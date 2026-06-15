# Баланс монстров + размеры элиток: мини-элитки возвышения МЕНЬШЕ, элитки на карте БОЛЬШЕ и страшнее

Статус: done
Приоритет: high
Роль: Back-end (баланс/бой)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-260
QA: in_progress (2026-06-14)
Эпик-патч: 0.1.5 Бой и баланс (SCRUM-232)

## Sprint 0.1.5
Фича-фриз снят после релиза `v0.1.4`; задача входит в активный sprint 0.1.5 и
готова к dispatch, если нет file-collision с уже взятой Back-end задачей.

## Dispatcher Dispatch (2026-06-13)

Отправлено в существующий Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`
как 0.1.5 Back-end task. Keep reasoning High/no low. Указан collision context:
SCRUM-256 уже `in_progress` и может трогать `scripts/progression_data.gd`; если
SCRUM-260 требует тот же файл, сериализовать работу или явно заблокировать, а не
смешивать правки.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Переделать баланс монстров. Элитки, которые идут ПОСЛЕ возвышений (свита) —
должны быть МЕНЬШЕ по размеру. Элитки, которые встречаются НА КАРТЕ — должны
быть БОЛЬШИМИ и страшными».

Сейчас (enemy.gd): `EPIC_ELITE_SCALE := 1.4`, `EPIC_BOSS_SCALE := 1.9`,
`_epic_scale_factor()` (139-145) — один размер для всех элиток. Мини-элитки
свиты возвышения (combat_director `_maybe_spawn_mini_elite`/`_apply_mini_elite_kind`,
meta `drop_class="mini_elite"`, HP×0.55) визуально НЕ отделены по размеру.

## Требования
1. **Развести размеры элиток по типу:**
   - **Мини-элитки свиты возвышения** (meta `mini_elite`) — заметно МЕНЬШЕ
     обычной элитки (например множитель ~0.9-1.05, между мобом и полноценной
     элиткой), визуально читаются как «усиленный моб», а не босс.
   - **Карточные элитки** (основная элитка узла маршрута, `_spawn_elite_enemy`)
     — БОЛЬШЕ и страшнее (поднять elite scale, например 1.4→1.6-1.8, согласовать
     хитбокс/contact_range/health-bar через единый node scale, как сейчас).
   - Боссы — остаются доминантно крупными (проверить, что карточная элитка не
     сливается с боссом по размеру).
   - Размеры — data-driven/по meta, не хардкод вперемешку.
2. **Баланс монстров (общий пересмотр):** HP/урон/скорость обычных мобов,
   жирных, мини-элиток, элиток и боссов — согласовать со шкалой сложности
   (stage_scale) и патчем выживаемости игрока (нерф регена/вампиризма): монстры
   не должны стать тривиальными после ослабления саслейна игрока. Через
   balance_harness / survivability сценарии; в коридорах глобального smoke
   (backend_global_balance_smoke_damage_survivability_task SCRUM-249).
3. Хитбоксы/contact_range/HP-бары масштабируются согласованно с новым размером
   (правило enemy.gd: один node scale тянет визуал+хитбокс+бар).
4. Тест (smoke): фактический scale мини-элитки < scale карточной элитки <
   scale босса; баланс-метрики в коридорах.
5. CHANGELOG; mechanics_extract (размеры/баланс монстров); current_game_state.

## Files / Assets / IDs
- scripts/enemy.gd (EPIC_ELITE_SCALE/EPIC_BOSS_SCALE:115-116, _epic_scale_factor:139,
  _apply_epic_scale:148)
- scripts/combat_director.gd (_spawn_elite_enemy:499, _maybe_spawn_mini_elite:210,
  _apply_mini_elite_kind:268)
- scripts/progression_data.gd (mini_elite_kinds, элитки/боссы данные)
- tools/balance_harness.gd, tests/

## Acceptance Criteria
- [x] Мини-элитки свиты меньше; карточные элитки крупнее и страшнее; босс крупнее всех.
- [x] Размеры data-driven; хитбоксы/бары согласованы.
- [x] Баланс монстров пересмотрен под нерф игрока; глобальные smoke в коридорах.
- [x] Тест порядка размеров; smoke/balance зелёные; CHANGELOG/доки.

## Result Summary (2026-06-13)

Back-end реализация завершена:
- добавлен `ProgressionData.ENEMY_SIZE_PROFILES` (`ordinary=1.00`, `mini_elite=1.05`, `elite=1.68`, `boss=1.90`);
- `enemy.gd` читает meta `epic_scale_profile` и применяет data-driven node scale до согласованного visible/collision/contact/HP-bar поведения;
- mini-элитки Возвышения получают `epic_scale_profile=mini_elite` до `_ready()`, поэтому больше не выглядят как полноценные route-элитки;
- карточные элитки получают `epic_scale_profile=elite`, стали крупнее и чуть страшнее: HP x1.08, damage x1.06 поверх прежнего elite budget;
- боссы получают `epic_scale_profile=boss` и остаются крупнейшим enemy rank;
- обновлены `tests/runtime_smoke_test.gd` и `tests/progression_data_api_surface_test.gd`;
- обновлены `CHANGELOG.md`, `docs/design/mechanics_extract.md`, `docs/design/current_game_state.md`, `docs/design/systems/enemies_bosses.md`.

Verification:
- `progression_data_api_surface_test.gd` — passed;
- `runtime_smoke_boss_elite_test.gd` — passed;
- `global_damage_balance_smoke_test.gd` — passed;
- `global_survivability_balance_smoke_test.gd` — passed;
- `runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: e09d679e (ветка dev)

Проверено (фактически, на зелёном HEAD после стабилизации дерева):
- **Размеры data-driven**: профили mini_elite 1.05 / route elite 1.68 / boss 1.90
  (мини-элитки меньше, карточные элитки крупнее, босс крупнее всех).
- **Целевой тест** `runtime_smoke_boss_elite_test` — passed (включает
  `_test_epic_elite_boss_scale_hitbox` — согласованность хитбоксов/contact/HP-бар
  с новым размером); api_surface — passed.
- **Баланс в коридоре**: `global_damage_balance` (51 пара) + `global_survivability`
  — зелёные; runtime — зелёный.

Acceptance:
- [x] Мини-элитки меньше, карточные элитки крупнее/страшнее, босс крупнее всех.
- [x] Размеры data-driven; хитбоксы/бары согласованы (scale-hitbox тест).
- [x] Баланс в коридорах; smoke зелёные.

Примечание: первичный QA-прогон ловил падения boss_elite/runtime — это была
ТРАНЗИЕНТНАЯ churn активного воркера SCRUM-273 (кит кнопок, mid-edit ui_screens.gd),
НЕ дефект SCRUM-260. После коммита кита билд зелёный, перепроверено.

Баги: нет.
