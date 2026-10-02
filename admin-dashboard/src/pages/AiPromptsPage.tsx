import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import {
  Sparkles,
  Save,
  RotateCcw,
  Copy,
  Check,
  AlertCircle,
  CheckCircle2,
  Server,
  FileText,
  Sliders,
  Eye,
  Edit3,
  Clock,
  Zap,
} from 'lucide-react';

interface PromptVariable {
  name: string;
  description: string;
}

interface AiPrompt {
  id: string;
  key: string;
  title: string;
  category: 'SERVER_GENERATION' | 'SERVER_REVIEW' | 'MANUAL_REFERENCE';
  description: string;
  draftPrompt: string;
  publishedPrompt: string;
  variables?: PromptVariable[];
  version: number;
  isLive: boolean;
  hasUnpublishedChanges: boolean;
  lastPublishedAt?: string;
  updatedAt: string;
}

export const AiPromptsPage: React.FC = () => {
  const [prompts, setPrompts] = useState<AiPrompt[]>([]);
  const [selectedKey, setSelectedKey] = useState<string>('');
  const [activeTab, setActiveTab] = useState<'SERVER' | 'MANUAL'>('SERVER');
  const [draftText, setDraftText] = useState<string>('');
  const [viewMode, setViewMode] = useState<'DRAFT' | 'LIVE'>('DRAFT');
  const [loading, setLoading] = useState<boolean>(true);
  const [saving, setSaving] = useState<boolean>(false);
  const [publishing, setPublishing] = useState<boolean>(false);
  const [copied, setCopied] = useState<boolean>(false);
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  useEffect(() => {
    fetchPrompts();
  }, []);

  const fetchPrompts = async (maintainKey?: string) => {
    setLoading(true);
    try {
      const res = await api.getAiPrompts();
      if (res.data?.success) {
        const list: AiPrompt[] = res.data.data;
        setPrompts(list);

        const targetKey = maintainKey || selectedKey;
        const current = list.find((p) => p.key === targetKey);
        if (current) {
          setSelectedKey(current.key);
          setDraftText(current.draftPrompt);
        } else if (list.length > 0) {
          const firstServer = list.find((p) => p.category !== 'MANUAL_REFERENCE') || list[0];
          setSelectedKey(firstServer.key);
          setDraftText(firstServer.draftPrompt);
        }
      }
    } catch (err: any) {
      console.error('Failed to load AI prompts:', err);
      setFeedback({ type: 'error', message: err.response?.data?.error || 'Failed to load AI prompts' });
    } finally {
      setLoading(false);
    }
  };

  const selectedPrompt = prompts.find((p) => p.key === selectedKey);

  const handleSelectPrompt = (prompt: AiPrompt) => {
    setSelectedKey(prompt.key);
    setDraftText(prompt.draftPrompt);
    setViewMode('DRAFT');
    setFeedback(null);
  };

  const handleSaveDraft = async () => {
    if (!selectedPrompt) return;
    setSaving(true);
    setFeedback(null);
    try {
      const res = await api.updateAiPromptDraft(selectedPrompt.key, draftText);
      if (res.data?.success) {
        setFeedback({
          type: 'success',
          message: 'Draft saved in database. Server continues running the published prompt until you click Publish.',
        });
        await fetchPrompts(selectedPrompt.key);
      }
    } catch (err: any) {
      setFeedback({
        type: 'error',
        message: err.response?.data?.error || 'Failed to save draft.',
      });
    } finally {
      setSaving(false);
    }
  };

  const handlePublish = async () => {
    if (!selectedPrompt) return;
    const confirmPublish = window.confirm(
      `Publish prompt "${selectedPrompt.title}" to LIVE production?\n\nThis will take effect IMMEDIATELY across all PvP and Question generation on the server without requiring any restart.`
    );
    if (!confirmPublish) return;

    setPublishing(true);
    setFeedback(null);
    try {
      // If there are unsaved editor changes in the draft, save draft first
      if (draftText !== selectedPrompt.draftPrompt) {
        await api.updateAiPromptDraft(selectedPrompt.key, draftText);
      }

      const res = await api.publishAiPrompt(selectedPrompt.key);
      if (res.data?.success) {
        setFeedback({
          type: 'success',
          message: `PROMPT PUBLISHED! Version ${res.data.data.version} is now LIVE on the server without reboot.`,
        });
        await fetchPrompts(selectedPrompt.key);
      }
    } catch (err: any) {
      setFeedback({
        type: 'error',
        message: err.response?.data?.error || 'Failed to publish prompt.',
      });
    } finally {
      setPublishing(false);
    }
  };

  const handleResetToDefault = async () => {
    if (!selectedPrompt) return;
    const confirmReset = window.confirm(
      `Reset the draft of "${selectedPrompt.title}" back to the system factory default template?`
    );
    if (!confirmReset) return;

    try {
      const res = await api.resetAiPromptToDefault(selectedPrompt.key);
      if (res.data?.success) {
        setDraftText(res.data.data.draftPrompt);
        setFeedback({
          type: 'success',
          message: 'Draft reset to system factory default. Click Publish to make it live if desired.',
        });
        await fetchPrompts(selectedPrompt.key);
      }
    } catch (err: any) {
      setFeedback({
        type: 'error',
        message: err.response?.data?.error || 'Failed to reset prompt.',
      });
    }
  };

  const handleCopyPrompt = () => {
    const textToCopy = viewMode === 'LIVE' ? selectedPrompt?.publishedPrompt : draftText;
    if (textToCopy) {
      navigator.clipboard.writeText(textToCopy);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    }
  };

  const serverPrompts = prompts.filter((p) => p.category !== 'MANUAL_REFERENCE');
  const manualPrompts = prompts.filter((p) => p.category === 'MANUAL_REFERENCE');
  const displayedPrompts = activeTab === 'SERVER' ? serverPrompts : manualPrompts;

  // Auto-select first prompt when changing tabs if current prompt is not in tab
  const handleTabChange = (tab: 'SERVER' | 'MANUAL') => {
    setActiveTab(tab);
    setFeedback(null);
    const pool = tab === 'SERVER' ? serverPrompts : manualPrompts;
    if (pool.length > 0 && (!selectedPrompt || !pool.some((p) => p.key === selectedPrompt.key))) {
      setSelectedKey(pool[0].key);
      setDraftText(pool[0].draftPrompt);
      setViewMode('DRAFT');
    }
  };

  const hasUnpublished =
    selectedPrompt &&
    (selectedPrompt.hasUnpublishedChanges || draftText !== selectedPrompt.publishedPrompt);

  if (loading && prompts.length === 0) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#7b809a' }}>
        <p>Loading AI Prompt Configurations...</p>
      </div>
    );
  }

  return (
    <div style={{ paddingBottom: '60px' }}>
      {/* Page Header */}
      <div style={{ marginBottom: '24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div
                style={{
                  width: '36px',
                  height: '36px',
                  borderRadius: '10px',
                  background: 'linear-gradient(135deg, #1e293b, #0f172a)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#38bdf8',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
                }}
              >
                <Sparkles size={20} />
              </div>
              <h2 style={{ fontSize: '22px', fontWeight: 700, margin: 0 }}>AI Prompts Control Center</h2>
            </div>
            <p style={{ fontSize: '13px', color: '#7b809a', marginTop: '6px' }}>
              Inspect and edit backend AI instructions. Update live server behavior instantly with{' '}
              <strong style={{ color: '#16a34a' }}>zero restart</strong>, or manage syllabus extraction templates.
            </p>
          </div>

          {/* Tab Selector */}
          <div
            style={{
              display: 'flex',
              background: '#e2e8f0',
              padding: '4px',
              borderRadius: '10px',
              gap: '4px',
            }}
          >
            <button
              onClick={() => handleTabChange('SERVER')}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                padding: '8px 16px',
                borderRadius: '8px',
                border: 'none',
                fontSize: '13px',
                fontWeight: 600,
                cursor: 'pointer',
                background: activeTab === 'SERVER' ? '#ffffff' : 'transparent',
                color: activeTab === 'SERVER' ? '#0f172a' : '#64748b',
                boxShadow: activeTab === 'SERVER' ? '0 2px 6px rgba(0,0,0,0.08)' : 'none',
                transition: 'all 0.2s ease',
              }}
            >
              <Server size={15} />
              <span>Server Prompts ({serverPrompts.length})</span>
            </button>
            <button
              onClick={() => handleTabChange('MANUAL')}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                padding: '8px 16px',
                borderRadius: '8px',
                border: 'none',
                fontSize: '13px',
                fontWeight: 600,
                cursor: 'pointer',
                background: activeTab === 'MANUAL' ? '#ffffff' : 'transparent',
                color: activeTab === 'MANUAL' ? '#0f172a' : '#64748b',
                boxShadow: activeTab === 'MANUAL' ? '0 2px 6px rgba(0,0,0,0.08)' : 'none',
                transition: 'all 0.2s ease',
              }}
            >
              <FileText size={15} />
              <span>Manual Synthesis Prompts ({manualPrompts.length})</span>
            </button>
          </div>
        </div>
      </div>

      {/* Feedback Alert */}
      {feedback && (
        <div
          style={{
            background: feedback.type === 'success' ? '#f0fdf4' : '#fef2f2',
            border: `1px solid ${feedback.type === 'success' ? '#86efac' : '#fca5a5'}`,
            borderRadius: '10px',
            padding: '12px 16px',
            marginBottom: '20px',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            fontSize: '13px',
            color: feedback.type === 'success' ? '#166534' : '#991b1b',
            boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
          }}
        >
          {feedback.type === 'success' ? <CheckCircle2 size={18} /> : <AlertCircle size={18} />}
          <span style={{ flex: 1 }}>{feedback.message}</span>
          <button
            onClick={() => setFeedback(null)}
            style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', fontWeight: 700 }}
          >
            ✕
          </button>
        </div>
      )}

      {/* Main 2-Column Interface */}
      <div style={{ display: 'grid', gridTemplateColumns: '320px 1fr', gap: '20px', alignItems: 'start' }}>
        {/* Left Column: Prompt Selection List */}
        <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
          <div style={{ fontSize: '13px', fontWeight: 700, color: '#334155', marginBottom: '12px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
            {activeTab === 'SERVER' ? 'Live Server Prompts' : 'Curriculum Reference Prompts'}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {displayedPrompts.map((p) => {
              const isSelected = p.key === selectedKey;
              const hasDraftChanges = p.hasUnpublishedChanges;

              return (
                <div
                  key={p.key}
                  onClick={() => handleSelectPrompt(p)}
                  style={{
                    padding: '12px 14px',
                    borderRadius: '10px',
                    cursor: 'pointer',
                    background: isSelected ? '#f1f5f9' : '#ffffff',
                    border: `1px solid ${isSelected ? '#3b82f6' : '#e2e8f0'}`,
                    boxShadow: isSelected ? '0 2px 8px rgba(59, 130, 246, 0.12)' : 'none',
                    transition: 'all 0.15s ease',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '4px' }}>
                    <span style={{ fontSize: '14px', fontWeight: 600, color: isSelected ? '#1e293b' : '#334155' }}>
                      {p.title}
                    </span>
                    {p.category !== 'MANUAL_REFERENCE' && (
                      <span
                        style={{
                          fontSize: '10px',
                          fontWeight: 700,
                          padding: '2px 6px',
                          borderRadius: '4px',
                          background: '#e0f2fe',
                          color: '#0369a1',
                        }}
                      >
                        v{p.version}
                      </span>
                    )}
                  </div>

                  <div style={{ fontSize: '11px', color: '#64748b', lineHeight: 1.4 }}>
                    {p.description.slice(0, 75)}...
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '8px' }}>
                    {p.category === 'SERVER_GENERATION' && (
                      <span className="badge badge-info" style={{ fontSize: '10px', padding: '2px 6px' }}>
                        Generation
                      </span>
                    )}
                    {p.category === 'SERVER_REVIEW' && (
                      <span className="badge badge-warning" style={{ fontSize: '10px', padding: '2px 6px' }}>
                        Integrity Auditor
                      </span>
                    )}
                    {p.category === 'MANUAL_REFERENCE' && (
                      <span className="badge badge-neutral" style={{ fontSize: '10px', padding: '2px 6px' }}>
                        Book & PYQ Tool
                      </span>
                    )}

                    {p.category !== 'MANUAL_REFERENCE' && hasDraftChanges && (
                      <span
                        style={{
                          fontSize: '10px',
                          fontWeight: 600,
                          color: '#b45309',
                          background: '#fef3c7',
                          padding: '2px 6px',
                          borderRadius: '4px',
                        }}
                      >
                        Draft Unsaved
                      </span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Right Column: Prompt Editor & Live Details */}
        {selectedPrompt ? (
          <div className="card" style={{ padding: '20px', marginBottom: 0 }}>
            {/* Header info for selected prompt */}
            <div
              style={{
                display: 'flex',
                alignItems: 'flex-start',
                justifyContent: 'space-between',
                borderBottom: '1px solid #e2e8f0',
                paddingBottom: '16px',
                marginBottom: '16px',
              }}
            >
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <h3 style={{ fontSize: '18px', fontWeight: 700, margin: 0, color: '#0f172a' }}>
                    {selectedPrompt.title}
                  </h3>
                  <code
                    style={{
                      fontSize: '12px',
                      background: '#f1f5f9',
                      padding: '2px 8px',
                      borderRadius: '4px',
                      color: '#475569',
                      fontWeight: 600,
                    }}
                  >
                    {selectedPrompt.key}
                  </code>
                </div>
                <p style={{ fontSize: '13px', color: '#64748b', marginTop: '6px', marginBottom: 0 }}>
                  {selectedPrompt.description}
                </p>
              </div>

              {/* Version & Live status */}
              {selectedPrompt.category !== 'MANUAL_REFERENCE' ? (
                <div style={{ textAlign: 'right' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', justifyContent: 'flex-end' }}>
                    <span
                      style={{
                        width: '8px',
                        height: '8px',
                        borderRadius: '50%',
                        background: '#22c55e',
                        display: 'inline-block',
                      }}
                    />
                    <span style={{ fontSize: '12px', fontWeight: 700, color: '#16a34a' }}>
                      LIVE ENGINE (v{selectedPrompt.version})
                    </span>
                  </div>
                  {selectedPrompt.lastPublishedAt && (
                    <span style={{ fontSize: '11px', color: '#94a3b8', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '4px' }}>
                      <Clock size={12} /> Published {new Date(selectedPrompt.lastPublishedAt).toLocaleString()}
                    </span>
                  )}
                </div>
              ) : (
                <div style={{ textAlign: 'right' }}>
                  <span className="badge badge-neutral" style={{ fontSize: '11px' }}>
                    Manual Copy / Paste Tool
                  </span>
                </div>
              )}
            </div>

            {/* Variable pills reference (if applicable) */}
            {selectedPrompt.variables && selectedPrompt.variables.length > 0 && (
              <div
                style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  padding: '10px 14px',
                  marginBottom: '16px',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', fontWeight: 600, color: '#475569', marginBottom: '6px' }}>
                  <Sliders size={13} />
                  <span>Dynamic Template Variables Provided by Server:</span>
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                  {selectedPrompt.variables.map((v, i) => (
                    <span
                      key={i}
                      style={{
                        fontSize: '11px',
                        background: '#ffffff',
                        border: '1px solid #cbd5e1',
                        borderRadius: '6px',
                        padding: '3px 8px',
                        color: '#1e293b',
                      }}
                      title={v.description}
                    >
                      <code style={{ fontWeight: 700, color: '#2563eb' }}>{`{{${v.name}}}`}</code>: {v.description}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Toolbar for Editor */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                marginBottom: '10px',
              }}
            >
              {/* Draft vs Live toggle (for server prompts) */}
              {selectedPrompt.category !== 'MANUAL_REFERENCE' ? (
                <div style={{ display: 'flex', gap: '6px' }}>
                  <button
                    onClick={() => setViewMode('DRAFT')}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '5px',
                      padding: '6px 12px',
                      borderRadius: '6px',
                      border: '1px solid',
                      fontSize: '12px',
                      fontWeight: 600,
                      cursor: 'pointer',
                      background: viewMode === 'DRAFT' ? '#eff6ff' : '#ffffff',
                      borderColor: viewMode === 'DRAFT' ? '#3b82f6' : '#cbd5e1',
                      color: viewMode === 'DRAFT' ? '#1d4ed8' : '#64748b',
                    }}
                  >
                    <Edit3 size={13} />
                    <span>Draft Editor {hasUnpublished ? '• (Edited)' : ''}</span>
                  </button>
                  <button
                    onClick={() => setViewMode('LIVE')}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '5px',
                      padding: '6px 12px',
                      borderRadius: '6px',
                      border: '1px solid',
                      fontSize: '12px',
                      fontWeight: 600,
                      cursor: 'pointer',
                      background: viewMode === 'LIVE' ? '#f0fdf4' : '#ffffff',
                      borderColor: viewMode === 'LIVE' ? '#22c55e' : '#cbd5e1',
                      color: viewMode === 'LIVE' ? '#15803d' : '#64748b',
                    }}
                  >
                    <Eye size={13} />
                    <span>Active Live Prompt (v{selectedPrompt.version})</span>
                  </button>
                </div>
              ) : (
                <div style={{ fontSize: '13px', fontWeight: 600, color: '#334155' }}>
                  Prompt Template Content:
                </div>
              )}

              {/* Utility actions: Copy, Character Count, Reset */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <span style={{ fontSize: '12px', color: '#94a3b8' }}>
                  {(viewMode === 'LIVE' ? selectedPrompt.publishedPrompt : draftText).length} characters
                </span>
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={handleCopyPrompt}
                  style={{
                    padding: '6px 12px',
                    fontSize: '12px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '5px',
                  }}
                  title="Copy full prompt to clipboard"
                >
                  {copied ? <Check size={13} color="#16a34a" /> : <Copy size={13} />}
                  <span>{copied ? 'Copied!' : 'Copy'}</span>
                </button>
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={handleResetToDefault}
                  style={{
                    padding: '6px 12px',
                    fontSize: '12px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '5px',
                  }}
                  title="Reset draft to factory default"
                >
                  <RotateCcw size={13} />
                  <span>Reset Default</span>
                </button>
              </div>
            </div>

            {/* Prompt Textarea */}
            <div style={{ position: 'relative' }}>
              <textarea
                value={viewMode === 'LIVE' ? selectedPrompt.publishedPrompt : draftText}
                onChange={(e) => setDraftText(e.target.value)}
                readOnly={viewMode === 'LIVE'}
                rows={18}
                style={{
                  width: '100%',
                  fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
                  fontSize: '13px',
                  lineHeight: '1.6',
                  padding: '16px',
                  borderRadius: '10px',
                  border: viewMode === 'LIVE' ? '1px solid #bbf7d0' : '1px solid #cbd5e1',
                  background: viewMode === 'LIVE' ? '#fcfdfd' : '#ffffff',
                  color: '#0f172a',
                  resize: 'vertical',
                  boxSizing: 'border-box',
                  outline: 'none',
                }}
              />
            </div>

            {/* Status indicator bar */}
            {selectedPrompt.category !== 'MANUAL_REFERENCE' && (
              <div
                style={{
                  marginTop: '12px',
                  padding: '10px 14px',
                  borderRadius: '8px',
                  background: hasUnpublished ? '#fffbeb' : '#f0fdf4',
                  border: `1px solid ${hasUnpublished ? '#fcd34d' : '#bbf7d0'}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  fontSize: '12px',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  {hasUnpublished ? (
                    <>
                      <AlertCircle size={15} color="#d97706" />
                      <span style={{ color: '#92400e', fontWeight: 600 }}>
                        Unpublished changes in draft. The live server will NOT use these edits until you press{' '}
                        <strong>Publish</strong>.
                      </span>
                    </>
                  ) : (
                    <>
                      <CheckCircle2 size={15} color="#16a34a" />
                      <span style={{ color: '#166534', fontWeight: 600 }}>
                        Live & Draft in sync. The server is actively running this exact prompt version.
                      </span>
                    </>
                  )}
                </div>
                <div style={{ color: '#64748b' }}>
                  Zero Server Restart Required
                </div>
              </div>
            )}

            {/* Bottom Actions: Save | Publish */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'flex-end',
                gap: '12px',
                marginTop: '18px',
                paddingTop: '16px',
                borderTop: '1px solid #e2e8f0',
              }}
            >
              {selectedPrompt.category !== 'MANUAL_REFERENCE' ? (
                <>
                  {/* Save Draft Button */}
                  <button
                    type="button"
                    className="btn-secondary"
                    onClick={handleSaveDraft}
                    disabled={saving || publishing}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '10px 20px',
                      fontSize: '13px',
                      fontWeight: 600,
                    }}
                  >
                    <Save size={16} />
                    <span>{saving ? 'Saving Draft...' : 'Save Draft'}</span>
                  </button>

                  {/* Publish Button */}
                  <button
                    type="button"
                    onClick={handlePublish}
                    disabled={saving || publishing}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      padding: '10px 24px',
                      fontSize: '13px',
                      fontWeight: 700,
                      color: '#ffffff',
                      background: 'linear-gradient(135deg, #16a34a, #15803d)',
                      border: 'none',
                      borderRadius: '8px',
                      cursor: saving || publishing ? 'not-allowed' : 'pointer',
                      boxShadow: '0 4px 12px rgba(22, 163, 74, 0.25)',
                      transition: 'all 0.2s ease',
                      opacity: saving || publishing ? 0.6 : 1,
                    }}
                  >
                    <Zap size={16} />
                    <span>{publishing ? 'Publishing Live...' : 'Publish to Live'}</span>
                  </button>
                </>
              ) : (
                /* For Manual Reference Prompts: Save button & Copy */
                <>
                  <button
                    type="button"
                    className="btn-secondary"
                    onClick={handleCopyPrompt}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '10px 20px',
                      fontSize: '13px',
                      fontWeight: 600,
                    }}
                  >
                    {copied ? <Check size={16} color="#16a34a" /> : <Copy size={16} />}
                    <span>{copied ? 'Copied Prompt!' : 'Copy Full Prompt'}</span>
                  </button>
                  <button
                    type="button"
                    className="btn-primary"
                    onClick={handleSaveDraft}
                    disabled={saving}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '10px 24px',
                      fontSize: '13px',
                      fontWeight: 600,
                    }}
                  >
                    <Save size={16} />
                    <span>{saving ? 'Saving...' : 'Save Changes'}</span>
                  </button>
                </>
              )}
            </div>
          </div>
        ) : (
          <div className="card" style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
            Select an AI Prompt from the list on the left to inspect or edit.
          </div>
        )}
      </div>
    </div>
  );
};

export default AiPromptsPage;
