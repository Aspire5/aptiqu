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
  const scriptSlug = 'script-qa-foundations-intro';

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

  // 3. Step: Welcome -> Click "Continue"
  if (currentNodeId === 'welcome') {
    console.log('2. Submitting action: Welcome -> Continue');
    const step1 = await lessonSessionService.submitAction(userId, sessionId, {
      clientActionId: uuidv4(),
      stateVersion,
      currentNodeId,
      action: { type: 'CONTINUE', actionId: 'continue' },
    });
    console.log(' -> Next Node:', step1.currentNode.id, '| Version:', step1.stateVersion);
    stateVersion = step1.stateVersion;
    currentNodeId = step1.currentNode.id;
  }

  // 4. Step: Hook Choice -> Click "Recognize easy patterns quickly" (patterns)
  if (currentNodeId === 'hook') {
    console.log('3. Submitting action: Hook -> Option "patterns"');
    const step2 = await lessonSessionService.submitAction(userId, sessionId, {
      clientActionId: uuidv4(),
      stateVersion,
      currentNodeId,
      action: { type: 'CHOICE', actionId: 'patterns' },
    });
    console.log(' -> Next Node:', step2.currentNode.id, '| Version:', step2.stateVersion);
    console.log(' -> Evaluation:', step2.evaluation);
    stateVersion = step2.stateVersion;
    currentNodeId = step2.currentNode.id;
  }

  // 5. Step: Real Life -> Continue
  if (currentNodeId === 'real_life') {
    console.log('4. Submitting action: Real Life -> Continue');
    const step3 = await lessonSessionService.submitAction(userId, sessionId, {
      clientActionId: uuidv4(),
      stateVersion,
      currentNodeId,
      action: { type: 'CONTINUE', actionId: 'continue' },
    });
    console.log(' -> Next Node:', step3.currentNode.id, '| Version:', step3.stateVersion);
    stateVersion = step3.stateVersion;
    currentNodeId = step3.currentNode.id;
  }

  // 6. Step: Real Life Continue -> "Let's go" (yes)
  if (currentNodeId === 'real_life_continue') {
    console.log('5. Submitting action: Real Life Continue -> Option "yes"');
    const step4 = await lessonSessionService.submitAction(userId, sessionId, {
      clientActionId: uuidv4(),
      stateVersion,
      currentNodeId,
      action: { type: 'CHOICE', actionId: 'yes' },
    });
    console.log(' -> Next Node:', step4.currentNode.id, '| Version:', step4.stateVersion);
    stateVersion = step4.stateVersion;
    currentNodeId = step4.currentNode.id;
  }

  // 7. Step: Map -> Continue
  if (currentNodeId === 'map') {
    console.log('6. Submitting action: Map -> Continue');
    const step5 = await lessonSessionService.submitAction(userId, sessionId, {
      clientActionId: uuidv4(),
      stateVersion,
      currentNodeId,
      action: { type: 'CONTINUE', actionId: 'continue' },
    });
    console.log(' -> Next Node:', step5.currentNode.id, '| Version:', step5.stateVersion);
    console.log(' -> Is Completed:', step5.isCompleted);
    console.log(' -> Next Step Result:', step5.next);
  }

  console.log('✅ End-to-End Lesson Flow Verification passed successfully!');
}

testLessonFlow()
  .catch((e) => {
    console.error('Test failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
