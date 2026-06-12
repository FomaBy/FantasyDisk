# Задача Для Back-end-Агента: Починить Runtime Smoke После CombatDirector Type Inference

Статус: done 2026-06-12 (закрыта как transient)
Создано: 2026-06-12
Автор: Design handoff
Роль: Back-end
Приоритет: high

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Подтверждение не требуется.

## Контекст

Во время Design-задачи `design_weapon_attack_vfx_animations_polish_task.md` был запущен runtime smoke:

```text
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Тест упал до проверки Design/VFX изменений из-за compile error в `scripts/combat_director.gd`:

```text
SCRIPT ERROR: Parse Error: Cannot infer the type of "xp_reward" variable because the value doesn't have a set type.
          at: GDScript::reload (res://scripts/combat_director.gd:670)
SCRIPT ERROR: Parse Error: Cannot infer the type of "money_reward" variable because the value doesn't have a set type.
          at: GDScript::reload (res://scripts/combat_director.gd:671)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
          at: GDScript::reload (res://scripts/main.gd:0)
```

Эти строки находятся в `_grant_combat_completion_rewards(event_combat := {})`. Это Back-end/runtime typing issue, не Design/VFX.

## Что Уже Сделано Design

- Добавлены растровые VFX pool assets:
  - `assets/sprites/effects/poison_pool.png`
  - `assets/sprites/effects/spark_pool.png`
  - `assets/sprites/effects/briar_pool.png`
- `scripts/class_weapon.gd` подключает эти PNG вместо видимого `Polygon2D` pool.
- `tests/attack_vfx_smoke_test.gd` — passed.
- `tests/animation_smoke_test.gd` — passed.
- Runtime smoke blocked only by this compile error.

## Что Нужно От Back-end

- Исправить GDScript type inference в `scripts/combat_director.gd` около строк 670-671.
- Не менять баланс наград без отдельного требования.
- После фикса прогнать:
  - `tests/runtime_smoke_test.gd`
  - `tests/attack_vfx_smoke_test.gd` желательно для регрессии Design block.

## Acceptance Criteria

- [ ] `tests/runtime_smoke_test.gd` проходит.
- [ ] Награды XP/money после боя сохраняют прежние значения и multiplier behavior.
- [ ] Изменение не затрагивает Design assets.


## Резолюция (Claude-Backend, 2026-06-12)

**Закрыто как transient — type-inference ошибка была мид-эдитом параллельной незакоммиченной работы.**

Диагностика:
- Закоммиченный HEAD `combat_director.gd` бага НЕ содержит: его `_grant_combat_completion_rewards()` использует инлайн-выражения без промежуточных `var xp_reward`/`money_reward`, компилируется чисто.
- Сломанная форма `var xp_reward := 3 + game.route_stage` (walrus без типа: `game` нетипизирован -> `game.route_stage` Variant -> вывод типа падает) существовала ТОЛЬКО в промежуточном состоянии незакоммиченной работы Backend-агента по задаче `backend_enemy_scaling_elite_boss_difficulty_task` (stage_scale-кривая, elite/boss rewards, event_combat). Design-агент поймал именно этот момент.
- К моменту разбора рабочее дерево уже содержит исправленную форму с явной аннотацией `var xp_reward: int = ...` / `var money_reward: int = ...` — компилируется и проходит.

Проверка acceptance:
- `tests/runtime_smoke_test.gd` — зелёный, стабильно 3 прогона.
- Награды XP/money сохранены: базовые значения (норм `3+stage` XP / `4+stage*2` money; элитка `7+stage*2` / `10+stage*4`) идентичны HEAD; event-мультипликаторы добавлены поверх без изменения базы.
- Design-ассеты не затронуты (правок кода от меня не потребовалось).

Действий по коду не требовалось: фикс уже присутствует в рабочем дереве (часть enemy-scaling задачи, которую закоммитит её исполнитель). HEAD type-safe и без бага. Для надёжности на будущее: при `var x := <выражение с game.поле>` всегда ставить явный `: int`/`: float`, т.к. `game` нетипизирован.
