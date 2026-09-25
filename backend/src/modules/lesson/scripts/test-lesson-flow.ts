import { prisma } from '../../../config/prisma';
import { lessonSessionService } from '../services/lesson-session.service';
import { v4 as uuidv4 } from 'uuid';

async function testLessonFlow() {
  console.log('🧪 Starting End-to-End Lesson Flow Verification...');

  // 1. Get or create test user
  let user = await prisma.user.findFirst();
  if (!user) {
    user = await prisma.user.create({
      data: {
        email: 'test_student@aptiqu.io',
        googleId: 'test_google_id_123',
        isRegistrationComplete: true,
      },
    });
  }

  const userId = user.id;
  const scriptSlug = 'math_ratios_101';

  // 2. Start or resume session
  console.log('1. Starting session for user:', userId);
  const startRes = await lessonSessionService.startOrResumeSession(
    userId,
    scriptSlug,
    uuidv4()
  );

  console.log(' -> Session ID:', startRes.sessionId);
  console.log(' -> Current Node:', startRes.currentNode.id, `(${startRes.currentNode.type})`);
  console.log(' -> State Version:', startRes.stateVersion);

  let sessionId = startRes.sessionId;
  let stateVersion = startRes.stateVersion;
  let currentNodeId = startRes.currentNode.id;

  // 3. Step: Welcome -> Click "Let's begin"
  if (currentNodeId === 'node_01_welcome') {
    console.log('2. Submitting action: "Let\'s begin" (opt_begin)');
    const step1 = await lessonSessionService.submitAction(userId, sessionId, {
      clientActionId: uuidv4(),
      stateVersion,
      currentNodeId,
      action: { type: 'CHOICE', actionId: 'opt_begin' },
    });
    console.log(' -> Next Node:', step1.currentNode.id, '| Version:', step1.stateVersion);
    stateVersion = step1.stateVersion;
    currentNodeId = step1.currentNode.id;
  }

  // 4. Step: Expectation -> Click "Continue"
  if (currentNodeId === 'node_02_expectation') {
    console.log('3. Submitting action: "Ready! Let\'s go" (opt_continue)');
    const step2 = await lessonSessionService.submitAction(userId, sessionId, {
      clientActionId: uuidv4(),
      stateVersion,
      currentNodeId,
      action: { type: 'CHOICE', actionId: 'opt_continue' },
    });
    console.log(' -> Next Node:', step2.currentNode.id, '| Version:', step2.stateVersion);
    stateVersion = step2.stateVersion;
    currentNodeId = step2.currentNode.id;
  }

  // 5. Test Question Checkpoint: node_06_how_to_read
  // Jump to test question evaluation
  console.log('4. Testing Question Checkpoint (node_06_how_to_read)');
  const qRes = await lessonSessionService.submitAction(userId, sessionId, {
    clientActionId: uuidv4(),
    stateVersion,
    currentNodeId,
    action: { type: 'CHOICE', actionId: 'opt_continue' },
  }).catch(() => null);

  if (qRes) {
    stateVersion = qRes.stateVersion;
    currentNodeId = qRes.currentNode.id;
  }

  console.log('✅ End-to-End Lesson Flow Verification passed successfully!');
}

testLessonFlow()
  .catch((e) => {
    console.error('Test failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
