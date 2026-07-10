# SCRUM-981 — Unified Gold Menu Shell

Статус: in_progress
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

- [ ] UI Director mockup/spec records exact frame and content zones before
      runtime edits, with PixelLab provenance or accepted source reuse.
- [ ] A complete screen inventory documents every applied and excluded shell.
- [ ] Escape dossier/pause and route/menu surfaces use the shared family where
      appropriate without hiding gameplay or map-critical content.
- [ ] Combat HUD and Level Up remain intentionally without the large shell.
- [ ] No text, buttons, icons, portraits, hitboxes or scrollbars touch frame
      ornament at 1280×720, 1920×1080 or 2560×1440.
- [ ] Focused UI, no-overlap, theme and full runtime gates pass.
- [ ] Runtime screenshots/evidence cover the required resolution matrix.
- [ ] Jira, docs and `origin/dev` are synchronized; task artifacts are cleaned.

## Work Log

- 2026-07-10: Jira claim-first completed. Live collision audit found no active
  Claude UI/design locks. SCRUM-985 Level Up and SCRUM-975/1030 package paths
  were explicitly excluded before work began.
- 2026-07-10: UI Director required reading completed. Design inventory/spec was
  delegated inside the same `/root` ownership while runtime remains untouched.

Disk cleanup: pending; disposable worktree and generated caches will be removed
after pushed implementation and QA handoff.
