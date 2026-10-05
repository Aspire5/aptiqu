import fs from 'fs';
import path from 'path';
import { prisma } from '../../../config/prisma';
import { bookStorageService } from './book-storage.service';
import { bookCancellationService } from './book-cancellation.service';

// Polyfill Node.js environment for pdfjs-dist / pdf-parse across all Node.js versions
if (typeof (process as any).getBuiltinModule !== 'function') {
  (process as any).getBuiltinModule = (name: string) => {
    try {
      return require(name);
    } catch {
      return null;
    }
  };
}
if (typeof (globalThis as any).DOMMatrix === 'undefined') {
  (globalThis as any).DOMMatrix = class DOMMatrix {
    a = 1; b = 0; c = 0; d = 1; e = 0; f = 0;
    m11 = 1; m12 = 0; m13 = 0; m14 = 0;
    m21 = 0; m22 = 1; m23 = 0; m24 = 0;
    m31 = 0; m32 = 0; m33 = 1; m34 = 0;
    m41 = 0; m42 = 0; m43 = 0; m44 = 1;
    is2D = true;
    isIdentity = true;
    constructor(init?: any) {
      if (Array.isArray(init) && init.length === 6) {
        this.a = this.m11 = init[0];
        this.b = this.m12 = init[1];
        this.c = this.m21 = init[2];
        this.d = this.m22 = init[3];
        this.e = this.m41 = init[4];
        this.f = this.m42 = init[5];
      }
    }
    multiply() { return this; }
    translate() { return this; }
    scale() { return this; }
    rotate() { return this; }
    inverse() { return this; }
    transformPoint(point: any) { return point; }
    toFloat32Array() { return new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]); }
    toFloat64Array() { return new Float64Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]); }
  };
}
if (typeof (globalThis as any).ImageData === 'undefined') {
  (globalThis as any).ImageData = class ImageData {
    data: Uint8ClampedArray;
    width: number;
    height: number;
    constructor(width: number, height: number) {
      this.width = width;
      this.height = height;
      this.data = new Uint8ClampedArray(width * height * 4);
    }
  };
}
if (typeof (globalThis as any).Path2D === 'undefined') {
  (globalThis as any).Path2D = class Path2D {
    addPath() {}
    closePath() {}
    moveTo() {}
    lineTo() {}
    bezierCurveTo() {}
    quadraticCurveTo() {}
    arc() {}
    arcTo() {}
    ellipse() {}
    rect() {}
  };
}

export interface ParsedPageData {
  pageNumber: number;
  rawText: string;
  cleanedMarkdown: string;
  hasImages: boolean;
  hasFormulas: boolean;
  hasTables: boolean;
  headingCandidates: string[];
  tokenCount: number;
}

export class PdfParserService {
  private static instance: PdfParserService;

  private constructor() {}

  public static getInstance(): PdfParserService {
    if (!PdfParserService.instance) {
      PdfParserService.instance = new PdfParserService();
    }
    return PdfParserService.instance;
  }

  /**
   * Normalizes raw extracted text into clean, structured Markdown.
   */
  public cleanPageTextToMarkdown(rawText: string): {
    markdown: string;
    hasFormulas: boolean;
    hasTables: boolean;
    headings: string[];
  } {
    const lines = rawText.split('\n');
    const cleanedLines: string[] = [];
    const headings: string[] = [];

    const formulaPattern = /(=|\+|\-|\*|\/|÷|×|√|∑|%|\^|≤|≥|≠|∴|∵|log|sin|cos|tan)/;
    let hasFormulas = false;
    let hasTables = false;

    for (const rawLine of lines) {
      const line = rawLine.trim();
      if (!line) {
        cleanedLines.push('');
        continue;
      }

      if (formulaPattern.test(line)) {
        hasFormulas = true;
      }
      if (line.includes('\t') || line.split(/\s{2,}/).length >= 3) {
        hasTables = true;
      }

      // Identify Heading candidates: e.g. "CHAPTER 1", "NUMBER SYSTEM", "Ex. 1.", "SOLVED EXAMPLES"
      const isAllUpper = line.length > 3 && line === line.toUpperCase() && /[A-Z]/.test(line);
      const isChapterOrSection = /^(CHAPTER|SECTION|PART|EXERCISE|PRACTICE SET|SOLVED EXAMPLES|IMPORTANT FACTS)/i.test(line);

      if (isChapterOrSection || (isAllUpper && line.length < 60)) {
        headings.push(line);
        cleanedLines.push(`\n## ${line}\n`);
      } else if (/^(Ex\.|Example|Q\.|Question|\d+\.)/i.test(line) && line.length < 80) {
        headings.push(line);
        cleanedLines.push(`\n### ${line}\n`);
      } else {
        cleanedLines.push(line);
      }
    }

    const markdown = cleanedLines.join('\n').replace(/\n{3,}/g, '\n\n').trim();

    return {
      markdown,
      hasFormulas,
      hasTables,
      headings,
    };
  }

  /**
   * Parses the complete PDF for a BookSource, stores page JSONs in filesystem,
   * creates BookPage records in PostgreSQL, and updates BookSource.totalPages.
   */
  public async parseBookPdf(
    bookId: string,
    onProgress?: (progress: number, currentPage: number, totalPages: number) => Promise<void>
  ): Promise<{ totalPages: number }> {
    bookCancellationService.checkAndThrowIfCancelled(bookId, 'start of parseBookPdf');

    const bookSource = await prisma.bookSource.findUnique({
      where: { id: bookId },
    });

    if (!bookSource) {
      throw new Error(`BookSource not found with ID: ${bookId}`);
    }

    if (!fs.existsSync(bookSource.storagePath)) {
      throw new Error(`PDF file not found at storage path: ${bookSource.storagePath}`);
    }

    console.log(`[PdfParserService] Beginning extraction for Book "${bookSource.title}" (${bookId})...`);

    // 1. Update status to PARSING_PAGES
    await prisma.bookSource.update({
      where: { id: bookId },
      data: { status: 'PARSING_PAGES', errorMessage: null },
    });

    const fileBuffer = fs.readFileSync(bookSource.storagePath);

    // 2. Load PDF with PDFParse
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const pdfParseModule = require('pdf-parse');
    const PDFParse = pdfParseModule.PDFParse || pdfParseModule.default || pdfParseModule;
    const parserInstance = new PDFParse({ data: fileBuffer });

    let parsedResult: any;
    try {
      parsedResult = await parserInstance.getText();
    } finally {
      if (typeof parserInstance.destroy === 'function') {
        await parserInstance.destroy();
      }
    }

    const rawPages: any[] = parsedResult.pages || [];
    const totalPages = rawPages.length || parsedResult.total || 0;

    if (totalPages === 0) {
      throw new Error('PDF extraction returned 0 pages. The file may be corrupt or encrypted.');
    }

    console.log(`[PdfParserService] Extracted ${totalPages} pages for book "${bookSource.title}". Processing pages...`);

    const pagesDir = bookStorageService.getPagesDirForBook(bookId);
    const CHUNK_SIZE = 50;
    const pagesToInsert: any[] = [];

    for (let i = 0; i < totalPages; i++) {
      if (i % 25 === 0) {
        bookCancellationService.checkAndThrowIfCancelled(bookId, `parsing page ${i + 1}`);
      }
      const pageNumber = i + 1;
      const rawText = (rawPages[i]?.text || '').trim();
      const { markdown, hasFormulas, hasTables, headings } = this.cleanPageTextToMarkdown(rawText);

      // Estimate tokens: ~1.3 tokens per word
      const wordCount = rawText ? rawText.split(/\s+/).length : 0;
      const tokenCount = Math.round(wordCount * 1.35);

      const pageData: ParsedPageData = {
        pageNumber,
        rawText,
        cleanedMarkdown: markdown,
        hasImages: false,
        hasFormulas,
        hasTables,
        headingCandidates: headings,
        tokenCount,
      };

      // A. Write page JSON to disk for lightning-fast subsequent reads
      const pageFilePath = path.join(pagesDir, `page_${String(pageNumber).padStart(4, '0')}.json`);
      fs.writeFileSync(pageFilePath, JSON.stringify(pageData, null, 2), 'utf-8');

      // B. Prepare DB record
      pagesToInsert.push({
        bookId,
        pageNumber,
        rawText: rawText.slice(0, 30000), // Protect against anomalous giant strings
        cleanedMarkdown: markdown.slice(0, 30000),
        hasImages: false,
        hasFormulas,
        hasTables,
        tokenCount,
      });

      // C. Flush in batches to DB
      if (pagesToInsert.length >= CHUNK_SIZE || i === totalPages - 1) {
        const batch = pagesToInsert.splice(0, pagesToInsert.length);
        await prisma.bookPage.createMany({
          data: batch,
          skipDuplicates: true,
        });

        if (onProgress) {
          const progress = (i + 1) / totalPages;
          await onProgress(progress, i + 1, totalPages);
        }
      }
    }

    // 3. Update BookSource with totalPages & transition status to PAGES_EXTRACTED
    await prisma.bookSource.update({
      where: { id: bookId },
      data: {
        totalPages,
        status: 'PAGES_EXTRACTED',
      },
    });

    console.log(`[PdfParserService] Successfully parsed and stored ${totalPages} pages for book ID: ${bookId}`);
    return { totalPages };
  }

  /**
   * Retrieves page data from local disk cache or database
   */
  public async getPageData(bookId: string, pageNumber: number): Promise<ParsedPageData | null> {
    const pagesDir = bookStorageService.getPagesDirForBook(bookId);
    const pageFilePath = path.join(pagesDir, `page_${String(pageNumber).padStart(4, '0')}.json`);

    if (fs.existsSync(pageFilePath)) {
      try {
        const content = fs.readFileSync(pageFilePath, 'utf-8');
        return JSON.parse(content) as ParsedPageData;
      } catch {
        // Fallback to database
      }
    }

    const dbPage = await prisma.bookPage.findUnique({
      where: {
        bookId_pageNumber: {
          bookId,
          pageNumber,
        },
      },
    });

    if (!dbPage) return null;

    return {
      pageNumber: dbPage.pageNumber,
      rawText: dbPage.rawText,
      cleanedMarkdown: dbPage.cleanedMarkdown || dbPage.rawText,
      hasImages: dbPage.hasImages,
      hasFormulas: dbPage.hasFormulas,
      hasTables: dbPage.hasTables,
      headingCandidates: [],
      tokenCount: dbPage.tokenCount,
    };
  }

  /**
   * Retrieves text across a range of pages [startPage, endPage] inclusive
   */
  public async getPagesText(bookId: string, startPage: number, endPage: number): Promise<string> {
    const texts: string[] = [];
    for (let p = startPage; p <= endPage; p++) {
      const page = await this.getPageData(bookId, p);
      if (page && page.cleanedMarkdown.trim().length > 0) {
        texts.push(`--- [PAGE ${p}] ---\n${page.cleanedMarkdown}`);
      }
    }
    return texts.join('\n\n');
  }
}

export const pdfParserService = PdfParserService.getInstance();
