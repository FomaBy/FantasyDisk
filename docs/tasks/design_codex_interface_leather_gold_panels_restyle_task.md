# Задача Для Design-Агента: Переделать интерфейс — панели/окна в стиле «кожа+золото» (референсы пользователя)

Статус: done
Приоритет: high
Роль: Design (Claude-Designer обработка/9-slice/интеграция) → Back-end handoff
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-229

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Роль И Границы
Владелец — Claude-Designer (обработка сырого арта, 9-slice, ревью, интеграция,
коммит). Доп. генерация при нехватке — Codex Design с этими референсами.
Интеграция стайлбоксов в код — handoff Back-end (или Designer сам, если просто
замена panel-stylebox).

## Контекст (запрос пользователя)
«Переделать интерфейс — файлы PNG интерфейса лежат в папке references/interface».
Это `docs/design/references/interface/` — 5 PNG: цельный кит ПАНЕЛЕЙ/РАМОК
«тёмная кожа + золотая гравированная окантовка» (угловые кронштейны, заклёпки,
свечение по канту, прозрачный фон). Состав — см. README папки.

Связь с SCRUM-147: тот рестайл сведён к «кнопки = Parchment&WaxSeal, панели =
legacy». Этот кит — именно для ПАНЕЛЕЙ/ОКОН, которые остались legacy. Итог:
кнопки — пергамент+печать, панели/окна/плашки — кожа+золото (единый dark fantasy).

## Требования
1. **Обработать сырьё**: 5 ChatGPT-PNG (имена с пробелами) → отобрать, обрезать,
   привести к каноничным именам (например `ui_panel_leather_gold_square.png`,
   `ui_panel_leather_gold_wide.png`, `ui_bar_leather_gold_thin.png`,
   `ui_window_leather_gold_main.png`, `ui_check_leather_gold.png`), проверить
   alpha. Сырьё НЕ кладётся в live-ассеты — финал в `assets/sprites/ui/frames/`.
2. **9-slice**: для каждой рамки задать nine-patch margins (тянущаяся середина,
   неискажаемые углы/кронштейны/заклёпки) — корректное растяжение под любой
   размер панели.
3. **Карта замены**: применить кит ко ВСЕМ панелям/окнам интерфейса —
   пауза-досье, level-up, докачка, магазин, события, награда элитки, настройки,
   кодекс, hero select, HUD-плашки, тултипы, чипы, разделители, чекбоксы
   (галочка из набора). Таблица «текущий panel-stylebox → новый ассет» в отчёте.
4. **Согласовать с кнопками**: панели — кожа+золото, кнопки — пергамент+печать
   (SCRUM-147). Чтобы вместе смотрелось как один dark fantasy канон.
5. **Удалить/заменить legacy panel-фреймы** после интеграции (старые в backup,
   content_registry почистить). «no junk UI» — без лишнего декора.
6. Правило «UI не наползает»: новые рамки не ломают раскладки/отступы на
   1280x720 и 2560x1440.
7. Канон: обновить docs/design/systems/visual_style_assets.md (панель-кит).
8. Тест (smoke): экраны грузят новые panel-стайлбоксы (фактическое дерево +
   загрузка текстур), no-overlap ключевых экранов; скриншоты до/после в build/qa/.
9. CHANGELOG; content_registry.

## Files / Assets / IDs
- Сырьё: docs/design/references/interface/ (5 PNG, см. README)
- Финал: assets/sprites/ui/frames/ (новые panel/window/bar/check ассеты)
- scripts/ui_screens.gd, scripts/pause_stats_menu.gd (потребители panel-styleboxes)
- docs/design/systems/visual_style_assets.md, content_registry.md

## Acceptance Criteria
- [ ] 5 рамок обработаны (имена/alpha/9-slice), в assets/sprites/ui/frames/.
- [ ] Панели/окна/плашки/тултипы/чекбоксы переведены на кит «кожа+золото»; карта замены полная.
- [ ] Согласовано с кнопками-пергаментом; legacy panel-фреймы убраны.
- [ ] no-overlap; 6 smoke зелёные; скриншоты до/после в build/qa/; CHANGELOG/registry.

## Документация
visual_style_assets.md, content_registry.md, current_game_state.md.

## Dispatcher Note (2026-06-13)
Jira key `SCRUM-229` found in existing sync map/Jira and synced into this task. Dispatched to Design Codex thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. Dependency context: SCRUM-147/SCRUM-222 accepted wax-seal buttons and legacy panels; this task is the new leather+gold panel kit pass. Avoid touching `scripts/ui_screens.gd` while Back-end's serialized UI batch SCRUM-224..227 is active; create/update a Back-end handoff for integration if code/stylebox wiring is needed. If any rig/motion/animation scope appears, create/update an Animator handoff instead.

## Dispatcher QA Sync (2026-06-13)
Recorded Design result is READY FOR QA and Jira `SCRUM-229` is already in `Контроль качества`; local task status synced to `done` so Claude-QA can pick it up from the board. Jira remains in QA, not final `Готово`.

## Result / 2026-06-13 — READY FOR QA

Design-only pass completed without touching `scripts/ui_screens.gd`.

Source processing:

- Added reproducible pipeline `tools/build_leather_gold_ui_kit.py`.
- Processed the 5 raw user references from `docs/design/references/interface/`.
- Removed baked checkerboard background via edge flood-fill, cropped the real
  frame art, preserved alpha and resized into stable game/UI asset sizes.

Canonical leather+gold source kit:

```text
assets/sprites/ui/frames/leather_gold/ui_panel_leather_gold_square.png
assets/sprites/ui/frames/leather_gold/ui_panel_leather_gold_wide.png
assets/sprites/ui/frames/leather_gold/ui_bar_leather_gold_thin.png
assets/sprites/ui/frames/leather_gold/ui_window_leather_gold_main.png
assets/sprites/ui/frames/leather_gold/ui_check_leather_gold.png
```

Live replacement map:

| UI target | New source motive |
| --- | --- |
| `assets/sprites/ui/frames/dark_fantasy/ui_df_panel_frame.png` | leather+gold main window |
| `ui_df_level_panel_frame.png` | leather+gold main window |
| `ui_df_card_frame.png` | leather+gold square panel |
| `ui_df_tooltip_frame.png`, `ui_df_shop_frame.png`, `ui_df_stat_value_state_swatches.png` | leather+gold wide panel |
| `ui_df_hud_panel_frame.png`, `ui_df_hud_card_frame.png`, `ui_df_stat_row_frame.png`, `ui_df_stat_chip_frame.png`, `ui_df_section_divider.png` | leather+gold bar/thin bar |
| `assets/sprites/ui/frames/global/ui_*_frame.png` non-button frames | matching leather+gold scaled fallbacks |
| `assets/sprites/ui/frames/escape/ui_escape_panel_frame.png`, stat rows/groups/chips/tooltips/divider/swatches | matching leather+gold escape frames |
| `assets/sprites/ui/shop/ui_shop_*` state sprites | leather+gold slot, hover, price badge, purchased check and tooltip |
| `assets/sprites/ui/icons/system/ui_checkbox_checked.png`, `ui_checkbox_unchecked.png` | leather+gold check/empty checkbox |

Buttons remain the accepted SCRUM-147 Parchment & Wax Seal kit. The leather+gold
pass replaces panels/windows/bars/checks only.

9-slice / margins:

- Existing Back-end styleboxes already use the `dark_fantasy` frame paths.
- The active margins remain compatible with the new art:
  - global panel `Vector4(34, 34, 34, 34)`;
  - level panel `Vector4(46, 46, 46, 46)`;
  - card `Vector4(28..30)`;
  - HUD panel/card `Vector4(28,22,28,24)` / `Vector4(22,18,22,20)`;
  - tooltip `Vector4(26,26,26,26)`;
  - Escape stat frames keep their existing `StyleBoxTexture` margins in
    `scripts/pause_stats_menu.gd`.

Preview / QA artifacts:

```text
docs/design/previews/interface_refs_contact.png
docs/design/previews/interface_leather_gold_panel_kit_contact.png
build/qa/interface_leather_gold_panel_kit_contact.png
```

Validation:

- PNG validation passed for canonical leather+gold source kit, live dark_fantasy
  panel frames and system checkbox assets: correct RGBA/non-empty alpha.
- Godot import passed.
- `dark_fantasy_ui_theme_test.gd` passed.
- `ui_no_overlap_matrix_test.gd` passed.
- Full `runtime_smoke_test.gd` passed.

Back-end handoff:

- No new Back-end integration task is required for the current pass because the
  live paths already consumed by SCRUM-222 were replaced in-place.
- If QA wants old legacy frame assets physically removed/archived, use the
  existing safe cleanup flow rather than deleting runtime assets in this Design task.
