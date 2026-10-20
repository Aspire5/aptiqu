import { publicFailure } from '../../security/public-error';
import { Request, Response } from 'express';
import { aiPromptService } from '../ai/services/ai-prompt.service';

export class AdminAiPromptsController {
  public static async listPrompts(req: Request, res: Response) {
    try {
      const prompts = await aiPromptService.listPrompts();
      res.json({ success: true, data: prompts });
    } catch (err: any) {
      publicFailure(res,err);
    }
  }

  public static async getPrompt(req: Request, res: Response) {
    try {
      const key = req.params.key as string;
      const prompt = await aiPromptService.getPrompt(key);
      if (!prompt) {
        return res.status(404).json({ success: false, error: `Prompt '${key}' not found.` });
      }
      res.json({ success: true, data: prompt });
    } catch (err: any) {
      publicFailure(res,err);
    }
  }

  public static async updateDraft(req: Request, res: Response) {
    try {
      const key = req.params.key as string;
      const { draftPrompt } = req.body;

      if (typeof draftPrompt !== 'string' || draftPrompt.trim().length === 0) {
        return res.status(400).json({ success: false, error: 'draftPrompt must be a non-empty string.' });
      }

      const updated = await aiPromptService.saveDraft(key, draftPrompt,req.body.expectedRevision);
      res.json({ success: true, data: updated, message: 'Draft saved successfully. Prompt is not live yet.' });
    } catch (err: any) {
      publicFailure(res,err);
    }
  }

  public static async publishPrompt(req: Request, res: Response) {
    try {
      const key = req.params.key as string;
      const published = await aiPromptService.publishPrompt(key,req.body.expectedRevision);
      res.json({ 
        success: true, 
        data: published, 
        message: `Prompt '${key}' published successfully! Now live across server without restart.` 
      });
    } catch (err: any) {
      publicFailure(res,err);
    }
  }

  public static async resetToDefault(req: Request, res: Response) {
    try {
      const key = req.params.key as string;
      const reset = await aiPromptService.resetToDefault(key,req.body.expectedRevision);
      res.json({ 
        success: true, 
        data: reset, 
        message: `Prompt '${key}' draft reset to system default template.` 
      });
    } catch (err: any) {
      publicFailure(res,err);
    }
  }
}
