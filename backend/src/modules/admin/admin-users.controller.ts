import { publicFailure } from '../../security/public-error';
import { Request, Response } from 'express';
import { AdminUsersService } from './admin-users.service';

export class AdminUsersController {
  public static async listUsers(req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminUsersService.listUsers(req.query as any);
      res.status(200).json({ success: true, data });
    } catch (err: any) { publicFailure(res,err); }
  }

  // CACHE_CANDIDATE ref=C20 scope=admin-role layer=redis ttl=30-60s owner=analytics
  public static async getUserStats(_req: Request, res: Response): Promise<void> {
    try {
      const data = await AdminUsersService.getUserStats();
      res.status(200).json({ success: true, data });
    } catch (err: any) { publicFailure(res,err); }
  }

  public static async hardDeleteUser(req: Request, res: Response): Promise<void> {
    try {
      const result = await AdminUsersService.hardDeleteUser(req.params.id as string);
      res.status(200).json({ success: true, data: result });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
}
