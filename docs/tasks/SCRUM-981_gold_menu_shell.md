# SCRUM-981 — Unified Gold Menu Shell

Статус: done
Версия: 0.2.1
Jira: SCRUM-981
Контур: Codex
Owner: UI Design + Back-end/Codex `/root`
Thread/Worker: `root-scrum-981`
Приоритет: p1
Роль: Design + Back-end

## Scope And Locks

Combined Design/runtime scope is explicitly coordinated by `/root` because the
screen inventory, mockup geometry and integration use the same menu-shell safe
area. Locked paths/screens:

- unified non-combat shell sections in `scripts/ui_screens.gd`;
- `scripts/pause_stats_menu.gd` and `scripts/route_map_screen.gd` only where the
  audited screen inventory proves a missing shell hook;
- `docs/design/{mockups,references,previews}/scrum981_gold_menu_shell/`;
- `docs/design/systems/menus_ui.md`, `docs/design/current_game_state.md`,
  `docs/design/content_registry.md`;
- this mirror and SCRUM-981-specific focused tests/evidence.

Explicit exclusions:

- Level Up keeps the SCRUM-985 no-outer-frame contract;
- the live combat view/HUD never receives a large menu frame;
- do not edit the SCRUM-975/SCRUM-1030 Settings Game-tab design package;
- do not edit Claude-owned gameplay/class files or another worker's task paths.

Branch/worktree: `codex/scrum-981-gold-menu-shell` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-981-gold-menu-shell`,
created from fresh `origin/dev` `8d0f4be31`.

## Goal

Audit every live menu surface and give appropriate non-combat screens one
coherent hollow gold-edge shell based on the accepted PixelLab `meta40`
`frame_border` family. Content, input hitboxes and scroll lanes must remain in
the real empty interior at 1280×720, 1920×1080 and 2560×1440.

## Required Inventory Decisions

- `applied`: the full-screen shell is appropriate and present;
- `add`: the shell is appropriate but missing;
- `intentional exception`: the screen must remain frameless or use a local
  specialist frame because an outer shell would obscure gameplay/art/content;
- `covered by child task`: preserve a more specific accepted contract.

The inventory must cover main-menu family, Settings, Codex/Atlas, Hero/Weapon
Select, Route Map, pause/Escape dossier, shop, event, rest, upgrade, reward and
result screens, dialogs, Level Up and Combat HUD.

## Acceptance Criteria

- [x] UI Director mockup/spec records exact frame and content zones before
      runtime edits, with PixelLab provenance or accepted source reuse.
- [x] A complete screen inventory documents every applied and excluded shell.
- [x] Escape dossier/pause and route/menu surfaces use the shared family where
      appropriate without hiding gameplay or map-critical content.
- [x] Combat HUD and Level Up remain intentionally without the large shell.
- [x] No text, buttons, icons, portraits, hitboxes or scrollbars touch frame
      ornament at 1280×720, 1920×1080 or 2560×1440.
- [ ] Focused UI, no-overlap, theme and full runtime gates pass (all listed
      focused/matrix/theme/UI gates pass; full runtime awaits the active Claude
      ownership release for `tests/runtime_smoke_test.gd`).
- [x] Runtime screenshots/evidence cover the required resolution matrix.
- [ ] Jira, docs and `origin/dev` are synchronized; task artifacts are cleaned.

## Work Log

- 2026-07-10: Jira claim-first completed. Live collision audit found no active
  Claude UI/design locks. SCRUM-985 Level Up and SCRUM-975/1030 package paths
  were explicitly excluded before work began.
- 2026-07-10: UI Director required reading completed. Design inventory/spec was
  delegated inside the same `/root` ownership while runtime remains untouched.
- 2026-07-10: UI plan validation returned `ready_for_image` with zero errors or
  warnings. Accepted PixelLab references: Main Menu v3
  `7d9c5262-5448-40c0-beaf-2b7d4b6b1f58` (exact six 2×3 slots, SHA
  `a3f446d54cf2b1c2bdfbd2a4f2a097962aadf8c166c0a99869bf9a50597dbd85`)
  and Route Map v2 `1df5105f-5469-4a93-b93c-ebe839831ed0` (SHA
  `647fe73e85e3777dc6401f2fe9f920a411802d314f883f35eca04d2a8a62b0d6`).
  Rejected checkerboard and incorrect four-slot generations remain recorded in
  `docs/design/references/scrum981_gold_menu_shell/manifest.json`.
- 2026-07-10: runtime integrated the hollow production
  `assets/sprites/ui/meta40/frame_border.png` shell into Main Menu, Route Map,
  Rest, Upgrade, Battle Reward, Victory and Defeat. Main Menu uses exact 2×3
  geometry and 2D focus navigation; Route Map reserves header/title/resource,
  scroll, scrollbar and FAB zones; compact menu/result tiers keep 720–900p
  content inside the real frame interior. Codex, Level Up, Combat and specialist
  child-task screens remain explicit exceptions.
- 2026-07-10: focused gates PASS:
  `tests/scrum981_gold_menu_shell_test.gd`,
  `tests/scrum981_route_map_gold_shell_test.gd`,
  `tests/main_menu_title_no_overlap_test.gd`,
  `tests/ui_no_overlap_matrix_test.gd`,
  `tests/dark_fantasy_ui_theme_test.gd`, and
  `tests/runtime_smoke_ui_test.gd` (the known dummy-renderer screenshot warning
  remains non-fatal; suite prints PASS).
- 2026-07-10: windowed OpenGL capture PASS at 1280×720, 1920×1080 and
  2560×1440 for all seven live screens (21 PNGs: Main Menu, Route Map, Rest,
  Upgrade, Battle Reward, Victory and Defeat). Runtime screenshots and rect
  report: `build/qa/scrum981/`. Visual review confirms no content or hitbox
  touches the ornamental rails; the compact result summary remains fully
  visible above its action plate.
- 2026-07-10: independent review found a false-green live-resize gap, a version
  slot drift and incomplete screenshot coverage. Runtime now relayouts existing
  generic/result shells, cards, HUD/FAB and Route Map canvas on `resized`; the
  focused gate explicitly shrinks 2560×1440 to 1280×720 without rebuilding the
  screen. Main Menu version rects now match the spec exactly, and focused QA
  checks visible labels/icons/scroll lanes plus unclipped result summaries.
- 2026-07-10: final independent re-review PASSED after one additional compact
  Battle Reward defect was caught. `BattleRewardPreview` is capped to two lines
  and description to one line with intentional ellipsis (full copy remains in
  tooltip); the focused oracle now rejects both combined-minimum overflow and
  any full child rect outside `BattleRewardCardContent`. Regenerated 720p visual
  evidence is clean; no remaining actionable finding in reviewed scope.
- 2026-07-10: full `runtime_smoke_test.gd` and its obsolete Main Menu/Route Map
  assertions are intentionally not edited yet because active Claude engineer
  worktree `/private/tmp/fsd_wt/w10-soldier` owns a dirty copy. Jira heartbeat
  records this live coordination; all other available gates continue.

## Final routing (2026-07-10)

- Landed directly in `origin/dev` through `575951159`; implementation commits
  are `f818a89d6`, `fb48f077c` and umbrella assertion commit `575951159`.
- Final merged-context PASS: focused Main Menu and Route Map shells,
  SCRUM-986 centering, SCRUM-985/1032 capture, no-overlap matrix, dark-fantasy
  theme, runtime UI, gamepad full-flow and full `runtime_smoke_test.gd`.
- Jira routed to `Контроль качества`; shared UI and umbrella-test locks are released.
- Disk cleanup: removed the shared `.godot` cache (444 MB); tracked QA evidence
  remains in `build/qa/scrum981/`.
