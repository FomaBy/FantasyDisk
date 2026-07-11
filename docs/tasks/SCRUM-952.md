# SCRUM-952 — Hero Select trait, strengths and weaknesses copy

Статус: done
Версия: 0.2.1
Jira: SCRUM-952
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-next2`

## Scope

- shared player-facing class-trait data and Codex projection;
- Hero Select dossier hierarchy `Особенность` → `Плюсы` → `Минусы`;
- responsive 720p / 1080p / 2K fit and frame-safe QA;
- PixelLab-first mockup/spec and focused regression coverage.

No Hero Select frame, portrait, animation, stat, ascension or carousel art is
replaced. Canonical trait mechanics come from SCRUM-953 and
`docs/design/class_traits_registry.md`.

## Progress

- Jira claimed and exact locks recorded.
- SCRUM-953 is `Готово`; all 17 final traits are present in the canonical
  registry and current `CLASS_TRAITS` data.
- PixelLab mockup job `c72b6dba-895e-4f6a-93a1-1a5a36934a54` submitted.
- Pre-generation content-zone plan validated as `ready_for_image`.
- PixelLab source accepted after visual review. The first composite was rejected
  for crossing the center ornament; remeasured zones now pass `fit_report.json`
  and stay inside the three empty bands.
- Shared short trait copy, Codex projection and native Hero Select hierarchy are
  implemented. Canonical sections have no line cap/ellipsis; dossier scrolling
  is focusable and resets when the hero changes.
- Reviewer-found source drift is corrected: Sniper/Priest/Druid registry status
  is implemented, Priest no longer promises weapon sustain, and Druid mentions
  the implemented Wild Force Aura.

## Implementation result

- `CLASS_TRAITS` now carries concise `short_description` copy for all 17
  classes while preserving detailed mechanics in `description`.
- Canonical `CHARACTER_CONFIGS.strengths/weaknesses` were shortened into
  concrete selection copy; Codex keeps projecting those same fields.
- `CodexData.characters()` projects one shared `trait` record with id, title,
  short description and details.
- Hero Select renders `Особенность — <title>: <copy>` → `Плюсы:` → `Минусы:`
  before extended prose. These labels have no line cap or ellipsis, use full
  tooltips, and never leave `HS4DossierScroll`.
- The dossier scroll is keyboard/gamepad focusable, resets on every hero change,
  and stays inside the existing frame content area. No frame/art/portrait/stat/
  ascension/carousel geometry changed.

## Verification

- `hero_select_scrum952_trait_copy_test.gd`: PASS headless and actual Metal
  windowed, all 17 heroes at 1280×720 / 1920×1080 / 2560×1440; 1080p/2K show
  all three decision sections without scrolling, 720p proves scroll reachability;
  windowed teardown is clean with zero ObjectDB/resource/Ogg lifecycle errors.
- Visual inspection: final Metal captures at all three target viewports keep
  content inside the dossier and outer frame ornaments. An intermediate layout
  that hid plus/minus copy below generic prose was rejected and reordered.
- PASS: `hero_select_pixellab_layout_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `codex_data_smoke_test.gd`, `progression_data_character_contract_test.gd`,
  `gamepad_menu_focus_test.gd`, `gamepad_full_flow_smoke_test.gd`,
  `runtime_smoke_ui_test.gd`, and full `runtime_smoke_test.gd` (known dummy
  renderer screenshot diagnostic only).

Post-rebase green gate on fresh `origin/dev` `4b8b89f73`: focused SCRUM-952 and
no-overlap PASS; the first parallel full-runtime attempt was invalidated by a
shared `user://` autosave race, then the authoritative isolated HOME/XDG rerun
passed completely. Implementation commit: `6812188f5`.

Disk cleanup: pending post-land removal of the 446 MiB task `.godot/` cache,
transient `build/qa/scrum952` captures and task worktree.

Thread cleanup: not a disposable worker thread.
