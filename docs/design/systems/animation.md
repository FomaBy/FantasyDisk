# Animation

Обновлено: 2026-06-12

Animator ownership описан в `docs/process/agent_role_boundaries_and_handoffs.md`. Back-end должен не полировать motion, а предоставлять стабильные states/API.

## Architecture

- Игровые сущности используют polished full-art sprites как видимый слой.
- `scripts/cutout_rig_2d.gd` собирает rig/cutout parts для движения, squash, socket, hit/action timing.
- Source PNG остаются меню/fallback-изображениями.
- `scripts/sliced_rig_manifest.gd` хранит данные нарезки.

## Player Motion

- Movement facing — отдельно от attack targeting.
- Attack direction приходит из weapon targeting и не перетирается velocity.
- `WeaponSocket` используется для attached weapons и должен оставаться совместимым с анимацией.
- Player cutout rig использует per-character `walk_blend_rate` / `direction_blend_rate`: `berserk` двигается тяжелее, `dark_mage` мягче и с меньшим robe/body lean, `guitarist` быстрее. Pass 2026-06-12 добавил отдельные visual motion profiles для новых классов: `assassin` быстрый/резкий, `ranger` собранный, `doctor` спокойный тяжелый, `chemist` чуть нервный, `knight` тяжелый инертный, `druid` мягкий ритуальный.
- Все cutout rigs имеют контактную `GroundShadow`; на новых плоских фонах она остается основным grounding cue и не должна удаляться при будущих visual passes.
- Berserk attack pose получает animation variant из текущего `weapon_id`: `sword` = forward thrust, `axe` = wide arc, `hammer` = overhead slam. Это только motion layer; damage shape/window остаются в weapon/backend конфигурации.

## Enemy Motion

- Враги/элитки/боссы используют cutout rig и base facing.
- Мобы не должны двигаться спиной вперед: facing sign учитывает `base_facing`.
- Elite active attacks имеют внешние фазы `windup/strike/recover/idle`.
- `enemy.gd` передает elite phases в rig как animation variant `<elite_behavior>:<elite_attack_id>:<phase>` вместе с backend duration. `cutout_rig_2d.gd` держит pose layer для `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`; VFX и damage остаются в backend/effects layer.

## Pause Behavior

- Gameplay animations/effects должны уважать паузу.
- UI может работать в `PROCESS_MODE_ALWAYS`, gameplay tweens/effects — node-bound и pause-aware.
- Persistent weapon pool VFX (`poison_pool`, `spark_pool`, `briar_pool`) use Sprite2D textures and node-bound tweens on their owning pool nodes, so their visual pulse/fade follows gameplay pause together with the pool lifetime.

## Handoffs

- Новые sprite redraw / visual style issues -> Design.
- Walk/attack/cast/death motion polish -> Animator.
- Кодовые hooks, lifecycle, cleanup, state signals -> Back-end.

- Оружие в сокете получает собственный action-kick (`cutout_rig_2d.gd::_socket_action_kick`) поверх движения руки: anticipation/выпад на attack, отдача+подброс на shoot, подъём на cast — оживляет дальнобой/каст-оружие. Базовые снаряды (`projectile.gd`) тянут дешёвый мировой `Line2D`-трейл (кэп точек, без аллокаций нод в кадре).
