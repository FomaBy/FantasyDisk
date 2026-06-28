# SCRUM-537: Route map central chest artifact node

Jira: SCRUM-537
Статус: done
Контур: Codex
Owner: Back-end / codex-background-backend-agent
Locked paths: `scripts/route_map_screen.gd`, `scripts/main.gd`, `tests/route_chest_artifact_test.gd`, `docs/design/systems/route_map.md`, `docs/design/systems/progression_balance.md`, `docs/design/current_game_state.md`, `docs/design/content_registry.md`

## Scope

Back-end runtime implementation for the current-sprint `chest` route node.
Design icon dependency SCRUM-536 is done and QA-passed; this task does not draw
or alter art assets.

## Implementation Notes

- Midpoint convention: lower-middle non-boss row. With current 10 activity rows,
  this is row index `4`.
- Placement order preserves existing route guarantees: generate rows, place two
  required shops, place one chest into the central row without replacing a shop,
  append boss, assign route connections.
- Chest activation reuses the existing mandatory artifact reward UI and sampler:
  `ProgressionData.elite_artifact_choices(route_scaling_stage(), 3)`.

## Acceptance Evidence

- `tests/route_chest_artifact_test.gd` — PASS.
- `tests/route_node_preview_test.gd` — PASS.
- `tests/event_data_contract_check.gd` — PASS; confirms existing random events
  and `random_artifact` contract remain valid.
- `tests/runtime_smoke_test.gd` — PASS.

## Result

Implemented central route chest runtime hook:
- generated route contains exactly one `chest` node at lower-middle row index `4`
  for the current 10 non-boss activity rows;
- required two-shop placement and first two battle-only rows are preserved;
- chest uses `assets/sprites/map_icons/map_chest_artifact.png` from SCRUM-536;
- opening chest shows the existing mandatory 3-card artifact reward flow;
- chosen artifact is applied once through the shared run reward path;
- after choosing, the route advances, autosave writes the checkpoint, and the
  completed chest node is no longer available.
