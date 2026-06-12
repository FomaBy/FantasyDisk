# Задача Для Design-Агента: Визуал 9 Классов И 3 Оружия На Класс

Статус: done
Создано: 2026-06-11
Автор: PM/Codex dispatcher
Роль: Design
Приоритет: high

## Autonomy / Approval
Пользователь заранее одобрил все in-scope изменения. Не спрашивать подтверждений:
принять художественные решения, довести качество и передать готовые ассеты дальше.

## Роль И Границы
Design отвечает за качество персонажей, оружия, прозрачные PNG, cutout-ready позы,
визуальную цельность и регистрацию ассетов в документации. Не делать gameplay logic,
баланс, сцены оружия и подключение механик — это делает Back-end в
`backend_all_classes_three_weapons_gameplay_task.md`.

Если для генерации части ассетов нужен Codex image executor, Design сам формирует
подзадачу/сообщение executor-у, но финальное арт-ревью и статус остаются за Design.

## Контекст
Пользователь хочет, чтобы у каждого класса было по 3 оружия, и чтобы новые персонажи
и оружие выглядели так же хорошо, как первые 3 героя (`berserk`, `dark_mage`,
`guitarist`): не placeholder, не плоско, не случайно, а как полноценный набор
мрачного мультяшного dark fantasy.

Уже есть:
- 3 реализованных героя: `berserk`, `dark_mage`, `guitarist`;
- 6 новых full-art PNG в статусе review из `codex_design_new_classes_art_task.md`;
- по 3 оружия у первых 3 классов;
- по 1 стартовому оружию у новых классов.

## Главная Цель
Сделать единый визуальный набор для 9 классов и 27 оружий:
- каждый персонаж выглядит как полноценный герой игры;
- у каждого класса есть 3 оружия с понятным силуэтом;
- новые 6 персонажей не хуже первых 3 по качеству;
- оружие читается на карточках выбора, в магазине/кодексе и при экипировке;
- все ассеты готовы для будущей анимации/rig/cutout.

## Канонические Классы
| ID | Имя | Визуальная цель |
| --- | --- | --- |
| `berserk` | Берсерк | Брутальный воин ближнего боя, без оружия в базовом спрайте |
| `dark_mage` | Темный маг | Маг пустоты/проклятий, читаемые ноги под walk rig |
| `guitarist` | Гитарист | Мрачный боевой музыкант, рок/магия/звук |
| `assassin` | Ассасин | Поджарый убийца в капюшоне, быстрый силуэт |
| `ranger` | Рейнджер | Следопыт с дальнобойной охотничьей эстетикой |
| `doctor` | Доктор | Чумной доктор, алхимия лечения и заражения |
| `chemist` | Химик | Безумный алхимик, колбы, порошки, ядовитые пары |
| `knight` | Рыцарь | Тяжелый защитник, латная броня, щитовая эстетика |
| `druid` | Друид | Дикий призыватель, ветви, кости, тотемы |

## Оружие: 3 На Каждый Класс
Design должен подготовить/проверить ассеты для всех ID ниже. Существующие файлы
можно оставить, если они уже соответствуют стилю, но если качество ниже новых героев —
перерисовать/полировать.

| Класс | Weapon ID | Имя | Файл |
| --- | --- | --- | --- |
| `berserk` | `sword` | Двуручный меч | `assets/sprites/weapons/two_handed_sword.png` |
| `berserk` | `axe` | Двуручный топор | `assets/sprites/weapons/two_handed_axe.png` |
| `berserk` | `hammer` | Двуручный молот | `assets/sprites/weapons/two_handed_hammer.png` |
| `dark_mage` | `dark_book` | Книга тьмы | `assets/sprites/weapons/dark_book.png` |
| `dark_mage` | `cursed_skull` | Проклятый череп | `assets/sprites/weapons/cursed_skull.png` |
| `dark_mage` | `dark_wand` | Темная палочка | `assets/sprites/weapons/dark_wand.png` |
| `guitarist` | `electric_guitar` | Электрогитара | `assets/sprites/weapons/electric_guitar.png` |
| `guitarist` | `bass_guitar` | Бас-гитара | `assets/sprites/weapons/bass_guitar.png` |
| `guitarist` | `sound_amp` | Звуковой усилитель | `assets/sprites/weapons/sound_amp.png` |
| `assassin` | `chakrams` | Чакрамы | `assets/sprites/weapons/chakrams.png` |
| `assassin` | `shadow_daggers` | Теневые кинжалы | `assets/sprites/weapons/shadow_daggers.png` |
| `assassin` | `venom_wire` | Ядовитая струна | `assets/sprites/weapons/venom_wire.png` |
| `ranger` | `moon_crossbow` | Лунный арбалет | `assets/sprites/weapons/moon_crossbow.png` |
| `ranger` | `storm_longbow` | Грозовой длинный лук | `assets/sprites/weapons/storm_longbow.png` |
| `ranger` | `hunter_trap` | Охотничий капкан | `assets/sprites/weapons/hunter_trap.png` |
| `doctor` | `restore_potion` | Зелье восстановления | `assets/sprites/weapons/restore_potion.png` |
| `doctor` | `plague_syringe` | Чумной шприц | `assets/sprites/weapons/plague_syringe.png` |
| `doctor` | `bone_saw` | Костяная пила | `assets/sprites/weapons/bone_saw.png` |
| `chemist` | `blast_powder` | Взрывная пыль | `assets/sprites/weapons/blast_powder.png` |
| `chemist` | `acid_flask` | Кислотная колба | `assets/sprites/weapons/acid_flask.png` |
| `chemist` | `homunculus_vial` | Склянка гомункула | `assets/sprites/weapons/homunculus_vial.png` |
| `knight` | `long_spear` | Копье | `assets/sprites/weapons/long_spear.png` |
| `knight` | `tower_shield` | Башенный щит | `assets/sprites/weapons/tower_shield.png` |
| `knight` | `holy_flail` | Освященный кистень | `assets/sprites/weapons/holy_flail.png` |
| `druid` | `summon_amulet` | Амулет призыва | `assets/sprites/weapons/summon_amulet.png` |
| `druid` | `briar_staff` | Посох терний | `assets/sprites/weapons/briar_staff.png` |
| `druid` | `raven_totem` | Вороний тотем | `assets/sprites/weapons/raven_totem.png` |

## Требования К Персонажам
1. Проверить новые `assassin/ranger/doctor/chemist/knight/druid.png` из
   `codex_design_new_classes_art_task.md`:
   - если выглядят слабее первых 3 героев — перерисовать;
   - если есть грязный фон, halos, плохие края, квадратность или плохой силуэт — исправить;
   - ноги должны быть разделены и читаемы для walk rig.
2. Базовый спрайт персонажа должен быть без экипированного оружия в руках, если
   оружие выбирается отдельно. Допустимы декоративные элементы на поясе/спине, но
   не так, чтобы мешать выбранному оружию.
3. Размер full-art персонажей: `512x512`, прозрачный фон.
4. Сохранить единый стиль: мрачное фэнтези, мультяшная выразительность, аккуратная
   светотень, читаемый силуэт, как у первых 3 героев.

## Требования К Оружию
1. Размер: `256x256`, PNG, прозрачный фон.
2. Один основной предмет по центру, без текста/watermark.
3. Оружие должно быть читаемо в `64x64` и `40x40`.
4. Для melee-оружия учитывать направление/сокет: предмет должен выглядеть естественно
   в руке персонажа и не перекрывать все тело.
5. Для deploy/projectile/totem-оружия сделать предмет так, чтобы его можно было
   использовать и как UI-иконку, и как world sprite/effect base.
6. Все 27 оружий должны выглядеть одним сетом, но иметь разную цветовую/силуэтную
   идентичность по классам.

## Дополнительные Визуальные Пояснения По Новым Оружиям
- `shadow_daggers`: пара коротких темных кинжалов, фиолетовый след/ядро.
- `venom_wire`: тонкая ядовитая струна/гаррота с зелеными каплями и крючьями.
- `storm_longbow`: длинный лук с грозовым синим свечением и металлическими дугами.
- `hunter_trap`: капкан/ловушка с рунами, читается как deployable trap.
- `plague_syringe`: крупный шприц/инъектор с зеленой чумной жидкостью.
- `bone_saw`: грубая хирургическая пила из кости/черненой стали.
- `acid_flask`: колба с кислотой, яркий зеленый яд, трещины/пузырьки.
- `homunculus_vial`: склянка с маленькой темной формой внутри, алхимический summon.
- `tower_shield`: массивный щит, потертая сталь, защитная руна.
- `holy_flail`: цепной кистень, темное золото/сталь, светлый ударный акцент.
- `briar_staff`: деревянный посох с шипами/ветвями и природной магией.
- `raven_totem`: тотем с черепом/вороньими перьями, зеленовато-черное свечение.

## Документация
Обновить:
- `docs/design/content_registry.md` — все 9 персонажей и 27 оружий с asset paths;
- `docs/design/systems/visual_style_assets.md` — стиль персонажей/оружия;
- `docs/design/current_game_state.md` — актуальный visual content status;
- `CHANGELOG.md` — Unreleased.

Если какие-то ассеты оставлены как временные, явно пометить `needs rework` и создать
follow-up task. Не оставлять молча placeholder.

## Handoff Для Back-end
После готовности ассетов указать:
- какие файлы добавлены/заменены;
- какие weapon IDs готовы;
- какие ассеты требуют особого socket/scale/rotation;
- что можно подключать в `backend_all_classes_three_weapons_gameplay_task.md`.

## Acceptance Criteria
- [x] 6 новых персонажей art-approved и не хуже первых 3 героев.
- [x] 27 weapon PNG существуют по точным путям.
- [x] Все weapon PNG `256x256`, персонажи `512x512`, прозрачный фон.
- [x] Все персонажи/оружие визуально едины по стилю игры.
- [x] Оружие читается на малых размерах.
- [x] content_registry/current_game_state/visual docs/CHANGELOG обновлены.
- [x] Back-end handoff заполнен.

## Result Summary

Закрыто 2026-06-11.

Design art-review подтвердил, что `assassin`, `ranger`, `doctor`, `chemist`, `knight`, `druid` соответствуют текущему polished cartoon dark fantasy уровню первых трех героев и не требуют срочной перерисовки. Все 9 character PNG имеют прозрачный фон; новые 6 персонажей сохраняются как `512x512`.

Добавлены 12 недостающих weapon PNG:
- `assets/sprites/weapons/shadow_daggers.png`
- `assets/sprites/weapons/venom_wire.png`
- `assets/sprites/weapons/storm_longbow.png`
- `assets/sprites/weapons/hunter_trap.png`
- `assets/sprites/weapons/plague_syringe.png`
- `assets/sprites/weapons/bone_saw.png`
- `assets/sprites/weapons/acid_flask.png`
- `assets/sprites/weapons/homunculus_vial.png`
- `assets/sprites/weapons/tower_shield.png`
- `assets/sprites/weapons/holy_flail.png`
- `assets/sprites/weapons/briar_staff.png`
- `assets/sprites/weapons/raven_totem.png`

Полный набор 27 оружий готов по таблице выше: все PNG `256x256`, transparent, без текста/watermark, читаются в 40px preview. Код, сцены, баланс и gameplay integration не менялись в рамках Design-задачи.

## Back-end Handoff

Можно подключать новые visual assets в `backend_all_classes_three_weapons_gameplay_task.md` / weapon scenes без documented fallback для 12 финальных оружий.

Особые display/socket notes:
- `storm_longbow`, `long_spear`, `holy_flail`, `briar_staff` — вытянутые ассеты, при отображении в руке лучше настроить индивидуальные `scale`/`rotation`/offset.
- `venom_wire` — намеренно тонкая струна/гаррота; для атаки лучше использовать отдельный line/VFX, PNG подходит для UI/equipment/world cue.
- `hunter_trap`, `sound_amp`, `tower_shield`, `raven_totem`, `summon_amulet`, `homunculus_vial` — подходят как deployable/world sprite bases и могут не висеть постоянно в hand socket.
- `restore_potion`, `acid_flask`, `blast_powder` — лучше воспринимаются как thrown/deployable item sprites, а не постоянное оружие в руках.
- `shadow_daggers`, `chakrams`, `plague_syringe`, `bone_saw` — handheld/offhand sprites, стартовая visual scale около `0.8..1.0`.

Verification:
- image QA script: 9 character PNG `512x512`, 27 weapon PNG `256x256`, RGBA/transparent, non-empty alpha bbox;
- manual contact sheets checked at 96px and 40px.
