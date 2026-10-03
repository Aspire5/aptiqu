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
  const [selectedPyq, setSelectedPyq] = useState<'ALL' | 'PYQ_ONLY' | 'NON_PYQ'>('ALL');
  const [selectedStatus, setSelectedStatus] = useState('');
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
  }, [page, search, selectedSubtopic, selectedDifficulty, selectedSource, selectedPyq, selectedStatus]);

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
      if (selectedPyq === 'PYQ_ONLY') params.pyqOnly = 'true';
      if (selectedPyq === 'NON_PYQ') params.pyqOnly = 'false';
      if (selectedStatus && selectedStatus !== 'ALL') params.status = selectedStatus;

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
            <span style={{ fontSize: '11px', color: '#4caf50' }}>Active questions</span>
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

          {/* PYQ Filter */}
          <select
            className="select-custom"
            value={selectedPyq}
            onChange={(e) => {
              setSelectedPyq(e.target.value as any);
              setPage(1);
            }}
          >
            <option value="ALL">All PYQ Status</option>
            <option value="PYQ_ONLY">🏛️ PYQ Questions Only</option>
            <option value="NON_PYQ">Non-PYQ Questions</option>
          </select>

          {/* Status Filter */}
          <select
            className="select-custom"
            value={selectedStatus}
            onChange={(e) => {
              setSelectedStatus(e.target.value);
              setPage(1);
            }}
          >
            <option value="ALL">All Statuses</option>
            <option value="PUBLISHED">Published</option>
            <option value="REVIEW">Review Required</option>
            <option value="DRAFT">Draft</option>
          </select>

          {(search || selectedSubtopic || selectedDifficulty || selectedSource || selectedPyq !== 'ALL' || (selectedStatus && selectedStatus !== 'ALL')) && (
            <button
              className="btn-secondary"
              style={{ padding: '8px 12px', fontSize: '12px' }}
              onClick={() => {
                setSearch('');
                setSelectedSubtopic('');
                setSelectedDifficulty('');
                setSelectedSource('');
                setSelectedPyq('ALL');
                setSelectedStatus('');
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
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap', marginBottom: '6px' }}>
                            {q.externalKey && (
                              <span style={{ fontSize: '10px', color: '#475569', background: '#f1f5f9', padding: '1px 6px', borderRadius: '4px', fontFamily: 'monospace', border: '1px solid #e2e8f0' }}>
                                #{q.externalKey}
                              </span>
                            )}
                            {q.pyq && (
                              <span className="badge" style={{ fontSize: '11px', background: '#fef3c7', color: '#92400e', border: '1px solid #fde68a', fontWeight: 600 }}>
                                🏛️ {q.pyq}
                              </span>
                            )}
                            {q.status === 'REVIEW' && (
                              <span className="badge" style={{ fontSize: '10px', background: '#fef9c3', color: '#854d0e', border: '1px solid #fde047', fontWeight: 600 }}>
                                ⚠️ REVIEW REQUIRED
                              </span>
                            )}
                            {q.preferredSolution && (
                              <span className="badge" style={{ fontSize: '10px', background: '#ecfdf5', color: '#047857', border: '1px solid #a7f3d0' }}>
                                ⭐ Preferred: {q.preferredSolution}
                              </span>
                            )}
                          </div>
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

                      {/* Expandable explanation, dual-solution and provenance */}
                      {isExpanded && (
                        <tr style={{ background: '#f8fafc' }}>
                          <td colSpan={6} style={{ padding: '20px 24px', borderBottom: '1px solid #e2e8f0' }}>
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginBottom: '16px' }}>
                              {/* Solution 1: Book Method */}
                              <div style={{ background: '#ffffff', padding: '14px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                                  <h5 style={{ fontSize: '13px', fontWeight: 700, color: '#1e293b', margin: 0 }}>
                                    📖 Solution 1 (Book Method)
                                  </h5>
                                  {q.preferredSolution === 'BOOK' && (
                                    <span className="badge badge-success" style={{ fontSize: '10px' }}>⭐ Preferred Solution</span>
                                  )}
                                </div>
                                <p style={{ fontSize: '13px', lineHeight: 1.5, color: '#334155', whiteSpace: 'pre-wrap' }}>
                                  {q.explanation || 'No standard explanation provided.'}
                                </p>
                                {q.method && (
                                  <p style={{ fontSize: '12px', color: '#64748b', marginTop: '6px' }}>
                                    <strong>Formula/Method:</strong> {q.method}
                                  </p>
                                )}
                              </div>

                              {/* Solution 2: Alternative Shortcut */}
                              <div style={{ background: '#ffffff', padding: '14px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                                  <h5 style={{ fontSize: '13px', fontWeight: 700, color: '#1e293b', margin: 0 }}>
                                    ⚡ Solution 2 (Alternative / Speed Shortcut)
                                  </h5>
                                  {q.preferredSolution === 'ALTERNATIVE' && (
                                    <span className="badge badge-success" style={{ fontSize: '10px' }}>⭐ Preferred Solution</span>
                                  )}
                                </div>
                                <p style={{ fontSize: '13px', lineHeight: 1.5, color: '#334155', whiteSpace: 'pre-wrap' }}>
                                  {q.alternativeExplanation || <em style={{ color: '#94a3b8' }}>No alternative speed solution provided.</em>}
                                </p>
                                {q.preferredReason && (
                                  <div style={{ marginTop: '8px', padding: '8px', background: '#ecfdf5', borderRadius: '6px', fontSize: '11px', color: '#065f46' }}>
                                    <strong>Why Preferred:</strong> {q.preferredReason}
                                  </div>
                                )}
                              </div>
                            </div>

                            {/* Provenance & Metadata */}
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', fontSize: '12px', color: '#64748b', background: '#f1f5f9', padding: '12px 16px', borderRadius: '8px' }}>
                              <div>
                                <div><strong>Source Book:</strong> {q.sourceBook || 'Not specified'} {q.sourceEdition ? `(${q.sourceEdition})` : ''}</div>
                                <div><strong>Chapter / Pages:</strong> {q.sourceChapter || 'N/A'} {q.sourcePageRange ? `[${q.sourcePageRange}]` : ''}</div>
                                <div><strong>Generation Method:</strong> {q.generationMethod || 'HUMAN_MANUAL'}</div>
                              </div>
                              <div>
                                <div><strong>PYQ Exam:</strong> {q.pyq || 'None (Standard textbook practice)'}</div>
                                <div><strong>Hints:</strong> {Array.isArray(q.hints) && q.hints.length > 0 ? q.hints.join(', ') : 'None'}</div>
                                <div><strong>ID / ExtKey:</strong> {q.id} {q.externalKey ? `(Ext: ${q.externalKey})` : ''}</div>
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
  const [defaultSubtopicId, setDefaultSubtopicId] = useState('');
  const [parsedRows, setParsedRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [importSummary, setImportSummary] = useState<any>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setErrorMessage(null);
    setImportSummary(null);

    const reader = new FileReader();
    if (file.name.toLowerCase().endsWith('.json')) {
      reader.onload = (evt) => {
        try {
          const content = evt.target?.result as string;
          const parsed = JSON.parse(content);
          const rows = Array.isArray(parsed) ? parsed : (parsed.questions || parsed.data || []);
          if (!Array.isArray(rows) || rows.length === 0) {
            throw new Error('JSON file must contain an array of question objects (or an object with a "questions" array).');
          }
          setParsedRows(rows);
        } catch (err: any) {
          setErrorMessage(`Failed to parse JSON file: ${err.message}`);
          alert(`Failed to parse JSON file: ${err.message}`);
        }
      };
      reader.readAsText(file);
    } else {
      reader.onload = (evt) => {
        try {
          const bstr = evt.target?.result;
          const wb = XLSX.read(bstr, { type: 'binary' });
          const wsname = wb.SheetNames[0];
          const ws = wb.Sheets[wsname];
          const data = XLSX.utils.sheet_to_json(ws);
          setParsedRows(data);
        } catch (err: any) {
          setErrorMessage(`Failed to parse file: ${err.message}`);
          alert(`Failed to parse file: ${err.message}`);
        }
      };
      reader.readAsBinaryString(file);
    }
  };

  const handleDownloadSample = () => {
    const sampleData = [
      {
        externalQuestionKey: 'rs-agg-ch01-q001',
        externalSubtopicKey: 'ns-01-place-value-notation',
        prompt: 'What is the place value of 7 in 84725?',
        optionA: '70',
        optionB: '700',
        optionC: '7000',
        optionD: '7',
        correctAnswer: 'B',
        difficulty: 'EASY',
        explanation: '7 is in hundreds place, so 7 * 100 = 700.',
        method: 'Standard Place Value Notation',
        alternativeExplanation: 'Count digits to the right: 2 digits = two zeros = 700.',
        preferredSolution: 'ALTERNATIVE',
        preferredReason: 'Faster mental determination.',
        pyq: 'SSC CGL (2022)',
        sourceBook: 'Quantitative Aptitude for Competitive Examinations',
        sourceEdition: '2024 Revised',
        sourceChapter: 'Chapter 01: Number System',
        sourcePageRange: 'pp. 12-14',
        hints: 'Look at the hundreds digit position.',
        calculationMode: 'MENTAL',
      },
      {
        externalQuestionKey: 'rs-agg-ch01-q002',
        externalSubtopicKey: 'ns-02-number-types-and-rationality',
        prompt: 'Which of the following numbers is irrational?',
        optionA: '0.333...',
        optionB: 'sqrt(4)',
        optionC: 'sqrt(7)',
        optionD: '22/7',
        correctAnswer: 'C',
        difficulty: 'MEDIUM',
        explanation: 'sqrt(7) is non-repeating and non-terminating, hence irrational.',
        method: 'Definition of Irrational Numbers',
        alternativeExplanation: '4 is a perfect square so sqrt(4)=2 (rational). 7 is not a square.',
        preferredSolution: 'BOOK',
        preferredReason: 'Standard definition check.',
        pyq: 'CAT (2018)',
        sourceBook: 'Quantitative Aptitude for Competitive Examinations',
        sourceEdition: '2024 Revised',
        sourceChapter: 'Chapter 01: Number System',
        sourcePageRange: 'pp. 15-16',
        hints: 'Check if the square root yields an integer.',
        calculationMode: 'CONCEPTUAL',
      },
    ];

    const ws = XLSX.utils.json_to_sheet(sampleData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Sample_Questions');
    XLSX.writeFile(wb, 'aptiqu_curriculum_questions_template.xlsx');
  };

  const handleImportSubmit = async () => {
    if (parsedRows.length === 0) return;
    setLoading(true);
    setErrorMessage(null);
    try {
      const res = await api.bulkImportQuestions(parsedRows, defaultSubtopicId || undefined);
      if (res.data?.success) {
        setImportSummary(res.data.data);
      }
    } catch (err: any) {
      let msg = err.response?.data?.message || err.message || 'Import failed';
      if (
        err.response?.status === 413 ||
        msg.toLowerCase().includes('too large')
      ) {
        msg =
          'File payload was rejected by the server (too large). Please pull the latest backend commit (which increases limit to 50MB) and restart it with "pm2 restart aptiqu-backend". Also ensure Nginx has "client_max_body_size 50M;".';
      }
      setErrorMessage(msg);
      alert(`Import failed: ${msg}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '820px' }}>
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <FileSpreadsheet size={20} color="#1a73e8" />
            <h3 className="modal-title">Bulk Import Questions (JSON, Excel, CSV)</h3>
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
                  <strong>Import issues:</strong>
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
                  Upload a <code>.json</code> question bank or <code>.xlsx</code> / <code>.csv</code> spreadsheet.
                </p>
                <button className="btn-secondary" style={{ fontSize: '12px', padding: '6px 12px' }} onClick={handleDownloadSample}>
                  <Download size={14} />
                  <span>Download Template</span>
                </button>
              </div>

              {errorMessage && (
                <div style={{ marginTop: '12px', padding: '12px 16px', background: '#fef2f2', border: '1px solid #fecaca', borderRadius: '8px', color: '#b91c1c', fontSize: '13px' }}>
                  <strong>⚠️ Import Blocked:</strong>
                  <div style={{ marginTop: '4px', whiteSpace: 'pre-wrap' }}>{errorMessage}</div>
                </div>
              )}

              <div className="form-group" style={{ marginTop: '12px' }}>
                <label className="form-label" style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span>Target Subtopic Resolution</span>
                  <span style={{ fontSize: '11px', color: '#64748b' }}>
                    {defaultSubtopicId ? 'Forced into selected subtopic' : 'Auto-matching each question by key'}
                  </span>
                </label>
                <select className="form-control" value={defaultSubtopicId} onChange={(e) => setDefaultSubtopicId(e.target.value)}>
                  <option value="">⚡ Auto-resolve per question (via externalSubtopicKey in file)</option>
                  {subtopics.map((s) => (
                    <option key={s.id} value={s.id}>Override / Force into: {s.topicName} → {s.name}</option>
                  ))}
                </select>
                <span style={{ fontSize: '11px', color: '#64748b', marginTop: '4px', display: 'block' }}>
                  {defaultSubtopicId
                    ? 'All questions in the file will be assigned directly to this selected subtopic.'
                    : 'Each question will be linked to its subtopic using "externalSubtopicKey" (e.g. "ns-01-place-value-notation"). If any key does not match a subtopic in the database or if questions are duplicates, the import will fail completely.'}
                </span>
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
                <p style={{ fontSize: '14px', fontWeight: 600 }}>Select or Drop JSON, Excel or CSV File</p>
                <input
                  type="file"
                  accept=".json, .xlsx, .xls, .csv"
                  onChange={handleFileUpload}
                  style={{ marginTop: '12px' }}
                />
              </div>

              {parsedRows.length > 0 && (
                <div style={{ marginTop: '16px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                    <span style={{ fontSize: '13px', fontWeight: 600 }}>
                      Parsed Preview ({parsedRows.length} questions loaded):
                    </span>
                  </div>
                  <div style={{ maxHeight: '180px', overflowY: 'auto', border: '1px solid #e2e8f0', borderRadius: '6px' }}>
                    <table className="table-custom" style={{ fontSize: '11px' }}>
                      <thead>
                        <tr>
                          <th>#</th>
                          <th>Key</th>
                          <th>Subtopic Key</th>
                          <th>Prompt</th>
                          <th>PYQ</th>
                          <th>Ans</th>
                          <th>Diff</th>
                        </tr>
                      </thead>
                      <tbody>
                        {parsedRows.slice(0, 10).map((r, i) => {
                          const subKey = r.externalSubtopicKey || r.subtopicKey || r.subtopicSlug;
                          return (
                            <tr key={i}>
                              <td>{i + 1}</td>
                              <td><code style={{ fontSize: '10px' }}>{r.externalQuestionKey || r.externalKey || r.externalId || r.id || '-'}</code></td>
                              <td>
                                {subKey ? (
                                  <code style={{ fontSize: '10px', background: '#eff6ff', color: '#1d4ed8', padding: '2px 4px', borderRadius: '3px' }}>
                                    {subKey}
                                  </code>
                                ) : defaultSubtopicId ? (
                                  <span style={{ color: '#64748b' }}>Default Selected</span>
                                ) : (
                                  <span style={{ color: '#ef4444', fontWeight: 600 }}>⚠️ Missing Key</span>
                                )}
                              </td>
                              <td>{(r.prompt || r.question || '').slice(0, 45)}...</td>
                              <td>{r.pyq ? <span style={{ color: '#b45309', fontWeight: 600 }}>🏛️ {r.pyq}</span> : '-'}</td>
                              <td>{r.correctAnswer || r.answer || (typeof r.options === 'object' ? r.options.find((o: any) => o.isCorrect)?.text : '-')}</td>
                              <td>{r.difficulty || 'EASY'}</td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {loading && (
                <div style={{
                  marginTop: '16px',
                  padding: '16px',
                  background: '#f0f9ff',
                  border: '1px solid #bae6fd',
                  borderRadius: '8px',
                  textAlign: 'center',
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', fontWeight: 600, color: '#0369a1', marginBottom: '4px' }}>
                    <div className="spinner-border spinner-border-sm" role="status" style={{ width: '14px', height: '14px', border: '2px solid #0284c7', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
                    <span>Processing {parsedRows.length} Questions...</span>
                  </div>
                  <div style={{ fontSize: '12px', color: '#0c4a6e' }}>
                    Validating curriculum subtopics, checking duplicate fingerprints & keys, and writing chunked records to database.
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
                {loading ? 'Validating & Importing Questions...' : `Import ${parsedRows.length} Questions`}
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
  const [externalKey, setExternalKey] = useState(editItem?.externalKey || '');
  const [prompt, setPrompt] = useState(editItem?.prompt || '');
  const [pyq, setPyq] = useState(editItem?.pyq || '');
  const [status, setStatus] = useState(editItem?.status || 'PUBLISHED');
  const [sourceType, setSourceType] = useState(editItem?.sourceType || 'MANUAL');
  const [generationMethod, setGenerationMethod] = useState(editItem?.generationMethod || 'HUMAN_MANUAL');

  // Book Provenance
  const [sourceBook, setSourceBook] = useState(editItem?.sourceBook || '');
  const [sourceEdition, setSourceEdition] = useState(editItem?.sourceEdition || '');
  const [sourceChapter, setSourceChapter] = useState(editItem?.sourceChapter || '');
  const [sourcePageRange, setSourcePageRange] = useState(editItem?.sourcePageRange || '');
  
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

  // Dual Solutions
  const [explanation, setExplanation] = useState(editItem?.explanation || '');
  const [method, setMethod] = useState(editItem?.method || 'Standard Method');
  const [alternativeExplanation, setAlternativeExplanation] = useState(editItem?.alternativeExplanation || '');
  const [preferredSolution, setPreferredSolution] = useState(editItem?.preferredSolution || '');
  const [preferredReason, setPreferredReason] = useState(editItem?.preferredReason || '');

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

    const payload: any = {
      subtopicId,
      prompt,
      options,
      correctAnswer,
      difficulty,
      calculationMode,
      estimatedTimeSeconds: Number(estimatedTime) || 60,
      explanation,
      method: method.trim() || 'Standard Method',
      hints,
      externalKey: externalKey.trim() || undefined,
      pyq: pyq.trim() || null,
      status,
      sourceType,
      generationMethod,
      sourceBook: sourceBook.trim() || null,
      sourceEdition: sourceEdition.trim() || null,
      sourceChapter: sourceChapter.trim() || null,
      sourcePageRange: sourcePageRange.trim() || null,
      alternativeExplanation: alternativeExplanation.trim() || null,
      preferredSolution: preferredSolution ? preferredSolution : null,
      preferredReason: preferredReason.trim() || null,
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
      <div className="modal-content" style={{ maxWidth: '800px', maxHeight: '90vh', overflowY: 'auto' }}>
        <div className="modal-header">
          <h3 className="modal-title">{editItem ? 'Edit Question' : 'Add New Question'}</h3>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer' }}><X size={18} /></button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            {/* Top row: Subtopic and External Key */}
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '12px' }}>
              <div className="form-group">
                <label className="form-label">Subtopic Assignment</label>
                <select className="form-control" value={subtopicId} onChange={(e) => setSubtopicId(e.target.value)} required>
                  {subtopics.map((s) => (
                    <option key={s.id} value={s.id}>{s.topicName} → {s.name}</option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">External Key (Unique ID)</label>
                <input
                  type="text"
                  className="form-control"
                  value={externalKey}
                  onChange={(e) => setExternalKey(e.target.value)}
                  placeholder="e.g. rs-agg-ch21-q014"
                />
              </div>
            </div>

            {/* Prompt */}
            <div className="form-group">
              <label className="form-label">Question Prompt</label>
              <textarea className="form-control" value={prompt} onChange={(e) => setPrompt(e.target.value)} required rows={3} placeholder="e.g. A store offers a 20% discount..." />
            </div>

            {/* PYQ Tag, Review Status, & Generation Row */}
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr 1fr', gap: '12px' }}>
              <div className="form-group">
                <label className="form-label">PYQ Exam & Year</label>
                <input
                  type="text"
                  className="form-control"
                  value={pyq}
                  onChange={(e) => setPyq(e.target.value)}
                  placeholder='e.g. TCS NQT (2023), CAT (2012)'
                />
              </div>

              <div className="form-group">
                <label className="form-label">Status</label>
                <select className="form-control" value={status} onChange={(e) => setStatus(e.target.value)}>
                  <option value="PUBLISHED">PUBLISHED</option>
                  <option value="REVIEW">REVIEW</option>
                  <option value="DRAFT">DRAFT</option>
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">Source</label>
                <select className="form-control" value={sourceType} onChange={(e) => setSourceType(e.target.value)}>
                  <option value="MANUAL">MANUAL</option>
                  <option value="AI_GENERATED">AI_GEN</option>
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">Method</label>
                <select className="form-control" value={generationMethod} onChange={(e) => setGenerationMethod(e.target.value)}>
                  <option value="HUMAN_MANUAL">HUMAN</option>
                  <option value="AI_EXTRACTED">AI_EXTRACTED</option>
                  <option value="AI_SYNTHETIC">AI_SYNTHETIC</option>
                </select>
              </div>
            </div>

            {/* Options */}
            <div className="form-group">
              <label className="form-label">Options (Select Correct Radio)</label>
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

            {/* Difficulty & Calculation Mode */}
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

            {/* Provenance Details */}
            <div style={{ background: '#f8fafc', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', marginBottom: '16px' }}>
              <span style={{ fontSize: '12px', fontWeight: 700, color: '#475569', textTransform: 'uppercase' }}>
                Curriculum Book Provenance
              </span>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '8px' }}>
                <div>
                  <label className="form-label" style={{ fontSize: '11px' }}>Source Book Title</label>
                  <input type="text" className="form-control" value={sourceBook} onChange={(e) => setSourceBook(e.target.value)} placeholder="e.g. RS Aggarwal Quantitative Aptitude" />
                </div>
                <div>
                  <label className="form-label" style={{ fontSize: '11px' }}>Edition</label>
                  <input type="text" className="form-control" value={sourceEdition} onChange={(e) => setSourceEdition(e.target.value)} placeholder="e.g. 2024 Revised" />
                </div>
                <div>
                  <label className="form-label" style={{ fontSize: '11px' }}>Chapter / Unit</label>
                  <input type="text" className="form-control" value={sourceChapter} onChange={(e) => setSourceChapter(e.target.value)} placeholder="e.g. Chapter 21: Time and Distance" />
                </div>
                <div>
                  <label className="form-label" style={{ fontSize: '11px' }}>Page Range</label>
                  <input type="text" className="form-control" value={sourcePageRange} onChange={(e) => setSourcePageRange(e.target.value)} placeholder="e.g. pp. 310-312" />
                </div>
              </div>
            </div>

            {/* Dual Solutions Section */}
            <div style={{ background: '#eff6ff', padding: '14px', borderRadius: '8px', border: '1px solid #bfdbfe', marginBottom: '16px' }}>
              <span style={{ fontSize: '13px', fontWeight: 700, color: '#1d4ed8' }}>
                Dual Solutions (Book Method + Alternative Speed Shortcut)
              </span>

              {/* Solution 1: Book */}
              <div className="form-group" style={{ marginTop: '10px' }}>
                <label className="form-label">📖 Solution 1 (Book / Standard Method)</label>
                <textarea className="form-control" rows={3} value={explanation} onChange={(e) => setExplanation(e.target.value)} placeholder="Standard textbook step-by-step derivation..." required />
              </div>
              <div className="form-group">
                <label className="form-label" style={{ fontSize: '11px' }}>Solving Formula / Method Descriptor</label>
                <input type="text" className="form-control" value={method} onChange={(e) => setMethod(e.target.value)} placeholder="e.g. Standard Distance Formula, Ratio Shortcut..." />
              </div>

              {/* Solution 2: Alternative */}
              <div className="form-group" style={{ marginTop: '12px' }}>
                <label className="form-label">⚡ Solution 2 (Alternative / Speed Shortcut Method)</label>
                <textarea className="form-control" rows={3} value={alternativeExplanation} onChange={(e) => setAlternativeExplanation(e.target.value)} placeholder="High-speed trick, mental-math shortcut, or elimination technique..." />
              </div>

              {/* Preference selector */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '12px' }}>
                <div className="form-group">
                  <label className="form-label" style={{ fontSize: '11px' }}>Preferred Solution</label>
                  <select className="form-control" value={preferredSolution} onChange={(e) => setPreferredSolution(e.target.value)}>
                    <option value="">None / Neutral</option>
                    <option value="BOOK">Solution 1 (Book Method)</option>
                    <option value="ALTERNATIVE">Solution 2 (Alternative Speed Shortcut)</option>
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label" style={{ fontSize: '11px' }}>Reason for Preference</label>
                  <input type="text" className="form-control" value={preferredReason} onChange={(e) => setPreferredReason(e.target.value)} placeholder="e.g. Solves in 15 seconds without algebra" />
                </div>
              </div>
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
