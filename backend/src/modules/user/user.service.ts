import { prisma } from '../../config/prisma';

export class UserService {
  /**
   * Retrieves user profile and gamification stats.
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
      // Gamification stats
      level: user.gameStats?.level ?? 1,
      // NOTE: Streak is hardcoded to 0 for now as requested. Daily streak calculation logic will be handled later.
      streak: `${user.gameStats?.streak ?? 0}d`,
      // NOTE: Coins is hardcoded to 0 for now as requested (coins instead of xp). Coin rewards logic will be handled later.
      coins: user.gameStats?.coins ?? 0,
    };
  }
}
