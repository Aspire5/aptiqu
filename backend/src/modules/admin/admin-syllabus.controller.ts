import { Request, Response } from 'express';
import { AdminSyllabusService } from './admin-syllabus.service';

export class AdminSyllabusController {
  public static async getSyllabus(_req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminSyllabusService.getFullSyllabus();
      res.status(200).json({ success: true, data });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  // Subject Handlers
  public static async createSubject(req: Request, res: Response): Promise<void> {
    try {
      const subject = await AdminSyllabusService.createSubject(req.body);
      res.status(201).json({ success: true, data: subject });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async updateSubject(req: Request, res: Response): Promise<void> {
    try {
      const subject = await AdminSyllabusService.updateSubject(req.params.id as string, req.body);
      res.status(200).json({ success: true, data: subject });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async deleteSubject(req: Request, res: Response): Promise<void> {
    try {
      const hard = req.query.hard === 'true';
      await AdminSyllabusService.deleteSubject(req.params.id as string, hard);
      res.status(200).json({ success: true, message: `Subject deleted successfully (${hard ? 'hard' : 'soft'})` });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  // Topic Handlers
  public static async createTopic(req: Request, res: Response): Promise<void> {
    try {
      const topic = await AdminSyllabusService.createTopic(req.body);
      res.status(201).json({ success: true, data: topic });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async updateTopic(req: Request, res: Response): Promise<void> {
    try {
      const topic = await AdminSyllabusService.updateTopic(req.params.id as string, req.body);
      res.status(200).json({ success: true, data: topic });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async deleteTopic(req: Request, res: Response): Promise<void> {
    try {
      const hard = req.query.hard === 'true';
      await AdminSyllabusService.deleteTopic(req.params.id as string, hard);
      res.status(200).json({ success: true, message: `Topic deleted successfully (${hard ? 'hard' : 'soft'})` });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  // Subtopic Handlers
  public static async createSubtopic(req: Request, res: Response): Promise<void> {
    try {
      const subtopic = await AdminSyllabusService.createSubtopic(req.body);
      res.status(201).json({ success: true, data: subtopic });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async updateSubtopic(req: Request, res: Response): Promise<void> {
    try {
      const subtopic = await AdminSyllabusService.updateSubtopic(req.params.id as string, req.body);
      res.status(200).json({ success: true, data: subtopic });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async deleteSubtopic(req: Request, res: Response): Promise<void> {
    try {
      const hard = req.query.hard === 'true';
      await AdminSyllabusService.deleteSubtopic(req.params.id as string, hard);
      res.status(200).json({ success: true, message: `Subtopic deleted successfully (${hard ? 'hard' : 'soft'})` });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  // Script Handlers
  public static async getScript(req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminSyllabusService.getScriptDetails(req.params.id as string);
      res.status(200).json({ success: true, data });
    } catch (err: any) {
      res.status(404).json({ success: false, message: err.message });
    }
  }

  public static async createScript(req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminSyllabusService.createScript(req.body);
      res.status(201).json({ success: true, data });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async updateScript(req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminSyllabusService.updateScript(req.params.id as string, req.body);
      res.status(200).json({ success: true, data });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  // ==================== REORDERING ====================

  public static async reorderTopics(req: Request, res: Response): Promise<void> {
    try {
      const { topicIds } = req.body;
      const subjectId = req.params.subjectId as string;
      if (!Array.isArray(topicIds)) {
        res.status(400).json({ success: false, message: 'topicIds must be an array of IDs' });
        return;
      }
      await AdminSyllabusService.reorderTopics(subjectId, topicIds);
      res.status(200).json({ success: true, message: 'Topics reordered successfully' });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async reorderSubtopics(req: Request, res: Response): Promise<void> {
    try {
      const { subtopicIds } = req.body;
      const topicId = req.params.topicId as string;
      if (!Array.isArray(subtopicIds)) {
        res.status(400).json({ success: false, message: 'subtopicIds must be an array of IDs' });
        return;
      }
      await AdminSyllabusService.reorderSubtopics(topicId, subtopicIds);
      res.status(200).json({ success: true, message: 'Subtopics reordered successfully' });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  // ==================== LINKING / REUSABILITY ====================

  public static async linkTopic(req: Request, res: Response): Promise<void> {
    try {
      const { topicId } = req.body;
      const subjectId = req.params.subjectId as string;
      if (!topicId) {
        res.status(400).json({ success: false, message: 'topicId is required' });
        return;
      }
      const link = await AdminSyllabusService.linkTopicToSubject(subjectId, topicId);
      res.status(200).json({ success: true, data: link });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async unlinkTopic(req: Request, res: Response): Promise<void> {
    try {
      const subjectId = req.params.subjectId as string;
      const topicId = req.params.topicId as string;
      const result = await AdminSyllabusService.unlinkTopicFromSubject(subjectId, topicId);
      res.status(200).json(result);
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async linkSubtopic(req: Request, res: Response): Promise<void> {
    try {
      const { subtopicId } = req.body;
      const topicId = req.params.topicId as string;
      if (!subtopicId) {
        res.status(400).json({ success: false, message: 'subtopicId is required' });
        return;
      }
      const link = await AdminSyllabusService.linkSubtopicToTopic(topicId, subtopicId);
      res.status(200).json({ success: true, data: link });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async unlinkSubtopic(req: Request, res: Response): Promise<void> {
    try {
      const topicId = req.params.topicId as string;
      const subtopicId = req.params.subtopicId as string;
      const result = await AdminSyllabusService.unlinkSubtopicFromTopic(topicId, subtopicId);
      res.status(200).json(result);
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  public static async getAvailableTopics(_req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminSyllabusService.getAllAvailableTopics();
      res.status(200).json({ success: true, data });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  public static async getAvailableSubtopics(_req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminSyllabusService.getAllAvailableSubtopics();
      res.status(200).json({ success: true, data });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
}
