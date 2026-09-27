# Architectural Implementation Plan: Practice Mode, Ranked PvP & Gemini AI Pipeline

---

## Executive Summary & System Philosophy

This engineering plan details the architecture and implementation roadmap for **Practice Mode**, **Ranked PvP Mode**, and the **Gemini 3.5 Flash-Lite dynamic question generation and validation pipeline** in Aptiqu.

### Architectural Tenets
1. **PostgreSQL as Sole Durable Truth**: All questions, options, practice attempts, match states, user scores, and XP allocations are recorded durably in PostgreSQL with strict ACID transactional semantics and foreign key constraints across the `learning`, `gamification`, `auth`, and `users` schemas.
2. **Deterministic Authoritative Backend**: The client (Flutter) is purely a presentation device. Client timers, client score calculations, and client answer evaluations are strictly non-authoritative. The backend validates answers, manages countdowns, computes winners, and mints XP.
3. **AI as an Unprivileged Generator**: Gemini 3.5 Flash-Lite produces raw question drafts and semantic reviews. AI outputs are never directly trusted: backend application code validates structural conformance (4 options, 1 valid answer, non-empty fields, time limits, normalized fingerprints) before any question is committed to the database.
4. **Persistent Content Pooling & On-Demand Generation**: AI questions are generated on-demand when inventory shortages are detected, verified, stored in PostgreSQL, and pooled. Questions and PvP question sets are reused across users, avoiding redundant AI inference costs. Background replenishment queues are excluded from MVP.
5. **Strict Content Gate (Live Syllabus Only)**: Only topics and subtopics with active, published lesson scripts (`LessonScript.status = PUBLISHED` and `publishedVersionId != null` assigned via `ScriptAssignment`) are eligible for question generation, practice sessions, and PvP matches. Locked/future curriculum is rejected.
6. **Centralized XP Integration**: All XP minted by Practice and PvP is routed through `XpService.getInstance().awardXp` with the canonical `XpPolicy`, guaranteeing idempotency and level progression consistency. No shortcut XP exists for premature session exit.
7. **Development Phase Pragmatism**: The project is in active development. Database resets (`prisma migrate reset`) and fresh re-seeding are standard practice. No complex migration fallbacks or multi-step migration scripts are needed.

---

## PHASE 0 — Codebase Audit & Architectural Baseline

### 0.1 Backend State
- **Runtime**: Node.js 22 + TypeScript 5.8 + Express 4.21.
- **ORM & Database**: Prisma 6.4 with PostgreSQL multi-schema support (`auth`, `users`, `gamification`, `learning`).
- **Cache & Ephemeral Layer**: `ioredis` (wrapped in `RedisService` with in-memory fallback, supporting `get`, `set`, `setNx`, and `del`).
- **Curriculum & Roadmap**: Fully modeled (`Subject`, `Topic`, `Subtopic`, `Roadmap`, `RoadmapStep`, `ScriptAssignment`). Mathematical Foundations & Mental Calculation is currently live with 8 published script definitions.
- **Centralized XP Module**: `XpService` and `XpPolicy` with `XpPolicy.QUESTION_TYPE_XP` (`PRACTICE: 5`, `UNRANKED: 5`, `RANKED: 10`) and `XpPolicy.QUESTION_DIFFICULTY_XP` (`EASY: 5`, `MEDIUM: 10`, `HARD: 15`). Level progression formula $L = \lfloor\frac{1 + \sqrt{1 + 0.4 \times \text{totalXp}}}{2}\rfloor$ is established.
- **Existing Question Model**: `Question` in `learning` schema currently stores minimal fields (`conceptId`, `prompt`, `questionType`, `options`, `correctAnswer`, `explanation`, `difficulty`). It requires schema evolution.

### 0.2 Flutter State
- **Architecture & State Management**: GetX (`get: ^4.7.3`) with reactive controllers (`Obx`), GoRouter (`go_router: ^17.2.3`), and Dio (`dio: ^5.11.1`).
- **Navigation & Screens**: `home_screen.dart` has 4 bottom nav zones: Tab 0 (Conversational AI), Tab 1 (Topics), Tab 2 (Speed Practice placeholder), Tab 3 (Ranked Arena placeholder).
- **Existing Question Rendering**: `QuestionNodeWidget` provides styled option tiles, stopwatch tracking, and submission hooks.

### 0.3 Gaps to Address
1. The `learning.questions` table lacks taxonomy metadata (`subjectId`, `topicId`, `subtopicId`, `pattern`), lifecycle statuses, calculation mode, hint arrays, deduplication fingerprints, and AI provenance fields.
2. No tables exist for `PracticeSession`, `PracticeSessionQuestion`, `UserQuestionProgress`, `PvpQuestionSet`, `PvpMatch`, `PvpMatchPlayer`, `PvpMatchAnswer`, or `PvpPlayerSetHistory`.
3. Gemini SDK (`@google/genai`) is not installed.
4. WebSocket server (`ws`) is not installed on the backend; Flutter needs `web_socket_channel`.
5. Redis generation locking (`setNx`) must be wired to on-demand generation to prevent duplicate concurrent Gemini requests for the same shortage scope.

---

## PHASE 1 — Database Schema & Migrations

All models will be placed in the `learning` schema (with cross-schema foreign keys to `auth.users`).

```
                    ┌─────────────────────────┐
                    │      Subject (Live)     │
                    └────────────┬────────────┘
                                 │ 1:N
                    ┌────────────▼────────────┐
                    │       Topic (Live)      │
                    └────────────┬────────────┘
                                 │ 1:N
                    ┌────────────▼────────────┐
                    │     Subtopic (Live)     │
                    └────────────┬────────────┘
                                 │ 1:N
                    ┌────────────▼───────────────────────────────────┐
                    │               Question Pool                    │
                    │  - MANUAL / AI_GENERATED                       │
                    │  - DRAFT / REVIEW / PUBLISHED / ARCHIVED       │
                    │  - fingerprint (SHA-256 normalized text)       │
                    └───────┬────────────────────────────────┬───────┘
                            │                                │
            1:N (Session)   │                                │ 1:N (Set)
    ┌───────────────────────▼───────┐        ┌───────────────▼───────────────┐
    │     PracticeSessionQuestion   │        │     PvpQuestionSetQuestion    │
    └───────────────┬───────────────┘        └───────────────┬───────────────┘
                    │                                        │
    ┌───────────────▼───────────────┐        ┌───────────────▼───────────────┐
    │        PracticeSession        │        │        PvpQuestionSet         │
    │  - userId (FK User)           │        │  - 10 Questions               │
    │  - status, score, time        │        │  - Reusable across matches    │
    └───────────────────────────────┘        └───────────────┬───────────────┘
                                                             │
                                             ┌───────────────▼───────────────┐
                                             │           PvpMatch            │
                                             │  - Server Authoritative Clock │
                                             │  - 2 Players, 10 Questions    │
                                             └───────────────┬───────────────┘
                                                             │
                                             ┌───────────────▼───────────────┐
                                             │   PvpMatchPlayer & Answers    │
                                             └───────────────────────────────┘
```

### 1.1 Updated Enums and Models in `schema.prisma`

```prisma
// =============================================================================
// ENUMS
// =============================================================================

enum QuestionSourceType {
  MANUAL
  AI_GENERATED

  @@schema("learning")
}

enum QuestionStatus {
  DRAFT
  REVIEW
  PUBLISHED
  ARCHIVED

  @@schema("learning")
}

enum QuestionDifficultyEnum {
  EASY
  MEDIUM
  HARD

  @@schema("learning")
}

enum CalculationMode {
  MENTAL
  LIGHT_PEN_AND_PAPER
  PEN_AND_PAPER

  @@schema("learning")
}

enum PracticeSessionStatus {
  ACTIVE
  PAUSED
  COMPLETED
  ABANDONED

  @@schema("learning")
}

enum PvpMatchStatus {
  MATCHMAKING
  STARTING
  IN_PROGRESS
  QUESTION_ACTIVE
  QUESTION_TRANSITION
  COMPLETED
  CANCELLED

  @@schema("learning")
}

enum PvpConnectionStatus {
  CONNECTED
  DISCONNECTED

  @@schema("learning")
}

// =============================================================================
// EVOLVED QUESTION MODEL
// =============================================================================

model Question {
  id                     String                 @id @default(uuid()) @db.Uuid
  subjectId              String                 @map("subject_id")
  topicId                String                 @map("topic_id")
  subtopicId             String                 @map("subtopic_id")
  conceptId              String?                @map("concept_id") @db.Uuid
  pattern                String?                // e.g. "Successive Increase", "Base 100 Multiplication"
  prompt                 String
  questionType           String                 @default("MCQ") @map("question_type")
  options                Json                   @db.JsonB // [{"id": "A", "text": "12"}, ...]
  correctAnswer          String                 @map("correct_answer") // "A" | "B" | "C" | "D"
  hints                  Json                   @default("[]") @db.JsonB // ["Hint 1", "Hint 2"]
  explanation            String
  method                 String                 // Formula or mental shortcut used
  difficulty             QuestionDifficultyEnum @default(EASY)
  estimatedTimeSeconds   Int                    @default(60) @map("estimated_time_seconds")
  calculationMode        CalculationMode        @default(MENTAL) @map("calculation_mode")
  
  sourceType             QuestionSourceType     @default(MANUAL) @map("source_type")
  status                 QuestionStatus         @default(PUBLISHED)
  fingerprint            String                 @unique // SHA-256 hash of normalized prompt + options
  
  // Provenance metadata
  generationModel        String?                @map("generation_model")
  generationPromptVersion String?               @map("generation_prompt_version")
  generationJobId        String?                @map("generation_job_id")
  generatedAt            DateTime?              @map("generated_at")
  reviewedAt             DateTime?              @map("reviewed_at")

  createdAt              DateTime               @default(now()) @map("created_at")
  updatedAt              DateTime               @updatedAt @map("updated_at")

  // Relations
  subject                Subject                @relation(fields: [subjectId], references: [id], onDelete: Restrict)
  topic                  Topic                  @relation(fields: [topicId], references: [id], onDelete: Restrict)
  subtopic               Subtopic               @relation(fields: [subtopicId], references: [id], onDelete: Restrict)
  concept                Concept?               @relation(fields: [conceptId], references: [id], onDelete: SetNull)
  
  attempts               QuestionAttempt[]
  practiceSessionQuestions PracticeSessionQuestion[]
  userProgress           UserQuestionProgress[]
  pvpSetQuestions        PvpQuestionSetQuestion[]
  pvpMatchAnswers        PvpMatchAnswer[]

  @@index([subtopicId, status, difficulty])
  @@index([topicId, status])
  @@index([sourceType, status])
  @@map("questions")
  @@schema("learning")
}

// =============================================================================
// PRACTICE DOMAIN MODELS
// =============================================================================

model PracticeSession {
  id              String                 @id @default(uuid()) @db.Uuid
  userId          String                 @map("user_id") @db.Uuid
  subjectId       String                 @map("subject_id")
  topicId         String                 @map("topic_id")
  subtopicIds     String[]               @map("subtopic_ids")
  status          PracticeSessionStatus  @default(ACTIVE)
  currentIndex    Int                    @default(0) @map("current_index")
  totalQuestions  Int                    @default(10) @map("total_questions")
  correctCount    Int                    @default(0) @map("correct_count")
  totalTimeMs     Int                    @default(0) @map("total_time_ms")
  xpAwarded       Int                    @default(0) @map("xp_awarded")
  
  startedAt       DateTime               @default(now()) @map("started_at")
  lastActivityAt  DateTime               @default(now()) @map("last_activity_at")
  completedAt     DateTime?              @map("completed_at")

  user            User                   @relation(fields: [userId], references: [id], onDelete: Cascade)
  questions       PracticeSessionQuestion[]

  @@index([userId, status])
  @@index([userId, createdAt(sort: Desc)])
  @@map("practice_sessions")
  @@schema("learning")
}

model PracticeSessionQuestion {
  id                   String          @id @default(uuid()) @db.Uuid
  sessionId            String          @map("session_id") @db.Uuid
  questionId           String          @map("question_id") @db.Uuid
  sequence             Int
  isAnswered           Boolean         @default(false) @map("is_answered")
  userSelectedOptionId String?         @map("user_selected_option_id")
  isCorrect            Boolean?        @map("is_correct")
  responseTimeMs       Int?            @map("response_time_ms")
  hintsRevealedCount   Int             @default(0) @map("hints_revealed_count")
  answeredAt           DateTime?       @map("answered_at")

  session              PracticeSession @relation(fields: [sessionId], references: [id], onDelete: Cascade)
  question             Question        @relation(fields: [questionId], references: [id], onDelete: Restrict)

  @@unique([sessionId, sequence])
  @@index([sessionId, isAnswered])
  @@map("practice_session_questions")
  @@schema("learning")
}

model UserQuestionProgress {
  id                String    @id @default(uuid()) @db.Uuid
  userId            String    @map("user_id") @db.Uuid
  questionId        String    @map("question_id") @db.Uuid
  subtopicId        String    @map("subtopic_id")
  timesSeen         Int       @default(1) @map("times_seen")
  timesCorrect      Int       @default(0) @map("times_correct")
  lastSeenAt        DateTime  @default(now()) @map("last_seen_at")
  lastIsCorrect     Boolean   @map("last_is_correct")
  avgResponseTimeMs Int?      @map("avg_response_time_ms")

  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  question          Question  @relation(fields: [questionId], references: [id], onDelete: Cascade)

  @@unique([userId, questionId])
  @@index([userId, subtopicId, lastSeenAt])
  @@map("user_question_progress")
  @@schema("learning")
}

// =============================================================================
// RANKED PVP DOMAIN MODELS
// =============================================================================

model PvpQuestionSet {
  id                      String             @id @default(uuid()) @db.Uuid
  code                    String             @unique
  sourceType              QuestionSourceType @default(AI_GENERATED) @map("source_type")
  status                  QuestionStatus     @default(PUBLISHED)
  questionCount           Int                @default(10) @map("question_count")
  
  generationModel         String?            @map("generation_model")
  generationPromptVersion String?            @map("generation_prompt_version")
  generationJobId         String?            @map("generation_job_id")
  createdAt               DateTime           @default(now()) @map("created_at")
  updatedAt               DateTime           @updatedAt @map("updated_at")

  setQuestions            PvpQuestionSetQuestion[]
  matches                 PvpMatch[]
  playerHistory           PvpPlayerSetHistory[]

  @@index([status, createdAt])
  @@map("pvp_question_sets")
  @@schema("learning")
}

model PvpQuestionSetQuestion {
  id         String         @id @default(uuid()) @db.Uuid
  setId      String         @map("set_id") @db.Uuid
  questionId String         @map("question_id") @db.Uuid
  sequence   Int            // 1 to 10

  set        PvpQuestionSet @relation(fields: [setId], references: [id], onDelete: Cascade)
  question   Question       @relation(fields: [questionId], references: [id], onDelete: Restrict)

  @@unique([setId, sequence])
  @@map("pvp_question_set_questions")
  @@schema("learning")
}

model PvpMatch {
  id                       String         @id @default(uuid()) @db.Uuid
  questionSetId            String         @map("question_set_id") @db.Uuid
  status                   PvpMatchStatus @default(MATCHMAKING)
  totalQuestions           Int            @default(10) @map("total_questions")
  currentQuestionIndex     Int            @default(0) @map("current_question_index") // 0 to 9
  currentQuestionStartedAt DateTime?      @map("current_question_started_at")
  currentQuestionDeadline  DateTime?      @map("current_question_deadline")
  
  winnerId                 String?        @map("winner_id") @db.Uuid
  isTie                    Boolean        @default(false) @map("is_tie")
  
  startedAt                DateTime?      @map("started_at")
  endedAt                  DateTime?      @map("ended_at")
  createdAt                DateTime       @default(now()) @map("created_at")

  questionSet              PvpQuestionSet @relation(fields: [questionSetId], references: [id], onDelete: Restrict)
  winner                   User?          @relation("PvpMatchWinner", fields: [winnerId], references: [id], onDelete: SetNull)
  players                  PvpMatchPlayer[]
  answers                  PvpMatchAnswer[]

  @@index([status, createdAt])
  @@map("pvp_matches")
  @@schema("learning")
}

model PvpMatchPlayer {
  id                  String              @id @default(uuid()) @db.Uuid
  matchId             String              @map("match_id") @db.Uuid
  userId              String              @map("user_id") @db.Uuid
  score               Int                 @default(0) // correct answers count
  totalResponseTimeMs Int                 @default(0) @map("total_response_time_ms")
  isWinner            Boolean             @default(false) @map("is_winner")
  xpAwarded           Int                 @default(0) @map("xp_awarded")
  connectionStatus    PvpConnectionStatus @default(CONNECTED) @map("connection_status")
  joinedAt            DateTime            @default(now()) @map("joined_at")

  match               PvpMatch            @relation(fields: [matchId], references: [id], onDelete: Cascade)
  user                User                @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([matchId, userId])
  @@index([userId, joinedAt(sort: Desc)])
  @@map("pvp_match_players")
  @@schema("learning")
}

model PvpMatchAnswer {
  id                  String    @id @default(uuid()) @db.Uuid
  matchId             String    @map("match_id") @db.Uuid
  userId              String    @map("user_id") @db.Uuid
  questionId          String    @map("question_id") @db.Uuid
  questionIndex       Int       @map("question_index") // 0 to 9
  selectedOptionId    String?   @map("selected_option_id")
  isCorrect           Boolean   @map("is_correct")
  responseTimeMs      Int       @map("response_time_ms")
  serverReceivedAt    DateTime  @default(now()) @map("server_received_at")
  isLate              Boolean   @default(false) @map("is_late")

  match               PvpMatch  @relation(fields: [matchId], references: [id], onDelete: Cascade)
  user                User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  question            Question  @relation(fields: [questionId], references: [id], onDelete: Restrict)

  @@unique([matchId, userId, questionIndex])
  @@index([matchId, questionIndex])
  @@map("pvp_match_answers")
  @@schema("learning")
}

model PvpPlayerSetHistory {
  id            String         @id @default(uuid()) @db.Uuid
  userId        String         @map("user_id") @db.Uuid
  questionSetId String         @map("question_set_id") @db.Uuid
  lastPlayedAt  DateTime       @default(now()) @map("last_played_at")
  playCount     Int            @default(1) @map("play_count")

  user          User           @relation(fields: [userId], references: [id], onDelete: Cascade)
  questionSet   PvpQuestionSet @relation(fields: [questionSetId], references: [id], onDelete: Cascade)

  @@unique([userId, questionSetId])
  @@index([userId, lastPlayedAt])
  @@map("pvp_player_set_history")
  @@schema("learning")
}
```

### 1.2 User Model Relations Addition
In `model User`:
```prisma
  practiceSessions       PracticeSession[]
  userQuestionProgress   UserQuestionProgress[]
  pvpMatchesWon          PvpMatch[]              @relation("PvpMatchWinner")
  pvpMatchParticipations PvpMatchPlayer[]
  pvpMatchAnswers        PvpMatchAnswer[]
  pvpSetHistory          PvpPlayerSetHistory[]
```

### 1.3 Development Migration Philosophy
- We are in the active development phase. Never introduce multi-step migration complexity or temporary migration defaults.
- Running `npx prisma migrate dev --name add_practice_pvp_and_question_domain` or `npx prisma migrate reset` followed by `npm run seed:curriculum` is the official, fast mechanism to clean and align the schema.
- Fingerprints for all questions (whether seeded, manual, or AI-generated) are computed using the exact same `SHA-256(normalized prompt + options)` logic.

---

## PHASE 2 — Question Domain & Deduplication Service

### 2.1 Domain Models & Interfaces
Located in: `backend/src/modules/question/domain/question.types.ts`
- `NormalizedQuestion`: In-memory representation.
- `QuestionOption`: `{ id: 'A' | 'B' | 'C' | 'D', text: string }`.
- `QuestionFingerprint`: Deterministic hash derived from normalized prompt and sorted options text.

### 2.2 Deduplication Engine
Located in: `backend/src/modules/question/services/fingerprint.service.ts`
- **Normalization pipeline**:
  1. Lowercase text.
  2. Strip non-alphanumeric characters (keep basic math symbols: `+`, `-`, `*`, `/`, `=`, `%`, `^`).
  3. Collapse multiple whitespaces.
  4. Alphabetize and normalize the 4 options text.
  5. Compute `SHA-256(normalizedPrompt + ':::' + normalizedOptions.join('|||'))`.
- **Database enforcement**: The `fingerprint` column has a unique constraint. If Gemini generates a question with an identical fingerprint, the database insertion rejects it, and the on-demand generation pipeline prunes the collision without failing the entire batch.

---

## PHASE 3 — Gemini Provider & Node.js SDK Integration

### 3.1 Official SDK & Package Selection
- **Official Package**: `@google/genai` (current unified Google GenAI SDK for Node.js).
- **Installed via**: `npm install @google/genai`.
- **Backend Environment Variable**: `GEMINI_API_KEY`.
- **Target Model**: `gemini-3.5-flash-lite`.

### 3.2 Service Architecture
Located in: `backend/src/modules/ai/`
```
backend/src/modules/ai/
├── gemini.provider.ts        # Wraps GoogleGenAI client, auth, timeout, backoff
├── gemini.config.ts          # Model names, thinking token budget, temperature
├── interfaces/
│   ├── generator.types.ts    # Input blueprints and structured output interfaces
│   └── reviewer.types.ts     # Reviewer request & verdict interfaces
└── schemas/
    ├── question-batch.schema.ts # Strict JSON schema for Question Generator
    ├── question-review.schema.ts# Strict JSON schema for Reviewer
    └── pvp-set.schema.ts        # Strict JSON schema for PvP Set Generator
```

### 3.3 Gemini Provider Implementation Pattern
```typescript
import { GoogleGenAI } from '@google/genai';
import { ENV } from '../../config/env';

export class GeminiProvider {
  private static instance: GeminiProvider;
  private ai: GoogleGenAI;

  private constructor() {
    if (!ENV.GEMINI_API_KEY) {
      throw new Error('GEMINI_API_KEY is not defined in server environment.');
    }
    this.ai = new GoogleGenAI({ apiKey: ENV.GEMINI_API_KEY });
  }

  public static getInstance(): GeminiProvider {
    if (!GeminiProvider.instance) {
      GeminiProvider.instance = new GeminiProvider();
    }
    return GeminiProvider.instance;
  }

  public async generateStructuredContent<T>(params: {
    systemInstruction: string;
    prompt: string;
    responseSchema: Record<string, any>;
    thinkingBudget?: number; // Default: 1024 (medium level)
    timeoutMs?: number;      // Default: 25000ms
  }): Promise<T> {
    const { systemInstruction, prompt, responseSchema, thinkingBudget = 1024, timeoutMs = 25000 } = params;

    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error(`Gemini request timed out after ${timeoutMs}ms`)), timeoutMs)
    );

    const callPromise = this.ai.models.generateContent({
      model: ENV.GEMINI_MODEL || 'gemini-3.5-flash-lite',
      contents: prompt,
      config: {
        systemInstruction,
        thinkingConfig: {
          thinkingBudget,
        },
        responseMimeType: 'application/json',
        responseSchema,
        temperature: 0.2, // Low temperature for mathematical consistency
      },
    });

    const response = await Promise.race([callPromise, timeoutPromise]);
    const rawText = response.text?.trim();

    if (!rawText) {
      throw new Error('Empty response received from Gemini API.');
    }

    try {
      return JSON.parse(rawText) as T;
    } catch (err: any) {
      throw new Error(`Failed to parse Gemini JSON output: ${err.message}. Raw output: ${rawText.slice(0, 200)}`);
    }
  }
}
```

---

## PHASE 4 — Production AI Prompts & JSON Schemas

### Prompt A: Practice Question Generator

#### 1. System / Developer Prompt
```text
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
```

#### 2. Dynamic Variables Injection
```typescript
const prompt = `
Generate ${count} aptitude practice questions under these constraints:
- Subject: ${subject.name} (ID: ${subject.id})
- Topic: ${topic.name} (ID: ${topic.id})
- Target Subtopic: ${subtopic.name} (ID: ${subtopic.id})
- Subtopic Description: ${subtopic.description || 'Core fundamental skills'}
- Difficulty Target: ${difficultyCount.EASY} EASY (30-60s), ${difficultyCount.MEDIUM} MEDIUM (45-90s), ${difficultyCount.HARD} HARD (60-120s)
- Time Window: 30 to 120 seconds per question (strictly enforced)
- Calculation Mode: MENTAL or LIGHT_PEN_AND_PAPER
- Existing Question Fingerprints to Avoid (Do NOT duplicate):
${existingFingerprints.map(f => `- ${f}`).join('\n')}

Generate exactly ${count} questions.
`;
```

#### 3. Expected JSON Schema
```json
{
  "type": "object",
  "properties": {
    "questions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "pattern": { "type": "string" },
          "prompt": { "type": "string" },
          "options": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "id": { "type": "string", "enum": ["A", "B", "C", "D"] },
                "text": { "type": "string" }
              },
              "required": ["id", "text"]
            },
            "minItems": 4,
            "maxItems": 4
          },
          "correctAnswer": { "type": "string", "enum": ["A", "B", "C", "D"] },
          "difficulty": { "type": "string", "enum": ["EASY", "MEDIUM", "HARD"] },
          "estimatedTimeSeconds": { "type": "integer" },
          "calculationMode": { "type": "string", "enum": ["MENTAL", "LIGHT_PEN_AND_PAPER", "PEN_AND_PAPER"] },
          "hints": {
            "type": "array",
            "items": { "type": "string" },
            "minItems": 2,
            "maxItems": 2
          },
          "method": { "type": "string" },
          "explanation": { "type": "string" }
        },
        "required": [
          "pattern",
          "prompt",
          "options",
          "correctAnswer",
          "difficulty",
          "estimatedTimeSeconds",
          "calculationMode",
          "hints",
          "method",
          "explanation"
        ]
      }
    }
  },
  "required": ["questions"]
}
```

---

### Prompt B: Practice Question Reviewer

#### 1. System / Developer Prompt
```text
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
- If all questions are flawless: Set verdict="PASS" and return the questions array unchanged.
- If any question has an error (wrong option label, arithmetic slip, typo, bad hint): Set verdict="REVISE" and provide the corrected question in the revisedQuestions array.
- If a question is fundamentally unfixable: Exclude it from revisedQuestions and document the rejection reason in rejections.
Output strictly formatted JSON matching the response schema.
```

#### 2. Dynamic Variables Injection
```typescript
const prompt = `
Audit this batch of ${questions.length} questions for:
Subject: ${subject.name}
Topic: ${topic.name}
Subtopic: ${subtopic.name}

Questions to Audit:
${JSON.stringify(questions, null, 2)}
`;
```

#### 3. Expected JSON Schema
```json
{
  "type": "object",
  "properties": {
    "verdict": { "type": "string", "enum": ["PASS", "REVISE"] },
    "auditSummary": { "type": "string" },
    "acceptedQuestions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "pattern": { "type": "string" },
          "prompt": { "type": "string" },
          "options": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "id": { "type": "string", "enum": ["A", "B", "C", "D"] },
                "text": { "type": "string" }
              },
              "required": ["id", "text"]
            },
            "minItems": 4,
            "maxItems": 4
          },
          "correctAnswer": { "type": "string", "enum": ["A", "B", "C", "D"] },
          "difficulty": { "type": "string", "enum": ["EASY", "MEDIUM", "HARD"] },
          "estimatedTimeSeconds": { "type": "integer" },
          "calculationMode": { "type": "string", "enum": ["MENTAL", "LIGHT_PEN_AND_PAPER", "PEN_AND_PAPER"] },
          "hints": {
            "type": "array",
            "items": { "type": "string" },
            "minItems": 2,
            "maxItems": 2
          },
          "method": { "type": "string" },
          "explanation": { "type": "string" }
        },
        "required": [
          "pattern", "prompt", "options", "correctAnswer",
          "difficulty", "estimatedTimeSeconds", "calculationMode",
          "hints", "method", "explanation"
        ]
      }
    },
    "rejections": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "questionIndex": { "type": "integer" },
          "reason": { "type": "string" }
        },
        "required": ["questionIndex", "reason"]
      }
    }
  },
  "required": ["verdict", "auditSummary", "acceptedQuestions", "rejections"]
}
```

---

### Prompt C: PvP Question Set Generator (10-Question Match Set)

#### 1. System / Developer Prompt
```text
You are Aptiqu's PvP Arena Game Designer.
You generate exactly 10 high-tempo, competitive aptitude questions for a 1v1 live duel.

Rules for PvP Sets:
1. FIXED TEMPO: Exactly 10 questions. Every question must be solvable mentally or with minimal scribbling in 30 to 60 seconds (the PvP hard timer is exactly 60 seconds per question).
2. DIFFICULTY ALLOCATION:
   Each question independently receives EASY, MEDIUM, or HARD based on the requested configurable distribution.
   (Architecture Note: In future releases, player league tiers will dictate difficulty curves; for MVP, draw independently across the requested distribution).
3. ONLY LIVE UNIVERSE: Questions must be drawn strictly from the provided list of LIVE topics and subtopics.
4. VARIETY: Do not generate two questions testing the identical formula. Diversify across the provided live subtopics.
5. CONSTRUCTIVE TRAPS: Realistic distractors targeting haste and careless errors under 60-second time pressure.
6. HINTS: Provide 2 hints per question (useful if later inspected in match review).
7. OUTPUT: Raw JSON strictly adhering to schema. No conversation.
```

#### 2. Dynamic Variables Injection
```typescript
const prompt = `
Generate a 10-Question Ranked PvP Set from the following LIVE Curriculum Universe:
${liveCurriculumUniverse.map(s => `Subject: ${s.subjectName} -> Topic: ${s.topicName} -> Subtopics: ${s.subtopics.map(sub => sub.name).join(', ')}`).join('\n')}

Requested Difficulty Target for this Set:
- Target Distribution: ${pvpDifficultyConfig.easyCount} EASY, ${pvpDifficultyConfig.mediumCount} MEDIUM, ${pvpDifficultyConfig.hardCount} HARD
- Each question must be independently solvable within 30 to 60 seconds (60 seconds fixed PvP maximum).

Exclude previously generated fingerprints:
${existingFingerprints.slice(0, 30).map(f => `- ${f}`).join('\n')}
`;
```

#### 3. Expected JSON Schema
Identical question array schema as Prompt A, with `"minItems": 10`, `"maxItems": 10`.

---

### Prompt D: PvP Question Set Reviewer

#### 1. System / Developer Prompt
```text
You are Aptiqu's PvP Match Integrity Auditor.
Audit this 10-question set destined for head-to-head ranked multiplayer competition.

Integrity Rules:
1. ZERO AMBIGUITY: In PvP, an ambiguous question ruins rank fairness. Verify that the declared answer is the ONLY correct answer.
2. SPEED FAIRNESS: Confirm that every question is genuinely solvable in under 60 seconds (the PvP hard limit).
3. DIFFICULTY CONFORMANCE: Confirm each question has a valid difficulty tag (EASY, MEDIUM, or HARD).
4. MATHEMATICAL TRUTH: Re-compute all 10 answers from scratch.
5. If any question fails: Revise it immediately so the resulting set has exactly 10 fully valid questions.
Output strictly formatted JSON matching the response schema.
```

#### 2. Expected JSON Schema
Identical schema as Prompt B, enforcing that `acceptedQuestions` contains exactly 10 questions after audit/revision.

---

### Prompt E: Indian Exam Pattern Extractor (Optional Future Capability)

#### 1. System / Developer Prompt
```text
You are an Aptitude Exam Researcher specialized in SSC CGL, CHSL, IBPS PO, RRB NTPC, and TCS NQT.
Analyze the provided concept name and exam syllabus description.
Extract:
1. The classic problem archetypes tested in the last 5 years.
2. The standard tricks / formulas used by top rankers (e.g. digital sum, unitary shortcut, percentage-fraction equivalence).
3. The common trap choices exam setters use.
4. Generate 3 ORIGINAL prototype questions modeling these archetypes without copying copyrighted question text verbatim.
```

---

## PHASE 5 — Question Generation & Validation Pipeline

### 5.1 Pipeline Architecture & Class Diagram

```
Practice / PvP Service
        │
        ▼ (Check shortage)
Inventory Manager (On-Demand)
        │
        ▼ (Acquire Lock via Redis setNx)
QuestionGenerationService
        │
        ├── 1. Query Live Hierarchy (DB)
        ├── 2. GeminiProvider.generateStructuredContent() [Generator]
        ├── 3. Application Structural Validator (Node.js code - 30..120s check)
        ├── 4. GeminiProvider.generateStructuredContent() [Reviewer]
        ├── 5. Application Structural Validator (Node.js code - 30..120s check)
        ├── 6. Fingerprint Computation & Batch Deduplication (SHA-256)
        └── 7. Prisma Transaction -> Save to learning.questions
```

### 5.2 Deterministic Application Structural Validator
Located in: `backend/src/modules/question/validators/question-structural.validator.ts`
```typescript
import { z } from 'zod';
import { TIME_CONFIG } from '../../../config/inventory.config';

export const RawQuestionSchema = z.object({
  pattern: z.string().min(2).max(100),
  prompt: z.string().min(10).max(1000),
  options: z.array(z.object({
    id: z.enum(['A', 'B', 'C', 'D']),
    text: z.string().min(1).max(300),
  })).length(4),
  correctAnswer: z.enum(['A', 'B', 'C', 'D']),
  difficulty: z.enum(['EASY', 'MEDIUM', 'HARD']),
  // Enforces global 30..120 seconds solving time window
  estimatedTimeSeconds: z.number().int().min(TIME_CONFIG.GLOBAL_MIN_SECONDS).max(TIME_CONFIG.GLOBAL_MAX_SECONDS),
  calculationMode: z.enum(['MENTAL', 'LIGHT_PEN_AND_PAPER', 'PEN_AND_PAPER']),
  hints: z.array(z.string().min(5).max(300)).length(2),
  method: z.string().min(5).max(500),
  explanation: z.string().min(10).max(1000),
});

export function validateQuestionStructure(raw: unknown, isPvp = false) {
  const result = RawQuestionSchema.safeParse(raw);
  if (!result.success) {
    return { valid: false, errors: result.error.errors.map(e => `${e.path.join('.')}: ${e.message}`) };
  }
  
  // Logical check: ensure all 4 option IDs are distinct (A, B, C, D)
  const optionIds = new Set(result.data.options.map(o => o.id));
  if (optionIds.size !== 4) {
    return { valid: false, errors: ['Option IDs must be unique (A, B, C, D)'] };
  }

  // Ensure correctAnswer matches one of the option IDs
  if (!optionIds.has(result.data.correctAnswer)) {
    return { valid: false, errors: ['correctAnswer must be one of A, B, C, D'] };
  }

  // PvP additional time constraint: must be <= 60 seconds
  if (isPvp && result.data.estimatedTimeSeconds > TIME_CONFIG.PVP_MAX_SECONDS) {
    return { valid: false, errors: [`PvP questions must be solvable in <= ${TIME_CONFIG.PVP_MAX_SECONDS} seconds`] };
  }

  return { valid: true, data: result.data };
}
```

---

## PHASE 6 — AI Review & Quality Gate

1. **Generation Execution**: The generator produces a batch of questions.
2. **First Gate (Structural)**: Code validates options, answer matching, and strict 30–120s bounds. Any malformed question is dropped.
3. **Second Gate (Semantic Reviewer)**: The surviving questions are passed to `Prompt B` (Reviewer).
4. **Third Gate (Correction Application)**: If the Reviewer returns `REVISE`, the revised items replace the flawed items and undergo structural validation again.
5. **Deduplication Check**: `FingerprintService` hashes each question via `SHA-256(normalized prompt + options)`. Any question matching an existing database fingerprint or a duplicate in the same batch is pruned.
6. **Persistence**: The remaining approved questions are persisted with `status: PUBLISHED`, `sourceType: AI_GENERATED`, and complete audit metadata (`generationModel`, `generationJobId`, `reviewedAt`).

---

## PHASE 7 — Inventory Engine & On-Demand Replenishment

### 7.1 Centralized Time & Inventory Configuration
Configured in: `backend/src/config/inventory.config.ts`
Designed cleanly so all parameters can be adjusted via future admin APIs without code deployment:
```typescript
export const TIME_CONFIG = {
  GLOBAL_MIN_SECONDS: 30,
  GLOBAL_MAX_SECONDS: 120,
  PRACTICE_MIN_SECONDS: 30,
  PRACTICE_MAX_SECONDS: 120,
  PVP_FIXED_SECONDS: 60,
  PVP_MAX_SECONDS: 60,
};

export const INVENTORY_CONFIG = {
  MINIMUM_THRESHOLD_PER_SUBTOPIC: 20,
  TARGET_THRESHOLD_PER_SUBTOPIC: 30,
  DEFAULT_BATCH_GENERATION_UNIT: 10,
  PRACTICE_DIFFICULTY_DISTRIBUTION: {
    EASY: 5,
    MEDIUM: 4,
    HARD: 1,
  },
  PVP_DIFFICULTY_CONFIG: {
    // Random distribution for MVP; future: league tier determines curve
    EASY_WEIGHT: 0.33,
    MEDIUM_WEIGHT: 0.34,
    HARD_WEIGHT: 0.33,
  },
  LOCK_TTL_SECONDS: 60, // Distributed lock TTL in Redis
  PRACTICE_SESSION_QUESTIONS_COUNT: 10,
  PVP_SET_QUESTIONS_COUNT: 10,
};
```

### 7.2 On-Demand Flow (No Background Queues in MVP)
```
User requests Practice/PvP
        │
        ▼
Database Check (PostgreSQL)
        │
        ├── Usable inventory >= threshold?
        │      └── YES ──► Select & Serve immediately
        │
        └── NO (Shortage detected)
               │
               ▼
        Acquire Redis Lock (setNx)
               │
               ├── Lock Acquired?
               │      ├── YES ──► Call Gemini Generator ──► AI Review ──► Structural Validation ──► Save to DB ──► Serve
               │      └── NO  ──► Wait / Poll DB for up to 10s (reusing in-flight generation) ──► Serve
```

### 7.3 Authoritative Live Content Resolver
Located in: `backend/src/modules/curriculum/services/live-curriculum.service.ts`
```typescript
import { prisma } from '../../../config/prisma';

export class LiveCurriculumService {
  /**
   * Authoritatively determines if a topic or subtopic is LIVE.
   * A topic/subtopic is LIVE if and only if it has a published lesson script
   * with an active published version in an active roadmap.
   */
  public static async isSubtopicLive(subtopicId: string): Promise<boolean> {
    const liveCount = await prisma.scriptAssignment.count({
      where: {
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
        roadmapStep: {
          subtopicId,
          isActive: true,
        },
      },
    });

    if (liveCount > 0) return true;

    // Direct check on LessonScript
    const scriptCount = await prisma.lessonScript.count({
      where: {
        subtopicId,
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
      },
    });

    return scriptCount > 0;
  }

  public static async getAllLiveCurriculumUniverse() {
    return await prisma.subject.findMany({
      where: { isActive: true },
      include: {
        topics: {
          where: { isActive: true },
          include: {
            subtopics: {
              where: {
                isActive: true,
                roadmapSteps: {
                  some: {
                    scriptAssignments: {
                      some: {
                        status: 'PUBLISHED',
                        publishedVersionId: { not: null },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    });
  }
}
```

---

## PHASE 8 — Practice Mode Backend Architecture

### 8.1 API Endpoints Specification
- **Prefix**: `/api/v1/practice`

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/topics/live` | Returns only LIVE topics and subtopics with question counts |
| `POST` | `/sessions` | Creates and initializes a practice session |
| `GET` | `/sessions/:sessionId` | Retrieves active session state, current question, and progress |
| `POST` | `/sessions/:sessionId/answer` | Submits an answer for the current question |
| `POST` | `/sessions/:sessionId/hint` | Records a hint view (presentation assist) |
| `POST` | `/sessions/:sessionId/abandon` | Explicitly abandons session (marks ABANDONED, awards 0 completion XP) |

### 8.2 Question Selection Algorithm
Located in: `backend/src/modules/practice/services/practice-selection.service.ts`

When a user initiates Practice for one or more subtopics:
1. **Live Validation**: Every requested `subtopicId` is validated against `LiveCurriculumService`. If any subtopic is not live, throw HTTP `400 Bad Request ("Selected topic is not yet live")`.
2. **Inventory Check & Replenish**: For each selected subtopic, check available published questions. If below threshold, trigger lock-guarded on-demand generation.
3. **Candidate Prioritization Pipeline**:
   - Priority 1: Unseen questions (`user_question_progress` has no record for `userId` + `questionId`).
   - Priority 2: Previously incorrect questions (`last_is_correct = false`), ordered by `last_seen_at ASC`.
   - Priority 3: Least recently seen fallback (`last_seen_at ASC`).
4. **Assembly**: Pull 10 questions matching the balanced difficulty ratio (5 Easy, 4 Medium, 1 Hard across the selected subtopics).
5. **Session Persistence**: Insert into `practice_sessions` and `practice_session_questions` (with `sequence = 1..10`).

### 8.3 Answering & Anti-Shortcut XP Award Lifecycle
1. User submits: `{ questionId, selectedOptionId, responseTimeMs }`.
2. Server verifies `PracticeSessionQuestion` for `sessionId` and `sequence`.
3. Check correctness against `Question.correctAnswer`.
4. Update `PracticeSessionQuestion` (`isAnswered = true`, `isCorrect`, `responseTimeMs`, `answeredAt = now()`).
5. Update `user_question_progress` (`timesSeen++`, `timesCorrect += isCorrect ? 1 : 0`, `lastSeenAt = now()`).
6. **Strict Completion & XP Policy**:
   - XP is **only** awarded when **all 10 required questions have been answered**.
   - If a user closes the app, navigates away, or calls `/abandon`, the session is marked `status = ABANDONED`. **Zero completion XP is minted for abandoned sessions or unanswered questions.**
   - Once all 10 questions are answered:
     - Compute total XP: For each correct question, award $XP = \text{TypeXP}(\text{PRACTICE}) + \text{DifficultyXP}(\text{difficulty})$.
     - Call `XpService.getInstance().awardXp` with idempotency key `'practice:session:' + session.id`.
     - Mark `PracticeSession.status = COMPLETED`.
     - Return verified performance report to the client.

---

## PHASE 9 — Ranked PvP Mode Backend & Server-Authoritative Engine

### 9.1 WebSocket Event Protocol & Server-Authoritative State Machine

```
       PLAYER 1                              SERVER                              PLAYER 2
          │                                     │                                   │
          ├───────── JOIN_MATCHMAKING ─────────►│◄──────── JOIN_MATCHMAKING ────────┤
          │                                     │                                   │
          │                               (Pair Players)                            │
          │                               (Select/Gen 10-Q Set)                     │
          │                                     │                                   │
          │◄────────── MATCH_FOUND ─────────────┼─────────── MATCH_FOUND ──────────►│
          ├─────────── MATCH_READY ────────────►│◄────────── MATCH_READY ───────────┤
          │                                     │                                   │
          │                        ┌────────────────────────┐                       │
          │                        │ QUESTION 1 STARTED     │                       │
          │                        │ (Server Clock: 60.00s) │                       │
          │                        └────────────┬───────────┘                       │
          │◄──────── QUESTION_STARTED ──────────┴───────── QUESTION_STARTED ───────►│
          │                                     │                                   │
          ├────────── SUBMIT_ANSWER (12.4s) ───►│                                   │
          │◄───────── ANSWER_ACCEPTED ──────────┤                                   │
          │                                     │◄──────── SUBMIT_ANSWER (18.1s) ───┤
          │                                     ├───────── ANSWER_ACCEPTED ────────►│
          │                                     │                                   │
          │                        ┌────────────────────────┐                       │
          │                        │ DEADLINE OR BOTH DONE  │                       │
          │                        └────────────┬───────────┘                       │
          │◄──────── QUESTION_ENDED ────────────┴────────── QUESTION_ENDED ────────►│
          │                             [Repeat Q2..Q10]                            │
          │                                     │                                   │
          │◄──────── MATCH_COMPLETED ───────────┴───────── MATCH_COMPLETED ────────►│
          │                               (Award XP)                                │
```

### 9.2 Server-Authoritative Timing Rules
1. **Clock Authority**: The server issues `currentQuestionStartedAt` and `currentQuestionDeadline = startedAt + 60_000ms`.
2. **Late Answers**: An answer received where `serverReceivedAt > currentQuestionDeadline + 1000ms (grace buffer)` is flagged `isLate = true`, awarded `score = 0`, and rejected.
3. **No Early Reveals**: Neither client receives information on whether the opponent answered or what they picked until `QUESTION_ENDED` broadcasts.
4. **Early Advance**: If both players submit valid answers before 60s, the server ends the question immediately, enters a 3-second transition, and broadcasts the next question.

### 9.3 Match Abandoning / AFK Handling: Uninterrupted Active Player Run
A critical principle is that **one player going AFK or closing the app must never ruin or abort the match for the active player**:
1. If Player 2 disconnects or goes AFK midway through Question 3:
   - The server **does not** cancel the match or freeze the screen for Player 1.
   - The server simply lets the standard 60-second timer run for Question 3.
   - Player 1 continues playing naturally without disruption or popups.
   - For all unattended questions (Questions 3 through 10), Player 2 is scored `0` with no response recorded.
2. Player 1 completes the entire 10-question script as intended.
3. At the end of Question 10, `MATCH_COMPLETED` broadcasts:
   - Player 1 sees their full score report, time taken, and total XP won.
   - Opponent status is marked clearly: `"Opponent Left / AFK"`.
   - Player 1 is awarded the authoritative Match Winner bonus.
   - Player 2 receives 0 XP and an abandoned loss penalty.

### 9.4 MVP PvP Difficulty Distribution
- In MVP, each of the 10 questions in a PvP set independently receives `EASY`, `MEDIUM`, or `HARD` according to a configurable distribution (e.g. ~33% Easy, ~34% Medium, ~33% Hard).
- In future releases, player leagues (Bronze, Silver, Gold, Platinum) will determine the exact difficulty curve.

### 9.5 Scoring & Tie-Breaker Logic
1. **Primary Metric**: Total correct answers ($S \in [0, 10]$).
2. **Secondary Metric (Tie-Breaker)**: Total response time across all 10 questions in milliseconds ($T = \sum_{i=1}^{10} t_i$).
3. **Decision Rule**:
   - If $S_1 > S_2 \implies$ Player 1 wins.
   - If $S_2 > S_1 \implies$ Player 2 wins.
   - If $S_1 = S_2$ and $T_1 < T_2 \implies$ Player 1 wins.
   - If $S_1 = S_2$ and $T_2 < T_1 \implies$ Player 2 wins.
   - If $S_1 = S_2$ and $T_1 = T_2 \implies$ Match is a Tie.
4. **Authoritative XP Award**:
   - Winner: 100 XP bonus + sum of question difficulty XP ($10 \text{ per ranked correct} + \text{DifficultyXP}$).
   - Loser: Sum of their correct question XP.
   - Tie: 50 XP bonus each + correct question XP.
   - Idempotency key: `'pvp:match:' + match.id + ':user:' + player.userId`.

### 9.6 PvP Set Selection Strategy
1. Query `PvpQuestionSet` where `status = 'PUBLISHED'`.
2. Filter for sets that neither player has seen (`NOT EXISTS in PvpPlayerSetHistory for P1 AND P2`).
3. If no set is unseen by both, select a set unseen by at least one player.
4. If still none, pick the least recently used set.
5. If zero sets exist in the database, trigger an on-demand set generation under Redis lock, save it, and immediately serve it to the paired players.

---

## PHASE 10 — Redis Concurrency & Distributed Lock Architecture (BullMQ Deferred from MVP)

### 10.1 Distributed Lock Implementation
We reuse the existing `RedisService` (`ioredis`) for atomic distributed locking without introducing background queue infrastructure into the MVP:
```typescript
import { redisService } from '../lesson/services/redis.service';
import { INVENTORY_CONFIG } from '../../config/inventory.config';

export class ConcurrencyLockService {
  public static async acquireShortageLock(scopeKey: string, ttlMs = 60000): Promise<boolean> {
    const lockKey = `LOCK:SHORTAGE_GEN:${scopeKey}`;
    return await redisService.setNx(lockKey, 'locked', ttlMs);
  }

  public static async releaseShortageLock(scopeKey: string): Promise<void> {
    const lockKey = `LOCK:SHORTAGE_GEN:${scopeKey}`;
    await redisService.del(lockKey);
  }
}
```

### 10.2 Handling 10 Simultaneous Shortage Requests
When 10 users simultaneously request Practice for an empty subtopic:
1. All 10 query the database and observe a shortage.
2. Request 1 wins the atomic `setNx` lock.
3. Requests 2 through 10 fail to acquire the lock. They enter an asynchronous waiting loop (polling the DB every 1.5s for up to 10s).
4. Request 1 calls Gemini, runs AI Review, validates structure, saves 10 questions to PostgreSQL, and releases the lock.
5. Requests 2 through 10 wake up, see the 10 fresh questions in PostgreSQL, and serve them to their respective users.
6. **Result**: Exactly 1 Gemini API call is executed; zero duplicate questions are generated; all 10 users are successfully served.

---

## PHASE 11 — Flutter Practice Mode Implementation

### 11.1 Directory Structure
Located in: `lib/features/practice/`
```
lib/features/practice/
├── controllers/
│   ├── practice_catalog_controller.dart # Loads live topics/subtopics
│   └── practice_session_controller.dart # Manages active 10-Q session
├── models/
│   ├── practice_topic_model.dart
│   ├── practice_session_model.dart
│   └── practice_question_model.dart
├── repositories/
│   └── practice_repository.dart         # Dio HTTP client
└── views/
    ├── practice_catalog_screen.dart     # Topic & Subtopic selector
    ├── practice_session_screen.dart     # Question runner, options, hints
    ├── practice_summary_screen.dart     # Score, XP, level progress
    └── widgets/
        ├── hint_bottom_sheet.dart
        ├── practice_timer_bar.dart
        └── practice_option_tile.dart
```

### 11.2 Integration with Home Screen Tab 2
In `home_screen.dart`:
Replace `_buildSecondaryTabPlaceholder(2)` with `PracticeCatalogScreen()`.

### 11.3 User Flow & UX Polish
1. **Catalog View**: Displays only live topics (e.g., Mathematical Foundations & Mental Calculation). Subtopics show current mastery badge and question availability. Locked topics display a subtle padlock icon with "Unlocks with next roadmap milestone".
2. **Session Start**: Tap "Start Practice (10 Questions)". If generation is in flight, show a sleek branded skeleton loader: *"Preparing your customized problem set..."*.
3. **Question Runner**:
   - Clean Aptiqu dark-mode card.
   - Question prompt with LaTeX/math formatting support.
   - 4 options with instant haptic touch feedback.
   - Two progressive hints: "Hint 1" (reveal strategy), "Hint 2" (reveal intermediate calculation).
4. **Answer Feedback**:
   - Instant visual highlight (Emerald Green for correct, Crimson Red for wrong).
   - Shows correct answer and the concise "Method / Trick" box.
   - "Next Question" button to proceed.
5. **Completion Screen**:
   - Only shown after all 10 questions are completed.
   - Animated XP count-up.
   - Level progression bar using Aptiqu theme tokens.
   - Breakdown of accuracy and speed.

---

## PHASE 12 — Flutter Ranked PvP Mode Implementation

### 12.1 Directory Structure
Located in: `lib/features/pvp/`
```
lib/features/pvp/
├── controllers/
│   ├── pvp_matchmaking_controller.dart  # Queue state & countdown
│   └── pvp_arena_controller.dart        # Real-time match state machine
├── models/
│   ├── pvp_match_model.dart
│   ├── pvp_player_model.dart
│   └── pvp_event_models.dart
├── repositories/
│   └── pvp_socket_service.dart          # WebSocket client with auto-reconnect
└── views/
    ├── pvp_lobby_screen.dart            # Matchmaking & rank display
    ├── pvp_arena_screen.dart            # Live duel screen
    ├── pvp_result_screen.dart           # Win/loss animation, XP, time comparison
    └── widgets/
        ├── pvp_clock_radial.dart        # 60s animated countdown ring
        ├── pvp_player_header.dart       # Opponent avatar, level, score indicators
        └── pvp_versus_splash.dart       # Match intro animation
```

### 12.2 Integration with Home Screen Tab 3
In `home_screen.dart`:
Replace `_buildSecondaryTabPlaceholder(3)` with `PvpLobbyScreen()`.

### 12.3 Real-Time State Management & Opponent AFK Handling
1. **Heartbeat & Ping/Pong**: Ping every 5 seconds. If connection drops, display non-blocking overlay: *"Reconnecting to Arena..."*.
2. **State Restoration**: Upon socket reconnect, client sends `{ type: 'RECONNECT_MATCH', matchId, userId }`. Server responds with exact remaining time on current question and scores, allowing seamless match continuation.
3. **Opponent AFK**: If the opponent goes AFK or disconnects, the player sees no disruption. The active player plays all 10 questions uninterrupted. At the match conclusion, the final score card notes the opponent abandoned the match and awards the active player their well-earned victory and XP.

---

## PHASE 13 — Admin & Content Management Tooling

### 13.1 Backend Admin Capabilities (Built in MVP)
Admin REST APIs under `/api/v1/admin/questions`:
1. `GET /api/v1/admin/questions`: Filter by topic, subtopic, status (`DRAFT`, `REVIEW`, `PUBLISHED`, `ARCHIVED`), and source type.
2. `POST /api/v1/admin/questions`: Manually author and publish a question with the identical schema.
3. `PUT /api/v1/admin/questions/:id`: Edit prompt, options, correct answer, hints, or explanation.
4. `POST /api/v1/admin/questions/:id/archive`: Soft-delete/archive poor questions.
5. `POST /api/v1/admin/inventory/generate`: Manually trigger an on-demand generation batch for a specific subtopic.
6. `POST /api/v1/admin/pvp-sets/generate`: Manually trigger generation of a new PvP set.
7. `PUT /api/v1/admin/config/timing`: Update practice/pvp time limits (e.g. 60s PvP limit, 30–120s practice limits) dynamically.

### 13.2 UI Deferral
No complex admin web UI will be built now. Admin operations will be supported via clean REST endpoints authenticated with admin role tokens, runnable via Postman / curl scripts.

---

## PHASE 14 — Testing Matrix & Concurrency Scenarios

### 14.1 Unit Tests
- `fingerprint.service.test.ts`: Verify identical fingerprints are produced using `SHA-256` regardless of whitespace, casing, or reordered options.
- `question-structural.validator.test.ts`: Verify strict rejection of questions outside 30..120 seconds, invalid correct option IDs, empty hints, or missing fields.
- `pvp-timing.validator.test.ts`: Verify rejection of PvP questions exceeding 60 seconds.
- `xp-anti-shortcut.test.ts`: Verify that calling `/abandon` or incomplete sessions awards exactly 0 XP.

### 14.2 Integration Tests
- `practice-session-lifecycle.test.ts`:
  1. Create session for live subtopic.
  2. Answer 10 questions sequentially.
  3. Validate score, total time, and XP transaction record.
  4. Attempt duplicate answer submission (assert HTTP 409 / idempotent rejection).
- `pvp-afk-resilience.test.ts`:
  1. Start match between P1 and P2.
  2. P2 drops at Q3.
  3. P1 plays all 10 questions to completion.
  4. Verify P1 receives victory XP and complete match summary.

### 14.3 Critical Concurrency Test: 10 Simultaneous Shortage Requests
- **Test Setup**: Set subtopic inventory to 2 questions.
- **Execution**: Fire 10 parallel HTTP requests to `POST /api/v1/practice/sessions` for the same subtopic.
- **Assertion**:
  - Exactly ONE on-demand generation acquires the Redis lock and calls Gemini.
  - Exactly ONE batch of questions is inserted.
  - Zero duplicate key constraint errors occur.
  - All 10 users receive valid sessions without failure.

---

## PHASE 15 — Security & Credential Hygiene

### 15.1 Gemini API Key Isolation
- `GEMINI_API_KEY` is **strictly confined** to the backend environment variables (`backend/.env`).
- Never referenced or imported into Flutter code, Dart packages, or client-facing configuration files.
- `.gitignore` in both root and backend explicitly ignores `.env`, `.env.production`, and credentials.

### 15.2 Anti-Cheat & Tamper Resistance
- **Option Scrambling**: Option letters (A, B, C, D) are assigned server-side. Correct answer is never exposed in `GET /sessions/:id` or WebSocket question broadcasts until after submission.
- **Client Time Enforcement**: The server records `receivedAt - startedAt`. Client-sent `responseTimeMs` is only used for UI analytics; the server validates that response time cannot be less than 500ms (preventing automated bots) and cannot exceed the deadline.

---

## PHASE 16 — Observability, Analytics & Cost Control

### 16.1 Cost Projection & Efficiency (gemini-3.5-flash-lite)
- **Model Pricing Baseline**: Flash-Lite has an extremely competitive cost (~$0.075 / million input tokens, ~$0.30 / million output tokens).
- **Prompt Size**:
  - Generator Request: ~600 input tokens + ~1,200 output tokens $\approx \$0.0004$ per 10-question batch.
  - Reviewer Request: ~1,500 input tokens + ~800 output tokens $\approx \$0.00035$.
  - Total per batch of 10 verified questions: **< $0.001 (less than one-tenth of a cent)**.
- **Reusability Multiplier**: Because questions are persisted in PostgreSQL, 100,000 student practice sessions across 10 live subtopics will reuse the existing pooled questions, resulting in **$0.00 additional AI cost** once inventory reaches targets.

### 16.2 Analytical Logging
Each attempt records:
- `responseTimeMs` (actual) vs `estimatedTimeSeconds` (AI estimated).
- Option selection distribution (identifies if a distractor is never picked or if an unintended option is misleading).
- Hint usage count ($0, 1, 2$).
- Accuracy per question.

---

## PHASE 17 — Deployment Architecture & Environment Configuration

### 17.1 Infrastructure Topology
```
[ Client (Flutter App) ]
         │
         ▼ HTTPS / WSS
   [ Nginx Reverse Proxy ]
         │
   [ Node.js Backend API (Express + ws) ]
         ├── [ PostgreSQL 16 (Durable Data) ]
         ├── [ Redis 7 (Cache, Distributed Locks, Pub/Sub) ]
         └── [ Gemini 3.5 Flash-Lite API ]
```

### 17.2 Backend Environment Additions
In `backend/.env`:
```env
# Gemini AI Configuration
GEMINI_API_KEY=AIzaSy...
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_THINKING_BUDGET=1024

# Inventory Configuration
INVENTORY_MIN_THRESHOLD=20
INVENTORY_TARGET_THRESHOLD=30

# Redis & WebSockets
REDIS_URL=redis://127.0.0.1:6379
WS_PORT=5001 # Shared on Express HTTP server
```

---

## PHASE 18 — Incremental Rollout & Verification Milestones

1. **Milestone 1**: Database schema updated via Prisma in development.
2. **Milestone 2**: Gemini Provider, structural validators (30..120s), and `SHA-256` deduplication verified via CLI test script.
3. **Milestone 3**: On-demand lock-guarded generation tested on `Basic Arithmetic` and `BODMAS`.
4. **Milestone 4**: Practice Mode backend REST API integration complete; anti-shortcut XP rules verified.
5. **Milestone 5**: Flutter Practice UI connected to live backend; end-to-end practice session verified.
6. **Milestone 6**: WebSocket PvP arena engine tested with 2 simulated clients, including AFK opponent scenario.
7. **Milestone 7**: Flutter Ranked Arena connected and tested.

---

## WHAT SHAGUN NEEDS TO DO BEFORE IMPLEMENTATION

This is your practical, step-by-step preparation checklist:

### Step 1: Google Gemini API Credential Setup
1. Go to **Google AI Studio** (https://aistudio.google.com/) or **Google Cloud Console**.
2. Create a new API Key in your desired project.
3. Verify that the project has access to `gemini-3.5-flash-lite` (or the `gemini-2.5` / `gemini-3.x` family).
4. Copy the API key string (starts with `AIzaSy...`).

### Step 2: Configure Backend Environment
1. Open `backend/.env`.
2. Add the following lines:
   ```env
   GEMINI_API_KEY=your_actual_api_key_here
   GEMINI_MODEL=gemini-3.5-flash-lite
   GEMINI_THINKING_BUDGET=1024
   ```
3. Ensure `backend/.gitignore` contains `.env`.

### Step 3: Install Required Backend Packages
In your terminal, navigate to `backend` and run:
```bash
cd /Users/shagunkumar/Desktop/aptiqu/backend
npm install @google/genai ws @types/ws
```

### Step 4: Run Prisma Migration
When ready to begin Phase 1:
```bash
cd /Users/shagunkumar/Desktop/aptiqu/backend
npx prisma migrate dev --name add_practice_pvp_and_question_domain
```

### Step 5: Verify Redis is Running Locally
Run:
```bash
redis-cli ping
```
Ensure it returns `PONG`. If Redis is not running:
```bash
brew services start redis
# or run redis-server in a terminal
```

### Step 6: Verify Live Curriculum in Database
Verify that your database has the live curriculum seeded by running:
```bash
cd /Users/shagunkumar/Desktop/aptiqu/backend
npm run seed:curriculum
```
Ensure Mathematical Foundations & Mental Calculation is seeded with its published scripts.

### What You DO NOT Need to Do
- ❌ **DO NOT put any Gemini API key in Flutter, Dart code, or mobile `.env` files.**
- ❌ **DO NOT configure any Gemini SDK in Android Studio or Xcode.**
- ❌ **DO NOT manually write or seed hundreds of practice questions.** (The lazy AI replenishment engine will populate them on demand).
- ❌ **DO NOT build or set up Google Gemini Batch API infrastructure.** (We are using immediate inference with persistent database caching).
- ❌ **DO NOT attempt to generate questions for locked topics** (Number System, Percentages, etc.).
- ❌ **DO NOT set up background queue workers (BullMQ) or pre-warming jobs for MVP.**
- ❌ **DO NOT write complex database migration downgrade/upgrade scripts.** (We are in dev and can reset/re-seed anytime).

---

## FINAL SUMMARY

### A. FIXED DECISIONS
1. **Target AI Model**: `gemini-3.5-flash-lite` with internal thinking enabled (`thinkingBudget: 1024`) and structured JSON output.
2. **SDK**: Official `@google/genai` TypeScript SDK.
3. **Architecture Boundary**: Gemini is called **only server-side** by the Node.js backend.
4. **No Batch API & No Background Replenishment in MVP**: Purely on-demand generation when a shortage is hit, guarded by Redis `setNx` lock, stored durably in PostgreSQL, and reused.
5. **Time Constraints**:
   - Practice: 30–120 seconds.
   - PvP: Fixed 60 seconds per question.
   - Structural validator enforces 30..120s globally; PvP enforces $\le 60$s.
   - Configurable in `TIME_CONFIG` for future admin dashboard editing.
6. **PvP Difficulty**:
   - MVP: Independent random draw per question across EASY, MEDIUM, and HARD based on a configurable distribution.
   - Future: Player league tiers determine the curve.
7. **Anti-Shortcut XP**:
   - Practice XP is only awarded when all 10 required questions are answered. Exiting early or calling `/abandon` awards 0 completion XP.
8. **PvP Match Abandoning / AFK**:
   - The active player continues uninterrupted through the entire 10-question match. The opponent who went AFK/disconnected is scored 0 for missed questions, and the active player is awarded the victory report and XP upon completing Question 10.
9. **Deduplication & Migrations**:
   - Uniform `SHA-256(normalized prompt + options)` via `FingerprintService`. No MD5 anywhere.
   - Development database policy: simple migrate/reset and re-seed.
10. **XP System**: Reuses the centralized `XpService` and `XpPolicy`.

### B. DECISIONS REQUIRING APPROVAL
1. **WebSocket Framework**: The plan specifies native `ws` attached to the existing Express HTTP server on port 5001 for Ranked PvP.
2. **PvP Match Duration**: Default set to 10 questions at 60 seconds fixed per question.
3. **Practice Session Length**: Default set to 10 questions per practice run.

### C. ASSUMPTIONS
1. Redis is available in both local development and production environments (`REDIS_URL`).
2. Google AI Studio API key has sufficient rate limits (RPM/TPM) for development testing.
3. Mathematical Foundations & Mental Calculation remains the primary live topic for initial verification.

### D. RISKS / THINGS TO WATCH
1. **Gemini Latency during Cold Start**: If a user selects a subtopic with fewer than 20 questions, the on-demand generation and review cycle will take 3 to 5 seconds. The Flutter client must display a clear, branded loading state (*"Preparing your customized problem set..."*).
2. **Math Formatting (LaTeX)**: Complex algebraic questions may output LaTeX expressions (e.g. `\frac{a}{b}`). The Flutter question runner should support basic LaTeX rendering or prompt guidelines must mandate clean plain text math notations (e.g. `a/b`).
3. **Mobile Network Drops**: Mobile devices frequently switch between Wi-Fi and cellular. The PvP WebSocket engine must strictly support the reconnect protocol with state re-synchronization.
