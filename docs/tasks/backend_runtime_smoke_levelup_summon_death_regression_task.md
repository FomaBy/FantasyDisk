# Back-end: Runtime Smoke Blockers — Level-Up Return Button + Ally Death Test

Статус: in_progress
Приоритет: high
Роль: Back-end (UI/runtime smoke)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Design/Animator handoff from SCRUM-399
Jira: SCRUM-402

## Context

During Design verification for SCRUM-399, summon art/import/animation checks
passed, but two runtime/test checks failed for reasons outside Design scope.
Design did not change gameplay, level-up logic, cleanup logic, SpriteFrames
resources or GDScript behavior.

## Blocker 1 — Runtime Smoke Level-Up Return Button

Command:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Failure:

```text
ERROR: Expected a labelled level-up return button after deferring.
tests/runtime_smoke_test.gd:1051
```

Relevant context:
- Existing Back-end/UI tasks around this flow are already marked done:
  `ux_levelup_fab_return_button_dedup_task.md`, SCRUM-123;
  `backend_levelup_buttons_beautify_and_uncrop_task.md`, SCRUM-348.
- Current failure happens before runtime smoke reaches the summon visual checks.

## Blocker 2 — Summoner Strengthening Test Death Lifecycle Expectation

Command:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/summoner_strengthening_test.gd
```

Failure:

```text
ERROR: Summoner strengthening: Expected AllyMinion to queue_free after lethal damage.
```

Likely cause:
- SCRUM-379 introduced animated/full-frame death lifecycle for entities.
- `AllyMinion` can now play a `death` row before cleanup.
- The focused summoner test appears to still assert immediate `queue_free`
  after lethal damage rather than validating the animated-death cleanup contract.

## Requirements

- Fix the level-up return button runtime contract or update the runtime smoke
  expectation to the intended current UX.
- Update `tests/summoner_strengthening_test.gd` to respect the current
  `AllyMinion` death lifecycle without weakening the once-only cleanup invariant.
- Do not change Design assets.
- Preserve gameplay damage, summon targeting, death rewards and balance.

## Acceptance Criteria

- [ ] `tests/runtime_smoke_test.gd` passes.
- [ ] `tests/summoner_strengthening_test.gd` passes.
- [ ] `tests/animation_smoke_test.gd` still passes.
- [ ] If UX behavior changed intentionally, update relevant docs/changelog.
