# BALANCE: Возвышения — усилить монстров на низких, меньше элиток на высоких

Статус: done (2026-06-14, Claude Fable 5)
Приоритет: high
Роль: Back-end (баланс)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-358

## Результат (2026-06-14)
Переработан `ASCENSION_MODIFIERS` (data-driven, кумулятивность учтена):
- **Низкие — монстры сильнее/плотнее (не элитки):** L1 enemy_hp 1.15→1.20, dmg
  1.10→1.14; L3 spawn_count 1.20→1.26, spawn_cooldown 0.83→0.80.
- **Высокие — меньше элиток, пресс на монстров/босса:** L7 mini_elite_chance
  0.20→0.14; L8 +enemy_hp_mult 1.10; L9 +mini_elite_chance −0.06; L10
  +enemy_damage_mult 1.12, +mini_elite_chance −0.05.
- Итог mini_elite кривой: L7=0.14, L8=0.14, L9=0.08, L10=0.03 — **немонотонна,
  пик НЕ на максимуме, спад к высоким** (combat_director трактует ≤0 как «без
  элиток», `combat_director.gd:216`). Монстры монотонно крепнут до L10 hp×1.32.
- Гейт: новый `tests/ascension_curve_balance_test.gd` (свойства кривой). runtime
  smoke (его ascension-ladder проверка обновлена под новые числа), ascension
  curve, survivability — зелёные. balance-гейты ascension не используют (не задеты).

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Усилить монстров на простых возвышениях и уменьшить количество элиток на высоких
возвышениях».

Сейчас `ASCENSION_MODIFIERS` (scripts/progression_data_ascension.gd) кумулятивны
(уровень N = сумма модов 1..N). Низкие уровни: L1 enemy_hp 1.15/dmg 1.10, L3
spawn_count 1.20. Элитные: L4 «Свирепые элитки» (elite_hp 1.20, instant_phase),
L7 «Эхо бездны» (mini_elite_chance 0.20) — стакаются и сохраняются до самых
высоких уровней → на высоких возвышениях МНОГО элиток.

## Требования
1. **Усилить обычных монстров на низких (простых) возвышениях**: поднять
   monster-пресс на ранних уровнях (enemy_hp/damage и/или плотность волн на L1-L3),
   чтобы «простые» возвышения ощущались плотнее именно за счёт ОБЫЧНЫХ врагов,
   а не элиток. Значения data-driven, аккуратно (не ломать L0).
2. **Уменьшить количество элиток на высоких возвышениях**: переработать так, чтобы
   высокие уровни НЕ наваливали элиток — снизить/убрать mini_elite_chance и/или
   частоту элиток на высоких уровнях, сместив сложность в сторону усиленных
   монстерских волн/боссов. (Можно сделать elite-частоту немонотонной: пик не на
   максимуме.) Сохранить осмысленную кривую сложности.
3. Учесть кумулятивность: если моды складываются, добавить возможность
   уменьшать/переопределять элитные параметры на высоких уровнях (напр. поздний
   мод снижает mini_elite_chance), либо пересобрать таблицу.
4. Согласовать с общим балансом 0.1.5 и существующей системой
   ascension_difficulty (enemy scaling УМНОЖАЕТ stage_scale).
5. Тест: на низких возвышениях обычные монстры заметно сильнее/плотнее; на высоких
   число элиток МЕНЬШЕ, чем сейчас; runtime_smoke + ascension/balance тесты зелёные.
6. CHANGELOG; current_game_state; systems/progression_balance.

## Files / Assets / IDs
- scripts/progression_data_ascension.gd (ASCENSION_MODIFIERS 5-27; DEFAULTS;
  mini_elite_chance, elite_hp_mult, spawn_count_mult, enemy_hp/damage)
- scripts/progression_data.gd (ascension_difficulty_mods 334)
- scripts/combat_director.gd (spawn/elite применение)
- tests/runtime_smoke_test.gd (+ ascension-баланс проверки)

## Acceptance Criteria
- [ ] Низкие возвышения: обычные монстры сильнее/плотнее (пресс не от элиток).
- [ ] Высокие возвышения: элиток МЕНЬШЕ, чем сейчас; сложность смещена в монстров/босса.
- [ ] Кривая сложности осмысленна; L0 не сломан; runtime + balance smoke зелёные; CHANGELOG.

## Документация
docs/design/systems/progression_balance.md, current_game_state.
