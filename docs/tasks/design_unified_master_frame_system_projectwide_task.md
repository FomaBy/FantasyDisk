# ART/UX: Единый мастер-фрейм для ВСЕХ интерфейсов (9-slice) + внедрение по проекту

Статус: done
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-373
QA: in_progress (2026-06-14)
Связано: SCRUM-327 (UI Overhaul опорная), SCRUM-324 (asset-skill), SCRUM-318 (hover без жёлтого),
hero-select рамки (320/321/322/323/356)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Хочу использовать ОДИН единый фрейм для всех фреймов интерфейса в игре: углы,
повторяемая рамка по горизонтали и вертикали, опционально фон внутри рамки;
возможно элементы посередине рамки и опциональные ховеры (увеличение яркости/
контрастности) там, где уместно. Разработать такой фрейм и внедрить по всему проекту».

Сейчас фрагментация: 67 frame-PNG в 9 семействах (contextual/dark_fantasy/ornate/
red_gold/leather_gold/hero_select/global/escape/settings) + ~12 констант
GLOBAL_*_FRAME_PATH (panel/button/card/hero_card/card_hover/level_panel/hud_panel/
hud_card/tooltip/timer_panel) и множество style-хелперов (_panel_style,
_character_card_style, _card_hover_style, _tooltip, ...). Цель — ОДИН фрейм.

## ОБЯЗАТЕЛЬНО — скилл
Мастер-фрейм СОЗДАВАТЬ скиллом `fantasydisk-asset-generator` (gpt-image-2, PNG,
ПРОЗРАЧНЫЙ фон), стиль D&D + Dark Fantasy Dragon (опорная SCRUM-327). Исходники в
references/, внедрить в assets/. Старые семейства рамок — в бэкап.

## Требования
### 1. Спроектировать единый мастер-фрейм (true 9-slice)
- **Углы** (4 угловых элемента) + **повторяемые края** по горизонтали и вертикали
  (тайлящиеся, НЕ растягиваемые: StyleBoxTexture `axis_stretch_horizontal/vertical =
  AXIS_STRETCH_MODE_TILE`) — рамка любого размера без искажений.
- **Опциональный фон внутри** рамки (заливка/подложка content-зоны; включаемая).
- **Опциональные элементы посередине краёв** (центральные орнаменты сверху/снизу/
  по бокам) — как включаемые оверлей-декорации (поскольку тайлящийся край не несёт
  единичный центр); применять «где уместно» (крупные панели/окна).
- **Ховер (опционально)**: увеличение яркости/контрастности на наведении —
  предпочтительно через modulate/шейдер (без жёлтого свечения, SCRUM-318), не
  отдельным тяжёлым ассетом; включается там, где элемент интерактивен.
- Соблюдать глобальное правило фреймов: content-зона ≥ окантовки, контент не на орнаменте.

### 2. Централизовать в коде (Back-end)
- Один источник истины: единый стиль-билдер (напр. `_unified_frame_style(opts)`
  / общий StyleBoxTexture) с параметрами: размер/толщина (margins), вкл/выкл фон,
  вкл/выкл центральные орнаменты, hover. Тинт-вариант допустим для смысловых
  акцентов (редкость/опасность), но ВИЗУАЛЬНО это один фрейм.
- Заменить все панели/окна/карточки/тултипы/HUD-плашки/диалоги на единый фрейм;
  свести 12 GLOBAL_*_FRAME_PATH и style-хелперы к одному. Старые ассеты/пути — в
  бэкап, удалить мёртвые ссылки.

### 3. Внедрить по ВСЕМУ проекту
- Все экраны: меню/настройки, бой-HUD, выбор героя, кодекс, магазин, награды,
  повышение, пауза, финалы, тултипы, диалоги. Согласовать с кластерами UI Overhaul
  (SCRUM-329..332/338/345) и hero-select (320/321/322/323/356) — они адаптируются
  под единый фрейм (тематический тинт допустим, но единая база).
- Ничего не накладывается, текст читаем, на 1280×720/1920×1080/2560×1440.

## Тест/верификация
- runtime_smoke + ui_no_overlap_matrix зелёные; все целевые экраны строятся с
  единым фреймом; рамка тайлится без искажений на разных размерах; hover работает.
- Демо-контактлист единого фрейма (углы/края/фон/центр/ховер) в docs/design/previews/;
  скрины ключевых экранов в build/qa/.
- CHANGELOG; systems/menus_ui + visual_style_assets; content_registry.

## Files / Assets / IDs
- scripts/ui_screens.gd (_global_texture_style; _panel_style/_character_card_style/
  _card_hover_style/тултипы; GLOBAL_*_FRAME_PATH 23-32) — централизация
- scripts/ui/ui_theme_paths.gd (UIThemePaths) — единый путь
- assets/sprites/ui/frames/ (новый unified/ + бэкап старых 9 семейств)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Единый мастер-фрейм (9-slice: углы + тайлящиеся края H/V + опц. фон + опц. центр.орнаменты + опц. hover) создан скиллом.
- [ ] Код централизован в один стиль-билдер; 12 GLOBAL_*_FRAME_PATH/хелперы сведены к одному; мёртвые ассеты в бэкап.
- [ ] Единый фрейм внедрён по ВСЕМ экранам; рамка тайлится без искажений; контент в content-зоне; ничего не накладывается; текст читаем на 3 разрешениях.
- [ ] runtime + no-overlap matrix зелёные; контактлист фрейма + скрины; CHANGELOG.

## Документация
docs/design/systems/visual_style_assets.md, docs/design/systems/menus_ui.md, content_registry.

## Result — 2026-06-14

Design pass complete; projectwide runtime integration is handed off to Back-end.

Generated through the required `fantasydisk-asset-generator` / OpenAI Images
workflow using the secure env source outside git, then postprocessed into a
true 9-slice-ready runtime kit:

- `assets/sprites/ui/frames/unified/ui_frame_unified_master.png`
  (`1024x1024`, RGBA, transparent frame)
- `assets/sprites/ui/frames/unified/ui_frame_unified_master_fill.png`
  (`1024x1024`, RGBA, full panel-fill variant)
- `assets/sprites/ui/frames/unified/ui_frame_unified_inner_fill.png`
  (`256x256`, RGBA, center fill tile)
- `assets/sprites/ui/frames/unified/ui_frame_unified_ornament_top.png`
  (`204x150`, RGBA, optional large-panel overlay)
- `assets/sprites/ui/frames/unified/ui_frame_unified_ornament_bottom.png`
  (`204x150`, RGBA, optional large-panel overlay)
- `assets/sprites/ui/frames/unified/ui_frame_unified_hover_overlay.png`
  (`1024x1024`, RGBA, optional fallback overlay)

Reference, metadata and previews:

- `docs/design/references/unified_master_frame/ui_frame_unified_master_reference.png`
- `docs/design/references/unified_master_frame/ui_frame_unified_master_reference_alpha_clean.png`
- `docs/design/references/unified_master_frame/unified_master_frame_metadata.json`
- `docs/design/previews/unified_master_frame_9slice_contact.png`
- `docs/design/previews/unified_master_frame_safe_zone.png`
- `build/qa/scrum373/unified_master_frame_design_qa.md`

Runtime spec for Back-end:

- source size: `1024x1024`
- texture margins: `128/128/128/128`
- content margins: `132/132/132/132`
- strict safe rect: `Rect2(132, 132, 760, 760)`
- horizontal/vertical stretch: tile, not one-axis stretch
- optional top/bottom ornaments only for large panels/windows
- hover/focus should prefer runtime modulate/contrast; overlay is fallback only

Back-end handoff created:

- `docs/tasks/backend_unified_master_frame_system_projectwide_integration_task.md`

Validation:

- Pillow dimension/alpha checks passed for all runtime assets and previews.
- Godot headless import passed for all SCRUM-373 assets/references/previews.
- Runtime smoke/no-overlap/projectwide replacement are intentionally delegated
  to Back-end because they require UI builder/theme path integration and screen
  layout updates.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: 9-slice мастер-фрейм кит + спека + Back-end handoff)

Проверено (фактически):
- **6 ассетов** (skill `fantasydisk-asset-generator`): `master.png` 1024² RGBA
  прозрачный (alpha 0-255), `ornament_top/bottom` 204×150 RGBA прозрачные,
  `hover_overlay` 1024² RGBA; `master_fill`/`inner_fill` намеренно непрозрачны
  (это фон-заливки, не рамка — корректно). Godot import чист.
- **Метаданные** `unified_master_frame_metadata.json`: source 1024², texture_margins
  128, content_margins 132, `strict_safe_rect [132,132,760,760]`,
  `axis_stretch H/V = tile` (НЕ one-axis stretch), draw_center/ornament/hover-правила,
  content-safe-zone правило — полная 9-slice спека для Back-end.
- **Визуал** `unified_master_frame_9slice_contact.png` (+ safe_zone): орнаментальные
  углы + тайлящиеся края H/V + опц. фон + опц. верх/низ орнаменты (D&D dark-fantasy),
  масштабируется без искажений на разных размерах.
- **Back-end handoff** `backend_unified_master_frame_system_projectwide_integration_task.md`
  / SCRUM-382 создан.

⚠️ **Проектная интеграция (централизация 12 GLOBAL_*_FRAME_PATH → один билдер +
замена единым фреймом по ВСЕМ экранам + бэкап старых 9 семейств) ещё НЕ в рантайме**:
это Back-end задача SCRUM-382 (статус **«new»**), явно вне Design-scope. runtime/
no-overlap по экранам — после интеграции.

Acceptance (фактическое состояние):
- [x] Единый 9-slice мастер-фрейм (углы + тайл-края H/V + опц. фон/центр.орнаменты/hover) скиллом.
- [~] Код-централизация (12 путей→один) + внедрение по всем экранам — Back-end SCRUM-382 («new»).
- [~] runtime/no-overlap по экранам — после интеграции (382).
- [x] Контактлист фрейма + safe-zone превью + метаданные/спека; Godot import чист.

Вывод: Design-деливерабл (кит + 9-slice спека + handoff) выполнен. Видимое проектное
внедрение — гейтится SCRUM-382. Статус review→done. Баги: нет.
