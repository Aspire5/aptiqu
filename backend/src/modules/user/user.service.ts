import { prisma } from '../../config/prisma';
import { xpService } from '../xp/xp.service';

export class UserService {
  /**
   * Retrieves user profile and gamification stats including XP and level progression.
   */
  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        profile: true,
        gameStats: true,
      },
    });

    if (!user) {
      throw new Error('User not found');
    }

    const xpProgress = await xpService.getUserProgress(userId);

    return {
      id: user.id,
      email: user.email,
      isRegistrationComplete: user.isRegistrationComplete,
      firstName: user.profile?.firstName || '',
      lastName: user.profile?.lastName || '',
      dob: user.profile?.dob,
      gender: user.profile?.gender || '',
      religion: user.profile?.religion || '',
      country: user.profile?.country || '',
      avatarUrl: user.profile?.avatarUrl || '',
      // Gamification & XP stats
      level: xpProgress.level,
      totalXp: xpProgress.total,
      currentLevelStartXp: xpProgress.currentLevelStartXp,
      nextLevelStartXp: xpProgress.nextLevelStartXp,
      xpIntoCurrentLevel: xpProgress.xpIntoCurrentLevel,
      xpRequiredForNextLevel: xpProgress.xpRequiredForNextLevel,
      xpRemainingToNextLevel: xpProgress.xpRemainingToNextLevel,
      progress: xpProgress.progress,
      xp: xpProgress,
      // NOTE: Streak is hardcoded to 0 for now as requested. Daily streak calculation logic will be handled later.
      streak: `${user.gameStats?.streak ?? 0}d`,
      // NOTE: Coins is hardcoded to 0 for now as requested. Coin rewards logic will be handled later.
      coins: user.gameStats?.coins ?? 0,
    };
  }

  /**
   * Retrieves standalone XP progression metrics.
   */
  async getProgress(userId: string) {
    return xpService.getUserProgress(userId);
  }
}
