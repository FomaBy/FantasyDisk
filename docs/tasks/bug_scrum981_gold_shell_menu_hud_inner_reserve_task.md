# BUG: Gold shell menu HUD/FAB violate authored inner reserve

Статус: done
Приоритет: high
Роль: Back-end (UI runtime/tests)
Контур: Codex
Исполнитель: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-1036-gold-inner-reserve`
Jira: SCRUM-1036
Версия: 0.2.1
Найдено QA при тестировании: SCRUM-981
Locked paths: `scripts/ui_screens.gd`; `tests/scrum981_gold_menu_shell_test.gd`;
`tests/ui_no_overlap_matrix_test.gd`; SCRUM-981 geometry evidence/docs only

Branch/worktree: `codex/scrum-1036-gold-inner-reserve` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1036-gold-inner-reserve`

## Контекст

Принятый UI Director spec SCRUM-981 объявляет первые `24px` внутреннего
резерва (`32px` на 2560x1440) forbidden-зоной для текста, иконок, кнопок,
hitbox и scrollbar. Runtime меню привязывает общий `RunResourceHud` к
`raw_safe.position + Vector2(16, 8)`, а FAB — к той же верхней полосе.
Текущие focused/no-overlap тесты проверяют их только относительно raw
texture-safe rect и поэтому дают false-green.

## Воспроизведение

1. Взять `origin/dev` не ранее `02fc618de` с SCRUM-981 коммитами
   `f818a89d6`, `fb48f077c`, `575951159`.
2. Открыть Rest, Upgrade или Battle Reward на `1280x720`, `1920x1080` и
   `2560x1440`.
3. Сравнить фактические `global_rect` детей `RunResourceHud` и
   `UpgradeFabButton` с inner rect из
   `docs/design/mockups/scrum981_gold_menu_shell/spec.md`.

## Ожидание / Реальность

Authored inner rect:

- 1280x720: `Rect2(157,137,966,446)`;
- 1920x1080: `Rect2(224,193,1472,694)`;
- 2560x1440: `Rect2(299,257,1962,926)`.

Фактические live rect, которые остаются внутри raw safe rect, но выходят из
authored inner reserve:

- 1280x720: `UIIcon_hp=Rect2(154,125,21,21)`,
  `HudHPTrack=Rect2(179,127,258,16)`,
  `HudHPLabel=Rect2(179,127,258,17)`,
  `UpgradeFabButton=Rect2(1051,121,72,88)`;
- 1920x1080: `UIIcon_hp=Rect2(224,182,32,32)`,
  HP track/label начинаются на `y=186`, FAB — `Rect2(1624,177,74,91)`;
- 2560x1440: `UIIcon_hp=Rect2(293,240,42,42)`, HP track/label начинаются на
  `y=245`, XP/ULT icons — на `x=297 < 299`, FAB —
  `Rect2(2197,233,74,91)` и пересекает правый reserve.

Opaque local panel сам по себе не является находкой: QA измерил именно live
icons/labels/tracks и button hitbox. Outer ornament визуально не скрыт, но
опубликованный обязательный `texture margins + reserve` контракт не соблюдён.

## Acceptance Criteria

- [x] Menu-only resource HUD, его видимые дети и FAB полностью находятся внутри
      authored inner rect на 720p/1080p/1440p.
- [x] Live resize 2560x1440 -> 1280x720 пересчитывает те же inner-safe rect.
- [x] Route Map сохраняет собственные точные header/resource/scroll/FAB зоны.
- [x] Combat HUD и Level Up exceptions не меняются.
- [x] Focused SCRUM-981 и no-overlap oracle проверяют actual child/icon/text/
      button rect, а не только raw texture-safe rect.
- [x] Focused 981, no-overlap, theme, runtime UI, gamepad full-flow и полный
      runtime smoke проходят; внешний Robot-дефект SCRUM-1034 не маскируется.
- [x] Результат закоммичен, запушен в `origin/dev` и передан в независимый QA.

## Implementation result (2026-07-10)

- Raw `gold_shell_content_rect` сохранён как texture-safe контракт; отдельный
  `gold_shell_inner_rect` добавляет обязательный резерв `24px` / `32px`.
- Общий menu `RunResourceHud` заново раскладывается без накопленного scale и
  равномерно вписывается в authored header-left `72/88/104px`.
- Общий `UpgradeFabButton` равномерно вписан в точный top-right socket `72x72`;
  специализированная Route Map раскладка не менялась.
- На 720p Rest/Upgrade/Battle Reward используют единый верхний резерв `96px`;
  compact Battle Reward card height `224px` сохраняет panel/HUD gap и нижний
  texture-safe край.
- Focused oracle теперь проверяет реальные HUD icons/tracks/labels/FAB против
  inner rect и проход `2560 -> 1280 -> 2560`; no-overlap matrix проверяет тот же
  контракт на всей своей матрице.

Verification PASS: `scrum981_gold_menu_shell_test`, `ui_no_overlap_matrix_test`,
`dark_fantasy_ui_theme_test`, `runtime_smoke_ui_test`,
`gamepad_full_flow_smoke_test`, полный `runtime_smoke_test`. Известные два
`freed lambda capture` сообщения принадлежат отдельному Robot-багу SCRUM-1034;
smoke завершён `exit 0`.

Git/Jira routing: implementation `144371177` is in `origin/dev`; SCRUM-1036
and parent SCRUM-981 routed to independent production QA.
Disk cleanup: removed task `.godot` (445 MB); clean task worktree/branch removal
follows after this routing mirror lands.

## QA evidence

Независимая приёмка SCRUM-981 на `02fc618de`; product/runtime files QA не
менял. Связанный Jira verdict содержит полную матрицу rect и список зелёных
регрессионных гейтов.
