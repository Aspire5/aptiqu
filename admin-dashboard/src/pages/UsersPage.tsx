import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import { 
  Search, 
  Trash2, 
  AlertTriangle, 
  X, 
  Flame, 
  Coins
} from 'lucide-react';

export const UsersPage: React.FC = () => {
  const [users, setUsers] = useState<any[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  // Search & Pagination
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Hard Delete Modal
  const [deleteModal, setDeleteModal] = useState<{ open: boolean; user?: any }>({ open: false });
  const [confirmInput, setConfirmInput] = useState('');
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    fetchStats();
  }, []);

  useEffect(() => {
    fetchUsers();
  }, [page, search]);

  const fetchStats = async () => {
    try {
      const res = await api.getUserStats();
      if (res.data?.success) {
        setStats(res.data.data);
      }
    } catch (err) {
      console.error('Failed to load user stats', err);
    }
  };

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const res = await api.getUsers({ page, limit: 12, search: search.trim() });
      if (res.data?.success) {
        setUsers(res.data.data.users || []);
        setTotalPages(res.data.data.pagination?.totalPages || 1);
        setTotalCount(res.data.data.pagination?.total || 0);
      }
    } catch (err) {
      console.error('Failed to load users', err);
    } finally {
      setLoading(false);
    }
  };

  const handleHardDelete = async () => {
    if (!deleteModal.user) return;
    if (confirmInput.trim().toUpperCase() !== 'DELETE') {
      alert('Please type DELETE to confirm permanent deletion.');
      return;
    }

    setDeleting(true);
    try {
      await api.hardDeleteUser(deleteModal.user.id);
      setDeleteModal({ open: false });
      setConfirmInput('');
      fetchUsers();
      fetchStats();
    } catch (err: any) {
      alert(`Delete failed: ${err.response?.data?.message || err.message}`);
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div>
      {/* 1. DEMOGRAPHICS ANALYTICS OVERVIEW */}
      {stats && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginBottom: '24px' }}>
          {/* Total & Registration */}
          <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
            <span style={{ fontSize: '12px', color: '#7b809a' }}>User Base</span>
            <h3 style={{ fontSize: '24px', fontWeight: 700, marginTop: '4px' }}>{stats.totalUsers ?? 0}</h3>
            <div style={{ display: 'flex', gap: '6px', marginTop: '6px', fontSize: '11px' }}>
              <span className="badge badge-success">Completed: {stats.registration?.completed || 0}</span>
              <span className="badge badge-warning">Pending: {stats.registration?.pending || 0}</span>
            </div>
          </div>

          {/* Gender Split */}
          <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
            <span style={{ fontSize: '12px', color: '#7b809a' }}>Gender Distribution</span>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginTop: '8px' }}>
              <span className="badge badge-info">Male: {stats.byGender?.MALE || 0}</span>
              <span className="badge badge-danger">Female: {stats.byGender?.FEMALE || 0}</span>
              <span className="badge badge-neutral">Unspecified: {stats.byGender?.UNSPECIFIED || 0}</span>
            </div>
          </div>

          {/* Top Countries */}
          <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
            <span style={{ fontSize: '12px', color: '#7b809a' }}>Geographic Presence</span>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginTop: '8px' }}>
              {stats.byCountry?.length > 0 ? (
                stats.byCountry.slice(0, 3).map((c: any, i: number) => (
                  <span key={i} className="badge badge-neutral">
                    {c.name}: {c.count}
                  </span>
                ))
              ) : (
                <span style={{ fontSize: '12px', color: '#94a3b8' }}>No location data yet</span>
              )}
            </div>
          </div>

          {/* Religions */}
          <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
            <span style={{ fontSize: '12px', color: '#7b809a' }}>Religion Demographics</span>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginTop: '8px' }}>
              {stats.byReligion?.length > 0 ? (
                stats.byReligion.slice(0, 3).map((r: any, i: number) => (
                  <span key={i} className="badge badge-neutral">
                    {r.name}: {r.count}
                  </span>
                ))
              ) : (
                <span style={{ fontSize: '12px', color: '#94a3b8' }}>No religion data yet</span>
              )}
            </div>
          </div>
        </div>
      )}

      {/* 2. USER SEARCH & TABLE */}
      <div className="card" style={{ padding: '20px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <h3 style={{ fontSize: '18px', fontWeight: 700 }}>Registered Learners & Accounts</h3>
            <p style={{ fontSize: '12px', color: '#7b809a' }}>
              Showing {totalCount} total registered accounts. Search by typing a user's Gmail.
            </p>
          </div>

          <div className="search-input-wrap" style={{ maxWidth: '360px' }}>
            <Search size={16} />
            <input
              type="text"
              className="input-custom"
              placeholder="Search user by Gmail or name..."
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </div>
        </div>

        {/* User Table */}
        <div className="table-responsive">
          <table className="table-custom">
            <thead>
              <tr>
                <th>Learner</th>
                <th>Gmail / Email</th>
                <th>Level & XP</th>
                <th>Streak & Coins</th>
                <th>Demographics</th>
                <th>Joined</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: '#7b809a' }}>
                    Loading user records...
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: '#7b809a' }}>
                    No users found matching your search.
                  </td>
                </tr>
              ) : (
                users.map((u) => {
                  const initials = u.profile?.displayName?.[0]?.toUpperCase() || u.email?.[0]?.toUpperCase() || 'U';
                  const joinedDate = new Date(u.createdAt).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric',
                  });

                  return (
                    <tr key={u.id}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                          <div style={{
                            width: '34px',
                            height: '34px',
                            borderRadius: '50%',
                            background: 'linear-gradient(195deg, #49a3f1, #1a73e8)',
                            color: 'white',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontWeight: 700,
                            fontSize: '13px',
                          }}>
                            {initials}
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, color: '#1e293b' }}>
                              {u.profile?.displayName || 'Learner'}
                            </div>
                            <span className={`badge ${u.isRegistrationComplete ? 'badge-success' : 'badge-warning'}`} style={{ fontSize: '9px', padding: '2px 6px' }}>
                              {u.isRegistrationComplete ? 'Verified' : 'Incomplete'}
                            </span>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span style={{ fontSize: '13px', fontFamily: 'monospace', color: '#334155' }}>
                          {u.email}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontSize: '13px', fontWeight: 600 }}>
                          Level {u.gameStats?.level || u.progress?.level || 1}
                        </div>
                        <div style={{ fontSize: '11px', color: '#7b809a' }}>
                          {u.progress?.totalXp || 0} XP
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#d81b60', fontSize: '13px', fontWeight: 600 }}>
                            <Flame size={14} />
                            <span>{u.gameStats?.streak || 0}</span>
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#f57f17', fontSize: '13px', fontWeight: 600 }}>
                            <Coins size={14} />
                            <span>{u.gameStats?.coins || 0}</span>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div style={{ fontSize: '12px', color: '#475569' }}>
                          {u.profile?.country || 'Unknown'} • {u.profile?.gender || 'N/A'}
                        </div>
                        <div style={{ fontSize: '11px', color: '#94a3b8' }}>
                          {u.profile?.religion || 'N/A'}
                        </div>
                      </td>
                      <td>
                        <div style={{ fontSize: '12px', color: '#64748b' }}>
                          {joinedDate}
                        </div>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button
                          className="btn-danger"
                          style={{ padding: '6px 12px', fontSize: '11px' }}
                          title="Hard Delete user and all records"
                          onClick={() => {
                            setDeleteModal({ open: true, user: u });
                            setConfirmInput('');
                          }}
                        >
                          <Trash2 size={13} />
                          <span>HARD DELETE</span>
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="pagination">
          <span style={{ fontSize: '13px', color: '#7b809a' }}>
            Page {page} of {totalPages} ({totalCount} total)
          </span>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              className="pagination-btn"
              disabled={page <= 1}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              Previous
            </button>
            <button
              className="pagination-btn"
              disabled={page >= totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              Next
            </button>
          </div>
        </div>
      </div>

      {/* ============================================================== */}
      {/* HARD DELETE CONFIRMATION MODAL */}
      {/* ============================================================== */}
      {deleteModal.open && deleteModal.user && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '480px' }}>
            <div className="modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#c62828' }}>
                <AlertTriangle size={20} />
                <h3 className="modal-title">Confirm Permanent Hard Delete</h3>
              </div>
              <button 
                onClick={() => setDeleteModal({ open: false })} 
                style={{ background: 'none', border: 'none', cursor: 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            <div className="modal-body">
              <p style={{ fontSize: '14px', lineHeight: 1.5, color: '#334155' }}>
                You are about to permanently delete <strong>{deleteModal.user.email}</strong> ({deleteModal.user.profile?.displayName || 'Learner'}).
              </p>

              <div style={{
                background: '#fff1f2',
                border: '1px solid #fecdd3',
                padding: '12px 14px',
                borderRadius: '8px',
                marginTop: '10px',
                fontSize: '12px',
                color: '#9f1239',
              }}>
                <strong>Warning:</strong> This will cascade and permanently erase:
                <ul style={{ paddingLeft: '18px', marginTop: '4px' }}>
                  <li>User profile, tokens, and credentials</li>
                  <li>All progress, levels, game stats, and XP events</li>
                  <li>PvP match history, answers, and practice sessions</li>
                  <li>Daily streak challenge participation and history</li>
                </ul>
              </div>

              <div className="form-group" style={{ marginTop: '16px' }}>
                <label className="form-label">
                  To confirm, type <strong>DELETE</strong> below:
                </label>
                <input
                  type="text"
                  className="form-control"
                  placeholder="Type DELETE"
                  value={confirmInput}
                  onChange={(e) => setConfirmInput(e.target.value)}
                  autoFocus
                />
              </div>
            </div>

            <div className="modal-footer">
              <button 
                className="btn-secondary" 
                onClick={() => setDeleteModal({ open: false })}
                disabled={deleting}
              >
                Cancel
              </button>
              <button
                className="btn-danger"
                disabled={confirmInput.trim().toUpperCase() !== 'DELETE' || deleting}
                onClick={handleHardDelete}
              >
                <Trash2 size={16} />
                <span>{deleting ? 'Erasing User...' : 'Permanently Delete User'}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
