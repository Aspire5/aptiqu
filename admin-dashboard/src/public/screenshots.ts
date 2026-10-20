export interface AppScreenshot {
  id: string;
  title: string;
  path: string;
  caption: string;
  alt: string;
  theme: 'dark' | 'light';
  order: number;
  available: boolean;
  source: string;
  provenance: 'flutter-fixture';
}

export const screenshots: AppScreenshot[] = [
  { id: 'home', title: 'Your starting point', path: '/showcase/screenshots/home-dark.webp', caption: 'Pick up a lesson. See your progress.', alt: 'AptiQu dark Home screen with Continue learning and performance information.', theme: 'dark', order: 1, available: true, source: 'docs/ui_ux_phase_g/S03-home-dark-phone.png', provenance: 'flutter-fixture' },
  { id: 'lesson', title: 'One idea at a time', path: '/showcase/screenshots/lesson-dark.webp', caption: 'Concepts, examples and questions in one flow.', alt: 'AptiQu guided lesson explaining equal sharing with a multiple-choice question.', theme: 'dark', order: 2, available: true, source: 'docs/ui_ux_phase_g/S04-embedded-dark-phone.png', provenance: 'flutter-fixture' },
  { id: 'setup', title: 'Make practice yours', path: '/showcase/screenshots/practice-setup-dark.webp', caption: 'Choose your topics, subtopics and session options.', alt: 'AptiQu custom Practice setup with subject and subtopic selection, friendly duel and timer options.', theme: 'dark', order: 3, available: true, source: 'test/goldens/practice-custom.png', provenance: 'flutter-fixture' },
  { id: 'question', title: 'Think. Solve. Learn.', path: '/showcase/screenshots/practice-question-dark.webp', caption: 'Work through questions at your own pace.', alt: 'AptiQu Practice question with four answer options and a Submit answer control.', theme: 'dark', order: 4, available: true, source: 'docs/ui_ux_phase_g/S08-practice-dark-phone.png', provenance: 'flutter-fixture' },
  { id: 'duel', title: 'Bring a friend', path: '/showcase/screenshots/duel-dark.webp', caption: 'A shared challenge. Two different approaches.', alt: 'AptiQu friendly duel room showing a pending challenge invitation and both players.', theme: 'dark', order: 5, available: true, source: 'docs/ui_ux_phase_g/S17-duel-dark-phone.png', provenance: 'flutter-fixture' },
  { id: 'ranked', title: 'Find your next match', path: '/showcase/screenshots/ranked-dark.webp', caption: 'Your league, rating and season in one place.', alt: 'AptiQu Ranked lobby with a Platinum badge, sample Elo rating and monthly season details.', theme: 'dark', order: 6, available: true, source: 'docs/ranked_phase4/lobby-qualified-dark-phone.png', provenance: 'flutter-fixture' },
  { id: 'home-light', title: 'A lighter perspective', path: '/showcase/screenshots/home-light.webp', caption: 'The same learning experience in Light mode.', alt: 'The corresponding AptiQu Home screen in Light mode.', theme: 'light', order: 7, available: true, source: 'docs/ui_ux_phase_g/S03-home-light-phone.png', provenance: 'flutter-fixture' },
];

export function screenshot(id: string): AppScreenshot {
  const result = screenshots.find((entry) => entry.id === id);
  if (!result) throw new Error(`Unknown showcase screenshot: ${id}`);
  return result;
}
