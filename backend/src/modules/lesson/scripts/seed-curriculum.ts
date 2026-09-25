import fs from 'fs';
import path from 'path';
import { prisma } from '../../../config/prisma';
import { publishScriptFromJson } from './seed-lesson';

export async function seedCurriculum() {
  console.log('🌱 Starting Curriculum & Roadmap Seeding...');

  // Resolve assets/subjectseed.txt
  const candidates = [
    path.resolve(process.cwd(), 'assets/subjectseed.txt'),
    path.resolve(process.cwd(), '../assets/subjectseed.txt'),
    path.resolve(__dirname, '../../../../../../assets/subjectseed.txt'),
    path.resolve(__dirname, '../../../../../assets/subjectseed.txt'),
  ];

  let seedFilePath = '';
  for (const c of candidates) {
    if (fs.existsSync(c)) {
      seedFilePath = c;
      break;
    }
  }

  if (!seedFilePath) {
    throw new Error(`Could not find subjectseed.txt in candidate locations: ${candidates.join(', ')}`);
  }

  console.log(`📖 Reading seed file from: ${seedFilePath}`);
  const content = fs.readFileSync(seedFilePath, 'utf8');

  // Extract all JSON blocks
  const jsonBlocks: string[] = [];
  let depth = 0;
  let start = -1;
  for (let i = 0; i < content.length; i++) {
    if (content[i] === '{' && depth === 0) {
      start = i;
      depth = 1;
    } else if (content[i] === '{') {
      depth++;
    } else if (content[i] === '}') {
      depth--;
      if (depth === 0 && start !== -1) {
        jsonBlocks.push(content.substring(start, i + 1));
        start = -1;
      }
    }
  }

  const subjects: any[] = [];
  const roadmaps: any[] = [];
  const roadmapSubjects: any[] = [];
  const topics: any[] = [];
  const subtopics: any[] = [];
  const roadmapSteps: any[] = [];

  for (const block of jsonBlocks) {
    try {
      const data = JSON.parse(block);
      if (data.subjects) subjects.push(...data.subjects);
      if (data.roadmaps) roadmaps.push(...data.roadmaps);
      if (data.roadmapSubjects) roadmapSubjects.push(...data.roadmapSubjects);
      if (data.topics) topics.push(...data.topics);
      if (data.subtopics) subtopics.push(...data.subtopics);
      if (data.roadmapSteps) roadmapSteps.push(...data.roadmapSteps);
    } catch (e: any) {
      console.warn('⚠️ Warning: Failed to parse a JSON block:', e.message);
    }
  }

  console.log(`Parsed:
  - Subjects: ${subjects.length}
  - Roadmaps: ${roadmaps.length}
  - Roadmap Subjects: ${roadmapSubjects.length}
  - Topics: ${topics.length}
  - Subtopics: ${subtopics.length}
  - Roadmap Steps: ${roadmapSteps.length}`);

  // 1. Seed Subjects
  console.log('📌 Seeding Subjects...');
  for (const s of subjects) {
    await prisma.subject.upsert({
      where: { id: s.id },
      update: {
        slug: s.slug || s.id,
        name: s.name,
        description: s.description || null,
        displayOrder: s.displayOrder ?? 0,
        isActive: s.isActive ?? true,
      },
      create: {
        id: s.id,
        slug: s.slug || s.id,
        name: s.name,
        description: s.description || null,
        displayOrder: s.displayOrder ?? 0,
        isActive: s.isActive ?? true,
      },
    });
  }

  // 2. Seed Roadmaps
  console.log('📌 Seeding Roadmaps...');
  for (const r of roadmaps) {
    await prisma.roadmap.upsert({
      where: { id: r.id },
      update: {
        slug: r.slug || r.id,
        name: r.name,
        course: r.course || 'general',
        description: r.description || null,
        isDefault: r.isDefault ?? false,
        isActive: r.isActive ?? true,
      },
      create: {
        id: r.id,
        slug: r.slug || r.id,
        name: r.name,
        course: r.course || 'general',
        description: r.description || null,
        isDefault: r.isDefault ?? false,
        isActive: r.isActive ?? true,
      },
    });
  }

  // 3. Seed Roadmap Subjects
  console.log('📌 Seeding Roadmap Subjects...');
  for (const rs of roadmapSubjects) {
    await prisma.roadmapSubject.upsert({
      where: {
        roadmapId_subjectId: {
          roadmapId: rs.roadmapId,
          subjectId: rs.subjectId,
        },
      },
      update: {
        sequence: rs.sequence,
      },
      create: {
        roadmapId: rs.roadmapId,
        subjectId: rs.subjectId,
        sequence: rs.sequence,
      },
    });
  }

  // 4. Seed Topics
  console.log('📌 Seeding Topics...');
  for (const t of topics) {
    await prisma.topic.upsert({
      where: { id: t.id },
      update: {
        subjectId: t.subjectId,
        slug: t.slug || t.id,
        name: t.name,
        description: t.description || null,
        defaultImportance: t.defaultImportance || null,
        defaultTeachingDepth: t.defaultTeachingDepth ?? null,
        defaultTeachingMinutes: t.defaultTeachingMinutes ?? null,
        isActive: t.isActive ?? true,
      },
      create: {
        id: t.id,
        subjectId: t.subjectId,
        slug: t.slug || t.id,
        name: t.name,
        description: t.description || null,
        defaultImportance: t.defaultImportance || null,
        defaultTeachingDepth: t.defaultTeachingDepth ?? null,
        defaultTeachingMinutes: t.defaultTeachingMinutes ?? null,
        isActive: t.isActive ?? true,
      },
    });
  }

  // 5. Seed Subtopics
  console.log('📌 Seeding Subtopics...');
  for (const st of subtopics) {
    await prisma.subtopic.upsert({
      where: { id: st.id },
      update: {
        topicId: st.topicId,
        slug: st.slug || st.id,
        name: st.name,
        description: st.description || null,
        sequence: st.sequence ?? 0,
        importance: st.importance || null,
        teachingDepth: st.teachingDepth ?? null,
        teachingMinutes: st.teachingMinutes ?? null,
        isActive: st.isActive ?? true,
      },
      create: {
        id: st.id,
        topicId: st.topicId,
        slug: st.slug || st.id,
        name: st.name,
        description: st.description || null,
        sequence: st.sequence ?? 0,
        importance: st.importance || null,
        teachingDepth: st.teachingDepth ?? null,
        teachingMinutes: st.teachingMinutes ?? null,
        isActive: st.isActive ?? true,
      },
    });
  }

  // 6. Seed Roadmap Steps
  console.log('📌 Seeding Roadmap Steps...');
  for (const step of roadmapSteps) {
    await prisma.roadmapStep.upsert({
      where: { id: step.id },
      update: {
        roadmapId: step.roadmapId,
        subjectId: step.subjectId,
        topicId: step.topicId,
        subtopicId: step.subtopicId || null,
        sequence: step.sequence,
        course: step.course || 'general',
        importance: step.importance || 'medium',
        teachingDepth: step.teachingDepth ?? 3,
        teachingMinutes: step.teachingMinutes ?? 30,
        isRequired: step.isRequired ?? true,
        isActive: step.isActive ?? true,
      },
      create: {
        id: step.id,
        roadmapId: step.roadmapId,
        subjectId: step.subjectId,
        topicId: step.topicId,
        subtopicId: step.subtopicId || null,
        sequence: step.sequence,
        course: step.course || 'general',
        importance: step.importance || 'medium',
        teachingDepth: step.teachingDepth ?? 3,
        teachingMinutes: step.teachingMinutes ?? 30,
        isRequired: step.isRequired ?? true,
        isActive: step.isActive ?? true,
      },
    });
  }

  // 7. Ensure Ratios script is published and assigned to its roadmap step
  console.log('📌 Checking Script Assignment for Ratios lesson...');
  const ratiosScriptFile = path.resolve(__dirname, 'ratios-15min-beginner.json');
  if (fs.existsSync(ratiosScriptFile)) {
    await publishScriptFromJson(ratiosScriptFile);
  }

  const ratiosScript = await prisma.lessonScript.findUnique({
    where: { slug: 'math_ratios_101' },
  });

  if (ratiosScript && ratiosScript.publishedVersionId) {
    // Find the roadmap step for Ratio & Proportion in general-aptitude (ga-qa-04)
    const ratioStep = await prisma.roadmapStep.findFirst({
      where: {
        roadmapId: 'general-aptitude',
        topicId: 'qa-ratio-proportion',
      },
    });

    if (ratioStep) {
      // Find or create ScriptAssignment
      const existingAssignment = await prisma.scriptAssignment.findFirst({
        where: {
          roadmapStepId: ratioStep.id,
          scriptId: ratiosScript.id,
        },
      });

      if (!existingAssignment) {
        await prisma.scriptAssignment.create({
          data: {
            roadmapStepId: ratioStep.id,
            scriptId: ratiosScript.id,
            publishedVersionId: ratiosScript.publishedVersionId,
            status: 'PUBLISHED',
            sequence: 1,
            isRequired: true,
          },
        });
        console.log(`🔗 Linked script "math_ratios_101" to Roadmap Step "${ratioStep.id}"`);
      } else {
        await prisma.scriptAssignment.update({
          where: { id: existingAssignment.id },
          data: {
            publishedVersionId: ratiosScript.publishedVersionId,
            status: 'PUBLISHED',
          },
        });
        console.log(`🔄 Updated assignment for script "math_ratios_101" on step "${ratioStep.id}"`);
      }
    }
  }

  // 8. Set active roadmap for existing users if not set
  await prisma.user.updateMany({
    where: { activeRoadmapId: null },
    data: { activeRoadmapId: 'general-aptitude' },
  });

  console.log('🎉 Curriculum & Roadmap Seeding Completed Successfully!');
}

if (require.main === module) {
  seedCurriculum()
    .catch((err) => {
      console.error('Failed to seed curriculum:', err);
      process.exit(1);
    })
    .finally(() => prisma.$disconnect());
}
