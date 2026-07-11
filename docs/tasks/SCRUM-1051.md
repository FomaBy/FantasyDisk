# SCRUM-1049 Back-end: унификация runtime UI и icon-only credits button

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1051
Контур: Codex
Owner: Back-end
Thread: /root/ui_unification_backend
Locked paths: `scripts/ui_screens.gd`, discovered shared UI helper/theme scripts, relevant `tests/*ui*`, `docs/design/systems/menus_ui.md`, backend result section in this file

## Scope

- Start with a read-only inventory of every user-facing `Button`/`TextureButton` and local style helper.
- Do not edit runtime UI until the SCRUM-1050 mockup/spec handoff exists.
- Consolidate the common FantasyDisk button family while preserving documented screen accents.
- Align Codex navigation, rows and actions with the shared kit.
- Replace `MainMenuCreditsButton` face text with the accepted icon-only asset in the top-right safe zone; keep navigation, focus, tooltip/accessibility and UI SFX.
- Add/update responsive/state/frame-safety tests and UI documentation.

## Acceptance criteria

- No unexplained one-off user-facing button style remains.
- Credits button has no face text, is readable as gratitude, and opens the existing Credits screen.
- Relevant UI matrix tests and `tests/runtime_smoke_test.gd` pass.

## Back-end read-only inventory (2026-07-11)

Runtime UI was not edited: SCRUM-1050 mockup/spec is still the implementation
gate required by `fantasydisk-ui-director`.

### Coverage

- `scripts/ui_screens.gd` is the main factory: 50 `_make_button(...)` call sites
  plus direct factories for action buttons, content rows/cards, settings fields,
  Hero Select controls and the prayer modal. The common action resolver is
  `_apply_fantasy_button_theme` / `_button_asset_type` /
  `_text_button_unique_id` / `_button_state_style` at lines 13873-14086.
- Canonical paths and safe margins live in `scripts/ui/ui_theme_paths.gd`:
  `MINIMAL_METAL_BUTTON_*` and the 15 `TEXT_BUTTON_UNIQUE_*` families at lines
  350-528.
- `scripts/pause_stats_menu.gd` owns four player-facing pause actions but copies
  the resolver locally in `_kit_button`, `_apply_kit_button_theme` and
  `_kit_button_state_style` at lines 1826-1895.
- `scripts/route_map_screen.gd::_draw_route_nodes` creates route-node Buttons
  through the common factory, then deliberately replaces their state styles in
  `_style_route_node_button` at lines 1280-1307.
- The only live `TextureButton` families are Atlas class medallions
  (`ui_screens.gd:3091`) and Atlas constellation sockets (`ui_screens.gd:3773`).
  They are semantic icon/sockets, not text-action plates.

### Intentional screen families to preserve

- action/navigation: shared text-button/minimal-metal kit;
- content rows: `_unified_apply_row_theme` (Hero stat rows/carousel slots, Codex
  entry rows);
- selectable cards: `_apply_atlas_choice_card_theme`,
  `_apply_level_up_card_atlas_theme`, `_apply_reward_card_theme`,
  `_weapon_card_theme`;
- settings input fields: `_settings_v6_apply_field_theme` for `OptionButton` and
  rebind fields; settings actions already return to the global kit through
  `_settings_v6_make_action_button`;
- Hero Select carousel arrows, Route nodes, Atlas medallions/sockets, combat
  Level-Up FAB and Battle Prayer hitboxes are documented shape/icon exceptions;
- Continue Run and keyboard rebind-conflict use the accepted @2K slot family via
  `_apply_overhaul_2k_button_theme` and should remain explicit exceptions unless
  SCRUM-1050 replaces them.

### Unexplained drift / exact consolidation points

1. `MainMenuCreditsButton` (`ui_screens.gd:677-716`) is the only player-facing
   action with five `StyleBoxEmpty` states and hand-written colors. It must become
   the SCRUM-1050 icon-only family while keeping `_show_credits_screen`, focus,
   tooltip/accessibility, `_connect_ui_sfx` and authored top-right inner-zone
   layout.
2. Codex action styling is order-dependent. `CodexBackButton` is global-kit
   styled at `ui_screens.gd:4891-4900`, but each tab is first named
   `CodexNavButton`, styled, then renamed `CodexTab_<id>` at 4955-4977. The
   resolver therefore sees a 260x104 generic button and selects
   `back_260x104`; `_button_asset_type`'s `codex_tab` branch is never used.
   The five state styles are then duplicated again only to change content
   margins. Codex entry rows at 5127-5150 correctly use the content-row family
   and are not action-button drift.
3. Pause duplicates the global resolver and hard-codes the same asset paths and
   thresholds in `pause_stats_menu.gd:1826-1895`. This is a guaranteed future
   anti-drift failure; both modules need one shared semantic family resolver.
4. `_apply_shop_leave_button_theme` (`ui_screens.gd:10199-10208`) is not
   Shop-only: it styles Shop leave plus Attribute Shop reroll/skip/action rows
   (`2574-2588`, `2645-2652`). It silently uses `minimal_metal_rebind` textures.
   Preserve the compact geometry if accepted, but rename/map it to an explicit
   `slim_action` family instead of borrowing the input-field visual.
5. The current resolver infers family from mutable `name`, face text and size.
   `_make_button` applies theme before most call sites assign their final name;
   later `_set_action_button_size` happens to repair many controls, but Codex
   proves this is not reliable. Family selection should be explicit metadata or
   an argument applied only after final name/size.

### Minimal implementation plan after SCRUM-1050 handoff

1. Add one shared button-family applicator next to
   `scripts/ui/ui_theme_paths.gd`; resolve explicit semantic families and record
   `ui_button_family` metadata. Keep card/slot/route/prayer exceptions explicit.
2. Route `ui_screens.gd` global actions and `pause_stats_menu.gd` actions through
   it; remove the Pause copy and replace the misleading Shop/rebind reuse with an
   explicit compact family.
3. Apply final Codex tab/back families after final name/size, preserving the
   SCRUM-954 frameless three-column geometry and Codex content-row family.
4. Integrate the accepted gratitude icon with `text == ""`, retained node name,
   callback, tooltip/accessibility, focus and UI SFX; derive its exact hitbox from
   the SCRUM-1050 safe-zone spec and keep it inside the gold-shell authored inner
   rect on fresh layout and live resize.

### Tests to add/update

- new focused family inventory gate: every visible user-facing `Button` /
  `TextureButton` must expose an approved `ui_button_family` or a documented
  specialty-family allowlist; no raw unexplained state override remains;
- `tests/codex_scrum954_layout_test.gd`: assert tab/back family IDs, all five
  state textures/margins and geometry-stable state sizes;
- `tests/scrum981_gold_menu_shell_test.gd` and
  `tests/ui_no_overlap_matrix_test.gd`: icon-only Credits (`text == ""`, accepted
  icon path, tooltip/focus), authored-inner containment, peer disjointness and
  fresh/live-resize equality at 1280x720, 1920x1080 and 2560x1440;
- `tests/dark_fantasy_ui_theme_test.gd`: validate the shared resolver against
  `UIThemePaths` state paths and `content margins >= texture margins + reserve`;
- `tests/runtime_smoke_ui_test.gd` / `tests/runtime_smoke_test.gd`: Credits open,
  Back/Escape return and existing navigation remain intact.

Inventory only; tests were not run and no runtime files were changed.

## Back-end implementation result (2026-07-11)

Status: implementation complete in shared worktree; root integration/commit and
final full-runtime rerun remain.

Implemented:

- added `scripts/ui/ui_button_family.gd` as the semantic source of truth for
  action/text/minimal families and documented specialty families;
- global actions recompute inferred family after final name/size, while explicit
  screen families persist through later sizing calls;
- Codex tabs now apply `minimal/codex_tab` after their final node name and size;
  Back remains `text/back_260x104`, entry cards remain `content_row`, and every
  state keeps identical content margins;
- Pause dossier actions now consume the shared resolver instead of copied path,
  margin and size-threshold tables;
- compact Shop/Attribute actions use explicit `slim_action` semantics rather
  than presenting themselves as rebind fields; current accepted slim source and
  geometry are preserved;
- cards, rows, Settings fields/toggles, Route nodes, Atlas medallions/sockets,
  Hero carousel arrows, prayer cards, combat FAB and @2K controls are explicitly
  tagged specialty families rather than unexplained overrides;
- integrated PixelLab gratitude source
  `assets/sprites/ui/icons/credits/ui_icon_gratitude.png` (256×256 RGBA; source
  object `c1c1c353-e56e-405b-9adf-f1e6bd993152`) into
  `MainMenuCreditsButton`: empty face text, icon-only rendering, visible
  hover/focus/pressed states, tooltip/accessibility metadata «Благодарности»,
  existing Credits callback and UI SFX;
- exact responsive Credits rects are `(1059,137,64,64)`,
  `(1624,193,72,72)`, `(2173,257,88,88)` for 720p/1080p/1440p; the formula uses
  the shell-safe rect plus the authored 24/24/32 reserve and matches on live
  resize;
- updated `docs/design/systems/menus_ui.md` with the runtime contract.

Tests:

- PASS `tests/scrum1051_ui_button_family_test.gd` (includes Credits open/back
  flow);
- PASS `tests/codex_scrum954_layout_test.gd`;
- PASS `tests/scrum981_gold_menu_shell_test.gd`;
- PASS `tests/ui_no_overlap_matrix_test.gd` (includes the complete existing
  screen/resolution inventory family audit);
- PASS `tests/dark_fantasy_ui_theme_test.gd`;
- PASS `tests/runtime_smoke_ui_test.gd` (known non-fatal dummy-renderer texture
  capture diagnostic only);
- PASS `tests/audio_integration_test.gd`;
- BLOCKED `tests/runtime_smoke_test.gd` before suite execution by unrelated
  pre-existing shared-tree duplicate artifacts
  `tests/hero_select_scrum980_ascension_layout_test.gd 2.uid` and
  `tools/capture_scrum985_level_up.gd 2.uid`; this worker did not delete files
  outside its locked scope.

Files changed by Back-end:

- `scripts/ui/ui_button_family.gd`;
- `scripts/ui/ui_button_family.gd.uid` (Godot-generated resource UID);
- `scripts/ui_screens.gd`;
- `scripts/pause_stats_menu.gd`;
- `scripts/route_map_screen.gd`;
- `tests/scrum1051_ui_button_family_test.gd`;
- `tests/codex_scrum954_layout_test.gd`;
- `tests/scrum981_gold_menu_shell_test.gd`;
- `tests/ui_no_overlap_matrix_test.gd`;
- `tests/runtime_smoke_test.gd`;
- `docs/design/systems/menus_ui.md`;
- this Back-end result section.

No commit/push performed by subagent, per root instruction. Disk cleanup: none
created. Next: root removes/routes the two unrelated duplicate UID artifacts,
reruns full runtime smoke, then performs Jira/Git integration.
