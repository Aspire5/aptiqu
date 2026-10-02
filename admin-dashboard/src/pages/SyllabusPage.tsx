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
  X,
  GripVertical,
  Link as LinkIcon,
  Unlink as UnlinkIcon
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

  // Link Modals & Unlink Safe Modals
  const [linkTopicModal, setLinkTopicModal] = useState<{ open: boolean; subjectId: string; subjectName: string; currentTopicIds: string[] } | null>(null);
  const [linkSubtopicModal, setLinkSubtopicModal] = useState<{ open: boolean; topicId: string; topicName: string; currentSubtopicIds: string[] } | null>(null);
  const [unlinkModal, setUnlinkModal] = useState<{
    open: boolean;
    type: 'topic' | 'subtopic';
    parentId: string;
    childId: string;
    title: string;
    parentTitle: string;
  } | null>(null);

  // Drag and drop tracking
  const [draggedTopic, setDraggedTopic] = useState<{ subjectId: string; topicId: string; index: number } | null>(null);
  const [draggedSubtopic, setDraggedSubtopic] = useState<{ topicId: string; subtopicId: string; index: number } | null>(null);

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

  // Safe Unlink handler (detaches without deleting underlying item, questions, or scripts)
  const confirmUnlink = async () => {
    if (!unlinkModal) return;
    try {
      const { type, parentId, childId } = unlinkModal;
      if (type === 'topic') {
        await api.unlinkTopic(parentId, childId);
      } else {
        await api.unlinkSubtopic(parentId, childId);
      }
      setUnlinkModal(null);
      fetchSyllabus();
    } catch (err: any) {
      alert(`Unlinking failed: ${err.response?.data?.message || err.message}`);
    }
  };

  // Drag and Drop: Topics reordering within a Subject
  const handleTopicDragStart = (e: React.DragEvent, subjectId: string, topicId: string, index: number) => {
    e.stopPropagation();
    setDraggedTopic({ subjectId, topicId, index });
    e.dataTransfer.effectAllowed = 'move';
  };

  const handleTopicDrop = async (e: React.DragEvent, subjectId: string, targetIndex: number) => {
    e.preventDefault();
    e.stopPropagation();
    if (!draggedTopic || draggedTopic.subjectId !== subjectId || draggedTopic.index === targetIndex) {
      setDraggedTopic(null);
      return;
    }
    const newSyllabus = [...syllabus];
    const sub = newSyllabus.find((s) => s.id === subjectId);
    if (!sub || !sub.topics) return;

    const topicsList = [...sub.topics];
    const [moved] = topicsList.splice(draggedTopic.index, 1);
    topicsList.splice(targetIndex, 0, moved);
    sub.topics = topicsList;
    setSyllabus(newSyllabus);
    setDraggedTopic(null);

    try {
      const topicIds = topicsList.map((t: any) => t.id);
      await api.reorderTopics(subjectId, topicIds);
    } catch (err: any) {
      console.error('Failed to persist topic order', err);
      fetchSyllabus();
    }
  };

  // Drag and Drop: Subtopics reordering within a Topic
  const handleSubtopicDragStart = (e: React.DragEvent, topicId: string, subtopicId: string, index: number) => {
    e.stopPropagation();
    setDraggedSubtopic({ topicId, subtopicId, index });
    e.dataTransfer.effectAllowed = 'move';
  };

  const handleSubtopicDrop = async (e: React.DragEvent, topicId: string, targetIndex: number) => {
    e.preventDefault();
    e.stopPropagation();
    if (!draggedSubtopic || draggedSubtopic.topicId !== topicId || draggedSubtopic.index === targetIndex) {
      setDraggedSubtopic(null);
      return;
    }
    const newSyllabus = [...syllabus];
    let foundTopic: any = null;
    for (const s of newSyllabus) {
      foundTopic = s.topics?.find((t: any) => t.id === topicId);
      if (foundTopic) break;
    }
    if (!foundTopic || !foundTopic.subtopics) return;

    const subtopicsList = [...foundTopic.subtopics];
    const [moved] = subtopicsList.splice(draggedSubtopic.index, 1);
    subtopicsList.splice(targetIndex, 0, moved);
    foundTopic.subtopics = subtopicsList;
    setSyllabus(newSyllabus);
    setDraggedSubtopic(null);

    try {
      const subtopicIds = subtopicsList.map((st: any) => st.id);
      await api.reorderSubtopics(topicId, subtopicIds);
    } catch (err: any) {
      console.error('Failed to persist subtopic order', err);
      fetchSyllabus();
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

  // Strictly verify question references & import script via Admin Syllabus API
  const handleImportVerifiedScript = async () => {
    if (!scriptModal || !scriptModal.topicId) return;
    try {
      let parsedDefinition;
      try {
        parsedDefinition = JSON.parse(scriptModal.definitionJson);
      } catch (e: any) {
        setScriptJsonError(`JSON Syntax Error: ${e.message}`);
        return;
      }

      await api.importScript({
        topicId: scriptModal.topicId,
        subtopicId: scriptModal.subtopicId,
        scriptDefinition: parsedDefinition,
      });

      alert('Script verified and imported successfully with valid question references!');
      setScriptModal(null);
      fetchSyllabus();
    } catch (err: any) {
      const errMsg = err.response?.data?.message || err.message;
      setScriptJsonError(`Strict Validation Error: ${errMsg}`);
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
                      style={{ padding: '6px 12px', fontSize: '12px', color: '#1a73e8', borderColor: '#bfdbfe' }}
                      title="Link an existing topic to this subject"
                      onClick={() => setLinkTopicModal({
                        open: true,
                        subjectId: subject.id,
                        subjectName: subject.name,
                        currentTopicIds: (subject.topics || []).map((t: any) => t.id),
                      })}
                    >
                      <LinkIcon size={14} />
                      <span>Link Topic</span>
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
                      subject.topics.map((topic: any, tIndex: number) => {
                        const isTopicExpanded = !!expandedTopics[topic.id];
                        return (
                          <div
                            key={topic.id}
                            draggable
                            onDragStart={(e) => handleTopicDragStart(e, subject.id, topic.id, tIndex)}
                            onDragOver={(e) => e.preventDefault()}
                            onDrop={(e) => handleTopicDrop(e, subject.id, tIndex)}
                            style={{
                              background: '#f8fafc',
                              padding: '14px 18px',
                              borderRadius: '10px',
                              border: '1px solid #e2e8f0',
                              transition: 'all 0.15s ease',
                            }}
                          >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flex: 1 }}>
                                <div
                                  title="Drag to reorder topic"
                                  style={{ cursor: 'grab', display: 'flex', alignItems: 'center', color: '#94a3b8', padding: '2px' }}
                                >
                                  <GripVertical size={16} />
                                </div>
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
                                      {topic.isLinked && (
                                        <span className="badge" style={{ fontSize: '10px', background: '#eff6ff', color: '#1d4ed8', border: '1px solid #bfdbfe' }}>
                                          <LinkIcon size={9} style={{ marginRight: '3px' }} /> Linked
                                        </span>
                                      )}
                                      <span style={{ fontSize: '11px', color: '#7b809a' }}>
                                        ({topic.subtopics?.length || 0} Subtopics)
                                      </span>
                                    </div>
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
                                  style={{ padding: '4px 10px', fontSize: '11px', color: '#1a73e8', borderColor: '#bfdbfe' }}
                                  title="Link an existing subtopic to this topic"
                                  onClick={() => setLinkSubtopicModal({
                                    open: true,
                                    topicId: topic.id,
                                    topicName: topic.name,
                                    currentSubtopicIds: (topic.subtopics || []).map((st: any) => st.id),
                                  })}
                                >
                                  <LinkIcon size={12} />
                                  <span>Link Subtopic</span>
                                </button>
                                <button
                                  className="btn-secondary"
                                  style={{ padding: '4px 8px' }}
                                  title="Edit Topic"
                                  onClick={() => setTopicModal({ open: true, subjectId: subject.id, editItem: topic })}
                                >
                                  <Edit3 size={12} />
                                </button>
                                <button
                                  className="btn-secondary"
                                  style={{ padding: '4px 8px', color: '#d97706' }}
                                  title="Unlink Topic from this Subject (preserves topic, subtopics & questions)"
                                  onClick={() => setUnlinkModal({
                                    open: true,
                                    type: 'topic',
                                    parentId: subject.id,
                                    childId: topic.id,
                                    title: topic.name,
                                    parentTitle: subject.name,
                                  })}
                                >
                                  <UnlinkIcon size={12} />
                                </button>
                                <button
                                  className="btn-secondary"
                                  style={{ padding: '4px 8px', color: '#ef5350' }}
                                  title="Delete Topic"
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
                                  topic.subtopics.map((subtopic: any, stIndex: number) => {
                                    const attachedScript = getAttachedScript(topic.id, subtopic.id);
                                    return (
                                      <div
                                        key={subtopic.id}
                                        draggable
                                        onDragStart={(e) => handleSubtopicDragStart(e, topic.id, subtopic.id, stIndex)}
                                        onDragOver={(e) => e.preventDefault()}
                                        onDrop={(e) => handleSubtopicDrop(e, topic.id, stIndex)}
                                        style={{
                                          display: 'flex',
                                          alignItems: 'center',
                                          justifyContent: 'space-between',
                                          background: '#ffffff',
                                          padding: '10px 14px',
                                          borderRadius: '8px',
                                          border: '1px solid #e2e8f0',
                                          transition: 'all 0.15s ease',
                                        }}
                                      >
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                          <div
                                            title="Drag to reorder subtopic"
                                            style={{ cursor: 'grab', display: 'flex', alignItems: 'center', color: '#94a3b8', padding: '2px' }}
                                          >
                                            <GripVertical size={14} />
                                          </div>
                                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                            <span style={{ fontSize: '13px', fontWeight: 600 }}>{subtopic.name}</span>
                                            {subtopic.isLinked && (
                                              <span className="badge" style={{ fontSize: '9px', background: '#eff6ff', color: '#1d4ed8', border: '1px solid #bfdbfe' }}>
                                                <LinkIcon size={8} style={{ marginRight: '2px' }} /> Linked
                                              </span>
                                            )}
                                            <span className="badge badge-neutral" style={{ fontSize: '10px' }}>
                                              {subtopic._count?.questions || 0} Questions
                                            </span>
                                          </div>
                                        </div>

                                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
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
                                            title="Edit Subtopic"
                                            onClick={() => setSubtopicModal({ open: true, topicId: topic.id, editItem: subtopic })}
                                          >
                                            <Edit3 size={12} />
                                          </button>
                                          <button
                                            className="btn-secondary"
                                            style={{ padding: '4px 8px', color: '#d97706' }}
                                            title="Unlink Subtopic from Topic (safe dissociation)"
                                            onClick={() => setUnlinkModal({
                                              open: true,
                                              type: 'subtopic',
                                              parentId: topic.id,
                                              childId: subtopic.id,
                                              title: subtopic.name,
                                              parentTitle: topic.name,
                                            })}
                                          >
                                            <UnlinkIcon size={12} />
                                          </button>
                                          <button
                                            className="btn-secondary"
                                            style={{ padding: '4px 8px', color: '#ef5350' }}
                                            title="Delete Subtopic"
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

            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <button className="btn-secondary" onClick={() => setScriptModal(null)}>
                Cancel
              </button>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button
                  className="btn-secondary"
                  style={{ background: '#eff6ff', color: '#1d4ed8', borderColor: '#bfdbfe' }}
                  onClick={handleImportVerifiedScript}
                  title="Verify all question externalKey references and subtopic bindings before persisting"
                >
                  <FileCode size={15} />
                  <span>Strict Import & Verify Refs</span>
                </button>
                <button className="btn-primary" onClick={handleSaveScript}>
                  <Check size={16} />
                  <span>{scriptModal.isNew ? 'Create & Attach' : 'Publish New Version'}</span>
                </button>
              </div>
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
      {/* UNLINK CONFIRMATION MODAL (SAFE DISSOCIATION) */}
      {/* ============================================================== */}
      {unlinkModal?.open && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '480px' }}>
            <div className="modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#d97706' }}>
                <UnlinkIcon size={20} />
                <h3 className="modal-title">Unlink {unlinkModal.type === 'topic' ? 'Topic' : 'Subtopic'}</h3>
              </div>
              <button onClick={() => setUnlinkModal(null)} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                <X size={18} />
              </button>
            </div>

            <div className="modal-body">
              <p style={{ fontSize: '14px', color: '#344767' }}>
                Are you sure you want to unlink <strong>"{unlinkModal.title}"</strong> from <strong>"{unlinkModal.parentTitle}"</strong>?
              </p>

              <div style={{
                background: '#fef3c7',
                border: '1px solid #fde68a',
                padding: '12px 14px',
                borderRadius: '8px',
                marginTop: '12px',
              }}>
                <p style={{ fontSize: '12px', color: '#92400e', margin: 0, lineHeight: 1.5 }}>
                  <strong>Safe Action:</strong> This item is only detached from this {unlinkModal.type === 'topic' ? 'subject' : 'topic'}. The underlying record, all its questions, and lesson scripts remain safe and will <strong>NOT</strong> be deleted.
                </p>
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn-secondary" onClick={() => setUnlinkModal(null)}>
                Cancel
              </button>
              <button
                className="btn-primary"
                style={{ background: '#d97706', borderColor: '#d97706' }}
                onClick={confirmUnlink}
              >
                <UnlinkIcon size={16} />
                <span>Confirm Unlink</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* LINK TOPIC MODAL */}
      {linkTopicModal?.open && (
        <LinkTopicModal
          subjectId={linkTopicModal.subjectId}
          subjectName={linkTopicModal.subjectName}
          currentTopicIds={linkTopicModal.currentTopicIds}
          onClose={() => setLinkTopicModal(null)}
          onSuccess={() => {
            setLinkTopicModal(null);
            fetchSyllabus();
          }}
        />
      )}

      {/* LINK SUBTOPIC MODAL */}
      {linkSubtopicModal?.open && (
        <LinkSubtopicModal
          topicId={linkSubtopicModal.topicId}
          topicName={linkSubtopicModal.topicName}
          currentSubtopicIds={linkSubtopicModal.currentSubtopicIds}
          onClose={() => setLinkSubtopicModal(null)}
          onSuccess={() => {
            setLinkSubtopicModal(null);
            fetchSyllabus();
          }}
        />
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
  const [isActive, setIsActive] = useState(editItem?.isActive ?? true);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (editItem) {
        await api.updateTopic(editItem.id, { name, description, defaultImportance, defaultTeachingMinutes, isActive });
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
            {editItem && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '12px' }}>
                <input type="checkbox" id="topicActive" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
                <label htmlFor="topicActive" style={{ fontSize: '13px', cursor: 'pointer' }}>Active (Visible in Curriculum)</label>
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

const SubtopicFormModal: React.FC<{ topicId: string; editItem?: any; onClose: () => void; onSuccess: () => void }> = ({
  topicId,
  editItem,
  onClose,
  onSuccess,
}) => {
  const [name, setName] = useState(editItem?.name || '');
  const [description, setDescription] = useState(editItem?.description || '');
  const [sequence, setSequence] = useState(editItem?.sequence ?? 0);
  const [importance, setImportance] = useState(editItem?.importance || 'medium');
  const [teachingMinutes, setTeachingMinutes] = useState(editItem?.teachingMinutes ?? 30);
  const [isActive, setIsActive] = useState(editItem?.isActive ?? true);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (editItem) {
        await api.updateSubtopic(editItem.id, { name, description, sequence, importance, teachingMinutes, isActive });
      } else {
        await api.createSubtopic({ topicId, name, description, sequence, importance, teachingMinutes });
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
              <label className="form-label">Description</label>
              <textarea className="form-control" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Subtopic learning goals or concepts..." />
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
            <div className="form-group">
              <label className="form-label">Teaching Minutes</label>
              <input type="number" className="form-control" value={teachingMinutes} onChange={(e) => setTeachingMinutes(Number(e.target.value))} />
            </div>
            {editItem && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '12px' }}>
                <input type="checkbox" id="subActive" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
                <label htmlFor="subActive" style={{ fontSize: '13px', cursor: 'pointer' }}>Active (Visible in Curriculum)</label>
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


// ============================================================================
// LINK EXISTING TOPIC MODAL (REUSABILITY)
// ============================================================================
const LinkTopicModal: React.FC<{
  subjectId: string;
  subjectName: string;
  currentTopicIds: string[];
  onClose: () => void;
  onSuccess: () => void;
}> = ({ subjectId, subjectName, currentTopicIds, onClose, onSuccess }) => {
  const [topics, setTopics] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [selectedTopicId, setSelectedTopicId] = useState('');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadTopics();
  }, []);

  const loadTopics = async () => {
    try {
      const res = await api.getAvailableTopics();
      if (res.data?.success) {
        setTopics(res.data.data || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filteredTopics = topics.filter((t) => {
    const isAlreadyLinked = currentTopicIds.includes(t.id);
    const matchesSearch = t.name.toLowerCase().includes(search.toLowerCase());
    return !isAlreadyLinked && matchesSearch;
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedTopicId) return;
    setSubmitting(true);
    try {
      await api.linkTopic(subjectId, selectedTopicId);
      onSuccess();
    } catch (err: any) {
      alert(`Linking failed: ${err.response?.data?.message || err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '520px' }}>
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <LinkIcon size={18} color="#1a73e8" />
            <h3 className="modal-title">Link Existing Topic to "{subjectName}"</h3>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}><X size={18} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            <p style={{ fontSize: '13px', color: '#64748b', marginBottom: '12px', lineHeight: 1.4 }}>
              Reuse a topic across multiple subjects. The topic, child subtopics, questions, and scripts remain unique in the backend and linked here.
            </p>
            <div className="form-group">
              <input
                type="text"
                className="form-control"
                placeholder="Search available topics..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            {loading ? (
              <p style={{ fontSize: '13px', color: '#94a3b8' }}>Loading topics...</p>
            ) : filteredTopics.length === 0 ? (
              <p style={{ fontSize: '13px', color: '#94a3b8', fontStyle: 'italic' }}>No unlinked topics found.</p>
            ) : (
              <div style={{ maxHeight: '240px', overflowY: 'auto', border: '1px solid #e2e8f0', borderRadius: '8px', padding: '6px' }}>
                {filteredTopics.map((t) => (
                  <div
                    key={t.id}
                    onClick={() => setSelectedTopicId(t.id)}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '10px 12px',
                      borderRadius: '6px',
                      cursor: 'pointer',
                      background: selectedTopicId === t.id ? '#eff6ff' : 'transparent',
                      border: selectedTopicId === t.id ? '1px solid #3b82f6' : '1px solid transparent',
                      marginBottom: '4px',
                    }}
                  >
                    <div>
                      <span style={{ fontSize: '13px', fontWeight: 600, color: '#1e293b' }}>{t.name}</span>
                      <span style={{ fontSize: '11px', color: '#64748b', marginLeft: '8px' }}>
                        ({t.subtopics?.length || 0} subtopics)
                      </span>
                    </div>
                    <span className="badge badge-info" style={{ fontSize: '10px' }}>{t.defaultImportance || 'medium'}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={!selectedTopicId || submitting}>
              {submitting ? 'Linking...' : 'Link Topic'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// ============================================================================
// LINK EXISTING SUBTOPIC MODAL (REUSABILITY)
// ============================================================================
const LinkSubtopicModal: React.FC<{
  topicId: string;
  topicName: string;
  currentSubtopicIds: string[];
  onClose: () => void;
  onSuccess: () => void;
}> = ({ topicId, topicName, currentSubtopicIds, onClose, onSuccess }) => {
  const [subtopics, setSubtopics] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [selectedSubtopicId, setSelectedSubtopicId] = useState('');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadSubtopics();
  }, []);

  const loadSubtopics = async () => {
    try {
      const res = await api.getAvailableSubtopics();
      if (res.data?.success) {
        setSubtopics(res.data.data || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filteredSubtopics = subtopics.filter((st) => {
    const isAlreadyLinked = currentSubtopicIds.includes(st.id);
    const matchesSearch = st.name.toLowerCase().includes(search.toLowerCase());
    return !isAlreadyLinked && matchesSearch;
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedSubtopicId) return;
    setSubmitting(true);
    try {
      await api.linkSubtopic(topicId, selectedSubtopicId);
      onSuccess();
    } catch (err: any) {
      alert(`Linking failed: ${err.response?.data?.message || err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '520px' }}>
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <LinkIcon size={18} color="#1a73e8" />
            <h3 className="modal-title">Link Existing Subtopic to "{topicName}"</h3>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}><X size={18} /></button>
        </div>
        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            <p style={{ fontSize: '13px', color: '#64748b', marginBottom: '12px', lineHeight: 1.4 }}>
              Reuse a subtopic across multiple topics. The subtopic and all its questions and lesson scripts remain unique and linked.
            </p>
            <div className="form-group">
              <input
                type="text"
                className="form-control"
                placeholder="Search available subtopics..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            {loading ? (
              <p style={{ fontSize: '13px', color: '#94a3b8' }}>Loading subtopics...</p>
            ) : filteredSubtopics.length === 0 ? (
              <p style={{ fontSize: '13px', color: '#94a3b8', fontStyle: 'italic' }}>No unlinked subtopics found.</p>
            ) : (
              <div style={{ maxHeight: '240px', overflowY: 'auto', border: '1px solid #e2e8f0', borderRadius: '8px', padding: '6px' }}>
                {filteredSubtopics.map((st) => (
                  <div
                    key={st.id}
                    onClick={() => setSelectedSubtopicId(st.id)}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '10px 12px',
                      borderRadius: '6px',
                      cursor: 'pointer',
                      background: selectedSubtopicId === st.id ? '#eff6ff' : 'transparent',
                      border: selectedSubtopicId === st.id ? '1px solid #3b82f6' : '1px solid transparent',
                      marginBottom: '4px',
                    }}
                  >
                    <div>
                      <span style={{ fontSize: '13px', fontWeight: 600, color: '#1e293b' }}>{st.name}</span>
                      <span style={{ fontSize: '11px', color: '#64748b', marginLeft: '8px' }}>
                        ({st._count?.questions || 0} questions)
                      </span>
                    </div>
                    <span className="badge badge-neutral" style={{ fontSize: '10px' }}>{st.importance || 'medium'}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={!selectedSubtopicId || submitting}>
              {submitting ? 'Linking...' : 'Link Subtopic'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
