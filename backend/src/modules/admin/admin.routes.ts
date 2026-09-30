import { Router } from 'express';
import { authenticateAdmin } from './admin.middleware';
import { AdminAuthController } from './admin-auth.controller';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminSyllabusController } from './admin-syllabus.controller';
import { AdminQuestionsController } from './admin-questions.controller';
import { AdminUsersController } from './admin-users.controller';
import { AdminController } from './admin.controller';

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

// Script Inspection & Versioning
router.get('/syllabus/scripts/:id', AdminSyllabusController.getScript);
router.post('/syllabus/scripts', AdminSyllabusController.createScript);
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

export default router;
