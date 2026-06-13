# Баланс монстров + размеры элиток: мини-элитки возвышения МЕНЬШЕ, элитки на карте БОЛЬШЕ и страшнее

Статус: in_progress
Приоритет: high
Роль: Back-end (баланс/бой)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-260
Эпик-патч: 0.1.5 Бой и баланс (SCRUM-232)

## PM Override (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Эта уже существующая board-задача поднята из backlog `0.1.5` в текущий релиз и
отправлена владельцу. Новые задачи после этой директивы остаются backlog
`0.1.5`, если PM явно не решит иначе.

## Dispatcher Redispatch (2026-06-13)

Отправлено в существующий Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`
как часть serialized 0.1.4 board-completion queue. Keep reasoning High/no low.
Back-end owns size/balance/meta/tests; sprite/VFX clarity goes to Design, motion
naturalness and attack-state timing go to Animator if uncovered.

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
- [ ] Мини-элитки свиты меньше; карточные элитки крупнее и страшнее; босс крупнее всех.
- [ ] Размеры data-driven; хитбоксы/бары согласованы.
- [ ] Баланс монстров пересмотрен под нерф игрока; глобальные smoke в коридорах.
- [ ] Тест порядка размеров; 6 smoke зелёные; CHANGELOG/доки.
