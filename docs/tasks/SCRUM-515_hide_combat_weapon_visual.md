# SCRUM-515: Скрыть визуальное оружие персонажа во время боя

Jira: SCRUM-515 · Роль: backend · Контур: codex · Приоритет: P1 · foma · Эпик: SCRUM-213 ([COMBAT] Бой, враги, боссы и события)
Статус: done

## Что и зачем

Пользователь хочет, чтобы экипированное оружие НЕ отображалось у персонажа во время боя. Сейчас у героя на орбите вокруг тела крутится спрайт оружия (held/orbit weapon sprite) — узел `WeaponVisual` внутри каждой оружейной сцены. Пользователю это визуально не нравится.

Требование: убрать только runtime-визуал держимого оружия. Вся боевая механика оружия (урон, target pattern, cooldown, projectiles, VFX попаданий, hazards, summon-сущности, баланс) обязана работать ровно как сейчас. Меняется ТОЛЬКО отображение узла-спрайта экипированного оружия.

Ожидаемый результат для игрока: в обычном бою у персонажа не видно спрайта оружия на орбите/в руке, но все атаки, эффекты, снаряды и вызванные сущности продолжают появляться и наносить урон без изменений. Hero Select / Codex / preview-экраны оружия (где оружие — это UI/reference) не затрагиваются.

## Текущее состояние в коде

Архитектура держимого оружия:

- `scripts/player.gd:331` `_weapon_socket()` — возвращает/создаёт узел `VisualRoot/WeaponSocket` (Node2D), к которому крепится оружие. Слой настраивается в `_configure_weapon_socket_layer()` (`scripts/player.gd:352`): `z_index = WEAPON_ORBIT_Z_INDEX` (= -8, константа на `scripts/player.gd:48`), радиус орбиты `WEAPON_ORBIT_RADIUS = 104.0` (`scripts/player.gd:46`).
- `scripts/player.gd:291` `_attach_weapon_scene()` — инстанцирует оружейную сцену, добавляет в `player_weapons` группу, цепляет под `WeaponSocket`, вызывает `_configure_attached_weapon_layer(weapon)` (`scripts/player.gd:358`).
- `scripts/player.gd:358` `_configure_attached_weapon_layer(weapon)` — выставляет `z_index = 0` на корне оружия (CanvasItem) и на дочернем `WeaponVisual` (CanvasItem). **Это естественная точка, где можно скрыть визуал.**
- `scripts/player.gd:1630` `_apply_sprite_transform()` → `scripts/player.gd:1639` — каждый кадр двигает `WeaponSocket` по орбите: ставит позицию `_weapon_orbit_position(orbit_direction)`, поворот по направлению атаки. Это и есть «оружие крутится вокруг героя».

Оружейная сцена (пример `scenes/LongSpear.tscn`): корневой `Node2D` (script `class_weapon.gd`/`berserk_weapon.gd`/`summoner_weapon.gd`) в группе `player_weapons`, и дочерний `[node name="WeaponVisual" type="Sprite2D"]` с `texture` оружия, позицией, поворотом, масштабом. Таких сцен ~102 (`grep -rln "WeaponVisual" --include="*.tscn"`). **`WeaponVisual` — это и есть видимый спрайт держимого оружия.**

КРИТИЧНО (подводный камень №1): текстура `WeaponVisual` ПЕРЕИСПОЛЬЗУЕТСЯ боевой логикой как источник текстуры для снарядов/ловушек/орбов. См. `scripts/class_weapon.gd:2168` `_weapon_visual_texture()` — читает `get_node_or_null("WeaponVisual").texture`. Эта текстура идёт в:
- `scripts/class_weapon.gd:886-887` trap_visual (ловушки),
- `scripts/class_weapon.gd:1160-1162` orb (орбы),
- `scripts/class_weapon.gd:1677-1679`, `scripts/class_weapon.gd:1788-1789` projectile visuals,
- `scripts/class_weapon.gd:2175` `_deploy_visual_texture()` fallback.

Поэтому НЕЛЬЗЯ удалять узел `WeaponVisual` или обнулять его `texture` — иначе сломаются снаряды/ловушки/орбы. Нужно скрыть только РЕНДЕР узла (`visible = false`), оставив сам узел и текстуру на месте.

Атакующие VFX/projectiles/hazards/summons рисуются отдельно (через `AttackVfx.*` в `_projectile_parent()`, регистрируются в `_register_effect()`), к `WeaponVisual` как к рендеру не привязаны — их трогать НЕ нужно.

Decouple от UI (подводный камень №2): Hero Select / Codex рисуют своё превью оружия СВОИМ спрайтом, не через игровой `WeaponVisual`. См. `scripts/ui_screens.gd:3935` `WeaponSelectSprite_%s` + `_weapon_sprite_path()` (`scripts/ui_screens.gd:3986`) — берёт текстуру из config (`icon_path`/`sprite_path`/`weapon_sprite_path`), а не из инстанса оружия на игроке. Значит изменение в `player.gd`/сценах НЕ затронет UI-превью. `scripts/ui_screens.gd` — locked path, его НЕ трогаем.

Существующий смоук: `tests/weapon_orbit_smoke_test.gd` (SCRUM-455) — гоняет berserk/sword, проверяет что `WeaponVisual` существует и его эффективный z-index уходит за `Body` (`tests/weapon_orbit_smoke_test.gd:62`). После того как визуал станет скрытым, этот тест надо обновить: вместо проверки z-порядка под телом — проверять, что `WeaponVisual.visible == false` (или корень оружия не виден), при этом сам узел/группа `player_weapons` и боевая механика остаются.

## Что сделать — по шагам

1. Добавить runtime-выключение рендера держимого оружия в `scripts/player.gd`. Минимально-инвазивный путь — в `_configure_attached_weapon_layer(weapon)` (`scripts/player.gd:358`) после настройки z-index скрывать визуальное отображение:
   - выставить `visible = false` у корневого CanvasItem оружия и/или у дочернего `WeaponVisual` (CanvasItem). Скрытие корня оружия (`weapon as CanvasItem`) прячет всё его поддерево визуала за один раз — предпочтительно скрывать именно корень оружия, чтобы поймать любые альтернативные дочерние спрайты.
   - НЕ обнулять `texture`, НЕ удалять узел `WeaponVisual` — текстура нужна для `_weapon_visual_texture()` (снаряды/ловушки/орбы).
   - Узел `_process`/`_attack` оружия работает независимо от `visible` — механика не пострадает.
2. Ввести явный debug-флаг, чтобы оставить возможность показать оружие вне боя/для отладки (требование тикета «оставить debug/preview только вне боя или под явным debug flag»). Предложение:
   - константа `const SHOW_HELD_WEAPON_VISUAL := false` рядом с `WEAPON_ORBIT_*` (`scripts/player.gd:46-48`), и в `_configure_attached_weapon_layer` скрывать визуал только когда флаг `false`. Это даёт единую точку включения визуала обратно.
   - (опционально) читать override из root meta по аналогии с `aim_mode` (`scripts/player.gd:267`: `get_tree().root.get_meta("aim_mode", ...)`), напр. `root.get_meta("show_held_weapon", SHOW_HELD_WEAPON_VISUAL)` — чтобы тесты/preview могли включить визуал без правки кода. Делать только если просто; иначе достаточно константы.
3. Проверить, что нет других мест, которые принудительно ставят оружию `visible = true` каждый кадр. `_apply_sprite_transform()` (`scripts/player.gd:1639`) двигает только `WeaponSocket` (позиция/rotation/scale/z), `visible` не трогает — ок, скрытие переживёт кадровый апдейт. При `configure_character`/`equip_weapon` оружие переинстанцируется → `_attach_weapon_scene` → `_configure_attached_weapon_layer` снова применит скрытие. Убедиться, что при смене оружия (берсерк сабкласс `configure_berserk_subclass`, `scripts/player.gd:274`) путь тоже идёт через `equip_weapon` → скрытие применяется.
4. Обновить `tests/weapon_orbit_smoke_test.gd`:
   - заменить/дополнить ассерты z-порядка `WeaponVisual` (`tests/weapon_orbit_smoke_test.gd:53-64`) на проверку, что держимый визуал скрыт: корень оружия (CanvasItem) `visible == false` ИЛИ `WeaponVisual.visible == false`. Использовать `CanvasItem.is_visible_in_tree()` для надёжности (учитывает скрытого родителя).
   - сохранить ассерты, что оружие по-прежнему инстанцируется, лежит в группе `player_weapons` под `WeaponSocket`, и орбита `WeaponSocket` всё ещё считается (механика/позиционирование живы). Это и есть доказательство, что геймплей не поменялся, изменился только рендер.
   - обновить QA-dump (`tests/weapon_orbit_smoke_test.gd:82`) — добавить строку `WeaponVisualVisible`/`WeaponRootVisible`.
5. Прогнать боевые смоуки (`tests/runtime_smoke_combat_test.gd`, `tests/runtime_smoke_weapon_mechanics_test.gd`, `tests/weapon_orbit_smoke_test.gd`, `tests/weapon_scene_integrity_test.gd`, `tests/unique_weapon_vfx_assets_test.gd`) headless и приложить вывод как QA evidence: урон наносится, снаряды/ловушки/орбы с текстурой остаются видимыми, держимый спрайт скрыт.

Запуск теста: `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/weapon_orbit_smoke_test.gd`

## Acceptance Criteria

- [ ] В обычном бою у персонажа не виден orbit/held weapon sprite (`WeaponVisual`) или иные weapon-visual узлы оружия.
- [ ] Урон, target pattern, cooldown, fire_interval оружия НЕ изменены; боевые/runtime смоуки проходят (`runtime_smoke_combat_test.gd`, `runtime_smoke_weapon_mechanics_test.gd`).
- [ ] Attack/VFX попаданий, projectiles, hazards, summon-сущности и эффекты атаки остаются видимыми (они не являются отображением экипированного оружия).
- [ ] Снаряды/ловушки/орбы, использующие текстуру через `_weapon_visual_texture()` (`scripts/class_weapon.gd:2168`), по-прежнему рисуются корректно — текстура `WeaponVisual` НЕ обнулена и узел не удалён.
- [ ] Hero Select / Codex / preview-отображение оружия не сломано (рисуется через `ui_screens.gd` `WeaponSelectSprite` из config, не из игрового инстанса — должно быть нетронуто).
- [ ] Есть явный debug/preview flag (константа/meta), под которым держимый визуал можно показать обратно вне боя.
- [ ] `tests/weapon_orbit_smoke_test.gd` обновлён: проверяет скрытость держимого визуала и сохранность боевой/орбитальной механики; проходит headless. QA evidence приложено.

## Files / точки входа

- `scripts/player.gd:358` `_configure_attached_weapon_layer(weapon)` — добавить скрытие визуала держимого оружия (`visible = false` на корне оружия / `WeaponVisual`), под debug-флагом.
- `scripts/player.gd:46-48` (рядом с `WEAPON_ORBIT_*`) — добавить `const SHOW_HELD_WEAPON_VISUAL := false` (+ опц. meta-override по аналогии с `scripts/player.gd:267`).
- `scripts/player.gd:291` `_attach_weapon_scene` / `scripts/player.gd:278` `equip_weapon` — путь, который применяет скрытие при экипировке/смене оружия (проверить, ничего не переопределяет visible обратно).
- `tests/weapon_orbit_smoke_test.gd` — переключить ассерты с z-порядка `WeaponVisual` на проверку скрытости + сохранить проверку механики/орбиты; обновить QA-dump.
- (только читать, НЕ менять) `scripts/class_weapon.gd:2168` `_weapon_visual_texture()` — убедиться, что зависимость снарядов/ловушек/орбов от текстуры `WeaponVisual` не нарушена.
- (только читать, НЕ менять) `scripts/ui_screens.gd:3935`/`:3986` — подтвердить, что UI-превью оружия независимо от игрового `WeaponVisual`.

## Замечания / подводные камни

- ANTI-COLLISION / locked paths: `scripts/ui_screens.gd` и `scripts/progression_data.gd` — НЕ трогать. UI-превью оружия и данные оружия должны остаться как есть; задача целиком решается в `scripts/player.gd` (+ тест). Сцены оружия `scenes/*.tscn` править НЕ требуется (скрытие — runtime в коде); если всё же менять `visible` в сценах — это 102 файла, рискованно и избыточно, предпочтительно runtime-скрытие в `player.gd`.
- НЕ удалять узел `WeaponVisual` и НЕ обнулять его `texture` — иначе сломаются снаряды/ловушки/орбы (`_weapon_visual_texture()`), это самый частый способ всё уронить.
- Скрывать рендер (`visible`/`is_visible_in_tree`), а не отцеплять узел от дерева — оружие должно остаться в группе `player_weapons` под `WeaponSocket`, иначе `_equipped_weapons()` (`scripts/player.gd:1530`), скейлинг статов и cleanup перестанут его находить.
- Edge-case: смена оружия в рантайме (берсерк сабклассы `configure_berserk_subclass` → `equip_weapon`, повторные `configure_character`) переинстанцирует оружие — убедиться, что скрытие применяется каждый раз через `_configure_attached_weapon_layer`.
- Edge-case: разные базовые скрипты оружия — `class_weapon.gd`, `berserk_weapon.gd` (напр. `LongSpear.tscn`), `summoner_weapon.gd`. Скрытие на корне оружия (общий CanvasItem) покрывает все варианты, не завязывайся на имя `WeaponVisual` жёстко — но если у части сцен визуал лежит в нестандартном дочернем узле, скрытие корня всё равно его поймает.
- Связанный тикет/история: SCRUM-455 ввёл орбиту держимого оружия и `weapon_orbit_smoke_test.gd`. Эта задача фактически прячет результат SCRUM-455 в бою — тест из SCRUM-455 надо переориентировать, а не удалять.
- Проверять реальным мета-сейвом осторожно: тесты могут читать dev meta — см. практику запуска смоуков headless из QA-роли.
