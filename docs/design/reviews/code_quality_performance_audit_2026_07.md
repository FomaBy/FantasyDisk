# FantasyDisk code quality / Windows performance audit — FAN-1040

Дата: 2026-07-13

Baseline: `origin/dev@1190db1d1de10ab90e21d2cdea32be908efbeada`

Scope: runtime GDScript, resource/cache hot paths, tests/tooling, release/process
contracts, security review. Balance scope FAN-1028/FAN-1031, UI redesign, art and
animation generation were intentionally excluded.

## Executive summary

Three independent read-only passes reviewed Windows/performance, architecture,
and QA/process. The baseline was green, but it had one critical client secret,
no enforceable CI, no native Windows performance evidence, and several credible
stutter sources. FAN-1040 applies only high-confidence changes which preserve
gameplay semantics, adds a basic static GitHub Actions gate, and creates
dedicated follow-ups for work that needs native profiling, external
administration, branch protection or wider architecture.

This audit does **not** claim a measured Windows FPS improvement. It removes
specific synchronous loads and repeated allocations/scans; a measured claim
requires the native Windows benchmark tracked by FAN-1042.

## Fixed in FAN-1040

### P0 — embedded Discord credential

Evidence: `scripts/feedback_reporter.gd` reconstructed a production Discord
webhook from Base64 chunks and explicitly described evading scanners. Base64 is
reversible, so every source checkout and player build exposed the credential.

Fix:

- removed the built-in credential and fail-open fallback;
- configuration now fails closed to local `user://feedback` storage;
- added client-source secret scan to `tools/quality_gate.py`;
- updated config test, release message and feedback documentation;
- created FAN-1041 for external revocation and a rate-limited server-side proxy.

Residual: current-source removal cannot revoke the webhook and cannot erase it
from existing Git history/builds. Discord revocation is mandatory.

### P1 — first-use Engineer resource loads during combat

Evidence: `_fire_engineer_sentry_link`, `_fire_engineer_orbit_drone` and
`_spawn_engineer_pressure_mine` synchronously loaded known scene/scripts on the
first combat use.

Fix: `scripts/class_weapon.gd` now preloads the turret scene, orbit-drone script
and mine script. Deploy behavior, caps, damage and timing are unchanged.

### P2 — repeated group allocations in enemy separation

Evidence: every enemy refresh called `get_nodes_in_group("enemies")`; with N
enemies this created N group arrays per separation cycle in addition to the
existing O(N²) distance comparisons.

Fix: `_refresh_separation_neighbors()` reuses the per-frame
`CombatTargetQuery.enemies()` snapshot. The four-neighbor algorithm, cadence,
stagger, weights and radii are unchanged. A future spatial grid remains in
FAN-1042 because it needs a result-equivalence/performance benchmark.

### P2 — threat indicator scans and duplicates every draw

Evidence: every rendered frame scanned `bosses`, `elite_enemies` and `enemies`;
bosses/elites are also enemies, creating duplicates and three arrays before
filtering.

Fix: relevant threat candidates refresh at 10 Hz from the shared enemy snapshot;
positions are still transformed/drawn every frame for smooth movement. New
`tests/hot_path_cache_test.gd` verifies relevant-only candidates, no duplicate
instances, and same-frame query reuse.

### P1 — non-portable/incomplete validation

Evidence:

- `tools/godot_gate.py` imported POSIX-only `fcntl` unconditionally and used
  `/tmp` plus a hard-coded macOS Godot path;
- `tools/run_focused_tests.sh` discovered only direct `extends SceneTree` files:
  213 of 233 baseline tests, missing 20 inherited UI/gamepad/runtime suites;
- test processes shared user data and bypassed the repository semaphore.

Fix:

- `godot_gate.py` now uses `fcntl` on POSIX and `msvcrt` on Windows, the OS temp
  directory, `GODOT_BIN`/`GODOT`/PATH discovery and testable helpers;
- new `tools/quality_gate.py` discovers direct and inherited suites, isolates
  HOME/XDG/AppData/`user://`, routes every run through the semaphore, detects
  fatal script diagnostics and emits JSON evidence;
- changed selection includes modified/untracked test scripts automatically and
  falls back to the umbrella for unmapped runtime/scene changes; filtered or
  skipped runs are recorded as non-certifying `partial_pass`, while an empty
  run is rejected;
- per-test/process timeouts terminate the full process group; `godot_gate.py`
  also enforces a configurable timeout for direct test/import/export commands;
- the old shell command is a compatibility wrapper around the Python runner;
- Python regression tests cover discovery (236 suites after FAN-1040), lock
  behavior, executable precedence and client secret scanning;
- the repo-local `fantasydisk-code-quality-director` skill makes the evidence,
  profile selection, synchronous landing and independent-QA workflow mandatory.

### Additional correctness/hot-path hardening integrated from concurrent FAN-1040 work

- Bastion taunt target selection reads one scalar status value instead of
  deep-copying every active status each physics tick.
- DoT signature introspection runs only when a damage tick is actually due;
  expired status/marker metadata is cleaned deterministically.
- Wave-pack spawn keeps a local remaining-cap counter instead of rescanning the
  whole enemy group after every spawned enemy.
- Run autosave uses a temporary file plus backup/rollback, so a failed replace
  cannot destroy the last good checkpoint; completion cleanup checks deletion
  errors and removes `.tmp`/`.bak` before the primary checkpoint.
- Shared `SceneContracts` validates configurable Node2D scene roots at primary
  enemy/elite/boss/pickup/summon boundaries.
- Static architecture ratchets prevent further growth of existing god-files and
  new scripts above the reviewed ceiling.

## Confirmed risks deferred with explicit owners

### FAN-1042 — native Windows performance and high-cost runtime changes

1. `full_frame_animation_registry.gd` synchronously loads first-seen SpriteFrames
   while `combat_director.gd` can spawn a multiplied pack in one frame.
2. `main.gd`/UI/combat owners retain large full-screen lossless textures without
   a session bound; backgrounds/UI consume hundreds of MiB compressed on disk
   and potentially much more resident.
3. Combat hits create Labels, Sprite2D, CanvasItemMaterial, tweens and group scans;
   157 AttackVfx call sites amplify churn during AoE/DoT.
4. `get_method_list()` reflection remains in several hit paths; the previous
   every-physics-frame DoT reflection was fixed in this pass.
5. Animation resolution allocates arrays/strings and writes metadata for every
   animated enemy frame.
6. Ally targeting and the remaining separation algorithm need a shared spatial
   index, not independent full-list nearest-neighbor scans.

Required order: native baseline → threaded prewarm/spawn spreading → bounded
large-texture ownership → pooled/aggregated feedback/VFX → reflection/state
caches → spatial index. Renderer/import changes require visual and GPU-vendor A/B.

### FAN-1043 — enforceable CI / exact merge candidate

A basic `.github/workflows/quality.yml` now runs the certifying static profile on
push/PR. It is not yet a required full Godot/native-Windows exact-merge check.
`.githooks/post-commit` can still test the task SHA, create and push a different
merge SHA in a detached process, and offers a skip flag. FAN-1043 therefore
still owns task branches, required exact-merge checks, branch protection, merge
queue, Windows-native correctness and scheduled performance.

### FAN-1044 — atomic Jira-to-Multica process cutover

The live runtime/workspace uses Multica, while root onboarding, README, QA/version
docs and scheduled worker skills still declare Jira authoritative. A partial
wording change would leave split ownership, so FAN-1044 owns one atomic cutover
and clean-clone verification. FAN-1040 adds the quality skill/gate but does not
silently rewrite historical task evidence or Jira automation.

### FAN-1041 — feedback delivery security/lifecycle

Besides external credential revocation/proxy delivery, the feedback reporter has
one mutable pending request and the UI callback can outlive a cancelled overlay.
The server/proxy change must include request identity, concurrent-submit policy,
weak UI lifecycle handling and delayed completion tests. This touches the UI
ownership boundary and therefore is not mixed into the secret-removal patch.

### Additional architecture debt

- `scripts/ui_screens.gd` is 16,978 lines, `class_weapon.gd` 5,950,
  `player.gd` 4,256, and umbrella `runtime_smoke_test.gd` 9,260. Migrate one
  complete bounded component at a time; do not perform mechanical file splits.
- Delayed enemy/boss hazard callbacks capture the caster after the caster can be
  freed. Move payload/lifecycle to hazard-owned scripts with delete-before-timeout
  tests after the active combat scope is released.
- `Player.CHARACTER_CONFIGS` visual fallback keys drift from the canonical
  registry (Soldier missing). Rename it to express visual-only ownership and add
  canonical-key coverage in a focused follow-up.
- `tools/run_balance_validation.sh` defaults to `origin/dev`, uses a fixed shared
  worktree and incomplete fatal-pattern scanning; it must validate exact HEAD in
  unique scratch state before being called an enforcement gate.
- release builds overlay current build files onto a tagged worktree, so artifacts
  are not a pure function of tag SHA. Release infrastructure should be versioned
  in the tag or record both approved SHAs.

## Quality profiles

```bash
python3 tools/quality_gate.py --profile changed --changed-ref origin/dev
python3 tools/quality_gate.py --profile full
python tools/quality_gate.py --profile windows  # native Windows only
```

`changed` runs static/security checks plus diff-selected domain tests and core
combat/UI smoke. `full` discovers all leaf/inherited suites plus the umbrella.
`windows` refuses to run on macOS/Linux so a cross-export cannot masquerade as
native evidence. Reports are written to `build/quality_gate_report.json`.

## Verification evidence

Baseline before edits:

- Python unittest discovery: 13 passed;
- `combat_target_query_cache_test.gd`: passed;
- `enemy_separation_behavior_test.gd`: passed;
- `runtime_smoke_ui_test.gd`: passed;
- constellation/runtime-manifest mutation validators: passed.

Final combined changed-profile from baseline `1190db1d`:

- 12 static/security/export-config/whole-range whitespace checks passed;
- 14 diff-selected Godot suites passed, including target/separation/hot-path
  caches, Engineer kit, feedback, persistence, scene contracts, status effects,
  combat/UI split smoke and the umbrella `runtime_smoke_test.gd`;
- skill structure validation: passed;
- discovery audit: 236/236 current GDScript suites selected by `full` profile.

The entire 236-process `full` profile was not executed during this macOS pass;
the umbrella plus all changed-domain gates were. Native Windows `windows` and
performance profiles remain acceptance work for FAN-1042/FAN-1043.

## Review conclusion

The safe portion of the review is implemented and regression-gated. Remaining
high-impact work is no longer an unstructured “optimize the game” request: every
risk has an evidence path, sequence, acceptance contract and live Multica child
issue. Independent QA must review the final diff and exact test evidence before
FAN-1040 can close.
