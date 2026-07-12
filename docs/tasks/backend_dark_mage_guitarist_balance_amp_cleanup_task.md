# Задача Для Back-end-Агента: Перебалансировать Темного Мага И Гитариста, Починить Cleanup Усилителя

> Историческая справка: упоминания `sound_wave_damage` в этом документе описывают состояние ДО SCRUM-898 (2026-07-10). Звуковая ось урона удалена; оружия Гитариста/Друида бьют магией (`magic_damage`).

Дата: 2026-06-10

Статус: done 2026-06-11. Результат: задача закрыта через более конкретную `backend_mage_buff_guitarist_rework_task.md`: Темный маг получил 2 луча/2 AoE-снаряда и усиленный DoT, Гитарист переработан в speed/control identity, `sound_amp` стал деплойным объектом с lifetime/лимитом от Лидерства и cleanup-группами `deployed_sound_amps`/`player_weapon_effects`. Runtime smoke test покрывает баланс-конфиги, beam count, amp limit/cleanup и проходит.

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: перебалансируй классы, исправь баг cleanup, обнови тесты и документацию. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Проблема

Темный маг сейчас работает заметно хуже других персонажей. Его скиллы ощущаются слабыми, и он не убивает монстров так же эффективно, как Берсерк с молотом.

Гитариста тоже нужно пересмотреть по эффективности и удобству.

Есть отдельный баг: Гитарист оставляет текстуру/объект усилителя на карте. Потом этот усилитель может появляться или оставаться на карте даже при игре за другого персонажа. Нужно пересмотреть cleanup оружия, временных объектов, class-specific visuals и исправить утечку.

## Главная Цель

После задачи:

- Темный маг должен убивать волны монстров примерно так же эффективно, как Берсерк с молотом, но своим стилем: магия, AoE, лучи, DoT, контроль зоны.
- Гитарист должен быть конкурентоспособным по clear speed и выживаемости, но отличаться через звуковые волны, пульсы, усилитель, knockback и контроль.
- Усилитель Гитариста не должен оставаться на карте после смены персонажа, смены оружия, завершения боя, смерти, возврата в меню или нового забега.
- Все временные visuals/projectiles/weapon children должны корректно очищаться.

## Обязательные Документы Перед Работой

Перед началом прочитать:

- `AGENTS.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- `docs/design/mechanics_extract.md`

## Файлы Для Проверки

Обязательно проверить:

- `scripts/progression_data.gd`
- `scripts/player.gd`
- `scripts/class_weapon.gd`
- `scripts/berserk_weapon.gd`
- `scripts/main.gd`
- `scripts/enemy.gd`
- `tests/runtime_smoke_test.gd`
- `tests/animation_smoke_test.gd`, если меняются visual/weapon expectations

## Баланс Темного Мага

Темный маг должен быть сильным AoE/caster персонажем, но не копией Берсерка.

Текущее ощущение: скиллы слабые, монстры умирают слишком медленно.

Пересмотреть:

- base stats Темного мага;
- `magic_damage` formula;
- damage multipliers оружия Темного мага;
- fire intervals;
- AoE radius;
- projectile speed;
- pierce count;
- DoT damage/ticks/speed;
- targeting behavior;
- early-game clear speed;
- scaling от `intelligence`, `energy`, `knowledge`, `perception`.

### Целевой Power Level

Темный маг должен быть сопоставим по эффективности с Берсерком + `Двуручный молот`:

- на ранних волнах не должен проигрывать по clear speed в 2+ раза;
- должен уверенно убивать пачки обычных melee врагов;
- должен иметь понятную сильную сторону против плотных групп;
- должен оставаться хрупким, но компенсировать это уроном, AoE и контролем дистанции.

### Оружие Темного Мага

#### Книга тьмы (`dark_book`)

Должна быть сильным AoE-снарядом:

- увеличить взрывной урон и/или AoE radius;
- сделать попадание по группе надежнее;
- проверить projectile speed, чтобы снаряд не промахивался слишком часто;
- визуально/механически должно ощущаться как главный wave-clear инструмент.

#### Проклятый череп (`cursed_skull`)

Должен быть полезен против жирных целей и элиток:

- усилить initial hit или DoT;
- проверить количество тиков;
- DoT должен реально помогать, а не быть декоративным;
- возможно добавить небольшой splash/chain, если single target слишком слаб.

#### Темная палочка (`dark_wand`)

Должна быть сильным line/pierce оружием:

- проверить beam width;
- проверить pierce count;
- увеличить урон или уменьшить interval, если beam не чистит волны;
- beam должен стабильно поражать несколько врагов в линии.

## Баланс Гитариста

Гитарист должен быть не слабее по общему темпу, но играться через контроль:

- sound wave должна надежно чистить ближнюю толпу;
- pulse должен давать сильный контроль и не быть слишком слабым по урону;
- amp должен быть полезным, но не ломать cleanup;
- knockback должен помогать выживанию, но не разбрасывать монстров так, что игрок теряет DPS;
- damage/attack speed/radius нужно сравнить с Берсерком и Темным магом.

Пересмотреть:

- `sound_wave_damage` formula;
- damage multipliers Guitarist weapons;
- `electric_guitar` width/range/damage/interval;
- `bass_guitar` radius/damage/knockback/interval;
- `sound_amp` pulse damage/radius/interval/lifetime/cleanup.

## Баг Cleanup Усилителя Гитариста

Симптом:

- Гитарист оставляет texture/объект усилителя на карте.
- Усилитель появляется/остается при игре за другого персонажа.

Нужно найти источник:

- `ClassWeapon` amp visual может создаваться вне weapon node и не удаляться;
- amp node может добавляться в scene/root вместо being child of weapon/player;
- при `configure_character`, `equip_weapon`, `start_new_run`, death, victory, return to menu или route transition старые weapon visuals могут не очищаться;
- `queue_free` может не вызываться для spawned amp/projectile/effects;
- groups могут не использоваться для cleanup.

Требования:

- все временные объекты оружия должны принадлежать владельцу, которого можно очистить;
- при смене персонажа/оружия старое оружие и его spawned visuals удаляются;
- при старте нового забега карта очищается от class-specific leftovers;
- при переходе из боя на карту/магазин/event/rest не должно оставаться amp visuals;
- при выборе другого персонажа усилитель Гитариста не появляется.

Рекомендуемое решение:

- добавить group для временных объектов оружия, например `player_weapon_effects`;
- amp visual/projectile/effects создавать как children weapon/player/effects container с явным owner cleanup;
- добавить cleanup method в `ClassWeapon`, который удаляет amp/effects;
- вызывать cleanup при unequip, configure_character, combat cleanup, return to menu/new run.

## Сравнительный Playtest / Smoke Scenario

Проверить минимум:

- Берсерк + молот;
- Темный маг + Книга тьмы;
- Темный маг + Проклятый череп;
- Темный маг + Темная палочка;
- Гитарист + Электрогитара;
- Гитарист + Бас-гитара;
- Гитарист + Усилитель.

Сравнить:

- сколько врагов убивает персонаж за первые 30-45 секунд;
- насколько быстро чистятся плотные группы;
- насколько персонаж выживает против melee толпы;
- нет ли ситуации, где маг/гитарист просто бегают без урона.

Не нужно делать всех одинаковыми. Нужно, чтобы каждый был эффективен своим способом.

## Acceptance Criteria

Задача готова, если:

- Темный маг по clear speed примерно сопоставим с Берсерком + молот;
- все три оружия Темного мага ощущаются полезными;
- Гитарист не выглядит слабым или бесполезным на фоне Берсерка/Мага;
- все три оружия Гитариста имеют понятную роль;
- усилитель Гитариста не остается на карте после смены персонажа/оружия/забега;
- усилитель не появляется при игре за другого персонажа;
- temporary weapon effects очищаются централизованно;
- runtime smoke test обновлен и проходит;
- документация обновлена.

## Проверка

Запустить:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Если менялись visual/animation expectations:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

Ручная проверка:

- сыграть за Темного мага со всеми тремя оружиями;
- сыграть за Гитариста со всеми тремя оружиями;
- после игры за Гитариста начать забег за Берсерка и Темного мага;
- проверить, что усилителя нет на карте;
- проверить level-up, route transition, death/victory cleanup.

## Документация

После реализации обновить:

- `docs/design/current_game_state.md` - новые class balance notes, cleanup behavior;
- `docs/design/mechanics_extract.md` - обновленные формулы, multipliers, intervals, weapon roles;
- `docs/design/fantasydisk_design_brief.md` - если изменилась роль Темного мага или Гитариста;
- `docs/design/content_registry.md` - если добавлены новые effect IDs/groups/assets.

Не оставлять баланс и cleanup только в коде.
