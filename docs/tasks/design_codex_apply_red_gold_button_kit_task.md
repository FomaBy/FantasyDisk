# Задача Для Design-Агента: Применить кит кнопок «Red & Gold Dragon» из docs/design/references/Buttons ко всей игре

Статус: done
Приоритет: high
Роль: Design (Claude-Designer нарезка/9-slice/интеграция) → Back-end handoff
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-273

## Dispatcher Sync Note (2026-06-14)

Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` took this task via its
own task-polling heartbeat and is actively working it. Dispatcher did not resend
the handoff; board/Jira were aligned to the existing `in_progress` owner.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Взять кнопки из папки docs/design/references/Buttons и применить их в игре».
`button_kit_red_gold_dragon_sheet.png` — полный лист кнопок в красно-золотом
драконьем стиле с ТОЧНЫМИ размерами под каждый тип кнопки игры (см. README папки;
совпадают с унифицированной системой SCRUM-263/264, высота action-кнопок 104px).

Это заменяет текущий button-стиль (пергамент+печать, SCRUM-147) на новый
красно-золотой драконий кит.

## Состав листа (тип → размер, из README)
Standard 420×104, Max-visual 560×104, Main menu 380×104, Hero select 320×104,
Settings reset audio 420×104, Settings reset bindings 440×104, Codex tab 170×104,
Back S 170×104, Back M 280×104, Back L 380×104, Attribute selector 560×104,
Upgrade FAB 50×50, Compact utility 54×42, Pause menu 280×60, Rebind 420×62.

## Требования
1. **Нарезать лист** на отдельные PNG по типам кнопок (по размерам из README),
   RGBA, прозрачный фон, чистые края (без соседних кусков/подписей-номеров).
   Имена к канону: `ui_btn_red_gold_<type>.png` (standard/max/main_menu/hero_confirm/
   reset_audio/reset_bindings/codex_tab/back_s/back_m/back_l/attr_selector/fab/
   utility/pause/rebind). Финал — в `assets/sprites/ui/frames/red_gold/`.
2. **Состояния**: лист даёт базовый вид (idle). Состояния hover/pressed/disabled
   получить программно (подсветка/затемнение/десатурация) ИЛИ сгенерировать
   варианты Codex по образцу — решение Designer; idle обязателен, остальные —
   консистентной логикой.
3. **9-slice**: задать nine-patch margins так, чтобы тянулась центральная
   нейтральная зона, а драконьи когти/орнамент по краям не искажались (учесть
   дисциплину растяжения SCRUM-263). Размеры из листа — как референс пропорций.
4. **Применить ко ВСЕМ кнопкам игры** (handoff Back-end на стайлбоксы/тему):
   главное меню, выбор героя/оружия, магазин, настройки (+reset audio/bindings),
   события, level-up, кодекс-вкладки, пауза, FAB докачки, rebind, attribute
   selector, Back-кнопки. Карта «тип кнопки в игре → ассет кита» — в отчёт.
   Сохранить высоты/стандарт из SCRUM-263/264 и no-overlap.
5. **Старый button-кит** (пергамент+печать) после замены — в backup вне assets,
   content_registry почистить. (Панели/окна «кожа+золото» SCRUM-229 — НЕ трогать,
   это про кнопки.)
6. content_registry + visual_style_assets (новый button-канон); CHANGELOG;
   превью до/после кнопок в docs/design/previews/.
7. Тест (smoke): кнопки грузят новые стайлбоксы (фактическое дерево + текстуры),
   no-overlap ключевых экранов; читаемость текста на красно-золотом фоне.

## Files / Assets / IDs
- Источник: docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png (+README)
- Финал: assets/sprites/ui/frames/red_gold/ (нарезанные кнопки)
- scripts/ui_screens.gd (_make_button/_apply_fantasy_button_theme — потребители)
- docs/design/systems/visual_style_assets.md, content_registry.md

## Acceptance Criteria
- [x] Лист нарезан на per-type PNG (правильные размеры/имена, чистая alpha).
- [x] Состояния idle+hover/pressed/disabled; 9-slice без искажения когтей.
- [x] ВСЕ кнопки игры на новом красно-золотом ките; карта замены полная; старый кит в backup.
- [x] Текст читаем; no-overlap; 6 smoke зелёные; превью до/после; content_registry/CHANGELOG.

## Документация
visual_style_assets.md (button-канон red&gold), content_registry.md, current_game_state.md.

## Результат (2026-06-14)

SCRUM-273 закрыт как Design/runtime visual integration pass: пользовательский
лист `docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png`
нарезан в новый live-кит `assets/sprites/ui/frames/red_gold/`.

Добавлено:
- 15 типов кнопок: `standard`, `max`, `main_menu`, `hero_confirm`,
  `reset_audio`, `reset_bindings`, `codex_tab`, `back_s`, `back_m`, `back_l`,
  `attr_selector`, `fab`, `utility`, `pause`, `rebind`;
- 4 состояния для каждого типа: idle/base, hover, pressed, disabled;
- итого 60 RGBA PNG с прозрачной alpha и Godot import sidecars;
- pipeline `tools/build_red_gold_button_kit.py`;
- contact preview `docs/design/previews/red_gold_button_kit_contact.png`;
- backup прежнего parchment/wax button kit:
  `build/cleanup_backup_red_gold_buttons_2026_06_14/`.

Runtime mapping:
- `scripts/ui/ui_theme_paths.gd` теперь содержит `RED_GOLD_BUTTON_TEXTURES`,
  9-slice margins и content margins для всех типов;
- `scripts/ui_screens.gd` выбирает тип кнопки по node name/role/size: главное
  меню, выбор героя, настройки, reset audio/bindings, кодекс-вкладки,
  attribute selector, back S/M/L, pause menu, FAB, compact utility и rebind;
- non-button панели/окна/HUD/tooltips оставлены на SCRUM-229 leather+gold kit.

Примечание по source sheet: README остаётся каноном runtime-размеров, но часть
подписей на самом листе слегка отличается. Финальные PNG приведены к размерам
из задачи/README, а crop-boxes подогнаны по фактическому арту листа.

Проверки:
- `python3 tools/build_red_gold_button_kit.py` — PASS;
- asset validation — 60/60 PNG имеют ожидаемые размеры, RGBA и непустую alpha;
- `tests/dark_fantasy_ui_theme_test.gd` — PASS;
- `tests/runtime_smoke_ui_test.gd` — PASS;
- `tests/ui_no_overlap_matrix_test.gd` — PASS;
- `tests/runtime_smoke_test.gd` — PASS.
