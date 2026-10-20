# Public AptiQu website

The existing React 18 / TypeScript / Vite project in `admin-dashboard/` now builds both the public landing page and existing admin interface. No new framework or package was installed. No backend, Flutter screen, database, AWS, Nginx or PM2 changes are part of this work.

## Build and local preview

```sh
cd admin-dashboard
npm run dev
npm run build
npm run preview -- --host 127.0.0.1
```

The existing build runs TypeScript project checks and Vite, producing `admin-dashboard/dist/`. Publish the **whole** directory at the serving origin root (including `/assets`, `/showcase`, and existing admin public assets). It is not a `/dashboard`-based Vite build.

## Routing and isolation

- `/`: public page. Public bootstrap does not import admin CSS, mount AuthProvider, read admin storage, or make API requests.
- `/dashboard`: existing protected dashboard.
- `/dashboard/login`: existing admin login; login, logout and 401 redirects use this URL.
- `/dashboard/{syllabus,books,questions,ai-prompts,achievements,users}`: existing protected admin pages.
- Old `/login`, `/syllabus`, `/books`, `/questions`, `/ai-prompts`, `/achievements`, `/users` bookmarks redirect to their corresponding `/dashboard/...` paths, preserving query/hash.
- Public links are only in-page navigation; there is no public admin link.

`src/main.tsx` chooses separate lazy entry chunks. Admin global CSS loads only with the admin chunk. Landing rules are prefixed `.aq-*`, with public document rules gated by `html[data-aptiqu-public]`; admin design tokens/components are unchanged. Admin navigation changes are path-only, plus exact matching on the dashboard index link. API request URLs, Vite API proxy and authentication checks are preserved.

## Hosting proposal — operator action only

No live server configuration was inspected or changed. The Express app owns API routes and returns JSON 404 for other paths; it does not serve this Vite build. The current public IP will show this page **only after an operator deploys the build and configures the serving origin**.

Required routing precedence at the existing HTTP origin:

1. Preserve **all existing `/api/...` handling** and upstream destinations.
2. Preserve **the existing WebSocket upgrade location(s)**, protocol headers, timeouts and upstreams exactly. Repository upgrade paths are `/ws/pvp` and `/ws/social` (`backend/src/server.ts`); preserve their current production mappings rather than introducing `/socket.io` (the backend uses `ws`).
3. Serve existing files from the deployed `dist/` directory, including `/assets/*`, `/showcase/*`, `/logo.jpeg` and the favicon. Missing assets should return 404 rather than the SPA HTML; do not apply long immutable caching to replaceable showcase filenames.
4. Serve `dist/index.html` for `/`, `/dashboard`, `/dashboard/*` and legacy admin bookmark paths so direct navigation and refresh work.
5. Keep other existing server locations ahead of any generic SPA fallback; do not route API failures or WebSocket requests to `index.html`.

Conceptually, the static-site location needs a `try_files <requested-file> /index.html` fallback, **after** current API/WebSocket exclusions. Exact Nginx server-block changes depend on the live configuration and must be prepared by the operator. Do not replace the server block with a generic snippet. No future domain, TLS, DNS, security-group or environment changes are required by the source code.

## Screenshot assets and replacement

Manifest: `admin-dashboard/src/public/screenshots.ts`. Each entry records stable ID, title, image path, caption, alt text, theme, order, availability and original source. Files: `admin-dashboard/public/showcase/screenshots/`.

All seven images are **genuine deterministic Flutter widget renders**, copied from existing local evidence and encoded to WebP at quality 90. They show actual application widgets with safe demo data. **No new emulator/device screenshots were captured. No fabricated UI or temporary image placeholders are displayed.** The visible gallery notes the demo provenance. Evidence may predate concurrent Home changes; replace it after the relevant UI is approved.

| File | Original local render |
|---|---|
| home-dark.webp | docs/ui_ux_phase_g/S03-home-dark-phone.png |
| home-light.webp | docs/ui_ux_phase_g/S03-home-light-phone.png |
| lesson-dark.webp | docs/ui_ux_phase_g/S04-embedded-dark-phone.png |
| practice-setup-dark.webp | test/goldens/practice-custom.png |
| practice-question-dark.webp | docs/ui_ux_phase_g/S08-practice-dark-phone.png |
| duel-dark.webp | docs/ui_ux_phase_g/S17-duel-dark-phone.png |
| ranked-dark.webp | docs/ranked_phase4/lobby-qualified-dark-phone.png |

To replace: overwrite the matching WebP, retaining the filename, then rebuild. Prefer a 390×844 portrait render, with demo identity, no debugging overlays, no credentials and no unfinished/error state. Practice setup's source is 360×800; the shared preview normalizes its frame to 390:844 with a slight bottom crop. Update alt text/caption/source/provenance in the manifest if the content changes; extend the provenance union for native captures. Set `available: false` to hide an entry from the gallery. Hero/feature/theme placements show a clearly labelled fallback if a required entry is unavailable or its file fails, never fake UI. Keep paired Home Light/Dark images corresponding to the same app state. Add or remove manifest entries to extend the gallery; referenced stable IDs must remain defined.

Brand assets are copied unchanged from `assets/images/main_logo.webp` and the six files in `assets/images/ranked/`. Fonts are bundled Outfit and Plus Jakarta Sans, with their OFL license copies in `showcase/fonts/`. Decorative lighting, phone frames and backgrounds are code-created and replaceable in `public.css`; no AI image generation was used.

## Truthful product copy

Learning copy reflects the embedded lesson, script/questions and roadmap implementation. Practice copy is grounded in `practice_catalog_view.dart`, its controllers and `practice-selection.service.ts` (including weak-pattern Smart AI Picks). Friendly Practice duels and Ranked are separate. Elo/monthly seasons are grounded in `ranked-rating.ts`, `ranked-season-time.ts` and the mobile Ranked UI. Rank states use the existing six assets. The AI lesson assistant, bookmarks, shared question links, mobile push, AI feedback and achievement expansion are explicitly planned. Existing achievements are described separately in the history. No feature activation or production availability is asserted.

## Changelog updates

Root `CHANGELOG.md` is canonical for the whole product. `src/public/releases.ts` imports its raw Markdown at build time, reading descending `## [0.0.x] — YYYY-MM-DD · Title` sections and their bullets. The public timeline shows three recent milestones and expands the older ones. Unreleased and reserved v1.0.0 are excluded from historical releases. Add meaningful work to Unreleased; assign a new pre-release milestone only after verifying implementation and its Git evidence. Rebuild to update the page. Historical service logs and the old release manifest remain untouched as provenance, not current product version authority. No tags/history were rewritten.

## Metadata and future assets

Title, description, social title/description, theme color and existing brand favicon are set in `index.html`. No canonical URL, future domain, tracking, fake store/profile links or invented social preview image is included. A real 1200×630 social sharing creative and final absolute public URL can be added later. There is no Google Play button until its real URL is supplied. The existing admin Roboto stylesheet reference remains in the HTML to preserve its typography; the landing itself uses local brand fonts.

## Focused verification

- `npm run build`: TypeScript project checks and production Vite build passed. The existing large admin chunk still triggers Vite’s >500 kB warning; it is separate from the public chunk.
- Browser: actual page rendered with no console errors; logo, original badges and screenshot assets loaded.
- Responsive rendered review at 1440, 390 and 320 px: document width matched viewport width; no page overflow. Additional direct desktop review at 1280 px.
- Theme toggle changed to the genuine Light image; gallery control moved the scroll track; earlier milestones expanded.
- Temporarily marked Home unavailable: labelled fallback appeared in hero/theme and the gallery omitted that entry; restored before build.
- `/dashboard`, `/dashboard/questions` and legacy `/questions` reached the existing login when unauthenticated. No login submission or backend/database action was used. Authenticated admin business flows were not exercised.
- API client diff checked: only browser 401 redirect/guard paths changed; API request URLs are unchanged. Public links contain no admin destination.
- Temporary responsive harness removed; `git diff --check` passed for task files.

No native capture or production/proxy validation was performed. Screenshot replacement and optional social preview creative remain future asset work, not blocked functionality.

## Files in this change

Created: root `CHANGELOG.md`; this guide; `admin-dashboard/src/public/{PublicLanding.tsx,public.css,screenshots.ts,releases.ts}`; `admin-dashboard/public/showcase/` brand, rank, screenshot and licensed font assets.

Modified only for metadata/bootstrap/routing: `admin-dashboard/index.html`, `src/main.tsx`, `src/App.tsx`, `src/components/layout/AdminLayout.tsx`, `src/pages/DashboardPage.tsx`, `src/services/api.ts`. Existing admin page visuals, authentication logic and API endpoint strings are preserved. Other working-tree changes belong to concurrent work and were left intact.
