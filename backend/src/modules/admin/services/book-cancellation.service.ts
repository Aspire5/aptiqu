export class BookCancellationService {
  private static instance: BookCancellationService;
  private cancelledBooks: Set<string> = new Set();

  private constructor() {}

  public static getInstance(): BookCancellationService {
    if (!BookCancellationService.instance) {
      BookCancellationService.instance = new BookCancellationService();
    }
    return BookCancellationService.instance;
  }

  public cancel(bookId: string): void {
    this.cancelledBooks.add(bookId);
    console.log(`[BookCancellationService] Book ${bookId} marked as CANCELLED.`);
  }

  public isCancelled(bookId: string): boolean {
    return this.cancelledBooks.has(bookId);
  }

  public reset(bookId: string): void {
    this.cancelledBooks.delete(bookId);
  }

  public checkAndThrowIfCancelled(bookId: string, location?: string): void {
    if (this.isCancelled(bookId)) {
      const msg = `BOOK_INGESTION_CANCELLED: Book ${bookId} was cancelled${location ? ` at ${location}` : ''}.`;
      console.log(`[BookCancellationService] ${msg}`);
      throw new Error(msg);
    }
  }
}

export const bookCancellationService = BookCancellationService.getInstance();
