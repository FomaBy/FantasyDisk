# SCRUM-1067 → SCRUM-1068 implementation test plan

Этот документ — executable acceptance plan для реализации design contract. Он
не является runtime-тестом SCRUM-1067 и не ослабляет действующие gates.

## Static/data gates

1. `validate_scrum1067_constellation_spec.py` проходит на canonical manifest.
   `test_validate_scrum1067_constellation_spec.py` отдельно принимает canonical
   и отклоняет critical deep-copy mutations без изменения файлов.
2. Runtime data содержит 17 классов, 306 явных branch nodes, 51 уникальный
   canonical `weapon_id`, 51 уникальный `final_id`/`mechanic_id`, 34 явных
   hidden side nodes.
3. На класс: `1 core + 3×6 branch + 2 hidden = 21`; total cost `20`.
4. У каждого branch-node есть owning `class_id`/`weapon_id`, order 1..6,
   cost=1, affected axis, title, caps, unique fixture и зарегистрированный
   consumer/effect profile; указанный consumer path существует.
5. Unknown/no-op effect key, отсутствующий consumer, дубликат final или чужой
   weapon ID проваливает gate.
6. Первые пять узлов каждой ветви используют пять разных effect keys, имеют
   `measured_gain_min>=1.08`; direct flat строго `>=10`. Order 6 — final с
   `gain_over_order_5_min>=1.20`.
7. Core явно и всегда активно даёт ровно +1 primary attribute, cost=0 и
   исключено из spend.

Целевые тесты: новая schema-6 редакция `skill_tree_per_hero_test.gd` и
`meta_skill_tree_smoke_test.gd` плюс focused manifest/runtime parity test.

## Purchase/connectivity gates

- Core открыт и бесплатен.
- В каждой ветви последовательность 1→6 связна; полный путь стоит 6.
- Hidden side node до подвига `hidden`, после подвига `revealed/available`, после
  оплаты 1 — `purchased`; `reveal.reveals_only=true` и
  `purchase_required_for_effect=true`, поэтому reveal сам по себе эффект не
  активирует. Все 34 hidden-профиля имеют axis/effect/caps/consumer/fixture и
  минимум `1.08×`.
- Hidden edge не является обязательным predecessor для final.
- Все три finals покупаются и действуют одновременно; toggle/exclusive UI/API
  отсутствует.
- Respec возвращает ровно потраченные class sigils и не сбрасывает reveal facts
  или `legacy_mastery`.

## Economy/migration gates

Обновлённый `meta_points_per_ascension_test.gd` проверяет:

- cumulative rewards `2/4/7/11/15/20` за A0..A5;
- repeat clear не фармит sigils;
- class challenge не повышает spendable balance, но раскрывает правильный hidden;
- разные классы имеют независимые balances;
- максимум 20, full buy оставляет 0.

Schema 5→6 fixtures:

- пустой, частичный и полный schema-5 tree;
- 20, 22, 24 и 28 старых earned sigils;
- valid/invalid `active_keystones`;
- revealed/unrevealed hidden conditions;
- повторная загрузка уже мигрированного save.

Ожидание: allocations полностью refunded, progress facts сохранены,
`legacy_mastery=max(old-20,0)`, повторная миграция не меняет результат.

## 51-final behavioral matrix

Для каждой записи manifest:

1. Positive fixture с owning weapon доказывает hook и `≥1.20×` gain над 5/6.
2. Два negative controls запускают тот же state с двумя другими оружиями класса:
   geometry/cadence/damage/control/sustain должны остаться baseline в epsilon.
3. Caps/conditions проверяются на границе и выше границы.
4. Final выключен в 5/6 и включён только после покупки node6.

Итого минимум 51 positive + 102 negative fixtures. Общий subsystem можно
переиспользовать, но fixture и параметры остаются weapon-specific.

## Balance scenarios

Расширить class-balance harness сценариями:

| Scenario | Что сравнивается |
| --- | --- |
| `no_meta` | неизменность текущего 51-pair baseline |
| `path_5_of_6` | первые пять boons, каждый измерим и не ниже floor |
| `path_6_of_6` | final vs тот же 5/6 fixture; full path 1.60–2.00 |
| `three_paths_6_of_6` | все finals активны одновременно, но scoped |
| `full_20_of_20` | трио + hidden, средний gain 1.60–1.90 |
| `a5_live` | A5 сложнее A0, no runaway/immortality/control loop |

Отчёты содержат per-weapon solo/AoE/CCT5/10/20/defense и class-trio mean.
Гейты: axes ±10%; total ideal ±8%, hard fail ±15%; roster max/min ≤1.15;
A5 speedup over A0 baseline ≤15%.

Команды реализации запускаются только через semaphore:

```bash
python3 tools/godot_gate.py --headless --path . --script res://tools/balance_harness.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tools/survivability_harness.gd
python3 tools/godot_gate.py --headless --path . --script res://tools/live_combat_harness.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/live_balance_simulation_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd
```

## Atlas UI gates (SCRUM-1068, not SCRUM-1067)

До runtime layout change SCRUM-1068 создаёт/принимает UI Director spec. Проверить
21-node topology, three weapon labels, finals, hidden side stars, x/20 currency,
preview/buy/respec/focus, frame-safe content zones и responsive matrix. PixelLab
нужен только если существующий art kit не может реализовать принятый spec.
