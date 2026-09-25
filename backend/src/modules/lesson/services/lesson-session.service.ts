import { prisma } from '../../../config/prisma';
import { redisService } from './redis.service';
import { scriptCacheService } from './script-cache.service';
import { questionService } from './question.service';
import { masteryService } from './mastery.service';
import { defaultAiProvider } from '../providers/stub-ai.provider';
import { TransitionEngine } from '../engines/transition-engine';
import { LessonNode } from '../interfaces/script-dsl.interface';
import { SubmitActionInput, InterruptInput } from '../dtos/lesson-action.dto';
import { roadmapProgressionService } from '../../roadmap/services/roadmap-progression.service';

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

  /**
   * Starts or resumes a lesson session by roadmap step.
   * This is the authoritative entry point for roadmap-based learning.
   */
  public async startOrResumeSessionByStep(
    userId: string,
    roadmapStepId: string,
    clientActionId: string
  ) {
    const idempKey = `idemp:action:${clientActionId}`;
    const cachedResponse = await redisService.get(idempKey);
    if (cachedResponse) {
      return JSON.parse(cachedResponse);
    }

    const step = await prisma.roadmapStep.findUnique({
      where: { id: roadmapStepId },
      include: {
        roadmap: true,
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          orderBy: { sequence: 'asc' },
          include: {
            script: true,
            publishedVersion: true,
          },
        },
      },
    });

    if (!step) {
      throw new Error(`Roadmap step "${roadmapStepId}" not found.`);
    }

    if (!step.isActive || !step.roadmap.isActive) {
      throw new Error(`Roadmap step "${roadmapStepId}" is currently not active.`);
    }

    const assignment = step.scriptAssignments[0];
    if (!assignment || !assignment.script || !assignment.publishedVersionId) {
      const error: any = new Error(
        `Learning content for "${step.id}" is coming soon. No published script available yet.`
      );
      error.code = 'SCRIPT_NOT_PUBLISHED';
      error.status = 404;
      throw error;
    }

    const script = assignment.script;
    const scriptVersionId = assignment.publishedVersionId;

    // Check for an active resumable session for this user and step
    let session = await prisma.lessonSession.findFirst({
      where: {
        userId,
        roadmapStepId: step.id,
        status: { in: ['ACTIVE', 'PAUSED'] },
      },
      orderBy: { startedAt: 'desc' },
    });

    let definition: any;

    if (!session) {
      definition = await scriptCacheService.getScriptVersionDefinition(scriptVersionId);
      if (!definition) {
        throw new Error(`Script version definition "${scriptVersionId}" could not be loaded.`);
      }

      const entryNodeId = definition.entryNodeId;
      session = await prisma.lessonSession.create({
        data: {
          userId,
          roadmapId: step.roadmapId,
          roadmapStepId: step.id,
          scriptId: script.id,
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
          payload: { roadmapStepId: step.id, scriptSlug: script.slug, scriptVersionId },
        },
      });
    } else {
      // Resume existing session using its own scriptVersionId
      definition = await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId);
      if (!definition) {
        throw new Error(`Script version definition "${session.scriptVersionId}" could not be loaded.`);
      }
    }

    const rawNode = definition.nodes[session.currentNodeId];
    if (!rawNode) {
      throw new Error(`Current node "${session.currentNodeId}" not found in script version.`);
    }

    const response = {
      sessionId: session.id,
      roadmapId: session.roadmapId,
      roadmapStepId: session.roadmapStepId,
      scriptId: session.scriptId,
      scriptSlug: script.slug,
      scriptVersionId: session.scriptVersionId,
      status: session.status,
      stateVersion: session.stateVersion,
      currentNode: this.sanitizeNode(rawNode),
    };

    await redisService.set(idempKey, JSON.stringify(response), 86400);
    return response;
  }

  public async startOrResumeSession(
    userId: string,
    scriptSlug: string,
    clientActionId: string,
    roadmapStepId?: string
  ) {
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

    // Resolve roadmapStepId and roadmapId if not explicitly provided
    let effectiveRoadmapId: string | null = null;
    let effectiveRoadmapStepId: string | null = roadmapStepId || null;

    if (!effectiveRoadmapStepId) {
      // Check if user has an active roadmap and this script is assigned to one of its steps
      const activeRoadmap = await roadmapProgressionService.getUserActiveRoadmap(userId).catch(() => null);
      if (activeRoadmap) {
        const assignment = await prisma.scriptAssignment.findFirst({
          where: {
            scriptId,
            roadmapStep: { roadmapId: activeRoadmap.id },
            status: 'PUBLISHED',
          },
          include: { roadmapStep: true },
        });
        if (assignment) {
          effectiveRoadmapId = activeRoadmap.id;
          effectiveRoadmapStepId = assignment.roadmapStepId;
        }
      }
    } else {
      const step = await prisma.roadmapStep.findUnique({ where: { id: effectiveRoadmapStepId } });
      if (step) {
        effectiveRoadmapId = step.roadmapId;
      }
    }

    // Check for an active resumable session
    let session = await prisma.lessonSession.findFirst({
      where: {
        userId,
        scriptId,
        ...(effectiveRoadmapStepId ? { roadmapStepId: effectiveRoadmapStepId } : {}),
        status: { in: ['ACTIVE', 'PAUSED'] },
      },
      orderBy: { startedAt: 'desc' },
    });

    if (!session) {
      const entryNodeId = definition.entryNodeId;
      session = await prisma.lessonSession.create({
        data: {
          userId,
          roadmapId: effectiveRoadmapId,
          roadmapStepId: effectiveRoadmapStepId,
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
          payload: { scriptSlug, scriptVersionId, roadmapStepId: effectiveRoadmapStepId },
        },
      });
    }

    const rawNode = definition.nodes[session.currentNodeId];
    if (!rawNode) {
      throw new Error(`Current node "${session.currentNodeId}" not found in script version.`);
    }

    const response = {
      sessionId: session.id,
      roadmapId: session.roadmapId,
      roadmapStepId: session.roadmapStepId,
      scriptId: session.scriptId,
      scriptSlug,
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

      // Handle roadmap-aware progression when lesson completes
      let nextStepResult: any = undefined;
      if (isCompleted) {
        let effectiveRoadmapId = session.roadmapId;
        let effectiveRoadmapStepId = session.roadmapStepId;

        if (!effectiveRoadmapId || !effectiveRoadmapStepId) {
          const activeRoadmap = await roadmapProgressionService.getUserActiveRoadmap(userId).catch(() => null);
          if (activeRoadmap) {
            effectiveRoadmapId = activeRoadmap.id;
            const assignment = await prisma.scriptAssignment.findFirst({
              where: {
                scriptId: session.scriptId,
                roadmapStep: { roadmapId: activeRoadmap.id },
                status: 'PUBLISHED',
              },
            });
            if (assignment) {
              effectiveRoadmapStepId = assignment.roadmapStepId;
              await prisma.lessonSession.update({
                where: { id: sessionId },
                data: {
                  roadmapId: effectiveRoadmapId,
                  roadmapStepId: effectiveRoadmapStepId,
                },
              });
            }
          }
        }

        if (effectiveRoadmapId && effectiveRoadmapStepId) {
          await roadmapProgressionService.markStepCompleted(
            userId,
            effectiveRoadmapId,
            effectiveRoadmapStepId
          );
        }

        if (effectiveRoadmapId) {
          nextStepResult = await roadmapProgressionService.getNextStepOrScript(
            userId,
            effectiveRoadmapId,
            effectiveRoadmapStepId,
            session.scriptId
          );
        }
      }

      const response = {
        sessionId,
        stateVersion: nextStateVersion,
        status: isCompleted ? 'COMPLETED' : 'ACTIVE',
        isCompleted,
        evaluation,
        currentNode: this.sanitizeNode(nextNode),
        ...(isCompleted && nextStepResult ? { next: nextStepResult } : {}),
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
