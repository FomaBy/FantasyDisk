# SCRUM-1070 — Atlas reset footer 420 px

Статус: done
Версия: 0.2.1  
Jira: SCRUM-1070  
Контур: Codex  
Owner: Back-end UI / Codex  
Thread: `/root/audit_new_sprint_tail/review_scrum1067_spec`  
Branch: `codex/scrum1070-atlas-respec-420`  
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1070-atlas-respec-420`

## Locked scope

- Atlas reset/footer-only hunk in `scripts/ui_screens.gd`;
- focused `tests/atlas_scrum1070_respec_button_test.gd`;
- `docs/design/mockups/scrum1070_atlas_respec_420/`;
- `docs/design/systems/meta_constellations.md` and
  `docs/design/current_game_state.md`;
- this mirror and scoped Jira sync metadata.

Excluded: constellation/Guild topology, schema, balance and currencies
(SCRUM-1068/1069), reset business logic, other screens and new art/assets.

## UI Director source decision

The accepted existing SCRUM-832 OpenAI
`docs/design/previews/meta40_atlas_mockup.png` already shows the wide left
footer reset plate. Runtime reuses the accepted OpenAI per-size
`text/standard_420x104` five-state asset package and its 9-slice/content-margin
contract. PixelLab redraw exception: `existing source reuse`; no new art or
fallback generation is part of this geometry-only task.

## Acceptance

- exact 420×72/88/104 visible/hit geometry on seven target sizes through 4K
  plus same-instance compact→large→compact live resize;
- both Russian labels fit one line inside content margins;
- explicit `text/standard_420x104` family in all states;
- footer/button/legend stay inside the empty Atlas frame content zone;
- tooltip, mouse/gamepad focus, popup cancel/confirm and per-scope full refund
  stay unchanged;
- focused Atlas, Metal/family, semantic, gamepad, no-overlap and runtime gates
  pass before landing.

## Result

- `AtlasRespecButton` uses the exact accepted `standard_420x104` family at
  420×72/88/104, with 21px compact and 23px medium/large action typography.
- Same-instance live resize refreshes the button, `AtlasSafeArea` margins and
  outer `AtlasFrame` 9-slice margins across both tier thresholds.
- Both labels, tooltip/focus, confirmation and scope-specific full refunds are
  preserved; constellation/Guild data and reset business logic are unchanged.
- Independent subagent re-review: PASS, no remaining findings.

## Verification

Post-integration base: `origin/dev` `e5c8d32a8`.

- `tests/atlas_scrum1070_respec_button_test.gd` — PASS (seven tiers through
  3840×2160, same-instance 648→900→2160→720, both reset scopes);
- `tests/meta40_atlas_screen_smoke_test.gd` — PASS;
- `tests/atlas_scrum970_clickability_test.gd` — PASS;
- `tests/semantic_typography_scrum1061_test.gd` — PASS;
- `tests/scrum1051_ui_button_family_test.gd` — PASS;
- `tests/dark_fantasy_ui_theme_test.gd` — PASS;
- `tests/gamepad_menu_focus_test.gd` — PASS;
- `tests/ui_no_overlap_matrix_test.gd` — PASS;
- `tests/runtime_smoke_ui_test.gd` — PASS;
- `tests/runtime_smoke_test.gd` — PASS (known non-fatal dummy-renderer texture
  capture warning only).

Disk cleanup: `.godot`, isolated `/tmp/fsd-scrum1070-*` user-data roots and
generated unrelated UID sidecars removed; task worktree removed after push.
