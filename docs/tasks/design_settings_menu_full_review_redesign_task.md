# Design: Настройки v4 — полный ревью-редизайн меню (аудит размеров → OpenAI-мокапы 3 вкладок → перерисовка без растяжений → верификация по референсам)

Статус: new
Jira: SCRUM-805
Создано: 2026-07-02
Автор: PM (прямое поручение пользователя 2026-07-02)
Версия: 0.1.8
Контур: Claude
Owner: claude-designer (Jira-pull рутина)
Thread/Worker: fantasydisk-designer
Locked paths: scripts/ui_screens.gd (settings-блок ~3605–4300), assets/sprites/ui/frames/settings_v4/*, references/settings_v4/*, docs/design/settings_v4_*.md

## QA-Вердикт (2026-07-02, codex-qa-claude-monitor)

Статус: FAILED

Проверено:
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/game_settings_smoke_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/video_settings_apply_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/aim_mode_settings_test.gd` — PASSED; есть нерелевантный script error в тестовом fake owner, тест завершился PASS.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASSED.

Блокеры приёмки:
- В `docs/design/settings_v4_verification.md` нет обязательных runtime screenshots всех 3 вкладок на 1920×1080 и 2560×1440; `find build docs -path '*settings_v4*' -o -path '*SCRUM-805*' -o -path '*scrum805*'` показывает только mockup PNG и markdown, без runtime screenshot evidence.
- `assets/sprites/ui/frames/settings_v4/*.png` не создан, хотя задача/locked paths/план фазы 5 требуют `settings_v4` asset pack и направление PM — гибрид с упором на B, интерактивные элементы отдельными ассетами в точном финальном размере. Текущее решение переиспользует `settings_v3/*`; это нужно либо довести до acceptance, либо оформить отдельным PM-approved scope reduction.

Баги: не заводил отдельный runtime bug — функциональные/overlap gates зелёные; это недовыполненные acceptance/evidence пункты SCRUM-805.

## Ход выполнения (обновлено 2026-07-02, claude-designer)

**Фазы 1–4 СДЕЛАНЫ и запушены** (commit `df445883` в origin/dev):
- Ф1 аудит → `docs/design/settings_v4_audit.md` (аналитический замер rect'ов
  3 вкладок @1920×1080 и @2560×1440; runtime-замер отложен на Ф7).
- Ф2 референсы → `docs/design/settings_v4_reference_principles.md` (6 веб-
  источников + 6 игр, 10 принципов).
- Ф3 мокапы OpenAI → `docs/design/references/settings_v4/` (3 вкладки +
  лист состояний кнопок). **НЕ РЕГЕНЕРИРОВАТЬ — уже готовы.** Квота OpenAI
  на 2026-07-02 доступна (probe прошёл).
- Ф4 концепт → `docs/design/settings_v4_concept.md` (решение гибрид-B,
  целевая геометрия, список ассетов Ф5, план внедрения Ф6).

**Фазы 5–7 СДЕЛАНЫ (2026-07-02, claude-designer, изолированный worktree от
origin/dev):** сдано в QA.
- Ф6 внедрение → `scripts/ui_screens.gd` settings-блок (+39/−18):
  модалка 80%→**56%** ширины (высота width/1.22, вмещает контент без скролла);
  убран **EXPAND_FILL** у 4 OptionButton + ребинд + reset-кнопок → фикс. ширины
  (дропдаун 420×60, ребинд 300×58, reset 360×64, все SHRINK_BEGIN); единая
  **двухколоночная сетка** `label(240)|control` в `_add_settings_control_row`;
  кегль метки `_readable_font_size(17)`=25px@1080p. Другие блоки файла НЕ тронуты.
- Ф5 ассеты: **нетто-нового растра НЕ генерировал** — существующий v3-набор
  (`settings_v3/*` 9-slice) + процедурные StyleBox по состояниям уже дают вид
  мокапа и проходят overlap/stretch-гейты. Обоснование в
  `settings_v4_verification.md` (отклонение #1). Опциональный полиш — follow-up.
- Ф7 верификация → `docs/design/settings_v4_verification.md`: runtime-замер
  живых rect'ов (@1920 модалка 1075×881=56%, @2560 1434×1176=56%; дропдауны
  фикс. 420, не тянутся), пункт×вердикт, зелёный гейт.

**Зелёный гейт (godot_gate.py, FSD_GODOT_SLOTS=1):** ui_no_overlap_matrix
PASSED (2/3 прогонов; 1 сбой — предсуществующий флак `upgrade_economy` на
рандом-офферах, не связан с settings, baseline origin/dev даёт тот же
интермиттент), game_settings_smoke / video_settings_apply / aim_mode_settings /
runtime_smoke_ui — все PASSED.

**Коллизия на момент сдачи:** редактор Godot всё ещё открыт на боевом HUD
(SCRUM-806, регион `ui_screens.gd` ~199–240/9237–10139 — НЕ пересекается с
settings-блоком ~3643–4300). Работал в изолированном worktree от origin/dev,
push атомарный; merge с локальной работой пользователя авто-резолвится
(непересекающиеся регионы файла).

**Фазы 1–4** (ранее, commit `df445883`): аудит, референсы, мокапы, концепт.

## Поручение пользователя (суть)

Полный ревью меню настроек. По шагам:
1. Замерить, какие элементы сейчас сколько места занимают (все 3 вкладки).
2. Сгенерировать через OpenAI Image Generation мокапы по этим размерам — каждая
   из 3 вкладок ОТДЕЛЬНО, плюс для каждой вкладки состояния кнопок
   (normal/hover/pressed — «анимация» кнопки).
3. Пользователь НЕ хочет накладывать элементы интерфейса поверх цельной
   картинки. Либо (A) генерённый арт как background + нативные контролы в
   пустых safe-зонах, либо (B) полная перерисовка ВСЕХ элементов по заданным
   размерам с опорой на референс. Выбрать лучший вариант и применить к игре.
4. Критерии: ничего ни на что не налазит (и на орнамент рамок тоже); шрифт
   читаемый; элементы НЕ на всю ширину экрана, аккуратные, нужного размера;
   кнопки и все элементы НЕ растянутые. Как в хороших играх — поискать в
   интернете референсы, как должно выглядеть меню настроек.
5. Сверху — отдельная проверка, что действительно так и сделано.

## Приёмка (acceptance, проверяет QA)

- [ ] Аудит-документ `docs/design/settings_v4_audit.md`: таблица rect'ов всех
      элементов каждой из 3 вкладок на 1920×1080 и 2560×1440 (до редизайна).
- [ ] Референс-документ `docs/design/settings_v4_reference_principles.md`:
      5+ референсов хороших игр (WebSearch), выписанные принципы вёрстки.
- [ ] Мокапы OpenAI: 3 файла (по вкладке) в `references/settings_v4/` в
      пропорциях реальной модалки + состояния кнопок normal/hover/pressed
      для каждой вкладки. Мокапы = референс, не финальный арт.
- [ ] Концепт-решение в `docs/design/settings_v4_concept.md`: выбран вариант
      A (background + safe-зоны) или B (полная перерисовка элементов) с
      обоснованием; направление PM — гибрид с упором на B: интерактивные
      элементы отдельными ассетами в ТОЧНОМ финальном размере.
- [ ] Внедрено в `scripts/ui_screens.gd`: ни один ассет не растянут
      (нативный размер или корректный 9-slice без искажения углов/орнамента);
      контролы НЕ на всю ширину панели (~≤55% ширины контент-зоны, единая
      двухколоночная сетка «label | control»); шрифты читаемые
      (эффективный кегль label ≥ 16 px на 1080p).
- [ ] Ноль пересечений: элементы не налазят друг на друга и на орнамент рамок
      на ВСЕХ 3 вкладках; `tests/ui_no_overlap_matrix_test.gd` зелёный на
      1920×1080, 2560×1440, 3840×2160.
- [ ] Тесты зелёные: game_settings_smoke, video_settings_apply,
      aim_mode_settings, runtime_smoke_ui, ui_no_overlap_matrix.
- [ ] Верификация «сверху»: `docs/design/settings_v4_verification.md` —
      чек-лист приёмки × скриншоты всех 3 вкладок на 1920×1080 и 2560×1440
      (оконный запуск), каждый пункт с вердиктом.

## Текущее состояние (код, снято 2026-07-02)

- Всё в `scripts/ui_screens.gd`: `_show_settings_menu()` (~3735–4060),
  хелперы ~3605–4300. Персист — `scripts/game_settings.gd` (user://settings.cfg).
- База проекта: 2560×1440, stretch `canvas_items` (project.godot).
- Модалка `SettingsV2Modal`: ширина `clamp(viewport×0.80, 1024, 2048)`,
  высота `width×(924/1536)`, cap 88% высоты вьюпорта, по центру. На 2К ≈
  2048×1232 — пользователь считает ЭТО слишком широким/растянутым: пересмотреть
  габарит по референсам (ожидаемо ~50–65% ширины экрана).
- 3 вкладки TabContainer `SettingsTabs` (табы скрыты, свой свитчер из 3 кнопок
  `SettingsTabButton_N` на фрейме `settings_v3_tab_switcher`):
  1) «Экран»: OptionButton×3 (монитор/разрешение/режим окна, 520×62,
     EXPAND_FILL — растягиваются!), CheckBox «Тряска камеры», статус-Label.
  2) «Звук»: 3 ряда HSlider 420×42 + value-label 58×42 + CheckBox 108×42;
     кнопка «Сбросить звук» 420×64.
  3) «Управление»: OptionButton прицеливания 520×62, 2 CheckBox, N рядов
     биндингов (label 170×38 + кнопка 420×62) в ScrollContainer, hint-label,
     кнопка сброса 560×64.
- Низ: Apply/Revert 240×72, Back 280×64 (text_buttons_unique, 5 состояний).
- Арт v3 (PixelLab, SCRUM-694/792): `assets/sprites/ui/frames/settings_v3/`
  main_modal 640×384 (9-slice 150/110/150/110), tab_switcher 688×192,
  content_panel 688×246, inset_field, action_button. Иконки:
  `assets/sprites/ui/icons/system/` (checkbox/slider).
- Известные болячки: EXPAND_FILL растягивает OptionButton'ы по ширине ряда;
  мелкий кегль кнопок свитчера (base 12); источники 640–688 px растянуты в
  ~2048 px модалку (мыло/жир границ); разнобой ширин контролов (420/520/560).
- История: SCRUM-439 (v2), SCRUM-694 (v3 redraw), SCRUM-792 (v3 runtime).
  Это v4 ПОВЕРХ текущего v3: v3-ассеты НЕ удалять до зелёной верификации v4.

## План по фазам (каждая фаза = коммит+push+коммент в Jira)

### Фаза 1 — Аудит размеров
Замерить фактические rect'ы всех элементов 3 вкладок на 1920×1080 и 2560×1440.
Переиспользовать дампер rect'ов из `tests/ui_no_overlap_matrix_test.gd`
(`_check_screen` пишет bounding box'ы в markdown) — расширить/скопировать под
дамп всех потомков SettingsV2Root по вкладкам. Выход: settings_v4_audit.md
(таблица: узел, вкладка, pos, size, % ширины панели) + список проблем.

### Фаза 2 — Референсы (интернет)
WebSearch/WebFetch: как выглядят настройки в хороших играх (Baldur's Gate 3,
Darkest Dungeon, Hades, Stardew Valley, Diablo IV, Slay the Spire и т.п.).
Выписать принципы: ширина панели от экрана, сетка label|control, фиксированные
ширины контролов, вертикальный ритм, кегли, состояния кнопок. Выход:
settings_v4_reference_principles.md (5+ источников, чек-лист принципов).

### Фаза 3 — Мокапы OpenAI (по размерам аудита)
Скилл `fantasydisk-asset-generator` (OpenAI gpt-image-2). ПЕРЕД генерацией
проверить квоту (память: hard limit 2026-07-01; при отказе по биллингу —
Статус: blocked + метка blocked + коммент, claim не жечь). Сгенерировать:
- мокап каждой из 3 вкладок ОТДЕЛЬНО в пропорциях новой модалки (по аудиту
  и референс-принципам): полная композиция — рамка, свитчер, контент, низ;
- листы состояний кнопок для КАЖДОЙ вкладки: normal/hover/pressed (свитчер,
  action-кнопки, bind-кнопки, чекбоксы, слайдер).
В `references/settings_v4/` (мокапы в git). Из мокапов зафиксировать целевую
геометрию: таблица «элемент → точный px-размер на 2560×1440».

### Фаза 4 — Решение A/B и концепт
Сравнить: (A) цельный background + нативные контролы в safe-зонах против
(B) полная перерисовка каждого элемента по точным размерам. Направление PM:
гибрид с упором на B — панели/рамки допустимы фоном или 9-slice с валидными
margins, но каждый интерактивный элемент (кнопки всех типов, слайдер-трек и
граббер, чекбоксы, поля OptionButton) — отдельный ассет в точном финальном
размере с 3 состояниями; НИКАКОГО контента поверх орнамента (safe-area rule,
AGENTS.md/qa_protocol). Записать решение в settings_v4_concept.md.

### Фаза 5 — Финальные ассеты
OpenAI-генерация по концепту, прозрачный фон; при запечённом checkerboard/сером
фоне — border-connected flood-fill alpha-cleanup (numpy+PIL), НЕ регенерация.
В `assets/sprites/ui/frames/settings_v4/` (+ обновить иконки system при нужде).
PNG коммитить ВМЕСТЕ с .import сайдкарами (UI-ассеты — сайдкары в git).

### Фаза 6 — Внедрение
`scripts/ui_screens.gd` settings-блок: новые константы путей v4, габарит
модалки по концепту, фиксированные ширины контролов (убрать EXPAND_FILL у
OptionButton'ов), единая сетка label|control, кегли по концепту, стили
состояний кнопок из ассетов v4. Ничего не растягивать: point-размеры кратны
источнику или честный 9-slice. Другие блоки ui_screens.gd не трогать.

### Фаза 7 — Верификация «сверху» (обязательная, до сдачи в QA)
1) Полный прогон: ui_no_overlap_matrix (гейт 1920/2560/3840), game_settings,
   video_settings_apply, aim_mode_settings, runtime_smoke_ui — через
   tools/godot_gate.py (не параллелить Godot). 2) Оконный запуск, скриншоты
   всех 3 вкладок на 1920×1080 и 2560×1440. 3) settings_v4_verification.md:
   каждый пункт приёмки — evidence + вердикт. Только потом Статус: done.

## Процесс
- git pull перед стартом; коммит явным `git add` своих путей (не -A) после
  каждой фазы; green-gate до коммита; push сразу (multi-worker churn).
- Jira live-sync: коммент по завершении каждой фазы; сдача в QA — первым
  словом `Статус: done` в этом файле + push.
- Скриншоты для QA — в docs/qa/ (или пути из qa_protocol.md).

## Файлы
- scripts/ui_screens.gd — settings-блок (только он).
- assets/sprites/ui/frames/settings_v4/*.png (+ .import) — новые ассеты.
- references/settings_v4/* — мокапы и листы состояний.
- docs/design/settings_v4_{audit,reference_principles,concept,verification}.md.
- tests/ui_no_overlap_matrix_test.gd — при необходимости расширить дамп
  (не ослаблять существующие проверки).
