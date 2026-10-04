import { prisma } from '../../../config/prisma';
import { geminiProvider } from '../../ai/gemini.provider';
import { pdfParserService } from './pdf-parser.service';
import {
  SUBTOPIC_DISCOVERY_SYSTEM_INSTRUCTION,
  SUBTOPIC_DISCOVERY_JSON_SCHEMA,
} from '../prompts/subtopic-discovery.prompt';
import { DetectedTopicCandidate, DiscoveredSubtopicCandidate } from '../types/book-ingestion.types';

export class SubtopicDiscoveryService {
  private static instance: SubtopicDiscoveryService;

  private constructor() {}

  public static getInstance(): SubtopicDiscoveryService {
    if (!SubtopicDiscoveryService.instance) {
      SubtopicDiscoveryService.instance = new SubtopicDiscoveryService();
    }
    return SubtopicDiscoveryService.instance;
  }

  /**
   * Discovers subtopics for a single topic using its page range.
   */
  public async discoverSubtopicsForTopic(
    bookId: string,
    topicCandidate: DetectedTopicCandidate,
    dbTopicId: string
  ): Promise<DiscoveredSubtopicCandidate[]> {
    console.log(
      `[SubtopicDiscoveryService] Discovering subtopics for topic "${topicCandidate.name}" (Pages ${topicCandidate.startPage}-${topicCandidate.endPage})...`
    );

    // Retrieve topic source text (capped to 10 introductory theory/concept pages to prevent token overflow)
    const maxEndPage = Math.min(topicCandidate.endPage, topicCandidate.startPage + 10);
    let sourceText = await pdfParserService.getPagesText(
      bookId,
      topicCandidate.startPage,
      maxEndPage
    );

    if (sourceText.length > 25000) {
      sourceText = sourceText.slice(0, 25000) + '\n\n[... Remaining exercise pages omitted for subtopic outline synthesis ...]';
    }

    const prompt = `
Topic Name: ${topicCandidate.name} (Code: ${topicCandidate.code})
Topic Page Range: ${topicCandidate.startPage} to ${topicCandidate.endPage}

Textbook Content:
${sourceText}

Synthesize the pedagogical subtopics for this topic based strictly on the concepts in this material. Output matching the required schema.
`.trim();

    const result = await geminiProvider.generateStructuredContent<{
      subtopics: DiscoveredSubtopicCandidate[];
    }>({
      systemInstruction: SUBTOPIC_DISCOVERY_SYSTEM_INSTRUCTION,
      prompt,
      responseSchema: SUBTOPIC_DISCOVERY_JSON_SCHEMA,
      timeoutMs: 90000,
    });

    if (!result.subtopics || !Array.isArray(result.subtopics) || result.subtopics.length === 0) {
      throw new Error(`Subtopic discovery returned 0 subtopics for topic: ${topicCandidate.name}`);
    }

    const subtopics = result.subtopics;
    console.log(
      `[SubtopicDiscoveryService] Generated ${subtopics.length} subtopics for topic "${topicCandidate.name}". Persisting...`
    );

    // Persist into database under this topic
    for (let i = 0; i < subtopics.length; i++) {
      const s = subtopics[i];
      const codeSeq = String(s.sequence || i + 1).padStart(2, '0');
      const subtopicSlug = `${topicCandidate.code.toLowerCase()}-${codeSeq}-${s.suggestedSlug || s.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
      const subtopicId = subtopicSlug;

      await prisma.subtopic.upsert({
        where: { id: subtopicId },
        update: {
          name: s.name.trim(),
          description: s.description,
          sequence: s.sequence || i + 1,
          importance: s.importance || 'CORE',
          teachingMinutes: s.teachingMinutes || 10,
          isActive: false, // Inactive until published
        },
        create: {
          id: subtopicId,
          topicId: dbTopicId,
          slug: subtopicSlug,
          name: s.name.trim(),
          description: s.description,
          sequence: s.sequence || i + 1,
          importance: s.importance || 'CORE',
          teachingMinutes: s.teachingMinutes || 10,
          isActive: false, // Inactive until published
        },
      });
    }

    return subtopics;
  }

  /**
   * Iterates through all detected topics for a book and discovers subtopics for each.
   */
  public async discoverAllSubtopicsForBook(
    bookId: string,
    onProgress?: (progress: number, completedTopics: number, totalTopics: number) => Promise<void>
  ): Promise<Record<string, DiscoveredSubtopicCandidate[]>> {
    const bookSource = await prisma.bookSource.findUnique({
      where: { id: bookId },
      include: {
        subject: {
          include: {
            topics: { orderBy: { sequence: 'asc' } },
          },
        },
      },
    });

    if (!bookSource) {
      throw new Error(`BookSource not found with ID: ${bookId}`);
    }

    await prisma.bookSource.update({
      where: { id: bookId },
      data: { status: 'DISCOVERING_SUBTOPICS' },
    });

    const metadata = (bookSource.metadata as any) || {};
    const detectedTopics: DetectedTopicCandidate[] = metadata.detectedTopics || [];

    if (detectedTopics.length === 0) {
      throw new Error('No detected topics found in book metadata. Run topic discovery first.');
    }

    const subtopicsByTopicCode: Record<string, DiscoveredSubtopicCandidate[]> = {};
    const totalTopics = detectedTopics.length;

    for (let i = 0; i < totalTopics; i++) {
      const topicCandidate = detectedTopics[i];
      // Find matching dbTopicId
      const matchingTopic = bookSource.subject.topics.find(
        (t) =>
          t.name.toLowerCase() === topicCandidate.name.toLowerCase() ||
          t.slug.includes(topicCandidate.suggestedSlug)
      );

      const dbTopicId = matchingTopic ? matchingTopic.id : `${bookSource.subject.slug}-${topicCandidate.suggestedSlug}`;

      try {
        const discovered = await this.discoverSubtopicsForTopic(bookId, topicCandidate, dbTopicId);
        subtopicsByTopicCode[topicCandidate.code] = discovered;
      } catch (err: any) {
        console.error(
          `[SubtopicDiscoveryService] Error discovering subtopics for topic "${topicCandidate.name}":`,
          err.message
        );
        // Continue to other topics rather than aborting entire book
      }

      if (onProgress) {
        await onProgress((i + 1) / totalTopics, i + 1, totalTopics);
      }

      // Pacing delay between topics
      if (i < totalTopics - 1) {
        await new Promise((resolve) => setTimeout(resolve, 2000));
      }
    }

    metadata.discoveredSubtopics = subtopicsByTopicCode;

    await prisma.bookSource.update({
      where: { id: bookId },
      data: {
        status: 'SUBTOPICS_DISCOVERED',
        metadata,
      },
    });

    console.log(`[SubtopicDiscoveryService] Finished subtopic discovery across all topics for book "${bookSource.title}".`);
    return subtopicsByTopicCode;
  }
}

export const subtopicDiscoveryService = SubtopicDiscoveryService.getInstance();
