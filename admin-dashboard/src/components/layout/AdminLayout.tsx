import React from 'react';
import { NavLink, Outlet, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { 
  LayoutDashboard, 
  Layers, 
  HelpCircle, 
  Users, 
  LogOut, 
  Sparkles,
  Server
} from 'lucide-react';

export const AdminLayout: React.FC = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const getPageTitle = () => {
    if (location.pathname.includes('/syllabus')) return 'Syllabus & Curriculum';
    if (location.pathname.includes('/questions')) return 'Question Bank';
    if (location.pathname.includes('/users')) return 'User Management';
    return 'Executive SaaS Dashboard';
  };

  return (
    <div className="app-container">
      {/* Sidebar matching Material Dashboard 2 Dark Theme */}
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="sidebar-brand-icon">
            <Sparkles size={20} />
          </div>
          <div className="sidebar-brand-text">
            <h2>Aptiqu Console</h2>
            <span>Admin Control Panel</span>
          </div>
        </div>

        <nav className="sidebar-nav">
          <NavLink
            to="/dashboard"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <LayoutDashboard size={18} />
            <span>Dashboard</span>
          </NavLink>

          <NavLink
            to="/syllabus"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <Layers size={18} />
            <span>Syllabus</span>
          </NavLink>

          <NavLink
            to="/questions"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <HelpCircle size={18} />
            <span>Questions</span>
          </NavLink>

          <NavLink
            to="/users"
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <Users size={18} />
            <span>Users</span>
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
