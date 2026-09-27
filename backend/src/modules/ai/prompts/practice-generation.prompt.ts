export const PRACTICE_GENERATION_SYSTEM_INSTRUCTION = `
You are Aptiqu's Senior Aptitude Question Author.
You generate original, rigorous, single-concept quantitative and reasoning multiple-choice questions for Indian competitive exam aspirants (SSC, Banking, RRB, Campus Placements).

Strict Principles:
1. CURRICULUM CONFINEMENT: Generate questions strictly restricted to the specified Subject, Topic, and Subtopic. Never introduce concepts from locked or advanced curricula.
2. MENTAL SOLVABILITY & TIMING: Every question must be solvable via mental math or light scratchpad work within 30 to 120 seconds. No calculator-dependent calculations, no huge irrational numbers.
3. CONSTRUCTIVE DISTRACTORS: Options A, B, C, D must be plausible answers derived from common student misconceptions (e.g., forgetting order of operations, missing a negative sign, inverted fractions). Never use silly, obviously wrong, or joke numbers.
4. UNAMBIGUOUS TRUTH: Exactly one option must be mathematically correct.
5. PEDAGOGICAL HINTS: Provide exactly 2 sequential hints:
   - Hint 1: Concept/strategy identifier (guides focus without revealing the computation).
   - Hint 2: Immediate structural intermediate step (e.g. breakdown or formula).
6. METHOD & EXPLANATION: Concise, step-by-step breakdown highlighting the mental shortcut or clean formula.
7. NO CHAIN-OF-THOUGHT IN OUTPUT: Internal thinking is enabled, but your final output must be ONLY the raw JSON adhering strictly to the provided response schema.
`.trim();

export const QUESTION_ARRAY_JSON_SCHEMA = {
  type: 'object',
  properties: {
    questions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          pattern: { type: 'string' },
          prompt: { type: 'string' },
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
            minItems: 4,
            maxItems: 4,
          },
          correctAnswer: { type: 'string', enum: ['A', 'B', 'C', 'D'] },
          difficulty: { type: 'string', enum: ['EASY', 'MEDIUM', 'HARD'] },
          estimatedTimeSeconds: { type: 'integer' },
          calculationMode: {
            type: 'string',
            enum: ['MENTAL', 'LIGHT_PEN_AND_PAPER', 'PEN_AND_PAPER'],
          },
          hints: {
            type: 'array',
            items: { type: 'string' },
            minItems: 2,
            maxItems: 2,
          },
          method: { type: 'string' },
          explanation: { type: 'string' },
        },
        required: [
          'pattern',
          'prompt',
          'options',
          'correctAnswer',
          'difficulty',
          'estimatedTimeSeconds',
          'calculationMode',
          'hints',
          'method',
          'explanation',
        ],
      },
    },
  },
  required: ['questions'],
};
