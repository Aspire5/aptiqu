# Phase A production-font fixtures

These are the exact static font files referenced by `google_fonts` 8.1.0,
not one variable font substituted for every family and weight.

`sources.json` records the Google-hosted URL, SHA-256 and byte length for each
file. Each downloaded file was checked against both expected values. Font
licenses are included. The old test fixtures and golden baselines are untouched.
The fixtures are test-only; production font fetching and pubspec assets are unchanged.

The pilot test maps each Outfit/Plus Jakarta Sans request to its own weight.
Legacy Space Grotesk requests in the outer, unmigrated theme use the matching
Outfit test weight; those legacy regions are not evidence of Space Grotesk rendering.
