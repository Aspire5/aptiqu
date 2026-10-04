import { prisma } from '../../../config/prisma';
import { geminiProvider } from '../../ai/gemini.provider';
import { pdfParserService } from './pdf-parser.service';
import {
  TOPIC_DISCOVERY_SYSTEM_INSTRUCTION,
  TOPIC_DISCOVERY_JSON_SCHEMA,
} from '../prompts/topic-discovery.prompt';
import { DetectedTopicCandidate } from '../types/book-ingestion.types';

export class TopicDiscoveryService {
  private static instance: TopicDiscoveryService;

  private constructor() {}

  public static getInstance(): TopicDiscoveryService {
    if (!TopicDiscoveryService.instance) {
      TopicDiscoveryService.instance = new TopicDiscoveryService();
    }
    return TopicDiscoveryService.instance;
  }

  /**
   * Scans front-matter pages (1-35) to find Table of Contents,
   * extracts chapter topics and page ranges using Gemini,
   * and creates candidate Topic records in PostgreSQL.
   */
  public async discoverTopics(bookId: string): Promise<DetectedTopicCandidate[]> {
    const bookSource = await prisma.bookSource.findUnique({
      where: { id: bookId },
      include: { subject: true },
    });

    if (!bookSource) {
      throw new Error(`BookSource not found with ID: ${bookId}`);
    }

    console.log(`[TopicDiscoveryService] Discovering topics for book "${bookSource.title}" (${bookId})...`);

    await prisma.bookSource.update({
      where: { id: bookId },
      data: { status: 'DETECTING_TOPICS' },
    });

    // 1. Scan front-matter pages for Table of Contents
    const maxScanPages = Math.min(35, bookSource.totalPages);
    const tocPages: number[] = [];
    const tocKeywordRegex = /(contents|table of contents|index|brief contents|chapters)/i;

    for (let p = 1; p <= maxScanPages; p++) {
      const pageData = await pdfParserService.getPageData(bookId, p);
      if (pageData && tocKeywordRegex.test(pageData.rawText.slice(0, 1000))) {
        tocPages.push(p);
      }
    }

    let sourceExcerpt = '';
    if (tocPages.length > 0) {
      const startToc = tocPages[0];
      const endToc = Math.min(tocPages[tocPages.length - 1] + 3, maxScanPages);
      console.log(`[TopicDiscoveryService] Detected Table of Contents on pages ${startToc} to ${endToc}.`);
      sourceExcerpt = await pdfParserService.getPagesText(bookId, startToc, endToc);
    } else {
      // Fallback: Sample headings from first 30 pages
      console.log('[TopicDiscoveryService] No explicit TOC found in front-matter. Using sample chapter headings.');
      sourceExcerpt = await pdfParserService.getPagesText(bookId, 1, Math.min(25, bookSource.totalPages));
    }

    // 2. Invoke Gemini to extract structured topics
    const prompt = `
Book Title: ${bookSource.title}
Author: ${bookSource.author || 'Not specified'}
Total Book Pages: ${bookSource.totalPages}

Extracted Source Material:
${sourceExcerpt}

Extract all major topics / chapters from this book according to the instructions. Ensure every topic has valid startPage and endPage numbers within 1 and ${bookSource.totalPages}.
`.trim();

    const result = await geminiProvider.generateStructuredContent<{
      topics: DetectedTopicCandidate[];
    }>({
      systemInstruction: TOPIC_DISCOVERY_SYSTEM_INSTRUCTION,
      prompt,
      responseSchema: TOPIC_DISCOVERY_JSON_SCHEMA,
      timeoutMs: 60000,
    });

    if (!result.topics || !Array.isArray(result.topics) || result.topics.length === 0) {
      throw new Error('Gemini topic discovery did not return any candidate topics.');
    }

    const topics = result.topics;
    console.log(`[TopicDiscoveryService] Discovered ${topics.length} topics for book "${bookSource.title}".`);

    // 3. Persist detected topics into BookSource metadata and create draft Topics in PostgreSQL
    const metadata = (bookSource.metadata as any) || {};
    metadata.detectedTopics = topics;

    await prisma.$transaction(async (tx) => {
      // Create or update Topics directly under the book Subject
      for (let i = 0; i < topics.length; i++) {
        const t = topics[i];
        const topicSlug = `${bookSource.subject.slug}-${t.suggestedSlug || t.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
        const topicId = topicSlug;

        await tx.topic.upsert({
          where: { id: topicId },
          update: {
            name: t.name.trim(),
            description: t.description || `Chapter from ${bookSource.title}`,
            sequence: i,
            isActive: false, // Inactive until published
          },
          create: {
            id: topicId,
            subjectId: bookSource.subject.id,
            slug: topicSlug,
            name: t.name.trim(),
            description: t.description || `Chapter from ${bookSource.title}`,
            sequence: i,
            isActive: false, // Inactive until published
          },
        });
      }

      await tx.bookSource.update({
        where: { id: bookId },
        data: {
          status: 'TOPICS_DETECTED',
          metadata,
        },
      });
    });

    return topics;
  }
}

export const topicDiscoveryService = TopicDiscoveryService.getInstance();
