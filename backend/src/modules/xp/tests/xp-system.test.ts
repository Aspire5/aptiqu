import { prisma } from '../../../config/prisma';
import { XpPolicy } from '../xp.policy';
import { xpService } from '../xp.service';
import { v4 as uuidv4 } from 'uuid';

async function runXpTests() {
  console.log('====================================================');
  console.log('🧪 RUNNING COMPLETE XP & LEVEL SYSTEM TEST SUITE');
  console.log('====================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    if (condition) {
      console.log(`✅ [PASS] ${testName}`);
      passed++;
    } else {
      console.error(`❌ [FAIL] ${testName}${detail ? ` - ${detail}` : ''}`);
      failed++;
    }
  }

  // ---------------------------------------------------------------------------
  // TEST GROUP 1: MATHEMATICAL LEVEL CALCULATION BOUNDARIES
  // ---------------------------------------------------------------------------
  console.log('--- TEST GROUP 1: LEVEL CALCULATION BOUNDARIES ---');
  assert(XpPolicy.getLevelFromXp(0) === 1, 'Level calculation: 0 XP -> Level 1');
  assert(XpPolicy.getLevelFromXp(19) === 1, 'Level calculation: 19 XP -> Level 1');
  assert(XpPolicy.getLevelFromXp(20) === 2, 'Level calculation: 20 XP -> Level 2');
  assert(XpPolicy.getLevelFromXp(59) === 2, 'Level calculation: 59 XP -> Level 2');
  assert(XpPolicy.getLevelFromXp(60) === 3, 'Level calculation: 60 XP -> Level 3');
  assert(XpPolicy.getLevelFromXp(119) === 3, 'Level calculation: 119 XP -> Level 3');
  assert(XpPolicy.getLevelFromXp(120) === 4, 'Level calculation: 120 XP -> Level 4');
  assert(XpPolicy.getLevelFromXp(200) === 5, 'Level calculation: 200 XP -> Level 5');
  assert(XpPolicy.getLevelFromXp(900) === 10, 'Level calculation: 900 XP -> Level 10');
  assert(XpPolicy.getLevelFromXp(3800) === 20, 'Level calculation: 3800 XP -> Level 20');
  assert(XpPolicy.getLevelFromXp(99000) === 100, 'Level calculation: 99000 XP -> Level 100');

  // Boundary progress calculations
  const p0 = XpPolicy.getLevelProgress(0);
  assert(
    p0.currentLevel === 1 &&
      p0.currentLevelStartXp === 0 &&
      p0.nextLevel === 2 &&
      p0.nextLevelStartXp === 20 &&
      p0.xpIntoCurrentLevel === 0 &&
      p0.xpRequiredForNextLevel === 20 &&
      p0.progress === 0.0,
    'Progress at 0 XP has valid start, next, and 0% progress'
  );

  const p10 = XpPolicy.getLevelProgress(10);
  assert(
    p10.currentLevel === 1 &&
      p10.xpIntoCurrentLevel === 10 &&
      p10.xpRemainingToNextLevel === 10 &&
      p10.progress === 0.5,
    'Progress at 10 XP has 50% progress'
  );

  // ---------------------------------------------------------------------------
  // TEST GROUP 2: QUESTION XP MATRIX
  // ---------------------------------------------------------------------------
  console.log('\n--- TEST GROUP 2: QUESTION XP FORMULA MATRIX ---');
  assert(
    XpPolicy.calculateQuestionXp('PRACTICE', 'EASY') === 10,
    'Question XP: Practice + Easy = 10'
  );
  assert(
    XpPolicy.calculateQuestionXp('PRACTICE', 'MEDIUM') === 15,
    'Question XP: Practice + Medium = 15'
  );
  assert(
    XpPolicy.calculateQuestionXp('PRACTICE', 'HARD') === 20,
    'Question XP: Practice + Hard = 20'
  );

  assert(
    XpPolicy.calculateQuestionXp('UNRANKED', 'EASY') === 10,
    'Question XP: Unranked + Easy = 10'
  );
  assert(
    XpPolicy.calculateQuestionXp('UNRANKED', 'MEDIUM') === 15,
    'Question XP: Unranked + Medium = 15'
  );
  assert(
    XpPolicy.calculateQuestionXp('UNRANKED', 'HARD') === 20,
    'Question XP: Unranked + Hard = 20'
  );

  assert(
    XpPolicy.calculateQuestionXp('RANKED', 'EASY') === 15,
    'Question XP: Ranked + Easy = 15'
  );
  assert(
    XpPolicy.calculateQuestionXp('RANKED', 'MEDIUM') === 20,
    'Question XP: Ranked + Medium = 20'
  );
  assert(
    XpPolicy.calculateQuestionXp('RANKED', 'HARD') === 25,
    'Question XP: Ranked + Hard = 25'
  );

  // Case insensitivity & numeric difficulty support
  assert(
    XpPolicy.calculateQuestionXp('practice', 1) === 10,
    'Question XP: lower-case practice + numeric 1 = 10'
  );
  assert(
    XpPolicy.calculateQuestionXp('ranked', 3) === 25,
    'Question XP: lower-case ranked + numeric 3 = 25'
  );

  // ---------------------------------------------------------------------------
  // TEST GROUP 3: DATABASE & TRANSACTIONAL XP AWARDS
  // ---------------------------------------------------------------------------
  console.log('\n--- TEST GROUP 3: DATABASE AWARDS & IDEMPOTENCY ---');

  const testUser = await prisma.user.create({
    data: {
      email: `xp_tester_${Date.now()}@aptiqu.io`,
      googleId: `mock_g_xp_${Date.now()}`,
      isRegistrationComplete: true,
      progress: {
        create: {
          totalXp: BigInt(0),
          level: 1,
        },
      },
    },
  });

  try {
    // 3.1 Initial user state
    const initialProg = await xpService.getUserProgress(testUser.id);
    assert(
      initialProg.total === 0 && initialProg.level === 1,
      'User starts at Level 1 with 0 XP'
    );

    // 3.2 Question Completion Award
    const qAttemptId = uuidv4();
    const qAward1 = await xpService.awardQuestionXp({
      userId: testUser.id,
      clientActionId: qAttemptId,
      questionType: 'PRACTICE',
      difficulty: 'EASY',
      questionId: 'q-test-01',
    });

    assert(
      qAward1.awarded === true &&
        qAward1.xp.earned === 10 &&
        qAward1.xp.total === 10 &&
        qAward1.xp.level === 1 &&
        qAward1.levelUp.occurred === false,
      'Question XP award succeeds (+10 XP, Total: 10, Level: 1)'
    );

    // 3.3 Question Idempotency: Duplicate call with same attempt ID
    const qAwardDuplicate = await xpService.awardQuestionXp({
      userId: testUser.id,
      clientActionId: qAttemptId,
      questionType: 'PRACTICE',
      difficulty: 'EASY',
      questionId: 'q-test-01',
    });

    assert(
      qAwardDuplicate.awarded === false &&
        qAwardDuplicate.xp.earned === 0 &&
        qAwardDuplicate.xp.total === 10,
      'Duplicate question attempt yields 0 additional XP'
    );

    // 3.4 Subtopic Script Completion (+20 XP)
    const scriptId = uuidv4();
    const versionId = uuidv4();
    const sessionId = uuidv4();

    const subtopicAward = await xpService.awardSubtopicCompletionXp({
      userId: testUser.id,
      roadmapId: 'general-aptitude',
      roadmapStepId: 'ga-qa-01',
      topicId: 'qa-foundations',
      subtopicId: 'qaf-basic-operations',
      scriptId,
      scriptVersionId: versionId,
      sessionId,
    });

    // 10 XP + 20 XP = 30 XP -> crossed Level 2 (20 XP threshold)!
    assert(
      subtopicAward.awarded === true &&
        subtopicAward.xp.earned === 20 &&
        subtopicAward.xp.total === 30 &&
        subtopicAward.xp.level === 2 &&
        subtopicAward.levelUp.occurred === true &&
        subtopicAward.levelUp.fromLevel === 1 &&
        subtopicAward.levelUp.toLevel === 2 &&
        subtopicAward.levelUp.levelsGained === 1,
      'Subtopic script completion awards +20 XP and detects level-up (Level 1 -> 2)'
    );

    // 3.5 Subtopic Duplicate Idempotency
    const subtopicDuplicate = await xpService.awardSubtopicCompletionXp({
      userId: testUser.id,
      roadmapId: 'general-aptitude',
      roadmapStepId: 'ga-qa-01',
      topicId: 'qa-foundations',
      subtopicId: 'qaf-basic-operations',
      scriptId,
      scriptVersionId: versionId,
      sessionId,
    });

    assert(
      subtopicDuplicate.awarded === false &&
        subtopicDuplicate.xp.earned === 0 &&
        subtopicDuplicate.xp.total === 30,
      'Duplicate subtopic completion awards 0 XP'
    );

    // 3.6 Topic Completion Award
    // 7 required subtopics -> 7 * 10 = 70 XP
    const topicAward = await xpService.awardTopicCompletionXp({
      userId: testUser.id,
      roadmapId: 'general-aptitude',
      topicId: 'qa-foundations',
      requiredSubtopicCount: 7,
    });

    // 30 XP + 70 XP = 100 XP -> Level 3 (threshold is 60 XP, next is 120 XP)
    assert(
      topicAward.awarded === true &&
        topicAward.xp.earned === 70 &&
        topicAward.xp.total === 100 &&
        topicAward.xp.level === 3 &&
        topicAward.levelUp.occurred === true &&
        topicAward.levelUp.fromLevel === 2 &&
        topicAward.levelUp.toLevel === 3,
      'Topic completion with 7 required subtopics awards +70 XP and reaches Level 3'
    );

    // 3.7 Topic Completion Duplicate Idempotency
    const topicDuplicate = await xpService.awardTopicCompletionXp({
      userId: testUser.id,
      roadmapId: 'general-aptitude',
      topicId: 'qa-foundations',
      requiredSubtopicCount: 7,
    });

    assert(
      topicDuplicate.awarded === false &&
        topicDuplicate.xp.earned === 0 &&
        topicDuplicate.xp.total === 100,
      'Duplicate topic completion awards 0 XP'
    );

    // 3.8 Topic Completion with 5 required subtopics -> 50 XP
    const userB = await prisma.user.create({
      data: {
        email: `topic_5_${Date.now()}@aptiqu.io`,
        googleId: `mock_g_5_${Date.now()}`,
        isRegistrationComplete: true,
      },
    });

    const topic5Award = await xpService.awardTopicCompletionXp({
      userId: userB.id,
      roadmapId: 'general-aptitude',
      topicId: 'qa-another-topic',
      requiredSubtopicCount: 5,
    });

    assert(
      topic5Award.awarded === true &&
        topic5Award.xp.earned === 50 &&
        topic5Award.xp.total === 50,
      'Topic completion with 5 required subtopics awards +50 XP'
    );

    // -------------------------------------------------------------------------
    // TEST GROUP 4: MULTI-LEVEL LEAP DETECTION
    // -------------------------------------------------------------------------
    console.log('\n--- TEST GROUP 4: MULTI-LEVEL LEAP DETECTION ---');

    // Starting at 100 XP (Level 3), award +150 XP -> 250 XP
    // Thresholds:
    // Level 3 = 60 XP
    // Level 4 = 120 XP
    // Level 5 = 200 XP
    // Level 6 = 300 XP
    // 250 XP is Level 5 -> Crossed Level 4 AND Level 5 (+2 levels gained)!
    const leapAward = await xpService.awardXp({
      userId: testUser.id,
      amount: 150,
      sourceType: 'TOPIC_COMPLETION',
      idempotencyKey: `leap_test_${Date.now()}`,
      description: 'Multi-level leap test',
    });

    assert(
      leapAward.awarded === true &&
        leapAward.xp.total === 250 &&
        leapAward.xp.level === 5 &&
        leapAward.levelUp.occurred === true &&
        leapAward.levelUp.fromLevel === 3 &&
        leapAward.levelUp.toLevel === 5 &&
        leapAward.levelUp.levelsGained === 2,
      'Large XP award detects multiple crossed levels (Level 3 -> 5, levelsGained: 2)'
    );

    // -------------------------------------------------------------------------
    // TEST GROUP 5: CONCURRENCY PROTECTION
    // -------------------------------------------------------------------------
    console.log('\n--- TEST GROUP 5: CONCURRENCY PROTECTION ---');

    const concurrentKey = `concurrent_action_${Date.now()}`;
    // Fire 2 simultaneous identical awards
    const [res1, res2] = await Promise.all([
      xpService.awardXp({
        userId: testUser.id,
        amount: 20,
        sourceType: 'QUESTION_COMPLETION',
        idempotencyKey: concurrentKey,
      }),
      xpService.awardXp({
        userId: testUser.id,
        amount: 20,
        sourceType: 'QUESTION_COMPLETION',
        idempotencyKey: concurrentKey,
      }),
    ]);

    const oneAwarded =
      (res1.awarded && !res2.awarded) || (!res1.awarded && res2.awarded);
    const sumEarned = res1.xp.earned + res2.xp.earned;

    assert(
      oneAwarded && sumEarned === 20,
      'Two simultaneous identical award attempts yield exactly ONE award of +20 XP'
    );

    // Verify ledger record count
    const eventCount = await prisma.xpEvent.count({
      where: { idempotencyKey: concurrentKey },
    });
    assert(
      eventCount === 1,
      'Exactly 1 immutable XP event is persisted for the concurrent action'
    );

    // Clean up test data
    await prisma.xpEvent.deleteMany({
      where: { userId: { in: [testUser.id, userB.id] } },
    });
    await prisma.userProgress.deleteMany({
      where: { userId: { in: [testUser.id, userB.id] } },
    });
    await prisma.gameStats.deleteMany({
      where: { userId: { in: [testUser.id, userB.id] } },
    });
    await prisma.user.deleteMany({
      where: { id: { in: [testUser.id, userB.id] } },
    });
  } catch (err: any) {
    console.error('Test error:', err);
    failed++;
  }

  console.log('\n====================================================');
  console.log(`TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('====================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  runXpTests()
    .catch((err) => {
      console.error(err);
      process.exit(1);
    })
    .finally(() => prisma.$disconnect());
}
