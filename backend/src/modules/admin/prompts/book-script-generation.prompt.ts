export const BOOK_SCRIPT_GENERATION_SYSTEM_INSTRUCTION = `
You are an expert Aptitude Master and Interactive Lesson Architect for AptiQu.

CRITICAL CONTENT-GROUNDING & SCRIPT RULES:
1. Ground all instruction strictly in the supplied source textbook pages. Do NOT invent new formulas or tricks.
2. TONE & STYLE:
   - Direct, clear, conversational 1-on-1 human tutor.
   - Explain WHY standard algebraic approaches are slow, and HOW the book's speed trick eliminates steps.
3. SCRIPT DSL TOPOLOGY:
   - Must contain nodes of type "CONTENT", "QUESTION", and "COMPLETION".
   - The first node must be "node-1" (or entryNodeId).
   - The final node must have type: "COMPLETION" with transitions: [].
   - QUESTION nodes MUST reference one of the supplied question externalIds using:
     "questionReference": { "mode": "QUESTION_EXTERNAL_ID", "externalId": "<externalKey>" }
   - Do NOT duplicate prompt/options inside QUESTION node; questionHydrationService will hydrate it automatically.
   - Transitions must form a valid connected flow with no dangling node IDs.

Output the complete ScriptDefinition matching the required schema.
`.trim();

export const SCRIPT_DEFINITION_JSON_SCHEMA = {
  type: 'object',
  properties: {
    schemaVersion: { type: 'integer', enum: [1] },
    scriptId: { type: 'string' },
    version: { type: 'integer', enum: [1] },
    sourceType: { type: 'string', enum: ['MANUAL'] },
    entryNodeId: { type: 'string' },
    metadata: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        targetDurationMinutes: { type: 'integer' },
        description: { type: 'string' },
      },
      required: ['title', 'targetDurationMinutes'],
    },
    nodes: {
      type: 'object',
      description: 'Dictionary of lesson nodes keyed by node ID.',
      additionalProperties: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          type: { type: 'string', enum: ['CONTENT', 'QUESTION', 'COMPLETION'] },
          content: {
            type: 'object',
            properties: {
              text: { type: 'string' },
              avatarPersona: { type: 'string', enum: ['TUTOR', 'SYSTEM', 'PEER'] },
            },
            required: ['text'],
          },
          questionReference: {
            type: 'object',
            properties: {
              mode: { type: 'string', enum: ['QUESTION_EXTERNAL_ID'] },
              externalId: { type: 'string' },
            },
          },
          transitions: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                targetNodeId: { type: 'string' },
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
