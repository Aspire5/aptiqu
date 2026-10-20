import { prisma } from '../../../config/prisma';
export class BookCancellationService {
  private static instance: BookCancellationService;
  static getInstance() { return this.instance ??= new BookCancellationService(); }
  async cancel(bookId: string) {
    await prisma.bookSource.updateMany({where:{id:bookId},data:{processingCancelled:true,processingEpoch:{increment:1}}});
  }
  async isCancelled(bookId: string) {
    const book=await prisma.bookSource.findUnique({where:{id:bookId},select:{processingCancelled:true}});
    return !book || book.processingCancelled;
  }
  async reset(bookId: string) {
    await prisma.bookSource.updateMany({where:{id:bookId},data:{processingCancelled:false}});
  }
  async checkAndThrowIfCancelled(bookId: string, _location?: string) {
    if (await this.isCancelled(bookId)) throw new Error('BOOK_INGESTION_CANCELLED');
  }
}
export const bookCancellationService=BookCancellationService.getInstance();
