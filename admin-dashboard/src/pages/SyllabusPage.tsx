import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import { 
  Plus, 
  Edit3, 
  Trash2, 
  ChevronRight, 
  ChevronDown, 
  FileCode, 
  Layers, 
  AlertTriangle, 
  Check, 
  X
} from 'lucide-react';

export const SyllabusPage: React.FC = () => {
  const [syllabus, setSyllabus] = useState<any[]>([]);
  const [scripts, setScripts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedSubjects, setExpandedSubjects] = useState<Record<string, boolean>>({});
  const [expandedTopics, setExpandedTopics] = useState<Record<string, boolean>>({});

  // Modals
  const [subjectModal, setSubjectModal] = useState<{ open: boolean; editItem?: any }>({ open: false });
  const [topicModal, setTopicModal] = useState<{ open: boolean; subjectId?: string; editItem?: any }>({ open: false });
  const [subtopicModal, setSubtopicModal] = useState<{ open: boolean; topicId?: string; editItem?: any }>({ open: false });
  const [deleteModal, setDeleteModal] = useState<{
    open: boolean;
    type: 'subject' | 'topic' | 'subtopic';
    id: string;
    title: string;
    hardDelete: boolean;
  } | null>(null);

  // Script Inspector / Editor Modal
  const [scriptModal, setScriptModal] = useState<{
    open: boolean;
    scriptId?: string;
    subtopicId?: string;
    topicId?: string;
    subjectId?: string;
    title: string;
    status: string;
    definitionJson: string;
    isNew: boolean;
  } | null>(null);
  const [scriptJsonError, setScriptJsonError] = useState<string | null>(null);

  useEffect(() => {
    fetchSyllabus();
  }, []);

  const fetchSyllabus = async () => {
    setLoading(true);
    try {
      const res = await api.getSyllabus();
      if (res.data?.success) {
        setSyllabus(res.data.data.subjects || []);
        setScripts(res.data.data.scripts || []);
        // Automatically expand the first subject
        if (res.data.data.subjects?.[0]?.id) {
          setExpandedSubjects({ [res.data.data.subjects[0].id]: true });
        }
      }
    } catch (err) {
      console.error('Failed to load syllabus', err);
    } finally {
      setLoading(false);
    }
  };

  const toggleSubject = (id: string) => {
    setExpandedSubjects((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  const toggleTopic = (id: string) => {
    setExpandedTopics((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  // Helper to find script attached to topic or subtopic
  const getAttachedScript = (topicId: string, subtopicId?: string) => {
    if (subtopicId) {
      const subMatch = scripts.find((s) => s.subtopicId === subtopicId);
      if (subMatch) return subMatch;
    }
    return scripts.find((s) => s.topicId === topicId && !s.subtopicId) || null;
  };

  // Delete handler
  const confirmDelete = async () => {
    if (!deleteModal) return;
    try {
      const { type, id, hardDelete } = deleteModal;
      if (type === 'subject') await api.deleteSubject(id, hardDelete);
      else if (type === 'topic') await api.deleteTopic(id, hardDelete);
      else if (type === 'subtopic') await api.deleteSubtopic(id, hardDelete);
      setDeleteModal(null);
      fetchSyllabus();
    } catch (err: any) {
      alert(`Deletion failed: ${err.response?.data?.message || err.message}`);
    }
  };

  // Open script viewer/editor
  const handleOpenScript = async (scriptId: string) => {
    try {
      const res = await api.getScript(scriptId);
      if (res.data?.success) {
        const { script, latestVersion } = res.data.data;
        setScriptModal({
          open: true,
          scriptId: script.id,
          subtopicId: script.subtopicId,
          topicId: script.topicId,
          subjectId: script.subjectId,
          title: script.title,
          status: script.status,
          definitionJson: JSON.stringify(latestVersion?.definition || {}, null, 2),
          isNew: false,
        });
        setScriptJsonError(null);
      }
    } catch (err: any) {
      alert(`Could not load script: ${err.message}`);
    }
  };

  // Save script changes or create new script
  const handleSaveScript = async () => {
    if (!scriptModal) return;
    try {
      let parsedDefinition;
      try {
        parsedDefinition = JSON.parse(scriptModal.definitionJson);
      } catch (e: any) {
        setScriptJsonError(`JSON Syntax Error: ${e.message}`);
        return;
      }

      if (scriptModal.isNew) {
        await api.createScript({
          title: scriptModal.title,
          subjectId: scriptModal.subjectId,
          topicId: scriptModal.topicId,
          subtopicId: scriptModal.subtopicId,
          definition: parsedDefinition,
          status: scriptModal.status,
        });
      } else if (scriptModal.scriptId) {
        await api.updateScript(scriptModal.scriptId, {
          title: scriptModal.title,
          status: scriptModal.status,
          definition: parsedDefinition,
        });
      }

      setScriptModal(null);
      fetchSyllabus();
    } catch (err: any) {
      alert(`Failed to save script: ${err.response?.data?.message || err.message}`);
    }
  };

  return (
    <div>
      {/* Header bar */}
      <div className="card-header-styled" style={{ marginBottom: '24px' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: 700 }}>Curriculum & Syllabus Hierarchy</h2>
          <p style={{ fontSize: '13px', color: '#7b809a' }}>
            Manage Subjects, Topics, Subtopics, and interactive Lesson Scripts
          </p>
        </div>
        <button
          className="btn-primary"
          onClick={() => setSubjectModal({ open: true })}
        >
          <Plus size={16} />
          <span>Add Subject</span>
        </button>
      </div>

      {loading ? (
        <div className="empty-state">
          <p>Loading syllabus structure...</p>
        </div>
      ) : syllabus.length === 0 ? (
        <div className="card empty-state">
          <Layers size={48} />
          <h3>No Curriculum Configured Yet</h3>
          <p>Create your first subject to start building topics and subtopics.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {syllabus.map((subject) => {
            const isSubExpanded = !!expandedSubjects[subject.id];
            return (
              <div key={subject.id} className="card" style={{ padding: '20px', marginBottom: 0 }}>
                {/* Subject Header */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div 
                    style={{ display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer', flex: 1 }}
                    onClick={() => toggleSubject(subject.id)}
                  >
                    <button style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#7b809a' }}>
                      {isSubExpanded ? <ChevronDown size={20} /> : <ChevronRight size={20} />}
                    </button>
                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span style={{ fontSize: '16px', fontWeight: 700, color: '#344767' }}>{subject.name}</span>
                        <span className={`badge ${subject.isActive ? 'badge-success' : 'badge-neutral'}`}>
                          {subject.isActive ? 'Active' : 'Inactive'}
                        </span>
                        <span style={{ fontSize: '11px', color: '#7b809a' }}>
                          ({subject.topics?.length || 0} Topics, {subject._count?.questions || 0} Questions)
                        </span>
                      </div>
                      {subject.description && (
                        <p style={{ fontSize: '12px', color: '#7b809a', marginTop: '2px' }}>{subject.description}</p>
                      )}
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <button
                      className="btn-secondary"
                      style={{ padding: '6px 12px', fontSize: '12px' }}
                      onClick={() => setTopicModal({ open: true, subjectId: subject.id })}
                    >
                      <Plus size={14} />
                      <span>Add Topic</span>
                    </button>
                    <button
                      className="btn-secondary"
                      style={{ padding: '6px 10px' }}
                      title="Edit Subject"
                      onClick={() => setSubjectModal({ open: true, editItem: subject })}
                    >
                      <Edit3 size={14} />
                    </button>
                    <button
                      className="btn-secondary"
                      style={{ padding: '6px 10px', color: '#ef5350' }}
                      title="Delete Subject"
                      onClick={() => setDeleteModal({
                        open: true,
                        type: 'subject',
                        id: subject.id,
                        title: subject.name,
                        hardDelete: false,
                      })}
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>

                {/* Topics Container */}
                {isSubExpanded && (
                  <div style={{ marginTop: '16px', paddingLeft: '28px', borderLeft: '2px solid #e2e8f0', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {(!subject.topics || subject.topics.length === 0) ? (
                      <p style={{ fontSize: '12px', color: '#7b809a', padding: '8px 0' }}>No topics under this subject.</p>
                    ) : (
                      subject.topics.map((topic: any) => {
                        const isTopicExpanded = !!expandedTopics[topic.id];
                        return (
                          <div key={topic.id} style={{ background: '#f8fafc', padding: '14px 18px', borderRadius: '10px', border: '1px solid #e2e8f0' }}>
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                              <div
                                style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', flex: 1 }}
                                onClick={() => toggleTopic(topic.id)}
                              >
                                {isTopicExpanded ? <ChevronDown size={18} color="#7b809a" /> : <ChevronRight size={18} color="#7b809a" />}
                                <div>
                                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                    <span style={{ fontSize: '14px', fontWeight: 600 }}>{topic.name}</span>
                                    <span className={`badge ${topic.isActive ? 'badge-info' : 'badge-neutral'}`} style={{ fontSize: '10px' }}>
                                      {topic.defaultImportance || 'medium'}
                                    </span>
                                    <span style={{ fontSize: '11px', color: '#7b809a' }}>
                                      ({topic.subtopics?.length || 0} Subtopics)
                                    </span>
                                  </div>
                                </div>
                              </div>

                              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                <button
                                  className="btn-secondary"
                                  style={{ padding: '4px 10px', fontSize: '11px' }}
                                  onClick={() => setSubtopicModal({ open: true, topicId: topic.id })}
                                >
                                  <Plus size={12} />
                                  <span>Add Subtopic</span>
                                </button>
                                <button
                                  className="btn-secondary"
                                  style={{ padding: '4px 8px' }}
                                  onClick={() => setTopicModal({ open: true, subjectId: subject.id, editItem: topic })}
                                >
                                  <Edit3 size={12} />
                                </button>
                                <button
                                  className="btn-secondary"
                                  style={{ padding: '4px 8px', color: '#ef5350' }}
                                  onClick={() => setDeleteModal({
                                    open: true,
                                    type: 'topic',
                                    id: topic.id,
                                    title: topic.name,
                                    hardDelete: false,
                                  })}
                                >
                                  <Trash2 size={12} />
                                </button>
                              </div>
                            </div>

                            {/* Subtopics List */}
                            {isTopicExpanded && (
                              <div style={{ marginTop: '12px', paddingLeft: '20px', borderLeft: '2px dashed #cbd5e1', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                                {(!topic.subtopics || topic.subtopics.length === 0) ? (
                                  <p style={{ fontSize: '12px', color: '#7b809a', padding: '6px 0' }}>No subtopics configured.</p>
                                ) : (
                                  topic.subtopics.map((subtopic: any) => {
                                    const attachedScript = getAttachedScript(topic.id, subtopic.id);
                                    return (
                                      <div
                                        key={subtopic.id}
                                        style={{
                                          display: 'flex',
                                          alignItems: 'center',
                                          justifyContent: 'space-between',
                                          background: '#ffffff',
                                          padding: '10px 14px',
                                          borderRadius: '8px',
                                          border: '1px solid #e2e8f0',
                                        }}
                                      >
                                        <div>
                                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                            <span style={{ fontSize: '13px', fontWeight: 600 }}>{subtopic.name}</span>
                                            <span className="badge badge-neutral" style={{ fontSize: '10px' }}>
                                              {subtopic._count?.questions || 0} Questions
                                            </span>
                                          </div>
                                        </div>

                                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                          {/* Attached Script Chip / Button */}
                                          {attachedScript ? (
                                            <button
                                              className="btn-secondary"
                                              style={{
                                                padding: '4px 10px',
                                                fontSize: '11px',
                                                background: '#f0fdf4',
                                                color: '#15803d',
                                                borderColor: '#bbf7d0',
                                              }}
                                              onClick={() => handleOpenScript(attachedScript.id)}
                                              title="Inspect & edit JSON script definition"
                                            >
                                              <FileCode size={13} />
                                              <span>Script: {attachedScript.title.slice(0, 18)}...</span>
                                            </button>
                                          ) : (
                                            <button
                                              className="btn-secondary"
                                              style={{ padding: '4px 10px', fontSize: '11px', color: '#1a73e8' }}
                                              onClick={() => {
                                                setScriptModal({
                                                  open: true,
                                                  subjectId: subject.id,
                                                  topicId: topic.id,
                                                  subtopicId: subtopic.id,
                                                  title: `${subtopic.name} - Lesson Script`,
                                                  status: 'PUBLISHED',
                                                  definitionJson: JSON.stringify({
                                                    title: subtopic.name,
                                                    nodes: [
                                                      { id: 'node_1', type: 'DIALOG', text: `Welcome to ${subtopic.name}` },
                                                      { id: 'node_2', type: 'QUESTION', prompt: 'Sample question prompt', options: ['A', 'B', 'C', 'D'], answer: 'A' },
                                                    ],
                                                  }, null, 2),
                                                  isNew: true,
                                                });
                                                setScriptJsonError(null);
                                              }}
                                            >
                                              <Plus size={12} />
                                              <span>Attach Script</span>
                                            </button>
                                          )}

                                          <button
                                            className="btn-secondary"
                                            style={{ padding: '4px 8px' }}
                                            onClick={() => setSubtopicModal({ open: true, topicId: topic.id, editItem: subtopic })}
                                          >
                                            <Edit3 size={12} />
                                          </button>
                                          <button
                                            className="btn-secondary"
                                            style={{ padding: '4px 8px', color: '#ef5350' }}
                                            onClick={() => setDeleteModal({
                                              open: true,
                                              type: 'subtopic',
                                              id: subtopic.id,
                                              title: subtopic.name,
                                              hardDelete: false,
                                            })}
                                          >
                                            <Trash2 size={12} />
                                          </button>
                                        </div>
                                      </div>
                                    );
                                  })
                                )}
                              </div>
                            )}
                          </div>
                        );
                      })
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* ============================================================== */}
      {/* SCRIPT EDITOR / INSPECTOR MODAL */}
      {/* ============================================================== */}
      {scriptModal?.open && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '820px' }}>
            <div className="modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <FileCode size={20} color="#1a73e8" />
                <h3 className="modal-title">
                  {scriptModal.isNew ? 'Attach New Lesson Script' : 'Inspect & Modify Script Definition'}
                </h3>
              </div>
              <button 
                onClick={() => setScriptModal(null)} 
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#7b809a' }}
              >
                <X size={20} />
              </button>
            </div>

            <div className="modal-body">
              <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '16px' }}>
                <div className="form-group">
                  <label className="form-label">Script Title</label>
                  <input
                    type="text"
                    className="form-control"
                    value={scriptModal.title}
                    onChange={(e) => setScriptModal({ ...scriptModal, title: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Status</label>
                  <select
                    className="form-control"
                    value={scriptModal.status}
                    onChange={(e) => setScriptModal({ ...scriptModal, status: e.target.value })}
                  >
                    <option value="PUBLISHED">PUBLISHED (Live)</option>
                    <option value="DRAFT">DRAFT</option>
                    <option value="REVIEW">REVIEW</option>
                    <option value="ARCHIVED">ARCHIVED</option>
                  </select>
                </div>
              </div>

              <div className="form-group">
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <label className="form-label">Script JSON Definition (Nodes, Questions, Dialogue)</label>
                  <span style={{ fontSize: '11px', color: '#7b809a' }}>Prisma JSONB Versioned Engine</span>
                </div>
                {scriptJsonError && (
                  <div style={{ color: '#c62828', background: '#ffebee', padding: '8px 12px', borderRadius: '6px', fontSize: '12px' }}>
                    {scriptJsonError}
                  </div>
                )}
                <textarea
                  className="form-control"
                  style={{
                    fontFamily: 'monospace',
                    fontSize: '12px',
                    minHeight: '280px',
                    lineHeight: '1.4',
                    background: '#1e293b',
                    color: '#f8fafc',
                  }}
                  value={scriptModal.definitionJson}
                  onChange={(e) => {
                    setScriptModal({ ...scriptModal, definitionJson: e.target.value });
                    setScriptJsonError(null);
                  }}
                />
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn-secondary" onClick={() => setScriptModal(null)}>
                Cancel
              </button>
              <button className="btn-primary" onClick={handleSaveScript}>
                <Check size={16} />
                <span>{scriptModal.isNew ? 'Create & Attach' : 'Publish New Version'}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ============================================================== */}
      {/* DELETE CONFIRMATION MODAL (WITH SOFT VS HARD DELETE TOGGLE) */}
      {/* ============================================================== */}
      {deleteModal?.open && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '480px' }}>
            <div className="modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#ef5350' }}>
                <AlertTriangle size={20} />
                <h3 className="modal-title">Delete {deleteModal.type.toUpperCase()}</h3>
              </div>
              <button onClick={() => setDeleteModal(null)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                <X size={18} />
              </button>
            </div>

            <div className="modal-body">
              <p style={{ fontSize: '14px', color: '#344767' }}>
                Are you sure you want to delete <strong>"{deleteModal.title}"</strong>?
              </p>

              <div style={{
                background: '#f8fafc',
                border: '1px solid #e2e8f0',
                padding: '14px',
                borderRadius: '8px',
                marginTop: '10px'
              }}>
                <label style={{ display: 'flex', alignItems: 'flex-start', gap: '10px', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={deleteModal.hardDelete}
                    onChange={(e) => setDeleteModal({ ...deleteModal, hardDelete: e.target.checked })}
                    style={{ marginTop: '3px' }}
                  />
                  <div>
                    <span style={{ fontSize: '13px', fontWeight: 600, color: deleteModal.hardDelete ? '#c62828' : '#344767' }}>
                      HARD DELETE (Permanent Deletion)
                    </span>
                    <p style={{ fontSize: '12px', color: '#7b809a', marginTop: '2px' }}>
                      {deleteModal.hardDelete
                        ? 'Permanently erases this item and all dependent children from the database.'
                        : 'Soft delete marks isActive=false without removing data.'}
                    </p>
                  </div>
                </label>
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn-secondary" onClick={() => setDeleteModal(null)}>
                Cancel
              </button>
              <button className="btn-danger" onClick={confirmDelete}>
                <Trash2 size={16} />
                <span>Confirm {deleteModal.hardDelete ? 'Hard Delete' : 'Soft Delete'}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ============================================================== */}
      {/* SUBJECT ADD/EDIT MODAL */}
      {/* ============================================================== */}
      {subjectModal.open && (
        <SubjectFormModal
          editItem={subjectModal.editItem}
          onClose={() => setSubjectModal({ open: false })}
          onSuccess={() => {
            setSubjectModal({ open: false });
            fetchSyllabus();
          }}
        />
      )}

      {/* TOPIC ADD/EDIT MODAL */}
      {topicModal.open && (
        <TopicFormModal
          subjectId={topicModal.subjectId!}
          editItem={topicModal.editItem}
          onClose={() => setTopicModal({ open: false })}
          onSuccess={() => {
            setTopicModal({ open: false });
            fetchSyllabus();
          }}
        />
      )}

      {/* SUBTOPIC ADD/EDIT MODAL */}
      {subtopicModal.open && (
        <SubtopicFormModal
          topicId={subtopicModal.topicId!}
          editItem={subtopicModal.editItem}
          onClose={() => setSubtopicModal({ open: false })}
          onSuccess={() => {
            setSubtopicModal({ open: false });
            fetchSyllabus();
          }}
        />
      )}
    </div>
  );
};

// Form Modal Sub-components
const SubjectFormModal: React.FC<{ editItem?: any; onClose: () => void; onSuccess: () => void }> = ({
  editItem,
  onClose,
  onSuccess,
}) => {
  const [name, setName] = useState(editItem?.name || '');
  const [description, setDescription] = useState(editItem?.description || '');
  const [displayOrder, setDisplayOrder] = useState(editItem?.displayOrder ?? 0);
  const [isActive, setIsActive] = useState(editItem?.isActive ?? true);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (editItem) {
        await api.updateSubject(editItem.id, { name, description, displayOrder, isActive });
      } else {
        await api.createSubject({ name, description, displayOrder });
      }
      onSuccess();
    } catch (err: any) {
      alert(err.response?.data?.message || err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '480px' }}>
        <div className="modal-header">
          <h3 className="modal-title">{editItem ? 'Edit Subject' : 'Add Subject'}</h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}><X size={18} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            <div className="form-group">
              <label className="form-label">Subject Name</label>
              <input type="text" className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <div className="form-group">
              <label className="form-label">Description</label>
              <textarea className="form-control" value={description} onChange={(e) => setDescription(e.target.value)} />
            </div>
            <div className="form-group">
              <label className="form-label">Display Order</label>
              <input type="number" className="form-control" value={displayOrder} onChange={(e) => setDisplayOrder(Number(e.target.value))} />
            </div>
            {editItem && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <input type="checkbox" id="subActive" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
                <label htmlFor="subActive" style={{ fontSize: '13px', cursor: 'pointer' }}>Active</label>
              </div>
            )}
          </div>
          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={loading}>{loading ? 'Saving...' : 'Save'}</button>
          </div>
        </form>
      </div>
    </div>
  );
};

const TopicFormModal: React.FC<{ subjectId: string; editItem?: any; onClose: () => void; onSuccess: () => void }> = ({
  subjectId,
  editItem,
  onClose,
  onSuccess,
}) => {
  const [name, setName] = useState(editItem?.name || '');
  const [description, setDescription] = useState(editItem?.description || '');
  const [defaultImportance, setDefaultImportance] = useState(editItem?.defaultImportance || 'medium');
  const [defaultTeachingMinutes, setDefaultTeachingMinutes] = useState(editItem?.defaultTeachingMinutes ?? 30);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (editItem) {
        await api.updateTopic(editItem.id, { name, description, defaultImportance, defaultTeachingMinutes });
      } else {
        await api.createTopic({ subjectId, name, description, defaultImportance, defaultTeachingMinutes });
      }
      onSuccess();
    } catch (err: any) {
      alert(err.response?.data?.message || err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '480px' }}>
        <div className="modal-header">
          <h3 className="modal-title">{editItem ? 'Edit Topic' : 'Add Topic'}</h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}><X size={18} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            <div className="form-group">
              <label className="form-label">Topic Name</label>
              <input type="text" className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <div className="form-group">
              <label className="form-label">Description</label>
              <textarea className="form-control" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Topic description..." />
            </div>
            <div className="form-group">
              <label className="form-label">Importance</label>
              <select className="form-control" value={defaultImportance} onChange={(e) => setDefaultImportance(e.target.value)}>
                <option value="high">High</option>
                <option value="medium">Medium</option>
                <option value="low">Low</option>
              </select>
            </div>
            <div className="form-group">
              <label className="form-label">Teaching Minutes</label>
              <input type="number" className="form-control" value={defaultTeachingMinutes} onChange={(e) => setDefaultTeachingMinutes(Number(e.target.value))} />
            </div>
          </div>
          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={loading}>{loading ? 'Saving...' : 'Save'}</button>
          </div>
        </form>
      </div>
    </div>
  );
};

const SubtopicFormModal: React.FC<{ topicId: string; editItem?: any; onClose: () => void; onSuccess: () => void }> = ({
  topicId,
  editItem,
  onClose,
  onSuccess,
}) => {
  const [name, setName] = useState(editItem?.name || '');
  const [sequence, setSequence] = useState(editItem?.sequence ?? 0);
  const [importance, setImportance] = useState(editItem?.importance || 'medium');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (editItem) {
        await api.updateSubtopic(editItem.id, { name, sequence, importance });
      } else {
        await api.createSubtopic({ topicId, name, sequence, importance });
      }
      onSuccess();
    } catch (err: any) {
      alert(err.response?.data?.message || err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '480px' }}>
        <div className="modal-header">
          <h3 className="modal-title">{editItem ? 'Edit Subtopic' : 'Add Subtopic'}</h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}><X size={18} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            <div className="form-group">
              <label className="form-label">Subtopic Name</label>
              <input type="text" className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <div className="form-group">
              <label className="form-label">Sequence Number</label>
              <input type="number" className="form-control" value={sequence} onChange={(e) => setSequence(Number(e.target.value))} />
            </div>
            <div className="form-group">
              <label className="form-label">Importance</label>
              <select className="form-control" value={importance} onChange={(e) => setImportance(e.target.value)}>
                <option value="high">High</option>
                <option value="medium">Medium</option>
                <option value="low">Low</option>
              </select>
            </div>
          </div>
          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={loading}>{loading ? 'Saving...' : 'Save'}</button>
          </div>
        </form>
      </div>
    </div>
  );
};
