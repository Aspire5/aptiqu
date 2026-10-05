import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { prisma } from '../../../config/prisma';
import { BookSource, Subject } from '@prisma/client';
import { BookUploadInput } from '../types/book-ingestion.types';

export class BookStorageService {
  private static instance: BookStorageService;
  private readonly storageBaseDir: string;
  private readonly tempDir: string;

  private constructor() {
    this.storageBaseDir = path.resolve(process.cwd(), 'storage/books');
    this.tempDir = path.resolve(process.cwd(), 'storage/temp');

    if (!fs.existsSync(this.storageBaseDir)) {
      fs.mkdirSync(this.storageBaseDir, { recursive: true });
    }
    if (!fs.existsSync(this.tempDir)) {
      fs.mkdirSync(this.tempDir, { recursive: true });
    }
  }

  public static getInstance(): BookStorageService {
    if (!BookStorageService.instance) {
      BookStorageService.instance = new BookStorageService();
    }
    return BookStorageService.instance;
  }

  public getStorageDirForBook(bookId: string): string {
    const dir = path.join(this.storageBaseDir, bookId);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    return dir;
  }

  public getPagesDirForBook(bookId: string): string {
    const pagesDir = path.join(this.getStorageDirForBook(bookId), 'pages');
    if (!fs.existsSync(pagesDir)) {
      fs.mkdirSync(pagesDir, { recursive: true });
    }
    return pagesDir;
  }

  /**
   * Validates PDF magic bytes (%PDF) from file path
   */
  public validatePdfMagicBytes(filePath: string): boolean {
    const fd = fs.openSync(filePath, 'r');
    try {
      const buffer = Buffer.alloc(4);
      fs.readSync(fd, buffer, 0, 4, 0);
      return buffer.toString('utf-8') === '%PDF';
    } finally {
      fs.closeSync(fd);
    }
  }

  /**
   * Computes SHA-256 checksum of file in a streaming pass
   */
  public async computeFileChecksum(filePath: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const hash = crypto.createHash('sha256');
      const stream = fs.createReadStream(filePath);
      stream.on('data', (data) => hash.update(data));
      stream.on('end', () => resolve(hash.digest('hex')));
      stream.on('error', (err) => reject(err));
    });
  }

  /**
   * Ingests an uploaded temporary PDF file into permanent storage,
   * creates the BookSource and 1-to-1 Subject records in PostgreSQL.
   */
  public async saveUploadedBook(
    tempFilePath: string,
    metadata: BookUploadInput
  ): Promise<{ bookSource: BookSource; subject: Subject; isDuplicate: boolean }> {
    if (!fs.existsSync(tempFilePath)) {
      throw new Error(`Uploaded temporary file not found at: ${tempFilePath}`);
    }

    // 1. Verify PDF Magic Bytes
    const isPdf = this.validatePdfMagicBytes(tempFilePath);
    if (!isPdf) {
      fs.unlinkSync(tempFilePath);
      throw new Error('Invalid file format: File header is not a valid PDF (%PDF)');
    }

    // 2. Compute Checksum
    const checksum = await this.computeFileChecksum(tempFilePath);
    const stats = fs.statSync(tempFilePath);

    // 3. Duplicate Check
    const existing = await prisma.bookSource.findUnique({
      where: { fileChecksum: checksum },
      include: { subject: true },
    });

    if (existing) {
      // Cleanup temp file
      if (fs.existsSync(tempFilePath)) {
        fs.unlinkSync(tempFilePath);
      }
      return {
        bookSource: existing,
        subject: existing.subject,
        isDuplicate: true,
      };
    }

    // 4. Derive clean Subject slug from Title & Edition
    const baseSlug = metadata.title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '');
    const editionSuffix = metadata.edition
      ? `-${metadata.edition.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`
      : '';
    let finalSlug = `${baseSlug}${editionSuffix}`;

    // Ensure subject slug uniqueness
    const existingSubject = await prisma.subject.findUnique({ where: { slug: finalSlug } });
    if (existingSubject) {
      finalSlug = `${finalSlug}-${Date.now().toString(36)}`;
    }
    const subjectId = finalSlug;

    // 5. Create Subject and BookSource transactionally
    const result = await prisma.$transaction(async (tx) => {
      // A. Create new Subject representing the book
      const subject = await tx.subject.create({
        data: {
          id: subjectId,
          slug: finalSlug,
          name: metadata.title.trim(),
          description: `Educational material imported from ${metadata.title}${metadata.author ? ` by ${metadata.author}` : ''}.`,
          displayOrder: 100,
          isActive: false, // Inactive until published by admin
        },
      });

      // B. Create BookSource
      const bookSource = await tx.bookSource.create({
        data: {
          subjectId: subject.id,
          title: metadata.title.trim(),
          author: metadata.author ? metadata.author.trim() : null,
          edition: metadata.edition ? metadata.edition.trim() : null,
          isbn: metadata.isbn ? metadata.isbn.trim() : null,
          storagePath: '', // Will update after moving file to permanent directory
          fileSizeBytes: BigInt(stats.size),
          fileChecksum: checksum,
          status: 'UPLOADED',
        },
      });

      return { subject, bookSource };
    });

    // 6. Move file to permanent storage: storage/books/{bookId}/original.pdf
    const bookDir = this.getStorageDirForBook(result.bookSource.id);
    const permanentPath = path.join(bookDir, 'original.pdf');
    fs.copyFileSync(tempFilePath, permanentPath);
    fs.unlinkSync(tempFilePath);

    // Update permanent storage path
    const updatedBookSource = await prisma.bookSource.update({
      where: { id: result.bookSource.id },
      data: { storagePath: permanentPath },
    });

    return {
      bookSource: updatedBookSource,
      subject: result.subject,
      isDuplicate: false,
    };
  }

  /**
   * Cleans up all stored files and directories for a book on disk.
   */
  public deleteBookStorage(bookId: string): void {
    try {
      const dir = path.join(this.storageBaseDir, bookId);
      if (fs.existsSync(dir)) {
        fs.rmSync(dir, { recursive: true, force: true });
        console.log(`[BookStorageService] Cleaned up storage directory for book ${bookId}`);
      }
    } catch (err: any) {
      console.warn(`[BookStorageService] Error cleaning up storage directory for book ${bookId}:`, err.message);
    }
  }
}

export const bookStorageService = BookStorageService.getInstance();
