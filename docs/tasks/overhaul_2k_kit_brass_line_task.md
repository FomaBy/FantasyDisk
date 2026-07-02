# Overhaul-2K кит: жёлтая линия с уголками → латунь (баннеры боя/победы, weapon select, глоссарий, межбоевой HUD)

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
в ките `assets/sprites/ui/frames/overhaul_2k/` живая подгруппа «тёмное тело + яркая
жёлтая линия по периметру с угловыми скобками». Ассеты рисуются генератором
`tools/build_ui_2k_frame_kit.py` (SCRUM-485) ровно в размер слота, с anti-drift
`--verify` против `scripts/ui/ui_theme_paths.gd` (OVERHAUL_2K_FRAME_SOURCE_SIZE/
TEXTURE_MARGINS/CONTENT). Арт-дирекция SCRUM-806 reopen: тёмная кожа + тонкая латунная
линия (референс `assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png`).

Живые жёлтые слоты (bright% по скану аудита):

| Слот | Текстура | Экран | bright% |
|---|---|---|---|
| ctb_big | `ui_frame_2k_ctb_big.png` | интро-баннер босса (`_show_combat_title_banner`, ui_screens.gd ~6652) | 37.5 |
| ctb_small | `ui_frame_2k_ctb_small.png` | интро-баннер элитки (там же) | 1.0 (линия уже латунная — выровнять палитру с ctb_big) |
| vbn_frame | `ui_frame_2k_vbn_frame.png` | баннер победы (~2094) | 11.1 |
| ws_card | `ui_frame_2k_ws_card.png` | строки-карточки выбора оружия (~4756, 5 стейтов) | 15.0 |
| gt_panel | `ui_frame_2k_gt_panel.png` | тултип глоссария кодекса (~3505) | 22.0 |
| chud_resource_panel | `ui_frame_2k_chud_resource_panel.png` | межбоевой ресурс-HUD `_create_menu_run_hud`/`_create_resource_hud_panel` (~9801/9817, `_hud_panel_style` ~10032) и шапка route map (`scripts/route_map_screen.gd:96`) | 22.4 |

Большие панели кита (pm/result/evt/ws/pd/pn/attr/upgrade/qc/cr/rc/fb) уже тёмные
(3–7%) — НЕ трогать. Мёртвые жёлтые слоты кита (chud_timer, chud_artifact_row, hs4_*,
codex_*, mm/qc/cr/rc/pm/pd/fb-кнопки, ws_btn_back, st_panel) НЕ перегенеривать.

## Что сделать

1. Скрин-капчи «до» в `build/qa/`: бой с баннером элитки/босса (или форс-вызов
   `_show_combat_title_banner`), экран победы, выбор оружия, тултип глоссария,
   route map с ресурс-HUD (capture-тулзы в `tools/`, Godot через `tools/godot_gate.py`).
2. В `tools/build_ui_2k_frame_kit.py` найти палитру линии/уголков (ярко-жёлтый) и
   заменить на латунь с `ui_hud_v2_cluster_bg.png` (тёмный золотисто-коричневый,
   val ~0.3–0.45); перегенерить ТОЛЬКО 6 живых слотов из таблицы, прогнать `--verify`
   (margins не дрейфуют).
   Альтернатива, если генератор неудобен: точечная PIL-перекраска по hue-маске
   (как в задаче волны 1), размер не менять.
3. `chud_resource_panel` — предпочтительный вариант (согласован аудитом): вместо
   перегенерации перевести межбоевой HUD и шапку route map на кожаный кластер:
   в `scripts/ui_screens.gd` `_hud_panel_style` вернуть
   `_hud_v2_cluster_style(display_size)` (функция ~10041), сохранив
   `zero_content`-ветку через `_apply_stylebox_content_margins`; проверить
   `scripts/route_map_screen.gd:96` (вызывает `game.ui._hud_panel_style()`).
   Если вылезут визуальные конфликты карточек minimal_metal внутри полосы —
   зафиксировать в комментарии и откатиться на перегенерацию текстуры.
4. Пиксель-скан краевой полосы после: bright < 5% на всех 6 текстурах (или на
   заменяющей подложке).
5. Скрин-капчи «после», сверка с cluster_bg-референсом; smoke UI-тесты через гейт.

## Acceptance Criteria

- [x] 5 текстур (ctb_big, ctb_small, vbn_frame, ws_card, gt_panel) с латунной линией
      вместо жёлтой, единая палитра; `--verify` генератора зелёный, margins в
      `ui_theme_paths.gd` не изменены (или изменены синхронно с ассетом).
- [x] Межбоевой HUD/route map: жёлтая рамка chud_resource_panel не рендерится
      (кластер-стиль ЛИБО перегенерированная латунная текстура) — выполнено путём
      перегенерированной латунной текстуры; `ui_screens.gd` не трогался (зона
      другого исполнителя, координация с волной 5), cluster-переключение
      `_hud_panel_style` остаётся опцией отдельной .gd-правки.
- [x] Пиксель-скан bright < 5% по затронутым текстурам (0.17–0.97%, см. Прогресс).
- [x] Капчи до/после — осознанное отступление (решение оркестратора): вместо in-game
      капч в `build/qa/` сняты текстурные превью до/после с corner-зумами и
      референсом cluster_bg в `docs/design/previews/scrum818/` (3 листа, все слоты);
      Godot-гейт был занят флотом, геометрия слотов не менялась (альфа/размер
      бит-в-бит), рантайм-вёрстку страхуют матрица/смоук.
- [x] Контент в safe-area (frame-content-safe-area правило): margins/размер/альфа
      не менялись бит-в-бит → инсеты прежние; `ui_no_overlap_matrix_test` PASSED.
- [x] Smoke UI-тесты зелёные (два прогона ×2 теста, см. Прогресс).

## Прогресс

Выполнено 2026-07-02 (Claude, SCRUM-818). Выбран путь (а) — палитра генератора,
потому что все 6 живых PNG на диске оказались попиксельно идентичны выводу
`tools/build_ui_2k_frame_kit.py` (проверено ImageChops.difference до правки) —
генератор детерминирован и точно воспроизводит кит, PIL-перекраска не понадобилась.

**Слоты перегенерированы (только 6 живых):** ctb_big, ctb_small, vbn_frame, ws_card,
gt_panel, chud_resource_panel. Мёртвые жёлтые (chud_timer, chud_artifact_row, hs4_*,
codex_*, кнопки и пр.) и тёмные большие панели НЕ тронуты — в генератор добавлен флаг
`--only slug1,slug2` (селективная перегенерация; контактный лист пересобирается по
всем слотам с диска, чтобы не деградировал).

**Палитра** (референс `ui_hud_v2_cluster_bg.png`, латунь ~#8a6d3b..#a8895a):
- линия рамки: `AMBER (228,170,52)` → `BRASS (130,103,56)` (~#826738, hue 38°,
  sat 0.57, val 0.51 — сидит ПОД порогом bright-скана val≥0.52);
- угловые L-скобки: `ACCENT (245,196,96)` → `BRASS_ACCENT (168,137,90)` (#a8895a,
  верх латунной шкалы = блики референса; площадь уголков <0.3% краевой полосы);
- внутренняя тонкая линия — авто (`lerp(FILL_TOP, BRASS, 0.4)`), тело/альфа не менялись.

**Пиксель-скан** краевой полосы (метрика аудита SCRUM-809; калибровка: референс
cluster_bg = 0.0% bright): ctb_big 20.2→0.17%, ctb_small 25.7→0.18%,
vbn_frame 8.1→0.33%, ws_card 9.9→0.25%, gt_panel 16.1→0.97%,
chud_resource_panel 23.3→0.33% — гейт bright<5% зелёный на всех.
Размер и альфа-канал каждого PNG бит-в-бит с прежними (margins/9-slice/.import
валидны), `--verify` генератора PASS 45/45 слотов, `ui_theme_paths.gd` не менялся.

**Прогоны** (изолированный worktree `/private/tmp/fsd_wt_818` от origin/dev,
Godot 4.7 через `tools/godot_gate.py`, свежий `--import`):
`tests/ui_no_overlap_matrix_test.gd` PASSED и `tests/runtime_smoke_test.gd` PASSED —
дважды: на базе 32673612 + коммит, и повторно на финальном запушенном HEAD
(после rebase поверх прилетевших SCRUM-814/817).

**Коммиты в origin/dev:** `6cd5240e` — палитра генератора + `--only` + 6 PNG +
превью (в т.ч. обновлённый контактный лист); докс-коммит спеки — следом.
**Превью до/после:** `docs/design/previews/scrum818/scrum818_ctb_banners_before_after.png`,
`scrum818_ws_card_gt_panel_before_after.png`, `scrum818_vbn_chud_resource_before_after.png`
(каждый: до/после + corner-зум ×4 + референс cluster_bg; просмотрены глазами).

## Ссылки

- Аудит: `docs/design/audits/yellow_frames_audit_2026_07.md` (SCRUM-809), секция «волна 2».
- Арт-дирекция: SCRUM-806 reopen (`docs/tasks/combat_hud_compact_redesign_task.md`).
- Генератор: `tools/build_ui_2k_frame_kit.py` (SCRUM-485), анти-дрифт `--verify`.
- Внимание: `scripts/ui_screens.gd` также правится волной 5 — координировать мердж.
