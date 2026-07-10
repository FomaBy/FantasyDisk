# SCRUM-958 — Enlarged Codex entity and artifact images

Статус: done
Версия: 0.2.1
Jira: SCRUM-958
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-958`
Branch: `codex/scrum-958-icon-fit`

## Scope And Locks

Runtime integration only: `scripts/ui/codex_image_fit.gd`, Codex image-routing
hunks in `scripts/ui_screens.gd`, focused Codex tests, this mirror, Codex UI
system documentation and runtime screenshot evidence. `ProgressionData`,
`CodexData`, character/monster/artifact source PNGs and gameplay are read-only.

SCRUM-954 already owns and has landed the accepted SCRUM-1017 screen geometry.
SCRUM-958 preserves those exact frame content zones and changes only how actual
canonical entry images are fitted inside the existing 88×96 list and 236×248
dossier image areas. Existing PixelLab character/monster sources and the
independently accepted SCRUM-957 artifact pack are reused; no redraw or new
generic category art is in scope.

## Architecture Decision

`CodexImageFit` builds immutable cached `AtlasTexture` views keyed by canonical
source path, policy and destination aspect ratio. It never copies pixels or
modifies source assets. The non-transparent used rectangle is padded and then
expanded to the destination aspect ratio without excluding any visible alpha:

- characters: 8% reserve, bottom-center anchor;
- monsters: 4% reserve, centered contain; only transparent outer canvas is
  removed;
- artifacts/shop items: 10% reserve, centered contain.

Every view records source path, policy, alpha rect, view region, source size and
anchor as testable metadata. List and dossier builders pass explicit
`texture_path` and `image_policy`; missing canonical entity/artifact paths are a
test failure, not an accepted generic fallback. Repeated sources (for example
mini-elites sharing an elite portrait) reuse the same cached view.

## Implementation Result

- 17 character rows/details use alpha-fit bottom-centered full-frame sprites.
- 31 monster rows/details use actual centered monster/boss art without cropping
  visible pixels.
- 154 artifacts plus 7 shop items resolve their canonical icon paths; the five
  accepted SCRUM-957 icons are explicitly covered.
- Russian canonical names remain centered and no raw ids, English duplicates or
  category emblems were added.
- Existing 122×114 image wells, 300×300 dossier frame, frame margins,
  discovery/locked tinting, lazy section cache and gamepad behavior remain
  unchanged.

## Verification Result

Focused headless and windowed matrix `tests/codex_scrum958_image_fit_test.gd`
passes at 1280×720, 1920×1080 and 2560×1440. It checks all 209
character/monster/artifact projections in both list and dossier (1,254 fitted
render assertions), canonical paths, alpha containment, readable projected
size, policy/anchor metadata and frame-zone containment. It creates 392 cached
views across the two authored destination aspects.

`tests/codex_scrum954_layout_test.gd` and the shared runtime smoke contract were
migrated to unwrap canonical paths from fitted `AtlasTexture` views. Independent
read-only code review caught and then rechecked the edge/full-canvas reserve
case; the final helper uses virtual transparent `AtlasTexture.margin`, and the
test independently derives alpha, actual region, margin, output size and every
per-side reserve. Re-review verdict: PASS with no remaining actionable finding.

All final commands ran through `tools/godot_gate.py` and passed:

- `codex_scrum958_image_fit_test.gd` (headless and windowed);
- `codex_scrum954_layout_test.gd`;
- `codex_data_smoke_test.gd`;
- `asset_reference_integrity_test.gd`;
- `dark_fantasy_ui_theme_test.gd`;
- `ui_no_overlap_matrix_test.gd`;
- `gamepad_menu_focus_test.gd`;
- `gamepad_full_flow_smoke_test.gd`;
- `runtime_smoke_ui_test.gd`;
- `runtime_smoke_test.gd`.

The dummy-renderer null screenshot diagnostic in the runtime suite is the known
non-fatal headless capture warning; both runtime suites exit 0. A separate
independent QA owner is still required before Jira may move from
`Контроль качества` to `Готово`.

## Runtime Evidence

- `docs/design/previews/scrum958_codex_image_fit/codex_characters_1280x720.png`
- `docs/design/previews/scrum958_codex_image_fit/codex_monsters_1920x1080.png`
- `docs/design/previews/scrum958_codex_image_fit/codex_artifacts_2560x1440.png`

The full transient 3×3 section/resolution screenshot matrix and fit report are
generated under `build/qa/scrum958/` during implementation and removed with the
task worktree after committed evidence is pushed.

## QA-Вердикт — 2026-07-10

Статус: PASSED

- QA worker: `codex-qa-scrum-958-20260710` (`/root/audit_qa`), Codex lane.
- Fresh base: `origin/dev` `1b27a39b24112bc5ce053be8da2927fe7b39b323`.
- Canonical inventory: PASSED — 17 characters, 31 monster projections and 161
  artifact/shop projections resolve exact canonical paths and Russian titles;
  every entry is checked in both list and dossier at 1280×720, 1920×1080 and
  2560×1440. Generic fallback, raw ids and English duplicates were not found.
- Independent alpha/AtlasTexture oracle: PASSED — 209 projections, 418
  list/detail fit checks and 392 unique cached views. Real source pixels,
  `AtlasTexture.region`, `margin`, `get_size()` and actual Canvas-rendered alpha
  bboxes were derived independently of implementation metadata.
- Reserve/anchor contract: PASSED — character 8% per side with bottom-center,
  monster 4% centered and artifact/shop 10% centered. Four edge-touching and
  three full-canvas canonical sources preserve virtual reserve without cropping
  visible alpha.
- Cache contract: PASSED — repeated list/detail/viewport visits reuse the same
  immutable instances; cache remains exactly bounded to 392 unique
  path/policy/aspect views.
- Windowed visual matrix: PASSED for characters, monsters and artifacts on all
  three supported resolutions. Separate 720p locked-artifact and 1080p
  full-canvas elite captures also pass. Content remains inside empty image/list/
  dossier zones and no image, label, chip, scrollbar or selection state covers
  frame ornament.
- Locked/discovery: PASSED — silhouette, dimmed row, `Заперто` chip and Russian
  unlock condition remain intact; discovery persistence/reverse coverage is
  unchanged.
- Gamepad: menu/core/movement/combat/in-run/rebind PASS; full-flow smoke PASS in
  three consecutive runs.
- Regression PASS: SCRUM-954 layout, Codex data, asset references, dark-fantasy
  theme, UI no-overlap matrix, display resolution, runtime UI, animation, meta
  progression, melee targeting, target-query cache and full runtime smoke.
- Defects in SCRUM-958 scope: none. Production code/assets were read-only during
  independent QA.

Transient QA evidence was created only under ignored `build/qa/scrum958/` and
`build/qa/scrum958-independent-qa/`. The disposable QA worktree and `.godot`
cache are removed after commit/push; the final Jira comment records exact disk
cleanup.

Thread cleanup: collaboration subagent QA is not a standalone Codex app worker
task; the active parent user task must not be archived.
