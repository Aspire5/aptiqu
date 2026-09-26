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
        // Link googleId to existing user
        user = await prisma.user.update({
          where: { id: user.id },
          data: { googleId: googleUser.googleId },
          include: { profile: true, gameStats: true },
        });
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
                lastName: googleUser.lastName,
                avatarUrl: googleUser.avatarUrl,
              },
            },
            gameStats: {
              create: {
                level: 1,
                // NOTE: streak is hardcoded to 0 for now as requested. Daily streak calculation will be implemented later.
                streak: 0,
                // NOTE: coins is hardcoded to 0 for now as requested. Coin rewards/earnings will be implemented later.
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

    // 2. Generate 7-day Refresh Token and 15-minute Access Token
    const { rawToken, tokenHash, expiresAt } = createRefreshTokenData(7);

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
            // Streak hardcoded to 0 for now as requested
            streak: `${user.gameStats.streak}d`,
            // Coins hardcoded to 0 for now as requested
            coins: user.gameStats.coins,
          }
        : {
            level: 1,
            streak: '0d',
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
        // NOTE: streak is hardcoded to 0 for now as requested
        streak: 0,
        // NOTE: coins is hardcoded to 0 for now as requested
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
        // Streak and coins returned with proper hardcoded defaults
        streak: `${stats.streak}d`,
        coins: stats.coins,
      },
    };
  }

  /**
   * Refreshes access token and rotates the 7-day refresh token.
   */
  async refreshSession(rawRefreshToken: string) {
    const hashed = hashToken(rawRefreshToken);

    const tokenRecord = await prisma.refreshToken.findUnique({
      where: { tokenHash: hashed },
      include: { user: true },
    });

    if (!tokenRecord) {
      throw new Error('Invalid refresh token');
    }

    if (tokenRecord.expiresAt < new Date()) {
      await prisma.refreshToken.delete({ where: { id: tokenRecord.id } });
      throw new Error('Refresh token expired. Please log in again.');
    }

    // Rotate refresh token: delete old, create new 7-day token
    await prisma.refreshToken.delete({ where: { id: tokenRecord.id } });

    const { rawToken: newRawToken, tokenHash: newTokenHash, expiresAt } =
      createRefreshTokenData(7);

    await prisma.refreshToken.create({
      data: {
        userId: tokenRecord.userId,
        tokenHash: newTokenHash,
        expiresAt,
      },
    });

    const newAccessToken = signAccessToken({
      userId: tokenRecord.user.id,
      email: tokenRecord.user.email,
    });

    return {
      accessToken: newAccessToken,
      refreshToken: newRawToken,
    };
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
