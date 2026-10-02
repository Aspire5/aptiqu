# AptiQu Mobile App — Release & Update Log

All notable changes, version updates, and release notes for the AptiQu Flutter mobile application (iOS & Android).

---

## [1.2.0+3] — 2026-10-02

### PYQ Badges & Dual Solution Cards
* **Competitive Exam Badges (`🏛️ PYQ`):**
  * Displays competitive exam provenance badge (e.g. `🏛️ TCS NQT (2023), CAT (2012)`) under question prompt cards across Practice Arena, Daily Challenge, Lesson dialogues, and PvP Arenas.
* **Dual Solution Post-Answer Breakdown:**
  * Replaced single explanation banner with structured dual solutions: Solution 1 (Book Method) and Solution 2 (Alternative Speed Shortcut).
  * Solution cards highlight "⭐ AI Preferred" badge on the method recommended by AptiQu AI.
  * Tapping "AI Preferred" opens an info bottom sheet explaining the exact speed/clarity rationale under exam pressure.
* **Model Enriched Support:**
  * Updated `PracticeQuestionModel`, `PracticeAnswerResultModel`, `DailyChallengeQuestionModel`, `DailyChallengeAnswerResultModel`, `QuestionInlineModel`, and `PvpQuestionDataModel` with PYQ, provenance, and dual-solution parsing.

---

## [1.1.0+2] — 2026-10-01

### Daily Streak Alerts & UI/UX
* **Daily Challenge Banner:** Integrated high-visibility streak protection banner on the Play screen with real-time countdown ticking down to 12:00 AM IST.
* **Streak Risk Notifications:** Dynamic risk warnings ("X-day Streak at Risk! RESET 12 AM IST") with pulsing fire icon and direct CTA navigation to the challenge arena.
* **Secured State Display:** Displays verified green status ("Today's Streak Secured! 🔥") once the daily challenge is conquered.
* **Top Bar Attention Indicator:** Added glowing notification badge to the Streak icon in the global top bar when a daily challenge is pending.

---

## [1.0.0+1] — 2026-10-01 (Initial Production Candidate)

### Platform & Build Configurations
* **App Branding:** Official app display name finalized to **AptiQu** across Android and iOS.
* **App Icons:** Integrated production high-resolution adaptive app icon set for Android (`mipmap-anydpi-v26`, `mipmap-*dpi`) and iOS Asset Catalog (`AppIcon.appiconset` with 1024x1024 App Store artwork).
* **Operating System Support:**
  * **iOS:** Minimum deployment target updated to **iOS 15.0+** across `Podfile`, pod configs, and Xcode project settings.
  * **Android:** Configured `minSdkVersion 23` (Android 6.0+) and `targetSdkVersion 34`.
* **Binary Size & Performance Optimization:**
  * Enabled R8 code shrinking (`isMinifyEnabled = true`) and resource shrinking (`isShrinkResources = true`).
  * Added tailored `proguard-rules.pro` for Flutter Engine, Google Sign-In SDK, and EncryptedSharedPreferences.

### Authentication & Security
* **Authentication Redesign:** Minimalist, distraction-free authentication flow powered by Google OAuth.
* **Eliminated Test Harnesses:** Completely purged sandbox mock buttons, test tokens, and dev bypass logic from production code.
* **Session Termination:** Added clean sign-out workflow accessible via both the Profile navigation bar and dedicated Account Settings card, with confirmation dialog and secure token purging.

### Design System & Aesthetics
* **Theme Modernization:** Removed AI buzzword terminology and high-saturation default primary button fills.
* **Unified Dark Button Tokens:** Implemented cohesive elevated dark containers (`0xFF1B2030`), subtle 1.2px category-tinted borders, standardized 12px radii, and crisp white typography and iconography across Play Cards, Practice Drills, Ranked Arenas, and Daily Challenge screens.
