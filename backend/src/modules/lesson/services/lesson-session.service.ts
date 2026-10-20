import { prisma } from './learning-transaction';
import { learningAction } from './learning-transaction';
import { PublicError } from '../../../security/errors';
import { publicLessonNode } from './public-lesson-node';
import { scriptCacheService } from './script-cache.service';
import { questionService } from './question.service';
import { masteryService } from './mastery.service';
import { defaultAiProvider } from '../providers/stub-ai.provider';
import { TransitionEngine } from '../engines/transition-engine';
import { LessonNode } from '../interfaces/script-dsl.interface';
import { SubmitActionInput, InterruptInput } from '../dtos/lesson-action.dto';
import { roadmapProgressionService } from '../../roadmap/services/roadmap-progression.service';
import { xpService } from '../../xp/xp.service';
import { AwardXpResult } from '../../xp/xp.types';

export class LessonSessionService {

  public async startOrResumeSessionByStep(userId: string, step: string, action: string, slug?: string, restart = false): Promise<any> {
    return learningAction(userId, 'start-step', step, action, {step,slug,restart}, id => this.startOrResumeSessionByStepImpl(userId,step,id,slug,restart));
  }
  public async startOrResumeSession(userId: string, slug: string, action: string, step?: string, restart = false): Promise<any> {
    return learningAction(userId,'start-script',slug,action,{slug,step,restart},id => this.startOrResumeSessionImpl(userId,slug,id,step,restart));
  }
  public async submitAction(userId: string, sessionId: string, input: SubmitActionInput) {
    return learningAction(userId,'submit',sessionId,input.clientActionId,input,id => this.submitActionImpl(userId,sessionId,{...input,clientActionId:id}),sessionId);
  }

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
    return publicLessonNode(node);
  }

  private async sanitizeNodeForUser(node: LessonNode, userId?: string, scriptId?: string): Promise<LessonNode> {
    const cloned = this.sanitizeNode(node);
    if (userId && cloned.type === 'QUESTION') {
      const qRef = cloned.questionReference;
      const questionId = qRef?.questionId;
      const targetKey = questionId ? `q:${questionId}` : (scriptId ? `script:${scriptId}:node:${cloned.id}` : null);
      if (targetKey) {
        const idempKey = `question_first_solve:${userId}:${targetKey}`;
        const claimed = await prisma.xpEvent.findUnique({
          where: { idempotencyKey: idempKey },
          select: { id: true },
        });
        if (claimed && cloned.questionReference?.inlineData) {
          (cloned.questionReference.inlineData as any).xp = 0;
        }
      }
    }
    return cloned;
  }

  /**
   * Starts or resumes a lesson session by roadmap step.
   * This is the authoritative entry point for roadmap-based learning.
   */
  private async startOrResumeSessionByStepImpl(
    userId: string,
    roadmapStepId: string,
    clientActionId: string,
    targetScriptSlug?: string,
    restart = false
  ): Promise<any> {

    let step = await prisma.roadmapStep.findUnique({
      where: { id: roadmapStepId },
      include: {
        roadmap: true,
        subject: true,
        topic: true,
        subtopic: true,
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          orderBy: { sequence: 'asc' },
          include: {
            script: {
              include: {
                versions: {
                  where: { status: 'PUBLISHED' },
                  orderBy: { versionNumber: 'desc' },
                  take: 1,
                },
              },
            },
            publishedVersion: true,
          },
        },
      },
    });

    if (
      !step ||
      !step.isActive ||
      !step.roadmap.isActive ||
      (step.subject && !step.subject.isActive) ||
      (step.topic && !step.topic.isActive) ||
      (step.subtopic && !step.subtopic.isActive)
    ) {
      // Re-resolve active step dynamically if requested step is inactive or belongs to an inactive subject
      const activeRoadmap = await roadmapProgressionService.getUserActiveRoadmap(userId).catch(() => null);
      if (activeRoadmap) {
        const nextStep = await roadmapProgressionService
          .getNextStepOrScript(userId, activeRoadmap.id)
          .catch(() => null);
        if (nextStep?.available && nextStep.roadmapStepId && nextStep.roadmapStepId !== roadmapStepId) {
          return this.startOrResumeSessionByStepImpl(userId, nextStep.roadmapStepId, clientActionId, targetScriptSlug);
        }
      }
      throw new PublicError(`Roadmap step "${roadmapStepId}" is currently not active.`);
    }

    if (!step.scriptAssignments || step.scriptAssignments.length === 0) {
      const error: any = new Error(
        `Learning content for "${step.id}" is coming soon. No published script available yet.`
      );
      error.code = 'SCRIPT_NOT_PUBLISHED';
      error.status = 404;
      throw error;
    }

    // Check for an active resumable session for this user and step
    let session = await prisma.lessonSession.findFirst({
      where: {
        userId,
        roadmapStepId: step.id,
        status: { in: ['ACTIVE', 'PAUSED'] },
      },
      orderBy: { lastActivityAt: 'desc' },
      include: { script: true },
    });

    let assignment = step.scriptAssignments[0];

    if (targetScriptSlug) {
      let target = step.scriptAssignments.find((sa) => sa.script?.slug === targetScriptSlug);

      if (!target) {
        // Fallback 1: match by scriptId or subtopicId among step assignments
        target = step.scriptAssignments.find(
          (sa) => sa.scriptId === targetScriptSlug || sa.script?.subtopicId === targetScriptSlug
        );
      }

      if (!target) throw new PublicError('Published script is not assigned to this step', 'SCRIPT_NOT_PUBLISHED',404);

      if (target) {
        assignment = target;

        if (session) {
          if (session.scriptId !== target.scriptId || restart) {
            // Abandon prior session for different script or if restart requested
            await prisma.lessonSession.update({
              where: { id: session.id },
              data: { status: 'ABANDONED', lastActivityAt: new Date() },
            }).catch(() => {});
            session = null;
          }
        }
      }
    } else {
      // ONLY when NO targetScriptSlug was specified (e.g. general Play Topic tap):
      if (restart && session) {
        await prisma.lessonSession.update({
          where: { id: session.id },
          data: { status: 'ABANDONED', lastActivityAt: new Date() },
        }).catch(() => {});
        session = null;
      } else if (!session) {
        const completedSessions = await prisma.lessonSession.findMany({
          where: {
            userId,
            roadmapStepId: step.id,
            status: 'COMPLETED',
          },
          select: { scriptId: true },
        });
        const completedScriptIds = new Set(completedSessions.map((s) => s.scriptId));

        const nextAssignment = step.scriptAssignments.find(
          (sa) => !completedScriptIds.has(sa.scriptId)
        );
        if (nextAssignment) {
          assignment = nextAssignment;
        }
      } else {
        assignment =
          step.scriptAssignments.find((sa) => sa.scriptId === session!.scriptId) || assignment;
      }
    }

    const effectiveVersionId =
      assignment?.publishedVersionId ||
      assignment?.script?.publishedVersionId ||
      (assignment?.script as any)?.versions?.[0]?.id;

    if (!assignment || !assignment.script || !effectiveVersionId) {
      const error: any = new Error(
        `Learning content for "${step.id}" is coming soon. No published script available yet.`
      );
      error.code = 'SCRIPT_NOT_PUBLISHED';
      error.status = 404;
      throw error;
    }

    await scriptCacheService.assertPublished(assignment.scriptId, effectiveVersionId);

    // Self-heal assignment publishedVersionId if it was null
    if (!assignment.publishedVersionId && effectiveVersionId) {
      await prisma.scriptAssignment.update({
        where: { id: assignment.id },
        data: { publishedVersionId: effectiveVersionId },
      }).catch(() => {});
    }

    const script = session?.script || assignment.script;
    const scriptVersionId = session?.scriptVersionId || effectiveVersionId;

    await scriptCacheService.assertPublished(script.id, scriptVersionId);
    let definition: any;

    if (!session) {
      definition = await scriptCacheService.getScriptVersionDefinition(scriptVersionId, script.title);

      if (!definition) {
        const error: any = new Error(`Script version definition "${scriptVersionId}" could not be loaded.`);
        error.status = 404;
        throw error;
      }

      const entryNodeId = definition.entryNodeId || Object.keys(definition.nodes)[0] || 'node_1';
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
        include: { script: true },
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
      session = await prisma.lessonSession.update({
        where: { id: session.id },
        data: { status: 'ACTIVE', lastActivityAt: new Date() },
        include: { script: true },
      });
      definition = await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId, script.title);
      if (!definition) {
        const error: any = new Error(`Script version definition "${session.scriptVersionId}" could not be loaded.`);
        error.status = 404;
        throw error;
      }
    }

    const rawNode =
      definition.nodes[session.currentNodeId] ||
      definition.nodes[definition.entryNodeId] ||
      Object.values(definition.nodes)[0];

    if (!rawNode) {
      throw new PublicError(`Current node "${session.currentNodeId}" not found in script version.`);
    }

    const events = await prisma.lessonEvent.findMany({
      where: { sessionId: session.id },
      orderBy: { sequenceNumber: 'asc' },
    });

    const history: Array<{
      id: string;
      isUser: boolean;
      text: string;
      node?: LessonNode;
      evaluation?: { isCorrect: boolean; explanation?: string };
    }> = [];

    const entryNode = definition.nodes[definition.entryNodeId];
    if (entryNode && session.currentNodeId !== definition.entryNodeId) {
      history.push({
        id: `node_${entryNode.id}`,
        isUser: false,
        text: entryNode.content?.text ?? '',
        node: this.sanitizeNode(entryNode),
      });
    }

    for (const evt of events) {
      if (evt.eventType === 'SESSION_STARTED') continue;
      const payload = evt.payload as any;
      const userText =
        payload?.action?.answer ||
        payload?.action?.actionId ||
        (payload?.action?.type === 'CONTINUE' ? 'Continue' : null);
      if (userText) {
        history.push({
          id: `user_${evt.id}`,
          isUser: true,
          text: userText,
        });
      }
      if (payload?.evaluation?.explanation) {
        history.push({
          id: `eval_${evt.id}`,
          isUser: false,
          text: payload.evaluation.explanation,
          evaluation: payload.evaluation,
        });
      }
      const reachedNode = definition.nodes[evt.nodeId];
      if (reachedNode && reachedNode.id !== session.currentNodeId) {
        history.push({
          id: `node_${reachedNode.id}`,
          isUser: false,
          text: reachedNode.content?.text ?? '',
          node: this.sanitizeNode(reachedNode),
        });
      }
    }

    const response = {
      sessionId: session.id,
      roadmapId: session.roadmapId,
      roadmapStepId: session.roadmapStepId,
      scriptId: session.scriptId,
      scriptSlug: script.slug,
      scriptTitle: script.title,
      scriptVersionId: session.scriptVersionId,
      status: session.status,
      stateVersion: session.stateVersion,
      currentNode: await this.sanitizeNodeForUser(rawNode, userId, session.scriptId),
      history,
    };
    return response;
  }

  private async startOrResumeSessionImpl(
    userId: string,
    scriptSlug: string,
    clientActionId: string,
    roadmapStepId?: string,
    restart = false
  ) {

    const scriptMeta = await scriptCacheService.getPublishedScriptBySlug(scriptSlug);
    if (!scriptMeta) {
      throw new PublicError(`Published lesson script "${scriptSlug}" not found.`);
    }

    const { scriptId, scriptVersionId } = scriptMeta;
    let definition = scriptMeta.definition;

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
      orderBy: { lastActivityAt: 'desc' },
    });

    if (restart && session) {
      await prisma.lessonSession.update({
        where: { id: session.id },
        data: { status: 'ABANDONED', lastActivityAt: new Date() },
      }).catch(() => {});
      session = null;
    }

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
    } else {
      session = await prisma.lessonSession.update({
        where: { id: session.id },
        data: { status: 'ACTIVE', lastActivityAt: new Date() },
      });
    }

    await scriptCacheService.assertPublished(session.scriptId, session.scriptVersionId);
    definition = (await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId))!;
    const rawNode = definition.nodes[session.currentNodeId];
    if (!rawNode) {
      throw new PublicError(`Current node "${session.currentNodeId}" not found in script version.`);
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
      currentNode: await this.sanitizeNodeForUser(rawNode, userId, scriptId),
    };
    return response;
  }

  public async getSession(userId: string, sessionId: string) {
    const session = await prisma.lessonSession.findFirst({
      where: { id: sessionId, userId },
    });

    if (!session) {
      throw new PublicError(`Session "${sessionId}" not found or unauthorized.`);
    }

    await scriptCacheService.assertPublished(session.scriptId, session.scriptVersionId);
    const definition = await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId);
    if (!definition) {
      throw new PublicError(`Script version "${session.scriptVersionId}" could not be loaded.`);
    }

    const rawNode = definition.nodes[session.currentNodeId];
    return {
      sessionId: session.id,
      scriptId: session.scriptId,
      scriptVersionId: session.scriptVersionId,
      status: session.status,
      stateVersion: session.stateVersion,
      currentNode: await this.sanitizeNodeForUser(rawNode, userId, session.scriptId),
    };
  }

  private async submitActionImpl(userId: string, sessionId: string, input: SubmitActionInput) {

      const session = await prisma.lessonSession.findFirst({
        where: { id: sessionId, userId },
      });

      if (!session) {
        throw new PublicError(`Session "${sessionId}" not found.`);
      }

      if (!['ACTIVE', 'PAUSED'].includes(session.status)) {
        throw new PublicError('This lesson has already been completed.');
      }

      // Optimistic concurrency check
      if (session.stateVersion !== input.stateVersion) {
        const error: any = new PublicError('Stale state version. Client is out of sync.');
        error.code = 'STALE_STATE_VERSION';
        error.expectedVersion = session.stateVersion;
        error.authoritativeNodeId = session.currentNodeId;
        throw error;
      }

      // Node ID validation
      if (session.currentNodeId !== input.currentNodeId) {
        throw new PublicError(
          `Node mismatch. Server expects "${session.currentNodeId}", received "${input.currentNodeId}".`
        );
      }

      await scriptCacheService.assertPublished(session.scriptId, session.scriptVersionId);
      const definition = await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId);
      if (!definition) {
        throw new PublicError(`Script definition for version ${session.scriptVersionId} not found.`);
      }

      const currentNode = definition.nodes[session.currentNodeId];
      if (!currentNode) {
        throw new PublicError(`Node "${session.currentNodeId}" not found in script definition.`);
      }

      // Evaluate question if applicable
      let evaluation: { isCorrect: boolean; score: number; explanation?: string; correctOptionId?: string } | undefined;
      let actionXpResult: AwardXpResult | null = null;
      const effectiveActionPayload: { actionId?: string; answer?: string; isCorrect?: boolean } = {
        actionId: input.action.actionId,
        answer: input.action.answer,
      };

      if (
        currentNode.type === 'QUESTION' ||
        (currentNode.type === 'CHOICE' && currentNode.questionReference?.inlineData)
      ) {
        if (!['QUESTION_ANSWER', 'CHOICE'].includes(input.action.type)) throw new PublicError('An answer is required');
        const rawAnswer = input.action.answer || input.action.actionId || '';
        const evalRes = await questionService.evaluate(currentNode, rawAnswer);
        evaluation = {
          isCorrect: evalRes.isCorrect,
          score: evalRes.score,
          explanation: evalRes.explanation,
          correctOptionId: evalRes.correctOptionId,
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

        // Award Question XP using centralized formula (type XP + difficulty XP) ONLY on correct answer
        if (evalRes.isCorrect) {
          const qType = currentNode.questionReference?.inlineData?.questionType;
          const qDiff = currentNode.questionReference?.inlineData?.difficulty;
          actionXpResult = await xpService.awardQuestionXp({
            userId,
            clientActionId: input.clientActionId,
            scriptId: session.scriptId,
            questionType: qType,
            difficulty: qDiff,
            questionId: currentNode.questionReference?.questionId || null,
            nodeId: currentNode.id,
            sessionId,
          });
        }

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
      await Promise.all([
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

        if (effectiveRoadmapId) {
          nextStepResult = await roadmapProgressionService.getNextStepOrScript(
            userId,
            effectiveRoadmapId,
            effectiveRoadmapStepId,
            session.scriptId
          );
        }

        // Only mark roadmap step as completed if all scripts in this step have finished
        if (
          effectiveRoadmapId &&
          effectiveRoadmapStepId &&
          (!nextStepResult || nextStepResult.roadmapStepId !== effectiveRoadmapStepId)
        ) {
          await roadmapProgressionService.markStepCompleted(
            userId,
            effectiveRoadmapId,
            effectiveRoadmapStepId
          );
        }

        // Award Subtopic Script Completion XP (+20 XP)
        const effectiveTopicId = definition.metadata?.topicId || (session as any).script?.topicId;
        const effectiveSubtopicId = definition.metadata?.subtopicId || (session as any).script?.subtopicId;

        const scriptXpResult = await xpService.awardSubtopicCompletionXp({
          userId,
          roadmapId: effectiveRoadmapId,
          roadmapStepId: effectiveRoadmapStepId,
          topicId: effectiveTopicId,
          subtopicId: effectiveSubtopicId,
          scriptId: session.scriptId,
          scriptVersionId: session.scriptVersionId,
          sessionId: session.id,
        });

        let combinedXp = scriptXpResult.xp;
        let combinedLevelUp = scriptXpResult.levelUp;
        let topicXpResult: any = null;

        // Check if Topic is now fully completed in active roadmap
        if (effectiveRoadmapId && effectiveTopicId) {
          topicXpResult = await roadmapProgressionService.checkAndAwardTopicCompletion(
            userId,
            effectiveRoadmapId,
            effectiveTopicId
          );

          if (topicXpResult && topicXpResult.awarded) {
            combinedXp = {
              ...topicXpResult.xp,
              earned: scriptXpResult.xp.earned + topicXpResult.xp.earned,
              previousTotal: scriptXpResult.xp.previousTotal,
            };
            combinedLevelUp = {
              occurred: scriptXpResult.levelUp.occurred || topicXpResult.levelUp.occurred,
              fromLevel: scriptXpResult.levelUp.fromLevel,
              toLevel: topicXpResult.levelUp.toLevel,
              levelsGained: topicXpResult.levelUp.toLevel - scriptXpResult.levelUp.fromLevel,
            };
          }
        }

        const anyAwarded = scriptXpResult.awarded || (topicXpResult && topicXpResult.awarded);
        actionXpResult = {
          awarded: !!anyAwarded,
          xp: combinedXp,
          levelUp: combinedLevelUp,
        };
      }

      // If no XP-awarding event occurred on this action (e.g. continue node), get latest progress
      if (!actionXpResult) {
        const currentProgress = await xpService.getUserProgress(userId);
        actionXpResult = {
          awarded: false,
          xp: currentProgress,
          levelUp: {
            occurred: false,
            fromLevel: currentProgress.level,
            toLevel: currentProgress.level,
            levelsGained: 0,
          },
        };
      }

      const response = {
        sessionId,
        stateVersion: nextStateVersion,
        status: isCompleted ? 'COMPLETED' : 'ACTIVE',
        isCompleted,
        evaluation,
        currentNode: await this.sanitizeNodeForUser(nextNode, userId, session.scriptId),
        xp: actionXpResult && actionXpResult.awarded && actionXpResult.xp && actionXpResult.xp.earned > 0 ? actionXpResult.xp : null,
        levelUp: actionXpResult && actionXpResult.awarded && actionXpResult.levelUp && actionXpResult.levelUp.occurred ? actionXpResult.levelUp : null,
        ...(isCompleted && nextStepResult ? { next: nextStepResult } : {}),
      };
      return response;
  }

  public async handleInterrupt(userId: string, sessionId: string, input: InterruptInput) {
    // The current provider is a local stub. Real AI generation belongs outside this commit boundary.
    return learningAction(userId,'interrupt',sessionId,input.clientActionId,input,() => this.handleInterruptImpl(userId,sessionId,input),sessionId);
  }

  private async handleInterruptImpl(userId: string, sessionId: string, input: InterruptInput) {
    const session = await prisma.lessonSession.findFirst({
      where: { id: sessionId, userId },
    });

    if (!session) {
      throw new PublicError(`Session "${sessionId}" not found.`);
    }

    await scriptCacheService.assertPublished(session.scriptId, session.scriptVersionId);
    const definition = await scriptCacheService.getScriptVersionDefinition(session.scriptVersionId);
    if (input.currentNodeId !== session.currentNodeId) throw new PublicError('Lesson step has changed. Reopen the current step.','STALE_NODE',409);
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
    if (!await prisma.lessonSession.findFirst({where:{id:sessionId,userId},select:{id:true}})) throw new PublicError('Lesson session not found','NOT_FOUND',404);
    return prisma.lessonSession.updateMany({
      where: { id: sessionId, userId, status: 'ACTIVE' },
      data: { status: 'PAUSED', lastActivityAt: new Date() },
    });
  }

  public async resumeSession(userId: string, sessionId: string) {
    if (!await prisma.lessonSession.findFirst({where:{id:sessionId,userId},select:{id:true}})) throw new PublicError('Lesson session not found','NOT_FOUND',404);
    return prisma.lessonSession.updateMany({
      where: { id: sessionId, userId, status: { in: ['ACTIVE', 'PAUSED'] } },
      data: { status: 'ACTIVE', lastActivityAt: new Date() },
    });
  }

  public async getActiveSession(userId: string, roadmapStepId?: string): Promise<any> {
    let effectiveStepId = roadmapStepId;
    if (!effectiveStepId) {
      const activeRoadmap = await roadmapProgressionService.getUserActiveRoadmap(userId).catch(() => null);
      if (activeRoadmap) {
        const nextStep = await roadmapProgressionService
          .getNextStepOrScript(userId, activeRoadmap.id)
          .catch(() => null);
        if (nextStep?.available && nextStep.roadmapStepId) {
          effectiveStepId = nextStep.roadmapStepId;
        }
      }
      if (!effectiveStepId) {
        effectiveStepId = 'ga-qa-01';
      }
    }

    const step = await prisma.roadmapStep.findUnique({
      where: { id: effectiveStepId },
      include: {
        roadmap: true,
        subject: true,
        topic: true,
        subtopic: true,
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          orderBy: { sequence: 'asc' },
          include: {
            script: {
              include: {
                versions: {
                  where: { status: 'PUBLISHED' },
                  orderBy: { versionNumber: 'desc' },
                  take: 1,
                },
              },
            },
            publishedVersion: true,
          },
        },
      },
    });

    if (
      !step ||
      !step.isActive ||
      !step.roadmap.isActive ||
      (step.subject && !step.subject.isActive) ||
      (step.topic && !step.topic.isActive) ||
      (step.subtopic && !step.subtopic.isActive) ||
      !step.scriptAssignments.length
    ) {
      // Step is inactive, belongs to an inactive subject, or has no scripts. Re-resolve dynamically from active roadmap!
      const activeRoadmap = await roadmapProgressionService.getUserActiveRoadmap(userId).catch(() => null);
      if (activeRoadmap) {
        const nextStep = await roadmapProgressionService
          .getNextStepOrScript(userId, activeRoadmap.id)
          .catch(() => null);
        if (nextStep?.available && nextStep.roadmapStepId && nextStep.roadmapStepId !== effectiveStepId) {
          return this.getActiveSession(userId, nextStep.roadmapStepId);
        }
      }
      return { hasActiveSession: false, roadmapStepId: effectiveStepId, script: null, session: null };
    }

    // Check for an active session
    const activeSession = await prisma.lessonSession.findFirst({
      where: {
        userId,
        roadmapStepId: step.id,
        status: { in: ['ACTIVE', 'PAUSED'] },
      },
      orderBy: { lastActivityAt: 'desc' },
      include: { script: true },
    });

    if (activeSession) {
      await scriptCacheService.assertPublished(activeSession.scriptId,activeSession.scriptVersionId);
      let definition = await scriptCacheService.getScriptVersionDefinition(activeSession.scriptVersionId, activeSession.script.title);

      if (definition) {
        const rawNode =
          definition.nodes[activeSession.currentNodeId] ||
          definition.nodes[definition.entryNodeId] ||
          Object.values(definition.nodes)[0];
        const events = await prisma.lessonEvent.findMany({
          where: { sessionId: activeSession.id },
          orderBy: { sequenceNumber: 'asc' },
        });

        const history: Array<{
          id: string;
          isUser: boolean;
          text: string;
          node?: LessonNode;
          evaluation?: { isCorrect: boolean; explanation?: string };
        }> = [];

        const entryNode = definition.nodes[definition.entryNodeId];
        if (entryNode && activeSession.currentNodeId !== definition.entryNodeId) {
          history.push({
            id: `node_${entryNode.id}`,
            isUser: false,
            text: entryNode.content?.text ?? '',
            node: this.sanitizeNode(entryNode),
          });
        }

        for (const evt of events) {
          if (evt.eventType === 'SESSION_STARTED') continue;
          const payload = evt.payload as any;
          const userText =
            payload?.action?.answer ||
            payload?.action?.actionId ||
            (payload?.action?.type === 'CONTINUE' ? 'Continue' : null);
          if (userText) {
            history.push({
              id: `user_${evt.id}`,
              isUser: true,
              text: userText,
            });
          }
          if (payload?.evaluation?.explanation) {
            history.push({
              id: `eval_${evt.id}`,
              isUser: false,
              text: payload.evaluation.explanation,
              evaluation: payload.evaluation,
            });
          }
          const reachedNode = definition.nodes[evt.nodeId];
          if (reachedNode && reachedNode.id !== activeSession.currentNodeId) {
            history.push({
              id: `node_${reachedNode.id}`,
              isUser: false,
              text: reachedNode.content?.text ?? '',
              node: this.sanitizeNode(reachedNode),
            });
          }
        }

        return {
          hasActiveSession: true,
          roadmapStepId: step.id,
          script: {
            id: activeSession.script.id,
            slug: activeSession.script.slug,
            title: activeSession.script.title,
            sequence: step.scriptAssignments.find((sa) => sa.scriptId === activeSession.scriptId)?.sequence ?? 1,
            targetDurationMinutes: definition.metadata?.targetDurationMinutes || 8,
            description: definition.metadata?.description || '',
          },
          session: {
            sessionId: activeSession.id,
            roadmapId: activeSession.roadmapId,
            roadmapStepId: activeSession.roadmapStepId,
            scriptId: activeSession.scriptId,
            scriptSlug: activeSession.script.slug,
            scriptTitle: activeSession.script.title,
            scriptVersionId: activeSession.scriptVersionId,
            status: activeSession.status,
            stateVersion: activeSession.stateVersion,
            currentNode: rawNode ? await this.sanitizeNodeForUser(rawNode, userId, activeSession.scriptId) : null,
            history,
          },
        };
      }
    }

    // No active session -> check next uncompleted script
    const completedSessions = await prisma.lessonSession.findMany({
      where: {
        userId,
        roadmapStepId: step.id,
        status: 'COMPLETED',
      },
      select: { scriptId: true },
    });
    const completedScriptIds = new Set(completedSessions.map((s) => s.scriptId));

    const nextAssignment =
      step.scriptAssignments.find((sa) => !completedScriptIds.has(sa.scriptId)) ||
      step.scriptAssignments[0];

    const effectiveVerId =
      nextAssignment?.publishedVersionId ||
      nextAssignment?.script?.publishedVersionId ||
      (nextAssignment?.script as any)?.versions?.[0]?.id;

    if (effectiveVerId) await scriptCacheService.assertPublished(nextAssignment.scriptId,effectiveVerId);
    const def = effectiveVerId
      ? await scriptCacheService.getScriptVersionDefinition(effectiveVerId, nextAssignment.script?.title)
      : null;

    return {
      hasActiveSession: false,
      roadmapStepId: step.id,
      script: {
        id: nextAssignment.script.id,
        slug: nextAssignment.script.slug,
        title: nextAssignment.script.title,
        sequence: nextAssignment.sequence,
        targetDurationMinutes: def?.metadata?.targetDurationMinutes || 8,
        description: def?.metadata?.description || '',
      },
      session: null,
    };
  }
}

export const lessonSessionService = LessonSessionService.getInstance();
