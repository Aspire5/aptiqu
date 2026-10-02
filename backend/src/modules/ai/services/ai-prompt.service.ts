import { prisma } from '../../../config/prisma';
import { PVP_GENERATION_SYSTEM_INSTRUCTION } from '../prompts/pvp-generation.prompt';
import { PVP_REVIEW_SYSTEM_INSTRUCTION } from '../prompts/pvp-review.prompt';
import { PRACTICE_GENERATION_SYSTEM_INSTRUCTION } from '../prompts/practice-generation.prompt';
import { PRACTICE_REVIEW_SYSTEM_INSTRUCTION } from '../prompts/practice-review.prompt';
import { DAILY_CHALLENGE_GENERATION_SYSTEM_INSTRUCTION } from '../prompts/daily-challenge-generation.prompt';

export interface PromptDefinition {
  key: string;
  title: string;
  category: 'SERVER_GENERATION' | 'SERVER_REVIEW' | 'MANUAL_REFERENCE';
  description: string;
  defaultPrompt: string;
  variables: { name: string; description: string }[];
}

export const BOOK_CURRICULUM_SYNTHESIS_PROMPT = `
You are an expert Aptitude Master Educator and Curriculum Architect for AptiQu, a competitive examination preparation platform.

I have provided:
1. Reference material (images or text) from an authoritative aptitude textbook for a single chapter/topic (containing theoretical explanations, formulas, speed shortcuts, and worked examples).
2. A pool of practice questions and Previous Year Questions (PYQs) associated with this topic.

YOUR TASK:
Extract, synthesize, and structure this material into two production-ready JSON artifacts:
1. SUBTOPIC LIST & LESSON SCRIPTS (in AptiQu DSL format, referencing questions by external key).
2. QUESTION BANK JSON (linked via external subtopic keys, with optional dual solutions and strict PYQ attribution).

================================================================================
STRICT PEDAGOGICAL & CONTENT GUIDELINES
================================================================================
1. INDEPENDENT EXPLANATIONS (COPYRIGHT COMPLIANCE):
   - Use the supplied material strictly as a technical reference for understanding the mathematical concepts, formulas, shortcuts, and derivations.
   - Write completely independent, original explanations in AptiQu's direct, conversational teaching style.
   - DO NOT reproduce textbook prose, proprietary worked examples, distinctive phrasing, or close textual adaptations.
   - Maintain full mathematical precision while formulating the pedagogical explanation independently.

2. TONE & PROHIBITED BUZZWORDS:
   - Write like a world-class human private tutor or clear teacher.
   - FORBIDDEN JARGON: NEVER use terms such as "live engine", "advanced AI analysis", "neural tutor", "deep learning breakdown", or "system algorithm".

3. OPTIMAL STUDY SEQUENCE:
   - Organize the topic into a linear sequence of subtopics representing the strict pedagogical progression from fundamentals to advanced speed shortcuts.
   - Assign each subtopic an immutable externalSubtopicKey (e.g., "tsd-01-relative-speed").

4. SCRIPT & QUESTION RELATIONSHIP (NO DUPLICATION):
   - Do NOT duplicate complete question payloads (prompts, options, answers) inside the Lesson Script.
   - Assign each question an externalQuestionKey (e.g., "tsd-q-001").
   - In lesson scripts, reference questions via:
     "questionReference": { "mode": "QUESTION_EXTERNAL_ID", "externalId": "tsd-q-001" }

5. DUAL-SOLUTION RULES (OPTIONAL, NOT FORCED):
   - Solution 1 (Book Method): ALWAYS REQUIRED in "explanation". A clear, step-by-step mathematical explanation of the core concept. Also provide the core formula/rule in "method".
   - Solution 2 (Alternative Shortcut): OPTIONAL in "alternativeExplanation". Include ONLY if there is a genuinely useful, materially different method (e.g., unit-digit elimination, digital sum, ratio shortcut, option substitution) that reduces calculation steps.
   - If no distinct alternative method is practical, set:
     "alternativeExplanation": null, "preferredSolution": null, "preferredReason": null
   - CRITICAL VERIFICATION: Solution 1 and Solution 2 MUST produce the identical numerical result and correct option key.
   - REASONING PRECISION (NO FABRICATED TIME SAVINGS):
     Explain WHY the preferred method is superior strictly in terms of:
     - Fewer arithmetic operations
     - Elimination of intermediate algebraic variables
     - Lower probability of calculation errors
     - Direct option elimination
     DO NOT fabricate exact time metrics (e.g., do NOT say "saves 15 seconds"; say "avoids calculating the train length and reduces arithmetic from 4 steps to 1").

6. STRICT PYQ METADATA RULE:
   - Only assign PYQ metadata if the exam name and year are EXPLICITLY printed in the provided source material.
   - Format: "exam_name (year), exam_name (year)" (e.g., "TCS NQT (2023), CAT (2012)").
   - NEVER guess, remember, infer, or reconstruct exam/year details from training weights.
   - If not explicitly given in the source, set "pyq": null.

7. UNCERTAINTY & UNREADABLE SOURCE PROTOCOL:
   - If any page segment, formula, question, or answer key is blurry, obscured, or ambiguous, DO NOT GUESS.
   - Record each instance in the "reviewRequired" array with the page reference and nature of the ambiguity.

================================================================================
OUTPUT FORMAT SPECIFICATION
================================================================================
Output your complete response in two clearly demarcated JSON blocks:

### BLOCK 1: SUBTOPICS & LESSON SCRIPTS
\`\`\`json
{
  "topic": {
    "name": "<Topic Name, e.g., Time, Speed and Distance>",
    "suggestedSlug": "time-speed-distance",
    "description": "<Concise summary of chapter concepts>"
  },
  "provenance": {
    "bookTitle": "<e.g., Quantitative Aptitude for Competitive Examinations>",
    "edition": "<e.g., 2024 Revised Edition>",
    "chapter": "<e.g., Chapter 17: Time and Distance>",
    "pageRange": "<e.g., pp. 412-435>"
  },
  "subtopics": [
    {
      "sequence": 1,
      "externalSubtopicKey": "tsd-01-relative-speed",
      "name": "Relative Speed Fundamentals",
      "description": "Objects moving in identical vs. opposing directions with ratio derivations.",
      "teachingMinutes": 8,
      "importance": "CORE",
      "script": {
        "schemaVersion": 1,
        "scriptId": "script-tsd-01-relative-speed",
        "version": 1,
        "sourceType": "MANUAL",
        "entryNodeId": "node-1",
        "metadata": {
          "title": "Relative Speed & Directional Vectors",
          "targetDurationMinutes": 8,
          "description": "Core relative speed mechanics for trains, cars, and runners."
        },
        "nodes": {
          "node-1": {
            "id": "node-1",
            "type": "CONTENT",
            "content": {
              "text": "When two objects move simultaneously, their relative velocity depends directly on direction...",
              "avatarPersona": "TUTOR"
            },
            "transitions": [{ "targetNodeId": "node-2" }]
          },
          "node-2": {
            "id": "node-2",
            "type": "QUESTION",
            "content": { "text": "Let's apply this relative speed principle to a real problem:" },
            "questionReference": {
              "mode": "QUESTION_EXTERNAL_ID",
              "externalId": "tsd-q-001"
            },
            "transitions": [{ "targetNodeId": "node-3" }]
          },
          "node-3": {
            "id": "node-3",
            "type": "COMPLETION",
            "content": { "text": "Great job! You now understand the foundation of relative speed." },
            "transitions": []
          }
        }
      }
    }
  ],
  "reviewRequired": []
}
\`\`\`

### BLOCK 2: QUESTION BANK ARRAY (FOR BULK IMPORT)
\`\`\`json
[
  {
    "externalQuestionKey": "tsd-q-001",
    "externalSubtopicKey": "tsd-01-relative-speed",
    "pattern": "TRAIN_PLATFORM_CROSSING",
    "prompt": "A train running at 54 km/hr takes 20 seconds to pass a pole and 36 seconds to pass a platform. What is the length of the platform?",
    "questionType": "MCQ",
    "inputType": "SINGLE_SELECT",
    "calculationMode": "MENTAL",
    "difficulty": "MEDIUM",
    "estimatedTimeSeconds": 60,
    "options": [
      { "id": "A", "text": "220 meters" },
      { "id": "B", "text": "240 meters" },
      { "id": "C", "text": "250 meters" },
      { "id": "D", "text": "300 meters" }
    ],
    "correctAnswer": "B",
    "hints": [
      "Convert speed from km/h to m/s by multiplying by 5/18.",
      "The extra 16 seconds were used solely to cover the platform length."
    ],
    "pyq": "SSC CGL (2020), IBPS PO (2018)",
    "method": "Speed = 15 m/s; Distance = Speed * Delta Time",
    "explanation": "Speed = 54 * (5/18) = 15 m/s. Train length = 15 * 20 = 300m. Total distance in 36s = 15 * 36 = 540m. Platform length = 540 - 300 = 240m.",
    "alternativeExplanation": "Difference in time to cross platform vs. pole = 36 - 20 = 16 seconds. Length of platform = Speed * Delta Time = 15 m/s * 16 s = 240 meters.",
    "preferredSolution": "ALTERNATIVE",
    "preferredReason": "Isolating the delta time avoids calculating the train's length entirely, reducing calculation steps from 4 to 1.",
    "sourceType": "MANUAL",
    "status": "REVIEW_REQUIRED",
    "provenance": {
      "bookTitle": "Quantitative Aptitude for Competitive Examinations",
      "edition": "2024",
      "chapter": "Time and Distance",
      "pageRange": "p. 418"
    }
  }
]
\`\`\`
`.trim();

export const DEFAULT_PROMPT_DEFINITIONS: Record<string, PromptDefinition> = {
  PVP_GENERATION: {
    key: 'PVP_GENERATION',
    title: 'PvP Arena Question Generator',
    category: 'SERVER_GENERATION',
    description: 'System instruction used by server to generate 10-question high-tempo 1v1 PvP sets.',
    defaultPrompt: PVP_GENERATION_SYSTEM_INSTRUCTION,
    variables: [
      { name: 'topicName', description: 'Curriculum topic name for the match' },
      { name: 'subtopics', description: 'List of live subtopics to cover' },
      { name: 'difficultyDistribution', description: 'Requested EASY/MEDIUM/HARD count' },
    ],
  },
  PVP_REVIEW: {
    key: 'PVP_REVIEW',
    title: 'PvP Integrity Auditor',
    category: 'SERVER_REVIEW',
    description: 'System instruction used by server to audit, verify mathematical truth, and enforce time fairness on PvP sets.',
    defaultPrompt: PVP_REVIEW_SYSTEM_INSTRUCTION,
    variables: [
      { name: 'questions', description: '10 raw generated questions to audit' },
    ],
  },
  PRACTICE_GENERATION: {
    key: 'PRACTICE_GENERATION',
    title: 'Practice Question Generator',
    category: 'SERVER_GENERATION',
    description: 'System instruction used by server to generate adaptive practice questions for learners.',
    defaultPrompt: PRACTICE_GENERATION_SYSTEM_INSTRUCTION,
    variables: [
      { name: 'subject', description: 'Subject domain' },
      { name: 'topic', description: 'Topic name' },
      { name: 'subtopic', description: 'Subtopic name and target pattern' },
      { name: 'difficultyCount', description: 'Distribution of EASY, MEDIUM, and HARD' },
    ],
  },
  PRACTICE_REVIEW: {
    key: 'PRACTICE_REVIEW',
    title: 'Practice Mathematical Auditor',
    category: 'SERVER_REVIEW',
    description: 'System instruction used by server to verify practice question mathematical correctness and distractors.',
    defaultPrompt: PRACTICE_REVIEW_SYSTEM_INSTRUCTION,
    variables: [
      { name: 'batch', description: 'Batch of candidate practice questions' },
    ],
  },
  DAILY_CHALLENGE_GENERATION: {
    key: 'DAILY_CHALLENGE_GENERATION',
    title: 'Daily Challenge Question Generator',
    category: 'SERVER_GENERATION',
    description: 'System instruction for crafting high-impact daily streak challenge questions.',
    defaultPrompt: DAILY_CHALLENGE_GENERATION_SYSTEM_INSTRUCTION,
    variables: [
      { name: 'tier', description: 'Streak tier (1, 2, or 3)' },
      { name: 'topic', description: 'Daily challenge target topic' },
    ],
  },
  BOOK_EXTRACT_AND_SYNTHESIS: {
    key: 'BOOK_EXTRACT_AND_SYNTHESIS',
    title: 'Textbook OCR & PYQ Synthesis Prompt (Manual Tool)',
    category: 'MANUAL_REFERENCE',
    description: 'Manual reference prompt to copy and paste into Gemini/ChatGPT alongside book OCR scans and PYQs to generate AptiQu lesson scripts and question banks.',
    defaultPrompt: BOOK_CURRICULUM_SYNTHESIS_PROMPT,
    variables: [
      { name: 'referenceMaterial', description: 'Scanned pages or OCR text from textbook chapter' },
      { name: 'questionPool', description: 'Raw collection of PYQs and practice problems' },
    ],
  },
};

export class AiPromptService {
  private static instance: AiPromptService;
  // In-memory cache for ultra-fast, zero-restart prompt access
  private publishedPromptCache: Map<string, string> = new Map();
  private isInitialized = false;

  public static getInstance(): AiPromptService {
    if (!AiPromptService.instance) {
      AiPromptService.instance = new AiPromptService();
    }
    return AiPromptService.instance;
  }

  /**
   * Ensure default prompts exist in the database and pre-warm memory cache.
   */
  public async ensureInitialized(): Promise<void> {
    if (this.isInitialized) return;

    try {
      for (const [key, def] of Object.entries(DEFAULT_PROMPT_DEFINITIONS)) {
        const existing = await prisma.aiPrompt.findUnique({
          where: { key },
        });

        if (!existing) {
          const created = await prisma.aiPrompt.create({
            data: {
              key: def.key,
              title: def.title,
              category: def.category,
              description: def.description,
              draftPrompt: def.defaultPrompt,
              publishedPrompt: def.defaultPrompt,
              variables: def.variables as any,
              version: 1,
              isLive: true,
              lastPublishedAt: new Date(),
            },
          });
          this.publishedPromptCache.set(key, created.publishedPrompt);
        } else {
          this.publishedPromptCache.set(key, existing.publishedPrompt);
        }
      }
      this.isInitialized = true;
    } catch (err) {
      console.error('[AiPromptService] Failed to initialize default prompts:', err);
    }
  }

  /**
   * Retrieves the LIVE published prompt for server execution.
   * Reads from memory cache with DB fallback. Immediate live effect without server restart!
   */
  public async getPublishedPrompt(key: string, fallback?: string): Promise<string> {
    if (!this.isInitialized) {
      await this.ensureInitialized();
    }

    const cached = this.publishedPromptCache.get(key);
    if (cached) {
      return cached;
    }

    // Cache miss: check DB
    try {
      const record = await prisma.aiPrompt.findUnique({
        where: { key },
      });

      if (record && record.publishedPrompt) {
        this.publishedPromptCache.set(key, record.publishedPrompt);
        return record.publishedPrompt;
      }
    } catch (err) {
      console.warn(`[AiPromptService] DB read error for prompt key "${key}":`, err);
    }

    // Default fallback
    const def = DEFAULT_PROMPT_DEFINITIONS[key];
    const resolved = def ? def.defaultPrompt : (fallback || '');
    if (resolved) {
      this.publishedPromptCache.set(key, resolved);
    }
    return resolved;
  }

  /**
   * Synchronous getter for when caller already ensured initialization
   */
  public getPublishedPromptSync(key: string, fallback?: string): string {
    const cached = this.publishedPromptCache.get(key);
    if (cached) return cached;
    const def = DEFAULT_PROMPT_DEFINITIONS[key];
    return def ? def.defaultPrompt : (fallback || '');
  }

  /**
   * List all prompts for the Admin Dashboard.
   */
  public async listPrompts(): Promise<any[]> {
    await this.ensureInitialized();
    const prompts = await prisma.aiPrompt.findMany({
      orderBy: [
        { category: 'asc' },
        { createdAt: 'asc' },
      ],
    });

    return prompts.map((p) => ({
      ...p,
      hasUnpublishedChanges: p.draftPrompt !== p.publishedPrompt,
    }));
  }

  /**
   * Get a single prompt by key.
   */
  public async getPrompt(key: string): Promise<any> {
    await this.ensureInitialized();
    const prompt = await prisma.aiPrompt.findUnique({
      where: { key },
    });
    if (!prompt) return null;

    return {
      ...prompt,
      hasUnpublishedChanges: prompt.draftPrompt !== prompt.publishedPrompt,
    };
  }

  /**
   * Save a draft prompt (does NOT update live server prompt).
   */
  public async saveDraft(key: string, draftPrompt: string): Promise<any> {
    await this.ensureInitialized();
    const updated = await prisma.aiPrompt.update({
      where: { key },
      data: {
        draftPrompt,
      },
    });

    return {
      ...updated,
      hasUnpublishedChanges: updated.draftPrompt !== updated.publishedPrompt,
    };
  }

  /**
   * Publish the draft prompt (immediately updates live server prompt without restarting).
   */
  public async publishPrompt(key: string): Promise<any> {
    await this.ensureInitialized();
    const current = await prisma.aiPrompt.findUnique({
      where: { key },
    });

    if (!current) {
      throw new Error(`Prompt with key "${key}" not found.`);
    }

    const updated = await prisma.aiPrompt.update({
      where: { key },
      data: {
        publishedPrompt: current.draftPrompt,
        version: { increment: 1 },
        lastPublishedAt: new Date(),
      },
    });

    // CRITICAL: Immediately update memory cache so live server calls use the new prompt instantly
    this.publishedPromptCache.set(key, updated.publishedPrompt);

    console.log(`[AiPromptService] Prompt "${key}" PUBLISHED to version ${updated.version}. Memory cache refreshed.`);

    return {
      ...updated,
      hasUnpublishedChanges: false,
    };
  }

  /**
   * Reset prompt draft back to default implementation.
   */
  public async resetToDefault(key: string): Promise<any> {
    await this.ensureInitialized();
    const def = DEFAULT_PROMPT_DEFINITIONS[key];
    if (!def) {
      throw new Error(`Default definition for key "${key}" not found.`);
    }

    const updated = await prisma.aiPrompt.update({
      where: { key },
      data: {
        draftPrompt: def.defaultPrompt,
      },
    });

    return {
      ...updated,
      hasUnpublishedChanges: updated.draftPrompt !== updated.publishedPrompt,
    };
  }
}

export const aiPromptService = AiPromptService.getInstance();
