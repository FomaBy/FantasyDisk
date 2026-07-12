# Combat Feel Rework — точка отсчёта, анти-прилипание, честные АОЕ

**Дата:** 2026-07-12 · **Статус:** done · **Источник:** прямой запрос пользователя (чат-оркестратор) · **Трекинг:** Multica FAN-1037

## QA-Вердикт

**Статус: PASSED** (2026-07-12, изолированный worktree на origin/dev 7aab0b6dc, 17/17 зелёных):
runtime_smoke (134s), animation_smoke, meta_progression_smoke, melee_weapon_targeting,
runtime_smoke_combat, runtime_smoke_boss_elite, feet_anchor_ground_circle,
enemy_separation_behavior, combat_fairness, aoe_telegraph_fairness_runtime,
contact_stuck_attack_deadzone, contact_damage_softcap, boss_directional_telegraph,
elite_attack_config_safety, enemy_content_integrity + баланс-гейты boss_elite_ttk
(запас 1.87–2.34× при полу 1.35×) и enemy_damage_spread (худший TTD 0.58s при полу 0.48s —
следить при будущем тюнинге contact_range). Оконная приёмка: `docs/qa/combat_feel_rework/combat_feel_rework_windowed.png`
(круг-якорь на ногах, крест origin в центре круга, y-sort, телеграф в urgent-фазе).

## Зачем

1. **Точка отсчёта персонажа** должна быть кругом ПОД НОГАМИ, а не в центре/на уровне головы спрайта.
2. **Монстры прилипают к персонажу**: едут в точный центр игрока без stop-радиуса, без сепарации, физически не сталкиваются ни с кем (mask=SOLID only) — до 48 мобов сходятся в одну точку.
3. **АОЕ должны быть реагируемыми**: часть зон с windup 0.42–0.55s (порог реакции ~0.6s не выдержан), часть зон радиусом больше уворачиваемого расстояния, есть атаки вообще без телеграфа.

## Факты разведки (все дистанции origin-to-origin!)

- Игрок: спрайт 512-арт centered на origin, ноги ~+141..151px ниже origin. Данные `foot_y` per-class уже есть в `sliced_rig_manifest.gd`.
- Враги full-frame: уже ≈feet-anchored через `full_frame_animation_registry.gd` (negative Y offsets). Остаток +10..25px.
- Круг под ногами (GroundShadow) существует в `cutout_rig_2d.gd:297-305`, но мёртв на живом full-frame пути.
- Y-sort в проекте отсутствует полностью.
- `player.gd:_apply_sprite_transform` (3759) обнуляет VisualRoot каждый кадр — оффсет должен переживать это.
- `enemy.gd:_visible_sprite_size` (1114) меряет СКРЫТЫЙ статический Body, а не живой FullFrameBody.
- Скорость игрока: base 222–292 px/s по классам; дэша НЕТ; i-frames 0.32s; web-slow ×0.55.
- Ascension L5: boss_telegraph_mult=0.72 срезает все windup на 28%.
- Спавн-фильтр меряет до ARENA_CENTER, а не до игрока — спавн вплотную к игроку у краёв.

## Жёсткие контракты (НЕ ломать)

- `runtime_smoke_test.gd:705-714`: враги НЕ блокируют игрока физически; игрок проходит ≥12px за 0.18s сквозь наложенного врага. Сепарация — только steering, БЕЗ коллизий.
- `runtime_smoke_test.gd:694-714`, `contact_damage_softcap_test.gd:51`: враг на позиции игрока успешно наносит contact-удар → engage-дистанция должна остаться ВНУТРИ contact_range, отход из глубокого оверлапа не должен выходить за contact_range.
- `contact_stuck_attack_deadzone_test.gd`: оружие достаёт врага в упор — не трогаем.
- Гейты TTK/DPS: uptime contact-урона сохранить (engage ≤ 0.8×contact_range).
- `runtime_smoke_test.gd:916` (level-up effect ≤6px от origin), `:1636-1653` (боссовые зоны на фикс. оффсетах) — origin'ы не двигаем, всё остаётся валидно.
- `runtime_smoke_test.gd:1926-1934`: hitbox/silhouette ratio [0.45,1.25] — размеры коллизий не меняем.

## Дизайн

### Этап A — Feet-origin + круг под ногами + Y-sort (визуал, origin'ы не двигаются)

- Игрок: поднять визуал на `-(foot_y - size.y*0.5) * BASE_SPRITE_SCALE` per-class (foot_y из sliced_rig_manifest, дефолт 0.94*size при отсутствии). Оффсет хранить в поле и переприменять в `_apply_sprite_transform`.
- WeaponSocket: вертикальный bias на уровень торса (`-8 - lift*0.5`).
- Camera2D: offset.y ≈ `-lift*0.45` — силуэт визуально по центру, ноги чуть ниже центра (классика ARPG).
- Попапы/сокеты/level-up VFX над головой: сместить на lift.
- Враги: реестровые оффсеты не трогаем (уже feet-anchored, hand-tuned).
- GroundCircle: универсальный узел «круг под ногами» на живом пути — эллипс (Polygon2D) на локальном (0,0), z_index -8: игрок — заметный круг с ободком (читается как точка отсчёта), враги — мягкая тень; ширина от видимой ширины спрайта; у элиток/боссов масштабируется epic scale автоматически (child узла).
- Y-sort: `y_sort_enabled = true` на корне Main (плоский Node2D-родитель всех актёров); фоны/зоны/снаряды не страдают — у них явный z_index.
- `_visible_sprite_size`: учитывать живой FullFrameBody (frame size × scale), фолбэк на статический Body. Проверить дрейф contact_range/healthbar.

### Этап B — Естественное поведение монстров (enemy.gd движение + combat_director спавн)

- **Melee arrival**: engage_dist = 0.8×contact_range; полоса торможения +60px (плавное замедление до ~35%); внутри engage — тангенциальный дрейф 25% скорости (направление по хешу instance id); глубокий оверлап (<0.62×engage) — мягкий отход 45% скорости, но НЕ дальше 0.75×contact_range (уптайм урона сохранён).
- **Сепарация врагов** (steering, без физики): соседи из группы enemies, пересчёт списка раз в ~0.15-0.25s со stagger'ом, до 3-4 ближайших в радиусе суммы видимых радиусов; push 60-90 px/s; вес по рангу: ordinary 1.0, elite 0.4, boss 0.0 (не толкается).
- **Стрелки/саммонеры**: вместо freeze — медленный строб (тангенциально 40% скорости, смена направления по таймеру 2-4s/у края арены); гистерезис (подход до 0.92×desired, отход с 0.78×desired).
- **Contact windup**: на время замаха (0.22s) скорость ×0.2 — «клюёт и бьёт», а не «трётся».
- **Knockback читается**: вес chase-скорости = max(0, 1 − |kb|/300) — удары реально отбрасывают.
- **Спавн-защита**: `_is_spawn_position_clear` меряет до ЖИВОГО игрока (≥420px, фолбэк — дальняя точка кромки); pack/retinue/given-position спавны ≥320px от игрока; миньоны саммонера/рифтлинги ≥140px от игрока.

### Этап C — Честные АОЕ (boss.gd, enemy.gd элитки, hazard_vfx.gd, progression data)

- Новый статик-хелпер `scripts/combat_fairness.gd`:
  `fair_windup(base, escape_distance, asc_mult, player_speed)` = `max(base*asc_mult, REACTION 0.4 + escape_distance/ESCAPE_SPEED_REF 250, ABS_FLOOR 0.55)`; компенсация слоу игрока (escape время × base_speed/current_speed, cap ×1.8).
  `escape_distance`: полный радиус для зон с центром на игроке; radius×0.6 для boss-центрированных; ширина кольца для колец с безопасным проходом.
- Все 11 telegraph-сайтов boss.gd + элитные зоны enemy.gd переводятся на fair_windup (ascension-множитель остаётся, но не пробивает пол).
- **Ноль-телеграф чинится**:
  - Boss dash: 0.45s замах, направление фиксируется в начале замаха (сайдстеп работает), телеграф-линия/трейл.
  - Elite stalker dash: замах 0.4s с тинтом ДО рывка, направление залочено.
  - Night stalker phase-2 второй удар: цель = снапшот (не live-позиция игрока), телеграф 0.35s, урон только в радиусе снапшота.
  - Reflect thorns: остаётся (реактивная механика), но аура обязана быть видимой при активной защите.
- Элитные windup в data: 0.45-0.6 → 0.65-0.8; asc-L3 elite_instant_phase — первый удар не короче 0.45s.
- Телеграф читаемость (hazard_vfx.gd): пик альфы 0.5→0.62; последние ~25% windup — ускоренный «сейчас рванёт» пульс/вспышка.
- Пост-фазовый burst: клампы кулдаунов после смены фазы 0.45-1.1 → 1.2-1.8s.
- Iron bastion slam: ринг-визуал 0.30→0.15s (визуальная ложь минимизирована).

## Тесты (новые)

- `tests/combat_fairness_test.gd` — матем. пол windup, ascension не пробивает пол, скан data-windup'ов.
- `tests/enemy_separation_behavior_test.gd` — два наложенных врага расходятся; melee останавливается у engage и попадает contact-ударом; игрок проходит сквозь врага (≥12px/0.18s).
- `tests/feet_anchor_ground_circle_test.gd` — визуальный lift игрока по foot_y; GroundCircle есть у игрока и врага; y-sort включён.
- `tests/aoe_telegraph_fairness_runtime_test.gd` — элитная зона: телеграф существует, windup ≥ пола; night stalker бьёт по снапшоту.

## QA

Godot **4.7** (`~/Downloads/Godot.app`), прогоны через `python3 tools/godot_gate.py --headless --path . --script res://tests/<t>.gd`; pipestatus-ловушка; обязательный минимум: runtime_smoke, animation_smoke, meta_progression_smoke, melee_weapon_targeting + новые тесты + боевые смоуки (combat, boss_elite). Гейты TTK/спреда — прогнать и оценить дрейф. Визуальная приёмка телеграфов/круга — оконный капчер.
