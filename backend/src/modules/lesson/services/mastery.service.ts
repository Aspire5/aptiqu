import { prisma } from '../../../config/prisma';

export class MasteryService {
  private static instance: MasteryService;

  public static getInstance(): MasteryService {
    if (!MasteryService.instance) {
      MasteryService.instance = new MasteryService();
    }
    return MasteryService.instance;
  }

  public async recordAttempt(userId: string, conceptId: string, isCorrect: boolean): Promise<void> {
    const existing = await prisma.studentConceptMastery.findUnique({
      where: {
        userId_conceptId: {
          userId,
          conceptId,
        },
      },
    });

    const now = new Date();

    if (!existing) {
      await prisma.studentConceptMastery.create({
        data: {
          userId,
          conceptId,
          totalAttempts: 1,
          correctAttempts: isCorrect ? 1 : 0,
          masteryScore: isCorrect ? 1.0 : 0.0,
          lastAttemptAt: now,
          lastCorrectAt: isCorrect ? now : null,
        },
      });
      return;
    }

    const totalAttempts = existing.totalAttempts + 1;
    const correctAttempts = existing.correctAttempts + (isCorrect ? 1 : 0);
    // Simple rolling accuracy for MVP
    const masteryScore = parseFloat((correctAttempts / totalAttempts).toFixed(2));

    await prisma.studentConceptMastery.update({
      where: { id: existing.id },
      data: {
        totalAttempts,
        correctAttempts,
        masteryScore,
        lastAttemptAt: now,
        lastCorrectAt: isCorrect ? now : existing.lastCorrectAt,
      },
    });
  }
}

export const masteryService = MasteryService.getInstance();
