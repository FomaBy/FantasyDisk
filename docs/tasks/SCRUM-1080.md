# Main Menu: объединить благодарности и текущую версию справа внизу

Статус: done
Версия: 0.2.1
Jira: SCRUM-1080
Контур: Codex
Owner: coordinator/root
Thread: /root
Locked paths: Jira coordination, this mirror; implementation split into SCRUM-1081/1082/1083

## Цель

Собрать в правом нижнем углу Main Menu единый utility-блок: умеренно
увеличенная icon-only кнопка благодарностей с мягким свечением располагается
непосредственно слева от текущей версии игры. Версия читается динамически из
`application/config/version`. Колонка основных действий остаётся на исходном
месте.

Решение пользователя от 2026-07-12 supersedes первоначальный вариант с
благодарностями слева внизу.

## Декомпозиция

- `SCRUM-1081` — Design geometry/mockup/source-reuse handoff.
- `SCRUM-1082` — Back-end runtime placement, glow, version source and tests.
- `SCRUM-1083` — independent QA responsive matrix.

## Result

- Gratitude and the current runtime version now form one lower-right utility
  cluster; the icon sits immediately left of the version.
- The accepted gratitude asset/callback/a11y/SFX are reused, the hitbox is
  modestly larger, and a bounded procedural glow was added.
- The version remains dynamic from `application/config/version` and the main
  action column keeps its accepted SCRUM-1059 position.
- Design, Back-end and independent QA evidence live in `SCRUM-1081`,
  `SCRUM-1082` and `SCRUM-1083`.

## QA PASSED

Independent SCRUM-1083 verification passed the five-resolution matrix, live
resize, focus/gamepad flows, frame-safe visual inspection, focused tests and
UI/full runtime smoke. Bugs: none.

Disk cleanup: QA and implementation caches/captures/sidecars removed; the task
worktree is removed by the coordinator after the pushed result is confirmed.
