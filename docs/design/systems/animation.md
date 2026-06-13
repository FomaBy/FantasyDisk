# Animation

Обновлено: 2026-06-13

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
- Player cutout rig использует per-character `walk_blend_rate` / `direction_blend_rate`: `berserk` двигается тяжелее, `dark_mage` мягче и с меньшим robe/body lean, `guitarist` быстрее. Pass 2026-06-12 добавил отдельные visual motion profiles для новых классов: `assassin` быстрый/резкий, `ranger` собранный, `doctor` спокойный тяжелый, `chemist` чуть нервный, `knight` тяжелый инертный, `druid` мягкий ритуальный. Pass SCRUM-168 2026-06-13 добавил `soldier`: средневесовый дисциплинированный шаг, меньше arm swing, умеренный body bob. Pass SCRUM-169 2026-06-13 добавил `thief`: легкий осторожный шаг с быстрым direction blend, меньшим bob и сдержанным переносом веса. Pass SCRUM-163 2026-06-13 добавил `elementalist`: плавный энергичный caster-step, легче Dark Mage, с выраженным breath/channel sway. Pass SCRUM-167 2026-06-13 добавил `sniper`: controlled ranged/sniper gait, low bob, low arm swing, steady aim stance without melee lunge feel. Pass SCRUM-165 2026-06-13 добавил `priest`: calm healer/support caster gait, low aggression, restrained arm swing, readable robe bob and support-caster sway. Pass SCRUM-162 2026-06-13 добавил `biologist`: careful field-scientist gait, modest bob, specimen-handling arm posture, distinct from Chemist/Doctor. Pass SCRUM-166 2026-06-13 добавил `robot`: heavy construct gait, slow inertial walk, strong mass bob, low arm swing, slower direction blend.
- Все cutout rigs имеют контактную `GroundShadow`; на новых плоских фонах она остается основным grounding cue и не должна удаляться при будущих visual passes.
- Berserk attack pose получает animation variant из текущего `weapon_id`: `sword` = forward thrust, `axe` = wide arc, `hammer` = overhead slam. Это только motion layer; damage shape/window остаются в weapon/backend конфигурации.
- Soldier shoot pose получает animation variant из текущего `weapon_id`: `soldier_rifle` = suppression recoil, `soldier_grenade` = cook/throw, `soldier_bayonet` = defensive brace. Это только motion layer; attack modes/timing остаются в `ClassWeapon`.
- Thief shoot pose получает animation variant из текущего `weapon_id`: `thief_coin_pouch` = быстрый щелчок монетой вперед, `thief_shadow_cloak` = сжатие и backstab-рывок, `thief_smoke_bomb` = dodge-back и низкий бросок дымовой бомбы. Это только motion layer; `coin_ricochet`, `shadow_backstab` и `smoke_bomb` gameplay остаются в Back-end.
- Elementalist shoot pose получает animation variant из текущего `weapon_id`: `elementalist_orb_ring` = channel with both arms spread, `elementalist_prism_focus` = forward crystal focus, `elementalist_meteor_core` = overhead meteor summon. Это только motion layer; `elemental_orbit`, `prism_rift` и `meteor_shards` gameplay/timing остаются в Back-end.
- Sniper shoot pose получает animation variant из текущего `weapon_id`: `sniper_deadeye_rifle` = steady lockshot brace, `sniper_spotter_scope` = off-hand kill-zone mark, `sniper_shatter_rounds` = heavier braced recoil. Это только motion layer; `sniper_lockshot`, `sniper_kill_zone` и `sniper_split_round` targeting/damage/timing остаются в Back-end.
- Priest shoot pose получает animation variant из текущего `weapon_id`: `priest_reliquary` = sanctify blessing hand and release, `priest_censer` = outward ward pulse gesture, `priest_chime` = lifted chime/chant pose. Это только motion layer; `priest_sanctify`, `priest_ward` и `priest_prayer_chain` gameplay/timing остаются в Back-end.
- Biologist shoot pose получает animation variant из текущего `weapon_id`: `biologist_spore_lens` = raised inspection/bloom lens stance, `biologist_sample_injector` = precise forward dart pose, `biologist_symbiote_seed` = low planting/web gesture. Это только motion layer; `bio_spore_bloom`, `bio_sample_dart` и `bio_symbiote_web` gameplay/timing остаются в Back-end.
- Robot shoot pose получает animation variant из текущего `weapon_id`: `robot_magnetic_anchor` = heavy plant and low pull, `robot_hydraulic_press` = forward dual-arm compression drive, `robot_reactor_core` = wide reactor vent stance. Это только motion layer; `robot_magnetic_anchor`, `robot_compression_line` и `robot_reactor_vent` gameplay/timing остаются в Back-end.

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
