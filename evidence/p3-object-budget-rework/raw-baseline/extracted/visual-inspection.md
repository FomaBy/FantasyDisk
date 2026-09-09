# FAN-3877 visual evidence inspection

Verdict for visual evidence: **insufficient for holistic certification**.

Candidate: `d192be10bbe52dd89971cab0acc66eb92ccab37f`

Tree: `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf`

## Inspection performed

- Hydrated the LFS objects used by the 17 class evidence packages before inspection.
- Verified all 68 referenced PNG files (17 classes × 4 viewport sizes) as actual PNG data rather than LFS pointer text.
- Verified dimensions for every file: 1152×648, 1280×720, 1920×1080 and 2560×1440.
- Verified all 24 LFS-backed files against their pointer object IDs; `git lfs fsck` also passed. The other 44 files are ordinary Git PNG blobs.
- Inspected the 1152×648 sheet for every class, plus the 2560×1440 Ranger and Thief sheets. The inspected images are decoded, legible contact sheets without visible file corruption or edge truncation. Ranger and Thief show the four requested presentation modes without essential frame content crossing the image edge.

## Blocking coverage gap

The existence of four correctly sized files per class does not mean that four presentation modes were captured. Only the Ranger and Thief manifests declare fresh live evidence for all four modes (`normal`, `crowded`, `reduced_motion`, `photosensitivity_safe`), covering 2/17 classes and 6/51 weapons. The remaining 15 class packages expose four resolution variants of legacy per-weapon timeline/contact sheets and do not declare those four live modes.

Those legacy sheets cannot establish, for every ultimate and every required mode, that player-critical hazards, player state, and HUD remain readable. This is a missing-evidence failure under acceptance criteria 5 and 7, not an image-corruption failure.

## Evidence

- `capture-integrity.tsv`: path, storage form, decoded dimensions, bytes, SHA-256, LFS OID and manifest OID for all 68 files.
- `manifest-coverage.json`: strict manifest-derived class/weapon and four-mode coverage.
- `git-lfs-fsck.log`: hydrated LFS integrity result.

No product file was changed during this inspection.
