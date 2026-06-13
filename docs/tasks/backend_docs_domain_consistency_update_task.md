# Back-end Task: Domain Docs Consistency Update

Статус: blocked
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-195
Эпик: epic_full_project_quality_pass

## Scope

Refresh domain docs after the 0.1.4 class/content/UI growth.

## Documents

- `docs/design/systems/characters_weapons.md`
- `docs/design/systems/combat.md`
- `docs/design/systems/progression_economy.md`
- `docs/design/systems/ui_menus.md`
- `docs/design/systems/audio.md`
- `docs/design/current_game_state.md` as concise index/current summary.

## Requirements

- No gameplay/code changes.
- Cross-link reports from `docs/design/reviews/`.
- Keep content IDs aligned with `content_registry.md`.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## Blocked / Serialized (2026-06-13)

Blocked until the active content/UI queue stops moving the facts this task must
summarize. SCRUM-192 is closing character sprite registry drift, SCRUM-193 is
blocked on safe asset cleanup, and SCRUM-222 is blocked on a rejected UI kit.
Running the broad domain-doc refresh now would produce stale docs immediately.

Next unblock: resume after the active content/UI blockers above are either done
or explicitly deferred. Narrow task-local docs updates continue inside each
implementation task.
