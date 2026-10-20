import { PublicError } from '../../security/errors';
import { prisma } from '../../config/prisma';
import { verifyGoogleToken } from '../../utils/google';
import { signAccessToken, createRefreshTokenData } from '../../utils/jwt';
import { hashToken } from '../../utils/crypto';
import { OnboardingInput } from './auth.validation';

export class AuthService {
  /**
   * Authenticates user via Google OAuth ID Token.
   */
  async loginWithGoogle(idToken: string) {
    const googleUser = await verifyGoogleToken(idToken);

    // 1. Find or create user in auth.users
    let user = await prisma.user.findUnique({
      where: { googleId: googleUser.googleId },
      include: {
        profile: true,
        gameStats: true,
      },
    });

    if (!user) {
      // Check if user exists with the same email
      user = await prisma.user.findUnique({
        where: { email: googleUser.email },
        include: {
          profile: true,
          gameStats: true,
        },
      });

      if (user) {
        // An email match is never permission to replace an existing identity.
        if (user.googleId !== googleUser.googleId) throw new Error('Google account cannot be linked');
      } else {
        // Create new user and provisional profile with Google data
        user = await prisma.user.create({
          data: {
            email: googleUser.email,
            googleId: googleUser.googleId,
            isRegistrationComplete: false,
            profile: {
              create: {
                firstName: googleUser.firstName,
                searchName: `${googleUser.firstName} ${googleUser.lastName}`.normalize('NFKC').trim().toLowerCase(),
                lastName: googleUser.lastName,
                avatarUrl: googleUser.avatarUrl,
              },
            },
            gameStats: {
              create: {
                level: 1,
                streak: 0,
                coins: 0,
              },
            },
            progress: {
              create: {
                totalXp: BigInt(0),
                level: 1,
              },
            },
          },
          include: {
            profile: true,
            gameStats: true,
            progress: true,
          },
        });
      }
    }

    // Issue tokens using the configured expiration policy.
    const { rawToken, tokenHash, expiresAt } = createRefreshTokenData();

    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      },
    });

    const accessToken = signAccessToken({
      userId: user.id,
      email: user.email,
    });

    return {
      accessToken,
      refreshToken: rawToken,
      isRegistrationComplete: user.isRegistrationComplete,
      user: {
        id: user.id,
        email: user.email,
        isRegistrationComplete: user.isRegistrationComplete,
      },
      profile: user.profile
        ? {
            firstName: user.profile.firstName,
            lastName: user.profile.lastName,
            dob: user.profile.dob,
            gender: user.profile.gender,
            religion: user.profile.religion,
            country: user.profile.country,
            avatarUrl: user.profile.avatarUrl,
          }
        : null,
      stats: user.gameStats
        ? {
            level: user.gameStats.level,
            streak: user.gameStats.streak,
            coins: user.gameStats.coins,
          }
        : {
            level: 1,
            streak: 0,
            coins: 0,
          },
    };
  }

  /**
   * Completes onboarding by saving all mandatory demographic fields.
   */
  async completeOnboarding(userId: string, data: OnboardingInput) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });

    if (!user) {
      throw new Error('User not found');
    }

    const dobDate = new Date(data.dob);

    // Upsert profile
    const profile = await prisma.profile.upsert({
      where: { userId },
      update: {
        firstName: data.firstName,
        searchName: `${data.firstName} ${data.lastName}`.normalize('NFKC').trim().toLowerCase(),
        lastName: data.lastName,
        dob: dobDate,
        gender: data.gender,
        religion: data.religion,
        country: data.country,
        avatarUrl: data.avatarUrl || user.profile?.avatarUrl,
      },
      create: {
        userId,
        firstName: data.firstName,
        searchName: `${data.firstName} ${data.lastName}`.normalize('NFKC').trim().toLowerCase(),
        lastName: data.lastName,
        dob: dobDate,
        gender: data.gender,
        religion: data.religion,
        country: data.country,
        avatarUrl: data.avatarUrl || '',
      },
    });

    // Mark registration complete
    await prisma.user.update({
      where: { id: userId },
      data: { isRegistrationComplete: true },
    });

    // Ensure game stats are initialized
    const stats = await prisma.gameStats.upsert({
      where: { userId },
      update: {},
      create: {
        userId,
        level: 1,
        streak: 0,
        coins: 0,
      },
    });

    // Ensure user progression is initialized
    await prisma.userProgress.upsert({
      where: { userId },
      update: {},
      create: {
        userId,
        totalXp: BigInt(0),
        level: 1,
      },
    });

    return {
      isRegistrationComplete: true,
      profile: {
        firstName: profile.firstName,
        lastName: profile.lastName,
        dob: profile.dob,
        gender: profile.gender,
        religion: profile.religion,
        country: profile.country,
        avatarUrl: profile.avatarUrl,
      },
      stats: {
        level: stats.level,
        streak: stats.streak,
        coins: stats.coins,
      },
    };
  }

  /**
   * Refreshes access token and rotates the 7-day refresh token.
   */
  async refreshSession(rawRefreshToken: string) {
    const hashed = hashToken(rawRefreshToken);
    return prisma.$transaction(async tx => {
      const tokenRecord = await tx.refreshToken.findUnique({where:{tokenHash:hashed},include:{user:true}});
      if (!tokenRecord || tokenRecord.expiresAt.getTime() <= Date.now()) throw new PublicError('Invalid or expired refresh token','INVALID_REFRESH_TOKEN',401);
      const consumed = await tx.refreshToken.deleteMany({where:{id:tokenRecord.id,tokenHash:hashed,expiresAt:{gt:new Date()}}});
      if (consumed.count !== 1) throw new PublicError('Invalid or expired refresh token','INVALID_REFRESH_TOKEN',401);
      const replacement = createRefreshTokenData();
      await tx.refreshToken.create({data:{userId:tokenRecord.userId,tokenHash:replacement.tokenHash,expiresAt:replacement.expiresAt}});
      return {accessToken:signAccessToken({userId:tokenRecord.user.id,email:tokenRecord.user.email}),refreshToken:replacement.rawToken};
    });
  }

  /**
   * Logs out user by revoking refresh token.
   */
  async logout(rawRefreshToken: string) {
    if (!rawRefreshToken) return;
    const hashed = hashToken(rawRefreshToken);
    await prisma.refreshToken.deleteMany({
      where: { tokenHash: hashed },
    });
  }
}
