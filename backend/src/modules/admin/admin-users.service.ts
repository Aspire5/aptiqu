import { prisma } from '../../config/prisma';

export class AdminUsersService {
  /**
   * Paginated list of registered users with search support
   */
  public static async listUsers(params: {
    search?: string;
    page?: number;
    limit?: number;
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const limit = Math.max(1, Math.min(100, Number(params.limit) || 15));
    const skip = (page - 1) * limit;

    const where: any = {};
    if (params.search && params.search.trim()) {
      const q = params.search.trim();
      where.OR = [
        { email: { contains: q, mode: 'insensitive' } },
        { profile: { firstName: { contains: q, mode: 'insensitive' } } },
        { profile: { lastName: { contains: q, mode: 'insensitive' } } },
      ];
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          profile: true,
          gameStats: true,
          progress: true,
        },
      }),
      prisma.user.count({ where }),
    ]);

    const formattedUsers = users.map((u) => ({
      id: u.id,
      email: u.email,
      isRegistrationComplete: u.isRegistrationComplete,
      createdAt: u.createdAt,
      updatedAt: u.updatedAt,
      profile: u.profile
        ? {
            firstName: u.profile.firstName,
            lastName: u.profile.lastName,
            displayName: `${u.profile.firstName || ''} ${u.profile.lastName || ''}`.trim() || 'Learner',
            gender: u.profile.gender || 'Not specified',
            country: u.profile.country || 'Not specified',
            religion: u.profile.religion || 'Not specified',
            avatarUrl: u.profile.avatarUrl,
          }
        : null,
      gameStats: u.gameStats
        ? {
            level: u.gameStats.level,
            streak: u.gameStats.streak,
            highestStreak: u.gameStats.highestStreak,
            coins: u.gameStats.coins,
            lastDailyDate: u.gameStats.lastDailyDate,
          }
        : null,
      progress: u.progress
        ? {
            totalXp: Number(u.progress.totalXp),
            level: u.progress.level,
          }
        : null,
    }));

    return {
      users: formattedUsers,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * User demographics and registration analytics
   */
  public static async getUserStats() {
    const [
      totalUsers,
      completedRegistration,
      pendingRegistration,
      profiles,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { isRegistrationComplete: true } }),
      prisma.user.count({ where: { isRegistrationComplete: false } }),
      prisma.profile.findMany({
        select: {
          gender: true,
          country: true,
          religion: true,
        },
      }),
    ]);

    // Breakdown by Gender
    const genderMap: Record<string, number> = {
      MALE: 0,
      FEMALE: 0,
      OTHER: 0,
      UNSPECIFIED: 0,
    };

    // Breakdown by Country
    const countryMap: Record<string, number> = {};

    // Breakdown by Religion
    const religionMap: Record<string, number> = {};

    for (const p of profiles) {
      // Gender
      const g = (p.gender || '').toUpperCase();
      if (g.includes('MALE') && !g.includes('FE')) genderMap.MALE++;
      else if (g.includes('FEMALE')) genderMap.FEMALE++;
      else if (g.includes('OTHER')) genderMap.OTHER++;
      else genderMap.UNSPECIFIED++;

      // Country
      const c = (p.country || 'Unspecified').trim();
      countryMap[c] = (countryMap[c] || 0) + 1;

      // Religion
      const r = (p.religion || 'Unspecified').trim();
      religionMap[r] = (religionMap[r] || 0) + 1;
    }

    // Convert map to sorted arrays
    const byCountry = Object.entries(countryMap)
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    const byReligion = Object.entries(religionMap)
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    return {
      totalUsers,
      registration: {
        completed: completedRegistration,
        pending: pendingRegistration,
      },
      byGender: genderMap,
      byCountry,
      byReligion,
    };
  }

  /**
   * HARD DELETE user:
   * Permanently erases user and all associated learning records
   */
  public static async hardDeleteUser(userId: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new Error(`User not found with id: ${userId}`);
    }

    return prisma.$transaction(async (tx) => {
      // 1. Clear any winnerId references in pvpMatches
      await tx.pvpMatch.updateMany({
        where: { winnerId: userId },
        data: { winnerId: null },
      });

      // 2. Delete user - cascades to all dependent rows
      await tx.user.delete({
        where: { id: userId },
      });

      return { success: true, message: `User ${user.email} (${userId}) permanently hard deleted` };
    });
  }
}
