import React from 'react';
import { NavLink, Outlet, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { 
  LayoutDashboard, 
  Layers, 
  HelpCircle, 
  Users, 
  LogOut, 
  Server,
  Sparkles,
  BookOpen,
  Award
} from 'lucide-react';

export const AdminLayout: React.FC = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    logout();
    navigate('/dashboard/login');
  };

  const getPageTitle = () => {
    if (location.pathname.includes('/dashboard/books')) return 'Book Ingestion Engine';
    if (location.pathname.includes('/dashboard/syllabus')) return 'Syllabus & Curriculum';
    if (location.pathname.includes('/dashboard/questions')) return 'Question Bank';
    if (location.pathname.includes('/dashboard/ai-prompts')) return 'AI Prompts Control Center';
    if (location.pathname.includes('/dashboard/achievements')) return 'Achievements';
    if (location.pathname.includes('/dashboard/users')) return 'User Management';
    return 'Executive SaaS Dashboard';
  };

  return (
    <div className="app-container">
      {/* Sidebar matching Material Dashboard 2 Dark Theme */}
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="sidebar-brand-icon" style={{ overflow: 'hidden', padding: 0, background: 'transparent' }}>
            <img 
              src="/logo.jpeg" 
              alt="AptiQu Logo" 
              style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: '10px' }} 
            />
          </div>
          <div className="sidebar-brand-text">
            <h2>AptiQu Console</h2>
            <span>ADMIN CONTROL PANEL</span>
          </div>
        </div>

        <nav className="sidebar-nav">
          <NavLink
            to="/dashboard"
            end
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <LayoutDashboard size={18} />
            <span>Dashboard</span>
          </NavLink>

          <NavLink
            to="/dashboard/syllabus"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <Layers size={18} />
            <span>Syllabus</span>
          </NavLink>

          <NavLink
            to="/dashboard/books"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <BookOpen size={18} />
            <span>Book Ingestion</span>
          </NavLink>

          <NavLink
            to="/dashboard/questions"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <HelpCircle size={18} />
            <span>Questions</span>
          </NavLink>

          <NavLink
            to="/dashboard/ai-prompts"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <Sparkles size={18} />
            <span>AI Prompts</span>
          </NavLink>

          <NavLink
            to="/dashboard/users"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <Users size={18} />
            <span>Users</span>
          </NavLink>
          <NavLink to="/dashboard/achievements" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
            <Award size={18} /><span>Achievements</span>
          </NavLink>
        </nav>

        <div className="sidebar-footer">
          <div className="sidebar-user-info">
            <div className="user-avatar-circle">
              {user?.username?.[0]?.toUpperCase() || 'A'}
            </div>
            <div className="sidebar-user-name">
              {user?.username || 'shagun5750'}
            </div>
          </div>
          <button 
            className="sidebar-logout-btn" 
            onClick={handleLogout}
            title="Log out"
          >
            <LogOut size={16} />
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="main-wrapper">
        <header className="top-navbar">
          <div className="breadcrumb-area">
            <span className="breadcrumb-path">Pages / {getPageTitle()}</span>
            <h1 className="breadcrumb-title">{getPageTitle()}</h1>
          </div>

          <div className="top-navbar-actions">
            <button 
              className="btn-secondary" 
              onClick={() => window.location.reload()}
              title="Refresh console state"
            >
              <Server size={14} />
              <span>Refresh</span>
            </button>
          </div>
        </header>

        {/* Content View */}
        <Outlet />
      </main>
    </div>
  );
};
