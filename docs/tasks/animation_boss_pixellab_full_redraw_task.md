# Animation Task: Boss PixelLab Full Redraw And Animated Packs

Статус: done
Приоритет: P1
Роль: Animator
Контур: Codex
Owner: animator/codex-boss-pixellab-redraw-orchestrator
Thread/Worker: current Codex control thread + subagents
Jira: SCRUM-865
Версия: 0.2.1
Создано: 2026-07-04
Locked paths: `assets/sprites/bosses/**`, `assets/sprites/bosses/full_frame/**`,
`assets/sprites/bosses/pixellab_candidates/**`,
`docs/design/references/bosses/boss_pixellab_full_redraw_2026_07/**`,
`docs/design/previews/boss_pixellab_full_redraw_2026_07_*`,
`docs/design/content_registry.md`, `docs/design/current_game_state.md`,
`docs/design/systems/enemies_bosses.md`, `docs/design/systems/animation.md`,
`scripts/full_frame_animation_registry.gd`, `scripts/boss.gd`,
`scripts/combat_director.gd`, `scripts/main.gd`, `scripts/enemy.gd`,
`scenes/Boss*.tscn`, `tests/*boss*animation*.gd`,
`tests/animation_smoke_test.gd`, `tests/runtime_smoke_boss_elite_test.gd`,
`docs/tasks/animation_boss_pixellab_full_redraw_task.md`,
`docs/process/task_board.md`, `docs/process/jira_sync_map.json`

## Context

User request: redraw all current bosses from scratch through PixelLab, using the
current boss references and mechanics. The new bosses must be beautiful unified
dark fantasy creatures, source size 256x256 where PixelLab supports it, visibly
larger than playable characters in-game, with polished walk/move, attack/skill,
and especially heavy death animations. After boss death, the victory/act
transition must wait long enough for the death animation to be enjoyed.

Previous work:

- `SCRUM-779`: PixelLab boss roster candidates and new-boss concepts.
- `SCRUM-793`: promoted accepted single-view candidates only for
  `disk_devourer` and `brood_mother`.
- `SCRUM-794`: integrated static `bloodthorn_lion` runtime boss, but kept it
  outside route rotation and without full-frame animation rows.

This task supersedes partial/source-only state by creating a complete animated
PixelLab-first pack for the live boss roster.

## Boss Roster And Animation Contract

Live/current bosses:

- `rift_warden` / Страж Разлома: rift volleys, rift zones, summons, shield,
  dodges, `BossGravityWell`.
- `disk_devourer` / Пожиратель Диска: dash pressure, disk slam AoE, radial
  burst, `BossVampiricBite`, enrage.
- `bone_archon` / Костяной Архонт: skeleton waves, skull volley, bone
  prison/wall via `BossRiftZone`.
- `brood_mother` / Матерь Роя: brood spawn, `BroodWebZone`, extra web pressure,
  phase-3 lunge.
- `ashen_colossus` / Пепельный Колосс: slam waves, ember fields,
  `BossMoltenArmorPulse`, enrage below 25% HP.
- `bloodthorn_lion` / Кровавый Шипастый Лев: dash-pounce, radial thorn burst,
  bleed-style rift zones, `BloodthornSpikeRing`, enrage.

Required rows per boss:

- `move` / `walk`: readable heavy boss locomotion.
- `attack_primary`: core strike/volley/slam/pounce.
- Two boss-specific `skill_*` rows matching existing callbacks where available.
- `death`: large, slow, satisfying death with collapse/disintegration/fade, long
  enough to justify a victory-delay.

Keep gameplay callbacks, IDs, scenes, hitboxes, damage timings and VFX node names
unchanged unless a separate backend bug is created.

## Short PixelLab Base Prompts

Shared style suffix for all base prompts:

`top-down 3/4 dark fantasy pixel art boss, transparent background, 256x256, huge readable silhouette, ornate D&D monster, dramatic shadows, no text`

Per-boss base prompts:

- `rift_warden`: `void-armored rift warden, floating horned warlock knight, purple black-hole core, gold-black armor, torn shadow cloak`
- `disk_devourer`: `cosmic disk devourer, round many-eyed maw demon, ring of teeth and tentacles, violet singularity mouth`
- `bone_archon`: `bone archon necromancer, crowned skeletal lich, bone staff, ragged grave robes, green-gold necrotic glow`
- `brood_mother`: `brood mother spider queen, massive armored arachnid, egg sacs, webbed legs, sickly gold and black chitin`
- `ashen_colossus`: `ashen colossus, cracked obsidian lava giant, molten fists, ember smoke, heavy ancient golem`
- `bloodthorn_lion`: `bloodthorn lion, huge dark fantasy lion predator, crimson thorn mane, black hide, blood crystal spikes`

## Short PixelLab Animation Prompts

- `move`: `heavy boss walk, slow powerful weight shifts, body sways, claws/robes/legs move clearly`
- `death`: `epic boss death, stagger, collapse, crack apart, dark magic and embers leak out, final fading corpse`
- `rift_warden.attack_primary`: `casts rift bolts from both hands, cloak flares, core pulses`
- `rift_warden.skill_gravity_well`: `summons a purple gravity well, arms raised, vortex expands from chest`
- `rift_warden.skill_rift_zone`: `opens jagged rift fissures, sweeping occult casting gesture`
- `disk_devourer.attack_primary`: `lunges and slams its disk body, teeth flare, tentacles recoil`
- `disk_devourer.skill_vampiric_bite`: `vampiric bite, maw opens wide, red-violet drain energy`
- `disk_devourer.skill_rift_zone`: `spins and opens a rift ring, eye core flashes`
- `bone_archon.attack_primary`: `skull volley cast, staff points forward, skull spirits launch`
- `bone_archon.skill_skull_volley`: `rapid necromantic skull barrage, crown and staff glow`
- `bone_archon.skill_bone_prison`: `raises bone prison walls from the ground, staff slams down`
- `brood_mother.attack_primary`: `spider queen lunge bite, front legs stab forward`
- `brood_mother.skill_brood_spawn`: `spawns brood eggs and hatchlings, abdomen pulses`
- `brood_mother.skill_web_zone`: `casts sticky web zone, legs spread and silk bursts`
- `ashen_colossus.attack_primary`: `massive molten fist slam, shoulders recoil, lava cracks flare`
- `ashen_colossus.skill_molten_slam`: `ground-breaking lava shockwave slam, both fists down`
- `ashen_colossus.skill_armor_pulse`: `molten armor pulse, chest glows, ember ring bursts outward`
- `bloodthorn_lion.attack_primary`: `predator pounce slash, thorn mane whips forward`
- `bloodthorn_lion.skill_spike_ring`: `blood thorn spike ring roar, crimson crystals erupt around body`
- `bloodthorn_lion.skill_rift_zone`: `bleeding thorn fissures, claws carve red rift trails`

## Acceptance Criteria

- PixelLab MCP is used for every new production boss source/animation asset; no
  generic OpenAI fallback.
- PixelLab job/source IDs, prompts and selected candidates are recorded in a
  manifest under `docs/design/references/bosses/boss_pixellab_full_redraw_2026_07/`.
- Every live boss has movement, attack/skill rows and a large death row in the
  existing boss full-frame contract.
- Bosses render larger than playable characters via proportional runtime scale,
  preserving collision/HP-bar readability.
- Victory/act transition waits for boss death playback.
- Focused boss animation/runtime smokes pass through `tools/godot_gate.py`.
- Docs and Jira evidence are updated; task result records disk cleanup.

## Start Note

2026-07-04 Codex claim: Jira `SCRUM-865` created in active sprint
`Спринт 0.2.1` and claimed as Animator/Codex via required label
`boss-pixellab-redraw`. Branch/worktree: `dev` at
`/Users/sergeyfomin/Documents/AI Agent`. Next verification: inspect current boss
SpriteFrames/callback states, create PixelLab jobs, and record source IDs.

## Progress Note

2026-07-04:

- Created PixelLab MCP 8-direction 256x256 base-object jobs for all six live
  bosses and recorded object IDs/prompts in
  `docs/design/references/bosses/boss_pixellab_full_redraw_2026_07/manifest.json`.
- Current PixelLab status: all six base objects are queued/pending; animation
  jobs cannot be started until PixelLab completes or exposes review candidates.
- 03:48 EEST retry: PixelLab later marked all six original `256x256`
  8-direction base objects as failed because the service currently caps output
  frames at `168x168`. Retried all six bosses at supported `168x168`
  low-top-down canvas and recorded active object IDs in the manifest:
  `rift_warden` `ab1c7701-3ee7-4c7c-8842-22a7def87f08`,
  `disk_devourer` `2df47b9e-a5f8-4f4a-b423-4aca73d8c3b3`,
  `bone_archon` `0335a72f-9905-4a18-ba1e-e91d2a9de9bc`,
  `brood_mother` `0f0db439-9b79-4b25-8951-988319c5e821`,
  `ashen_colossus` `eb2bfa56-9406-4855-96e6-dc05c9272494`,
  `bloodthorn_lion` `1b923d8c-e83e-48a1-970e-4681f63ead0a`.
- Added boss-death victory delay: boss kill now clears immediate combat
  pressure, waits `2.0s`, then completes victory/act transition so the death
  row is visible.
- Raised boss full-frame death playback cap from `1.2s` to `2.4s`.
- Fixed static fallback textures for `bone_archon`, `brood_mother`, and
  `ashen_colossus`; animation smoke now checks all six live boss fallback PNGs.
- Verification:
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd` PASS
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` PASS
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` PASS
- Disk cleanup: removed `/tmp/fantasydisk_boss_pixellab_refs` and
  `/tmp/fantasydisk_boss_refs_contact.png`.

## Integration Result

2026-07-04:

- PixelLab completed the retry pass as `170x170` 8-direction base objects for
  all six live bosses. The first `256x256` attempt is retained in the manifest
  as failed evidence because PixelLab currently caps 8-direction output frame
  size at `168x168`.
- Imported west-facing 6-frame runtime rows into the current Godot boss
  full-frame contract for `rift_warden`, `disk_devourer`, `bone_archon`,
  `brood_mother`, `ashen_colossus`, and `bloodthorn_lion`: `move`,
  `attack`/`attack_primary`, `death`, two `skill_*` rows and matching
  `attack_*` aliases.
- Added `bloodthorn_lion` to `FullFrameAnimationRegistry` and wired its
  `BloodthornSpikeRing` / rift-zone visuals to request `skill_spike_ring` and
  `skill_rift_zone` rows while preserving gameplay timings, damage, route-pool
  status and boss mechanics.
- Added `tools/import_pixellab_boss_rows.py` to make the PixelLab zip to Godot
  row import reproducible. It normalizes transparent frames to the existing
  `512x512` boss runtime canvas and writes the SpriteFrames resource.
- Preview evidence:
  `docs/design/previews/boss_pixellab_full_redraw_2026_07_runtime_contact.png`.

## Verification

2026-07-04 implementation verification:

- `python3 -m json.tool docs/design/references/bosses/boss_pixellab_full_redraw_2026_07/manifest.json` PASS
- `python3 -m py_compile tools/import_pixellab_boss_rows.py` PASS
- `git diff --check` PASS
- `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` PASS
- `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/full_frame_registry_integrity_test.gd` PASS
- `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd` PASS
- `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` PASS

Implementation result is ready for Jira QA with the PixelLab manifest, runtime
preview and task-owned boss rows committed together. Jira is in
`Готово` after the QA PASSED verdict below.

## QA-Вердикт (2026-07-04, origin/dev @ 96145d2a)
Статус: PASSED

- Commit head: `96145d2ac5beb9a7bfbfb75eeeb9bdd23d245437` on `origin/dev`.
- Scope verified: all six live boss PixelLab full-frame rows load; `bloodthorn_lion`
  registry entry and skill visual states load; boss/elite runtime mechanics still
  pass smoke checks.
- Gates:
  - `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` PASS
  - `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/full_frame_registry_integrity_test.gd` PASS
  - `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd` PASS
  - `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` PASS
- Disk cleanup: removed `build/qa/scrum865_boss_pixellab_full_redraw`;
  no `/tmp/fantasydisk_scrum865*` or `tools/__pycache__` remained; `.godot` in
  the main checkout was retained because an active Godot editor process was open
  on this project.
