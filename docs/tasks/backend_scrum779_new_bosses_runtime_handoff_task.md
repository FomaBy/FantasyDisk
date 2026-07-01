# Back-end Task: SCRUM-779 New Bosses Runtime Integration

Статус: new
Контур: Codex
Owner: unassigned
Thread: n/a
Locked paths: scripts/boss.gd; scripts/combat_director.gd; scripts/progression_data_enemies.gd; scripts/codex_data.gd; scenes/Boss*.tscn; tests/runtime_smoke_boss_elite_test.gd; docs/design/content_registry.md; docs/design/current_game_state.md; docs/design/systems/enemies_bosses.md
Jira: SCRUM-794

## Autonomy / Approval
Пользователь заранее одобрил in-scope работу. Agents should not ask for routine
confirmation before editing project files, running tests, updating Jira/docs,
committing and pushing task-owned files.

## Context
SCRUM-779 delivered a Design-source boss package:

- Source manifest:
  `docs/design/references/bosses/pixellab_roster_redraw_2026_06/manifest.json`
- New boss concepts:
  - `skeletal_dragon` / Костяной Дракон
  - `bloodthorn_lion` / Шипастый Кровавый Лев
- PixelLab candidates:
  `assets/sprites/bosses/pixellab_candidates/`

SCRUM-779 did not change live boss scenes, boss rotation, balance, Codex unlocks
or route map selection.

## What Back-end Needs To Do
- Decide whether to introduce `skeletal_dragon`, `bloodthorn_lion`, or only one
  of them in the next gameplay pass.
- Add stable boss configs/scenes/mechanics for accepted new boss IDs.
- Add route/boss-pool integration only after mechanics and QA are ready.
- Add Codex discovery entries and meta unlock handling for new boss IDs.
- Keep current boss redraw candidates out of live runtime unless Design/Animator
  promotes them as accepted replacements.
- Update docs and run focused boss/elite runtime smoke.

## Acceptance Criteria
- New boss IDs have scenes, mechanics, unique pattern metadata, Codex entries and
  tests if implemented.
- Boss pool/route selection remains deterministic and does not reference missing
  scenes or assets.
- Current boss roster still passes `runtime_smoke_boss_elite_test.gd`.
- Docs and Jira comments state which SCRUM-779 candidate assets are live versus
  source-only.
