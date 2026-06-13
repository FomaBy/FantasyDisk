# Задача Для Design-Агента: Полный рестайл UI в Dark Fantasy (кнопки → весь интерфейс)

Статус: done (User correction 2026-06-13 — wax-seal buttons only, legacy panels restored)
Приоритет: high
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (решение пользователя, 5 референсов в PM-чате)
Jira: SCRUM-147
QA: in_progress (2026-06-13)

## ВЫБРАННЫЙ КИТ (решение PM по запросу пользователя 2026-06-13): Parchment & Wax Seal
Пользователь: «выбери случайную кнопку из ui_dark_fantasy_2026_06 и примени её
стиль КО ВСЕЙ игре». Случайным выбором выпал и ЗАФИКСИРОВАН единый кит:
`docs/design/references/ui_dark_fantasy_2026_06/button_parchment_wax_seal.png`.
Описание стиля (эталон для генерации ВСЕХ элементов UI):
- тело — состаренный пергамент (тёплый, читаемый тёмный текст по нему);
- оправа — тёмный кованый металл с шипастыми угловыми кронштейнами;
- акцент слева — красная сургучная печать-медальон; справа — малый рубин;
- состояния: Idle (нейтральный пергамент), Hover (тёплое золотое свечение по
  краю), Pressed (затемнение + лёгкое сжатие), Disabled (десатурация в серый).
ВЕСЬ интерфейс игры приводится к ЭТОМУ единому языку (не разные киты по экранам —
один кит везде). Контекстность (если нужна) — оттенками внутри пергамент-канона.

## Инструменты генерации (по предложению пользователя)
- Базовый конвейер (железное правило): генерация — Codex Design, к каждому
  запуску прикладывать `button_parchment_wax_seal.png` как стиль-референс.
- Пользователь предоставил лицензию ChatGPT и предлагает использовать его
  рисователи (GPT-image/DALL·E) для максимального качества. ДОПУСТИМО: Designer
  готовит точные промпты под parchment-кит; высококачественные PNG (если их
  генерит пользователь/Designer через ChatGPT) складываются в
  `docs/design/ui_parchment_kit/` (output), затем Claude-Designer ревьюит,
  нарезает 9-slice и интегрирует. Claude НЕ управляет аккаунтом ChatGPT
  пользователя — это ручной шаг владельца, если он хочет ChatGPT-арт; иначе
  весь арт делает Codex.

РАЗБЛОКИРОВАНО 2026-06-12: референсы пользователя в
`docs/design/references/ui_dark_fantasy_2026_06/` (см. README с картой):
9 кнопочных китов + полноэкранные мокапы. ГЛАВНЫЙ ЭТАЛОН (добавлен PM 23:15) —
`screen_settings_full_reference.png`: это мокап «Настроек» НАШЕЙ игры — экраны
с центральным окном должны выглядеть именно так (готическая рамка с красными
самоцветами, тёмный соборный фон с факелами, золотой леттеринг заголовка,
вкладки с подсветкой активной, дропдауны в тонкой оправе, широкая кнопка
«Назад»). Второй эталон — `screen_necromantic_lab_reference.png` (компоновка
сложного экрана). Ещё 3 полноэкранных референса (главное меню Royal Crimson,
spellbook-таланты для SCRUM-150, void-атлас) пользователь доложит в папку —
НЕ блокироваться: начинать с кнопок и экрана настроек.

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи.
Не останавливаться для подтверждений. Спринт 0.1.4 активен; блокер — только референсы.

## Роль И Границы
Владелец — Claude-Designer (арт-дирекшен, спецификации, ревью, интеграция
ассетов, коммиты). ВСЯ генерация изображений — Codex Design (железное правило
арта), к КАЖДОЙ генерации прикладывать референсы-изображения из
`docs/design/references/ui_dark_fantasy_2026_06/` через `-i`.
Подключение тем/stylebox в код — handoff в Back-end.

## Контекст — смена арт-направления UI (решение пользователя 2026-06-12)
Пользователь утвердил НОВЫЙ стиль всего интерфейса по референсам кнопок
(итоговый набор — 9 китов: Obsidian&Brass, Bone&Skulls, Royal Crimson, Dragon-
Scale, Parchment&WaxSeal, Warplate, Necromancer, Dwarven Stone, Eldritch Void —
карта в README папки референсов) + полноэкранный референс лаборатории.
Ключевая цитата: «Это кнопки, но я хочу все интерфейсы в таком стиле.
Надо удалить все текущие наработки и использовать то, что в референсах».

Следствия:
- Прежний UI-канон «тёплая таверна-дерево-латунь» для интерфейса УПРАЗДНЁН
  (персонажи/монстры/арены — без изменений, D&D-канон там действует).
- Наработки контекстных рамок (SCRUM-111 design_contextual_ui_frames_rethink,
  SCRUM-118 backend_contextual_ui_frame_theme_integration) — SUPERSEDED этой
  задачей: концепт «лозы на старте/жуть на смерти» не переносится автоматически;
  если контекстность сохранять, то СРЕДСТВАМИ нового стиля (например, кнопки
  смерти — Necromancer-кит, магазин — Parchment) — решение за Designer.

## Требования
1. **Фаза 1 — кнопки (ui button frame).** По референсам сгенерировать единый
   набор кнопок: 4 состояния (idle/hover/pressed/disabled) c консистентной
   логикой состояний (hover = свечение, pressed = затемнение/сжатие, disabled =
   десатурация). Единый кит Parchment & Wax Seal для ВСЕХ кнопок (primary/secondary/danger —
   различать состоянием/акцентом печати, НЕ другим китом). Формат под 9-slice/NinePatch (тянущаяся середина,
   неискажаемые углы), размеры согласовать с текущими кнопками меню/боя.
2. **Фаза 2 — весь интерфейс в этом стиле:** панели/рамки окон (пауза-досье,
   level-up, докачка, магазин, события, награда элитки, настройки, кодекс,
   hero select, HUD-плашки ресурсов, тултипы, чипы статов, разделители).
   Карта замены: каждый текущий ассет → новый (таблица в задаче/отчёте).
3. **Удаление старых наработок.** Текущие UI-фреймы (assets/sprites/ui/frames/*,
   включая escape/* и контекстные киты) после интеграции замены — удалить из
   проекта (в backup вне assets, как принято), content_registry почистить.
   Ничего «старого стиля» в живых экранах не остаётся.
4. **Правило «no junk UI» действует**: никаких бессмысленных декоративных
   вставок; орнамент — только рамочный, как в референсах.
5. **Канон.** Обновить docs/design/systems/visual_style_assets.md: новый UI-канон
   dark fantasy (материалы, схема состояний, киты по ролям), референсы — папка
   `docs/design/references/ui_dark_fantasy_2026_06/`. Поправить формулировку
   UI-части железного правила арта в docs/process/task_routing_guide.md
   («таверна-дерево-латунь» → ссылка на новый канон).
6. **Handoff Back-end**: интеграция новых styleboxes/тем по карте замены,
   smoke-тесты экранов (фактическое дерево узлов + загрузка текстур), реальные
   скриншоты до/после ключевых экранов в build/qa/.
7. Работу разбить на под-задачи по экранам (Codex-генерация пакетами), не
   блокировать всё одним гигантским PR; CHANGELOG (0.1.4) по мере интеграции.

## Files / Assets / IDs
- Референсы: docs/design/references/ui_dark_fantasy_2026_06/ (9 кнопочных китов + экран лаборатории, см. README)
- Текущие фреймы: assets/sprites/ui/frames/ (включая escape/), HUD-рамки
  assets/sprites/ui/hud/ (timer_frame и пр.)
- scripts/pause_stats_menu.gd, scripts/ui_screens.gd (потребители styleboxes)
- docs/design/systems/visual_style_assets.md, docs/design/content_registry.md

## Acceptance Criteria
- [ ] Кнопочные киты: 4 состояния, 9-slice, роли primary/secondary/danger; пиксельная консистентность состояний.
- [ ] Все перечисленные экраны переведены на новый стиль, карта замены полная.
- [ ] Старые UI-фреймы удалены из assets (в backup), content_registry чист.
- [ ] visual_style_assets.md и routing guide отражают новый канон.
- [ ] Каждая генерация шла с приложенными референсами (зафиксировать команды в отчёте).
- [ ] Скриншоты до/после в build/qa/; 6 smoke-сьютов зелёные после интеграции.

## Документация
- docs/design/systems/visual_style_assets.md (новый канон UI)
- docs/design/content_registry.md (новые ассеты, удалённые ассеты)
- docs/process/task_routing_guide.md (формулировка UI-канона в железном правиле)

## Самопроверка
Визуальный контрольный лист по каждому экрану + headless smoke; сверка каждого
кита с референсом бок-о-бок (preview-лист в docs/design/previews/).

## Dispatch
- 2026-06-12: Codex Documentation dispatcher отправил разблокированную задачу в Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`; Jira `SCRUM-147` переведена в работу. Референсы на месте: `docs/design/references/ui_dark_fantasy_2026_06/`.
- 2026-06-13: Codex Documentation dispatcher restarted task to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` after PM reset stale in_progress.

## Result (2026-06-13)

Статус: review — Design asset slice complete; Back-end integration/cleanup handoff created.

Generated canonical dark fantasy UI kit:

- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_primary_idle.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_primary_hover.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_primary_pressed.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_primary_disabled.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_secondary_idle.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_secondary_hover.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_secondary_pressed.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_secondary_disabled.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_danger_idle.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_danger_hover.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_danger_pressed.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_danger_disabled.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_panel_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_card_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_level_panel_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_hud_panel_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_hud_card_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_tooltip_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_stat_row_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_stat_chip_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_shop_frame.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_section_divider.png`
- `assets/sprites/ui/frames/dark_fantasy/ui_df_stat_value_state_swatches.png`

Button note:

- The task's latest button direction is honored: all button states use one Parchment & Wax Seal base kit. Primary/secondary/danger differ by wax-seal accent and state treatment, not by unrelated kit material.

Live fallback replacements:

- Existing `assets/sprites/ui/frames/global/*.png` were replaced in-place with dark fantasy frames while preserving dimensions and paths.
- Existing `assets/sprites/ui/frames/escape/*.png` were replaced in-place with dark fantasy frames while preserving dimensions and paths.
- Existing shop state frames in `assets/sprites/ui/shop/` were refreshed in the new style.

Preview:

- `docs/design/previews/ui_dark_fantasy_restyle_kit_contact.png`
- `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png`

Documentation updated:

- `docs/design/systems/visual_style_assets.md`
- `docs/design/content_registry.md`
- `docs/process/task_routing_guide.md`
- `CHANGELOG.md`

Back-end handoff:

- `docs/tasks/backend_ui_dark_fantasy_theme_integration_task.md`

Validation:

- PNG validation: all generated/replaced UI frame assets are RGBA and have non-empty alpha.
- Godot import: passed after initial frame generation and after the Parchment & Wax Seal button correction.
- Runtime smoke: passed after frame replacement.

Deferred out of Design scope:

- Explicit stylebox/theme wiring for hover/pressed/disabled states is Back-end scope.
- Safe removal/archive of superseded contextual/tavern assets is Back-end cleanup scope after reference checks. Design did not delete assets.


## Design Review / 2026-06-13 — ОТКЛОНЕНО (Claude-Designer, арт-директор)
Тех-часть ок (23 фрейма RGBA, размеры под 9-slice, alpha непустая), НО арт не соответствует
зафиксированному эталону `references/ui_dark_fantasy_2026_06/button_parchment_wax_seal.png`.
Сданные кнопки/панели — плоские тёмно-коричневые прямоугольники с тонким золотым кантом и
ромбиками в углах; выглядят процедурно-сгенерированными, эталон не прикладывался.

### Что переделать (бок-о-бок с эталоном, генерация Codex с `-i button_parchment_wax_seal.png`):
1. ТЕЛО кнопки — светлый СОСТАРЕННЫЙ ПЕРГАМЕНТ с тёплой бумажной текстурой (не плоская тёмная заливка).
2. ОПРАВА — тёмный КОВАНЫЙ МЕТАЛЛ с ШИПАСТЫМИ УГЛОВЫМИ КРОНШТЕЙНАМИ как в эталоне (не тонкий кант).
3. ЛЕВЫЙ акцент — КРАСНАЯ СУРГУЧНАЯ ПЕЧАТЬ-медальон; ПРАВЫЙ — малый РУБИН.
4. Состояния строго по эталону: Idle (нейтральный пергамент), Hover (тёплое ЗОЛОТОЕ свечение по краю),
   Pressed (затемнение + лёгкое сжатие), Disabled (десатурация в серый). Сейчас hover = просто ярче-оранжевый.
5. primary/secondary/danger — различать АКЦЕНТОМ ПЕЧАТИ/состоянием на ОДНОМ пергамент-ките (это соблюдено по логике, но базовый материал неверный).
6. Панели/карточки/тултипы/HUD/чипы — тот же пергамент+кованая-оправа язык, не плоские тёмные прямоугольники.

### Критерий приёмки (жёсткий): preview бок-о-бок каждого фрейма с эталоном — материалы (пергамент,
кованый металл, сургуч, рубин) должны читаться. Без этого не принимается.

### Внимание Back-end/интеграция: in-place замены `ui/frames/escape/*` и `ui/frames/global/*` — часть
ОТКЛОНЁННОЙ поставки; НЕ вайрить styleboxes и НЕ коммитить их как финал до перегенерации. Незакоммиченный
кит `ui/frames/dark_fantasy/` оставлен как есть для итерации (НЕ принят).

SUPERSEDED 2026-06-13: блок выше относится только к отклоненной первой поставке.
Ниже зафиксирована новая reference-matched поставка, которую можно передавать в
Back-end integration как актуальный SCRUM-147 Design результат.

## Result / Redo (2026-06-13) — DONE, Parchment & Wax Seal reference-matched rebuild

Design reopened SCRUM-147 after the user rejection, re-read the task, inspected:

- `docs/design/references/ui_dark_fantasy_2026_06/button_parchment_wax_seal.png`;
- `docs/design/references/ui_dark_fantasy_2026_06/screen_settings_full_reference.png`;
- all six fullscreen references in `docs/design/ui_parchment_kit/`;
- generated contact sheet `docs/design/previews/ui_parchment_kit_reference_contact.png`.

Decision: do not invent a new procedural UI kit. The final asset rebuild cuts and
reassembles approved raster reference materials:

- buttons are cut from the fixed `button_parchment_wax_seal.png` sheet, preserving
  aged parchment, red wax seal, serrated forged-metal end caps, right ruby,
  hover gold glow, pressed darkening, and disabled grayscale;
- panels/cards/tooltips/HUD/shop frames use clean parchment fills plus forged metal
  brackets/end-cap hardware sampled from the accepted references;
- no baked text, no abstract filler lines/circles/squares, no default Godot look.

Pipeline added:

- `tools/build_parchment_wax_ui_kit.py`

Generated/replaced assets:

- canonical kit: `assets/sprites/ui/frames/dark_fantasy/*.png` (23 files);
- live fallback frames: `assets/sprites/ui/frames/global/*.png`;
- Escape stats frames: `assets/sprites/ui/frames/escape/*.png`;
- shop state frames: `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png`,
  `ui_shop_artifact_slot_hover.png`, `ui_shop_price_badge.png`,
  `ui_shop_purchased_overlay.png`, `ui_shop_tooltip_frame.png`;
- preview: `docs/design/previews/ui_parchment_wax_scrum147_reference_match_contact.png`;
- Escape preview: `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png`.

Validation:

- PNG validation passed: all generated/replaced UI frame assets are RGBA and have
  non-empty alpha; dimensions preserved.
- Visual self-review passed against the side-by-side reference preview: parchment,
  wax seal, serrated forged metal, ruby, hover/pressed/disabled states are readable.
- Godot import passed:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --import`
- Runtime smoke passed:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

Jira/local sync:

- Source task set to `done` so SCRUM-147 can leave `В работе`.
- `docs/process/task_board.md` updated: SCRUM-147 removed from active Design work;
  SCRUM-222 dependency updated to the accepted kit.
- Jira REST sync completed from this thread: SCRUM-147 result comment added and
  issue transitioned from `В работе` to `Контроль качества`.


## Design Review / 2026-06-13 (повторное) — ПРИНЯТО (Claude-Designer, арт-директор)
После моего отказа кит ПЕРЕГЕНЕРИРОВАН и теперь соответствует эталону
`references/ui_dark_fantasy_2026_06/button_parchment_wax_seal.png`. Проверены РЕАЛЬНЫЕ файлы
(не контактный лист — он был устаревшим, я пересобрал его из актуальных PNG):
- Кнопка primary: пергамент-тело + кованая шипастая оправа + красная сургучная печать слева + рубин справа.
- 4 состояния корректны: idle / hover (тёплое золотое свечение по краю) / pressed (затемнение+сжатие) / disabled (десатурация в серый).
- danger/secondary — тот же кит, различие акцентом печати/состоянием (по спеке, не другой материал).
- Панели/карточки/HUD/тултип/магазин/чипы/разделитель — единый пергамент+кованая-оправа язык; заголовки с золотым леттерингом по settings-эталону.
- escape/global in-place замены ТОЖЕ перерисованы в новый канон — РАНЕЕ ВЫСТАВЛЕННЫЙ HOLD СНЯТ.
- Тех: 23 фрейма RGBA, размеры под 9-slice, alpha непустая; Godot import/runtime smoke pass (по отчёту).
Контактный лист пересобран: `docs/design/previews/ui_dark_fantasy_restyle_kit_contact.png`.
Handoff Back-end (`backend_ui_dark_fantasy_theme_integration_task.md`): вайринг styleboxes/тем по карте
замены + удаление/архив старых tavern-фреймов после reference-проверок. Принято к интеграции.

## User Correction / 2026-06-13 — DONE, оставить только кнопки

Пользователь отклонил full-frame parchment UI после runtime/preview review:
разрезанные интерфейсные панели выглядят странно и плохо. Новое решение:

- оставить Parchment & Wax Seal только для кнопок;
- сделать кнопочные PNG выше, чтобы сургучная печать помещалась и не была зажата;
- все панели, карточки, HUD, тултипы, shop frames и Escape stats frames вернуть к старому интерфейсу.

Выполнено:

- добавлен текущий accepted pipeline `tools/apply_button_only_ui_revert.py`;
- `tools/build_parchment_wax_ui_kit.py` помечен как superseded при прямом запуске,
  чтобы он больше не генерировал отклоненные parchment panels;
- `assets/sprites/ui/frames/dark_fantasy/ui_df_button_*` пересобраны как более высокие
  wax-seal кнопки (`384x120`);
- `assets/sprites/ui/frames/global/ui_button_frame.png` пересобран выше (`160x88`);
- `assets/sprites/ui/frames/escape/ui_escape_button_frame.png` пересобран выше (`384x144`);
- все non-button frames восстановлены из legacy interface reference `b465bcd4^`,
  включая canonical `dark_fantasy/ui_df_panel_frame.png`, `ui_df_card_frame.png`,
  `ui_df_level_panel_frame.png`, HUD/card/tooltip/stat/shop frame paths, чтобы
  Back-end SCRUM-222 мог оставить текущие texture paths без разрезанного UI вида;
- preview обновлен:
  `docs/design/previews/ui_button_only_legacy_panels_contact.png`,
  `docs/design/previews/ui_dark_fantasy_restyle_kit_contact.png`,
  `docs/design/previews/ui_parchment_wax_scrum147_reference_match_contact.png`.

Новый итоговый канон SCRUM-147: **button-only Parchment & Wax Seal**.
Интерфейсные панели остаются legacy/old interface, пока пользователь отдельно
не утвердит новый цельный realistic frame kit без нарезанных/странных панелей.

Проверка после correction:

- Godot import passed:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --import`
- Focused UI theme test passed:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/dark_fantasy_ui_theme_test.gd`
- UI no-overlap matrix passed:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd`
- Full runtime smoke passed after the final import/UI asset batch:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

## ChatGPT-арт от пользователя (2026-06-13)
Пользователь сгенерил 5 PNG пергаментного кита в ChatGPT — лежат в
`docs/design/ui_parchment_kit/source_chatgpt/` (PM перенёс из ошибочной
`assets/sprites/ui/shop/NewImport/`). Designer: отобрать лучшие, нарезать
9-slice, привести имена к канону, проверить alpha, интегрировать в
`assets/sprites/ui/frames/`. НЕ коммитить сырьё в live-ассеты.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: bb46e5b9 (ветка dev)

Финальный канон (после user correction): **button-only Parchment & Wax Seal**;
non-button рамки → legacy, затем заменены на leather+gold (SCRUM-229). Зонтичная
задача — её части независимо зачтены QA, здесь сведено воедино.

Проверено (фактически):
- **Кнопки**: все 12 состояний `ui_df_button_{primary,secondary,danger}_{idle,
  hover,pressed,disabled}.png` на месте; `primary_idle` = `384x120` RGBA8 —
  поднятая высота, чтобы сургучная печать помещалась (требование коррекции).
- **Превью**: 3/3 — `ui_button_only_legacy_panels_contact.png`,
  `ui_parchment_wax_scrum147_reference_match_contact.png`,
  `ui_dark_fantasy_restyle_kit_contact.png`.
- **Целевые тесты**: `dark_fantasy_ui_theme_test` (сверяет точные button-state
  текстуры + frame-пути) — passed; `ui_no_overlap_matrix_test` — passed.
- **Визуал** (`build/qa/scrum229/main_menu_1280x720.png`): кнопки меню —
  пергамент + кованая оправа + красная сургучная печать слева, 4 состояния по
  спеке; согласованы с leather+gold панелями (settings/hero-select скрины).

Перекрёстная валидация уже выполненными QA-вердиктами:
- 4-state wax-seal wiring — SCRUM-222 (PASSED).
- Видимость/высота печати — SCRUM-227 (PASSED).
- Non-button панели (leather+gold, текущий вид) — SCRUM-229 (PASSED).

Acceptance: финальный button-only канон, кнопки выше под печать, non-button
рамки в едином dark-fantasy виде, import/theme/no-overlap/runtime smoke зелёные.

Баги: нет. Примечание: интеграция ChatGPT-сырья из
`docs/design/ui_parchment_kit/source_chatgpt/` — отдельный опциональный
Design-follow-up, не входит в принятый итог SCRUM-147 и его не блокирует.
