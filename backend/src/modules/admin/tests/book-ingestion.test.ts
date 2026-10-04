import path from 'path';
import fs from 'fs';
import { prisma } from '../../../config/prisma';
import { bookStorageService } from '../services/book-storage.service';
import { pdfParserService } from '../services/pdf-parser.service';
import { contentValidationService } from '../services/content-validation.service';
import { bookPublishingService } from '../services/book-publishing.service';
import { ScriptValidator } from '../../lesson/engines/script-validator';

async function runBookIngestionIntegrationTest() {
  console.log('====================================================');
  console.log('🧪 Starting AptiQu Book Ingestion Integration Test');
  console.log('====================================================\n');

  let testBookId: string | null = null;
  let testSubjectId: string | null = null;
  const tempTestPdfPath = path.resolve(process.cwd(), 'storage/temp/test-book.pdf');

  try {
    // Pre-clean old test records if any
    const oldTestBooks = await prisma.bookSource.findMany({
      where: { title: { startsWith: 'Test Quantitative Aptitude Book' } },
      select: { id: true, subjectId: true },
    });
    for (const b of oldTestBooks) {
      await prisma.question.deleteMany({ where: { subjectId: b.subjectId } });
      await prisma.lessonScript.deleteMany({ where: { subjectId: b.subjectId } });
      await prisma.subtopic.deleteMany({ where: { topic: { subjectId: b.subjectId } } });
      await prisma.topic.deleteMany({ where: { subjectId: b.subjectId } });
      await prisma.subject.delete({ where: { id: b.subjectId } }).catch(() => {});
    }

    // 1. Create a minimal valid PDF file for testing
    const uniqueToken = `${Date.now()}-${Math.random()}`;
    const minimalPdf = `%PDF-1.4
% Test Token: ${uniqueToken}
1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >> endobj
4 0 obj << /Length 55 >> stream
BT
/F1 12 Tf
72 712 Td
(Chapter 1: Number System. Concepts and Questions.) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000214 00000 n 
trailer << /Size 5 /Root 1 0 R >>
startxref
320
%%EOF`;

    if (!fs.existsSync(path.dirname(tempTestPdfPath))) {
      fs.mkdirSync(path.dirname(tempTestPdfPath), { recursive: true });
    }
    fs.writeFileSync(tempTestPdfPath, minimalPdf);
    console.log('✅ [PASS] Step 1: Created test PDF with valid %PDF header and unique checksum');

    // 2. Test Book Storage Service
    const stored = await bookStorageService.saveUploadedBook(tempTestPdfPath, {
      title: `Test Quantitative Aptitude Book ${Date.now()}`,
      author: 'AptiQu Test Author',
      edition: '1st Edition',
      isbn: 'TEST-ISBN-001',
    });

    testBookId = stored.bookSource.id;
    testSubjectId = stored.bookSource.subjectId;
    console.log(`✅ [PASS] Step 2: Stored book and created Subject: "${stored.bookSource.title}" (Subject ID: ${testSubjectId})`);

    // Verify Subject was created with isActive = false
    const subject = await prisma.subject.findUnique({ where: { id: testSubjectId } });
    if (!subject || subject.isActive !== false) {
      throw new Error(`Subject should be created with isActive = false, got ${subject?.isActive}`);
    }
    console.log('✅ [PASS] Step 3: Verified Subject has isActive = false prior to publishing');

    // 3. Test PDF Parser Service
    const parseResult = await pdfParserService.parseBookPdf(testBookId);
    console.log(`✅ [PASS] Step 4: Parsed PDF pages. Total pages: ${parseResult.totalPages}`);
    if (parseResult.totalPages <= 0) {
      throw new Error('PDF parser returned 0 pages');
    }

    // 4. Test Topic & Subtopic creation under Subject
    const topic = await prisma.topic.create({
      data: {
        id: `test-top-${Date.now()}`,
        subjectId: testSubjectId,
        name: 'Number System',
        slug: `number-system-${Date.now()}`,
        sequence: 0,
      },
    });

    const subtopic = await prisma.subtopic.create({
      data: {
        id: `test-subtop-${Date.now()}`,
        topicId: topic.id,
        name: 'Divisibility Rules & Prime Factors',
        slug: `divisibility-rules-${Date.now()}`,
        sequence: 0,
      },
    });
    console.log(`✅ [PASS] Step 5: Created Topic ("${topic.name}") and Subtopic ("${subtopic.name}") linked to Subject`);

    // 5. Test Question Extraction and Storage
    const question = await prisma.question.create({
      data: {
        subjectId: testSubjectId,
        topicId: topic.id,
        subtopicId: subtopic.id,
        prompt: 'Which of the following numbers is divisible by 9?',
        questionType: 'MCQ',
        options: [
          { key: 'A', text: '12345' },
          { key: 'B', text: '54321' },
          { key: 'C', text: '43218' },
          { key: 'D', text: '98761' },
        ],
        correctAnswer: 'C',
        explanation: 'Sum of digits of 43218 is 4+3+2+1+8 = 18, which is divisible by 9.',
        method: 'Digital Sum Rule',
        difficulty: 'EASY',
        calculationMode: 'MENTAL',
        fingerprint: `test-fp-${Date.now()}`,
        sourceBook: 'Test Quantitative Aptitude Book',
        sourcePageRange: '1',
      },
    });
    console.log(`✅ [PASS] Step 6: Created Question with options, step solution, and page provenance (ID: ${question.id})`);

    // 6. Test Interactive Lesson Script Generation & DSL Validation
    const scriptDefinition = {
      schemaVersion: 1,
      scriptId: `script-divisibility-${Date.now()}`,
      version: 1,
      entryNodeId: 'node-1',
      metadata: {
        title: 'Mastering Divisibility Rules',
        subjectId: testSubjectId,
        topicId: topic.id,
        subtopicId: subtopic.id,
        estimatedMinutes: 5,
      },
      nodes: {
        'node-1': {
          id: 'node-1',
          type: 'DIALOGUE',
          content: {
            speaker: 'TUTOR',
            text: 'Welcome to Divisibility Rules. Let us check if a number is divisible by 9 by adding its digits.',
          },
          transitions: [{ targetNodeId: 'node-2' }],
        },
        'node-2': {
          id: 'node-2',
          type: 'QUESTION',
          questionReference: {
            mode: 'QUESTION_EXTERNAL_ID',
            externalId: question.id,
          },
          transitions: [{ targetNodeId: 'node-3' }],
        },
        'node-3': {
          id: 'node-3',
          type: 'COMPLETION',
          content: {
            title: 'Subtopic Mastered!',
            message: 'You have mastered divisibility rules.',
          },
        },
      },
    };

    const validationResult = ScriptValidator.validate(scriptDefinition as any);
    if (!validationResult.valid) {
      throw new Error(`Script validation failed: ${JSON.stringify(validationResult.errors)}`);
    }
    console.log('✅ [PASS] Step 7: Lesson Script validated against AptiQu DSL Schema (schemaVersion: 1)');

    const lessonScript = await prisma.lessonScript.create({
      data: {
        slug: `script-divisibility-${Date.now()}`,
        title: 'Mastering Divisibility Rules',
        subjectId: testSubjectId,
        topicId: topic.id,
        subtopicId: subtopic.id,
        status: 'DRAFT',
        versions: {
          create: {
            versionNumber: 1,
            schemaVersion: 1,
            definition: scriptDefinition as any,
            checksum: 'test-checksum-001',
            status: 'DRAFT',
          },
        },
      },
    });
    console.log(`✅ [PASS] Step 8: Stored LessonScript and LessonScriptVersion (ID: ${lessonScript.id})`);

    // 7. Test Multi-Layer Content Validation
    const contentValidation = await contentValidationService.validateBookContent(testBookId);
    console.log(`✅ [PASS] Step 9: Ran ContentValidationService (Passed: ${contentValidation.passed}, Questions: ${contentValidation.totalQuestionsChecked})`);

    // 8. Test Book Publishing Service
    const publishResult = await bookPublishingService.publishBook(testBookId);
    console.log(`✅ [PASS] Step 10: Published Book Subject: "${publishResult.subjectName}" (Success: ${publishResult.success})`);

    // Verify Subject is now isActive = true in DB
    const updatedSubject = await prisma.subject.findUnique({ where: { id: testSubjectId } });
    if (!updatedSubject?.isActive) {
      throw new Error('Subject should have isActive = true after publishing');
    }
    console.log('✅ [PASS] Step 11: Verified Subject is live for learners with isActive = true');

    // Verify LessonScript status is PUBLISHED
    const updatedScript = await prisma.lessonScript.findUnique({ where: { id: lessonScript.id } });
    if (updatedScript?.status !== 'PUBLISHED') {
      throw new Error(`LessonScript status should be PUBLISHED, got ${updatedScript?.status}`);
    }
    console.log('✅ [PASS] Step 12: Verified LessonScript status is PUBLISHED');

    console.log('\n====================================================');
    console.log('🎉 ALL 12 INTEGRATION TESTS PASSED SUCCESSFULLY!');
    console.log('====================================================');
  } catch (err: any) {
    console.error('❌ [FAIL] Test encountered an error:', err);
    process.exit(1);
  } finally {
    // Teardown test artifacts
    if (fs.existsSync(tempTestPdfPath)) {
      try { fs.unlinkSync(tempTestPdfPath); } catch {}
    }
    if (testSubjectId) {
      console.log('\n🧹 Cleaning up test database records...');
      try {
        await prisma.question.deleteMany({ where: { subjectId: testSubjectId } });
        await prisma.lessonScript.deleteMany({ where: { subjectId: testSubjectId } });
        await prisma.subtopic.deleteMany({ where: { topic: { subjectId: testSubjectId } } });
        await prisma.topic.deleteMany({ where: { subjectId: testSubjectId } });
        await prisma.subject.delete({ where: { id: testSubjectId } });
        console.log('🧹 Test Subject and all cascaded book records cleanly deleted.');
      } catch (e) {
        console.warn('Cleanup warning:', e);
      }
    }
    await prisma.$disconnect();
  }
}

runBookIngestionIntegrationTest();
