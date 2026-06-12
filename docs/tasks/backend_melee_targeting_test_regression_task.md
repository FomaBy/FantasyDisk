# Задача Для Back-end-Агента: Проверить Падение Melee Targeting Test

Статус: done
Создано: 2026-06-12
Автор: Design handoff
Роль: Back-end
Приоритет: medium
Dispatch 2026-06-12: передано в Back-end чат `019eabd9-780b-78a2-9f4b-e7203d659ef2`.

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Не спрашивать подтверждение, если причина понятна.

## Контекст

Во время Design-задачи `design_ui_overhaul_flat_battle_bg_motion_polish_task.md` были запущены smoke/QA проверки. Design не менял gameplay-логику, баланс, hit shapes или targeting, но дополнительный тест:

```text
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/melee_weapon_targeting_test.gd
```

упал с ошибкой:

```text
Expected sword strip to avoid enemies far outside its narrow width.
```

Основные проверки Design-задачи прошли: `runtime_smoke_test.gd`, `animation_smoke_test.gd`, `attack_vfx_smoke_test.gd`, `meta_progression_smoke_test.gd`.

## Что Нужно От Back-end

- Проверить, является ли падение `melee_weapon_targeting_test.gd` актуальной gameplay-регрессией или устаревшим тестом после последних изменений weapon targeting/strip geometry.
- Если это регрессия, исправить механику/геометрию меча.
- Если тест устарел, обновить ожидания теста и документацию.
- Не менять Design-ассеты и visual style.

## Files / IDs

- `tests/melee_weapon_targeting_test.gd`
- `scripts/berserk_weapon.gd`
- `scenes/TwoHandedSword.tscn`

## Acceptance Criteria

- [x] `melee_weapon_targeting_test.gd` проходит или документированно обновлен.
- [x] Runtime smoke остается зеленым.
- [x] Если менялась механика, обновлены backend/system docs.

## Результат 2026-06-12

Причина падения: тест и `ProgressionData.BERSERK_WEAPONS["sword"]` ожидали старый меч как узкую `strip`-полосу 120x500, а актуальная сцена `TwoHandedSword.tscn` и последние gameplay-требования уже используют широкий `frustum`-замах: 90 градусов, радиус 600, base width 150, outer width 1200. Это был outdated test/data mismatch, не regression в Design assets.

Изменения:
- `ProgressionData` синхронизирован со сценой меча: `attack_shape = frustum`, range 600, inner width 150, outer width 1200, interval 0.58.
- `tests/melee_weapon_targeting_test.gd` обновлен под frustum geometry и изолирует вторичные on-hit эффекты, чтобы проверять именно shape targeting.
- `tests/runtime_smoke_test.gd` обновлен под новую конфигурацию меча.
- Документация обновлена: `characters_weapons.md`, `mechanics_extract.md`, `current_game_state.md`, `content_registry.md`, `CHANGELOG.md`.

Проверки:
- `melee_weapon_targeting_test.gd`: passed.
- `runtime_smoke_test.gd`: passed.
