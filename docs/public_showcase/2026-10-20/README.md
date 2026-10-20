# Public screenshot refresh · 20 October 2026

These are fresh 780×1688 renders of the **current production Flutter widgets**, captured at 390×844 logical pixels with 2× output resolution and bundled brand fonts. They are screenshot fixtures with illustrative data, not a real account, native-device captures or claims about production rankings. No Flutter screen/backend code or database was changed.

Reproduce only this bounded capture (about three seconds of rendering after compilation):

```sh
flutter test --no-pub test/public_showcase_capture_test.dart --reporter expanded
```

The fixture uses the supplied portrait from `admin-dashboard/public/showcase/brand/shagun.jpeg` through Flutter's in-memory image cache; no image request leaves the process. All API data comes from local fixture adapters. Neither sign-in nor a live API/database is used.

Demo identity: **Shagun**, Level 8, 648 XP (Level 8 begins at 560 XP; 88/160 toward Level 9), 4-day streak and 240 coins. Home uses 272 submissions, 204 correct (75%) and 18.5-second average solve time. The three difficulty counts sum to those totals. October activity includes gaps and four consecutive completed Daily Challenges on 17–20 October. Highest streak is a historical seven-day value, which may precede the displayed activity window. Ranked sample: Platinum, 1500 Elo, #128, 30 matches (20 wins/8 losses/2 draws), with a recent 8–5 win and +16 Elo. Friend Maya is sample data.

Files: Home Dark/Light, scrolled Home consistency calendar, the existing lesson with only refreshed shell identity, all three current login carousel slides (Learn Dark / Practice Light / Compete Dark), current friendly duel, and current Ranked lobby. The lesson message, question and options remain the same as the original public screenshot. Both original Practice images remain byte-for-byte unchanged.

The corresponding WebP files in `admin-dashboard/public/showcase/screenshots/` are encoded at quality 90. Their paths/provenance are recorded in `admin-dashboard/src/public/screenshots.ts`. The login fan uses three separate full, genuine screenshots, not a composited/fabricated app interface. Its centre preview is Light mode. The supplied diya and developer portrait are reused unchanged.

Focused checks: the single capture fixture passed; frontend TypeScript/production build passed; desktop browser reported no console errors or broken loaded images. Phone review at 390 and 320 px found no horizontal page overflow and confirmed an 18 px launch date (19 px desktop). No historical Flutter suite, backend test campaign, database action or production deployment was run.
