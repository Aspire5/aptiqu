export const SUBTOPIC_DISCOVERY_SYSTEM_INSTRUCTION = `
You are an expert Educational Curriculum Architect and Aptitude Master for AptiQu.

CRITICAL CONTENT-GROUNDING & GRANULARITY RULES:
1. The supplied textbook pages for this chapter are your SOLE AUTHORITATIVE SOURCE.
2. Do NOT browse the internet, introduce formulas from other sources, or hallucinate concepts.
3. CONTENT-DRIVEN GRANULARITY (NO ARBITRARY SUBTOPIC COUNTS):
   - A subtopic must represent a distinct, teachable mathematical/conceptual unit (e.g. a concept, a calculation method, a formula family, or a specific problem class).
   - Do NOT force an arbitrary minimum or maximum number of subtopics. A compact topic may have 1 to 3 subtopics; a standard topic may have 4 to 8; an extensive master chapter may have 12 to 20+.
   - Do NOT create a subtopic merely because a paragraph breaks, a decorative heading exists, or a minor worked example appears.
   - Do NOT merge genuinely distinct concepts together if doing so harms pedagogical clarity.
4. For each subtopic, identify:
   - Meaningful name
   - Suggested kebab-case slug
   - Start and end page numbers within this topic's range
   - Short pedagogical description
   - Key concepts covered
   - Key formulas (verbatim from source)
   - Speed shortcuts/tricks (verbatim from source)

Output your proposal as a JSON object matching the requested schema.
`.trim();

export const SUBTOPIC_DISCOVERY_JSON_SCHEMA = {
  type: 'object',
  properties: {
    subtopics: {
      type: 'array',
      description: 'Pedagogical subtopics covering the chapter material without artificial fragmentation.',
      items: {
        type: 'object',
        properties: {
          sequence: {
            type: 'integer',
            description: '1-based ordering in pedagogical sequence from fundamentals to advanced applications.',
          },
          code: {
            type: 'string',
            description: 'Stable code suffix (e.g., "01", "02", "12").',
          },
          name: {
            type: 'string',
            description: 'Clear, concise subtopic title.',
          },
          suggestedSlug: {
            type: 'string',
            description: 'URL-friendly slug (e.g., "place-value-notation").',
          },
          startPage: {
            type: 'integer',
            description: 'Starting page number within the textbook for this subtopic.',
          },
          endPage: {
            type: 'integer',
            description: 'Ending page number within the textbook for this subtopic.',
          },
          description: {
            type: 'string',
            description: '1-2 sentence summary of what this subtopic teaches.',
          },
          teachingMinutes: {
            type: 'integer',
            description: 'Estimated teaching duration in minutes (typically 8-15 minutes).',
          },
          importance: {
            type: 'string',
            enum: ['CORE', 'ADVANCED', 'PRACTICE'],
            description: 'Curriculum importance weighting.',
          },
          keyConcepts: {
            type: 'array',
            items: { type: 'string' },
            description: 'Specific concepts introduced in this subtopic.',
          },
          keyFormulas: {
            type: 'array',
            items: { type: 'string' },
            description: 'Mathematical formulas explicitly present in the source text for this subtopic.',
          },
          speedTricks: {
            type: 'array',
            items: { type: 'string' },
            description: 'Mental shortcuts or elimination rules explicitly mentioned in the source.',
          },
        },
        required: [
          'sequence',
          'code',
          'name',
          'suggestedSlug',
          'startPage',
          'endPage',
          'description',
          'keyConcepts',
        ],
      },
    },
  },
  required: ['subtopics'],
};
