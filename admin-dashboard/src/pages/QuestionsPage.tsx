import React, { useState, useEffect } from 'react';
import { api } from '../services/api';
import * as XLSX from 'xlsx';
import { 
  Plus, 
  Upload, 
  Search, 
  Edit3, 
  Trash2, 
  Link2, 
  CheckCircle, 
  X, 
  FileSpreadsheet,
  Download,
  ChevronDown,
  ChevronUp
} from 'lucide-react';

export const QuestionsPage: React.FC = () => {
  const [questions, setQuestions] = useState<any[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [syllabusData, setSyllabusData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  // Filters & Pagination
  const [search, setSearch] = useState('');
  const [selectedSubtopic, setSelectedSubtopic] = useState('');
  const [selectedDifficulty, setSelectedDifficulty] = useState('');
  const [selectedSource, setSelectedSource] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Expanded row details
  const [expandedRow, setExpandedRow] = useState<string | null>(null);

  // Modals
  const [questionModal, setQuestionModal] = useState<{ open: boolean; editItem?: any }>({ open: false });
  const [relinkModal, setRelinkModal] = useState<{ open: boolean; questionId?: string; currentSubtopicId?: string }>({ open: false });
  const [bulkModal, setBulkModal] = useState(false);

  useEffect(() => {
    fetchSyllabusDropdowns();
    fetchStats();
  }, []);

  useEffect(() => {
    fetchQuestions();
  }, [page, search, selectedSubtopic, selectedDifficulty, selectedSource]);

  const fetchSyllabusDropdowns = async () => {
    try {
      const res = await api.getSyllabus();
      if (res.data?.success) {
        setSyllabusData(res.data.data.subjects || []);
      }
    } catch (err) {
      console.error('Failed to load syllabus dropdowns', err);
    }
  };

  const fetchStats = async () => {
    try {
      const res = await api.getQuestionStats();
      if (res.data?.success) {
        setStats(res.data.data);
      }
    } catch (err) {
      console.error('Failed to load question stats', err);
    }
  };

  const fetchQuestions = async () => {
    setLoading(true);
    try {
      const params: any = { page, limit: 12 };
      if (search.trim()) params.search = search.trim();
      if (selectedSubtopic) params.subtopicId = selectedSubtopic;
      if (selectedDifficulty) params.difficulty = selectedDifficulty;
      if (selectedSource) params.sourceType = selectedSource;

      const res = await api.getQuestions(params);
      if (res.data?.success) {
        setQuestions(res.data.data.questions || []);
        setTotalPages(res.data.data.pagination?.totalPages || 1);
        setTotalCount(res.data.data.pagination?.total || 0);
      }
    } catch (err) {
      console.error('Failed to fetch questions', err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to permanently delete this question?')) return;
    try {
      await api.deleteQuestion(id);
      fetchQuestions();
      fetchStats();
    } catch (err: any) {
      alert(`Delete failed: ${err.response?.data?.message || err.message}`);
    }
  };

  // Helper to extract flat subtopics for dropdowns
  const allSubtopics: Array<{ id: string; name: string; topicName: string }> = [];
  syllabusData.forEach((s) => {
    s.topics?.forEach((t: any) => {
      t.subtopics?.forEach((sub: any) => {
        allSubtopics.push({ id: sub.id, name: sub.name, topicName: t.name });
      });
    });
  });

  return (
    <div>
      {/* 1. OVERVIEW STATS BANNER */}
      {stats && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginBottom: '24px' }}>
          <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
            <span style={{ fontSize: '12px', color: '#7b809a' }}>Total Questions</span>
            <h3 style={{ fontSize: '22px', fontWeight: 700, marginTop: '4px' }}>{stats.total ?? 0}</h3>
            <span style={{ fontSize: '11px', color: '#4caf50' }}>Active in engine</span>
          </div>

          <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
            <span style={{ fontSize: '12px', color: '#7b809a' }}>Difficulty Split</span>
            <div style={{ display: 'flex', gap: '8px', marginTop: '6px', fontSize: '12px' }}>
              <span className="badge badge-success">Easy: {stats.byDifficulty?.easy || 0}</span>
              <span className="badge badge-warning">Med: {stats.byDifficulty?.medium || 0}</span>
              <span className="badge badge-danger">Hard: {stats.byDifficulty?.hard || 0}</span>
            </div>
          </div>

          <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
            <span style={{ fontSize: '12px', color: '#7b809a' }}>Origin Source</span>
            <div style={{ display: 'flex', gap: '8px', marginTop: '6px', fontSize: '12px' }}>
              <span className="badge badge-info">AI Gen: {stats.bySource?.aiGenerated || 0}</span>
              <span className="badge badge-neutral">Manual/Import: {stats.bySource?.manual || 0}</span>
            </div>
          </div>

          <div className="card" style={{ padding: '16px', marginBottom: 0 }}>
            <span style={{ fontSize: '12px', color: '#7b809a' }}>Status</span>
            <div style={{ display: 'flex', gap: '8px', marginTop: '6px', fontSize: '12px' }}>
              <span className="badge badge-success">Published: {stats.byStatus?.published || 0}</span>
              <span className="badge badge-neutral">Draft: {stats.byStatus?.draft || 0}</span>
            </div>
          </div>
        </div>
      )}

      {/* 2. FILTER & ACTION BAR */}
      <div className="card" style={{ padding: '20px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <h3 style={{ fontSize: '18px', fontWeight: 700 }}>Question Bank Explorer</h3>
            <p style={{ fontSize: '12px', color: '#7b809a' }}>
              Showing {totalCount} total questions
            </p>
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <button className="btn-secondary" onClick={() => setBulkModal(true)}>
              <FileSpreadsheet size={15} />
              <span>Bulk Import (.xlsx / .csv)</span>
            </button>
            <button className="btn-primary" onClick={() => setQuestionModal({ open: true })}>
              <Plus size={15} />
              <span>Add Question</span>
            </button>
          </div>
        </div>

        {/* Filter controls */}
        <div className="filter-bar">
          <div className="search-input-wrap">
            <Search size={16} />
            <input
              type="text"
              className="input-custom"
              placeholder="Search by question prompt keywords..."
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </div>

          {/* Subtopic Filter */}
          <select
            className="select-custom"
            value={selectedSubtopic}
            onChange={(e) => {
              setSelectedSubtopic(e.target.value);
              setPage(1);
            }}
          >
            <option value="">All Subtopics</option>
            {allSubtopics.map((sub) => (
              <option key={sub.id} value={sub.id}>
                {sub.topicName} → {sub.name}
              </option>
            ))}
          </select>

          {/* Difficulty Filter */}
          <select
            className="select-custom"
            value={selectedDifficulty}
            onChange={(e) => {
              setSelectedDifficulty(e.target.value);
              setPage(1);
            }}
          >
            <option value="">All Difficulties</option>
            <option value="EASY">EASY</option>
            <option value="MEDIUM">MEDIUM</option>
            <option value="HARD">HARD</option>
          </select>

          {/* Source Type Filter */}
          <select
            className="select-custom"
            value={selectedSource}
            onChange={(e) => {
              setSelectedSource(e.target.value);
              setPage(1);
            }}
          >
            <option value="">All Sources</option>
            <option value="MANUAL">Manual / Sheet Import</option>
            <option value="AI_GENERATED">AI Generated</option>
          </select>

          {(search || selectedSubtopic || selectedDifficulty || selectedSource) && (
            <button
              className="btn-secondary"
              style={{ padding: '8px 12px', fontSize: '12px' }}
              onClick={() => {
                setSearch('');
                setSelectedSubtopic('');
                setSelectedDifficulty('');
                setSelectedSource('');
                setPage(1);
              }}
            >
              Reset Filters
            </button>
          )}
        </div>

        {/* 3. QUESTION LIST TABLE */}
        <div className="table-responsive">
          <table className="table-custom">
            <thead>
              <tr>
                <th style={{ width: '40px' }}></th>
                <th style={{ width: '45%' }}>Prompt & Options</th>
                <th>Subtopic</th>
                <th>Difficulty</th>
                <th>Source</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: '#7b809a' }}>
                    Loading questions...
                  </td>
                </tr>
              ) : questions.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: '#7b809a' }}>
                    No questions matched your filter criteria.
                  </td>
                </tr>
              ) : (
                questions.map((q) => {
                  const isExpanded = expandedRow === q.id;
                  const options = Array.isArray(q.options) ? q.options : [];

                  return (
                    <React.Fragment key={q.id}>
                      <tr>
                        <td>
                          <button
                            style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#7b809a' }}
                            onClick={() => setExpandedRow(isExpanded ? null : q.id)}
                          >
                            {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                          </button>
                        </td>
                        <td>
                          <div style={{ fontWeight: 600, color: '#1e293b', marginBottom: '6px' }}>
                            {q.prompt}
                          </div>
                          {/* Options pills preview */}
                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                            {options.map((opt: any, idx: number) => {
                              const isCorrect = (opt.id || ['A', 'B', 'C', 'D'][idx]) === q.correctAnswer;
                              return (
                                <span
                                  key={idx}
                                  style={{
                                    fontSize: '11px',
                                    padding: '2px 8px',
                                    borderRadius: '4px',
                                    background: isCorrect ? '#dcfce7' : '#f1f5f9',
                                    color: isCorrect ? '#15803d' : '#475569',
                                    fontWeight: isCorrect ? 700 : 400,
                                    border: isCorrect ? '1px solid #86efac' : '1px solid transparent',
                                  }}
                                >
                                  {opt.id || ['A', 'B', 'C', 'D'][idx]}: {opt.text || opt} {isCorrect && '✓'}
                                </span>
                              );
                            })}
                          </div>
                        </td>
                        <td>
                          <div style={{ fontSize: '13px', fontWeight: 500 }}>
                            {q.subtopic?.name || 'Unlinked'}
                          </div>
                          <div style={{ fontSize: '11px', color: '#7b809a' }}>
                            {q.topic?.name}
                          </div>
                        </td>
                        <td>
                          <span className={`badge ${
                            q.difficulty === 'EASY' ? 'badge-success' : q.difficulty === 'MEDIUM' ? 'badge-warning' : 'badge-danger'
                          }`}>
                            {q.difficulty}
                          </span>
                        </td>
                        <td>
                          <span className={`badge ${q.sourceType === 'AI_GENERATED' ? 'badge-info' : 'badge-neutral'}`}>
                            {q.sourceType === 'AI_GENERATED' ? 'AI' : 'MANUAL'}
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          <div style={{ display: 'inline-flex', gap: '6px' }}>
                            <button
                              className="btn-secondary"
                              style={{ padding: '6px 8px' }}
                              title="Relink to another subtopic"
                              onClick={() => setRelinkModal({ open: true, questionId: q.id, currentSubtopicId: q.subtopicId })}
                            >
                              <Link2 size={13} />
                            </button>
                            <button
                              className="btn-secondary"
                              style={{ padding: '6px 8px' }}
                              title="Edit Question"
                              onClick={() => setQuestionModal({ open: true, editItem: q })}
                            >
                              <Edit3 size={13} />
                            </button>
                            <button
                              className="btn-secondary"
                              style={{ padding: '6px 8px', color: '#ef5350' }}
                              title="Hard Delete"
                              onClick={() => handleDelete(q.id)}
                            >
                              <Trash2 size={13} />
                            </button>
                          </div>
                        </td>
                      </tr>

                      {/* Expandable explanation and details */}
                      {isExpanded && (
                        <tr style={{ background: '#f8fafc' }}>
                          <td colSpan={6} style={{ padding: '16px 24px', borderBottom: '1px solid #e2e8f0' }}>
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                              <div>
                                <h5 style={{ fontSize: '12px', textTransform: 'uppercase', color: '#7b809a', marginBottom: '4px' }}>
                                  Explanation & Method
                                </h5>
                                <p style={{ fontSize: '13px', lineHeight: 1.5, color: '#334155' }}>
                                  {q.explanation || 'No explanation provided.'}
                                </p>
                                {q.method && (
                                  <p style={{ fontSize: '12px', color: '#64748b', marginTop: '6px' }}>
                                    <strong>Shortcut/Method:</strong> {q.method}
                                  </p>
                                )}
                              </div>
                              <div>
                                <h5 style={{ fontSize: '12px', textTransform: 'uppercase', color: '#7b809a', marginBottom: '4px' }}>
                                  Hints & Metadata
                                </h5>
                                {Array.isArray(q.hints) && q.hints.length > 0 ? (
                                  <ul style={{ paddingLeft: '18px', fontSize: '12px', color: '#475569' }}>
                                    {q.hints.map((h: string, i: number) => (
                                      <li key={i}>{h}</li>
                                    ))}
                                  </ul>
                                ) : (
                                  <p style={{ fontSize: '12px', color: '#94a3b8' }}>No hints registered.</p>
                                )}
                                <div style={{ fontSize: '11px', color: '#94a3b8', marginTop: '8px' }}>
                                  Est. Time: {q.estimatedTimeSeconds}s | Mode: {q.calculationMode} | ID: {q.id}
                                </div>
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination controls */}
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
      {/* BULK IMPORT MODAL (XLSX / CSV / JSON) */}
      {/* ============================================================== */}
      {bulkModal && (
        <BulkImportModal
          subtopics={allSubtopics}
          onClose={() => setBulkModal(false)}
          onSuccess={() => {
            setBulkModal(false);
            fetchQuestions();
            fetchStats();
          }}
        />
      )}

      {/* ============================================================== */}
      {/* ADD / EDIT QUESTION MODAL */}
      {/* ============================================================== */}
      {questionModal.open && (
        <QuestionFormModal
          subtopics={allSubtopics}
          editItem={questionModal.editItem}
          onClose={() => setQuestionModal({ open: false })}
          onSuccess={() => {
            setQuestionModal({ open: false });
            fetchQuestions();
            fetchStats();
          }}
        />
      )}

      {/* ============================================================== */}
      {/* RELINK QUESTION SUBTOPIC MODAL */}
      {/* ============================================================== */}
      {relinkModal.open && (
        <RelinkModal
          questionId={relinkModal.questionId!}
          currentSubtopicId={relinkModal.currentSubtopicId!}
          subtopics={allSubtopics}
          onClose={() => setRelinkModal({ open: false })}
          onSuccess={() => {
            setRelinkModal({ open: false });
            fetchQuestions();
          }}
        />
      )}
    </div>
  );
};

// ==============================================================
// BULK IMPORT MODAL COMPONENT (XLSX, CSV)
// ==============================================================
const BulkImportModal: React.FC<{
  subtopics: Array<{ id: string; name: string; topicName: string }>;
  onClose: () => void;
  onSuccess: () => void;
}> = ({ subtopics, onClose, onSuccess }) => {
  const [defaultSubtopicId, setDefaultSubtopicId] = useState(subtopics[0]?.id || '');
  const [parsedRows, setParsedRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [importSummary, setImportSummary] = useState<any>(null);

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      try {
        const bstr = evt.target?.result;
        const wb = XLSX.read(bstr, { type: 'binary' });
        const wsname = wb.SheetNames[0];
        const ws = wb.Sheets[wsname];
        const data = XLSX.utils.sheet_to_json(ws);
        setParsedRows(data);
      } catch (err: any) {
        alert(`Failed to parse file: ${err.message}`);
      }
    };
    reader.readAsBinaryString(file);
  };

  const handleDownloadSample = () => {
    const sampleData = [
      {
        prompt: 'What is 25% of 80?',
        optionA: '15',
        optionB: '20',
        optionC: '25',
        optionD: '30',
        correctAnswer: 'B',
        difficulty: 'EASY',
        explanation: '25% of 80 is 80 / 4 = 20.',
        hints: 'Think of 25% as one quarter.',
        calculationMode: 'MENTAL',
      },
      {
        prompt: 'If a car travels at 60 km/h, how far does it travel in 2.5 hours?',
        optionA: '120 km',
        optionB: '140 km',
        optionC: '150 km',
        optionD: '160 km',
        correctAnswer: 'C',
        difficulty: 'EASY',
        explanation: 'Distance = Speed * Time = 60 * 2.5 = 150 km.',
        hints: 'Multiply 60 by 2 then add half of 60.',
        calculationMode: 'MENTAL',
      },
    ];

    const ws = XLSX.utils.json_to_sheet(sampleData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Sample_Questions');
    XLSX.writeFile(wb, 'aptiqu_bulk_questions_template.xlsx');
  };

  const handleImportSubmit = async () => {
    if (parsedRows.length === 0) return;
    setLoading(true);
    try {
      const res = await api.bulkImportQuestions(parsedRows, defaultSubtopicId);
      if (res.data?.success) {
        setImportSummary(res.data.data);
      }
    } catch (err: any) {
      alert(`Import failed: ${err.response?.data?.message || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '780px' }}>
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <FileSpreadsheet size={20} color="#1a73e8" />
            <h3 className="modal-title">Bulk Import Questions from Google Sheet / Excel</h3>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
            <X size={18} />
          </button>
        </div>

        <div className="modal-body">
          {importSummary ? (
            <div style={{ textAlign: 'center', padding: '24px' }}>
              <CheckCircle size={48} color="#4caf50" style={{ margin: '0 auto 12px auto' }} />
              <h4 style={{ fontSize: '18px', fontWeight: 700 }}>Import Complete</h4>
              <p style={{ marginTop: '8px', fontSize: '14px', color: '#475569' }}>
                Successfully imported <strong>{importSummary.successCount}</strong> questions.
                {importSummary.failedCount > 0 && ` (${importSummary.failedCount} duplicates or errors skipped)`}
              </p>
              {importSummary.errors?.length > 0 && (
                <div style={{ marginTop: '16px', textAlign: 'left', background: '#fff1f2', padding: '12px', borderRadius: '8px', fontSize: '12px' }}>
                  <strong>Skipped details:</strong>
                  <ul>
                    {importSummary.errors.map((err: any, i: number) => (
                      <li key={i}>Row {err.index}: {err.reason}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          ) : (
            <>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <p style={{ fontSize: '13px', color: '#475569' }}>
                  Upload an <code>.xlsx</code> or <code>.csv</code> file with columns: <strong>prompt, optionA, optionB, optionC, optionD, correctAnswer</strong>.
                </p>
                <button className="btn-secondary" style={{ fontSize: '12px', padding: '6px 12px' }} onClick={handleDownloadSample}>
                  <Download size={14} />
                  <span>Download Template</span>
                </button>
              </div>

              <div className="form-group" style={{ marginTop: '8px' }}>
                <label className="form-label">Target Subtopic for Imported Questions</label>
                <select className="form-control" value={defaultSubtopicId} onChange={(e) => setDefaultSubtopicId(e.target.value)}>
                  {subtopics.map((s) => (
                    <option key={s.id} value={s.id}>{s.topicName} → {s.name}</option>
                  ))}
                </select>
              </div>

              <div style={{
                border: '2px dashed #cbd5e1',
                borderRadius: '8px',
                padding: '24px',
                textAlign: 'center',
                background: '#f8fafc',
                marginTop: '12px',
              }}>
                <Upload size={32} color="#1a73e8" style={{ marginBottom: '8px' }} />
                <p style={{ fontSize: '14px', fontWeight: 600 }}>Select or Drop Excel/CSV File</p>
                <input
                  type="file"
                  accept=".xlsx, .xls, .csv"
                  onChange={handleFileUpload}
                  style={{ marginTop: '12px' }}
                />
              </div>

              {parsedRows.length > 0 && (
                <div style={{ marginTop: '16px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                    <span style={{ fontSize: '13px', fontWeight: 600 }}>Parsed Rows Preview ({parsedRows.length} questions):</span>
                  </div>
                  <div style={{ maxHeight: '160px', overflowY: 'auto', border: '1px solid #e2e8f0', borderRadius: '6px' }}>
                    <table className="table-custom" style={{ fontSize: '11px' }}>
                      <thead>
                        <tr>
                          <th>#</th>
                          <th>Prompt</th>
                          <th>Ans</th>
                          <th>Diff</th>
                        </tr>
                      </thead>
                      <tbody>
                        {parsedRows.slice(0, 10).map((r, i) => (
                          <tr key={i}>
                            <td>{i + 1}</td>
                            <td>{r.prompt || r.question}</td>
                            <td>{r.correctAnswer || r.answer}</td>
                            <td>{r.difficulty || 'EASY'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        <div className="modal-footer">
          {importSummary ? (
            <button className="btn-primary" onClick={onSuccess}>Done</button>
          ) : (
            <>
              <button className="btn-secondary" onClick={onClose}>Cancel</button>
              <button
                className="btn-primary"
                disabled={parsedRows.length === 0 || loading}
                onClick={handleImportSubmit}
              >
                {loading ? 'Importing Questions...' : `Import ${parsedRows.length} Questions`}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

// ==============================================================
// ADD / EDIT QUESTION MODAL COMPONENT
// ==============================================================
const QuestionFormModal: React.FC<{
  subtopics: Array<{ id: string; name: string; topicName: string }>;
  editItem?: any;
  onClose: () => void;
  onSuccess: () => void;
}> = ({ subtopics, editItem, onClose, onSuccess }) => {
  const [subtopicId, setSubtopicId] = useState(editItem?.subtopicId || subtopics[0]?.id || '');
  const [prompt, setPrompt] = useState(editItem?.prompt || '');
  
  // Options A, B, C, D
  const existingOptions = Array.isArray(editItem?.options) ? editItem.options : [];
  const [optA, setOptA] = useState(existingOptions[0]?.text || existingOptions[0] || '');
  const [optB, setOptB] = useState(existingOptions[1]?.text || existingOptions[1] || '');
  const [optC, setOptC] = useState(existingOptions[2]?.text || existingOptions[2] || '');
  const [optD, setOptD] = useState(existingOptions[3]?.text || existingOptions[3] || '');
  const [correctAnswer, setCorrectAnswer] = useState(editItem?.correctAnswer || 'A');

  const [difficulty, setDifficulty] = useState(editItem?.difficulty || 'EASY');
  const [calculationMode, setCalculationMode] = useState(editItem?.calculationMode || 'MENTAL');
  const [estimatedTime, setEstimatedTime] = useState(editItem?.estimatedTimeSeconds || 60);
  const [explanation, setExplanation] = useState(editItem?.explanation || '');
  const [method, setMethod] = useState(editItem?.method || '');
  const [hintsText, setHintsText] = useState((editItem?.hints || []).join('\n'));
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    const options = [
      { id: 'A', text: optA },
      { id: 'B', text: optB },
      { id: 'C', text: optC },
      { id: 'D', text: optD },
    ];

    const hints = hintsText
      .split('\n')
      .map((h: string) => h.trim())
      .filter((h: string) => h.length > 0);

    const payload = {
      subtopicId,
      prompt,
      options,
      correctAnswer,
      difficulty,
      calculationMode,
      estimatedTimeSeconds: Number(estimatedTime) || 60,
      explanation,
      method,
      hints,
    };

    try {
      if (editItem) {
        await api.updateQuestion(editItem.id, payload);
      } else {
        await api.createQuestion(payload);
      }
      onSuccess();
    } catch (err: any) {
      alert(`Save failed: ${err.response?.data?.message || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '680px' }}>
        <div className="modal-header">
          <h3 className="modal-title">{editItem ? 'Edit Question' : 'Add New Question'}</h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}><X size={18} /></button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            <div className="form-group">
              <label className="form-label">Subtopic Assignment</label>
              <select className="form-control" value={subtopicId} onChange={(e) => setSubtopicId(e.target.value)} required>
                {subtopics.map((s) => (
                  <option key={s.id} value={s.id}>{s.topicName} → {s.name}</option>
                ))}
              </select>
            </div>

            <div className="form-group">
              <label className="form-label">Question Prompt</label>
              <textarea className="form-control" value={prompt} onChange={(e) => setPrompt(e.target.value)} required placeholder="e.g. A store offers a 20% discount..." />
            </div>

            {/* Options */}
            <div className="form-group">
              <label className="form-label">Options (Mark Correct Radio)</label>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                {[
                  { id: 'A', val: optA, setter: setOptA },
                  { id: 'B', val: optB, setter: setOptB },
                  { id: 'C', val: optC, setter: setOptC },
                  { id: 'D', val: optD, setter: setOptD },
                ].map((opt) => (
                  <div key={opt.id} style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <input
                      type="radio"
                      name="correctAnswerRadio"
                      checked={correctAnswer === opt.id}
                      onChange={() => setCorrectAnswer(opt.id)}
                    />
                    <span style={{ fontWeight: 700, fontSize: '13px' }}>{opt.id}:</span>
                    <input
                      type="text"
                      className="form-control"
                      value={opt.val}
                      onChange={(e) => opt.setter(e.target.value)}
                      placeholder={`Option ${opt.id}`}
                      required
                    />
                  </div>
                ))}
              </div>
            </div>

            {/* Difficulty & Mode */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px' }}>
              <div className="form-group">
                <label className="form-label">Difficulty</label>
                <select className="form-control" value={difficulty} onChange={(e) => setDifficulty(e.target.value)}>
                  <option value="EASY">EASY</option>
                  <option value="MEDIUM">MEDIUM</option>
                  <option value="HARD">HARD</option>
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">Calculation Mode</label>
                <select className="form-control" value={calculationMode} onChange={(e) => setCalculationMode(e.target.value)}>
                  <option value="MENTAL">MENTAL</option>
                  <option value="LIGHT_PEN_AND_PAPER">LIGHT PEN & PAPER</option>
                  <option value="PEN_AND_PAPER">PEN & PAPER</option>
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">Time Limit (Sec)</label>
                <input type="number" className="form-control" value={estimatedTime} onChange={(e) => setEstimatedTime(Number(e.target.value))} />
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Explanation</label>
              <textarea className="form-control" value={explanation} onChange={(e) => setExplanation(e.target.value)} placeholder="Step-by-step solution..." />
            </div>

            <div className="form-group">
              <label className="form-label">Solving Method / Shortcut</label>
              <input type="text" className="form-control" value={method} onChange={(e) => setMethod(e.target.value)} placeholder="e.g. Unit digit method, ratio shortcut..." />
            </div>

            <div className="form-group">
              <label className="form-label">Hints (One per line)</label>
              <textarea className="form-control" value={hintsText} onChange={(e) => setHintsText(e.target.value)} placeholder="Hint 1&#10;Hint 2" />
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={loading}>{loading ? 'Saving...' : 'Save Question'}</button>
          </div>
        </form>
      </div>
    </div>
  );
};

// ==============================================================
// RELINK SUBTOPIC MODAL COMPONENT
// ==============================================================
const RelinkModal: React.FC<{
  questionId: string;
  currentSubtopicId: string;
  subtopics: Array<{ id: string; name: string; topicName: string }>;
  onClose: () => void;
  onSuccess: () => void;
}> = ({ questionId, currentSubtopicId, subtopics, onClose, onSuccess }) => {
  const [newSubtopicId, setNewSubtopicId] = useState(currentSubtopicId);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      await api.relinkQuestion(questionId, newSubtopicId);
      onSuccess();
    } catch (err: any) {
      alert(`Relink failed: ${err.response?.data?.message || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '480px' }}>
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Link2 size={18} color="#1a73e8" />
            <h3 className="modal-title">Relink Question to New Subtopic</h3>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}><X size={18} /></button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            <p style={{ fontSize: '13px', color: '#475569' }}>
              Moving this question will update its subtopic, topic, and subject relationships automatically.
            </p>
            <div className="form-group" style={{ marginTop: '12px' }}>
              <label className="form-label">New Target Subtopic</label>
              <select className="form-control" value={newSubtopicId} onChange={(e) => setNewSubtopicId(e.target.value)}>
                {subtopics.map((s) => (
                  <option key={s.id} value={s.id}>{s.topicName} → {s.name}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={loading}>{loading ? 'Relinking...' : 'Relink Question'}</button>
          </div>
        </form>
      </div>
    </div>
  );
};
