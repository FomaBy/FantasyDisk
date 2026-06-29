# SCRUM-509: Skeletal rig: устранить спам ERROR "det == 0" (affine_invert) при сборке рига

Jira: SCRUM-509 · Роль: animator · Контур: codex · Приоритет: P1 · foma · Эпик: —
Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)

## Что и зачем

Каждый прогон `runtime_smoke` и каждый старт боя со скелетным ригом (`dark_mage`, `knight`) сыпет в лог **360 строк**:

```
ERROR: Condition "det == 0" is true. at: affine_invert (core/math/transform_2d.cpp:51)
```

плюс сопутствующие **~20 строк/риг**:

```
WARNING: No Bone2D children of node X. Cannot calculate bone length or angle reliably.
```

Ошибки **нефатальны** — smoke остаётся зелёным, персонаж рисуется и анимируется. Но это шум, который:
- маскирует реальные ошибки в логах (CI/headless/билд-логи тонут в 360 одинаковых строк);
- пугает на плейтестах и в build-логах, выглядит как сломанный риг.

Цель: после `_build_rig()` каждый `Bone2D` имеет валидный, обратимый rest-трансформ (`det != 0`) и заданную длину/угол, так что `Skeleton2D` при пересчёте кэша поз не пытается инвертировать вырожденную матрицу. Внешний вид и анимация персонажа **не меняются** — это чисто гигиена логов рига.

Ожидаемый результат: чистый лог при сборке рига `dark_mage`/`knight`, ноль `det == 0`, ноль `No Bone2D children ... Cannot calculate bone length` для скелетных ригов, smoke и animation-smoke зелёные.

## Текущее состояние в коде

Риг строится в `scripts/skeleton_player_rig_2d.gd` (Node2D со скриптом). Сцены-обёртки:
- `scenes/characters/DarkMageSkeletonRig.tscn` → `entity_id="dark_mage"`, `manifest_path=res://assets/sprites/characters/skeleton_parts/dark_mage/skeleton_source_manifest.json`, `base_scale=(0.5,0.5)`.
- `scenes/characters/KnightSkeletonRig.tscn` (аналогично для knight).

Точка входа из игрока — `scripts/player.gd`:
- `_character_skeleton_rig_scene(class_id)` (≈1786) возвращает `DARK_MAGE_SKELETON_RIG_SCENE` / `KNIGHT_SKELETON_RIG_SCENE` (preload-константы строки 17–18).
- `_configure_skeletal_player_rig(skeleton_scene)` (строка 1760): инстансит сцену, добавляет в `_visual_root()`, вызывает `rig.configure(manifest, character_id, BASE_SPRITE_SCALE)`.

В `skeleton_player_rig_2d.gd`:
- `configure()` (стр. 28) → `_build_rig()` (стр. 38) → `_build_animation_player()` → `update_animation(...)`.
- `_build_rig()` (стр. 87): создаёт `Skeleton2D` (стр. 103), **сразу `add_child(_skeleton)`** (стр. 105), затем по одной спавнит кости `_spawn_bone(...)` каждая с немедленным `parent.add_child(bone)` (стр. 171). В самом конце дёргает `_finalize_bone_setup()` (стр. 124).
- `_spawn_bone()` (стр. 162) уже выставляет на каждой кости:
  - `bone.position = position`
  - `bone.set_autocalculate_length_and_angle(false)` (стр. 167)
  - `bone.set_length(MIN_BONE_LENGTH)` (`MIN_BONE_LENGTH = 8.0`, стр. 168)
  - `bone.set_bone_angle(0.0)` (стр. 169)
  - `bone.set_rest(Transform2D(bone.rotation, bone.position))` (стр. 170)
  - **затем** `parent.add_child(bone)` (стр. 171)
- `_finalize_bone_setup()` (стр. 178): проходит по всем костям повторно, пересчитывает length/angle от смещения первого дочернего Bone2D (`_first_child_bone_offset`, стр. 198) или от экстента спрайта (`_leaf_bone_length`, стр. 206), и снова `set_rest(Transform2D(bone.rotation, bone.position))` (стр. 193).

### Где именно рождается `det == 0`

`Transform2D(rotation, position)` сам по себе всегда обратим (det = 1). Проблема — в **порядке** и в **scale рига/масштабе глобальной позы**:

1. `_build_rig()` (стр. 97) и `update_animation()` (стр. 48) присваивают `scale` самому корню рига (`scale = base_scale = (0.5, 0.5)`, при отзеркаливании — `(−0.5, 0.5)`). `Skeleton2D` при `_update_bone_setup()` / пересчёте `bone_global_pose` накапливает rest-трансформы родителей. Любой `Bone2D`, у которого в цепочке родителей оказывается узел/кость с нулевым или вырожденным компонентом скейла на момент пересчёта, даёт нулевой det при `affine_invert()` накопленной позы.
2. **Главное:** `Skeleton2D` пересчитывает кэш на **каждый** `add_child` кости (через `NOTIFICATION_*`/`_make_bone_setup_dirty`). На промежуточных шагах сборки дерево костей ещё неполное и часть rest-ов ещё «дефолтные»/нулевой длины → 360 = многократный пересчёт × число костей × число ригов за прогон. К моменту `_finalize_bone_setup()` дерево уже полное, но ошибки уже насыпались во время пошагового `add_child`.
3. `No Bone2D children ... Cannot calculate bone length` — тот же корень: на момент, когда `Skeleton2D` считает длину родительской кости, у неё ещё нет дочерних `Bone2D` (они добавятся позже по ходу `_spawn_*`), а у листовых костей детей нет в принципе. `set_autocalculate_length_and_angle(false)` стоит, но предупреждение всё равно вылетает из внутреннего `_update_bone_setup`, потому что вызывается до того, как length/angle финализированы, либо до того, как `Skeleton2D` «видит» отключённый autocalculate в нужный момент.

### Манифест (dark_mage)

`assets/sprites/characters/skeleton_parts/dark_mage/skeleton_source_manifest.json`: 19 частей (`head, torso, pelvis, upper/lower_arm/hand × l/r, thigh/shin/foot × l/r, robe_front, cloak_back_l/r, hood_shadow`), `source_pivots`, `pivots`, `root_pivot_source={x:256,y:478}`, `z_order_hint_back_to_front`. Иерархия костей: `Root → Pelvis → Torso → Head` + конечности (`UpperArm/LowerArm/Hand`, `Thigh/Shin/Foot`) + опциональные (`robe→pelvis`, `cloak→torso`, `hood→head`).

### Тесты

- `tests/runtime_smoke_test.gd` — спавнит игроков, риг строится как побочный эффект; печатает `Runtime smoke test passed.`
- `tests/animation_smoke_test.gd` — `_assert_skeletal_player_rig(player, character_id)` (стр. 792): проверяет наличие `Skeleton2D`, `AnimationPlayer`, клипы idle/walk/move (без attack), путь костей `Root/Pelvis/Torso/...`, текстуру торса из `skeleton_parts/<id>/parts/`, что walk двигает Root и зеркалит при развороте. Печатает `Animation smoke test passed.`

## Что сделать — по шагам

Цель — все кости получают валидный rest/length/angle **до того**, как `Skeleton2D` впервые пересчитывает кэш поз, и пересчёт не происходит на каждый промежуточный `add_child`.

1. **Отложить присоединение `Skeleton2D` к дереву до полной сборки костей.** В `_build_rig()` строить всё поддерево костей (Root/Pelvis/Torso/… + конечности + опциональные части + WeaponSocketMarker), и только потом вызывать `_finalize_bone_setup()`, и **в самом конце** `add_child(_skeleton)`. Пока `_skeleton` не в дереве (`is_inside_tree()==false`), Godot не гоняет внутренний `_update_bone_setup`, и пошаговый спам исчезает. Сейчас `add_child(_skeleton)` стоит на стр. 105 — перенести его после `_finalize_bone_setup()` (стр. 124).
   - Поправить ссылки: `_spawn_bone("root", ...)` сейчас принимает `_skeleton` как parent (стр. 108) — это останется валидным, т.к. кости добавляются в ещё-не-в-дереве `_skeleton`.

2. **Финализировать rest/length/angle ПЕРЕД присоединением скелета.** Убедиться, что `_finalize_bone_setup()` (стр. 178) вызывается, когда всё дерево костей собрано, но `_skeleton` ещё не в `SceneTree`. После него — `add_child(_skeleton)`. Так первый и единственный `_update_bone_setup` Godot увидит уже корректные rest-ы (`det != 0`) и явно заданные length/angle с выключенным autocalculate.

3. **Гарантировать обратимость rest даже при зеркалировании.** Скейл рига (`scale = base_scale`, и `(−0.5, 0.5)` при развороте) применяется к корню рига, а rest-ы костей задаются `Transform2D(rotation, position)` — det=1, это ок. Но проверить, что нигде на кости не выставляется нулевой `scale`/нулевая длина. Оставить `set_length(maxf(length, MIN_BONE_LENGTH))` (стр. 191) — длина всегда ≥ 8. Добавить guard: если по какой-то причине `position == Vector2.ZERO` и нет детей-костей, всё равно задавать ненулевую длину и rest от родителя (уже частично покрыто, но убедиться явно для листовых костей `Hand*`, `Foot*`, `hood_shadow`).

4. **Подавить `No Bone2D children ... Cannot calculate bone length`.** Это предупреждение вылетает из `Skeleton2D` при autocalculate. Поскольку шаги 1–2 гарантируют, что autocalculate выключен и length/angle заданы ДО первого пересчёта, предупреждение должно исчезнуть. Если оно всё ещё течёт (Godot пересчитывает при `add_child(_skeleton)`), дополнительно: после присоединения скелета вызвать на каждой кости повторный `set_autocalculate_length_and_angle(false)` + `set_length(...)` (idempotent re-apply), либо явно `_skeleton.set_bone_setup_dirty`/форсировать один пересчёт после полной сборки. Не вводить autocalculate=true нигде.

5. **Не менять визуал/анимацию.** Позиции костей (`bone.position`), пивоты спрайтов (`_attach_part_sprite`, стр. 227), z-order, треки idle/walk (`_make_idle_animation`/`_make_walk_animation`) — НЕ трогать. Меняем только момент/порядок присоединения `Skeleton2D` и финализации rest, чтобы устранить шум. `_bone_rest_positions`/`_bone_rest_rotations` (используются анимацией через `_rest_pos`) должны остаться идентичными — заполняются в `_spawn_bone` (стр. 173–174), порядок их заполнения не меняем.

6. **(Knight параллельно.)** Knight использует тот же `skeleton_player_rig_2d.gd` через `KnightSkeletonRig.tscn` и свой манифест `skeleton_parts/knight/skeleton_source_manifest.json` — фикс в общем скрипте чинит оба рига автоматически. Проверить, что knight-манифест существует и риг строится без `det == 0` тем же прогоном.

7. **Прогнать оба smoke-теста headless и подтвердить нули** (см. Acceptance).

## Acceptance Criteria

- [ ] После `_build_rig()` каждый `Bone2D` имеет валидный rest (`set_rest`/`apply_rest`) и заданную длину/угол (`set_autocalculate_length_and_angle(false)` + `set_length`, либо корректный rest от родителя), так что rest-трансформ инвертируем (`det != 0`).
- [ ] `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_smoke_test.gd 2>&1 | grep -c 'det == 0'` возвращает **0** (было ~360).
- [ ] Тот же прогон **не содержит** `No Bone2D children of node ... Cannot calculate bone length` для скелетных ригов (было ~20/риг).
- [ ] Внешний вид/анимация персонажа в бою визуально не изменились (idle/walk играют, кости на местах) — подтвердить зелёным прогоном `tests/animation_smoke_test.gd` (`Animation smoke test passed.`), включая `_assert_skeletal_player_rig` для `dark_mage` и `knight`.
- [ ] `runtime_smoke_test.gd` остаётся зелёным (`Runtime smoke test passed.`).
- [ ] То же отсутствие `det == 0` подтверждено для рига `knight` (общий скрипт), не только `dark_mage`.
- [ ] Код стиля без autocalculate=true; `_bone_rest_positions`/`_bone_rest_rotations` для анимации не изменились (rest-позиции костей идентичны до/после фикса).

## Files / точки входа

- `scripts/skeleton_player_rig_2d.gd:87` `_build_rig()` — перенести `add_child(_skeleton)` (стр. 105) в конец, после `_finalize_bone_setup()` (стр. 124); собрать всё поддерево костей до присоединения скелета к дереву.
- `scripts/skeleton_player_rig_2d.gd:162` `_spawn_bone()` — сохранить выставление rest/length/angle/autocalculate(false); при необходимости вынести финальный `set_rest` исключительно в `_finalize_bone_setup`.
- `scripts/skeleton_player_rig_2d.gd:178` `_finalize_bone_setup()` — гарантировать вызов на полностью собранном дереве костей при ещё-не-в-дереве `_skeleton`; idempotent re-apply length/angle/rest; guard на ненулевую длину для листовых костей.
- `scripts/player.gd:1760` `_configure_skeletal_player_rig()` — точка вызова `rig.configure(...)`; менять, скорее всего, не нужно (фикс внутри рига), но проверить отсутствие повторных конфигов/двойного построения.
- `scenes/characters/DarkMageSkeletonRig.tscn`, `scenes/characters/KnightSkeletonRig.tscn` — сцены-обёртки рига (менять не требуется, для контекста).
- `assets/sprites/characters/skeleton_parts/dark_mage/skeleton_source_manifest.json` (+ knight-аналог) — источник pivots/иерархии (не менять, для верификации длины костей).
- `tests/runtime_smoke_test.gd`, `tests/animation_smoke_test.gd:792` `_assert_skeletal_player_rig` — гейты приёмки (не менять логику, прогонять headless).

## Замечания / подводные камни

- **Корень бага — не отсутствие rest, а порядок:** rest/length/angle уже выставляются (стр. 167–170, 190–193). Спам идёт из пошагового пересчёта `Skeleton2D` при каждом `add_child`, пока скелет уже в дереве (`add_child(_skeleton)` на стр. 105 ДО спавна костей). Главный рычаг — присоединять `_skeleton` к дереву ПОСЛЕ полной сборки и финализации костей. Не «лечить» симптом push_error-фильтром.
- **Не использовать autocalculate=true** нигде — это вернёт `No Bone2D children` предупреждения. Всегда явные `set_length`/`set_bone_angle`/`set_rest`.
- **Визуальная регрессия:** любое изменение `bone.position`, пивотов или треков анимации сломает `animation_smoke_test._assert_skeletal_player_rig` (проверяет walk двигает Root, зеркалит scale, опоры костей). Менять только тайминг присоединения скелета/финализации, не геометрию.
- **Anti-collision / locked paths:** задача НЕ трогает `scripts/ui_screens.gd` и `scripts/progression_data.gd` — конфликта с заблокированными путями нет. Основной файл `scripts/skeleton_player_rig_2d.gd` — изолирован за этим тикетом; `scripts/player.gd` правим минимально (вероятно не трогаем) — если параллельно есть другой тикет на player.gd, согласовать хунки, коммитить явным `git add` своих файлов (см. memory: commit explicit add during churn).
- **Knight ↔ dark_mage:** оба рига используют один скрипт. Если knight-манифеста ещё нет/он отличается по структуре — проверить, что `_finalize_bone_setup` корректен и для него; не хардкодить под dark_mage.
- **Зеркалирование:** `update_animation` ставит `scale=(±base_scale.x, base_scale.y)` на корень рига. Убедиться, что отрицательный X-скейл корня не порождает `det == 0` (он на Node2D-корне, не на rest костей — det rest остаётся 1; но проверить headless с разворотом влево).
- **Headless-сейв:** при прогоне smoke помнить про реальный dev мета-сейв (см. memory: godot-userdatadir не изолирует) — на счётчик `det == 0` это не влияет, но при ложных red'ах не эскалировать.
- **Верификация:** после фикса прогнать оба теста 2–3 раза, проверить `grep -c 'det == 0'` == 0 и `grep -c 'No Bone2D children'` == 0, оба `*passed.` присутствуют. После QA-вердикта PASSED — синкнуть Jira (`tools/jira_board_sync.py`).

## QA-Вердикт: PASSED

Статус: PASSED
Дата: 2026-06-27
Проверял: QA-воркер (фоновая приёмка), ветка dev @ HEAD, фикс `205fe13e` "Fix skeletal rig bone rest setup".

Прогоны (headless, Godot 4.6.3):
- `runtime_smoke_test.gd`: `grep -c 'det == 0'` = **0** (было ~360); `grep -c 'No Bone2D children'` = **0** (было ~20/риг); `Runtime smoke test passed.` Стабильно на 2 прогонах.
- `animation_smoke_test.gd`: `det == 0` = **0**, `No Bone2D children` = **0**, `Animation smoke test passed.` `_assert_skeletal_player_rig` покрывает `dark_mage` и `knight` (idle/walk играют, Root двигается, зеркалирование при развороте — визуал и rest-позиции не изменились).

Acceptance — все критерии сошлись:
- ✅ Bone2D имеют валидный rest + явную длину/угол (`set_autocalculate_length_and_angle(false)` + `set_length`), `_finalize_bone_setup` помечает `rest_det_safe` — rest инвертируем (det != 0).
- ✅ runtime_smoke `det == 0` = 0.
- ✅ runtime_smoke без `No Bone2D children ... Cannot calculate bone length`.
- ✅ Визуал/анимация не изменились — animation_smoke зелёный (вкл. dark_mage и knight).
- ✅ runtime_smoke зелёный (`Runtime smoke test passed.`).
- ✅ Ноль `det == 0` подтверждён и для knight (общий скрипт + существующий knight-манифест).
- ✅ autocalculate=true нигде не введён; rest-позиции костей идентичны (anim-smoke прошёл).

Действие: SCRUM-509 переведён в Jira «Готово», добавлен коммент с этим вердиктом.
