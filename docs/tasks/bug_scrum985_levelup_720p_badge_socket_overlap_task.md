# BUG: Level Up 720p — advisor-бейдж перекрывает сокет и наградную иконку

Статус: done
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

- [x] Badge rect и socket ornament rect disjoint на `1280x720`, `1920x1080`,
      `2560x1440`.
- [x] Badge rect и reward-icon rect disjoint на той же матрице.
- [x] Полная русская подпись advisor-бейджа читается без clipping/ellipsis.
- [x] Ровно три карточки, icon-safe containment, `Позже` и no-outer-frame
      контракт SCRUM-985 не изменены.
- [x] Focus не меняет геометрию карточки, бейджа, сокета и иконки; hover/pressed
      используют те же fixed Control rects/styles без layout mutation.
- [x] Focused Level Up capture/test и `ui_no_overlap_matrix_test.gd` явно
      проверяют badge-vs-socket/icon disjointness и больше не false-green.
- [x] `runtime_smoke_ui_test.gd`, `gamepad_inrun_ui_test.gd` и
      `gamepad_menu_focus_test.gd` проходят.
- [x] `gamepad_full_flow_smoke_test.gd` проходит.
- [ ] Полный `runtime_smoke_test.gd` проходит после release активного
      Claude-lock на umbrella smoke.

## Handoff

QA runtime не меняет. `/root` принял SCRUM-1032 как явно combined scope с
активным SCRUM-981: оба тикета используют те же уже locked
`scripts/ui_screens.gd` и `tests/ui_no_overlap_matrix_test.gd`, поэтому второй
конфликтующий worker/worktree не создаётся.

## Implementation result

- `_level_up_card_plan()` теперь всегда резервирует отдельный badge row для
  всего набора карточек, включая compact tier; бюджетный цикл уже умеет
  сокращать глубину описания/дельт, поэтому накладывать контент на сокет больше
  не требуется.
- Capture oracle теперь завершается кодом 1 при icon-safe, disjointness,
  complete-label или focus-stability регрессии; no-overlap matrix повторяет
  независимые runtime-ассерты. После независимого review оба oracle дополнены
  обязательным наличием advisor badge и сравнением socket/title top всех трёх
  карточек, поэтому исчезнувший бейдж или несимметричный reserved row также
  больше не дают false-green.
- Новый 1280x720 rect: badge `Rect2(334,240,150,31)`, socket
  `Rect2(379,278,60,60)`, icon `Rect2(392,291,34,34)`; оба intersection пусты.
- 1280x720, 1920x1080, 2560x1440: `icon safe=true`,
  `badge/socket disjoint=true`, `badge/icon disjoint=true`,
  `label full=true`, `focus stable=true`.
- PASS: `tools/capture_scrum985_level_up.gd`,
  `tests/level_up_advisor_test.gd`, `tests/ui_no_overlap_matrix_test.gd`,
  `tests/runtime_smoke_ui_test.gd`, `tests/gamepad_inrun_ui_test.gd`,
  `tests/gamepad_menu_focus_test.gd`, `tests/gamepad_full_flow_smoke_test.gd`,
  `tests/dark_fantasy_ui_theme_test.gd`.
- Independent re-review: FINAL PASS; обязательное наличие бейджа и одинаковые
  socket/title tops всех трёх карточек проверены, остаточных findings нет.

## Final routing (2026-07-10)

- Fix `6b0e25cf6` and umbrella acceptance `575951159` are in `origin/dev`.
- Full merged-context runtime smoke passed after the final rebase.
- SCRUM-1032 and parent SCRUM-985 are both back in independent QA; all shared
  locks are released.
- Disk cleanup: removed the shared `.godot` cache (444 MB).
