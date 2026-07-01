# Back-end Task: SCRUM-779 New Bosses Runtime Integration

Статус: done
Контур: Codex
Owner: claude-backend
Thread: n/a
Locked paths: scripts/boss.gd; scripts/combat_director.gd; scripts/progression_data_enemies.gd; scripts/codex_data.gd; scenes/Boss*.tscn; tests/runtime_smoke_boss_elite_test.gd; docs/design/content_registry.md; docs/design/current_game_state.md; docs/design/systems/enemies_bosses.md
Jira: SCRUM-794

## Autonomy / Approval
Пользователь заранее одобрил in-scope работу. Agents should not ask for routine
confirmation before editing project files, running tests, updating Jira/docs,
committing and pushing task-owned files.

## Context
SCRUM-779 delivered a Design-source boss package:

- Source manifest:
  `docs/design/references/bosses/pixellab_roster_redraw_2026_06/manifest.json`
- New boss concepts:
  - `skeletal_dragon` / Костяной Дракон
  - `bloodthorn_lion` / Шипастый Кровавый Лев
- PixelLab candidates:
  `assets/sprites/bosses/pixellab_candidates/`

SCRUM-779 did not change live boss scenes, boss rotation, balance, Codex unlocks
or route map selection.

## What Back-end Needs To Do
- Decide whether to introduce `skeletal_dragon`, `bloodthorn_lion`, or only one
  of them in the next gameplay pass.
- Add stable boss configs/scenes/mechanics for accepted new boss IDs.
- Add route/boss-pool integration only after mechanics and QA are ready.
- Add Codex discovery entries and meta unlock handling for new boss IDs.
- Keep current boss redraw candidates out of live runtime unless Design/Animator
  promotes them as accepted replacements.
- Update docs and run focused boss/elite runtime smoke.

## Acceptance Criteria
- New boss IDs have scenes, mechanics, unique pattern metadata, Codex entries and
  tests if implemented.
- Boss pool/route selection remains deterministic and does not reference missing
  scenes or assets.
- Current boss roster still passes `runtime_smoke_boss_elite_test.gd`.
- Docs and Jira comments state which SCRUM-779 candidate assets are live versus
  source-only.

## Delivery (SCRUM-794 — claude-backend, 2026-07-01)

**Decision:** introduced ONE new boss this pass — `bloodthorn_lion` (best-rated
new-boss candidate per manifest QA note "strong predatory blood-spike silhouette;
good single-view first-pass candidate"). `skeletal_dragon` stays source-only
("needs more epic boss mass before final runtime").

**Live vs source-only assets:**
- LIVE: `assets/sprites/bosses/boss_bloodthorn_lion.png` — promoted from the
  single-view candidate `assets/sprites/bosses/pixellab_candidates/bloodthorn_lion/bloodthorn_lion_pixellab_alpha.png`
  (upscaled 256→512 nearest to match the 512px live-boss pipeline).
- SOURCE-ONLY (unchanged, NOT in runtime): `skeletal_dragon`, `bloodthorn_lion_8dir`,
  and all `current_boss_redraw` / `special_boss_redraw` candidates under
  `assets/sprites/bosses/pixellab_candidates/` and the SCRUM-779 manifest.

**Wired end-to-end:**
- Scene `scenes/BossBloodthornLion.tscn` (boss.gd, `boss_behavior = "bloodthorn_lion"`).
- Unique behavior in `scripts/boss.gd`: dash-pounce + radial thorn burst + bleed
  rift-zones; unique mechanic `_spawn_bloodthorn_spike_ring` → `BloodthornSpikeRing`
  node (telegraphed nova + belt of thorn zones with a safe corridor).
- `UNIQUE_ENCOUNTER_PATTERNS["bloodthorn_lion"]` in `scripts/progression_data_enemies.gd`
  (4 mechanics) → drives `unique_pattern_id` / `unique_mechanics` meta.
- `CombatDirector._boss_scene_for_id` resolves `bloodthorn_lion`
  (`scripts/combat_director.gd`).
- Codex boss entry in `scripts/codex_data.gd` (4 abilities, live sprite).
- Test `_test_bloodthorn_lion_boss` in `tests/runtime_smoke_boss_elite_test.gd`;
  codex-count invariant bumped 5→6 bosses in `tests/runtime_smoke_test.gd`.

**Deferred (per staged AC "route/boss-pool integration only after mechanics and
QA are ready"):** `bloodthorn_lion` is intentionally NOT in the random route pool
`route_map_screen._random_boss_route_node`. The regression test asserts it stays
OUT of that pool until a QA-gated rotation follow-up. Route selection therefore
remains the deterministic 5-boss set and references no missing scenes/assets.
Full-frame animation rows for `bloodthorn_lion` are an Animator follow-up (live
scene uses the static sprite, mirroring the pre-animation state of siblings).

**Green-gate:** `tests/runtime_smoke_boss_elite_test.gd` PASSED and
`tests/runtime_smoke_test.gd` PASSED (EXIT=0) via `tools/godot_gate.py`
(Godot 4.7, FSD_GODOT_SLOTS=1).

Статус: done
