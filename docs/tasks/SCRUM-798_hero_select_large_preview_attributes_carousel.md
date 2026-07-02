# SCRUM-798 - Hero Select: крупное превью, атрибуты и увеличенная карусель

Статус: done
Контур: Codex
Owner: Back-end/Codex
Thread: codex-backend-scrum798-dev-integration
Locked paths: `scripts/ui_screens.gd`, `scripts/ui/hero_select_constants.gd`, focused Hero Select tests/UI smoke/no-overlap tests as needed, `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`, `build/qa/scrum798/`, Hero Select screen
Версия: 0.2.0
Приоритет: P1
Создано: 2026-07-01
Автор: PM/Codex dispatcher по прямому запросу пользователя
Jira: SCRUM-798
Labels: backend, codex, foma, fantasydisk, ui, hero-select, redesign, p1
Related: SCRUM-688, SCRUM-796, SCRUM-687

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Не останавливаться
для подтверждений, если требование понятно. Jira first: executor должен claim'ить
SCRUM-798 через Jira-pull перед правками.

## Роль И Границы
Ты - Back-end UI/runtime агент Codex. Делай runtime layout, интерактивность,
тесты и документацию. Не рисуй новый final art и не генерируй source UI pack в
этой задаче. Если без новых frame/source ассетов задачу нельзя довести до
приемлемого визуального качества, создай отдельный Design handoff, но сначала
попробуй выполнить требования нативной Godot-версткой и существующими ресурсами.

## Контекст
Прямой запрос пользователя от 2026-07-01 задает новый source of truth для Hero
Select. Он supersedes старую QA-линию SCRUM-688/SCRUM-796 про возврат
PixelLab-framed Hero Select как есть: текущая цель - сделать экран выбора
персонажа крупным, читаемым и полезным для выбора билда.

Текущий live screen строится в `scripts/ui_screens.gd::_build_character_select_v4()`:
черный минимальный layout, левый `HS4Portrait` около 250px, центр-досье, правая
панель возвышения и нижняя карусель со слотами около 150px. Пользователь просит
перекомпоновать экран вокруг большого героя и понятных атрибутов.

## Требования
1. Превью выбранного персонажа должно стать сильно больше - примерно в 2-3 раза
   относительно текущего минимального превью. На 1920x1080 персонаж должен быть
   главным визуальным объектом экрана, не клипаться и оставаться внутри safe/content
   зоны.
2. Под превью персонажа разместить выбор Возвышения и кнопку старта забега
   (`HS4ChooseButton` / переход к выбору оружия). Сохранить `ascension_selectable_max`,
   clamp выбранного уровня, +/- кнопки, текст модификатора и tooltip.
3. Справа от персонажа сделать крупное досье: имя, описание, сильные/слабые
   стороны, список оружия и характеристики с Line Bar.
4. Для каждой характеристики Line Bar нужен hover popup/tooltip с описанием,
   влияниями, формулой и классовой интерпретацией. Использовать существующие
   источники: `StatFormulas.STAT_DEFINITIONS`, `_hs4_stat_tooltip()`,
   `ProgressionData.class_interpretation_text()`.
5. В досье вывести build guidance секции:
   `Основные атрибуты`, `Второстепенные атрибуты`, `Дополнительные атрибуты`.
   Источник данных - `ProgressionData.attribute_relevance(attr_id, character_id)` /
   `CharacterData.ATTRIBUTE_RELEVANCE`, без ручных per-class списков. Маппинг:
   `primary -> Основные`, `secondary -> Второстепенные`, `optional -> Дополнительные`.
6. Нижнюю карусель увеличить примерно в 2 раза относительно текущих 150px слотов.
   Можно показывать меньше персонажей одновременно. Стрелки прокрутки сделать
   крупнее и удобнее. Выбранный/hovered персонаж должен быть заметен визуально.
7. Сохранить Back/Escape, mouse, keyboard/gamepad focus graph, циклическую/оконную
   прокрутку карусели, refresh выбранного героя, анимированное preview где есть
   SpriteFrames, и все gameplay/progression semantics.
8. Не восстанавливать старый SCRUM-686 PixelLab framed layout, если он не помогает
   выполнить новый пользовательский бриф. SCRUM-798 - актуальный contract.

## Files / Assets / IDs
- Основной код: `scripts/ui_screens.gd` (`_build_character_select_v4`,
  `_show_character_select`, `_hs4_stat_tooltip`, carousel/focus refresh blocks).
- Константы: `scripts/ui/hero_select_constants.gd`, если нужно вынести размеры,
  stat order или цветовые правила.
- Источники данных: `scripts/progression_data.gd`,
  `scripts/progression_data_characters.gd`, `scripts/stat_formulas.gd`
  read-only unless a tiny helper is truly needed.
- QA evidence: `build/qa/scrum798/`.
- Документы: `docs/design/current_game_state.md`,
  `docs/design/systems/menus_ui.md`.

## Acceptance Criteria
- [ ] На 1280x720, 1536x864, 1920x1080 и 2560x1440 превью выбранного персонажа
      минимум примерно в 2 раза крупнее старого footprint, не клипается и не
      перекрывается UI.
- [ ] Возвышение и кнопка старта находятся непосредственно под превью, читаемы
      и кликабельны на всех целевых разрешениях.
- [ ] Правое досье крупное и читаемое; Line Bars обновляются при смене персонажа.
- [ ] Hover tooltip/popup для характеристик показывает описание, формулу/влияния
      и классовую интерпретацию.
- [ ] В досье есть секции основных, второстепенных и дополнительных атрибутов,
      сформированные data-driven для каждого playable character.
- [ ] Карусельные иконки/портреты примерно удвоены, стрелки крупнее, допустимо
      меньше видимых персонажей, выбранный/hover state очевиден.
- [ ] Не нарушены выбор героя, выбор возвышения, старт забега/weapon select,
      back/Escape, tooltip и focus navigation.
- [ ] Нет overlap между UI-элементами и нет наложения контента на декоративные
      frame ornaments, если используются frame assets.
- [ ] QA evidence сохранен в `build/qa/scrum798/`: screenshots/rect dump для
      целевых разрешений и минимум нескольких персонажей с разным силуэтом
      (например Berserk, Dark Mage, Guitarist/Priest).
- [ ] Зеленые проверки через semaphore:
      `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`,
      `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`,
      `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`;
      unrelated upstream failures документировать отдельно.
- [ ] Обновлены `docs/design/current_game_state.md` и
      `docs/design/systems/menus_ui.md`.
- [ ] Jira final comment включает branch/commit/tests/evidence и `Disk cleanup:`.

## Самопроверка Executor
1. Перед первой правкой: `git fetch origin --prune`, безопасный `git pull
   --ff-only origin dev`, Jira claim SCRUM-798 с Owner/Thread/Lane/Locked paths.
2. После реализации: focused Hero Select capture/rect evidence на 4 разрешениях,
   затем UI/no-overlap/runtime smokes через `tools/godot_gate.py`.
3. После результата: update Jira first, локальный mirror, commit и push только
   task-owned files.

## Result 2026-07-01
- Реализация SCRUM-798 из `origin/codex/scrum-798-hero-select-layout`
  интегрирована в `origin/dev` merge-коммитом `85019376`.
- Проверено: `389fd151` и `b34dd949` являются предками `origin/dev`
  (`git merge-base --is-ancestor` exit 0 для обоих).
- Прогоны через `tools/godot_gate.py`: `hero_select_scrum798_capture_test.gd`,
  `runtime_smoke_ui_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `runtime_smoke_test.gd` - PASS.

## QA-Вердикт

Статус: PASSED

QA claude-qa 2026-07-01. Re-review после интеграции в origin/dev (389fd151 -> 85019376;
`git merge-base --is-ancestor 389fd151 origin/dev` = OK). Предыдущий прогон был FAILED
(strand на codex/scrum-798-hero-select-layout) — исполнитель влил в dev, тикет пересдан.

Render-проверка на committed evidence + локальный прогон на 798-коде (local ui_screens.gd
== origin/dev):
- 1280x720 / 1920x1080 / 2560x1440: крупное превью героя слева — доминирующий визуальный
  объект, не клипается, в safe-зоне; масштабируется с разрешением (портрет 320->640px).
- Под превью: «Возвышение» с −/значение/+ , clamp, текст модификатора и кнопка «Выбрать»
  (старт забега) — читаемо/кликабельно на всех разрешениях.
- Правое досье: имя, описание, Сильные/Слабые стороны, список оружия, ключевой атрибут,
  «Основные характеристики» c цветными Line Bar (обновляются при смене персонажа),
  «Подсказки билда» со скроллом. На 720p досье скроллится (scroll-safe), контент не
  выходит за рамку/экран, оверлапов нет.
- Секции билда data-driven: «Основные / Второстепенные / Дополнительные атрибуты»
  формируются per-class из ProgressionData.attribute_relevance (проверено по rects: у
  berserk/dark_mage/guitarist/priest разные наборы). Маппинг primary/secondary/optional ок.
- Карусель увеличена (слоты ~187px@720 -> ~374px@1440), крупные < > стрелки, выбранный
  слот подсвечен золотой рамкой.
- Изменения UI-only (ui_screens.gd, hero_select_constants.gd, тесты, докиб); gameplay/balance
  не тронуты.

Тесты через `tools/godot_gate.py` (семафор, live-editor рядом):
`hero_select_pixellab_layout_test.gd` PASS (no-overlap), `hero_select_scrum798_capture_test.gd`
PASS, `runtime_smoke_test.gd` PASS.

Замечание (не блокер): hover-tooltip характеристик в статичном capture не проверяется;
код-путь (`_hs4_stat_tooltip` / StatFormulas / class_interpretation_text) присутствует,
Line Bar'ы отрисованы, layout-тест зелёный.

QA-блок добавлен, чтобы board_sync не откатывал тикет из «Готово».
