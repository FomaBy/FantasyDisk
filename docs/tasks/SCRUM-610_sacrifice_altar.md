# SCRUM-610 - Sacrifice Altar Route Node

Статус: done (backend-loop-2 reverify 2026-06-28; ready for QA).
Jira: SCRUM-610
Role: Backend
Lane: Codex rescue/follow-up
Owner: backend-loop-2

## Scope

Add a non-combat route node where the player trades current health for
permanent run power.

Locked paths:
- `scripts/main.gd`
- `scripts/route_map_screen.gd`
- `scripts/event_data.gd`
- `tests/event_data_smoke_test.gd`
- `tests/runtime_smoke_test.gd`

## Result

Current `origin/dev` contains the SCRUM-610 implementation from `61eff04a`:
- `MAP_NODE_DEFINITIONS["altar"]` defines the altar route type.
- `RouteMapScreen._place_altar_node()` places exactly one altar before route
  connections are assigned.
- Altar route nodes carry `event_id = "sacrifice_altar"` and open the fixed
  event screen.
- `EventData` defines `sacrifice_altar` with three health-percent-cost choices
  that apply permanent run stats/mods and do not grant combat or artifacts.

Backend-loop-2 reverified this after the previous QA RED reported that the
implementation was missing from `origin/dev`.

## Verification

- PASS: `tests/event_data_smoke_test.gd` (`29` events, `12` EV risky/safe
  pairs).
- PASS: `tests/runtime_smoke_progression_economy_test.gd` (`16` event EV rows,
  exit code 0). The run emitted known clean-import asset/AttackVfx noise after
  printing the pass lines.
- Static evidence: `rg` confirms `MAP_NODE_DEFINITIONS["altar"]`,
  `_place_altar_node`, `event_id = "sacrifice_altar"`, and the fixed
  `sacrifice_altar` event are present on `origin/dev`.
