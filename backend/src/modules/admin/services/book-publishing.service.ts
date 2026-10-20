import { log, safeError } from '../../../observability/logger';
import { prisma } from '../../lesson/services/learning-transaction';
import { catalogMutation } from '../../roadmap/services/catalog-mutation';
import { ScriptValidator } from '../../lesson/engines/script-validator';
import { validateAdminQuestion, questionFields } from '../admin-input';
import { PublicError } from '../../../security/errors';
import { scriptCacheService } from '../../lesson/services/script-cache.service';
import { questionHydrationService } from '../../lesson/services/question-hydration.service';
import { AdminSyllabusService } from '../admin-syllabus.service';
import { createHash } from 'node:crypto';

export interface PublishResult {
  success: boolean;
  bookId: string;
  subjectId: string;
  subjectName: string;
  publishedTopicsCount: number;
  publishedSubtopicsCount: number;
  publishedScriptsCount: number;
  publishedQuestionsCount: number;
}

export class BookPublishingService {
  private static instance: BookPublishingService;

  private constructor() {}

  public static getInstance(): BookPublishingService {
    if (!BookPublishingService.instance) {
      BookPublishingService.instance = new BookPublishingService();
    }
    return BookPublishingService.instance;
  }

  /**
   * Activates the book Subject and marks all child topics, subtopics,
   * lesson scripts, and questions as live/PUBLISHED.
   */
  public async publishBook(bookId:string): Promise<PublishResult> {return catalogMutation(()=>this.publishBookImpl(bookId));}
  private async publishBookImpl(bookId: string): Promise<PublishResult> {
    await prisma.$queryRaw`SELECT id FROM learning.book_sources WHERE id=${bookId}::uuid FOR UPDATE`;
    const owner=await prisma.bookSource.findUniqueOrThrow({where:{id:bookId}});
    if(owner.processingToken)throw new PublicError('Wait for processing to stop before publishing','BOOK_PROCESSING',409);
    const bookSource = await prisma.bookSource.findUnique({
      where: { id: bookId },
      include: {
        subject: {
          include: {
            topics: {
              include: {
                subtopics: true,
              },
            },
          },
        },
      },
    });

    if (!bookSource) {
      throw new Error(`BookSource not found: ${bookId}`);
    }

    const subjectId = bookSource.subject.id;

    log('info','book_publishing_service.publishBookImpl.info');

    const result = await prisma.$transaction(async (tx) => {
      // 1. Activate the Subject
      const subject = await tx.subject.update({
        where: { id: subjectId },
        data: { isActive: true },
      });

      // 2. Activate all Topics under this Subject
      const topicsUpdate = await tx.topic.updateMany({
        where: { subjectId },
        data: { isActive: true },
      });

      // 3. Activate all Subtopics under these Topics
      const topicIds = bookSource.subject.topics.map((t) => t.id);
      const subtopicsUpdate = await tx.subtopic.updateMany({
        where: { topicId: { in: topicIds } },
        data: { isActive: true },
      });

      // Publish one reviewed, structurally valid current version per script, never historical drafts.
      const scriptRecords=await tx.lessonScript.findMany({where:{subjectId},include:{versions:{orderBy:{versionNumber:'desc'},take:1}}});
      for(const script of scriptRecords){
        const version=script.versions[0];
        if(!version)throw new PublicError('Book contains a script without a version');
        const definition=scriptCacheService.normalizeScriptDefinition(version.definition,script.title);
        if(!ScriptValidator.validate(definition).valid)throw new PublicError('Book contains an invalid script; review it before publication');
        const hydrated=await questionHydrationService.hydrateScriptDefinition(definition);
        await AdminSyllabusService.validateScript(hydrated,script.subjectId,script.topicId,script.subtopicId);
        const published=version.status==='PUBLISHED'?version:await tx.lessonScriptVersion.create({data:{
          scriptId:script.id,versionNumber:version.versionNumber+1,definition:hydrated as any,
          checksum:createHash('sha256').update(JSON.stringify(hydrated)).digest('hex'),status:'PUBLISHED',publishedAt:new Date(),
        }});
        await tx.lessonScript.update({where:{id:script.id},data:{status:'PUBLISHED',publishedVersionId:published.id}});
      }
      const scriptsUpdate={count:scriptRecords.length};

      const questions=await tx.question.findMany({where:{subjectId}});
      const hierarchy=await tx.subtopic.findMany({where:{id:{in:[...new Set(questions.map(q=>q.subtopicId))]}},select:{id:true,topicId:true,topic:{select:{subjectId:true}}}});
      const subtopics=new Map(hierarchy.map(s=>[s.id,s]));
      for(const question of questions){
        validateAdminQuestion(Object.fromEntries(Object.entries({...question,status:'PUBLISHED'}).filter(([key])=>Object.hasOwn(questionFields.shape,key))));
        const subtopic=subtopics.get(question.subtopicId);
        if(!subtopic || subtopic.topicId!==question.topicId || subtopic.topic.subjectId!==question.subjectId)throw new PublicError('Book contains an inconsistent question hierarchy');
      }
      // 5. Publish all Questions under this Subject
      const questionsUpdate = await tx.question.updateMany({
        where: { subjectId },
        data: {
          status: 'PUBLISHED',
          reviewedAt: new Date(),
        },
      });

      // 6. Mark BookSource as PUBLISHED
      await tx.bookSource.update({
        where: { id: bookId },
        data: {
          status: 'PUBLISHED',
          errorMessage: null,
        },
      });

      return {
        subject,
        publishedTopicsCount: topicsUpdate.count,
        publishedSubtopicsCount: subtopicsUpdate.count,
        publishedScriptsCount: scriptsUpdate.count,
        publishedQuestionsCount: questionsUpdate.count,
        scriptSlugs: scriptRecords.map((s) => s.slug),
      };
    });

    // Invalidate script caches
    for (const slug of result.scriptSlugs) {
      await scriptCacheService.invalidateScriptCache(slug);
    }

    log('info','book_publishing_service.publishBookImpl.info');

    return {
      success: true,
      bookId,
      subjectId,
      subjectName: result.subject.name,
      publishedTopicsCount: result.publishedTopicsCount,
      publishedSubtopicsCount: result.publishedSubtopicsCount,
      publishedScriptsCount: result.publishedScriptsCount,
      publishedQuestionsCount: result.publishedQuestionsCount,
    };
  }
}

export const bookPublishingService = BookPublishingService.getInstance();
