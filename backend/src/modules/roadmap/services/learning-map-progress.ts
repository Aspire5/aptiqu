/** Pure projection shared by the subject summary and topic map. No DB access. */
interface Subtopic {
  id: string;
  slug: string | null;
  name: string;
  sequence: number;
}
interface Assignment {
  id: string;
  scriptId: string;
  sequence: number;
  publishedVersionId: string | null;
  script: {
    slug: string;
    title: string;
    subtopicId: string | null;
    publishedVersionId: string | null;
  };
}

export function buildSubtopicProgress(
  topicSubtopics: readonly Subtopic[],
  assignments: readonly Assignment[],
  completedScriptIds: ReadonlySet<string>
) {
  const published = assignments.filter(a => a.publishedVersionId || a.script.publishedVersionId);
  const used = new Set<string>();
  const matches = new Map<string, Assignment>();
  // Explicit identities always take precedence over sequence-based legacy data.
  const byIdentity = new Map<string, Assignment>();
  const bySlug = new Map<string, Assignment>();
  for (const a of published) {
    if (a.script.subtopicId) byIdentity.set(a.script.subtopicId, a);
    else bySlug.set(a.script.slug, a);
  }
  for (const st of topicSubtopics) {
    const a = byIdentity.get(st.id) ?? (st.slug ? byIdentity.get(st.slug) ??
      bySlug.get(st.slug) ?? bySlug.get(`script-${st.slug}`) : undefined);
    if (a && !used.has(a.id)) {
      matches.set(st.id, a);
      used.add(a.id);
    }
  }
  const legacyBySequence = new Map<number, Assignment>();
  for (const a of published) {
    if (!a.script.subtopicId && !used.has(a.id)) legacyBySequence.set(a.sequence, a);
  }
  const subtopics = topicSubtopics.length > 0
    ? topicSubtopics.map(st => {
        const a = matches.get(st.id) ?? legacyBySequence.get(st.sequence);
        // Never reuse one script for two subtopics with overlapping identities.
        const match = matches.has(st.id) || (a && !used.has(a.id)) ? a : undefined;
        if (match) used.add(match.id);
        return {
          id: st.id,
          scriptId: match?.scriptId,
          scriptSlug: match?.script.slug,
          title: st.name,
          sequence: st.sequence,
          isCompleted: !!match && completedScriptIds.has(match.scriptId),
          isLocked: !match,
          canReplay: !!match && completedScriptIds.has(match.scriptId),
        };
      })
    : published.map(a => ({
        id: a.id,
        scriptId: a.scriptId,
        scriptSlug: a.script.slug,
        title: a.script.title,
        sequence: a.sequence,
        isCompleted: completedScriptIds.has(a.scriptId),
        isLocked: false,
        canReplay: completedScriptIds.has(a.scriptId),
      }));
  const completedSubtopics = subtopics.filter(st => st.isCompleted).length;
  return {
    subtopics,
    totalSubtopics: subtopics.length,
    completedSubtopics,
    hasPlayableContent: subtopics.some(st => !st.isLocked),
    isCompleted: subtopics.length > 0 && completedSubtopics === subtopics.length,
  };
}
