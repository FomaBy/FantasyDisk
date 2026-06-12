# Задача Для Back-end-Агента: 3 Оружия На Каждый Класс — Логика, Баланс, UI, Документация

Статус: done
Создано: 2026-06-11
Автор: PM/Codex dispatcher
Роль: Back-end
Приоритет: high

## Autonomy / Approval
Пользователь заранее одобрил все in-scope изменения. Работать автономно, не
останавливаться на вопросах, если можно принять разумное инженерное/балансное решение.

## Роль И Границы
Back-end отвечает за gameplay logic, конфиги оружия, выбор оружия/подкласса, баланс,
кодекс, тесты, интеграцию готовых ассетов и документацию механик. Не перерисовывать
спрайты и не принимать финальный арт — это задача Design:
`design_all_classes_three_weapons_visual_upgrade_task.md`.

## Контекст
Пользователь хочет, чтобы у каждого класса было по 3 оружия, и чтобы новые классы
ощущались так же полноценно, как первые 3 персонажа. Сейчас первые 3 класса уже имеют
3 оружия, а новые 6 классов добавляются фундаментом с 1 стартовым оружием.

Эту задачу выполнять после/поверх:
- `backend_full_attributes_wiring_audit_task.md`;
- `backend_new_classes_foundation_task.md`;
- Design handoff из `design_all_classes_three_weapons_visual_upgrade_task.md`
  для финальных PNG.

Если foundation-задача еще в процессе, расширить ее scope аккуратно или продолжить
после нее, не ломая текущие незакоммиченные изменения.

## Главная Цель
В игре должно быть 9 классов, и у каждого класса должно быть ровно 3 выбираемых
оружия/подкласса на старте забега. Каждое оружие должно менять игровой стиль, а не
быть только другим числом урона.

## Канонический Список Оружия
| Класс | Weapon ID | Имя | Gameplay Identity |
| --- | --- | --- | --- |
| `berserk` | `sword` | Двуручный меч | Длинная узкая полоса, высокий одиночный melee damage |
| `berserk` | `axe` | Двуручный топор | Широкая дуга, контроль ближней толпы |
| `berserk` | `hammer` | Двуручный молот | Малый стартовый круг, сильный late-game AoE scaling |
| `dark_mage` | `dark_book` | Книга тьмы | AoE-снаряды по нескольким целям |
| `dark_mage` | `cursed_skull` | Проклятый череп | Homing curse + DoT/splash |
| `dark_mage` | `dark_wand` | Темная палочка | Pierce beams/лучи |
| `guitarist` | `electric_guitar` | Электрогитара | Направленная звуковая волна |
| `guitarist` | `bass_guitar` | Бас-гитара | Частый круговой pulse/knockback контроль |
| `guitarist` | `sound_amp` | Звуковой усилитель | Deployable amp, autonome pulses, cleanup обязательно |
| `assassin` | `chakrams` | Чакрамы | Boomerang blades, урон туда-обратно, crit-friendly |
| `assassin` | `shadow_daggers` | Теневые кинжалы | Быстрые ближние multi-stabs / короткий cone, высокий crit |
| `assassin` | `venom_wire` | Ядовитая струна | Тонкая линия/гаррота с poison DoT и bleed/slow |
| `ranger` | `moon_crossbow` | Лунный арбалет | Дальний точный piercing shot |
| `ranger` | `storm_longbow` | Грозовой длинный лук | Chain/arc projectile или multishot по дальним целям |
| `ranger` | `hunter_trap` | Охотничий капкан | Deploy trap: root/slow + burst при входе врага |
| `doctor` | `restore_potion` | Зелье восстановления | AoE throw + self heal |
| `doctor` | `plague_syringe` | Чумной шприц | Projectile injection: poison/DoT, lifesteal/heal synergy |
| `doctor` | `bone_saw` | Костяная пила | Короткий melee arc, bleed, heal on kill/hit |
| `chemist` | `blast_powder` | Взрывная пыль | AoE explosion + poison cloud |
| `chemist` | `acid_flask` | Кислотная колба | Acid pool, armor/defense shred or stacking DoT |
| `chemist` | `homunculus_vial` | Склянка гомункула | Temporary summon/minion or bouncing vial with splash |
| `knight` | `long_spear` | Копье | Длинный точечный strip, defense passive |
| `knight` | `tower_shield` | Башенный щит | Shield bash / frontal block + knockback, tank identity |
| `knight` | `holy_flail` | Освященный кистень | Medium circular swing, stun/knockback, slower heavy hits |
| `druid` | `summon_amulet` | Амулет призыва | Summon pack scaling from Leadership |
| `druid` | `briar_staff` | Посох терний | Rooting/thorn zones, AoE DoT, crowd control |
| `druid` | `raven_totem` | Вороний тотем | Totem/summon aura: ravens attack targets or debuff area |

## Требования К Реализации
1. **Данные**:
   - в `ProgressionData.WEAPONS_BY_CLASS` у каждого из 9 классов ровно 3 оружия;
   - все IDs из таблицы выше канонические;
   - title/description на русском, с понятным описанием поведения;
   - `damage_parameter`, `passive_mods`, `attack_range`, `aoe_radius`, `fire_interval`,
     `projectile_speed`, `knockback`, DoT/summon/trap параметры заданы data-driven.
2. **Механики**:
   - переиспользовать существующие классы оружия (`class_weapon`, `summoner_weapon`,
     melee scenes) там, где это разумно;
   - новые attack modes добавлять только если реально нужны и не ломают текущие;
   - deployables/traps/totems обязаны чиститься при смене оружия, смене персонажа,
     смерти, выходе из забега и world cleanup;
   - all weapons must respect pause/freeze.
3. **Выбор Персонажа/Оружия**:
   - UI выбора класса должен показывать 9 классов и 3 оружия у выбранного класса;
   - оружие должно быть очевидно выбираемым, с иконкой/спрайтом, названием и кратким
     описанием;
   - выбранный weapon_id корректно передается в бой;
   - если ассет еще не готов, fallback не должен крашить игру, но placeholder должен
     быть явно отмечен в документации.
4. **Баланс**:
   - каждое оружие должно проходить раннюю волну без ощущения беспомощности;
   - у каждого класса 3 оружия должны давать разные стили: single target / AoE /
     control/summon/deploy где уместно;
   - целевой ориентир: зачистка стандартной волны в пределах +/-20-25% от текущих
     сильных билдов первых 3 классов, без очевидного auto-win;
   - слабый старт допустим только если есть понятный late-game payoff, как у hammer.
5. **Визуальная Интеграция**:
   - использовать новые Design-ассеты из `design_all_classes_three_weapons_visual_upgrade_task.md`;
   - оружие должно прикрепляться/отображаться естественно в UI и/или на персонаже;
   - не оставлять старые temporary visuals, если финальные ассеты готовы.
6. **Кодекс И Документация**:
   - добавить/обновить entries в кодексе для 9 классов и 27 оружий;
   - обновить `content_registry`, `mechanics_extract`, `current_game_state`,
     `docs/design/systems/characters_weapons.md`, `docs/design/systems/combat.md`,
     `CHANGELOG.md`;
   - все новые сущности должны иметь имена и ID, не быть случайными.

## Файлы Для Проверки
- `scripts/progression_data.gd`
- `scripts/player.gd`
- `scripts/class_weapon.gd`
- `scripts/summoner_weapon.gd`
- `scripts/ui_screens.gd`
- `scripts/codex_data.gd`
- `scenes/*.tscn` для новых/переиспользованных оружий
- `tests/runtime_smoke_test.gd` и профильные тесты, если есть

## Зависимости
- `backend_full_attributes_wiring_audit_task.md` — должен быть выполнен перед финальным балансом.
- `backend_new_classes_foundation_task.md` — эта задача расширяет фундамент новых классов.
- `design_all_classes_three_weapons_visual_upgrade_task.md` — финальные ассеты оружия/персонажей.

Можно начать с data/schema/UI groundwork, но финальный done ставить только после
готовых Design-ассетов или явного documented fallback.

## Acceptance Criteria
- [x] У каждого из 9 классов ровно 3 выбираемых оружия.
- [x] Все 27 weapon IDs из таблицы реализованы или явно documented fallback до ассетов.
- [x] Каждое оружие имеет отличимую механику и не является простой копией другого.
- [x] Выбор класса/оружия работает, выбранное оружие попадает в бой.
- [x] Deployables/traps/totems/summons чистятся без оставшихся текстур на карте.
- [x] Pause/freeze останавливает все новые атаки/effects.
- [x] Кодекс, registry, mechanics/current state/system docs и CHANGELOG обновлены.
- [x] Runtime smoke test зеленый; добавить/обновить тест, который проходит все 9 классов
      и проверяет наличие 3 оружий у каждого.

## Result Summary

Закрыто 2026-06-11:
- `ProgressionData.WEAPONS_BY_CLASS` содержит 9 классов x 3 оружия = 27 canonical weapon IDs.
- Добавлены backend-режимы `stab_flurry`, `dot_beam`, `trap`; deploy/totem visuals берут текстуру своего `WeaponVisual`.
- Добавлены сцены для 12 недостающих оружий новых классов; 6 signature weapons подключают готовые PNG, остальные 12 используют documented fallback до завершения Design task.
- `summoner_weapon.gd` поддерживает configurable `damage_parameter` / `summon_damage_multiplier`.
- Runtime smoke test расширен: проверяет все 9 классов, 27 weapon variants, equip/scene/mode/visual.
- Документация обновлена: registry, mechanics, current state, characters/weapons system doc, combat doc, brief, changelog.

Verification:
`/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

Result: passed.

## Design Handoff Update

2026-06-11: `design_all_classes_three_weapons_visual_upgrade_task.md` закрыта. Все 27 weapon PNG теперь существуют по каноническим путям в `assets/sprites/weapons/`; 12 бывших fallback-оружий (`shadow_daggers`, `venom_wire`, `storm_longbow`, `hunter_trap`, `plague_syringe`, `bone_saw`, `acid_flask`, `homunculus_vial`, `tower_shield`, `holy_flail`, `briar_staff`, `raven_totem`) готовы как финальные `256x256` transparent sprites. При следующем Back-end pass можно убрать documented visual fallback и настроить per-weapon socket/scale/rotation по notes из Design-задачи.
