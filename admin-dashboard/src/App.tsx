import './index.css';
import { AchievementsPage } from './pages/AchievementsPage';
import React from 'react';
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { AdminLayout } from './components/layout/AdminLayout';
import { LoginPage } from './pages/LoginPage';
import { DashboardPage } from './pages/DashboardPage';
import { SyllabusPage } from './pages/SyllabusPage';
import { QuestionsPage } from './pages/QuestionsPage';
import { UsersPage } from './pages/UsersPage';
import { AiPromptsPage } from './pages/AiPromptsPage';
import { BooksPage } from './pages/BooksPage';


const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return (
      <div style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#f0f2f5',
        color: '#7b809a',
        fontFamily: 'sans-serif',
      }}>
        Initializing Aptiqu Admin Console...
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/dashboard/login" replace />;
  }

  return <>{children}</>;
};

// Preserve old bookmarks, including query filters and hashes.
const LegacyAdminRedirect = ({ path }: { path: string }) => {
  const { search, hash } = useLocation();
  return <Navigate to={`/dashboard/${path}${search}${hash}`} replace />;
};

export const App: React.FC = () => {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/dashboard/login" element={<LoginPage />} />

          <Route
            path="/dashboard"
            element={
              <ProtectedRoute>
                <AdminLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="syllabus" element={<SyllabusPage />} />
            <Route path="books" element={<BooksPage />} />
            <Route path="questions" element={<QuestionsPage />} />
            <Route path="ai-prompts" element={<AiPromptsPage />} />
            <Route path="achievements" element={<AchievementsPage />} />
            <Route path="users" element={<UsersPage />} />
          </Route>

          {['login', 'syllabus', 'books', 'questions', 'ai-prompts', 'achievements', 'users'].map((path) => (
            <Route key={path} path={`/${path}`} element={<LegacyAdminRedirect path={path} />} />
          ))}
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
};

export default App;
