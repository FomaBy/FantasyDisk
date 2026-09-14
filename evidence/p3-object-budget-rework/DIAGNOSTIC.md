# FAN-3934 P3 object-budget breach — diagnostic report

Read-only diagnosis by dev_high agent `11dd50f9-2322-4aa0-a09e-631e1159c1df` (macOS-native).
Candidate under diagnosis: `d192be10bbe52dd89971cab0acc66eb92ccab37f` (same commit FAN-3877 measured).
No production, helper, test or configuration file was modified; all task output lives in
`evidence/p3-object-budget-rework/**` (`git status` shows only this untracked directory).

## 1. Environment

- Host: MacBook-Pro-Sergey, Apple M4 Pro, macOS 26.5.1 (25F80) — the same host class FAN-3877 used.
- Engine: Godot 4.7.stable.official.5b4e0cb0f (`/Applications/Godot.app`), gl_compatibility / OpenGL Metal, windowed 2560x1440 logical viewport (project default).
- Every Godot invocation went through `tools/godot_gate.py` admission.
- Scenario: exact FAN-3877 P3 reproduction — `fight boss`, `godmode`, `timer 3600`, `spawn_cooldown 3600`, berserk/axe, per-second reinforcement, one accepted ultimate activation out of 18 attempts (matches the original run), 12 s warm-up + 60 s sample. Boss: `rift_warden` (default `current_boss_id`), scene `scenes/BossWarden.tscn`, `boss_summon_scene = scenes/EnemyBiter.tscn`.
- Seed: none available (runtime uses `randf`); each variant is an independent 60 s sample.
- Instrumentation overhead: the attribution probe samples the same Performance monitors as the original FAN-3877 probe each frame plus one full-tree node census (~350 nodes) per second; the census is a pure read with negligible allocation (no new Objects kept alive). Object counts are workload-counting, not timing claims.
- Competing workload disclosure: during the later diagnostic runs other agents' Godot processes (ultimate presentation capture tests) were observed on this host. Object-count monitors are insensitive to host load, and the reproduced peaks (4,558/4,597) match the FAN-3877 breaches (4,411/4,610) measured on an idle host; no FPS/memory claims are made from the shared-host runs. Decisive post-fix validation will use the gate's exclusive mode.

## 2. Baseline breach reproduced

| Run | Peak objects | Cap | Result |
|---|---:|---:|---|
| FAN-3877 run 1 | 4,411 | 4,000 | FAIL |
| FAN-3877 run 2 | 4,610 | 4,000 | FAIL |
| FAN-3934 attribution `full` | 4,558 | 4,000 | FAIL (reproduced) |
| FAN-3934 census `full` | 4,597 | 4,000 | FAIL (reproduced) |

Node count peaks at only ~340 while object count peaks at ~4,600: the object population is
~92% non-Node Objects (resources, Tweens, Tweeners, materials). Orphans stay 0 and series are
non-monotonic — confirmed steady-state cap breach, not a leak.

## 3. Allocation attribution (12 s warm-up + 60 s samples)

Runtime ablations steer the boss script's exported attack-interval properties to 1e9
(no production edits). `summoned_enemies` cap (SCRUM-596 `MAX_SUMMONED_RIFTLINGS = 8`) and all
other thresholds untouched.

| Variant (ablated) | Mean objects | Peak | Peak nodes | Steady enemies |
|---|---:|---:|---:|---:|
| `full` (exact repro) | 4,109 | 4,558 | 342 | 8–10 |
| `no_volley` (radial/targeted bursts off) | 4,086 | 4,540 | 309 | 10 |
| `no_rift` (rift zones + zone waves off) | 4,119 | 4,520 | 328 | 10 |
| `no_unique` (gravity well off) | 4,147 | 4,618 | 345 | 10 |
| `no_summon` (riftling summoning off) | 3,584 | **3,779** | 226 | 2 |
| `no_attacks` (all boss attacks off) | 3,501 | **3,569** | 154 | 2 |

Isolated micro-measurements (8 instances, headless):

- One `EnemyBiter` (riftling) instance costs ~8 live objects (~7 nodes + 1 RefCounted
  `EnemyAnimationPriority`); its `FullFrameBody` AnimatedSprite2D shares the cached
  `small_biter_spriteframes.tres` (40 animations / 184 frames / 369 objects loaded once,
  then cached — second `load()` adds 0 objects).
- Freeing the FullFrameBody subtree appears to free ~47 objects/instance only because the
  shared 369-object SpriteFrames loses its last holders — an attribution artifact, not
  per-instance cost.

Per-second full node census (`attribution/census_full.json`):

- Persistent floor: with every boss attack disabled the fight still holds ~3,500 objects
  (menu contour P1 peak is 2,716 — combat loading adds ~800 persistent resources).
- The object count at any instant is 3,700–4,260 non-Node objects; the ±400–600/second
  fluctuation is transient VFX/feedback churn, top correlating owners: `CombatHitTick`,
  `SlashVfx`, `BerserkAxeCleaveVfx`, `AxeGhost`, `WeaponSignature*` (player axe feedback)
  and `HazardTelegraph`/`HazardBurst` (boss zones).

## 4. Causal model

1. Structural floor (~3,500 objects): loaded resources for the combat scene, entities and HUD.
   Alone it consumes 87.5% of the 4,000 budget.
2. Riftling population at the gameplay cap (8): each riftling is cheap persistently (~8
   objects) but multiplies player-feedback churn — cleaving a grouped summon pack keeps
   ~600 extra transient feedback objects alive on average (mean 4,109 vs 3,584/3,501).
3. Transient spikes (+400–600 above mean): every hazard telegraph, hit tick, damage tick and
   axe-swing ghost builds fresh Tweens/Tweeners and, critically, a fresh
   `CanvasItemMaterial.new()` per additive sprite (`hazard_vfx.gd:_additive`,
   `enemy.gd:_show_hit_flash` tick material, dot ticks) and per-event feedback nodes.
   Cadence coincidence of zone waves, volleys and cleaves produces the 4,558–4,610 peaks.

No single leak and no responsible production call site was established beyond the above:
the breach is the sum of a tight structural floor plus uncapped-rate transient feedback
allocation against the capped summon population.

## 5. Proposed bounded fix (subject to supporting-scope approval)

Reduce transient allocation churn with zero visual/gameplay change:

- Share one static additive `CanvasItemMaterial` (blend mode ADD) instead of
  `CanvasItemMaterial.new()` per sprite in `scripts/hazard_vfx.gd` (`_additive`) and
  `scripts/enemy.gd` (`_show_hit_flash` tick material, dot-tick material).
- Consolidate the per-telegraph tween tree in `scripts/hazard_vfx.gd:telegraph`
  (grow + looping pulse + urgent-pulse replacement tween: ~3 Tweens + ~7 Tweeners per
  telegraph) into fewer tween objects with identical visible timing.
- If measured shortfall remains, extend the existing SCRUM-611 feedback group-cap pattern
  to damage-number labels (`scripts/enemy.gd` floating label/marker) — cap concurrent
  instances, not events.

Invariants: identical textures, colors, blend modes and timings; no change to
`MAX_SUMMONED_RIFTLINGS`, `COMBAT_FEEDBACK_MAX_FLASHES`, hazard radii/windups, combat
balance, caps or budgets; P2 (48 enemies, ≤5,000) and P1 (≤400 MiB) unaffected or improved.

## 6. Files

- `attribution/*.json|csv` — per-variant monitor series and node censuses (raw).
- `census_full.json` — per-second node census of the exact P3 reproduction.
- `probe/*.gd` — the three read-only diagnostic probes (SceneTree scripts, task-owned).
- `raw-baseline/` — untouched FAN-3877 evidence archive (SHA-256
  `bdbecb8a3bc349e835ff7af49e05d4c19e7e76167404369adbc03c19c30ca0be`, verified) and its
  extracted contents, plus the original probe for reference.
