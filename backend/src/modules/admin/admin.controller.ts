import { getPracticeTiming,updatePracticeTiming } from '../../config/timing-policy';
import { publicFailure } from '../../security/public-error';
import { AdminQuestionsService } from './admin-questions.service';
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
    } catch (err: any) { publicFailure(res,err); }
  }

  /**
   * POST /api/v1/admin/pvp-sets/generate
   */
  public static async triggerPvpSetGeneration(_req: Request, res: Response) {
    try {
      const pvpSet = await pvpSetGenerationService.generatePvpQuestionSet();
      res.status(200).json({ success: true, data: pvpSet });
    } catch (err: any) { publicFailure(res,err); }
  }

  /**
   * POST /api/v1/admin/questions/manual
   */
  public static async createManualQuestion(req: Request, res: Response) {
    try {res.status(201).json({success:true,data:await AdminQuestionsService.createQuestion({...req.body,sourceType:'MANUAL'})});}
    catch {res.status(400).json({success:false,message:'Invalid question content'});}
  }

  /**
   * PUT /api/v1/admin/config/timing
   */
  public static async updateTimingConfig(req: Request, res: Response) {
    try {
      const policy=await updatePracticeTiming(req.body);
      res.json({success:true,data:{version:policy.version,TIME_CONFIG:{...TIME_CONFIG,PRACTICE_MIN_SECONDS:policy.minSeconds,PRACTICE_MAX_SECONDS:policy.maxSeconds},INVENTORY_CONFIG}});
    } catch(error){publicFailure(res,error);}
  }
  public static async getTimingConfig(_req:Request,res:Response){
    const policy=await getPracticeTiming();
    res.json({success:true,data:{version:policy.version,TIME_CONFIG:{...TIME_CONFIG,PRACTICE_MIN_SECONDS:policy.minSeconds,PRACTICE_MAX_SECONDS:policy.maxSeconds},INVENTORY_CONFIG}});
  }
}
