import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { AdminBooksController } from '../controllers/admin-books.controller';

const router = Router();

// Ensure temp storage directory exists
const tempDir = path.resolve(process.cwd(), 'storage/temp');
if (!fs.existsSync(tempDir)) {
  fs.mkdirSync(tempDir, { recursive: true });
}

// Multer disk storage config for large PDF streaming
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, tempDir);
  },
  filename: (_req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    cb(null, `${uniqueSuffix}-${sanitizedName}`);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 150 * 1024 * 1024, // 150 MB max
  },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'application/pdf' || file.originalname.toLowerCase().endsWith('.pdf')) {
      cb(null, true);
    } else {
      cb(new Error('Only PDF files are supported.'));
    }
  },
});

// Book routes
router.post('/upload', upload.single('file'), AdminBooksController.uploadBook);
router.get('/', AdminBooksController.listBooks);
router.get('/:id', AdminBooksController.getBook);
router.get('/:id/status', AdminBooksController.getStatus);
router.get('/:id/topics', AdminBooksController.getTopics);
router.put('/:id/topics', AdminBooksController.updateTopics);
router.get('/:id/subtopics', AdminBooksController.getSubtopics);
router.get('/:id/content-preview', AdminBooksController.getContentPreview);
router.post('/:id/publish', AdminBooksController.publishBook);
router.post('/:id/retry', AdminBooksController.retryStage);
router.delete('/:id', AdminBooksController.deleteBook);

export default router;
