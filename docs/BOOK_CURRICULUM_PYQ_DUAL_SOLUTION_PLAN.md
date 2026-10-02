# Comprehensive Architecture & Implementation Plan: Book-Sourced Curriculum, PYQ Engine & Dual-Solution System

---

## 1. Executive Summary & Core Architectural Invariants

This plan outlines the end-to-end transformation of AptiQu from synthetic AI content generation to an **authoritative, book-referenced curriculum (RS Aggarwal, Arihant, etc.) and real exam PYQ engine**.

### 1.1. Core Architectural Pillars
1. **Curriculum Hierarchy**: Subject (Book / Discipline) $\rightarrow$ Topic (Chapter) $\rightarrow$ Subtopics (Concept Modules in optimal pedagogical sequence).
2. **Three-Dimensional Provenance Model**: Explicit separation between **Origin** (Book/Edition/Chapter/Page), **Creation Method** (`HUMAN_MANUAL` vs `AI_EXTRACTED` vs `AI_SYNTHETIC`), and **Lifecycle Status** (`DRAFT` $\rightarrow$ `REVIEW_REQUIRED` $\rightarrow$ `PUBLISHED`).
3. **Single Source of Truth for Questions**: Questions exist once in the question repository with a stable `externalKey` (e.g. `tsd-q-001`). Lesson scripts reference questions via `questionReference.externalId`, eliminating duplicated question payloads and data drift.
4. **Deterministic Subtopic Ingestion**: Every subtopic has an immutable `externalSubtopicKey`. Bulk question import performs strict, batched exact-key lookups. **No fuzzy name guessing, no silent fallbacks to a default subtopic.**
5. **Strict Exam PYQ Integrity**: PYQ attribution (`"exam_name (year), exam_name (year)"`) is populated **only** when explicitly present in the source material. No model memory recall, guessing, or hallucinations.
6. **Value-Add Dual Solutions (Optional, Not Forced)**: Solution 1 (Book Method) is always required. Solution 2 (Alternative Shortcut) is included **only** when a genuinely distinct, reliable shortcut exists and produces the identical answer.
7. **Explicit Schema & Metadata Contract**: Complete audit and alignment of fields (`questionType`, `inputType`, `method`, `calculationMode`, `xp`) across Prisma, DTOs, lesson DSL, and Flutter UI.

### 1.2. Key System Invariants
- **Practice Invariant**: An AI-generated question must **NEVER** appear for a topic while an eligible, unsolved `MANUAL` question exists for the user in that topic.
- **PvP Matchmaking Invariant**: PvP uses the current isolated AI-generated question sets. If manual questions are utilized, they must be unattempted by **both** paired players; otherwise, PvP serves dedicated AI-generated sets.
- **Daily Streak Invariants**:
  - Daily challenge questions must strictly be `sourceType: 'MANUAL'`, `status: 'PUBLISHED'`, and have a valid non-empty `pyq` tag.
  - A question may appear in a Daily Challenge **only once in history** (enforced at both query and database levels via `@@unique([questionId])`).
  - Calendar boundaries are strictly anchored to **`Asia/Kolkata` (IST, UTC+05:30)**.
  - If the eligible pool is depleted, challenge creation is **halted** and a documented admin alert is triggered; synthetic questions are never substituted.
- **Script Validation Invariant**: A lesson script import must fail if any referenced `externalId` does not exist, belongs to a different subtopic, or belongs to a different topic.

---

## 2. Existing Schema Audit & Field Contract Mapping

Before defining prompt schemas and database migrations, we audit the existing Question model and DTO contracts to eliminate mismatches:

| Field | Current Prisma Model | Prompt / Ingestion JSON | Handling & Persistence Architecture |
|---|---|---|---|
| `questionType` | `String @default("MCQ")` | `"questionType": "MCQ"` | Represents question format (`"MCQ"`). Preserved as-is. |
| `inputType` | *Not stored on Question* | `"inputType": "SINGLE_SELECT"` | Governs the interactive interaction in Lesson Scripts (`InputType`: `'CHOICE' \| 'TEXT' \| 'NONE'`). In standalone Question table, all questions are multiple-choice options. Documented as client-side rendering hint; optionally persisted as `inputType String @default("SINGLE_SELECT")` if needed. |
| `method` | `String` (Required in DB) | `"method": "Speed = Distance / Delta Time"` | Core formula / shortcut descriptor. **Required in both JSON prompt and database**. |
| `calculationMode` | `CalculationMode` Enum | `"calculationMode": "MENTAL"` | Enum: `MENTAL`, `LIGHT_PEN_AND_PAPER`, `PEN_AND_PAPER`. |
| `difficulty` | `QuestionDifficultyEnum` | `"difficulty": "MEDIUM"` | Enum: `EASY`, `MEDIUM`, `HARD`. |
| `estimatedTimeSeconds` | `Int @default(60)` | `"estimatedTimeSeconds": 60` | Target time budget in seconds. |
| `xp` | *Dynamically Computed* | `"xp": 15` (or derived) | **Not a raw database column**. In AptiQu, XP is computed deterministically via `XpPolicy.calculateQuestionXp(questionType, difficulty)`: `Type XP (Practice: 5, Ranked: 10)` + `Difficulty XP (Easy: 5, Med: 10, Hard: 15)`. The prompt may output XP as a reference, but persistence always relies on `XpPolicy`. |
| `preferredSolution` | *New Column* | `"preferredSolution": "ALTERNATIVE"` | Typed PostgreSQL Enum: `BOOK` or `ALTERNATIVE` (Null if no alternative). |
| `preferredReason` | *New Column* | `"preferredReason": "..."` | Structural explanation of why the preferred method wins (fewer steps, eliminates variables). |
| `externalKey` | *New Column* | `"externalQuestionKey": "tsd-q-001"` | Unique slug/key used by scripts to reference the question without duplicating payloads. |

---

## 3. Reusable LLM Prompt Template (ChatGPT / Gemini / Claude)

This prompt is **model-agnostic** (no hardcoded model versions). Paste this template alongside digital book page scans / OCR text and question pools.

```markdown
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
   - Assign each subtopic an immutable `externalSubtopicKey` (e.g., "tsd-01-relative-speed").

4. SCRIPT & QUESTION RELATIONSHIP (NO DUPLICATION):
   - Do NOT duplicate complete question payloads (prompts, options, answers) inside the Lesson Script.
   - Assign each question an `externalQuestionKey` (e.g., "tsd-q-001").
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
Output your complete response in two clearly demarcated JSON blocks.

### BLOCK 1: SUBTOPICS & LESSON SCRIPTS
```json
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
```

### BLOCK 2: QUESTION BANK ARRAY (FOR BULK IMPORT)
```json
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
```
```

---

## 4. Database Schema & Provenance Architecture (`schema.prisma`)

### 4.1. Enums and Extended `Question` Model
```prisma
enum QuestionGenerationMethod {
  HUMAN_MANUAL
  AI_EXTRACTED
  AI_SYNTHETIC

  @@schema("learning")
}

enum PreferredSolution {
  BOOK
  ALTERNATIVE

  @@schema("learning")
}

model Question {
  id                     String                   @id @default(uuid()) @db.Uuid
  subjectId              String                   @map("subject_id")
  topicId                String                   @map("topic_id")
  subtopicId             String                   @map("subtopic_id")
  conceptId              String?                  @map("concept_id") @db.Uuid
  pattern                String?
  prompt                 String
  questionType           String                   @default("MCQ") @map("question_type")
  options                Json                     @db.JsonB
  correctAnswer          String                   @map("correct_answer")
  hints                  Json                     @default("[]") @db.JsonB
  explanation            String                   // Solution 1: Primary / Book Method
  method                 String                   // Core formula / shortcut tag
  difficulty             QuestionDifficultyEnum   @default(EASY)
  estimatedTimeSeconds   Int                      @default(60) @map("estimated_time_seconds")
  calculationMode        CalculationMode          @default(MENTAL) @map("calculation_mode")
  
  sourceType             QuestionSourceType       @default(MANUAL) @map("source_type")
  status                 QuestionStatus           @default(REVIEW_REQUIRED)
  fingerprint            String                   @unique

  // External Key for Ingestion & Script Referencing
  externalKey            String?                  @unique @map("external_key")

  // Provenance Dimensions
  generationMethod       QuestionGenerationMethod @default(AI_EXTRACTED) @map("generation_method")
  sourceBook             String?                  @map("source_book")
  sourceEdition          String?                  @map("source_edition")
  sourceChapter          String?                  @map("source_chapter")
  sourcePageRange        String?                  @map("source_page_range")

  // PYQ Metadata (Null if non-PYQ)
  pyq                    String?                  // e.g. "TCS NQT (2023), CAT (2012)"

  // Dual-Solution Framework (Null if no valid alternative exists)
  alternativeExplanation String?                  @map("alternative_explanation")
  preferredSolution      PreferredSolution?       @map("preferred_solution")
  preferredReason        String?                  @map("preferred_reason")

  generationModel        String?                  @map("generation_model")
  generationPromptVersion String?                 @map("generation_prompt_version")
  generationJobId        String?                  @map("generation_job_id")
  generatedAt            DateTime?                @map("generated_at")
  reviewedAt             DateTime?                @map("reviewed_at")

  createdAt              DateTime                 @default(now()) @map("created_at")
  updatedAt              DateTime                 @updatedAt @map("updated_at")

  // Relations
  subject                Subject                  @relation(fields: [subjectId], references: [id], onDelete: Restrict)
  topic                  Topic                    @relation(fields: [topicId], references: [id], onDelete: Restrict)
  subtopic               Subtopic                 @relation(fields: [subtopicId], references: [id], onDelete: Restrict)
  concept                Concept?                 @relation(fields: [conceptId], references: [id], onDelete: SetNull)
  
  attempts               QuestionAttempt[]
  practiceSessionQuestions PracticeSessionQuestion[]
  userProgress           UserQuestionProgress[]
  pvpSetQuestions        PvpQuestionSetQuestion[]
  pvpMatchAnswers        PvpMatchAnswer[]
  dailyChallengeScriptQuestions DailyChallengeScriptQuestion[]
  dailyChallengeAnswers         DailyChallengeAnswer[]

  @@index([subtopicId, sourceType, status, difficulty])
  @@index([topicId, sourceType, status])
  @@index([sourceType, status, pyq])
  @@index([pyq])
  @@map("questions")
  @@schema("learning")
}
```

### 4.2. Daily Challenge Database-Level Uniqueness Guarantee
```prisma
model DailyChallengeScriptQuestion {
  id         String                 @id @default(uuid()) @db.Uuid
  scriptId   String                 @map("script_id") @db.Uuid
  questionId String                 @map("question_id") @db.Uuid
  sequence   Int                    // 1, 2, 3...
  difficulty QuestionDifficultyEnum
  timeLimit  Int                    @default(60) @map("time_limit")

  script   DailyChallengeScript     @relation(fields: [scriptId], references: [id], onDelete: Cascade)
  question Question                 @relation(fields: [questionId], references: [id], onDelete: Restrict)

  // Enforces that a question can be used in Daily Challenge ONLY ONCE EVER across all history
  @@unique([questionId])
  @@unique([scriptId, sequence])
  @@map("daily_challenge_script_questions")
  @@schema("learning")
}
```

---

## 5. Scalable Practice Mode & PvP Selection Engines

### 5.1. Database-Level Scalable Practice Selection (`practice-selection.service.ts`)
Instead of fetching all progress IDs into application memory, PostgreSQL performs the filtering via relational indexes and bounded limits:

```typescript
export class PracticeSelectionService {
  /**
   * Scalable, indexed query for Practice questions enforcing the strict Manual Invariant.
   * INVARIANT: No AI question may appear while an eligible unsolved MANUAL question exists for the topic.
   */
  public static async selectQuestionsForPractice(
    userId: string,
    topicId: string,
    subtopicIds: string[],
    count: number = 10
  ): Promise<Question[]> {
    // STEP 1: Query bounded unsolved MANUAL questions directly in PostgreSQL
    // Unsolved = user has never answered correctly (userProgress.none with timesCorrect > 0)
    const unsolvedManual = await prisma.question.findMany({
      where: {
        topicId,
        subtopicId: { in: subtopicIds },
        sourceType: 'MANUAL',
        status: 'PUBLISHED',
        userProgress: {
          none: {
            userId,
            timesCorrect: { gt: 0 },
          },
        },
      },
      take: count,
      orderBy: [
        // Prioritize previously failed questions over never seen
        { attempts: { _count: 'desc' } },
        { createdAt: 'asc' },
      ],
    });

    // STEP 2: If at least one unsolved manual question exists, serve ONLY manual questions!
    if (unsolvedManual.length > 0) {
      if (unsolvedManual.length >= count) {
        return unsolvedManual;
      }

      // Reinforcement fill: If unsolved manual count < session count, fill remaining slots
      // with previously solved MANUAL questions from the same topic (Zero AI questions)
      const needed = count - unsolvedManual.length;
      const reinforcementManual = await prisma.question.findMany({
        where: {
          topicId,
          subtopicId: { in: subtopicIds },
          sourceType: 'MANUAL',
          status: 'PUBLISHED',
          id: { notIn: unsolvedManual.map((q) => q.id) },
        },
        take: needed,
        orderBy: { updatedAt: 'asc' }, // least recently reinforced
      });

      return [...unsolvedManual, ...reinforcementManual];
    }

    // STEP 3: Verify if ANY manual questions exist in this topic
    const totalManualCount = await prisma.question.count({
      where: {
        topicId,
        sourceType: 'MANUAL',
        status: 'PUBLISHED',
      },
    });

    // If manual questions exist and user has solved 100% of them correctly:
    // AI_GENERATED questions now become eligible from the published pool
    const aiCandidates = await prisma.question.findMany({
      where: {
        topicId,
        subtopicId: { in: subtopicIds },
        sourceType: 'AI_GENERATED',
        status: 'PUBLISHED',
        userProgress: {
          none: {
            userId,
            timesCorrect: { gt: 0 },
          },
        },
      },
      take: count,
      orderBy: { createdAt: 'desc' },
    });

    if (aiCandidates.length >= count || totalManualCount > 0) {
      return aiCandidates;
    }

    // STEP 4: Fallback to on-demand generation only if pool is completely exhausted
    return await questionGenerationService.generateQuestionsForSubtopic(subtopicIds[0], count);
  }
}
```

### 5.2. PvP Matchmaking Question Selection Rule
In Live PvP, two players often possess disparate progress states:
1. **Isolated High-Speed AI Engine**: PvP matchmaking retains the current isolated 10-question set engine.
2. **Manual Question Policy for PvP**: Manual questions are drawn into a PvP set **only if they are completely unattempted by BOTH Player 1 and Player 2**.
3. If no common unattempted manual questions exist across the required difficulty spread, the match serves a fresh, unique AI-generated PvP set.

---

## 6. Scalable Daily Streak Challenge Pipeline (`daily-challenge-generation.service.ts`)

### 6.1. Database-Determined Eligibility with Bounded Candidate Queries
To scale without memory bloat, PostgreSQL determines eligibility directly using the relation filter `dailyChallengeScriptQuestions: { none: {} }`:

```typescript
export class DailyChallengeGenerationService {
  /**
   * Generates or selects today's Daily Streak Challenge.
   * Bound to Asia/Kolkata (IST).
   */
  public static async generateDailyChallengeForDate(dateString: string, tier: number): Promise<any> {
    // 1. Target difficulties by tier
    const targetDifficulties: QuestionDifficultyEnum[] =
      tier === 1 ? ['EASY'] : tier === 2 ? ['EASY', 'MEDIUM'] : ['EASY', 'MEDIUM', 'HARD'];

    // 2. Fetch bounded eligible candidates per difficulty directly in PostgreSQL
    // Database determines: MANUAL + PUBLISHED + PYQ present + NEVER used in any DailyChallenge
    const selectedQuestions: Question[] = [];

    for (const diff of targetDifficulties) {
      const candidates = await prisma.question.findMany({
        where: {
          sourceType: 'MANUAL',
          status: 'PUBLISHED',
          pyq: { not: null },
          difficulty: diff,
          id: { notIn: selectedQuestions.map((q) => q.id) },
          dailyChallengeScriptQuestions: {
            none: {}, // Enforced by PostgreSQL relation index
          },
        },
        take: 25, // Bounded candidate pool (constant memory footprint)
        select: {
          id: true,
          difficulty: true,
          prompt: true,
          pyq: true,
          options: true,
          correctAnswer: true,
          explanation: true,
          method: true,
          estimatedTimeSeconds: true,
        },
      });

      if (candidates.length === 0) {
        console.error(
          `[DailyChallenge] INVENTORY DEPLETED: Zero unused MANUAL PYQs for difficulty ${diff} on ${dateString} (Tier ${tier}).`
        );
        // TODO: Surface inventory depletion alert in Admin Dashboard Daily Challenge tab
        // and prevent corrupted or synthetic daily challenge generation.
        throw new Error(
          `Daily Challenge creation halted: Manual PYQ inventory depleted for difficulty ${diff}.`
        );
      }

      // Deterministic pseudo-random pick from the bounded 25-candidate pool using date hash
      const dateHash = Math.abs(
        dateString.split('-').reduce((acc, part) => acc * 31 + parseInt(part, 10), 0)
      );
      const chosen = candidates[dateHash % candidates.length];
      selectedQuestions.push(chosen as any);
    }

    // 3. Persist in transaction with unique constraint protection
    return await prisma.$transaction(async (tx) => {
      const script = await tx.dailyChallengeScript.create({
        data: {
          dateString,
          tier,
          questionCount: selectedQuestions.length,
        },
      });

      for (let i = 0; i < selectedQuestions.length; i++) {
        await tx.dailyChallengeScriptQuestion.create({
          data: {
            scriptId: script.id,
            questionId: selectedQuestions[i].id,
            sequence: i + 1,
            difficulty: selectedQuestions[i].difficulty,
            timeLimit: selectedQuestions[i].estimatedTimeSeconds || 60,
          },
        });
      }

      return script;
    });
  }
}
```

---

## 7. Script & Question Ingestion Pipelines

### 7.1. Script Import Verification Pipeline (`POST /api/v1/admin/syllabus/scripts/import`)
A script import must fail and block persistence if any referenced question fails existence, subtopic ownership, or topic ownership checks:

```typescript
export class AdminScriptImportService {
  public static async importScript(payload: {
    subjectId: string;
    topicId: string;
    externalSubtopicKey: string;
    definition: ScriptDefinition;
    status?: 'DRAFT' | 'REVIEW_REQUIRED' | 'PUBLISHED';
  }) {
    // 1. Resolve subtopic by externalSubtopicKey
    const subtopic = await prisma.subtopic.findFirst({
      where: { slug: payload.externalSubtopicKey, topicId: payload.topicId },
      include: { topic: true },
    });

    if (!subtopic) {
      throw new Error(
        `Target subtopic with external key '${payload.externalSubtopicKey}' does not exist under topic '${payload.topicId}'.`
      );
    }

    // 2. Validate Script DSL Structure
    const validation = ScriptValidator.validate(payload.definition);
    if (!validation.valid) {
      throw new Error(`Script DSL validation failed: ${validation.errors.map(e => e.message).join('; ')}`);
    }

    // 3. STRICT QUESTION REFERENCE VERIFICATION
    // Collect all QUESTION_EXTERNAL_ID references in the script
    const referencedQuestionKeys: string[] = [];
    for (const node of Object.values(payload.definition.nodes)) {
      if (node.type === 'QUESTION' && node.questionReference?.mode === 'QUESTION_EXTERNAL_ID') {
        const extId = node.questionReference.externalId;
        if (!extId) {
          throw new Error(`Node '${node.id}' specifies QUESTION_EXTERNAL_ID but externalId is missing.`);
        }
        referencedQuestionKeys.push(extId);
      }
    }

    if (referencedQuestionKeys.length > 0) {
      // Single batched query to verify question existence and ownership
      const existingQuestions = await prisma.question.findMany({
        where: { externalKey: { in: referencedQuestionKeys } },
        select: { id: true, externalKey: true, topicId: true, subtopicId: true },
      });

      const questionMap = new Map(existingQuestions.map((q) => [q.externalKey!, q]));

      for (const key of referencedQuestionKeys) {
        const q = questionMap.get(key);
        // Check 1: Existence
        if (!q) {
          throw new Error(`❌ SCRIPT IMPORT FAILED: Question reference '${key}' does not exist in the question repository.`);
        }
        // Check 2: Topic Ownership
        if (q.topicId !== payload.topicId) {
          throw new Error(
            `❌ SCRIPT IMPORT FAILED: Question '${key}' belongs to topic '${q.topicId}', but this script is for topic '${payload.topicId}'.`
          );
        }
        // Check 3: Subtopic Ownership
        if (q.subtopicId !== subtopic.id) {
          throw new Error(
            `❌ SCRIPT IMPORT FAILED: Question '${key}' belongs to subtopic '${q.subtopicId}', while this script is for subtopic '${subtopic.id}' (${payload.externalSubtopicKey}).`
          );
        }
      }
    }

    // 4. Persistence in transaction
    const status = payload.status || 'REVIEW_REQUIRED';
    const checksum = crypto.createHash('sha256').update(JSON.stringify(payload.definition)).digest('hex');

    return prisma.$transaction(async (tx) => {
      let script = await tx.lessonScript.findUnique({
        where: { slug: payload.definition.scriptId },
      });

      if (!script) {
        script = await tx.lessonScript.create({
          data: {
            slug: payload.definition.scriptId,
            title: payload.definition.metadata.title,
            subjectId: payload.subjectId,
            topicId: payload.topicId,
            subtopicId: subtopic.id,
            status: status as any,
          },
        });
      }

      const version = await tx.lessonScriptVersion.create({
        data: {
          scriptId: script.id,
          versionNumber: 1,
          definition: payload.definition as any,
          checksum,
          status: status as any,
          publishedAt: status === 'PUBLISHED' ? new Date() : null,
        },
      });

      if (status === 'PUBLISHED') {
        await tx.lessonScript.update({
          where: { id: script.id },
          data: { publishedVersionId: version.id },
        });
      }

      return { script, version };
    });
  }
}
```

### 7.2. Bulk Question Ingestion with Batched Subtopic Resolution
In `admin-questions.service.ts`:
1. Extract distinct `externalSubtopicKey`s from question array.
2. Batched query: `prisma.subtopic.findMany({ where: { slug: { in: keys } }, include: { topic: true } })`.
3. If any key is missing from map: Reject import with 400 Bad Request and list missing keys.
4. Default status for all imported questions: `REVIEW_REQUIRED`.

---

## 8. Admin Dashboard Upgrades (`admin-dashboard`)

### 8.1. Question Management Table & Review Queue (`QuestionsPage.tsx`)
- **Review Queue Filter**: `Status: All | Review Required | Published | Draft`.
- **PYQ Badge**: Display amber/gold chip: `🏛️ TCS NQT (2023), CAT (2012)`.
- **Question Create / Edit Modal**:
  - `External Question Key`: e.g. `tsd-q-001` (unique).
  - `PYQ Details`: Text field with placeholder `"TCS NQT (2023), CAT (2012)"`.
  - `Method / Formula`: Required text field (e.g. `Speed = Distance / Delta Time`).
  - `Solution 1 (Book Method)`: Step-by-step mathematical explanation.
  - `Solution 2 (Alternative Shortcut)`: Optional secondary shortcut explanation.
  - `Preferred Approach`: Select dropdown (`None` | `BOOK` | `ALTERNATIVE`).
  - `Preferred Reason`: Text input explaining why this method saves calculation steps.
  - `Provenance Details`: Book title, edition, chapter, page range.

### 8.2. Script Ingestion Modal (`SyllabusPage.tsx`)
- Subtopic dropdown $\rightarrow$ `Import Lesson Script (JSON)`.
- Pre-import validation preview: checks referenced question keys against live database before enabling the "Save / Publish" button.

### 8.3. Future Roadmap: Daily Challenge Tab
- Tracks metrics (`DailyChallengeParticipation` & `DailyChallengeAnswer` telemetry).
- Live inspection & inline edit of today's challenge.
- Tomorrow's Challenge selector with automated/manual pick and `Previously Used in Daily Streak` badge.

---

## 9. Flutter Mobile App Architecture & UI

### 9.1. Model Updates
- Update `PracticeQuestionModel`, `QuestionInlineModel`, and `DailyChallengeQuestionModel`:
  ```dart
  final String? pyq;
  final String? alternativeExplanation;
  final String? preferredSolution; // 'BOOK' | 'ALTERNATIVE'
  final String? preferredReason;
  ```

### 9.2. UI Enhancements
- **Conditionally Rendered PYQ Badge**: Under prompt card in Practice, Daily Challenge, PvP, and Lesson Scripts.
- **Dual-Solution Post-Answer Card**:
  - If `alternativeExplanation == null`: Render standard explanation card without tabs.
  - If `alternativeExplanation != null`: Render segmented tabs:
    `[ Method 1: Book Method ]   [ Method 2: Speed Shortcut ⭐ ]`
  - Display "⭐ AI Preferred Approach" badge on the preferred tab with an `(i)` info icon opening a bottom sheet with `preferredReason`.

---

## 10. Comprehensive Verification & Automated Testing Plan

### 10.1. Automated Unit & Integration Tests (Test Suite Matrix)
File: `backend/src/modules/practice/tests/practice-curriculum-invariants.test.ts`

| # | Test Scenario | Expected Assertion |
|---|---|---|
| **T-01** | User has 10 unattempted MANUAL questions in topic | Practice session contains 100% MANUAL questions; zero AI calls triggered. |
| **T-02** | User has 5 failed MANUAL questions, 5 unseen MANUAL | Practice session contains 5 failed + 5 unseen MANUAL questions. |
| **T-03** | User has solved 100% of MANUAL questions correctly | `AI_GENERATED` questions become eligible for practice. |
| **T-04** | Daily challenge generator with valid Manual PYQ pool | Daily challenge successfully generated; all questions have non-null `pyq` and `sourceType: MANUAL`. |
| **T-05** | Question already in `DailyChallengeScriptQuestion` | Excluded from candidate pool; attempting duplicate insertion throws DB unique constraint error. |
| **T-06** | Manual PYQ pool has 0 unappeared questions | Generator throws descriptive depletion error; does NOT generate AI fallback questions. |
| **T-07** | Bulk import with invalid `externalSubtopicKey` | Import rejected; returns error `Unknown subtopic key: xyz`; 0 questions written. |
| **T-08** | Script import with non-existent `externalId` | Import rejected: `Question reference 'xyz' does not exist`. |
| **T-09** | Script import with cross-subtopic `externalId` | Import rejected: `Question belongs to subtopic A, while script is for subtopic B`. |
| **T-10** | Mobile question with `alternativeExplanation == null` | Flutter widget renders single explanation without tabs or alternative badge. |
| **T-11** | Mobile question with valid `pyq` | Flutter widget renders PYQ badge with exact formatted text. |

### 10.2. Static Analysis & Compilation Commands
```bash
# 1. Backend
cd backend
npx prisma validate
npx prisma generate
npx tsc --noEmit
npm run build
npm test

# 2. Admin Dashboard
cd ../admin-dashboard
npm run build

# 3. Flutter Mobile App
cd ..
flutter analyze
flutter test
flutter build apk --debug
```

---

## 11. Production VPS Deployment Runbook

Follow this exact non-breaking deployment sequence on the live AptiQu VPS:

```bash
# 1. SSH into VPS and navigate to project root
ssh deploy@aptiqu-vps
cd /var/www/aptiqu

# 2. Create timestamped database backup before migration
pg_dump -U aptiqu_user -d aptiqu_prod -F c -b -v -f "/var/backups/aptiqu_pre_curriculum_$(date +%Y%m%d_%H%M%S).dump"

# 3. Pull verified git release
git pull origin main

# 4. Backend Deployment
cd backend
npm ci --production=false
npx prisma migrate deploy
npm run build
pm2 reload aptiqu-backend --update-env

# 5. Admin Dashboard Deployment
cd ../admin-dashboard
npm ci
npm run build
# Sync build files to Nginx web root
rsync -av --delete dist/ /var/www/html/admin/

# 6. Verify System Health
curl -f http://localhost:4000/api/v1/health || echo "❌ Backend Health Check Failed!"
pm2 status
```
