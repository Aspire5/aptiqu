import { useCallback, useEffect, useRef, useState } from 'react';
import { Award, Plus, RefreshCw, Pencil, Archive, Trash2, RotateCcw, X } from 'lucide-react';
import { apiClient } from '../services/api';
import './AchievementsPage.css';

type Definition = { id: string; title: string; description: string; metric: string; source: string;
  difficulty: string | null; target: number; sortOrder: number; isActive: boolean;
  deletedAt: string | null; version: number; completed: number; inProgress: number; notStarted: number; eligibleUsers: number };
type Options = { metrics: string[]; sources: string[]; difficulties: string[] };
type Result = { items: Definition[]; total: number; overall: { definitions: number; eligibleUsers: number; completed: number; inProgress: number } };
type Draft = { title: string; description: string; metric: string; source: string; difficulty: string;
  target: string; sortOrder: string; isActive: boolean };
const label = (value: string) => value.toLowerCase().replaceAll('_', ' ').replace(/^./, s => s.toUpperCase());
const message = (error: unknown) => (error as { response?: { data?: { error?: string } } })?.response?.data?.error || 'Request failed. Please try again.';

export function AchievementsPage() {
  const [result, setResult] = useState<Result | null>(null);
  const [options, setOptions] = useState<Options | null>(null);
  const [status, setStatus] = useState('ALL');
  const [search, setSearch] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [formError, setFormError] = useState('');
  const [editing, setEditing] = useState<Definition | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const sequence = useRef(0);
  const load = useCallback(async () => {
    const request = ++sequence.current;
    setLoading(true); setError('');
    try {
      const response = await apiClient.get('/achievements', { params: { page, limit: 20, search: query, status } });
      if (request === sequence.current) {
        const data: Result = response.data.data;
        if (!data.items.length && page > 1 && data.total <= (page - 1) * 20) {
          setPage(Math.max(1, Math.ceil(data.total / 20))); return;
        }
        setResult(data);
      }
    } catch (err) { if (request === sequence.current) setError(message(err)); }
    finally { if (request === sequence.current) setLoading(false); }
  }, [page, query, status]);
  useEffect(() => { void load(); return () => { sequence.current++; }; }, [load]);
  useEffect(() => { apiClient.get('/achievements/options').then(r => setOptions(r.data.data)).catch(e => setError(message(e))); }, []);
  useEffect(() => { const timeout = setTimeout(() => { setQuery(search); setPage(1); }, 300); return () => clearTimeout(timeout); }, [search]);
  useEffect(() => { if (draft) { dialog.current?.showModal(); dialog.current?.querySelector<HTMLInputElement>('input')?.focus(); } }, [draft !== null]);
  const open = (definition?: Definition) => {
    if (!options) return;
    setEditing(definition || null); setFormError('');
    setDraft(definition ? { ...definition, difficulty: definition.difficulty || '', target: String(definition.target), sortOrder: String(definition.sortOrder) }
      : { title: '', description: '', metric: options.metrics[0], source: 'ALL', difficulty: '', target: '', sortOrder: '0', isActive: true });
  };
  const close = () => { if (!busy) { dialog.current?.close(); setDraft(null); } };
  const save = async (event: React.FormEvent) => {
    event.preventDefault(); if (!draft || busy) return;
    setBusy(true); setFormError('');
    const payload = { title: draft.title.trim(), description: draft.description.trim(), metric: draft.metric,
      source: draft.source, difficulty: draft.difficulty || null, target: Number(draft.target), sortOrder: Number(draft.sortOrder), isActive: draft.isActive };
    try {
      if (editing) await apiClient.put(`/achievements/${editing.id}`, { ...payload, version: editing.version });
      else await apiClient.post('/achievements', payload);
      dialog.current?.close(); setDraft(null); await load();
    } catch (err) { setFormError(message(err)); }
    finally { setBusy(false); }
  };
  const change = async (definition: Definition, action: 'archive' | 'hard' | 'restore') => {
    if (busy) return;
    const text = action === 'hard' ? `Permanently delete “${definition.title}”? It cannot be restored.`
      : action === 'restore' ? `Restore “${definition.title}” as inactive? You can activate it after reviewing its rule.`
      : `Soft delete “${definition.title}”? It will disappear from the app and can be restored.`;
    if (!window.confirm(text)) return;
    setBusy(true); setError('');
    try {
      if (action === 'restore') await apiClient.post(`/achievements/${definition.id}/restore`, { version: definition.version });
      else await apiClient.delete(`/achievements/${definition.id}`, { params: { hard: action === 'hard' }, data: { version: definition.version } });
      await load();
    } catch (err) { setError(message(err)); }
    finally { setBusy(false); }
  };
  return <section className="achievements-page">
    <div className="achievements-toolbar"><div><h2><Award size={24} /> Achievements</h2>
      <p>Create milestones and see live progress from recorded learning activity.</p></div>
      <div><button className="btn-secondary" disabled={busy || loading} onClick={() => void load()}><RefreshCw size={16} /> Refresh</button>
      <button className="btn-primary" disabled={!options || busy || loading} onClick={() => open()}><Plus size={16} /> New achievement</button></div></div>
    {error && <div role="alert" className="achievement-error">{error}</div>}
    <div className="achievements-filters">
      <label>Search<input className="form-control" type="search" value={search} onChange={e => setSearch(e.target.value)} placeholder="Title or description" /></label>
      <label>Status<select className="form-control" value={status} onChange={e => { setStatus(e.target.value); setPage(1); }}>
        <option value="ALL">All definitions</option><option value="ACTIVE">Active</option><option value="ARCHIVED">Soft deleted</option></select></label>
    </div>
    {result && <><div className="achievements-stats" aria-busy={loading}>
      {[['Matching achievements', result.overall.definitions], ['Registered learners', result.overall.eligibleUsers],
        ['Completed milestones', result.overall.completed], ['Milestones in progress', result.overall.inProgress]].map(([title, value]) =>
        <div className="stat-card" key={title}><span>{title}</span><strong>{Number(value).toLocaleString()}</strong></div>)}
    </div><p className="achievement-note">Totals follow the current filters. Milestone totals count learner–achievement pairs, not distinct learners. In progress means greater than zero and below the target. Analytics include registered learners only and reflect retained history.</p></>}
    {loading && <p role="status">Loading achievements…</p>}
    <div className="achievements-table-wrap"><table className="achievements-table"><thead><tr>
      <th>Achievement</th><th>Rule</th><th>Status</th><th>Completed</th><th>In progress</th><th>Not started</th><th>Actions</th>
    </tr></thead><tbody>{result?.items.map(a => <tr key={a.id}>
      <td><strong>{a.title}</strong><p>{a.description}</p></td>
      <td>{label(a.metric)} ≥ {a.target.toLocaleString()}<small>{label(a.source)} · {a.difficulty ? label(a.difficulty) : 'All difficulties'}</small></td>
      <td>{a.deletedAt ? 'Soft deleted' : a.isActive ? 'Active' : 'Inactive'}</td>
      <td>{a.completed.toLocaleString()}<small>{a.eligibleUsers ? (a.completed / a.eligibleUsers * 100).toFixed(1) : '0'}% of learners</small></td>
      <td>{a.inProgress.toLocaleString()}</td><td>{a.notStarted.toLocaleString()}</td>
      <td><div className="achievement-actions">
        {!a.deletedAt && <><button disabled={busy || loading} title="Edit achievement" aria-label={`Edit ${a.title}`} onClick={() => open(a)}><Pencil size={16} /></button>
          <button disabled={busy || loading} title="Soft delete" aria-label={`Soft delete ${a.title}`} onClick={() => void change(a, 'archive')}><Archive size={16} /></button></>}
        {a.deletedAt && <button disabled={busy || loading} title="Restore inactive" aria-label={`Restore ${a.title}`} onClick={() => void change(a, 'restore')}><RotateCcw size={16} /></button>}
        <button disabled={busy || loading} className="achievement-danger" title="Permanently delete" aria-label={`Permanently delete ${a.title}`} onClick={() => void change(a, 'hard')}><Trash2 size={16} /></button>
      </div></td></tr>)}</tbody></table></div>
    {!loading && result?.items.length === 0 && <p className="achievement-empty">No matching achievements. Create one to make it available in the app.</p>}
    {result && <div className="pagination"><span>{result.total} achievements · Page {page} of {Math.max(1, Math.ceil(result.total / 20))}</span><div>
      <button className="pagination-btn" disabled={page <= 1 || loading || busy} onClick={() => setPage(page - 1)}>Previous</button>
      <button className="pagination-btn" disabled={page * 20 >= result.total || loading || busy} onClick={() => setPage(page + 1)}>Next</button></div></div>}
    <dialog ref={dialog} className="achievement-dialog" onCancel={e => { e.preventDefault(); close(); }}>
      {draft && options && <form onSubmit={save}><div className="modal-header"><h3>{editing ? 'Edit achievement' : 'New achievement'}</h3>
        <button type="button" disabled={busy} aria-label="Close editor" onClick={close}><X size={20} /></button></div>
        <fieldset className="modal-body" disabled={busy}>{formError && <div role="alert" className="achievement-error">{formError}</div>}
          <label className="form-group">Title<input autoFocus className="form-control" required maxLength={120} value={draft.title} onChange={e => setDraft({ ...draft, title: e.target.value })} /></label>
          <label className="form-group">Description<textarea className="form-control" required maxLength={500} value={draft.description} onChange={e => setDraft({ ...draft, description: e.target.value })} /></label>
          <label className="form-group">Metric<select className="form-control" value={draft.metric} onChange={e => setDraft({ ...draft, metric: e.target.value, source: 'ALL', difficulty: '' })}>
            {options.metrics.map(value => <option key={value}>{value}</option>)}</select></label>
          <div className="achievements-filters"><label>Source<select className="form-control" disabled={!['ATTEMPTED', 'CORRECT'].includes(draft.metric)} value={draft.source} onChange={e => setDraft({ ...draft, source: e.target.value })}>
            {options.sources.map(value => <option key={value}>{value}</option>)}</select></label>
            <label>Difficulty<select className="form-control" disabled={!['ATTEMPTED', 'CORRECT'].includes(draft.metric)} value={draft.difficulty} onChange={e => setDraft({ ...draft, difficulty: e.target.value })}>
              <option value="">All difficulties</option>{options.difficulties.map(value => <option key={value}>{value}</option>)}</select></label></div>
          <div className="achievements-filters"><label>Target<input className="form-control" type="number" required min={1} max={2147483647} step={1} value={draft.target} onChange={e => setDraft({ ...draft, target: e.target.value })} /></label>
            <label>Display order<input className="form-control" type="number" required min={0} max={2147483647} step={1} value={draft.sortOrder} onChange={e => setDraft({ ...draft, sortOrder: e.target.value })} /></label></div>
          <label><input type="checkbox" checked={draft.isActive} onChange={e => setDraft({ ...draft, isActive: e.target.checked })} /> Active in the app</label>
          <p className="achievement-note">Rules apply to retained history, including earlier answers. Changing a target or rule recalculates progress. Best streak means the learner’s recorded highest Daily Challenge streak.</p>
        </fieldset><div className="modal-footer"><button type="button" className="btn-secondary" disabled={busy} onClick={close}>Cancel</button><button className="btn-primary" disabled={busy}>{busy ? 'Saving…' : 'Save achievement'}</button></div>
      </form>}
    </dialog>
  </section>;
}
