import { Router } from 'express';
import { authenticateAdmin } from './admin.middleware';
import { AdminAuthController } from './admin-auth.controller';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminSyllabusController } from './admin-syllabus.controller';
import { AdminQuestionsController } from './admin-questions.controller';
import { AdminUsersController } from './admin-users.controller';
import { AdminAiPromptsController } from './admin-ai-prompts.controller';
import { AdminController } from './admin.controller';
import adminBooksRoutes from './routes/admin-books.routes';

const router = Router();


// ==========================================
// 1. PUBLIC ADMIN AUTH ROUTE
// ==========================================
router.post('/auth/login', AdminAuthController.login);

// ==========================================
// PROTECTED ADMIN ROUTES (Require Admin JWT)
// ==========================================
router.use(authenticateAdmin);

// Auth verification
router.get('/auth/me', AdminAuthController.me);

// 2. Dashboard Analytics
router.get('/dashboard/stats', AdminDashboardController.getStats);

// 3. Syllabus Management
router.get('/syllabus', AdminSyllabusController.getSyllabus);

// Subject CRUD
router.post('/syllabus/subjects', AdminSyllabusController.createSubject);
router.put('/syllabus/subjects/:id', AdminSyllabusController.updateSubject);
router.delete('/syllabus/subjects/:id', AdminSyllabusController.deleteSubject);

// Topic CRUD
router.post('/syllabus/topics', AdminSyllabusController.createTopic);
router.put('/syllabus/topics/:id', AdminSyllabusController.updateTopic);
router.delete('/syllabus/topics/:id', AdminSyllabusController.deleteTopic);

// Subtopic CRUD
router.post('/syllabus/subtopics', AdminSyllabusController.createSubtopic);
router.put('/syllabus/subtopics/:id', AdminSyllabusController.updateSubtopic);
router.delete('/syllabus/subtopics/:id', AdminSyllabusController.deleteSubtopic);

// Reordering
router.put('/syllabus/subjects/:subjectId/reorder-topics', AdminSyllabusController.reorderTopics);
router.put('/syllabus/topics/:topicId/reorder-subtopics', AdminSyllabusController.reorderSubtopics);

// Reusability / Linking
router.get('/syllabus/available-topics', AdminSyllabusController.getAvailableTopics);
router.get('/syllabus/available-subtopics', AdminSyllabusController.getAvailableSubtopics);
router.post('/syllabus/subjects/:subjectId/link-topic', AdminSyllabusController.linkTopic);
router.delete('/syllabus/subjects/:subjectId/topics/:topicId/unlink', AdminSyllabusController.unlinkTopic);
router.post('/syllabus/topics/:topicId/link-subtopic', AdminSyllabusController.linkSubtopic);
router.delete('/syllabus/topics/:topicId/subtopics/:subtopicId/unlink', AdminSyllabusController.unlinkSubtopic);

// Script Inspection & Versioning
router.get('/syllabus/scripts/:id', AdminSyllabusController.getScript);
router.post('/syllabus/scripts', AdminSyllabusController.createScript);
router.post('/syllabus/scripts/import', AdminSyllabusController.importScript);
router.put('/syllabus/scripts/:id', AdminSyllabusController.updateScript);

// 4. Questions Management
router.get('/questions', AdminQuestionsController.listQuestions);
router.get('/questions/stats', AdminQuestionsController.getStats);
router.post('/questions', AdminQuestionsController.createQuestion);
router.put('/questions/:id', AdminQuestionsController.updateQuestion);
router.put('/questions/:id/link', AdminQuestionsController.relinkQuestion);
router.delete('/questions/:id', AdminQuestionsController.deleteQuestion);
router.post('/questions/bulk-import', AdminQuestionsController.bulkImport);

// Legacy AI generation endpoints
router.post('/questions/generate', AdminController.triggerQuestionGeneration);
router.post('/pvp-sets/generate', AdminController.triggerPvpSetGeneration);
router.post('/questions/manual', AdminController.createManualQuestion);

// 5. Users Management
router.get('/users', AdminUsersController.listUsers);
router.get('/users/stats', AdminUsersController.getUserStats);
router.delete('/users/:id', AdminUsersController.hardDeleteUser);

// 6. Timing & System Configuration
router.put('/config/timing', AdminController.updateTimingConfig);

// 7. AI Prompts Management
router.get('/ai-prompts', AdminAiPromptsController.listPrompts);
router.get('/ai-prompts/:key', AdminAiPromptsController.getPrompt);
router.put('/ai-prompts/:key', AdminAiPromptsController.updateDraft);
router.post('/ai-prompts/:key/publish', AdminAiPromptsController.publishPrompt);
router.post('/ai-prompts/:key/reset-default', AdminAiPromptsController.resetToDefault);

// 8. Book Content Ingestion Engine
router.use('/books', adminBooksRoutes);

export default router;

