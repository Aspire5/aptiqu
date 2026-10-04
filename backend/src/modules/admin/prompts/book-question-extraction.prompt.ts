export const BOOK_QUESTION_EXTRACTION_SYSTEM_INSTRUCTION = `
You are an expert Aptitude Question Extractor and Mathematical Analyst for AptiQu.

CRITICAL INGESTION & GROUNDING RULES:
1. Extract questions faithfully from the provided textbook exercise/example pages.
2. PRESERVE ORIGINAL CONTENT:
   - Preserve prompt text, variables, numbers, and multiple choice options (A, B, C, D).
   - If options are not labeled A/B/C/D, assign them sequentially to A, B, C, D.
3. ANSWERS, HINTS & EXPLANATIONS:
   - Solution 1 (Book Method): Required. A clear, step-by-step mathematical explanation of the core concept. Provide the core formula in "method".
   - Solution 2 (Alternative Shortcut): Optional. Include ONLY if there is a genuinely distinct speed trick (e.g., unit-digit elimination, digital sum, ratio shortcut, option substitution) that reduces calculation steps.
   - If no alternative shortcut exists, set alternativeExplanation: null, preferredSolution: null, preferredReason: null.
   - Verification: Solution 1 and Solution 2 MUST produce the identical correct answer key.
   - If the book provides no hint, generate 1-2 didactic hints (Hint 1: Conceptual nudge; Hint 2: Formula setup).
   - If the book provides only an answer key with no explanation, derive the complete step-by-step solution.
4. STRICT EXAM PYQ ATTRIBUTION RULE:
   - Only assign PYQ metadata if the exam name and year are EXPLICITLY printed in the provided source material (e.g. "CLAT (2010)", "SSC CGL (2018)").
   - Never guess, remember, or reconstruct exam details from training weights. If not printed in the source, set pyq: null.
5. CALCULATION MODE & DIFFICULTY:
   - calculationMode: "MENTAL" (solvable in head < 30s), "LIGHT_PEN_AND_PAPER" (1-3 lines of scratchpad), "PEN_AND_PAPER" (multi-step algebra).
   - difficulty: "EASY", "MEDIUM", "HARD".

Output all extracted questions in a single JSON array matching the requested schema.
`.trim();

export const BOOK_QUESTION_ARRAY_JSON_SCHEMA = {
  type: 'object',
  properties: {
    questions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          externalQuestionKey: {
            type: 'string',
            description: 'Temporary or parsed question identifier (e.g. "q-001").',
          },
          pattern: {
            type: 'string',
            description: 'Core problem pattern (e.g., "PLACE_VALUE", "RELATIVE_SPEED", "UNIT_DIGIT").',
          },
          prompt: {
            type: 'string',
            description: 'Complete question text with all conditions and data.',
          },
          options: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                id: { type: 'string', enum: ['A', 'B', 'C', 'D'] },
                text: { type: 'string' },
              },
              required: ['id', 'text'],
            },
            description: 'List of at least 2 options (typically 4: A, B, C, D).',
          },
          correctAnswer: {
            type: 'string',
            enum: ['A', 'B', 'C', 'D'],
            description: 'Correct option letter.',
          },
          hints: {
            type: 'array',
            items: { type: 'string' },
            description: '1-2 didactic hints guiding the student.',
          },
          pyq: {
            type: ['string', 'null'],
            description: 'Exact exam attribution if printed in source, or null.',
          },
          method: {
            type: 'string',
            description: 'Core formula or technique descriptor.',
          },
          explanation: {
            type: 'string',
            description: 'Complete, step-by-step textbook explanation.',
          },
          alternativeExplanation: {
            type: ['string', 'null'],
            description: 'Alternative speed trick explanation, or null.',
          },
          preferredSolution: {
            type: ['string', 'null'],
            enum: ['BOOK', 'ALTERNATIVE', null],
          },
          preferredReason: {
            type: ['string', 'null'],
            description: 'Why the preferred method wins (fewer arithmetic operations, etc.).',
          },
          calculationMode: {
            type: 'string',
            enum: ['MENTAL', 'LIGHT_PEN_AND_PAPER', 'PEN_AND_PAPER'],
          },
          difficulty: {
            type: 'string',
            enum: ['EASY', 'MEDIUM', 'HARD'],
          },
          estimatedTimeSeconds: {
            type: 'integer',
            description: 'Estimated time budget in seconds (15 to 120).',
          },
          sourcePageNumber: {
            type: 'integer',
            description: 'Page number where the question was found.',
          },
        },
        required: [
          'prompt',
          'options',
          'correctAnswer',
          'hints',
          'method',
          'explanation',
          'calculationMode',
          'difficulty',
        ],
      },
    },
  },
  required: ['questions'],
};
