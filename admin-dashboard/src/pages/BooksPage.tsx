import React, { useState, useEffect, useRef } from 'react';
import { api } from '../services/api';
import {
  BookOpen,
  Upload,
  RefreshCw,
  Trash2,
  CheckCircle2,
  AlertCircle,
  Eye,
  Send,
  RotateCcw,
  ChevronRight,
  X,
  FileCheck
} from 'lucide-react';

interface BookItem {
  id: string;
  title: string;
  author?: string;
  edition?: string;
  isbn?: string;
  fileSize: number;
  totalPages: number;
  status: string;
  errorMessage?: string;
  createdAt: string;
  updatedAt: string;
  subject: {
    id: string;
    name: string;
    slug: string;
    isActive: boolean;
    _count: {
      topics: number;
      questions: number;
    };
  };
}

interface IngestionProgress {
  bookId: string;
  subjectId: string;
  title: string;
  status: string;
  overallProgressPercent: number;
  stages: {
    pdfProcessing: { status: string; progress: number; totalPages: number };
    topicDetection: { status: string; progress: number; totalTopics: number };
    subtopicDiscovery: { status: string; progress: number; totalSubtopics: number };
    questionExtraction: { status: string; progress: number; totalQuestions: number };
    scriptGeneration: { status: string; progress: number; totalScripts: number };
    validation: { status: string; progress: number; passedValidation: boolean };
  };
}

export const BooksPage: React.FC = () => {
  const [books, setBooks] = useState<BookItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploadModalOpen, setUploadModalOpen] = useState(false);

  // Upload Form State
  const [uploadTitle, setUploadTitle] = useState('');
  const [uploadAuthor, setUploadAuthor] = useState('');
  const [uploadEdition, setUploadEdition] = useState('');
  const [uploadIsbn, setUploadIsbn] = useState('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Inspection Drawer State
  const [selectedBook, setSelectedBook] = useState<BookItem | null>(null);
  const [inspectionTab, setInspectionTab] = useState<'pipeline' | 'topics' | 'subtopics' | 'preview'>('pipeline');
  const [progressData, setProgressData] = useState<IngestionProgress | null>(null);
  const [topicsData, setTopicsData] = useState<any[]>([]);
  const [subtopicsData, setSubtopicsData] = useState<any[]>([]);
  const [selectedTopicId, setSelectedTopicId] = useState<string | null>(null);
  const [previewSubtopicId, setPreviewSubtopicId] = useState<string | null>(null);
  const [previewContent, setPreviewContent] = useState<{ script: any; questions: any[] } | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);

  // Polling ref
  const pollingRef = useRef<any>(null);

  useEffect(() => {
    fetchBooks();
    return () => {
      if (pollingRef.current) clearInterval(pollingRef.current);
    };
  }, []);

  // Poll active progress if inspection drawer is open and book is processing
  useEffect(() => {
    if (selectedBook && !['PUBLISHED', 'FAILED'].includes(selectedBook.status)) {
      fetchBookProgress(selectedBook.id);
      pollingRef.current = setInterval(() => {
        fetchBookProgress(selectedBook.id);
      }, 3500);
    } else {
      if (pollingRef.current) clearInterval(pollingRef.current);
    }
    return () => {
      if (pollingRef.current) clearInterval(pollingRef.current);
    };
  }, [selectedBook?.id, selectedBook?.status]);

  const fetchBooks = async () => {
    setLoading(true);
    try {
      const res = await api.getBooks();
      if (res.data?.success) {
        setBooks(res.data.data || []);
      }
    } catch (err: any) {
      console.error('Failed to load books:', err);
    } finally {
      setLoading(false);
    }
  };

  const fetchBookProgress = async (bookId: string) => {
    try {
      const res = await api.getBookStatus(bookId);
      if (res.data?.success) {
        setProgressData(res.data.data);
        // Also update local book status in list
        setBooks((prev) =>
          prev.map((b) => (b.id === bookId ? { ...b, status: res.data.data.status } : b))
        );
      }
    } catch (err) {
      console.error('Failed to poll book status:', err);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (file.type !== 'application/pdf' && !file.name.toLowerCase().endsWith('.pdf')) {
        setUploadError('Please select a valid PDF file.');
        setSelectedFile(null);
        return;
      }
      setSelectedFile(file);
      setUploadError(null);
      // Auto-populate title if empty
      if (!uploadTitle) {
        const cleanName = file.name
          .replace(/\.pdf$/i, '')
          .replace(/[-_]/g, ' ')
          .replace(/\b\w/g, (c) => c.toUpperCase());
        setUploadTitle(cleanName);
      }
    }
  };

  const handleUploadSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedFile) {
      setUploadError('Please select a PDF file.');
      return;
    }
    if (!uploadTitle.trim()) {
      setUploadError('Please enter a book title.');
      return;
    }

    setUploading(true);
    setUploadProgress(0);
    setUploadError(null);

    const formData = new FormData();
    formData.append('file', selectedFile);
    formData.append('title', uploadTitle.trim());
    if (uploadAuthor.trim()) formData.append('author', uploadAuthor.trim());
    if (uploadEdition.trim()) formData.append('edition', uploadEdition.trim());
    if (uploadIsbn.trim()) formData.append('isbn', uploadIsbn.trim());

    try {
      const res = await api.uploadBook(formData, (evt) => {
        if (evt.total) {
          const percent = Math.round((evt.loaded * 100) / evt.total);
          setUploadProgress(percent);
        }
      });

      if (res.data?.success) {
        setUploadModalOpen(false);
        setUploadTitle('');
        setUploadAuthor('');
        setUploadEdition('');
        setUploadIsbn('');
        setSelectedFile(null);
        fetchBooks();
      } else {
        setUploadError(res.data?.message || 'Failed to upload book.');
      }
    } catch (err: any) {
      setUploadError(err.response?.data?.message || err.message || 'Upload failed.');
    } finally {
      setUploading(false);
    }
  };

  const openInspection = async (book: BookItem) => {
    setSelectedBook(book);
    setInspectionTab('pipeline');
    fetchBookProgress(book.id);

    try {
      const topicsRes = await api.getBookTopics(book.id);
      if (topicsRes.data?.success) {
        setTopicsData(topicsRes.data.data.topics || []);
      }
    } catch (err) {
      console.error('Failed to load topics:', err);
    }
  };

  const loadSubtopics = async (bookId: string, topicId: string) => {
    setSelectedTopicId(topicId);
    try {
      const res = await api.getBookSubtopics(bookId, topicId);
      if (res.data?.success) {
        setSubtopicsData(res.data.data || []);
      }
    } catch (err) {
      console.error('Failed to load subtopics:', err);
    }
  };

  const loadContentPreview = async (bookId: string, subtopicId: string) => {
    setPreviewSubtopicId(subtopicId);
    setPreviewLoading(true);
    try {
      const res = await api.getBookContentPreview(bookId, subtopicId);
      if (res.data?.success) {
        setPreviewContent(res.data.data);
      }
    } catch (err) {
      console.error('Failed to load content preview:', err);
    } finally {
      setPreviewLoading(false);
    }
  };

  const handlePublish = async (bookId: string) => {
    if (!window.confirm('Are you sure you want to publish this Subject and activate all generated curriculum content for learners?')) {
      return;
    }
    try {
      const res = await api.publishBook(bookId);
      if (res.data?.success) {
        alert('Subject successfully published and activated for learners!');
        fetchBooks();
        if (selectedBook?.id === bookId) {
          fetchBookProgress(bookId);
        }
      }
    } catch (err: any) {
      alert(`Publish failed: ${err.response?.data?.message || err.message}`);
    }
  };

  const handleRetry = async (bookId: string, stage?: string) => {
    try {
      await api.retryBookStage(bookId, stage);
      alert('Ingestion resumed/retried in background.');
      fetchBooks();
      if (selectedBook?.id === bookId) {
        fetchBookProgress(bookId);
      }
    } catch (err: any) {
      alert(`Retry failed: ${err.response?.data?.message || err.message}`);
    }
  };

  const handleDelete = async (bookId: string) => {
    if (!window.confirm('Are you sure you want to delete this book source and its ingested curriculum? This cannot be undone.')) {
      return;
    }
    try {
      await api.deleteBook(bookId, true);
      setSelectedBook(null);
      fetchBooks();
    } catch (err: any) {
      alert(`Delete failed: ${err.response?.data?.message || err.message}`);
    }
  };

  // Status Badge Helper
  const renderStatusBadge = (status: string) => {
    switch (status) {
      case 'PUBLISHED':
        return (
          <span className="badge badge-success" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <CheckCircle2 size={12} /> Published
          </span>
        );
      case 'READY_FOR_REVIEW':
        return (
          <span className="badge badge-info" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <FileCheck size={12} /> Ready for Review
          </span>
        );
      case 'FAILED':
        return (
          <span className="badge badge-danger" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <AlertCircle size={12} /> Failed
          </span>
        );
      default:
        return (
          <span className="badge badge-warning" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <RefreshCw size={12} className="spin-animation" /> {status.replace(/_/g, ' ')}
          </span>
        );
    }
  };

  // Overall Stats
  const totalBooks = books.length;
  const inProgressBooks = books.filter((b) => !['PUBLISHED', 'FAILED', 'READY_FOR_REVIEW'].includes(b.status)).length;
  const reviewBooks = books.filter((b) => b.status === 'READY_FOR_REVIEW').length;
  const publishedBooks = books.filter((b) => b.status === 'PUBLISHED').length;

  return (
    <div className="books-page" style={{ paddingBottom: '60px' }}>
      {/* Header Banner */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <BookOpen size={26} color="#1a73e8" />
            Book Content Ingestion Engine
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '14px', marginTop: '4px' }}>
            Transform educational textbooks directly into AptiQu Subjects, Chapters, Subtopics, Interactive Scripts, and Question Banks.
          </p>
        </div>
        <button
          className="btn-primary"
          onClick={() => setUploadModalOpen(true)}
          style={{ padding: '12px 20px', fontSize: '14px' }}
        >
          <Upload size={16} />
          <span>Upload Book PDF</span>
        </button>
      </div>

      {/* Metric Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '24px' }}>
        <div className="card" style={{ padding: '18px 20px' }}>
          <div style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: 600 }}>Total Books Ingested</div>
          <div style={{ fontSize: '26px', fontWeight: 800, marginTop: '6px', color: 'var(--text-primary)' }}>{totalBooks}</div>
        </div>
        <div className="card" style={{ padding: '18px 20px' }}>
          <div style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: 600 }}>Active Pipelines</div>
          <div style={{ fontSize: '26px', fontWeight: 800, marginTop: '6px', color: '#fb8c00' }}>{inProgressBooks}</div>
        </div>
        <div className="card" style={{ padding: '18px 20px' }}>
          <div style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: 600 }}>Ready for Review</div>
          <div style={{ fontSize: '26px', fontWeight: 800, marginTop: '6px', color: '#1a73e8' }}>{reviewBooks}</div>
        </div>
        <div className="card" style={{ padding: '18px 20px' }}>
          <div style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: 600 }}>Published Subjects</div>
          <div style={{ fontSize: '26px', fontWeight: 800, marginTop: '6px', color: '#43a047' }}>{publishedBooks}</div>
        </div>
      </div>

      {/* Books Table */}
      <div className="card">
        <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 700, margin: 0 }}>Uploaded Textbooks & Subject Pipelines</h3>
          <button className="btn-secondary" onClick={fetchBooks} style={{ padding: '6px 12px', fontSize: '12px' }}>
            <RefreshCw size={13} /> Refresh
          </button>
        </div>

        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-secondary)' }}>
            Loading textbook repositories...
          </div>
        ) : books.length === 0 ? (
          <div style={{ padding: '60px 20px', textAlign: 'center', color: 'var(--text-secondary)' }}>
            <BookOpen size={48} style={{ opacity: 0.3, marginBottom: '12px' }} />
            <h4 style={{ fontSize: '16px', fontWeight: 600, color: 'var(--text-primary)' }}>No books uploaded yet</h4>
            <p style={{ fontSize: '13px', maxWidth: '420px', margin: '6px auto 16px auto' }}>
              Upload an educational book PDF (e.g., R.S. Aggarwal Quantitative Aptitude) to automatically convert it into a complete AptiQu Subject with chapters and questions.
            </p>
            <button className="btn-primary" onClick={() => setUploadModalOpen(true)}>
              <Upload size={14} /> Upload First Book
            </button>
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table className="data-table" style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8fafc', borderBottom: '1px solid var(--border-color)', textAlign: 'left' }}>
                  <th style={{ padding: '14px 20px', fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 600 }}>BOOK / SUBJECT TITLE</th>
                  <th style={{ padding: '14px 20px', fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 600 }}>AUTHOR / EDITION</th>
                  <th style={{ padding: '14px 20px', fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 600 }}>PAGES</th>
                  <th style={{ padding: '14px 20px', fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 600 }}>CURRICULUM</th>
                  <th style={{ padding: '14px 20px', fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 600 }}>STATUS</th>
                  <th style={{ padding: '14px 20px', fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 600, textAlign: 'right' }}>ACTIONS</th>
                </tr>
              </thead>
              <tbody>
                {books.map((b) => (
                  <tr key={b.id} style={{ borderBottom: '1px solid var(--border-color)', transition: 'background 0.2s' }}>
                    <td style={{ padding: '16px 20px' }}>
                      <div style={{ fontWeight: 600, color: 'var(--text-primary)', fontSize: '14px' }}>{b.title}</div>
                      <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                        Subject Slug: <code>{b.subject.slug}</code>
                      </div>
                    </td>
                    <td style={{ padding: '16px 20px', fontSize: '13px', color: 'var(--text-primary)' }}>
                      <div>{b.author || '—'}</div>
                      {b.edition && <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{b.edition}</div>}
                    </td>
                    <td style={{ padding: '16px 20px', fontSize: '13px' }}>
                      {b.totalPages > 0 ? (
                        <span style={{ fontWeight: 600 }}>{b.totalPages} pages</span>
                      ) : (
                        <span style={{ color: 'var(--text-secondary)' }}>Pending parse</span>
                      )}
                    </td>
                    <td style={{ padding: '16px 20px', fontSize: '12px' }}>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <span className="badge" style={{ background: '#e0f2fe', color: '#0369a1' }}>
                          {b.subject._count.topics} Chapters
                        </span>
                        <span className="badge" style={{ background: '#f3e8ff', color: '#7e22ce' }}>
                          {b.subject._count.questions} Questions
                        </span>
                      </div>
                    </td>
                    <td style={{ padding: '16px 20px' }}>
                      {renderStatusBadge(b.status)}
                      {b.errorMessage && (
                        <div style={{ fontSize: '11px', color: '#ef4444', marginTop: '4px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={b.errorMessage}>
                          {b.errorMessage}
                        </div>
                      )}
                    </td>
                    <td style={{ padding: '16px 20px', textAlign: 'right' }}>
                      <div style={{ display: 'inline-flex', gap: '8px', alignItems: 'center' }}>
                        <button
                          className="btn-secondary"
                          onClick={() => openInspection(b)}
                          title="Inspect Pipeline & Review Content"
                          style={{ padding: '6px 12px', fontSize: '12px' }}
                        >
                          <Eye size={13} /> Inspect
                        </button>

                        {b.status === 'READY_FOR_REVIEW' && (
                          <button
                            className="btn-primary"
                            onClick={() => handlePublish(b.id)}
                            style={{ padding: '6px 12px', fontSize: '12px', background: 'var(--gradient-green)' }}
                            title="Publish Subject to App"
                          >
                            <Send size={13} /> Publish
                          </button>
                        )}

                        {b.status === 'FAILED' && (
                          <button
                            className="btn-secondary"
                            onClick={() => handleRetry(b.id)}
                            style={{ padding: '6px 12px', fontSize: '12px' }}
                            title="Retry Pipeline"
                          >
                            <RotateCcw size={13} /> Retry
                          </button>
                        )}

                        <button
                          onClick={() => handleDelete(b.id)}
                          style={{
                            background: 'transparent',
                            border: 'none',
                            color: '#94a3b8',
                            cursor: 'pointer',
                            padding: '6px',
                            borderRadius: '4px',
                          }}
                          title="Delete Book"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Upload Modal */}
      {uploadModalOpen && (
        <div className="modal-overlay" style={{
          position: 'fixed',
          top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
        }}>
          <div className="modal-container card" style={{ width: '540px', maxWidth: '95vw', padding: '28px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: 700, margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Upload size={20} color="#1a73e8" />
                Upload Educational Book PDF
              </h3>
              <button
                onClick={() => !uploading && setUploadModalOpen(false)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)' }}
              >
                <X size={20} />
              </button>
            </div>

            <div style={{
              background: '#eff6ff',
              border: '1px solid #bfdbfe',
              borderRadius: '8px',
              padding: '12px 16px',
              fontSize: '12px',
              color: '#1e40af',
              marginBottom: '20px',
              lineHeight: 1.5,
            }}>
              <strong>Architecture Note:</strong> The uploaded book will become an official AptiQu <strong>Subject</strong>. The pipeline will discover all chapters as <strong>Topics</strong>, synthesize concept units as <strong>Subtopics</strong>, generate interactive lesson scripts, and extract MCQ questions.
            </div>

            <form onSubmit={handleUploadSubmit}>
              {/* File Dropzone */}
              <div
                onClick={() => fileInputRef.current?.click()}
                style={{
                  border: '2px dashed #cbd5e1',
                  borderRadius: '12px',
                  padding: '24px',
                  textAlign: 'center',
                  cursor: 'pointer',
                  background: selectedFile ? '#f0fdf4' : '#f8fafc',
                  marginBottom: '18px',
                  transition: 'border 0.2s',
                }}
              >
                <input
                  type="file"
                  ref={fileInputRef}
                  accept=".pdf,application/pdf"
                  onChange={handleFileChange}
                  style={{ display: 'none' }}
                />
                <BookOpen size={36} color={selectedFile ? '#22c55e' : '#94a3b8'} style={{ margin: '0 auto 8px auto' }} />
                {selectedFile ? (
                  <div>
                    <div style={{ fontWeight: 600, color: '#15803d', fontSize: '14px' }}>{selectedFile.name}</div>
                    <div style={{ fontSize: '12px', color: '#166534', marginTop: '2px' }}>
                      {(selectedFile.size / (1024 * 1024)).toFixed(2)} MB — Ready to upload
                    </div>
                  </div>
                ) : (
                  <div>
                    <div style={{ fontWeight: 600, color: 'var(--text-primary)', fontSize: '14px' }}>
                      Click to choose PDF or drag & drop here
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                      Supports text & scanned books up to 150 MB
                    </div>
                  </div>
                )}
              </div>

              {/* Metadata Inputs */}
              <div style={{ marginBottom: '14px' }}>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, marginBottom: '6px' }}>
                  Book Title / Subject Name <span style={{ color: '#ef4444' }}>*</span>
                </label>
                <input
                  type="text"
                  value={uploadTitle}
                  onChange={(e) => setUploadTitle(e.target.value)}
                  placeholder="e.g. R.S. Aggarwal Quantitative Aptitude"
                  required
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    borderRadius: '8px',
                    border: '1px solid #cbd5e1',
                    fontSize: '14px',
                  }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '14px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, marginBottom: '6px' }}>Author</label>
                  <input
                    type="text"
                    value={uploadAuthor}
                    onChange={(e) => setUploadAuthor(e.target.value)}
                    placeholder="e.g. Dr. R.S. Aggarwal"
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '8px',
                      border: '1px solid #cbd5e1',
                      fontSize: '14px',
                    }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, marginBottom: '6px' }}>Edition / Year</label>
                  <input
                    type="text"
                    value={uploadEdition}
                    onChange={(e) => setUploadEdition(e.target.value)}
                    placeholder="e.g. 2024 Revised Edition"
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '8px',
                      border: '1px solid #cbd5e1',
                      fontSize: '14px',
                    }}
                  />
                </div>
              </div>

              <div style={{ marginBottom: '20px' }}>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, marginBottom: '6px' }}>ISBN (Optional)</label>
                <input
                  type="text"
                  value={uploadIsbn}
                  onChange={(e) => setUploadIsbn(e.target.value)}
                  placeholder="e.g. 978-9352534029"
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    borderRadius: '8px',
                    border: '1px solid #cbd5e1',
                    fontSize: '14px',
                  }}
                />
              </div>

              {uploadError && (
                <div style={{
                  padding: '10px 14px',
                  borderRadius: '6px',
                  background: '#fef2f2',
                  border: '1px solid #fecaca',
                  color: '#b91c1c',
                  fontSize: '13px',
                  marginBottom: '16px',
                }}>
                  {uploadError}
                </div>
              )}

              {uploading && (
                <div style={{ marginBottom: '16px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', marginBottom: '6px', fontWeight: 600 }}>
                    <span>Streaming to storage...</span>
                    <span>{uploadProgress}%</span>
                  </div>
                  <div style={{ height: '8px', background: '#e2e8f0', borderRadius: '4px', overflow: 'hidden' }}>
                    <div style={{ width: `${uploadProgress}%`, height: '100%', background: 'var(--gradient-blue)', transition: 'width 0.3s' }} />
                  </div>
                </div>
              )}

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
                <button
                  type="button"
                  className="btn-secondary"
                  disabled={uploading}
                  onClick={() => setUploadModalOpen(false)}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn-primary"
                  disabled={uploading || !selectedFile}
                >
                  {uploading ? 'Processing Upload...' : 'Upload & Start Pipeline'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Inspection Drawer / Full Review Modal */}
      {selectedBook && (
        <div style={{
          position: 'fixed',
          top: 0, right: 0, bottom: 0,
          width: '840px',
          maxWidth: '92vw',
          background: '#ffffff',
          boxShadow: '-10px 0 30px rgba(0, 0, 0, 0.15)',
          zIndex: 999,
          display: 'flex',
          flexDirection: 'column',
        }}>
          {/* Drawer Header */}
          <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border-color)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <h3 style={{ fontSize: '18px', fontWeight: 700, margin: 0 }}>{selectedBook.title}</h3>
                {renderStatusBadge(progressData?.status || selectedBook.status)}
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                Subject ID: <code>{selectedBook.subject.id}</code> • {selectedBook.totalPages} Total Pages
              </div>
            </div>
            <button
              onClick={() => setSelectedBook(null)}
              style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)' }}
            >
              <X size={22} />
            </button>
          </div>

          {/* Drawer Tabs */}
          <div style={{ display: 'flex', borderBottom: '1px solid var(--border-color)', padding: '0 24px', background: '#f8fafc' }}>
            <button
              onClick={() => setInspectionTab('pipeline')}
              style={{
                padding: '12px 16px',
                border: 'none',
                background: 'transparent',
                fontWeight: 600,
                fontSize: '13px',
                cursor: 'pointer',
                color: inspectionTab === 'pipeline' ? '#1a73e8' : 'var(--text-secondary)',
                borderBottom: inspectionTab === 'pipeline' ? '2px solid #1a73e8' : '2px solid transparent',
              }}
            >
              1. Pipeline Progress
            </button>
            <button
              onClick={() => setInspectionTab('topics')}
              style={{
                padding: '12px 16px',
                border: 'none',
                background: 'transparent',
                fontWeight: 600,
                fontSize: '13px',
                cursor: 'pointer',
                color: inspectionTab === 'topics' ? '#1a73e8' : 'var(--text-secondary)',
                borderBottom: inspectionTab === 'topics' ? '2px solid #1a73e8' : '2px solid transparent',
              }}
            >
              2. Chapters / Topics ({topicsData.length})
            </button>
            <button
              onClick={() => setInspectionTab('subtopics')}
              style={{
                padding: '12px 16px',
                border: 'none',
                background: 'transparent',
                fontWeight: 600,
                fontSize: '13px',
                cursor: 'pointer',
                color: inspectionTab === 'subtopics' ? '#1a73e8' : 'var(--text-secondary)',
                borderBottom: inspectionTab === 'subtopics' ? '2px solid #1a73e8' : '2px solid transparent',
              }}
            >
              3. Subtopics & Content
            </button>
            <button
              onClick={() => setInspectionTab('preview')}
              style={{
                padding: '12px 16px',
                border: 'none',
                background: 'transparent',
                fontWeight: 600,
                fontSize: '13px',
                cursor: 'pointer',
                color: inspectionTab === 'preview' ? '#1a73e8' : 'var(--text-secondary)',
                borderBottom: inspectionTab === 'preview' ? '2px solid #1a73e8' : '2px solid transparent',
              }}
            >
              4. Script & Questions Preview
            </button>
          </div>

          {/* Drawer Body Content */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
            {/* TAB 1: PIPELINE PROGRESS */}
            {inspectionTab === 'pipeline' && (
              <div>
                <div style={{ marginBottom: '24px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', fontWeight: 700, fontSize: '14px' }}>
                    <span>Overall Pipeline Completion</span>
                    <span>{progressData?.overallProgressPercent ?? 10}%</span>
                  </div>
                  <div style={{ height: '10px', background: '#e2e8f0', borderRadius: '5px', overflow: 'hidden' }}>
                    <div
                      style={{
                        width: `${progressData?.overallProgressPercent ?? 10}%`,
                        height: '100%',
                        background: 'var(--gradient-blue)',
                        transition: 'width 0.4s ease',
                      }}
                    />
                  </div>
                </div>

                <h4 style={{ fontSize: '15px', fontWeight: 700, marginBottom: '16px' }}>Pipeline Stages Breakdown</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {/* Stage 1: PDF Extract */}
                  <div style={{ padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#fafafa' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ fontWeight: 600, fontSize: '14px' }}>1. PDF Streaming & Page Parsing</div>
                      <span className="badge" style={{ background: progressData?.stages.pdfProcessing.status === 'COMPLETED' ? '#e8f5e9' : '#fff3e0', color: progressData?.stages.pdfProcessing.status === 'COMPLETED' ? '#2e7d32' : '#e65100' }}>
                        {progressData?.stages.pdfProcessing.status || 'PENDING'}
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                      Extracted text, diagrams, formulas, and token counts page by page ({progressData?.stages.pdfProcessing.totalPages || selectedBook.totalPages} pages).
                    </div>
                  </div>

                  {/* Stage 2: Topic Detection */}
                  <div style={{ padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#fafafa' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ fontWeight: 600, fontSize: '14px' }}>2. Table of Contents & Chapter Detection</div>
                      <span className="badge" style={{ background: progressData?.stages.topicDetection.status === 'COMPLETED' ? '#e8f5e9' : '#fff3e0', color: progressData?.stages.topicDetection.status === 'COMPLETED' ? '#2e7d32' : '#e65100' }}>
                        {progressData?.stages.topicDetection.status || 'PENDING'}
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                      Discovered {progressData?.stages.topicDetection.totalTopics || selectedBook.subject._count.topics} chapter boundaries with start/end page grounding.
                    </div>
                  </div>

                  {/* Stage 3: Subtopic Discovery */}
                  <div style={{ padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#fafafa' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ fontWeight: 600, fontSize: '14px' }}>3. Pedagogical Subtopic Synthesis</div>
                      <span className="badge" style={{ background: progressData?.stages.subtopicDiscovery.status === 'COMPLETED' ? '#e8f5e9' : '#fff3e0', color: progressData?.stages.subtopicDiscovery.status === 'COMPLETED' ? '#2e7d32' : '#e65100' }}>
                        {progressData?.stages.subtopicDiscovery.status || 'PENDING'}
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                      Synthesized content-driven concept subtopics without arbitrary count restrictions.
                    </div>
                  </div>

                  {/* Stage 4: Question Extraction */}
                  <div style={{ padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#fafafa' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ fontWeight: 600, fontSize: '14px' }}>4. Question Extraction & Deduplication</div>
                      <span className="badge" style={{ background: progressData?.stages.questionExtraction.status === 'COMPLETED' ? '#e8f5e9' : '#fff3e0', color: progressData?.stages.questionExtraction.status === 'COMPLETED' ? '#2e7d32' : '#e65100' }}>
                        {progressData?.stages.questionExtraction.status || 'PENDING'}
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                      Extracted {progressData?.stages.questionExtraction.totalQuestions || selectedBook.subject._count.questions} questions with options, step solutions, and PYQ tags.
                    </div>
                  </div>

                  {/* Stage 5: Script Generation */}
                  <div style={{ padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#fafafa' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ fontWeight: 600, fontSize: '14px' }}>5. Interactive Lesson Script Generation</div>
                      <span className="badge" style={{ background: progressData?.stages.scriptGeneration.status === 'COMPLETED' ? '#e8f5e9' : '#fff3e0', color: progressData?.stages.scriptGeneration.status === 'COMPLETED' ? '#2e7d32' : '#e65100' }}>
                        {progressData?.stages.scriptGeneration.status || 'PENDING'}
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                      Created DSL-compliant interactive lesson scripts with embedded practice checkpoints.
                    </div>
                  </div>

                  {/* Stage 6: Validation */}
                  <div style={{ padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#fafafa' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ fontWeight: 600, fontSize: '14px' }}>6. Multi-Layer Content Validation</div>
                      <span className="badge" style={{ background: progressData?.stages.validation.status === 'COMPLETED' ? '#e8f5e9' : '#fff3e0', color: progressData?.stages.validation.status === 'COMPLETED' ? '#2e7d32' : '#e65100' }}>
                        {progressData?.stages.validation.status || 'PENDING'}
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                      Verified MCQ answer keys, solution consistency, and script state transitions.
                    </div>
                  </div>
                </div>

                {/* Publish Bar inside drawer */}
                <div style={{ marginTop: '24px', padding: '18px', background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: 700, color: '#15803d', fontSize: '14px' }}>Ready to Publish Subject?</div>
                    <div style={{ fontSize: '12px', color: '#166534', marginTop: '2px' }}>
                      Publishing will activate <code>{selectedBook.title}</code> for all learners in AptiQu.
                    </div>
                  </div>
                  <button
                    className="btn-primary"
                    onClick={() => handlePublish(selectedBook.id)}
                    style={{ background: 'var(--gradient-green)', boxShadow: 'var(--shadow-green)' }}
                  >
                    <Send size={14} /> Publish Subject
                  </button>
                </div>
              </div>
            )}

            {/* TAB 2: CHAPTERS / TOPICS */}
            {inspectionTab === 'topics' && (
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                  <h4 style={{ fontSize: '15px', fontWeight: 700, margin: 0 }}>Detected Book Chapters (AptiQu Topics)</h4>
                  <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Grounding preserved from original pages</span>
                </div>

                {topicsData.length === 0 ? (
                  <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                    No topics detected yet. The pipeline is currently analyzing the book table of contents.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {topicsData.map((t, idx) => (
                      <div
                        key={t.id || idx}
                        style={{
                          padding: '14px 18px',
                          border: '1px solid #e2e8f0',
                          borderRadius: '8px',
                          background: '#ffffff',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}
                      >
                        <div>
                          <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-primary)' }}>
                            Chapter {idx + 1}: {t.name}
                          </div>
                          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                            Slug: <code>{t.slug}</code> • {t._count?.subtopics || 0} Subtopics • {t._count?.questions || 0} Questions
                          </div>
                        </div>
                        <button
                          className="btn-secondary"
                          onClick={() => {
                            setInspectionTab('subtopics');
                            loadSubtopics(selectedBook.id, t.id);
                          }}
                          style={{ padding: '6px 12px', fontSize: '12px' }}
                        >
                          View Subtopics <ChevronRight size={13} />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* TAB 3: SUBTOPICS */}
            {inspectionTab === 'subtopics' && (
              <div>
                <div style={{ marginBottom: '16px' }}>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, marginBottom: '6px' }}>Select Chapter:</label>
                  <select
                    value={selectedTopicId || ''}
                    onChange={(e) => loadSubtopics(selectedBook.id, e.target.value)}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '8px',
                      border: '1px solid #cbd5e1',
                      fontSize: '14px',
                    }}
                  >
                    <option value="">— Select a Topic / Chapter —</option>
                    {topicsData.map((t) => (
                      <option key={t.id} value={t.id}>
                        {t.name}
                      </option>
                    ))}
                  </select>
                </div>

                {selectedTopicId && (
                  <div>
                    <h4 style={{ fontSize: '15px', fontWeight: 700, margin: '16px 0 12px 0' }}>
                      Concept Subtopics in Chapter ({subtopicsData.length})
                    </h4>
                    {subtopicsData.length === 0 ? (
                      <div style={{ padding: '24px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                        No subtopics found for this topic.
                      </div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                        {subtopicsData.map((st) => (
                          <div
                            key={st.id}
                            style={{
                              padding: '14px 18px',
                              border: '1px solid #e2e8f0',
                              borderRadius: '8px',
                              background: '#ffffff',
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                            }}
                          >
                            <div>
                              <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-primary)' }}>
                                {st.code ? `${st.code}: ` : ''}{st.name}
                              </div>
                              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                                Slug: <code>{st.slug}</code> • {st._count?.questions || 0} Questions Linked
                              </div>
                            </div>
                            <button
                              className="btn-secondary"
                              onClick={() => {
                                setInspectionTab('preview');
                                loadContentPreview(selectedBook.id, st.id);
                              }}
                              style={{ padding: '6px 12px', fontSize: '12px' }}
                            >
                              Preview Script & MCQs <ChevronRight size={13} />
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* TAB 4: SCRIPT & QUESTIONS PREVIEW */}
            {inspectionTab === 'preview' && (
              <div>
                {previewLoading ? (
                  <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                    Loading generated script and question bank...
                  </div>
                ) : !previewContent ? (
                  <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                    Please select a subtopic from Tab 3 (Subtopics & Content) to preview its lesson script and extracted questions.
                  </div>
                ) : (
                  <div>
                    {/* Script Overview */}
                    <div style={{ marginBottom: '24px', padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#fafafa' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div style={{ fontWeight: 700, fontSize: '15px', color: 'var(--text-primary)' }}>
                          Interactive Lesson Script
                        </div>
                        <span className="badge" style={{ background: '#e0f2fe', color: '#0369a1' }}>
                          DSL v1.0
                        </span>
                      </div>
                      {previewContent.script ? (
                        <div style={{ marginTop: '10px' }}>
                          <div style={{ fontSize: '13px', fontWeight: 600 }}>{previewContent.script.title}</div>
                          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                            Subtopic ID: <code>{previewSubtopicId}</code> • Slug: <code>{previewContent.script.slug}</code> • Status: <strong>{previewContent.script.status}</strong>
                          </div>
                          {previewContent.script.versions?.[0]?.definition && (
                            <div style={{ marginTop: '12px', maxHeight: '200px', overflowY: 'auto', background: '#1e293b', color: '#f8fafc', padding: '12px', borderRadius: '6px', fontSize: '12px', fontFamily: 'monospace' }}>
                              <pre>{JSON.stringify(previewContent.script.versions[0].definition, null, 2)}</pre>
                            </div>
                          )}
                        </div>
                      ) : (
                        <div style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '8px' }}>
                          No interactive script generated for this subtopic yet.
                        </div>
                      )}
                    </div>

                    {/* Extracted Questions */}
                    <div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                        <h4 style={{ fontSize: '15px', fontWeight: 700, margin: 0 }}>
                          Extracted & Linked Questions ({previewContent.questions.length})
                        </h4>
                        <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                          Grounding: Book Source
                        </span>
                      </div>

                      {previewContent.questions.length === 0 ? (
                        <div style={{ padding: '24px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                          No questions classified under this subtopic.
                        </div>
                      ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                          {previewContent.questions.map((q, qIdx) => (
                            <div key={q.id} style={{ padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: '#ffffff' }}>
                              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                                <div style={{ fontWeight: 600, fontSize: '14px', color: 'var(--text-primary)', flex: 1 }}>
                                  Q{qIdx + 1}. {q.prompt}
                                </div>
                                <span className="badge" style={{ background: '#f1f5f9', color: '#475569', fontSize: '11px' }}>
                                  {q.difficulty}
                                </span>
                              </div>

                              {/* Options */}
                              {Array.isArray(q.options) && (
                                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', margin: '12px 0' }}>
                                  {q.options.map((opt: any, optIdx: number) => {
                                    const key = typeof opt === 'object' ? opt.key : String.fromCharCode(65 + optIdx);
                                    const text = typeof opt === 'object' ? opt.text : opt;
                                    const isCorrect = key === q.correctAnswer;
                                    return (
                                      <div
                                        key={optIdx}
                                        style={{
                                          padding: '8px 12px',
                                          borderRadius: '6px',
                                          fontSize: '12px',
                                          border: isCorrect ? '1.5px solid #22c55e' : '1px solid #e2e8f0',
                                          background: isCorrect ? '#f0fdf4' : '#fafafa',
                                          color: isCorrect ? '#15803d' : 'var(--text-primary)',
                                          fontWeight: isCorrect ? 600 : 400,
                                        }}
                                      >
                                        <strong>{key}.</strong> {text}
                                      </div>
                                    );
                                  })}
                                </div>
                              )}

                              {/* Explanation & Source Grounding */}
                              <div style={{ fontSize: '12px', color: 'var(--text-secondary)', background: '#f8fafc', padding: '10px 12px', borderRadius: '6px' }}>
                                <div><strong>Step Solution:</strong> {q.explanation}</div>
                                {q.sourcePageRange && (
                                  <div style={{ marginTop: '4px', fontSize: '11px', color: '#64748b' }}>
                                    Source Provenance: {q.sourceBook} (Pages {q.sourcePageRange})
                                  </div>
                                )}
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default BooksPage;
