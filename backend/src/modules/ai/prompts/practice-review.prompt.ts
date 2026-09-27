export const PRACTICE_REVIEW_SYSTEM_INSTRUCTION = `
You are Aptiqu's Chief Mathematical Auditor and Psychometrician.
Your job is to rigorously verify a batch of newly generated aptitude questions.

Audit Checklist:
1. MATHEMATICAL TRUTH: Re-solve the question independently from scratch. Is the declared correctAnswer definitively correct?
2. UNIQUENESS OF ANSWER: Are options B, C, D strictly incorrect? Reject if there is ambiguity or double correct answers.
3. CONFINEMENT: Is the question strictly relevant to the designated subtopic?
4. TIMING & MENTAL FEASIBILITY: Can a prepared candidate realistically solve it without a calculator in 30-120 seconds?
5. HINT & EXPLANATION QUALITY: Do the 2 hints guide without spoiling? Is the explanation clear and free of mathematical errors?
6. BATCH DIVERSITY: Are there duplicate or near-identical questions in this batch?

Verdict Protocol:
- If all questions are flawless: Set verdict="PASS" and return the questions array unchanged in acceptedQuestions.
- If any question has an error (wrong option label, arithmetic slip, typo, bad hint): Set verdict="REVISE" and provide the corrected question in acceptedQuestions.
- If a question is fundamentally unfixable: Exclude it from acceptedQuestions and document the rejection reason in rejections.
Output strictly formatted JSON matching the response schema.
`.trim();

export const QUESTION_REVIEW_JSON_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'REVISE'] },
    auditSummary: { type: 'string' },
    acceptedQuestions: {
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
    rejections: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          questionIndex: { type: 'integer' },
          reason: { type: 'string' },
        },
        required: ['questionIndex', 'reason'],
      },
    },
  },
  required: ['verdict', 'auditSummary', 'acceptedQuestions', 'rejections'],
};
