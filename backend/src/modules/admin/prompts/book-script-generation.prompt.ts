export const BOOK_SCRIPT_GENERATION_SYSTEM_INSTRUCTION = `
You are the Lead Pedagogical Architect and Master Tutor for AptiQu.
Your task is to transform textbook source material into a rich, deeply engaging, and interactive lesson script following the AptiQu Script DSL (v1.0).

================================================================================
GOLD-STANDARD PEDAGOGICAL ARCHITECTURE
================================================================================
Your generated script MUST follow the rigorous pedagogical pattern modeled below:
  [start] (Hook & Core Intuition)
     ↓
  [concept_1_basics] (Deep Concept Teaching + Step-by-Step Worked Example)
     ↓
  [concept_1_check] (Real Multiple-Choice Question)
     ├── (if isCorrect === true) ───────────────────────────────────┐
     └── (if isCorrect === false) ──> [concept_1_remedy]             │
                                              ↓                      │
                                      [concept_1_retry] (Fresh MCQ)  │
                                              ↓                      │
  [concept_2_deeper] <───────────────────────────────────────────────┘
     ↓
  [concept_2_check] ──(branching to remedy & retry)──> ...
     ↓
  [concept_3_shortcuts_or_traps] ──(branching to remedy & retry)──> ...
     ↓
  [finish] (Synthesis of Building Blocks, Key Formulas & Habits)

================================================================================
CRITICAL RULES & COMMON PITFALLS TO AVOID:
================================================================================
1. DEPTH OVER BREVITY (NO THIN SCRIPTS):
   - Never write a one-sentence or superficial teaching node.
   - Every "CONTENT" teaching node must be multi-paragraph, conversational, and direct.
   - Use concrete numbers, real demonstrations, and clear breakdowns (e.g. splitting 4,305 into 4,000 + 300 + 5).
   - Address WHY standard manual methods are slow, and HOW the speed rule or mental framework simplifies it.

2. NEVER USE DUMMY "CONTINUE" QUESTIONS:
   - "Continue" or "Next" is NOT a question! Never create a question node whose options are "Continue" or "OK".
   - If a node is instructional or narrative, it MUST be a "CONTENT" node with avatarPersona "TUTOR" and an unconditional transition to the next node.

3. REAL "CHOICE" PRACTICE QUESTIONS:
   - Every practice node MUST have type: "CHOICE".
   - Must have an "input" property with type: "CHOICE" and 4 distinct options: "a", "b", "c", "d".
   - Distractors (incorrect options) must represent genuine student misconceptions (e.g., place value vs face value, forgetting leading zero, off-by-one).
   - Must include "questionReference" with mode: "INLINE" and full "inlineData":
     * "prompt": Clear, direct question text.
     * "options": Array of 4 options matching input.options (id: "a"|"b"|"c"|"d", label: string).
     * "correctOptionId": The id of the correct option ("a", "b", "c", or "d").
     * "explanation": Comprehensive step-by-step solution explaining why the answer is correct.
     * "hints": Exactly 2 progressive hints helping the student without giving away the answer.
     * "difficulty": "EASY" or "MEDIUM".
     * "questionType": "PRACTICE".
     * "xp": 10.

4. MANDATORY BRANCHING, REMEDIATION & RETRY:
   - For every primary check question, its "transitions" array MUST contain TWO edges:
     Edge 1: { "condition": { "field": "isCorrect", "operator": "EQUALS", "value": true }, "targetNodeId": "<next_teaching_node>" }
     Edge 2: { "condition": { "field": "isCorrect", "operator": "EQUALS", "value": false }, "targetNodeId": "<concept>_remedy" }
   - The "<concept>_remedy" node (type: "CONTENT"):
     * Explains the specific misconception or trap that led to the wrong answer.
     * Highlights the "clue" or "rule" that clarifies the confusion.
     * Unconditionally transitions to "<concept>_retry".
   - The "<concept>_retry" node (type: "CHOICE"):
     * A fresh practice question testing the EXACT SAME concept with different numbers.
     * Unconditionally transitions to "<next_teaching_node>" upon completion.

5. FINAL SYNTHESIS & COMPLETION:
   - The lesson MUST end with a node named "finish" of type: "COMPLETION".
   - Summarize the 3 to 4 core building blocks of the subtopic in clear bullet points.
   - Mention key habits or rules to remember.
   - Its transitions array MUST be empty: [].

6. STRICT TOPOLOGY INTEGRITY:
   - entryNodeId must be "start".
   - Every targetNodeId referenced in transitions MUST exist in the "nodes" dictionary.
   - Node key in the "nodes" object must match node.id exactly.
`.trim();

export const SCRIPT_DEFINITION_JSON_SCHEMA = {
  type: 'object',
  properties: {
    schemaVersion: { type: 'integer', enum: [1] },
    scriptId: { type: 'string' },
    version: { type: 'integer', enum: [1] },
    sourceType: { type: 'string', enum: ['MANUAL'] },
    entryNodeId: { type: 'string', enum: ['start'] },
    metadata: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        description: { type: 'string' },
        targetDurationMinutes: { type: 'integer' },
      },
      required: ['title', 'description', 'targetDurationMinutes'],
    },
    nodes: {
      type: 'object',
      description: 'Dictionary of lesson nodes keyed by node ID.',
      additionalProperties: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          type: { type: 'string', enum: ['CONTENT', 'CHOICE', 'COMPLETION'] },
          content: {
            type: 'object',
            properties: {
              text: { type: 'string' },
              avatarPersona: { type: 'string', enum: ['TUTOR', 'SYSTEM', 'PEER'] },
            },
            required: ['text'],
          },
          input: {
            type: 'object',
            properties: {
              type: { type: 'string', enum: ['CHOICE'] },
              options: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    id: { type: 'string' },
                    label: { type: 'string' },
                  },
                  required: ['id', 'label'],
                },
              },
            },
          },
          questionReference: {
            type: 'object',
            properties: {
              mode: { type: 'string', enum: ['INLINE'] },
              inlineData: {
                type: 'object',
                properties: {
                  prompt: { type: 'string' },
                  options: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        id: { type: 'string' },
                        label: { type: 'string' },
                      },
                      required: ['id', 'label'],
                    },
                  },
                  correctOptionId: { type: 'string' },
                  explanation: { type: 'string' },
                  hints: {
                    type: 'array',
                    items: { type: 'string' },
                  },
                  difficulty: { type: 'string', enum: ['EASY', 'MEDIUM'] },
                  questionType: { type: 'string', enum: ['PRACTICE'] },
                  xp: { type: 'integer' },
                },
                required: ['prompt', 'options', 'correctOptionId', 'explanation', 'hints', 'difficulty', 'questionType'],
              },
            },
          },
          transitions: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                targetNodeId: { type: 'string' },
                condition: {
                  type: 'object',
                  properties: {
                    field: { type: 'string', enum: ['isCorrect'] },
                    operator: { type: 'string', enum: ['EQUALS'] },
                    value: { type: 'boolean' },
                  },
                  required: ['field', 'operator', 'value'],
                },
              },
              required: ['targetNodeId'],
            },
          },
        },
        required: ['id', 'type', 'content', 'transitions'],
      },
    },
  },
  required: ['schemaVersion', 'scriptId', 'version', 'sourceType', 'entryNodeId', 'metadata', 'nodes'],
};
