import { Request, Response } from 'express';
import { prisma } from '../../config/prisma';
import { questionGenerationService } from '../ai/services/question-generation.service';
import { pvpSetGenerationService } from '../ai/services/pvp-set-generation.service';
import { TIME_CONFIG, INVENTORY_CONFIG } from '../../config/inventory.config';
import { FingerprintService } from '../question/services/fingerprint.service';

export class AdminController {
  /**
   * POST /api/v1/admin/questions/generate
   */
  public static async triggerQuestionGeneration(req: Request, res: Response) {
    const { subtopicId, count } = req.body;
    if (!subtopicId) {
      res.status(400).json({ success: false, message: 'subtopicId is required' });
      return;
    }

    try {
      const questions = await questionGenerationService.generateQuestionsForSubtopic(
        subtopicId,
        typeof count === 'number' ? count : 10
      );
      res.status(200).json({ success: true, count: questions.length, data: questions });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * POST /api/v1/admin/pvp-sets/generate
   */
  public static async triggerPvpSetGeneration(_req: Request, res: Response) {
    try {
      const pvpSet = await pvpSetGenerationService.generatePvpQuestionSet();
      res.status(200).json({ success: true, data: pvpSet });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * POST /api/v1/admin/questions/manual
   */
  public static async createManualQuestion(req: Request, res: Response) {
    const {
      subjectId,
      topicId,
      subtopicId,
      pattern,
      prompt,
      options,
      correctAnswer,
      hints,
      explanation,
      method,
      difficulty,
      estimatedTimeSeconds,
      calculationMode,
    } = req.body;

    if (!prompt || !options || !correctAnswer || !subtopicId) {
      res.status(400).json({ success: false, message: 'Missing required question fields' });
      return;
    }

    try {
      const fingerprint = FingerprintService.computeFingerprint(prompt, options);

      const question = await prisma.question.create({
        data: {
          subjectId,
          topicId,
          subtopicId,
          pattern,
          prompt,
          options,
          correctAnswer,
          hints: hints || [],
          explanation: explanation || '',
          method: method || '',
          difficulty: difficulty || 'EASY',
          estimatedTimeSeconds: estimatedTimeSeconds || 60,
          calculationMode: calculationMode || 'MENTAL',
          sourceType: 'MANUAL',
          status: 'PUBLISHED',
          fingerprint,
        },
      });

      res.status(201).json({ success: true, data: question });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  /**
   * PUT /api/v1/admin/config/timing
   */
  public static async updateTimingConfig(req: Request, res: Response) {
    const { practiceMin, practiceMax, pvpFixed } = req.body;

    if (typeof practiceMin === 'number') TIME_CONFIG.PRACTICE_MIN_SECONDS = practiceMin;
    if (typeof practiceMax === 'number') TIME_CONFIG.PRACTICE_MAX_SECONDS = practiceMax;
    if (typeof pvpFixed === 'number') {
      TIME_CONFIG.PVP_FIXED_SECONDS = pvpFixed;
      TIME_CONFIG.PVP_MAX_SECONDS = pvpFixed;
    }

    res.status(200).json({
      success: true,
      message: 'Timing configuration updated dynamically',
      data: { TIME_CONFIG, INVENTORY_CONFIG },
    });
  }
}
