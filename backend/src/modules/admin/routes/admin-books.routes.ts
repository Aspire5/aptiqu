import { randomUUID } from 'node:crypto';
import { ENV } from '../../../config/env';
import { PublicError } from '../../../security/errors';
import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { AdminBooksController } from '../controllers/admin-books.controller';

const router = Router();

const tempDir=ENV.BOOK_TEMP_ROOT;

// Multer disk storage config for large PDF streaming
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    fs.promises.mkdir(tempDir,{recursive:true,mode:0o700}).then(()=>cb(null,tempDir),error=>cb(error,tempDir));
  },
  filename: (_req, file, cb) => {
    cb(null, `upload-${randomUUID()}.pdf`);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: ENV.BOOK_UPLOAD_MAX_BYTES, files:1, fields:6, fieldSize:20000, parts:7,
  },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'application/pdf' || file.originalname.toLowerCase().endsWith('.pdf')) {
      cb(null, true);
    } else {
      cb(new PublicError('Only PDF files are supported.'));
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
router.post('/:id/cancel', AdminBooksController.cancelProcessing);
router.delete('/:id', AdminBooksController.deleteBook);

export default router;
