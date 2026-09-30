import { Request, Response } from 'express';
import { AdminQuestionsService } from './admin-questions.service';

export class AdminQuestionsController {
  public static async listQuestions(req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminQuestionsService.listQuestions(req.query as any);
      res.status(200).json({ success: true, data });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  public static async getStats(_req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminQuestionsService.getQuestionStats();
      res.status(200).json({ success: true, data });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  public static async createQuestion(req: Request, res: Response): Promise<void> {
    try {
      const question = await AdminQuestionsService.createQuestion(req.body);
      res.status(201).json({ success: true, data: question });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async updateQuestion(req: Request, res: Response): Promise<void> {
    try {
      const question = await AdminQuestionsService.updateQuestion(req.params.id as string, req.body);
      res.status(200).json({ success: true, data: question });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async relinkQuestion(req: Request, res: Response): Promise<void> {
    try {
      const { newSubtopicId } = req.body;
      if (!newSubtopicId) {
        res.status(400).json({ success: false, message: 'newSubtopicId is required' });
        return;
      }
      const question = await AdminQuestionsService.relinkQuestion(req.params.id as string, newSubtopicId);
      res.status(200).json({ success: true, data: question });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async deleteQuestion(req: Request, res: Response): Promise<void> {
    try {
      await AdminQuestionsService.deleteQuestion(req.params.id as string);
      res.status(200).json({ success: true, message: 'Question hard deleted successfully' });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async bulkImport(req: Request, res: Response): Promise<void> {
    try {
      const { questions, defaultSubtopicId } = req.body;
      if (!Array.isArray(questions) || questions.length === 0) {
        res.status(400).json({ success: false, message: 'questions array is required and must not be empty' });
        return;
      }
      const result = await AdminQuestionsService.bulkImport(questions, defaultSubtopicId);
      res.status(200).json({ success: true, data: result });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
}
