# SCRUM-898 — хвост миграции: scripts/ui_screens.gd

Статус: todo

## Контекст

SCRUM-898 удалил звуковую ось урона (`sound_wave_damage`) полностью: данные,
формулы, оружия (Guitarist x3 и Druid x3 → `magic_damage`), UI-реестры, палитры,
тесты и доки мигрированы (коммиты 35301aa4 + docs-коммит). Файл
`scripts/ui_screens.gd` на момент выполнения был ЗАЛОЧЕН другим воркером
(codex, SCRUM-955), поэтому в нём остались 5 легаси-упоминаний.

**Все остаточные упоминания crash-safe** (проверено):

- изоляционный фильтр превью (`parameter_id in _DAMAGE_TYPE_PARAMETERS and
  parameter_id != class_damage`) отбрасывает `sound_wave_damage` ДО любого
  обращения к данным — ни один класс больше не имеет этот параметр «своим»;
- `UIIconRegistry.make_icon("sound_wave_damage")` после удаления записи реестра
  отдаёт фолбэк-бейдж с аббревиатурой `SOU` (substr), не крашится;
- ветка `match` с удалённым id — мёртвый код, недостижима.

То есть баг только косметический: гитарист-affinity предметы магазина получают
generic-бейдж вместо иконки магического урона.

## Требуемые правки (5 точек; строки на момент коммита 35301aa4)

1. **`_shop_item_fallback_icon_id`** (~строка 8413-8414):

   ```gdscript
   if classes.has("guitarist"):
       return "sound_wave_damage"
   ```

   заменить на:

   ```gdscript
   if classes.has("guitarist"):
       return "magic_damage"
   ```

2. **`const STAT_DERIVED_PREVIEW`** (~строка 9851), ключ `"perception"`:
   убрать `"sound_wave_damage"` из списка →
   `"perception": ["attack_range", "aoe_radius", "pickup_radius"],`

3. **`const STAT_DERIVED_PREVIEW`** (~строка 9852), ключ `"energy"`:
   убрать `"sound_wave_damage"` из списка →
   `"energy": ["ultimate_multiplier", "projectile_speed"],`

4. **`const _DAMAGE_TYPE_PARAMETERS`** (~строка 9859):

   ```gdscript
   const _DAMAGE_TYPE_PARAMETERS := ["damage", "magic_damage", "sound_wave_damage"]
   ```

   заменить на:

   ```gdscript
   const _DAMAGE_TYPE_PARAMETERS := ["damage", "magic_damage"]
   ```

5. **`_level_up_parameter_label`** (~строка 10072-10073): удалить ветку

   ```gdscript
   "sound_wave_damage":
       return "Звуковой урон"
   ```

## Приёмка

- `grep -n "sound_wave_damage" scripts/ui_screens.gd` — пусто.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — зелёный.
- Магазин: у гитарист-affinity предметов иконка магического урона (не бейдж SOU).

## После применения

Удалить этот файл в том же коммите.
