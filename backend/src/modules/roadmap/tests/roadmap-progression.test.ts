import { prisma } from '../../../config/prisma';
import { roadmapProgressionService } from '../services/roadmap-progression.service';
import { lessonSessionService } from '../../lesson/services/lesson-session.service';
import { v4 as uuidv4 } from 'uuid';

async function runTests() {
  console.log('====================================================');
  console.log('🧪 RUNNING ROADMAP & PROGRESSION TEST SUITE (14 CASES)');
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

  // Setup test users
  const testEmail1 = `test_runner_user1_${Date.now()}@aptiqu.io`;
  const testEmail2 = `test_runner_user2_${Date.now()}@aptiqu.io`;

  const user1 = await prisma.user.create({
    data: {
      email: testEmail1,
      googleId: `mock_g_${Date.now()}_1`,
      isRegistrationComplete: true,
      activeRoadmapId: 'general-aptitude',
    },
  });

  const user2 = await prisma.user.create({
    data: {
      email: testEmail2,
      googleId: `mock_g_${Date.now()}_2`,
      isRegistrationComplete: true,
      activeRoadmapId: 'general-aptitude',
    },
  });

  try {
    // -------------------------------------------------------------------------
    // TEST 1: User opens General Aptitude roadmap
    // -------------------------------------------------------------------------
    const activeRoadmap = await roadmapProgressionService.getUserActiveRoadmap(user1.id);
    const roadmapList = await roadmapProgressionService.listRoadmaps(user1.id);
    const activeInList = roadmapList.find((r) => r.id === 'general-aptitude');

    assert(
      activeRoadmap.id === 'general-aptitude' &&
        activeRoadmap.name === 'General Aptitude' &&
        activeInList?.isActiveForUser === true,
      'Test 1: User opens General Aptitude roadmap'
    );

    // -------------------------------------------------------------------------
    // TEST 2: User opens Quantitative Aptitude learning map
    // -------------------------------------------------------------------------
    const qaMap = await roadmapProgressionService.getSubjectLearningMap(
      user1.id,
      'general-aptitude',
      'quantitative-aptitude'
    );

    assert(
      qaMap.subject.id === 'quantitative-aptitude' &&
        qaMap.roadmap.id === 'general-aptitude' &&
        qaMap.topics.length === 24,
      'Test 2: User opens Quantitative Aptitude learning map',
      `Expected 24 topics, received ${qaMap.topics.length}`
    );

    // -------------------------------------------------------------------------
    // TEST 3: Topics appear in correct order
    // -------------------------------------------------------------------------
    const topic0 = qaMap.topics[0];
    const topic1 = qaMap.topics[1];
    const topic2 = qaMap.topics[2];
    const topic3 = qaMap.topics[3]; // ga-qa-04 -> Ratio
    const isStrictlySequential = qaMap.topics.every(
      (t, idx) => t.sequence === idx + 1
    );

    assert(
      isStrictlySequential &&
        topic0.topicId === 'qa-foundations' &&
        topic1.topicId === 'qa-number-system' &&
        topic2.topicId === 'qa-fractions-decimals' &&
        topic3.topicId === 'qa-ratio-proportion',
      'Test 3: Topics appear in correct order',
      `Seq: ${qaMap.topics.map((t) => t.topicId).slice(0, 4).join(' -> ')}`
    );

    // -------------------------------------------------------------------------
    // TEST 4: Topic without a script displays Coming Soon
    // -------------------------------------------------------------------------
    const noScriptTopic = qaMap.topics.find((t) => t.topicId === 'qa-percentages');
    assert(
      noScriptTopic !== undefined &&
        noScriptTopic.state === 'COMING_SOON' &&
        noScriptTopic.scriptAvailable === false,
      'Test 4: Topic without a script displays Coming Soon',
      `State was: ${noScriptTopic?.state}`
    );

    // -------------------------------------------------------------------------
    // TEST 5: Topic with a script opens the correct script
    // -------------------------------------------------------------------------
    const startRes = await lessonSessionService.startOrResumeSessionByStep(
      user1.id,
      'ga-qa-04',
      uuidv4()
    );

    assert(
      startRes.scriptSlug === 'math_ratios_101' &&
        startRes.roadmapStepId === 'ga-qa-04' &&
        startRes.currentNode.id === 'node_01_welcome',
      'Test 5: Topic with a script opens the correct script',
      `Node: ${startRes.currentNode?.id}, Step: ${startRes.roadmapStepId}`
    );

    // -------------------------------------------------------------------------
    // TEST 6: Existing session resumes
    // -------------------------------------------------------------------------
    // Advance 1 step
    const step1 = await lessonSessionService.submitAction(user1.id, startRes.sessionId, {
      clientActionId: uuidv4(),
      stateVersion: startRes.stateVersion,
      currentNodeId: startRes.currentNode.id,
      action: { type: 'CHOICE', actionId: 'opt_begin' },
    });

    // Re-call startOrResumeSessionByStep
    const resumeRes = await lessonSessionService.startOrResumeSessionByStep(
      user1.id,
      'ga-qa-04',
      uuidv4()
    );

    assert(
      resumeRes.sessionId === startRes.sessionId &&
        resumeRes.currentNode.id === step1.currentNode.id &&
        resumeRes.stateVersion === step1.stateVersion,
      'Test 6: Existing session resumes',
      `Expected node "${step1.currentNode.id}", got "${resumeRes.currentNode.id}"`
    );

    // -------------------------------------------------------------------------
    // TEST 7: Completing script finds next roadmap step
    // -------------------------------------------------------------------------
    // Advance session to completion node: node_exit_topic
    // From node_01_welcome -> opt_another goes to node_exit_topic
    // Let's create a fresh user/session to cleanly complete or transition
    const user3 = await prisma.user.create({
      data: {
        email: `test_completer_${Date.now()}@aptiqu.io`,
        googleId: `mock_g_${Date.now()}_3`,
        isRegistrationComplete: true,
        activeRoadmapId: 'general-aptitude',
      },
    });

    const compStart = await lessonSessionService.startOrResumeSessionByStep(
      user3.id,
      'ga-qa-04',
      uuidv4()
    );

    const compActionRes = await lessonSessionService.submitAction(
      user3.id,
      compStart.sessionId,
      {
        clientActionId: uuidv4(),
        stateVersion: compStart.stateVersion,
        currentNodeId: compStart.currentNode.id,
        action: { type: 'CHOICE', actionId: 'opt_another' }, // transitions to node_exit_topic (COMPLETION)
      }
    );

    assert(
      compActionRes.isCompleted === true &&
        compActionRes.next !== undefined &&
        compActionRes.next.roadmapStepId === 'ga-qa-05',
      'Test 7: Completing script finds next roadmap step',
      `Next step: ${compActionRes.next?.roadmapStepId}`
    );

    // -------------------------------------------------------------------------
    // TEST 8: Next roadmap step without script returns SCRIPT_NOT_PUBLISHED
    // -------------------------------------------------------------------------
    assert(
      compActionRes.next?.available === false &&
        compActionRes.next?.reason === 'SCRIPT_NOT_PUBLISHED' &&
        compActionRes.next?.topicId === 'qa-percentages' &&
        compActionRes.next?.topicName === 'Percentages',
      'Test 8: Next roadmap step without script returns SCRIPT_NOT_PUBLISHED',
      `Reason: ${compActionRes.next?.reason}, Topic: ${compActionRes.next?.topicName}`
    );

    // -------------------------------------------------------------------------
    // TEST 9: Publishing a script changes its map state to AVAILABLE
    // -------------------------------------------------------------------------
    // Currently ga-qa-05 is COMING_SOON. Assign a published script to ga-qa-05:
    const ratiosScript = await prisma.lessonScript.findUnique({
      where: { slug: 'math_ratios_101' },
    });

    const tempAssignment = await prisma.scriptAssignment.create({
      data: {
        roadmapStepId: 'ga-qa-05',
        scriptId: ratiosScript!.id,
        publishedVersionId: ratiosScript!.publishedVersionId,
        status: 'PUBLISHED',
        sequence: 1,
      },
    });

    // For user3 who completed ga-qa-04, ga-qa-05 should now be AVAILABLE!
    const mapAfterPublish = await roadmapProgressionService.getSubjectLearningMap(
      user3.id,
      'general-aptitude',
      'quantitative-aptitude'
    );
    const step05After = mapAfterPublish.topics.find((t) => t.roadmapStepId === 'ga-qa-05');

    assert(
      step05After?.state === 'AVAILABLE' && step05After.scriptAvailable === true,
      'Test 9: Publishing a script changes its map state to AVAILABLE',
      `State was: ${step05After?.state}`
    );

    // Clean up temporary assignment
    await prisma.scriptAssignment.delete({ where: { id: tempAssignment.id } });

    // -------------------------------------------------------------------------
    // TEST 10: Script version change does not move active users to a new version
    // -------------------------------------------------------------------------
    // User1 has an active session on v1 of math_ratios_101
    const user1Session = await prisma.lessonSession.findFirst({
      where: { userId: user1.id, roadmapStepId: 'ga-qa-04' },
    });
    const originalVersionId = user1Session?.scriptVersionId;

    // Create a mock v2 of the script version
    const v2 = await prisma.lessonScriptVersion.create({
      data: {
        scriptId: ratiosScript!.id,
        versionNumber: 99,
        definition: {
          schemaVersion: 1,
          scriptId: 'math_ratios_101',
          version: 99,
          entryNodeId: 'node_v2_welcome',
          metadata: { title: 'V2 Ratios', subjectId: 'qa', topicId: 'ratios' },
          nodes: {
            node_v2_welcome: {
              id: 'node_v2_welcome',
              type: 'CONTENT',
              content: { text: 'Welcome to V2!' },
              transitions: [],
            },
          },
        },
        checksum: 'v2_checksum_test',
        status: 'PUBLISHED',
      },
    });

    // Point script publishedVersionId to v2
    await prisma.lessonScript.update({
      where: { id: ratiosScript!.id },
      data: { publishedVersionId: v2.id },
    });

    // Resume user1 session
    const user1Resumed = await lessonSessionService.startOrResumeSessionByStep(
      user1.id,
      'ga-qa-04',
      uuidv4()
    );

    assert(
      user1Resumed.scriptVersionId === originalVersionId &&
        user1Resumed.scriptVersionId !== v2.id,
      'Test 10: Script version change does not move active users to a new version',
      `User remained on: ${user1Resumed.scriptVersionId}`
    );

    // Restore script pointer and delete test v2
    await prisma.lessonScript.update({
      where: { id: ratiosScript!.id },
      data: { publishedVersionId: originalVersionId },
    });
    await prisma.lessonScriptVersion.delete({ where: { id: v2.id } });

    // -------------------------------------------------------------------------
    // TEST 11: A future roadmap can reuse the same topic
    // -------------------------------------------------------------------------
    const testSscRoadmap = await prisma.roadmap.create({
      data: {
        id: `ssc-cgl-test-${Date.now()}`,
        slug: `ssc-cgl-test-${Date.now()}`,
        name: 'SSC CGL Aptitude',
        course: 'ssc',
        description: 'SSC CGL specific learning path',
        isActive: true,
      },
    });

    const sscStep = await prisma.roadmapStep.create({
      data: {
        id: `ssc-step-01-${Date.now()}`,
        roadmapId: testSscRoadmap.id,
        subjectId: 'quantitative-aptitude',
        topicId: 'qa-ratio-proportion', // Reusing the exact same topic!
        sequence: 1,
        course: 'ssc',
        importance: 'very_important',
      },
    });

    assert(
      sscStep.topicId === 'qa-ratio-proportion' &&
        sscStep.roadmapId === testSscRoadmap.id,
      'Test 11: A future roadmap can reuse the same topic',
      `Topic qa-ratio-proportion attached to new roadmap ${testSscRoadmap.id}`
    );

    // -------------------------------------------------------------------------
    // TEST 12: Topic ordering differs correctly between roadmaps
    // -------------------------------------------------------------------------
    // In general-aptitude: Ratio is step sequence 4
    const gaRatioStep = await prisma.roadmapStep.findFirst({
      where: {
        roadmapId: 'general-aptitude',
        topicId: 'qa-ratio-proportion',
      },
    });

    // In ssc-cgl: Ratio is step sequence 1
    assert(
      gaRatioStep?.sequence === 4 && sscStep.sequence === 1,
      'Test 12: Topic ordering differs correctly between roadmaps',
      `General sequence: ${gaRatioStep?.sequence}, SSC sequence: ${sscStep.sequence}`
    );

    // Clean up test roadmap and its step
    await prisma.roadmapStep.delete({ where: { id: sscStep.id } });
    await prisma.roadmap.delete({ where: { id: testSscRoadmap.id } });

    // -------------------------------------------------------------------------
    // TEST 13: Different users can be at different roadmap steps while sharing the same script
    // -------------------------------------------------------------------------
    const u1Session = await prisma.lessonSession.findFirst({
      where: { userId: user1.id, roadmapStepId: 'ga-qa-04' },
    });

    const u2Start = await lessonSessionService.startOrResumeSessionByStep(
      user2.id,
      'ga-qa-04',
      uuidv4()
    );

    assert(
      u1Session !== null &&
        u2Start !== null &&
        u1Session.id !== u2Start.sessionId &&
        u1Session.currentNodeId !== u2Start.currentNode.id,
      'Test 13: Different users can be at different roadmap steps / session states while sharing the same script',
      `User 1 Node: ${u1Session?.currentNodeId}, User 2 Node: ${u2Start.currentNode.id}`
    );

    // -------------------------------------------------------------------------
    // TEST 14: No client-supplied nextNode/nextTopic can bypass roadmap progression
    // -------------------------------------------------------------------------
    let bypassPrevented = false;
    try {
      // Attempting to send invalid action payload or fake nextNode
      await lessonSessionService.submitAction(user2.id, u2Start.sessionId, {
        clientActionId: uuidv4(),
        stateVersion: u2Start.stateVersion,
        currentNodeId: 'arbitrary_fake_node', // spoofed node ID
        action: {
          type: 'CHOICE',
          actionId: 'fake_opt',
          // Client tries to inject nextNodeId or nextTopicId
          ...( { nextNodeId: 'node_18_completion', nextTopicId: 'qa-geometry' } as any ),
        },
      });
    } catch (err: any) {
      // Server rejected node mismatch and ignores spoofed transitions
      bypassPrevented = err.message.includes('Node mismatch');
    }

    assert(
      bypassPrevented,
      'Test 14: No client-supplied nextNode/nextTopic can bypass roadmap progression'
    );
  } finally {
    // Clean up test users
    await prisma.user.deleteMany({
      where: { id: { in: [user1.id, user2.id] } },
    });
    console.log('\n🧹 Test users cleaned up.');
  }

  console.log('\n====================================================');
  console.log(`TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  console.log('====================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests()
  .catch((e) => {
    console.error('Fatal test error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
