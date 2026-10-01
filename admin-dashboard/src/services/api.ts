import axios from 'axios';

// Use base URL from env if configured, or default to relative /api/v1/admin
const API_BASE_URL = import.meta.env.VITE_API_URL 
  ? `${import.meta.env.VITE_API_URL}/api/v1/admin`
  : '/api/v1/admin';

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to inject Admin JWT token
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('aptiqu_admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor to handle unauthorized errors
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && !window.location.pathname.includes('/login')) {
      localStorage.removeItem('aptiqu_admin_token');
      localStorage.removeItem('aptiqu_admin_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const api = {
  // Auth
  login: (credentials: { username: string; password: string }) =>
    apiClient.post('/auth/login', credentials),
  getMe: () => apiClient.get('/auth/me'),

  // Dashboard Stats
  getDashboardStats: () => apiClient.get('/dashboard/stats'),

  // Syllabus
  getSyllabus: () => apiClient.get('/syllabus'),
  
  createSubject: (data: any) => apiClient.post('/syllabus/subjects', data),
  updateSubject: (id: string, data: any) => apiClient.put(`/syllabus/subjects/${id}`, data),
  deleteSubject: (id: string, hard = false) => apiClient.delete(`/syllabus/subjects/${id}?hard=${hard}`),

  createTopic: (data: any) => apiClient.post('/syllabus/topics', data),
  updateTopic: (id: string, data: any) => apiClient.put(`/syllabus/topics/${id}`, data),
  deleteTopic: (id: string, hard = false) => apiClient.delete(`/syllabus/topics/${id}?hard=${hard}`),

  createSubtopic: (data: any) => apiClient.post('/syllabus/subtopics', data),
  updateSubtopic: (id: string, data: any) => apiClient.put(`/syllabus/subtopics/${id}`, data),
  deleteSubtopic: (id: string, hard = false) => apiClient.delete(`/syllabus/subtopics/${id}?hard=${hard}`),

  getScript: (id: string) => apiClient.get(`/syllabus/scripts/${id}`),
  createScript: (data: any) => apiClient.post('/syllabus/scripts', data),
  updateScript: (id: string, data: any) => apiClient.put(`/syllabus/scripts/${id}`, data),

  // Syllabus Reordering & Reusability
  reorderTopics: (subjectId: string, topicIds: string[]) =>
    apiClient.put(`/syllabus/subjects/${subjectId}/reorder-topics`, { topicIds }),
  reorderSubtopics: (topicId: string, subtopicIds: string[]) =>
    apiClient.put(`/syllabus/topics/${topicId}/reorder-subtopics`, { subtopicIds }),
  linkTopic: (subjectId: string, topicId: string) =>
    apiClient.post(`/syllabus/subjects/${subjectId}/link-topic`, { topicId }),
  unlinkTopic: (subjectId: string, topicId: string) =>
    apiClient.delete(`/syllabus/subjects/${subjectId}/link-topic/${topicId}`),
  linkSubtopic: (topicId: string, subtopicId: string) =>
    apiClient.post(`/syllabus/topics/${topicId}/link-subtopic`, { subtopicId }),
  unlinkSubtopic: (topicId: string, subtopicId: string) =>
    apiClient.delete(`/syllabus/topics/${topicId}/link-subtopic/${subtopicId}`),
  getAvailableTopics: () => apiClient.get('/syllabus/available-topics'),
  getAvailableSubtopics: () => apiClient.get('/syllabus/available-subtopics'),

  // Questions
  getQuestions: (params: any) => apiClient.get('/questions', { params }),
  getQuestionStats: () => apiClient.get('/questions/stats'),
  createQuestion: (data: any) => apiClient.post('/questions', data),
  updateQuestion: (id: string, data: any) => apiClient.put(`/questions/${id}`, data),
  relinkQuestion: (id: string, newSubtopicId: string) => apiClient.put(`/questions/${id}/link`, { newSubtopicId }),
  deleteQuestion: (id: string) => apiClient.delete(`/questions/${id}`),
  bulkImportQuestions: (questions: any[], defaultSubtopicId?: string) =>
    apiClient.post('/questions/bulk-import', { questions, defaultSubtopicId }),

  // Users
  getUsers: (params: any) => apiClient.get('/users', { params }),
  getUserStats: () => apiClient.get('/users/stats'),
  hardDeleteUser: (id: string) => apiClient.delete(`/users/${id}`),
};
