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
    // CACHE CANDIDATE: brief admin-only demographics snapshot; invalidate on registration/profile edits.
    const [totalUsers,completedRegistration,groups]=await Promise.all([
      prisma.user.count(),prisma.user.count({where:{isRegistrationComplete:true}}),
      prisma.$queryRaw<Array<{kind:string;name:string;count:number}>>`
        WITH dimensions AS (
          SELECT 'gender' AS kind,CASE WHEN lower(gender)='male' THEN 'MALE' WHEN lower(gender)='female' THEN 'FEMALE'
            WHEN lower(gender) IN ('non-binary','non binary','other') THEN 'OTHER' ELSE 'UNSPECIFIED' END AS name FROM users.profiles
          UNION ALL SELECT 'country',COALESCE(NULLIF(trim(country),''),'Unspecified') FROM users.profiles
          UNION ALL SELECT 'religion',COALESCE(NULLIF(trim(religion),''),'Unspecified') FROM users.profiles
        ), counts AS (SELECT kind,name,count(*)::int AS count FROM dimensions GROUP BY kind,name), ranked AS (
          SELECT *,row_number() OVER(PARTITION BY kind ORDER BY count DESC,name) AS position FROM counts
        ) SELECT kind,name,count FROM ranked WHERE position<=10 ORDER BY kind,count DESC,name`,
    ]);
    const pendingRegistration=totalUsers-completedRegistration;
    const genderMap={MALE:0,FEMALE:0,OTHER:0,UNSPECIFIED:0};
    for(const row of groups.filter(row=>row.kind==='gender'))if(Object.hasOwn(genderMap,row.name))genderMap[row.name as keyof typeof genderMap]=row.count;
    const byCountry=groups.filter(row=>row.kind==='country').map(({name,count})=>({name,count}));
    const byReligion=groups.filter(row=>row.kind==='religion').map(({name,count})=>({name,count}));

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
