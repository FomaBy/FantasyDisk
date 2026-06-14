# BUG: Runtime smoke victory flow misses required player-facing victory text

Статус: done
Приоритет: high
Роль: Back-end (UI/runtime smoke)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator handoff from SCRUM-370 runtime verification
Jira: SCRUM-385

## Context
Animator SCRUM-370 completed full-frame death animation integration and ran the
required runtime regression smoke because SpriteFrames resources changed.
Animation validation passed, but the umbrella runtime smoke fails outside
Animator scope in `_test_victory_flow`.

Failing command:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/sergeyfomin/Documents/AI\ Agent \
  --script res://tests/runtime_smoke_test.gd
```

Current failure:

```text
ERROR: Expected victory screen text to include 'Победа'.
GDScript backtrace:
  [0] _test_victory_flow (res://tests/runtime_smoke_test.gd:2968)
```

Relevant prior source of truth:
- `docs/tasks/backend_victory_screen_player_facing_text_task.md` / SCRUM-148
  required player-facing Russian victory copy and previously passed QA.
- `docs/tasks/bug_feedback_webhook_image_attachment_missing_task.md` already
  observed the same unrelated runtime smoke churn while working on SCRUM-374.

## Scope
Back-end/UI test fix only. Do not change animation assets, SpriteFrames, boss
death lifecycle, gameplay balance, targeting, damage, spawn rules, or rewards.

## Requirements
- Inspect the current victory flow and determine whether the actual player-facing
  screen lost the required Russian victory copy or the smoke test is collecting
  text from the wrong state/timing.
- Restore the SCRUM-148 contract: victory screen text visible to the player must
  include `Победа`, `Финальный босс повержен`, `Очки наследия`, and `Возвышения`
  without internal tokens such as `Meta points`, `asc_`, `_id`, `berserk_asc`.
- Keep the global UI frame safe-zone rule: do not place text/buttons/content on
  decorative frame borders.
- Re-run `tests/runtime_smoke_test.gd`.
- If the fix changes UI copy or end-run state, update relevant docs/CHANGELOG.

## Acceptance Criteria
- [x] `tests/runtime_smoke_test.gd` passes.
- [x] Victory player-facing text still satisfies SCRUM-148 localization/privacy
  contract.
- [x] No animation or gameplay/balance changes are made.

## Blocks
- `docs/tasks/animation_integrate_all_move_attack_death_states_task.md` /
  SCRUM-370 final runtime verification.

## Result
Done 2026-06-14.

- Root cause: runtime smoke killed the boss and waited only two frames before
  reading the victory screen. After SCRUM-379/SCRUM-370 full-frame death
  lifecycle work, boss death cleanup and victory UI can arrive asynchronously
  relative to that fixed two-frame window.
- Fixed the smoke by waiting with a bounded 120-frame timeout until combat is
  inactive and the actual player-facing victory screen text includes `Победа`.
  The existing SCRUM-148 contract assertions remain unchanged: required Russian
  strings are still checked and internal tokens (`Meta points`, `asc_`, `_id`,
  `berserk_asc`) remain forbidden.
- No UI copy, gameplay, animation assets, SpriteFrames, boss lifecycle visuals,
  balance, targeting, spawn, damage or rewards were changed.

Verification:
- `git diff --check -- tests/runtime_smoke_test.gd` — PASS
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS
