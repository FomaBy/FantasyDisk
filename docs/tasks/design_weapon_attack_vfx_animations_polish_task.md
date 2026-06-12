# Задача Для Claude-Designer: Анимации Атак Оружия И VFX-Полировка Всех «Голых» Эффектов

Статус: in_progress
Создано: 2026-06-12
Автор: PM
Dispatch: отправлено в существующий Design чат `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-12; выполнять после `design_weapon_art_v2_proportions_knight_task.md`.
Координация: выполнять ПОСЛЕ `design_weapon_art_v2_proportions_knight_task.md`
(анимировать финальные спрайты оружия, не промежуточные).

## Autonomy / Approval
Пользователь заранее одобрил. Работать автономно, самопроверяясь.

## Контекст (решение пользователя)
1. Анимация оружия при атаке должна стать красивой (сейчас местами схематично).
2. ВЕЗДЕ, где эффект существует без дизайна — например лужи яда — сделать
   красивую анимацию. Никаких «программных кружков» там, где игрок видит эффект.

## Требования

### Анимации атак оружия
1. Пройти все 27 оружий: замах/выстрел/каст читаемый и сочный — anticipation,
   удар, follow-through; снаряды с трейлами; отдача оружия в сокете.
   Тайминги боя — источник истины (конфиги оружия), анимация подстраивается.
2. Уникальные паттерны — с собственным характером: возврат чакрама (вращение,
   свист), заряд арбалета (нарастающее свечение), drain-луч (пульсация),
   контратака рыцаря (вспышка блока), и т.д.

### VFX-аудит «голых» эффектов
3. Составить список ВСЕХ игровых эффектов и их текущего вида (программный
   примитив vs оформленный): лужи/облака яда химика и пророка, зоны ловушек,
   ауры, эхо-удары, боевой клич, зачарование, DoT-тики на врагах, лечение,
   щиты, телеграфы атак элиток/босса, детонации, ульты всех 9 классов.
   Список с вердиктами — в лог задачи (это аудит-артефакт приёмки).
4. Каждому «голому» — оформленная анимация: спрайтовые кадры/шейдерные переливы/
   частицы (дешевые), появление-жизнь-затухание, читаемость на плоских фонах.
   Лужи яда — приоритетный пример пользователя: пузырящаяся анимированная лужа,
   а не статичный круг.
5. Производительность: эффекты массовые — без тяжелых аллокаций в кадре,
   проверка на 100+ врагах с активными зонами (FPS не проседает заметно).
6. Пауза замораживает все новые анимации.

### Самопроверка
7. Видео/скриншоты до-после по ключевым эффектам в лог; огрехи чинить сразу.
8. Все smoke зеленые; animation smoke расширить на новые анимационные состояния.

## Files / Assets / IDs
- `scripts/attack_vfx.gd` (центральный VFX), `assets/sprites/effects/`,
  `scripts/cutout_rig_2d.gd` (анимации оружия в сокете), сцены зон/снарядов.
- Новые спрайт-кадры эффектов — генерация допустима через Codex с референсами.

## Acceptance Criteria
- [ ] Аудит-список эффектов с вердиктами в логе задачи; «голых» не осталось.
- [ ] Атаки всех 27 оружий анимированы с характером; тайминги не разъехались с боем.
- [ ] Лужи/облака/зоны/ауры/ульты оформлены и читаемы на плоских фонах.
- [ ] FPS на 100+ врагах с зонами не просел; пауза работает.
- [ ] Smoke + animation smoke зеленые.

## Документация
- content_registry (новые VFX-ассеты), systems/animation.md, CHANGELOG.

## Progress Log

### 2026-06-12 — Phase 1 / Persistent Pool VFX

Выполнен первый приоритетный visual block по примеру пользователя: лужи/облака больше не выглядят как голые программные круги.

Added assets:
- `assets/sprites/effects/poison_pool.png` — bubbling green poison/acid pool.
- `assets/sprites/effects/spark_pool.png` — warm spark/ember chemical pool.
- `assets/sprites/effects/briar_pool.png` — thorny green bramble pool.
- `docs/design/previews/vfx_pool_assets_contact.png` — contact QA preview.

Implementation:
- `scripts/class_weapon.gd::_spawn_damage_pool()` переведен с видимого `Polygon2D`-диска на `Sprite2D` raster pool.
- `pool_element` выбирает `poison`, `spark` или `briar` texture.
- Визуал получил pause-aware node-bound scale/rotation pulse и fade-out.
- Gameplay не менялся: damage radius (`aoe_radius * 0.7`), tick interval, duration, combo cloud logic и damage formulas оставлены из существующего weapon config.

Current audit notes:
- `scripts/attack_vfx.gd` — большинство player weapon helper effects уже raster/tween based (`slash_arc`, `impact_ring`, `impact_flash`, `dust_puff_*`, `void_orb`, `beam_strip`, `sound_wave`, `music_note`, `curse_skull`).
- `scripts/class_weapon.gd` persistent pools — было naked `Polygon2D`, исправлено в этом block.
- `scripts/level_up_effect.gd` / `scripts/level_up_toast.gd` — используют `Polygon2D`/`ColorRect`; это UI/level-up layer, не weapon attack VFX, но стоит включить в отдельный visual polish pass, если приемка требует убрать все primitive bursts.
- `scripts/cutout_rig_2d.gd` ground shadows используют `Polygon2D`; это grounding shadow, не attack VFX, оставлено.
- Route map `ColorRect` lines/backdrops — UI/map layer, не combat VFX.

Validation:
- Godot import: completed for the new pool PNGs.
- `tests/attack_vfx_smoke_test.gd` — passed.
- `tests/animation_smoke_test.gd` — passed.
- `tests/runtime_smoke_test.gd` — blocked by unrelated Back-end compile error in `scripts/combat_director.gd` lines 670-671 (`xp_reward` / `money_reward` type inference). Handoff created: `docs/tasks/backend_runtime_smoke_combat_director_type_inference_task.md`.

Remaining in this task:
- Full 27-weapon attack animation polish/audit.
- Full review of ultimates, auras, shields, telegraphs, hazard zones and healing VFX.
- Performance/FPS check with many active effects after the broader VFX pass.
