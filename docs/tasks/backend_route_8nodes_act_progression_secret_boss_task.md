# Прогрессия актов: 8 нодов до босса + босс в акте, секретный босс в конце 3 акта

Версия: 0.1.8 · Роль: backend · Контур: Claude · Приоритет: P1 · foma · Эпик: Бой, враги, боссы, события
Статус: done · Спринт: 0.1.8
Jira: SCRUM-786
Owner: Backend / Claude
Locked paths: scripts/route_map_screen.gd; scripts/main.gd (route-консты ROUTE_STEPS_TO_BOSS/ACT_COUNT/secret-boss)

## Что и зачем
Ускорить продвижение по актам. Сейчас 10 нодов до босса в каждом акте — слишком
длинно. Нужно **8 нодов до босса + сам босс** в каждом акте (3 акта), а **в конце
3 акта — секретный босс**. Игрок быстрее доходит до ключевых боёв, ран ощущается
динамичнее и менее затянутым.

Ожидаемый результат: путь по акту = 8 шагов-нодов, затем босс акта. После босса 3
акта запускается секретный (финальный) босс.

## Текущее состояние в коде
`scripts/main.gd`:
- `ROUTE_STEPS_TO_BOSS = 10` (≈26) — число нодов в акте до босса.
- `ACT_COUNT = 3` (≈27), `ACT_SCALING_STAGE_OFFSET = 4` (≈28).
- `MIN_BRANCHES_PER_STEP = 2` (≈29), `MAX_BRANCHES_PER_STEP = 4` (≈30).
- `current_act` (≈375), `route_stage` (≈376), `route_scaling_stage()` (≈773):
  depth = route_stage + (current_act-1)*4.
- `advance_to_next_act()` (≈823–827): инкремент акта, route_stage=0, новый route.
- `should_start_secret_boss_after_act3()` (≈912–915) — флаг секретного босса после
  босса 3 акта (secret_ascension_boss; см. SCRUM-701/702).

`scripts/route_map_screen.gd`:
- Генерация route: 2D-массив `route[step][branch]`, boss в `route[ROUTE_STEPS_TO_BOSS]`.
- `_node_pool_for_step` (≈201–212) — пул типов нодов по индексу шага (хардкод диапазоны
  0-1 battle-only, 2 …, 3-7 …, 8-9 …, pre-boss). **Завязан на 10 шагов.**
- `_place_required_shop_nodes` (≈281–289) — шопы в строках 2-4 и 5-9. **Завязан на 10.**
- `_place_central_chest_node` (≈307–320) — сундук на midpoint `floor((non_boss_rows-1)*0.5)`.
- `_place_altar_node` (≈239–278), `_assign_route_connections` (≈374–402),
  `_route_connection_candidates` (≈405–426) — связи нодов (ветвление).
- `START_BATTLE_ONLY_ROWS` (=2) — первые ряды только бои.

## Что сделать — по шагам
1. **8 нодов до босса.** `ROUTE_STEPS_TO_BOSS = 10 → 8`. Босс теперь в `route[8]`.
2. **Адаптировать пул типов нодов под 8 шагов.** `_node_pool_for_step` сейчас
   хардкодит диапазоны под 10 рядов (2 battle-only старт, события/elite/hazard в
   3-7, тяжёлые в 8-9). Переписать диапазоны под 8 рядов (0..7), сохранив логику:
   - первые `START_BATTLE_ONLY_ROWS` рядов — только battle (можно оставить 2);
   - середина — battle/event/rest/elite/hazard;
   - предбоссовые ряды — без перегруза (elite/rest), как было задумано.
   Использовать индексы относительно ROUTE_STEPS_TO_BOSS, а не магические числа,
   чтобы при будущих изменениях не ломалось.
3. **Адаптировать размещение шопа/алтаря/сундука под 8 рядов.**
   `_place_required_shop_nodes`: гарантировать 1 шоп в первой половине, 1 во второй
   (диапазоны пересчитать от ROUTE_STEPS_TO_BOSS). Алтарь — как раньше (внутренний
   ряд). Сундук — координировать с задачей о chest-линиях
   ([[backend_route_chest_lines_unmissable_task]]); в ДАННОЙ задаче сундук НЕ
   переписывать (это делает chest-задача), только не сломать существующий вызов.
4. **Босс в каждом акте.** Подтвердить, что boss-нод по-прежнему генерится в
   `route[ROUTE_STEPS_TO_BOSS]` для всех 3 актов и `advance_to_next_act()` корректно
   стартует новый 8-нодовый route.
5. **Секретный босс в конце 3 акта.** Проверить/обеспечить, что после победы над
   боссом 3 акта `should_start_secret_boss_after_act3()` запускает секретного босса
   (secret_ascension_boss). Если уже работает (SCRUM-701/702) — только верифицировать
   и не сломать при смене числа нодов. Если не достроено — реализовать запуск
   секретного босса как финал ран'а после акта 3.
6. **Связи/ветвление.** Убедиться, что `_assign_route_connections` /
   `_route_connection_candidates` корректно работают на 8 рядах (все ноды следующего
   ряда достижимы, нет «висячих» нодов), ветвление 2–4 сохранено.
7. Прогнать `tests/route_chest_artifact_test.gd`, runtime smoke и любые route-тесты;
   убедиться, что генерация route не падает и проходима от старта до босса.

## Acceptance Criteria
- [x] Путь по каждому акту = 8 нодов, затем босс (boss-нод в route[8]).
- [x] Все 3 акта генерятся корректно; advance_to_next_act даёт новый 8-нодовый route.
- [x] Пулы типов нодов, шоп/алтарь/сундук размещаются валидно на 8 рядах (без
      пустых/невалидных рядов, без потери гарантированных нодов).
- [x] После босса 3 акта запускается секретный босс (финал ран'а).
- [x] Ветвление 2–4 сохранено; все ноды следующего ряда достижимы (нет тупиков).
- [x] Route-тесты и smoke зелёные; route проходим от старта до босса.

## Результат (backend / claude-backend, 2026-06-30)
- `main.gd`: `ROUTE_STEPS_TO_BOSS 10→8` — босс теперь в `route[8]`.
- `route_map_screen.gd`: `_node_pool_for_step` переписан без магического `<= 2` —
  границы рядов вычисляются от `ROUTE_STEPS_TO_BOSS` (старт→старт+1→середина→
  последняя треть `boss_row-3`→предбосс `boss_row-1`). Шоп/алтарь/сундук/связи уже
  были row-count-relative (от `non_boss_rows`) — адаптировались автоматически, проверено.
- Сундук НЕ трогал (по спеке — это SCRUM-787).
- Секретный босс после акта 3 (`should_start_secret_boss_after_act3` / SCRUM-701/702)
  верифицирован — не зависит от числа нодов.
- `tests/runtime_smoke_test.gd`: ассерты числа рядов (11) и высоты canvas (1700)
  переведены на `EXPECTED_ROUTE_STEPS_TO_BOSS` (8), иначе ложный fail.
- Гейты зелёные: route_generation_reachability (24 routes, 8 rows+boss),
  route_chest_artifact, route_node_preview, runtime_smoke, progression_economy.

## Files / точки входа
- scripts/main.gd — `ROUTE_STEPS_TO_BOSS` (≈26), `should_start_secret_boss_after_act3`
  (≈912–915), `advance_to_next_act` (≈823–827).
- scripts/route_map_screen.gd — `_node_pool_for_step`, `_place_required_shop_nodes`,
  `_place_altar_node`, `_assign_route_connections`, `_route_connection_candidates`.

## Замечания / подводные камни
- В одной волне с [[backend_route_chest_lines_unmissable_task]] — общий
  route_map_screen.gd/main.gd; делать последовательно одним контуром, не параллелить
  с combat-задачами (combat правит другой контур, но main.gd общий — НЕ пересекаться
  по времени с combat-волной).
- Магические числа рядов (3-7, 8-9, 5-9) — заменить на вычисления от
  ROUTE_STEPS_TO_BOSS, иначе при 8 рядах пулы съедут.
- Не сломать детерминизм seed'ов нодов и `route_selected_indices`.
- main.gd dirty на старте — точечные правки.
