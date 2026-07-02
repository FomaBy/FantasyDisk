# Перекраска семьи minimal_metal: жёлтый кант → тёмная латунь (экономика, награды, пауза, чип-HUD)

Статус: done
Роль: Back-end
Контур: Claude
Lane: claude
Версия: 0.1.8
Создано: 2026-07-02
Автор: SCRUM-809 аудит
Labels: foma, backend, claude

## Контекст

Аудит жёлтых рамок (SCRUM-809, `docs/design/audits/yellow_frames_audit_2026_07.md`):
семья `assets/sprites/ui/frames/minimal_metal/` — тёмный уголь с тонким
ярко-жёлто-оранжевым кантом — самая массовая жёлтая рамка в игре. Арт-дирекция
(SCRUM-806 reopen, `docs/tasks/combat_hud_compact_redesign_task.md`, раздел «Доработка
по фидбеку PM»): вместо ярко-жёлтых рамок — тёмная кожа + тонкая латунная линия
(референс `assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`), либо без рамки.

Затронутые текстуры (все в `assets/sprites/ui/frames/minimal_metal/`):

- `ui_frame_minimal_metal_card.png` (426×486) — карты наград (обычные+элитные),
  карты выбора экономики (событие/отдых/докачка/атрибуты).
- `ui_frame_minimal_metal_panel.png` (782×716) — генерик-панели `_create_menu_box`,
  панели экономики, группы статов паузы-досье.
- `ui_frame_minimal_metal_field.png` (616×286) — чипы CharacterStatsHud (В БОЮ —
  единственный жёлтый остаток боевого HUD), карточки межбоевого ресурс-HUD,
  ценники экономики, слот портрета кодекса, строки/чипы статов паузы.
- `ui_frame_minimal_metal_tooltip.png` (760×242) — тултипы экономики/кодекса.
- `ui_frame_minimal_metal_modal.png` (986×900) — fallback-модалка конца забега.

Код, который их применяет (менять НЕ требуется, если перекраска in-place):

- `scripts/ui/ui_theme_paths.gd` — MINIMAL_METAL_FRAME_PATHS/MARGINS/CONTENT (строки 10–64).
- `scripts/ui_screens.gd` — `_minimal_frame_style`, `_minimal_metal_frame_style`,
  `_reward_card_style`, `_economy_choice_style`, `_hud_card_style`,
  `_character_stats_hud_style`, `_codex_portrait_slot_style`, `_panel_style`,
  `_economy_panel_style` (искать по именам функций; константы ECONOMY_*/REWARD_*/
  COMBAT_HUD_CARD_PATHS/CODEX_PORTRAIT_SLOT_PATH в шапке файла, строки ~31–35, 160–170,
  370–380, 470–485, 575–585).
- `scripts/pause_stats_menu.gd:10–24` — preload'ы ESCAPE_PANEL_FRAME, STAT_BASIC_ROW_FRAME,
  STAT_GROUP_FRAME, STAT_CHIP_FRAME, STAT_TOOLTIP_FRAME, PAUSE_END_MODAL_FRAME.

## Что сделать

1. Скрин-капчи «до» затронутых экранов (экономика-выбор, награда, пауза-досье, бой с
   CharacterStatsHud, кодекс-портрет) в `build/qa/` — capture-тулзы в `tools/`
   (см. `tools/capture_*`; Godot 4.6.3, гонять через `tools/godot_gate.py`).
2. Перекрасить кант всех 5 текстур из ярко-жёлтого (#E8A33D-семейство, hue 30–68°,
   sat>0.42, val>0.52) в тёмную латунь как у `ui_hud_v2_cluster_bg.png` (пипеткой снять
   цвет линии: тёмный золотисто-коричневый, val ~0.3–0.45). Метод — python3+PIL
   таргет-перекраска по hue-маске (селектор: hue 30–68°, sat≥0.42, val≥0.52 → сдвиг
   val/sat вниз до латуни), РАЗМЕР PNG НЕ МЕНЯТЬ — тогда .import остаются валидными
   и 9-slice margins в `ui_theme_paths.gd` не трогаются.
3. Прогнать пиксель-скан краевой полосы (методика аудита): bright-доля каждой текстуры
   после перекраски < 5%.
4. Скрин-капчи «после» тех же экранов, глазами сверить с референсом cluster_bg.
5. Smoke-тесты UI (`tests/` через `tools/godot_gate.py`, один инстанс Godot).

## Acceptance Criteria

- [x] Все 5 текстур перекрашены: кант тёмно-латунный, тело угольное без изменений
      (бонусом перекрашена и 6-я, мёртвая `hud_strip` — семья палитрно единообразна).
- [x] Размеры PNG и 9-slice margins НЕ изменены (git diff только по содержимому PNG,
      без правок .import/ui_theme_paths.gd).
- [x] Пиксель-скан: bright-доля краевой полосы < 5% у каждой текстуры (факт: 0.0%).
- [x] Капчи до/после — согласованное в постановке SCRUM-817 отступление: подходящего
      capture-скрипта economy/shop в `tools/` нет, а `capture_combat_hud_v2.gd` требует
      оконный рендерер (небезопасно при живом редакторе). Вместо капч экранов —
      закоммиченные контрольные before/after превью всех 6 текстур в
      `docs/design/previews/scrum817/` (см. Прогресс).
- [x] Контент остаётся в safe-area фреймов: геометрия фреймов не менялась (только цвет
      канта), margins/content-инсеты в `ui_theme_paths.gd` нетронуты; подтверждено
      зелёным `ui_no_overlap_matrix_test`.
- [x] Smoke UI-тесты зелёные (`ui_no_overlap_matrix_test`, `runtime_smoke_test` — по 2
      прогона, включая итоговый HEAD origin/dev).

## Прогресс

2026-07-02, исполнитель: Claude (SCRUM-817).

Сделано:

- Написан переиспользуемый `tools/recolor_minimal_metal_brass.py` (python3+PIL+numpy):
  селективный HSV-ремап ТОЛЬКО жёлтых пикселей по маске аудита SCRUM-809
  (hue 30–68°, sat≥0.42, val≥0.52, alpha>0): hue −3°, sat ×0.68, val remap
  [0.52..1.0]→[0.30..0.50]. Режимы `--check` (сухой прогон + edge-band скан),
  `--preview-dir` (before/after листы), `--paths` (произвольные цели).
- Прогнан по всем 6 текстурам семьи `assets/sprites/ui/frames/minimal_metal/`
  (5 живых из спеки + мёртвая hud_strip для палитрного единообразия).
- Фактическая палитра: кант #E4AA34 → **#745D37** (тёмная латунь, H37° S0.53 V0.45),
  блик #F5C460 → **#7B6848** (приглушённый латунный блик, H37° S0.41 V0.48) —
  в вилке между линией референса cluster_bg (V~0.28–0.37) и латунью #8a6d3b,
  ниже bright-порога скана (V<0.52).
- Хирургичность подтверждена побайтово против HEAD: в каждой текстуре изменены
  ровно 2 цвета канта, alpha-канал и все остальные пиксели байт-в-байт нетронуты,
  размеры 1:1 (card 426×486, panel 782×716, field 616×286, tooltip 760×242,
  modal 986×900, hud_strip 1122×288). .import и `ui_theme_paths.gd` не менялись.
- Edge-band bright-скан (методика аудита, внешние 15% сторон):
  card 7.5→0.0%, panel 4.4→0.0%, field 8.6→0.0%, tooltip 9.2→0.0%,
  modal 3.5→0.0%, hud_strip 7.3→0.0% (AC <5% — с запасом).
- Контрольные before/after превью всех 6 текстур: `docs/design/previews/scrum817/`
  (+`.gdignore`, чтобы Godot не плодил .import для превью). Визуально сверены
  самые нагруженные: card (карты экономики/наград), field (ценники, чипы статов,
  боевой CharacterStatsHud), panel (группы статов паузы-досье) — тело угольное
  без изменений, кант тонкий тёмно-латунный в духе `ui_hud_v2_cluster_bg.png`.

Отступление от AC (согласовано в постановке): скрин-капчи экранов «до/после» в
`build/qa/` не снимались — capture-скрипта economy/shop нет, combat-капча требует
оконный рендерер (риск при живом редакторе пользователя); их заменяют закоммиченные
превью текстур выше.

Верификация (изолированный worktree `/private/tmp/fsd_wt_817` от origin/dev,
cherry-pick + полный `--import` через `tools/godot_gate.py`, fdengine, 1 слот):

- `tests/ui_no_overlap_matrix_test.gd` — PASSED (текстурные контракты путей целы);
- `tests/runtime_smoke_test.gd` — PASSED (duplicate-artifact guard 14314 файлов);
- оба теста перегнаны повторно после ребейза на свежий origin/dev
  (в окно заехал SCRUM-814 player.gd) — PASSED на итоговом HEAD.

Коммиты в origin/dev:

- `a8bec1f0866994761b41a789e5dd5aa3883b9bd8` — feat(SCRUM-817): перекраска канта
  семьи minimal_metal в тёмную латунь (6 PNG + tools/recolor_minimal_metal_brass.py
  + превью; локально 0cedcd95, перебазирован при пуше); ancestry в origin/dev
  проверена `git merge-base --is-ancestor`.
- коммит этой спеки (Статус: done + Прогресс) — отдельным пушем следом.

## Ссылки

- Аудит: `docs/design/audits/yellow_frames_audit_2026_07.md` (SCRUM-809), секция «волна 1».
- Арт-дирекция: SCRUM-806 reopen (`docs/tasks/combat_hud_compact_redesign_task.md`).
- Паттерн безопасной правки альфы/цвета без смены размера: memory
  alpha-flood-fill-fix-baked-bg (не менять размер → .import валиден).

## QA-Вердикт: PASSED
Статус: PASSED
QA claude-qa 2026-07-02 (изолированный worktree от origin/dev, независимая проверка).
- Диффскоуп: коммит a8bec1f0 трогает только 6 PNG minimal_metal + превью + tools/recolor_minimal_metal_brass.py; `.import` и `ui_theme_paths.gd` НЕ менялись (AC surgical-diff ✓).
- Размеры PNG 1:1 (card 426×486, panel 782×716, field 616×286, tooltip 760×242, modal 986×900, hud_strip 1122×288 — сверено против a8bec1f0^).
- Alpha-канал байт-в-байт идентичен во всех 6; изменены только пиксели канта (1.7–4.4%).
- Кант #E4AA34 → #745D37 (тёмная латунь H37° S53% V45%), блик #F5C460 → #7B6848 — как задано.
- Независимый edge-band bright-скан (hue 30–68°, sat≥0.42, val≥0.52, внешние 15%): 0.00% у всех 6 (AC <5% ✓). Превью до/после визуально сверены (card): яркий жёлтый → тонкая латунная линия, тело угольное без изменений.
- Тесты: ui_no_overlap_matrix_test PASS; runtime_smoke_test PASS (×2 после единичного known save-state флейка «autosave prompt» — SCRUM-817 меняет только PNG, к автосейв-логике отношения не имеет; см. memory godot-userdatadir-not-isolating-real-save).
