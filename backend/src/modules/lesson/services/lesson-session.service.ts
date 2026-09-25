import { prisma } from '../../../config/prisma';
import { redisService } from './redis.service';
import { scriptCacheService } from './script-cache.service';
import { questionService } from './question.service';
import { masteryService } from './mastery.service';
import { defaultAiProvider } from '../providers/stub-ai.provider';
import { TransitionEngine } from '../engines/transition-engine';
import { LessonNode } from '../interfaces/script-dsl.interface';
import { SubmitActionInput, InterruptInput } from '../dtos/lesson-action.dto';

export class LessonSessionService {
  private static instance: LessonSessionService;

  public static getInstance(): LessonSessionService {
    if (!LessonSessionService.instance) {
      LessonSessionService.instance = new LessonSessionService();
    }
    return LessonSessionService.instance;
  }

  /**
   * Sanitizes a node before sending it to the client so that answer keys are not leaked.
   */
  private sanitizeNode(node: LessonNode): LessonNode {
    const cloned = JSON.parse(JSON.stringify(node)) as LessonNode;
    if (cloned.type === 'QUESTION' && cloned.questionReference?.inlineData) {
      delete (cloned.questionReference.inlineData as any).correctOptionId;
      delete (cloned.questionReference.inlineData as any).explanation;
    }
    return cloned;
  }

  public async startOrResumeSession(userId: string, scriptSlug: string, clientActionId: string) {
    const idempKey = `idemp:action:${clientActionId}`;
    const cachedResponse = await redisService.get(idempKey);
    if (cachedResponse) {
      return JSON.parse(cachedResponse);
    }

    const scriptMeta = await scriptCacheService.getPublishedScriptBySlug(scriptSlug);
    if (!scriptMeta) {
      throw new Error(`Published lesson script "${scriptSlug}" not found.`);
    }

    const { scriptId, scriptVersionId, definition } = scriptMeta;

    // Check for an active resumable session
    let session = await prisma.lessonSession.findFirst({
      where: {
        userId,
        scriptId,
        status: { in: ['ACTIVE', 'PAUSED'] },
      },
      orderBy: { startedAt: 'desc' },
    });

    if (!session) {
      const entryNodeId = definition.entryNodeId;
      session = await prisma.lessonSession.create({
        data: {
          userId,
          scriptId,
          scriptVersionId,
          status: 'ACTIVE',
          currentNodeId: entryNodeId,
          stateVersion: 1,
          stateData: { variables: {}, visitedNodeIds: [entryNodeId] },
        },
      });

      await prisma.lessonEvent.create({
        data: {
          sessionId: session.id,
          userId,
          sequenceNumber: 1,
          nodeId: entryNodeId,
          eventType: 'SESSION_STARTED',
          clientActionId,
          payload: { scriptSlug, scriptVersionId },
        },
      });
    }

    const rawNode = definition.nodes[session.currentNodeId];
    if (!rawNode) {
      throw new Error(`Current node "${session.currentNodeId}" not found in script version.`);
    }

    const response = {
      sessionId: session.id,
      scriptId: session.scriptId,
      scriptVersionId: session.scriptVersionId,
      status: session.status,
      stateVersion: session.stateVersion,
      currentNode: this.sanitizeNode(rawNode),
    };

    await redisService.set(idempKey, JSON.stringify(response), 86400);
    return response;
  }

  public async getSession(userId: string, sessionId: string) {
    const session = await prisma.lessonSession.findFirst({
      where: { id: sessionId, userId },
    });

    if (!session) {
      throw new Error(`Session "${sessionId}" not found or unauthorized.`);
    }

    const definition = await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId);
    if (!definition) {
      throw new Error(`Script version "${session.scriptVersionId}" could not be loaded.`);
    }

    const rawNode = definition.nodes[session.currentNodeId];
    return {
      sessionId: session.id,
      scriptId: session.scriptId,
      scriptVersionId: session.scriptVersionId,
      status: session.status,
      stateVersion: session.stateVersion,
      currentNode: this.sanitizeNode(rawNode),
    };
  }

  public async submitAction(userId: string, sessionId: string, input: SubmitActionInput) {
    const idempKey = `idemp:action:${input.clientActionId}`;
    const cachedResponse = await redisService.get(idempKey);
    if (cachedResponse) {
      return JSON.parse(cachedResponse);
    }

    const lockKey = `lock:session:${sessionId}`;
    const locked = await redisService.setNx(lockKey, '1', 3000);
    if (!locked) {
      throw new Error('A concurrent action is being processed for this session. Please retry.');
    }

    try {
      const session = await prisma.lessonSession.findFirst({
        where: { id: sessionId, userId },
      });

      if (!session) {
        throw new Error(`Session "${sessionId}" not found.`);
      }

      if (session.status === 'COMPLETED') {
        throw new Error('This lesson has already been completed.');
      }

      // Optimistic concurrency check
      if (session.stateVersion !== input.stateVersion) {
        const error: any = new Error('Stale state version. Client is out of sync.');
        error.code = 'STALE_STATE_VERSION';
        error.expectedVersion = session.stateVersion;
        error.authoritativeNodeId = session.currentNodeId;
        throw error;
      }

      // Node ID validation
      if (session.currentNodeId !== input.currentNodeId) {
        throw new Error(
          `Node mismatch. Server expects "${session.currentNodeId}", received "${input.currentNodeId}".`
        );
      }

      const definition = await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId);
      if (!definition) {
        throw new Error(`Script definition for version ${session.scriptVersionId} not found.`);
      }

      const currentNode = definition.nodes[session.currentNodeId];
      if (!currentNode) {
        throw new Error(`Node "${session.currentNodeId}" not found in script definition.`);
      }

      // Evaluate question if applicable
      let evaluation: { isCorrect: boolean; score: number; explanation?: string } | undefined;
      const effectiveActionPayload: { actionId?: string; answer?: string; isCorrect?: boolean } = {
        actionId: input.action.actionId,
        answer: input.action.answer,
      };

      if (currentNode.type === 'QUESTION') {
        const rawAnswer = input.action.answer || input.action.actionId || '';
        const evalRes = await questionService.evaluate(currentNode, rawAnswer);
        evaluation = {
          isCorrect: evalRes.isCorrect,
          score: evalRes.score,
          explanation: evalRes.explanation,
        };
        effectiveActionPayload.isCorrect = evalRes.isCorrect;

        // Record attempt
        await prisma.questionAttempt.create({
          data: {
            userId,
            sessionId,
            questionId: currentNode.questionReference?.questionId || null,
            nodeId: currentNode.id,
            clientActionId: input.clientActionId,
            rawAnswer,
            isCorrect: evalRes.isCorrect,
            score: evalRes.score,
            responseTimeMs: input.action.responseTimeMs || null,
          },
        });

        // Record mastery if linked to concept
        if (evalRes.conceptId) {
          await masteryService.recordAttempt(userId, evalRes.conceptId, evalRes.isCorrect);
        }
      }

      // Resolve next node
      const nextNodeId = TransitionEngine.resolveNextNode(
        currentNode,
        effectiveActionPayload,
        definition.nodes
      );

      const nextNode = definition.nodes[nextNodeId];
      const isCompleted = nextNode.type === 'COMPLETION';
      const nextStateVersion = session.stateVersion + 1;

      // Atomic persistence
      await prisma.$transaction([
        prisma.lessonSession.update({
          where: { id: sessionId },
          data: {
            currentNodeId: nextNodeId,
            stateVersion: nextStateVersion,
            status: isCompleted ? 'COMPLETED' : 'ACTIVE',
            completedAt: isCompleted ? new Date() : null,
            lastActivityAt: new Date(),
          },
        }),
        prisma.lessonEvent.create({
          data: {
            sessionId,
            userId,
            sequenceNumber: nextStateVersion,
            nodeId: nextNodeId,
            eventType: input.action.type,
            clientActionId: input.clientActionId,
            payload: {
              previousNodeId: currentNode.id,
              action: input.action,
              evaluation,
            },
          },
        }),
      ]);

      const response = {
        sessionId,
        stateVersion: nextStateVersion,
        status: isCompleted ? 'COMPLETED' : 'ACTIVE',
        isCompleted,
        evaluation,
        currentNode: this.sanitizeNode(nextNode),
      };

      await redisService.set(idempKey, JSON.stringify(response), 86400);
      return response;
    } finally {
      await redisService.del(lockKey);
    }
  }

  public async handleInterrupt(userId: string, sessionId: string, input: InterruptInput) {
    const session = await prisma.lessonSession.findFirst({
      where: { id: sessionId, userId },
    });

    if (!session) {
      throw new Error(`Session "${sessionId}" not found.`);
    }

    const definition = await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId);
    const rawNode = definition?.nodes[session.currentNodeId];

    const answer = await defaultAiProvider.answerDoubt({
      userId,
      sessionId,
      scriptVersionId: session.scriptVersionId,
      nodeId: session.currentNodeId,
      nodeText: rawNode?.content.text || '',
      userQuestion: input.questionText,
    });

    // Record interruption conversation
    await prisma.aiConversation.create({
      data: {
        userId,
        sessionId,
        scriptVersionId: session.scriptVersionId,
        nodeId: session.currentNodeId,
        status: 'CLOSED',
        closedAt: new Date(),
        messages: {
          create: [
            { sender: 'USER', content: input.questionText },
            { sender: 'AI_TUTOR', content: answer },
          ],
        },
      },
    });

    return {
      status: 'STUB_RESPONSE',
      message: answer,
      resumeNodeId: session.currentNodeId,
    };
  }

  public async pauseSession(userId: string, sessionId: string) {
    return prisma.lessonSession.updateMany({
      where: { id: sessionId, userId, status: 'ACTIVE' },
      data: { status: 'PAUSED', lastActivityAt: new Date() },
    });
  }

  public async resumeSession(userId: string, sessionId: string) {
    return prisma.lessonSession.updateMany({
      where: { id: sessionId, userId, status: 'PAUSED' },
      data: { status: 'ACTIVE', lastActivityAt: new Date() },
    });
  }
}

export const lessonSessionService = LessonSessionService.getInstance();
