export const TOPIC_DISCOVERY_SYSTEM_INSTRUCTION = `
You are an expert Educational Curriculum Architect for AptiQu.

CRITICAL CONTENT-GROUNDING RULE:
You are analyzing source material from an uploaded educational textbook.
- You must NOT browse the internet or use external educational syllabi.
- You must NOT invent topics that are not present in the supplied source material.
- Your goal is to detect the MAJOR TOPICS (Chapters) of this book along with their start and end page numbers.

If Table of Contents (TOC) pages are provided:
- Use the TOC as the primary structural ground truth.
- Identify each major chapter/topic title.
- Map the printed page numbers to the actual book page range.

If Content pages are provided without a TOC:
- Infer the major topic boundaries from chapter title headings, section breaks, and subject shifts.

Output the chapters in strict pedagogical sequence as a JSON object matching the requested schema.
`.trim();

export const TOPIC_DISCOVERY_JSON_SCHEMA = {
  type: 'object',
  properties: {
    topics: {
      type: 'array',
      description: 'List of major chapters/topics discovered in the book.',
      items: {
        type: 'object',
        properties: {
          code: {
            type: 'string',
            description: 'Short 2-4 letter uppercase code for the topic (e.g., "NS" for Number System, "TSD" for Time Speed Distance).',
          },
          name: {
            type: 'string',
            description: 'Official chapter/topic title as printed in the book.',
          },
          suggestedSlug: {
            type: 'string',
            description: 'URL-friendly kebab-case slug (e.g., "number-system").',
          },
          startPage: {
            type: 'integer',
            description: 'Page number where this topic begins (inclusive).',
          },
          endPage: {
            type: 'integer',
            description: 'Page number where this topic ends (inclusive).',
          },
          description: {
            type: 'string',
            description: 'A 1-2 sentence overview of what this chapter covers according to the book.',
          },
          confidence: {
            type: 'number',
            description: 'Confidence score between 0.0 and 1.0 regarding the boundary accuracy.',
          },
        },
        required: ['code', 'name', 'suggestedSlug', 'startPage', 'endPage', 'confidence'],
      },
    },
  },
  required: ['topics'],
};
