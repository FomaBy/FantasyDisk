# BUG: Level Up 720p — advisor-бейдж перекрывает сокет и наградную иконку

Статус: in_progress
Jira: SCRUM-1032
Версия: 0.2.1
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-981 + SCRUM-1032 identical-lock fix`
Найдено QA при тестировании: `SCRUM-985`
Branch/worktree: `codex/scrum-981-gold-menu-shell` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-981-gold-menu-shell`
Locked paths: `scripts/ui_screens.gd`, `tests/ui_no_overlap_matrix_test.gd`,
`tools/capture_scrum985_level_up.gd`, task-unique evidence/mirror.

## Воспроизведение

1. Взять `origin/dev` с реализацией SCRUM-985 (`df25462f3`).
2. Запустить
   `python3 tools/godot_gate.py --path . --script res://tools/capture_scrum985_level_up.gd`.
3. Открыть capture `1280x720` и первую карточку с бейджем `ВЫЖИВАНИЕ`.

## Ожидание / Реальность

Ожидание: advisor-бейдж, орнамент сокета и наградная иконка не пересекаются;
полная русская подпись читаема; hover/focus/pressed не сдвигают геометрию.

Реальность на `1280x720`:

- `LevelUpRewardBadge`: `Rect2(334,259,150,31)`;
- `LevelUpRewardSocket`: `Rect2(379,259,60,60)`;
- их intersection: `Rect2(379,259,60,31)`;
- `UIIcon`: `Rect2(392,272,34,34)`;
- badge/icon intersection: `Rect2(392,272,34,18)`.

Бейдж закрывает верхние `31px` локального socket-ornament и `18px` из `34px`
высоты самой иконки. `1920x1080` и `2560x1440` визуально чистые.

## Evidence

- `docs/design/previews/scrum985_level_up_cleanup/runtime_1280x720.png`;
- Jira SCRUM-985 independent QA verdict от 2026-07-10;
- independent QA probe на `origin/dev` `23e15aed0`.

## Acceptance Criteria

- [ ] Badge rect и socket ornament rect disjoint на `1280x720`, `1920x1080`,
      `2560x1440`.
- [ ] Badge rect и reward-icon rect disjoint на той же матрице.
- [ ] Полная русская подпись advisor-бейджа читается без clipping/ellipsis.
- [ ] Ровно три карточки, icon-safe containment, `Позже` и no-outer-frame
      контракт SCRUM-985 не изменены.
- [ ] Hover/focus/pressed не меняют геометрию карточки, бейджа, сокета и иконки.
- [ ] Focused Level Up capture/test и `ui_no_overlap_matrix_test.gd` явно
      проверяют badge-vs-socket/icon disjointness и больше не false-green.
- [ ] `runtime_smoke_ui_test.gd`, Level Up gamepad full-flow и полный
      `runtime_smoke_test.gd` проходят.

## Handoff

QA runtime не меняет. `/root` принял SCRUM-1032 как явно combined scope с
активным SCRUM-981: оба тикета используют те же уже locked
`scripts/ui_screens.gd` и `tests/ui_no_overlap_matrix_test.gd`, поэтому второй
конфликтующий worker/worktree не создаётся.
