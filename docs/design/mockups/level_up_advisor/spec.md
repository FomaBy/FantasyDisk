# UI Mockup Spec - Level Up 3.0 (Advisor)

Status: ready_for_integration
Role owner: Claude (combined Design+Back-end по user-directed SCRUM-871)
Task: docs/tasks/ui_levelup_advisor_redesign_scrum871_task.md
Jira: SCRUM-871
Base resolution: 2560x1440 (кит SCRUM-682, рантайм скейлит через `_level_up_layout_metrics()`)
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: docs/design/mockups/level_up_advisor/levelup_advisor_mockup_2560x1440.png
Preview PNG: тот же файл (композит из PixelLab-ассетов кита + новых бейджей)
Generated with: PixelLab MCP create_ui_asset (ui-panel mode, 512x192, no_background);
source IDs: best_dps=451412de-c003-4aff-af59-ae61474c78c3,
best_surv=065e1a44-70e4-4f06-9f1d-d5d50c0577ad,
best_both=8f5ae959-2857-4e84-841b-48535eb96c65; кит панели/карточек — SCRUM-682.

## Source Request

Пользователь (2026-07-04): переделать экран выбора атрибута при получении уровня:
ясно видно, что увеличивается; подсказки «лучший выбор для ДПС» и «лучший для
выживаемости»; дизайн по лучшим практикам UI/UX.

## Screen Elements

Панель, шапка (портрет/титул/подзаголовок), ряд из 3 карточек и кнопка «Позже»
сохраняют геометрию SCRUM-682/683 (`LU_*`-константы ui_screens.gd). Новое —
внутренняя раскладка карточки (координаты в контент-зоне карточки
`LU_CARD_CONTENT_RECT = (58, 70, 354, 426)` @2K):

| ID | Type | Runtime content | Rect @card content | Z | States |
| --- | --- | --- | --- | --- | --- |
| badge | TextureRect + Label | бейдж рекомендации (dps/surv/both) или пусто | центр. слот 300x46, y 0..46 | 3 | есть/нет; не двигает сетку |
| icon | UIIconRegistry icon | иконка награды | 120x120, центр x, y 54..174 | 2 | — |
| title | Label | название награды | 6..348 x 180..222 | 2 | rare→TIER_COLORS[3] |
| desc | Label | краткое описание (2 строки) | 10..344 x 226..288 | 2 | — |
| deltas | PanelContainer(9-slice effect_preview) + 3 Label | «Параметр: до → после (+N%)», топ-3 | 0..354 x 294..426 | 2 | fallback: строка эффекта |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Label/content zone | 9-slice |
| --- | --- | --- | --- | --- |
| badge_dps | assets/sprites/ui/frames/level_up_scrum682/ui_badge_lu_best_dps.png | 468x78 | текст x 40%..90%, y 12%..88% | нет (KEEP_ASPECT) |
| badge_surv | assets/sprites/ui/frames/level_up_scrum682/ui_badge_lu_best_surv.png | 472x98 | текст x 38%..88% | нет |
| badge_both | assets/sprites/ui/frames/level_up_scrum682/ui_badge_lu_best_both.png | 474x102 | текст x 36%..84% | нет |
| deltas_frame | ui_frame_lu682_effect_preview.png | 330x64 | texture margins 22/18/22/18, content 32/22/32/22 | да |

Карточка/панель/кнопка «Позже» — прежние SCRUM-682 фреймы и margins.

## Interaction States

- Карточка: normal/hover/selected — прежние lu682-фреймы; бейдж и дельты внутри
  контент-зоны, состояния сетку не двигают.
- Тултип карточки: полный список изменений (все дельты) + классовая
  интерпретация награды.
- Тултип бейджа: объяснение расчёта («Наибольший прирост урона в секунду для
  твоего класса и оружия: +12.4%» / «Наибольший прирост живучести: ...»).
- Клавиатура/геймпад: прежняя SCRUM-812 раскладка (карточки по кругу, «Позже»
  через ui_down).

## Recommendation Logic (runtime, scripts/level_up_advisor.gd)

- Dry-run применения награды к копиям stats/run_modifiers (семантика
  player.apply_reward) → ProgressionData.derived_parameters до/после.
- DPS-скор: derived[damage_parameter_for(class)] × attack_speed × (1 +
  crit_chance × (crit_mult − 1)) + dot_damage × dot_speed.
- Живучесть: EHP-модель боевого take_damage — absorb режет типовой удар (20),
  затем defense, затем dodge; + (реген + вампиризм) × окно 12 с.
- Бейджи: argmax относительного прироста (> 0.1%); совпадение осей → «Лучший
  выбор» (both).

## Acceptance Checks

- [x] Мокап собран из PixelLab MCP ассетов (кит SCRUM-682 + 3 новых бейджа).
- [x] Превью показано в чате.
- [x] Каждый фрейм имеет объявленные margins/label-зоны.
- [x] Runtime-контент внутри safe-зон на 1280x720/1920x1080/2560x1440
      (гейт ui_no_overlap_matrix, слот level_up — PASSED).
- [x] Скриншот-сравнение после реализации: build/qa/scrum871/level_up_advisor_
      {1280x720,1920x1080,2560x1440}.png + level_up_advisor_rects.md.

## Deviations

- Плашка изменений использует фрейм `ui_frame_lu682_effect_preview`, но сам PNG
  пересобран офлайн-9-slice из прежней полосы 330x64 в родной аспект блока
  354x132 (границы орнамента 22/18 не тянутся; оригинал сохранён в
  docs/design/references/level_up_advisor/ui_frame_lu682_effect_preview_330x64_orig.png).
  Рантайм-стиль стал 1:1 @2K — прежний вертикальный стретч x2 ломал поля.
- Бейджи рисуются KEEP_ASPECT по высоте слота 46 @2K; ширины различаются
  (dps 6.0:1, surv 4.8:1, both 4.6:1) — слот центрирует.
- Подписи бейджей/титулы/строки дельт проходят авто-подбор размера шрифта
  под ширину зоны (`_shrink_label_font_to_width`, внешняя мерка с запасом
  fit_ratio 0.62 — фактический рендер строки в окне шире мерки до ~1.5x);
  титулы ряда выравниваются по минимальному подобранному размеру. Клип +
  ellipsis остаются страховкой.
- Титул `max_hp_up` сокращён в данных до «+Макс. здоровье» (канон подписи
  из STAT-лейблов) — самый длинный титул задавал ряду мелкий шрифт.
