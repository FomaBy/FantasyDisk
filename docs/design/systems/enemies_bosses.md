# Enemies, Elites And Bosses

Обновлено: 2026-07-04 (0.2.1)

Канонические enemy/boss IDs и assets находятся в `docs/design/content_registry.md`. Основная логика врагов: `scripts/enemy.gd`, боссов: `scripts/boss.gd`, спавна: `scripts/combat_director.gd`. Data-driven enemy slices после SCRUM-198 находятся в `scripts/progression_data_enemies.gd` и экспортируются через `ProgressionData`.

## Standard Enemies

MVP поддерживает несколько архетипов:

- melee pressure enemy;
- ranged/shooter enemy;
- bruiser/high HP enemy;
- fast runner;
- summoner/minion pressure;
- additional mage/spitter/shield/biter/bone/flying variants from the expanded pool.

Все враги имеют HP bars и contact damage range, подогнанный под фактический визуальный размер.

## Elites

SCRUM-260 развел размеры по data-driven профилям `ProgressionData.ENEMY_SIZE_PROFILES`
(`scripts/progression_data_enemies.gd`):

| Profile | Scale | Runtime meaning |
| --- | ---: | --- |
| `ordinary` | 1.25 | обычные враги, увеличены на +25% для читаемости в бою |
| `mini_elite` | 1.31 | усиленный моб: свита Возвышения и редкая pressure-добавка обычных волн, больше обычного, меньше полноценной элитки |
| `elite` | 1.68 | карточная элитка узла маршрута, крупная и страшная |
| `boss` | 1.90 | боссы, самые крупные сущности |

Профиль передается в meta `epic_scale_profile` до `_ready()`, поэтому один node
scale согласованно тянет visible rig/body, `CollisionShape2D`, auto-fit
`contact_range` и HP-bar. SCRUM-829 поднял стандартных мобов и mini-elite свиту
на визуальный шаг +25%; route elites и боссы остались на прежнем масштабе, чтобы
иерархия размеров не перевернулась. С SCRUM-135 активные elite source sprites и cutout
manifests переведены на native `512x512`, поэтому epic-scale рендер не апскейлит
прежний 256px-арт на QHD/Retina.

| Elite | Attack | Pattern |
| --- | --- | --- |
| `iron_bastion` | `slam_wave` | shield block, thorn reflect while shielded, windup shockwave, knockback |
| `night_stalker` | `shadow_strike` | telegraph, исчезновение/телепорт за спину, phase-2 mirror second strike |
| `plague_prophet` | `poison_volley` | lob-снаряды, ядовитые лужи с тиками, plague/healing-inversion hook |
| `shard_marshal` | `shard_fan` | aura buff, веер кристальных снарядов, phase-2 ring volley |

Параметры data-driven в `ProgressionData.ELITE_ATTACK_CONFIGS`, reusable mechanics — в `ProgressionData.ENEMY_MECHANIC_CATALOG`, unique signatures — в `ProgressionData.UNIQUE_ENCOUNTER_PATTERNS`. Фазы `windup/strike/recover/idle` доступны Animator через сигнал `elite_attack_phase_changed` и meta `elite_attack_phase`; сами сущности также получают meta `unique_pattern_id`, `unique_pattern_title`, `unique_mechanics`. Урон уникальной атаки ограничен 25% max HP игрока.

## Bosses

Live boss scenes exist for `rift_warden`, `disk_devourer`, `bone_archon`,
`brood_mother`, `ashen_colossus`, and `bloodthorn_lion`. The random route boss
pool still uses the QA-gated subset; `bloodthorn_lion` remains out of random
rotation until its follow-up gate lands. С SCRUM-135 первые два активных boss
source sprites и cutout parts также `512x512`; `rift_warden` сохраняет отдельный
`vortex` cutout part, `disk_devourer` остается single-torso rig. SCRUM-156
подготовил source sprites для трех новых боссов; runtime mechanics/scenes уже
заведены, а полный art/cutout wiring остается отдельным content/animation scope.

| Boss | Scene | Pattern |
| --- | --- | --- |
| `rift_warden` | `scenes/BossWarden.tscn` | залпы, зоны разлома, призыв, щит, увороты, `BossGravityWell` |
| `disk_devourer` | `scenes/BossDiskDevourer.tscn` | рывки, disk slam AoE, radial burst, `BossVampiricBite`, enrage |
| `bone_archon` | `scenes/BossBoneArchon.tscn` | волны скелетов, веер черепов, bone prison/wall через `BossRiftZone` с проходом |
| `brood_mother` | `scenes/BossBroodMother.tscn` | выводок, `BroodWebZone`, дополнительный web pressure, рывок в фазе 3 |
| `ashen_colossus` | `scenes/BossAshenColossus.tscn` | slam-волны, тлеющие зоны, `BossMoltenArmorPulse`, enrage ниже 25% HP |
| `bloodthorn_lion` | `scenes/BossBloodthornLion.tscn` | прыжки-рывки, `radial burst` шипов, колючие rift-зоны, `BloodthornSpikeRing` (кольцо с проходом), enrage |

SCRUM-779 adds a Design-source PixelLab boss redraw package, but does not change
the live boss node rotation. Current boss redraw candidates, the special
`secret_ascension_boss` candidate, and one planned new boss (`skeletal_dragon`)
live under `assets/sprites/bosses/pixellab_candidates/` with source manifest
`docs/design/references/bosses/pixellab_roster_redraw_2026_06/manifest.json`.
OpenAI image generation was used only for new-boss concept references; PixelLab
MCP produced the production sprite candidates. SCRUM-793 promoted only the
accepted `disk_devourer` and `brood_mother` candidates into live rows. SCRUM-865
then replaced the live full-frame rows for all six live bosses from PixelLab MCP
8-direction source objects and imported west-facing runtime rows into the
existing Godot contract. Existing boss gameplay callbacks, damage, cooldowns,
route-pool status and encounter mechanics are preserved. `skeletal_dragon`
remains source-only/planned. Evidence:
`docs/design/previews/boss_pixellab_full_redraw_2026_07_runtime_contact.png`.

**SCRUM-794 — `bloodthorn_lion` runtime integration.** Back-end promoted the
`bloodthorn_lion` new-boss candidate to a live-runtime boss: single-view
candidate `assets/sprites/bosses/pixellab_candidates/bloodthorn_lion/bloodthorn_lion_pixellab_alpha.png`
(source-only) was upscaled 256→512 (nearest) into the live static sprite
`assets/sprites/bosses/boss_bloodthorn_lion.png`. Wired end-to-end: scene
`scenes/BossBloodthornLion.tscn`, unique `boss_behavior = "bloodthorn_lion"`
(dash-pounce + radial thorn burst + bleed rift-zones + `BloodthornSpikeRing`
unique mechanic), `UNIQUE_ENCOUNTER_PATTERNS` entry, `CombatDirector._boss_scene_for_id`
resolution, and a Codex boss entry. Covered by `_test_bloodthorn_lion_boss` in
`tests/runtime_smoke_boss_elite_test.gd`.

*Deferred (per staged AC "route/boss-pool integration only after mechanics and
QA are ready"):* `bloodthorn_lion` is intentionally **NOT** in the random route
pool `route_map_screen._random_boss_route_node` — the QA-gated rotation hookup is
a follow-up. The remaining `skeletal_dragon` candidate ("needs more epic boss
mass before final runtime") stays source-only. SCRUM-865 added
`bloodthorn_lion` full-frame SpriteFrames and visual hooks for
`skill_spike_ring` and `skill_rift_zone`; the random route pool is still
unchanged.

**SCRUM-865 — full PixelLab boss redraw integration.** Animator/Codex generated
new PixelLab MCP 8-direction source objects for all six live bosses and imported
west-facing 6-frame runtime rows for `move`, `attack`/`attack_primary`, `death`
and two `skill_*` states per boss. The first `256x256` attempt failed because
PixelLab caps 8-direction output at `168x168`; the completed supported pass
landed as `170x170` source objects and normalized `512x512` Godot runtime rows.
Source IDs/prompts are recorded in
`docs/design/references/bosses/boss_pixellab_full_redraw_2026_07/manifest.json`.
The runtime slice also fixes static fallback PNGs for `bone_archon`,
`brood_mother`, and `ashen_colossus`, registers `bloodthorn_lion` in the
full-frame registry, and keeps gameplay mechanics unchanged.

SCRUM-259 добавил boss-specific telegraph mechanics, SCRUM-261 закрыл их визуальный слой. Новые зоны продолжают использовать `HazardVfx.telegraph`/`detonate`, но helper выбирает dedicated painterly textures по runtime node name: `BossGravityWell`, `BossVampiricBite`, `BossRiftZone`/bone prison, `BroodWebZone`, `AshEmberZone`, `BossMoltenArmorPulse`. SCRUM-378 добавил visual-only boss full-frame skill-state hooks: эти callbacks запрашивают matching `skill_*` animation state, если для босса есть `FullFrameBody`, и fallback'аются на прежние `cast`/`attack`/`shoot` rig actions. SCRUM-379 добавил death playback lifecycle для explicit full-frame deaths: rewards/death signals происходят сразу, а визуальный труп выходит из combat groups, отключает collision/HP bar и удаляется после `death` row; missing death rows остаются на `DeathGhostRig` fallback. SCRUM-865 добавляет boss victory delay: после смерти босса `CombatDirector` чистит не-boss pressure, ждёт `2.0s`, затем завершает победу/переход акта, а boss full-frame death cleanup cap поднят до `2.4s`. Щиты, reflect-thorns, command aura и summon portal также получили отдельные VFX PNG. Runtime smoke проверяет, что каждая boss scene получает unique-pattern meta и реально создает свой named mechanic node; Design smoke проверяет текстурный hazard pipeline.

## Mini-Elites

`ProgressionData.MINI_ELITE_KINDS` содержит 6 видов mini-elite pressure-свиты:
`mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`,
`mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`. Их source PNG из
SCRUM-156 лежат в `assets/sprites/elites/`, но SCRUM-193 cleanup их не удалял:
raw audit видит их как candidates до полного content wiring, поэтому это не
legacy cleanup scope.

Мини-элитки используют те же elite-сцены и поведенческие паттерны, но перед
добавлением в дерево получают meta `drop_class=mini_elite` и
`epic_scale_profile=mini_elite`; поэтому визуально они читаются как усиленная
свита, а не как полноценный route elite или босс.
SCRUM-853 разрешает обычным волнам подмешивать mini-elites без Ascension: шанс
начинается около `0.015` и растет от `route_scaling_stage`, wave index и elapsed
combat time до capped `0.12`; принудительные Ascension-тесты с
`mini_elite_chance = 1.0` сохраняют deterministic spawn.

Минимальные правила:

- boss fight завершает run;
- boss имеет больше HP и несколько attack patterns;
- victory screen появляется после короткого boss-death playback delay;
- defeat/death screen появляется при смерти игрока;
- boss fight использует kill-or-lose таймер, а не survival-таймер обычного боя.

## Balance Notes

- Обычные враги стали жирнее, чуть медленнее и визуально крупнее относительно ранних прототипов.
- Количество врагов растет по stage/wave, но early-game не должен зажимать игрока со всех сторон.
- Мини-элитки меньше карточных элиток, но дают повышенный drop class.
- Карточные элитки редкие, крупные и опасные, но их атаки читаемы через telegraph.
- Боссы остаются крупнейшими enemy entities.

## Tests

`tests/runtime_smoke_test.gd` и `tests/runtime_smoke_boss_elite_test.gd`
проверяют elite scenes, attack phases, boss pool, spawn bounds, wave pacing,
mini/card elite/boss scale order, boss death victory delay и базовые combat flows.

## SCRUM-541 Secret Ascension Boss

`secret_ascension_boss` is a post-Act-3 backend/balance boss, not part of the
normal boss node rotation. The route map still starts the ordinary Act 3 boss;
after that boss is defeated, `CombatDirector` starts the secret encounter only
when the run was launched at the maximum available Ascension level.

Current scene: `scenes/BossSecretAscension.tscn`. SCRUM-539 delivered the
Design source pack and static/VFX candidates in
`docs/design/references/bosses/secret_ascension_boss/`,
`assets/sprites/bosses/secret_ascension_boss.png`, and
`assets/sprites/effects/secret_ascension_boss_*_telegraph.png`. SCRUM-540 then
delivered the full-frame Animator pack, and SCRUM-701 verified it (source and
animation READY): runtime frames live under
`assets/sprites/bosses/full_frame/secret_ascension_boss/` (60 transparent RGBA
512x512 frames, no matte, bottom-center pivot `(256,480)`), the safe-gutter
sheet is `assets/sprites/bosses/full_frame/secret_ascension_boss_full_frame_sheet.png`,
and the final SpriteFrames resource is
`assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres`,
exposing 16 states: 6f looping `idle`/`move`, 6f `attack_primary` plus
`attack_primary_windup`/`attack_primary_release`, four cast pairs
(`skill_ring`/`attack_ring`, `skill_cone`/`attack_cone`,
`skill_beam`/`attack_beam`, `skill_rupture`/`attack_rupture`), `hit`, and
`death`. Back-end runtime wiring is a separate task: register
`secret_ascension_boss` in `FullFrameAnimationRegistry` (recommended
`scale Vector2(0.86, 0.86)`, `position Vector2(0.0, -104.0)`, source faces
left). The static plus VFX candidate remains an interim only until that wiring
lands. Mechanics are implemented in `scripts/boss.gd` under
`boss_behavior = "secret_ascension_boss"`:

- `SecretBossSectorRing`: large telegraphed ring/sector pressure with safe gaps.
- delayed rift eruption clusters around the player.
- phase 2 at 50% HP adds immediate sector pressure plus riftling adds; phase 3
  begins below 25% HP.

Balance benchmark for Act 3 max Ascension L5, route scaling stage 18:
estimated HP is about `47.6k`. L20 optimum class-kit 1-target DPS range from
`205.39` to `391.83`, producing estimated TTK `231.8s` to `121.5s`
(`179.8s` at median `264.77` DPS). L20 random average DPS range
`85.07` to `137.09`, producing estimated TTK `559.6s` to `347.3s`.

SCRUM-539 art handoff notes: source/runtime candidate is `1024x1024` RGBA,
alpha bbox `[180, 42, 843, 984]`, recommended pivot `(512, 960)`, and visual
radius about `390px` on the 1024 source. Telegraph warning colors should stay
violet/gold/crimson/bone-white, readable over dark floors, with no pure-neon
fills or opaque noisy plates.
