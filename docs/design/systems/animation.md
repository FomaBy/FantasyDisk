# Animation

Обновлено: 2026-06-14

Animator ownership описан в `docs/process/agent_role_boundaries_and_handoffs.md`. Back-end должен не полировать motion, а предоставлять стабильные states/API.

## Architecture

- Игровые сущности используют polished full-art sprites как видимый слой.
- `scripts/cutout_rig_2d.gd` собирает rig/cutout parts для движения, squash, socket, hit/action timing.
- Source PNG остаются меню/fallback-изображениями.
- `scripts/sliced_rig_manifest.gd` хранит данные нарезки.
- Read-only audit SCRUM-173 (2026-06-13) зафиксировал матрицу покрытия в `docs/design/reviews/animation_rig_audit_2026_06.md`: базовый rig/state слой широкий, но 0.1.4 follow-up нужен для legacy player weapon-action hooks, enemy archetype assertions, hit/death coverage, weapon timing/VFX sync и Design-ready parts для новых боссов/мини-элиток.
- Directive 2026-06-14: future production animation must follow
  `fantasydisk-animation-director`: every playable character, monster, summon,
  elite, and boss needs 5+ movement frames and 5+ primary attack frames. Elites
  and bosses must use smooth full-frame sprite sheets for production animation,
  not cutout slicing of static sprites, and need multiple skill/phase attack
  patterns. Audit `docs/design/reviews/animation_full_frame_pipeline_audit_2026_06.md`
  / SCRUM-350 tracks current compliance and created Design/Back-end handoffs
  SCRUM-352 and SCRUM-351.
- SCRUM-351 added `scripts/full_frame_animation_registry.gd`: a Back-end
  SpriteFrames lookup/state adapter for `hero`, `enemy`, `ally`, `elite`, and
  `boss` entity IDs. It may create `FullFrameBody` (enemies/bosses) or reuse
  `AnimatedBody` (allies) when registry frames exist, while preserving existing
  cutout/static fallback when frames are missing.
- SCRUM-363 integrated the first SCRUM-352 enemy pilot: `rift_cutter` now has
  padded full-frame SpriteFrames at
  `assets/sprites/enemies/full_frame/rift_cutter_spriteframes.tres` with
  `move` 6f loop and `attack_primary`/runtime `attack`, `hit`, `death` 6f
  one-shots. The visual override is registry-only and does not change enemy AI,
  damage, targeting, spawn rules or balance.
- SCRUM-364 extended the same standard-enemy full-frame integration to
  `ash_marksman`, `spark_runner`, `stone_bruiser`, `bone_caller`, and
  `void_mage`. Each uses a padded `384x384` runtime canvas, `move` 6f loop,
  `attack_primary`/runtime `attack`, `hit`, and `death` 6f one-shots, and
  registry-only activation on the existing enemy scenes.
- SCRUM-365 added the next accepted standard-enemy batch: `venom_spitter` and
  `rift_shieldbearer` use the same padded SpriteFrames contract and registry-only
  scene activation.
- SCRUM-366 added `small_biter` to the same full-frame registry path with a
  compact `0.30` scale and the standard 6-frame move/attack/hit/death contract.
- SCRUM-367 added `bone_shaman` and `winged_spark` to standard-enemy full-frame
  registry coverage. `winged_spark` preserves the accepted source `hover_flap`
  row as a looped runtime state and exposes `hit` as a visual alias to keep the
  existing enemy hit-state contract.

## Full-Frame State Registry

- `FullFrameAnimationRegistry.registry_config(entity_kind, entity_id)` is the
  canonical runtime lookup point for full-frame SpriteFrames metadata.
- `configure_entity_visual()` attaches the animated body, applies scale/offset,
  hides the static fallback only after a valid SpriteFrames resource exists, and
  records `entity_kind`, `entity_id`, and `source_faces_left` metadata.
- `play_state(animated_body, state, direction)` accepts direct states
  (`move`, `attack`, `hit`, `death`) and variants such as
  `attack_slam_wave` or `<elite_behavior>:<attack_id>:<phase>`. The helper
  records `last_requested_state` and `last_resolved_state` for smoke tests and
  Animator debugging.
- Missing states resolve through safe aliases (`attack_primary` -> `attack`,
  `walk/run/levitate` -> `move`, skill variants -> `attack`) before falling
  back to idle/move. Missing resources return `null` and leave old visuals
  untouched.
- Damage windows, targeting, cooldowns, spawn rules, VFX spawn and cleanup
  remain owned by gameplay code. The registry is a visual state bridge only.
- SCRUM-379 adds death playback lifecycle ownership for explicit full-frame
  deaths: enemies with `FullFrameBody.death` play that row before delayed
  cleanup while leaving combat groups/collisions immediately after rewards are
  emitted; missing death rows keep the existing death-ghost fallback.
- SCRUM-380 (2026-06-14) provides the complete Design source pack for explicit
  full-frame `death` rows: 19 entities, 114 transparent frames, row sheets,
  manifest `docs/design/references/scrum380_death_rows/scrum380_death_rows_manifest.json`
  and contact/readability previews. SCRUM-370 consumed all 19 rows into the
  existing runtime SpriteFrames paths for 4 allies, 4 route elites, all 6
  mini-elites and all 5 bosses; validation artifacts are under
  `build/qa/animation_integrate_all_move_attack_death_states/`.
- SCRUM-394 (2026-06-14) refreshes canonical source-sheet structure only:
  26 full-frame source sheets are now `1704x1144` RGBA and 19 death-row
  references are now `1704x304` RGBA, both using `256x256` cells with `24 px`
  transparent discard-only gutters and `24 px` outer padding. Runtime
  SpriteFrames, frame counts, states, timings and gameplay behavior were not
  changed.

## Player Motion

- SCRUM-422 defines the 0.1.6 playable character redraw v2 source contract.
  Design source sheets for the v2 wave are bright/epic per class, transparent
  RGBA, `512x512` cells, bottom-center pivot `(256, 470)`, and only
  `idle` + `move/walk` rows. Attack rows are intentionally out of scope for this
  initiative. The anchor exemplar is the cleaned Berserk source under
  `docs/design/references/characters_v2/bright_epic_anchor/` with the
  asset-side accepted source copy at
  `assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png`.
  Animator handoff after source acceptance should build `idle` 4-5f loop and
  `move` 5+f loop SpriteFrames/GIF/contact previews from the per-class sources,
  without changing gameplay, attack states, balance, collision, or weapon logic.
- SCRUM-298 Design standard: playable character full-frame redraws now use
  `docs/design/references/character_animation_style_sheet_0_1_5.md` as the
  source of truth for art direction, sheet rows, pivots and naming. Canonical
  future sheet path is `assets/sprites/characters/<class_id>_sheet.png`, default
  cell size is `384x384`, preferred sheet is `1920x1152` with rows
  `idle` / `walk` / `attack_primary` (5 frames each). Base character sheets are
  unarmed; weapon visuals stay in socket/weapon assets. Back-end now probes that
  path at character configure time, builds `idle`/`walk`/`attack_primary` and
  runtime `attack` SpriteFrames when a sheet exists, and otherwise falls back to
  the old cutout/static character visuals.
- SCRUM-411 fixed the runtime visibility switch for playable full-frame sheets:
  when `assets/sprites/characters/<class_id>_spriteframes.tres` or
  `<class_id>_sheet.png` exists, `Player/VisualRoot/Body` is visible and plays
  the full-frame `idle`/`walk`/`attack` states, while `RigRoot` is hidden so the
  old cutout body cannot cover the accepted redraw. The hidden rig remains only
  as a compatibility/socket/action-event anchor. Characters without full-frame
  frames keep the previous fallback: hidden `Body`, visible cutout `RigRoot`.
- SCRUM-412 cleaned the playable full-frame runtime PNG set at
  `assets/sprites/characters/full_frame/<class>/`: all 17 classes and all 255
  `idle` / `walk` / `attack_primary` frames now use real transparent alpha
  rather than a white/checkerboard matte inside the `384x384` canvas. The
  `SpriteFrames` resources and animation timings were not changed. Future
  playable sheet builds must run `tools/build_character_sheet.py`, which now
  calls `tools/alpha_clean_full_frame_characters.py` to remove edge-connected
  white/near-white/checkerboard matte from the visible alpha bounds and de-halo
  the silhouette before writing sliced frames. QA proof lives under
  `build/qa/scrum412_character_alpha/`; Godot import and animation smoke pass.
  `tests/animation_smoke_test.gd` now permanently samples one cleaned
  `*_idle_00.png` per playable class and fails if edge-ring white/checkerboard
  pixels or floodable matte regress beyond the SCRUM-412 thresholds.
- SCRUM-283 integrated Berserk's accepted unarmed source sheet
  `assets/sprites/characters/berserk_sheet.png` into runtime SpriteFrames at
  `assets/sprites/characters/berserk_spriteframes.tres`: `walk` 5f loop,
  `attack_primary`/runtime `attack` 5f one-shots, `idle` one-frame fallback,
  `384x384` canvas, bottom-center pivot guide `[192,348]`. Runtime frames are
  extracted to `assets/sprites/characters/full_frame/berserk/` so SpriteFrames
  do not slice neighboring source-sheet pixels; manifest/contact/GIF artifacts
  live under `build/qa/scrum283/`.
- SCRUM-286 integrated the accepted unarmed Dark Mage sheet
  `assets/sprites/characters/dark_mage_sheet.png` into runtime SpriteFrames at
  `assets/sprites/characters/dark_mage_spriteframes.tres`: `idle` 5f loop,
  `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, `384x384`
  canvas, bottom-center pivot guide `[192,348]`. Runtime frames are extracted to
  `assets/sprites/characters/full_frame/dark_mage/`; source references, a
  32px-gutter QA sheet, manifest and GIF previews are under
  `docs/design/references/characters/dark_mage/` and
  `build/qa/scrum286_dark_mage/`.
- SCRUM-291 integrated the accepted unarmed Guitarist sheet
  `assets/sprites/characters/guitarist_sheet.png` into runtime SpriteFrames at
  `assets/sprites/characters/guitarist_spriteframes.tres`: `idle` 5f loop,
  `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, `384x384`
  canvas, bottom-center pivot guide `[192,348]`. Runtime frames are extracted to
  `assets/sprites/characters/full_frame/guitarist/`; Design source references
  remain under `docs/design/references/characters/guitarist/`, while Animator
  manifest/contact/GIF artifacts live under `build/qa/scrum291/`. Manifest
  validation, Godot import, animation smoke and runtime smoke PASS after
  SCRUM-409.
- SCRUM-297 accepted the unarmed Thief sheet
  `assets/sprites/characters/thief_sheet.png`: `idle` 5f loop, `walk` 5f loop,
  `attack_primary` 5f one-shot, `384x384` canvas, bottom-center pivot guide
  `[192,348]`, no weapons/coins/smoke/held props. Design source references,
  alpha-clean sheet, 32px-gutter QA sheet, contact preview, manifest and GIF
  previews are under `docs/design/references/characters/thief/`,
  `docs/design/previews/scrum297_thief_sheet_contact.png` and
  `build/qa/scrum297_thief/`. Parallel Animator output already provides
  `assets/sprites/characters/thief_spriteframes.tres` and per-frame PNGs under
  `assets/sprites/characters/full_frame/thief/`.
- SCRUM-289 accepted the unarmed Elementalist Design source sheet
  `assets/sprites/characters/elementalist_sheet.png`: `idle` 5f loop source,
  `walk` 5f loop source, `attack_primary` 5f one-shot source, `384x384`
  canvas, bottom-center pivot guide `[192,348]`, no staff/wand/orb/focus/held
  object. Source references, alpha-clean sheet, 32px-gutter QA sheet, contact
  preview, manifest and GIF previews are under
  `docs/design/references/characters/elementalist/`,
  `docs/design/previews/scrum289_elementalist_sheet_contact.png` and
  `build/qa/scrum289_elementalist/`. Animator pass integrated runtime
  `assets/sprites/characters/elementalist_spriteframes.tres`: `idle` 5f loop,
  `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, `384x384`
  canvas, bottom-center pivot guide `[192,348]`, and per-frame PNGs under
  `assets/sprites/characters/full_frame/elementalist/`. Animator
  manifest/contact/GIF artifacts live under `build/qa/scrum289/`; manifest
  validation, Godot import, animation smoke and runtime smoke PASS.
- SCRUM-284 accepted the unarmed Biologist Design source sheet
  `assets/sprites/characters/biologist_sheet.png`: `idle` 5f loop source,
  `walk` 5f loop source, `attack_primary` 5f one-shot source, `384x384`
  canvas, bottom-center pivot guide `[192,348]`, no tools/syringes/flasks/bags/
  weapons/orbs/held objects. Source references, alpha-clean sheet, 32px-gutter
  QA sheet, contact preview, manifest and GIF previews are under
  `docs/design/references/characters/biologist/`,
  `docs/design/previews/scrum284_biologist_sheet_contact.png` and
  `build/qa/scrum284_biologist/`. Animator pass integrated runtime
  `assets/sprites/characters/biologist_spriteframes.tres`: `idle` 5f loop,
  `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, `384x384`
  canvas, bottom-center pivot guide `[192,348]`, and per-frame PNGs under
  `assets/sprites/characters/full_frame/biologist/`. Animator
  manifest/contact/GIF artifacts live under `build/qa/scrum284/`; manifest
  validation, Godot import, animation smoke and runtime smoke PASS.
- SCRUM-282 and SCRUM-294 integrated accepted unarmed Assassin/Ranger sheets
  into runtime SpriteFrames at
  `assets/sprites/characters/assassin_spriteframes.tres` and
  `assets/sprites/characters/ranger_spriteframes.tres`: each has `idle` 5f
  loop, `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, a
  `384x384` canvas, and per-frame PNGs under
  `assets/sprites/characters/full_frame/assassin/` and
  `assets/sprites/characters/full_frame/ranger/`. Manifest validation,
  animation smoke and runtime smoke PASS.
- Movement facing — отдельно от attack targeting.
- Attack direction приходит из weapon targeting и не перетирается velocity.
- `WeaponSocket` используется для attached weapons и должен оставаться совместимым с анимацией.
- Player cutout rig использует per-character `walk_blend_rate` / `direction_blend_rate`: `berserk` двигается тяжелее, `dark_mage` мягче и с меньшим robe/body lean, `guitarist` быстрее. Pass 2026-06-12 добавил отдельные visual motion profiles для новых классов: `assassin` быстрый/резкий, `ranger` собранный, `doctor` спокойный тяжелый, `chemist` чуть нервный, `knight` тяжелый инертный, `druid` мягкий ритуальный. Pass SCRUM-168 2026-06-13 добавил `soldier`: средневесовый дисциплинированный шаг, меньше arm swing, умеренный body bob. Pass SCRUM-169 2026-06-13 добавил `thief`: легкий осторожный шаг с быстрым direction blend, меньшим bob и сдержанным переносом веса. Pass SCRUM-163 2026-06-13 добавил `elementalist`: плавный энергичный caster-step, легче Dark Mage, с выраженным breath/channel sway. Pass SCRUM-167 2026-06-13 добавил `sniper`: controlled ranged/sniper gait, low bob, low arm swing, steady aim stance without melee lunge feel. Pass SCRUM-165 2026-06-13 добавил `priest`: calm healer/support caster gait, low aggression, restrained arm swing, readable robe bob and support-caster sway. Pass SCRUM-162 2026-06-13 добавил `biologist`: careful field-scientist gait, modest bob, specimen-handling arm posture, distinct from Chemist/Doctor. Pass SCRUM-166 2026-06-13 добавил `robot`: heavy construct gait, slow inertial walk, strong mass bob, low arm swing, slower direction blend. Pass SCRUM-164 2026-06-13 добавил `engineer`: practical tinkerer gait with workshop backpack/tools, moderate bob, measured arm swing, distinct from Druid/Robot.
- Все cutout rigs имеют контактную `GroundShadow`; на новых плоских фонах она остается основным grounding cue и не должна удаляться при будущих visual passes.
- Berserk attack pose получает animation variant из текущего `weapon_id`: `sword` = forward thrust, `axe` = wide arc, `hammer` = overhead slam. Это только motion layer; damage shape/window остаются в weapon/backend конфигурации.
- Legacy player pass SCRUM-186 (2026-06-13) добавил bespoke 3-weapon silhouettes для старых классов без изменения gameplay: `dark_mage` (book/skull/wand casts), `guitarist` (strum/bass pulse/amp deploy), `assassin` (chakram/dagger/wire), `ranger` (crossbow/longbow/trap), `doctor` (restore/syringe/saw), `chemist` (powder/flask/vial), `knight` (spear/shield/flail), `druid` (summon/briar/totem). Smoke проверяет distinct silhouettes и socket sanity по фактическим `progression_data.gd` weapon IDs.
- Soldier shoot pose получает animation variant из текущего `weapon_id`: `soldier_rifle` = suppression recoil, `soldier_grenade` = cook/throw, `soldier_bayonet` = defensive brace. Это только motion layer; attack modes/timing остаются в `ClassWeapon`.
- Thief shoot pose получает animation variant из текущего `weapon_id`: `thief_coin_pouch` = быстрый щелчок монетой вперед, `thief_shadow_cloak` = сжатие и backstab-рывок, `thief_smoke_bomb` = dodge-back и низкий бросок дымовой бомбы. Это только motion layer; `coin_ricochet`, `shadow_backstab` и `smoke_bomb` gameplay остаются в Back-end.
- Elementalist shoot pose получает animation variant из текущего `weapon_id`: `elementalist_orb_ring` = channel with both arms spread, `elementalist_prism_focus` = forward crystal focus, `elementalist_meteor_core` = overhead meteor summon. Это только motion layer; `elemental_orbit`, `prism_rift` и `meteor_shards` gameplay/timing остаются в Back-end.
- Sniper shoot pose получает animation variant из текущего `weapon_id`: `sniper_deadeye_rifle` = steady lockshot brace, `sniper_spotter_scope` = off-hand kill-zone mark, `sniper_shatter_rounds` = heavier braced recoil. Это только motion layer; `sniper_lockshot`, `sniper_kill_zone` и `sniper_split_round` targeting/damage/timing остаются в Back-end.
- Priest shoot pose получает animation variant из текущего `weapon_id`: `priest_reliquary` = sanctify blessing hand and release, `priest_censer` = outward ward pulse gesture, `priest_chime` = lifted chime/chant pose. Это только motion layer; `priest_sanctify`, `priest_ward` и `priest_prayer_chain` gameplay/timing остаются в Back-end.
- Biologist shoot pose получает animation variant из текущего `weapon_id`: `biologist_spore_lens` = raised inspection/bloom lens stance, `biologist_sample_injector` = precise forward dart pose, `biologist_symbiote_seed` = low planting/web gesture. Это только motion layer; `bio_spore_bloom`, `bio_sample_dart` и `bio_symbiote_web` gameplay/timing остаются в Back-end.
- Robot shoot pose получает animation variant из текущего `weapon_id`: `robot_magnetic_anchor` = heavy plant and low pull, `robot_hydraulic_press` = forward dual-arm compression drive, `robot_reactor_core` = wide reactor vent stance. Это только motion layer; `robot_magnetic_anchor`, `robot_compression_line` и `robot_reactor_vent` gameplay/timing остаются в Back-end.
- Engineer shoot pose получает animation variant из текущего `weapon_id`: `engineer_sentry_wrench` = lifted wrench deploy gesture, `engineer_repair_drone` = upward drone launch/guide pose, `engineer_pressure_mines` = crouched mine placement. Это только motion layer; `engineer_sentry_link`, `engineer_repair_drone` и `engineer_pressure_mines` gameplay/timing остаются в Back-end.

## Enemy Motion

- Враги/элитки/боссы используют cutout rig и base facing.
- Мобы не должны двигаться спиной вперед: facing sign учитывает `base_facing`.
- Enemy archetype pass SCRUM-184 (2026-06-13) добавил tailored action readability для partial rigs: marksman weapon recoil, runner coil/burst, bruiser slam, summoner/mage/shaman ritual casts, spitter body-squash shot, shieldbearer brace/shove, biter lunge, winged spark dive, Disk Devourer body chomp. Smoke проверяет movement + action silhouette per archetype.
- Elite active attacks имеют внешние фазы `windup/strike/recover/idle`.
- `enemy.gd` передает elite phases в rig как animation variant `<elite_behavior>:<elite_attack_id>:<phase>` вместе с backend duration. `cutout_rig_2d.gd` держит pose layer для `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`; VFX и damage остаются в backend/effects layer.
- SCRUM-368 (2026-06-14) перевел route elites `iron_bastion`, `night_stalker` и `plague_prophet` на production full-frame SpriteFrames через `FullFrameAnimationRegistry` kind `elite`. У каждой элитки есть `move` 6f loop, `attack`/`attack_primary` 6f one-shot, две 6f `skill_*` строки и `attack_*` validator aliases. Backend phase variants (`<elite_behavior>:<attack_id>:<phase>`) резолвятся в соответствующую accepted skill row без изменения damage/VFX timing.
- SCRUM-371 (2026-06-14) добавил тот же production full-frame contract для `shard_marshal`: `move`, `attack`/`attack_primary`, `skill_shard_fan`, `skill_command_pulse` и matching `attack_*` aliases; backend phase `shard_marshal:shard_fan:*` визуально резолвится в `skill_shard_fan`.
- SCRUM-376 (2026-06-14) подключил full-frame contract для всех mini-elites через SCRUM-372 `mini_elite_kind` visual-id hook: `mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`. У каждого есть `move` 6f loop, `attack`/`attack_primary` 6f one-shot, две 6f `skill_*` строки и matching `attack_*` aliases; missing mini-specific frames fallback'аются на base `elite_behavior`. SCRUM-370 добавил каждому `death` 6f one-shot.
- SCRUM-377 (2026-06-14) подключил full-frame contract для боссов `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`, `ashen_colossus`: `move`, `attack`/`attack_primary`, две 6f `skill_*` строки и matching `attack_*` aliases. SCRUM-378 добавил Back-end visual-only hooks: boss callbacks запрашивают matching `skill_*` state через `FullFrameAnimationRegistry`, а damage/VFX timing/targeting/cooldowns остаются прежними. SCRUM-370 добавил `death` 6f one-shot rows для всех 5 boss SpriteFrames.
- SCRUM-372 (2026-06-14) добавил visual-only hook для мини-элиток: если elite instance имеет meta `mini_elite_kind` и `FullFrameAnimationRegistry.sprite_frames_for("elite", mini_elite_kind)` существует, runtime выбирает именно этот full-frame visual ID. Если SpriteFrames для mini-kind еще нет, сохраняется прежний fallback на `elite_behavior` route-элитки.

## Summon / Ally Motion

- SCRUM-353 (2026-06-14) validated all mobile summon creatures through
  `fantasydisk-animation-director`: `druid_beast`, `druid_pack_spirit`,
  `homunculus`, and `leadership_echo` use full-frame SpriteFrames on the
  existing runtime paths. Each has `move` 8f/12fps loop and runtime `attack`
  6f/14fps non-loop, recorded as `attack_primary` in the skill manifest.
- SCRUM-370 adds ally `death` rows to those same SpriteFrames paths:
  6 frames at 10fps, non-loop, with static `ally_*.png` fallback unchanged.
- SCRUM-399 (2026-06-14) replaced the visual source and runtime PNG frame
  art for the four mobile summons with an ethereal allied spirit style: blue/
  cyan translucent bodies, soft inner glow and smoky edges. The pass preserved
  existing SpriteFrames resources, frame counts, loop flags, timings and
  registry placement. A follow-up safe-slicing cleanup repacked all 80 animated
  summon frame PNGs into the existing `256x256` cells with 24px transparent
  gutters: 0 edge-touch frames, 0 padding failures. Any new motion staging
  beyond this visual repaint remains Animator scope.
- `FullFrameAnimationRegistry` owns visual-only SpriteFrames lookup/placement for
  allies and keeps static `ally_*.png` sprites as fallback. Gameplay damage,
  targeting, command mode, lifetime, and summon role scaling remain in
  `SummonerWeapon` / `AllyMinion`.
- SCRUM-353 padded the wolf (`druid_beast`) frame PNGs to safe `256x256` canvas
  so transparent alpha no longer touches canvas edges; registry placement is
  `scale Vector2(0.37, 0.37)`, `position Vector2(0, -37)`.

## Hit / Death

- SCRUM-185 (2026-06-13) smoke coverage now asserts representative player, standard enemy, elite, and boss rigs entering `hit` and `death` states. `play_hit()` remains a short tint/shake state; `play_death()` keeps the existing collapse/fade; gameplay health, loot, cleanup, and death ownership remain Back-end.
- SCRUM-379 (2026-06-14) smoke coverage now asserts standard full-frame enemies
  select explicit `death` animation before cleanup and that fallback enemies
  still spawn `DeathGhostRig`. Gameplay rewards/death signals fire before the
  delayed visual cleanup, so loot/score/XP are not delayed or duplicated.

## Timing / VFX Sync

- SCRUM-187 (2026-06-13) implemented Animator-owned timing polish through existing `action_id`, `action_variant`, and normalized action progress in `cutout_rig_2d.gd`. This covers windup/release/body timing where the current action call already has enough data.
- SCRUM-208 (2026-06-13) added a Back-end timing event surface for weapon modes whose gameplay beats happen after the initial action pose. `Player.play_action_animation(action_id, direction, phase := "", duration := 0.0, metadata := {})` remains backward-compatible: calls without `phase` still drive the rig/action kick exactly as before, while calls with a non-empty phase update facing, store `last_weapon_animation_event`, and emit `weapon_animation_event(event)`.
- SCRUM-239 (2026-06-13) connects those phase events back into the cutout rig as
  Animator-owned pose timing: phase calls use variant
  `weapon_id:attack_mode:phase`, so existing class-specific pose hooks can read
  both the canonical weapon and the gameplay mode while keeping damage,
  targeting, VFX spawn, and cleanup in Back-end. Animation smoke covers every
  current playable class weapon variant for phase variant preservation and a
  visible non-idle silhouette.
- Timing event payload keys: `action_id`, `phase`, `duration`, `direction`, `weapon_id`, `character_id`, `metadata`. `ClassWeapon._emit_weapon_animation_event()` adds `metadata.attack_mode`, `metadata.weapon_id`, `metadata.display_name`, and `metadata.phase_source = "class_weapon"`.
- Supported phase names for weapon sync: `windup`, `release`, `pulse`, `burst`, `deploy`, `channel`, `recover`. Durations are derived from existing gameplay timing fields such as `grenade_delay`, `burst_interval`, `amp_lifetime`, `amp_pulse_interval`, `orbit_duration`, `pool_duration`, not Animator constants.
- Covered mode families: delayed area/deploy (`grenade_cook`, `smoke_bomb`, `prism_rift`, `meteor_shards`, `priest_sanctify`, traps/mines), repeated pulse/burst (`suppression_burst`, `amp`, `priest_ward`, `bio_spore_bloom`, `bio_sample_dart`, `elemental_orbit`, `engineer_sentry_link`), and channel/beam/chain (`beam`, `dot_beam`, `drain_link`, `priest_prayer_chain`, `bio_symbiote_web`, `engineer_repair_drone`).
- Animator should consume `weapon_animation_event` or `last_weapon_animation_event` for optional sync; gameplay damage, targeting, VFX spawning, cleanup and balance remain owned by Back-end weapon code.

## Pause Behavior

- Gameplay animations/effects должны уважать паузу.
- UI может работать в `PROCESS_MODE_ALWAYS`, gameplay tweens/effects — node-bound и pause-aware.
- Persistent weapon pool VFX (`poison_pool`, `spark_pool`, `briar_pool`) use Sprite2D textures and node-bound tweens on their owning pool nodes, so their visual pulse/fade follows gameplay pause together with the pool lifetime.

## Handoffs

- Новые sprite redraw / visual style issues -> Design.
- Walk/attack/cast/death motion polish -> Animator.
- Кодовые hooks, lifecycle, cleanup, state signals -> Back-end.

- Оружие в сокете получает собственный action-kick (`cutout_rig_2d.gd::_socket_action_kick`) поверх движения руки: anticipation/выпад на attack, отдача+подброс на shoot, подъём на cast — оживляет дальнобой/каст-оружие. Базовые снаряды (`projectile.gd`) тянут дешёвый мировой `Line2D`-трейл (кэп точек, без аллокаций нод в кадре).
