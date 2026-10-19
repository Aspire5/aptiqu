# Ranked Phase 4 rendered evidence

Safe deterministic Flutter fixtures with production-font helpers and the actual resized WebP badge decodes. These are local renders, not live rankings or native-device evidence. Phase 4 implementation/verification details: [handoff](../RANKED_LEAGUES_PHASE_4_HANDOFF.md).

| View | Light | Dark |
|---|---|---|
| Qualified lobby, 390×844 | [Light](lobby-qualified-light-phone.png) | [Dark](lobby-qualified-dark-phone.png) |
| Placements lobby, 390×844 | [Light](lobby-placements-light-phone.png) | [Dark](lobby-placements-dark-phone.png) |
| Qualified lobby, 320×568 / 2× text | [Light](lobby-qualified-light-large.png) | [Dark](lobby-qualified-dark-large.png) |
| Placements lobby, 320×568 / 2× text | [Light](lobby-placements-light-large.png) | [Dark](lobby-placements-dark-large.png) |
| Leaderboard, 390×844 | [Light](leaderboard-light.png) | [Dark](leaderboard-dark.png) |
| Leaderboard, 320×568 / 2× text, scrolled | [Light](leaderboard-light-large.png) | [Dark](leaderboard-dark-large.png) |
| Season history | [Light](seasons-light.png) | [Dark](seasons-dark.png) |
| Home Ranked region, scrolled | [Light](home-light.png) | [Dark](home-dark.png) |
| Profile identity → Appearance → Ranked | [Light](profile-light-identity.png) | [Dark](profile-dark-identity.png) |
| Profile Ranked details, scrolled | [Light](profile-light.png) | [Dark](profile-dark.png) |
| Inline result component, 320×568 / 2× text | [Light](result-light-large.png) | [Dark](result-dark-large.png) |
| Actual arena, recovered committed prior-month result | [Light](arena-recorded-light.png) | [Dark](arena-recorded-dark.png) |

Normal and representative enlarged/scrolled captures were visually inspected. The tests also check ownership, pagination/reset, reachability, semantics and reduced motion. This does not claim every native/accessibility state was manually inspected.

Reproduce locally, without starting a backend or connecting to a database:

```sh
flutter test --no-pub --dart-define=CAPTURE_RANKED_PHASE4=true test/ranked_phase_four_test.dart
```

No old screenshot/golden directory was overwritten; the existing Home compatibility golden passes unchanged. Fixtures intentionally use fixed sample ratings and dates. The renderer does not award XP/Elo or turn on server flags.
