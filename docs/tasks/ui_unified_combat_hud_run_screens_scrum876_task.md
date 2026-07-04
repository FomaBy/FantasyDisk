# Единый боевой HUD на всех экранах забега

Jira: SCRUM-876
Статус: review
Контур: Claude
Owner: claude-busy-taussig-7e019f (user-directed chat)
Thread: current Claude worker
Worktree: .claude/worktrees/busy-taussig-7e019f
Branch: claude/busy-taussig-7e019f
Locked paths: scripts/ui_screens.gd (menu run hud); scripts/route_map_screen.gd; tests/dark_fantasy_ui_theme_test.gd; docs/design/systems/menus_ui.md

## Source Request

Пользователь (2026-07-04): «надо худ, который у нас во время боя, его же
перенести во все места, где этот худ используется. На карту, его нужно
перенести на экран выбора, вот, при повышении уровня, на экран выбора
характеристик из в награде и так далее».

## Проблема

Бой показывал SCRUM-806 слим-кластер (пиксель-иконки HP/XP/ULT + золото,
`ui_hud_v2_cluster_bg`), а все меню-экраны забега (карта, level-up, награды,
магазины, события, докачка) — СТАРУЮ карточную панель SCRUM-564
(«ОЗ 0/1 | Опыт 0/5 | 0g | Ульта 0%», 690x72). Два разных вида одного HUD.

## Решение

- `_create_menu_run_hud()` строит боевой кластер тем же
  `_create_resource_hud_panel` (параметр combat_layout удалён — боевой вид
  единственный) + responsive `_layout_combat_hud` (resized + deferred).
- Карта маршрута держит кластер под своим заголовком: новый
  `_layout_menu_resource_hud(root, origin)` кладёт панель на кастомный origin,
  а внутренности раскладывает относительно боевого ректа (внутренние 2K-зоны
  абсолютные, `_hud_v2_place_in_panel` вычитает позицию панели).
- Мёртвый карточный код удалён: `_hud_panel_style`, `_add_hud_resource_card`,
  `_add_hud_money_card`, `_hud_bar_fill_style`. `RouteMapHeader` использует
  `chud_resource_panel` @2K-рамку напрямую (тот же вид).
- `dark_fantasy_ui_theme_test` больше не зовёт удалённый `_hud_panel_style`
  (текстуру кластера гейтит runtime_smoke).
- Боевые-only элементы (таймер, боссбар, ascension-пипсы) остаются только в бою.

## Acceptance Criteria

- [x] Карта/level-up/награды/магазины/события показывают боевой кластер
      (та же текстура и раскладка баров), значения живые (`_update_hud`).
- [x] Кластер на карте не наслаивается на `RouteMapHeader` и скейлится
      с вьюпортом.
- [x] `runtime_smoke` PASSED (route map ассерт RunResourceHud+bars сохранён,
      боевые ассерты текстуры не тронуты).
- [x] `ui_no_overlap_matrix` PASSED. `dark_fantasy_ui_theme_test` PASSED.
- [x] Мёртвый код старого меню-худа удалён.

## Result

Done 2026-07-04 by claude-busy-taussig-7e019f (ожидает QA-вердикта).
Файлы: scripts/ui_screens.gd, scripts/route_map_screen.gd,
tests/dark_fantasy_ui_theme_test.gd, tools/capture_route_map_hud.gd (new),
docs/design/systems/menus_ui.md.
Tests: runtime_smoke PASSED, ui_no_overlap_matrix PASSED,
dark_fantasy_ui_theme PASSED, level_up_advisor PASSED.
Evidence: build/qa/scrum876/route_map_hud_1920x1080.png (кластер под
заголовком карты), build/qa/scrum871/level_up_advisor_*.png (кластер на
level-up).
Disk cleanup: none created (переиспользован worktree чата).
