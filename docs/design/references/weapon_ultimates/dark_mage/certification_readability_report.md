## Dark Mage ultimate certification readability report

FAN-3938 captured the shipped Dark Mage runtime at all 48 weapon/mode/viewport
cells and at each class-declared release, active, and recovery beat: 144
standalone native PNGs in total. Each file is one full framebuffer readback;
there is no tiled contact sheet, scaling trick, painted HUD, synthetic player,
or synthetic hazard layer that could obscure a 648p cell boundary.

### Capture provenance

- Harness source ref: `agent/codex-dev-terra-a/c1f1525cda9e`
- Pre-artifact source commit: `7c682b2be8d8a17bbf534f23fe13f2a5073dd45d`
- Pre-artifact source tree: `827ca032eb1c1c18e58a62269f69a944c0c6bcbf`
- Engine: Godot `4.7-stable (official)`; renderer `gl_compatibility` on Apple
  M4 Pro / macOS.
- Controlled seed: `393820260910`, with a deterministic per-cell derived seed
  for the real Main RNG and global RNG.
- Runtime route: persisted `user://settings.cfg` → `Main` accessibility
  snapshot → `_start_combat` → real `current_player.activate_ultimate()` →
  shipped Dark Mage driver → native window framebuffer.

The capture source intentionally precedes the final PNG/manifest artifact
commit. PNG hashes identify the hydrated review assets; raw RGBA hashes identify
the in-run framebuffer. Fixed 60 FPS and per-cell seeds make the route
replayable on this platform, but Metal/GPU raster bytes are not claimed to be
identical across GPU or driver versions.

### Matrix and runtime state

The companion manifest records the hash, LFS object ID, path, exact scene,
native width/height, persisted settings, and observed driver/HUD/hazard/artwork
state for every file.

| Dimension | Frames | Live state |
| --- | ---: | --- |
| 1152×648 | 36 | One unscaled gameplay frame per weapon, mode, and named beat |
| 1280×720 | 36 | Same production Main/HUD/player/enemy route |
| 1920×1080 | 36 | Same production Main/HUD/player/enemy route |
| 2560×1440 | 36 | Same production Main/HUD/player/enemy route |

Modes are not test-side visual substitutes. `normal` and `crowded` persisted
both accessibility keys as false; `crowded` then placed 39 real
`Main.combat._spawn_random_enemy` hazards. `reduced_motion` persisted
`ultimate_reduced_motion=true` and confirmed the driver's
`ultimate_reduced_motion` timeline. `photosensitivity_safe` persisted
`ultimate_photosensitivity_safe=true` and confirmed the driver's live
photosensitivity flag and original timeline with its shipped luminance cap.
Each frame also confirms `CombatHudRoot`, a configured Dark Mage Player, and
visible director-spawned Enemy hazards.

### Readability observations

- **Abyss Mirror / dark_book:** release shows the authored mirror and paired
  reflections; active retains the opposing reflections around the mirror plane;
  recovery preserves the readable violet mirror signature while the scene exits.
- **Cursed Crown / cursed_skull:** release truthfully requires the authored
  crown only—the soul orbits are intentionally still transparent at that beat.
  Active and recovery show the crown with both visible SoulOrbit sprites, so the
  coronation and transfer/harvest language remain inspectable.
- **Vanishing Thread / dark_wand:** release shows the primary thread; active
  shows the primary thread plus the authored near echo at the real `1.45s`
  active phase; recovery includes both echoes, making the contraction path
  inspectable rather than using an early pre-active substitute.

Across the matrix, every stored observation has a non-empty framebuffer
luminance range (minimum recorded threshold `0.04`), visible authored Dark Mage
nodes appropriate to the phase, a visible shipped HUD, and one or more real
Enemy hazards. This establishes temporal scene evidence without relying on
runner-drawn color probes.

### Commands

```sh
FSD_GODOT_EXCLUSIVE=1 \
  DARK_MAGE_CERT_SOURCE_REF=agent/codex-dev-terra-a/c1f1525cda9e \
  DARK_MAGE_CERT_SOURCE_SHA=7c682b2be8d8a17bbf534f23fe13f2a5073dd45d \
  DARK_MAGE_CERT_SOURCE_TREE=827ca032eb1c1c18e58a62269f69a944c0c6bcbf \
  python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 \
  --script res://tests/ultimates/presentation/dark_mage_certification_live_capture.gd

python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/dark_mage_certification_capture_test.gd
```

The integrity gate fails closed for missing mode or settings keys, missing
files, unsmudged LFS pointers, malformed hashes, wrong native dimensions,
unregistered paths, duplicate capture keys, and absent release/active/recovery
observations. It verifies the hydrated files instead of treating a headless
capture skip as visual proof.

### Windowed accessibility-runtime recovery

The prior independent QA run on the earlier candidate was inconclusive because
its windowed accessibility-mode command stayed silent until the outer 3600-second
gate intervened. Recovery isolated the stall to the test harness after the
first `dark_book/normal` cell: `frame_post_draw` stopped arriving while the
SceneTree continued advancing fixed simulation ticks. Under `--fixed-fps`, a
`SceneTreeTimer` is simulation-time rather than a wall-clock deadline, so its
nominal two-second watchdog expired in 40–51 ms of elapsed wall time.

The recovery is limited to
`tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd`; no player,
ultimate, renderer, shared helper, or other-class code changed. Its test-only,
process-always watchdog now uses monotonic `Time`, arms `frame_post_draw`, and
requests `RenderingServer.force_draw(false)` only after the listener is armed.
A successful luminance sample therefore still follows a completed real native
window draw. If neither route completes, the watchdog records the exact
cell/stage/display/renderer and ordinary per-cell cleanup continues; a separate
180-second gate remains the fail-closed diagnostic for a complete engine freeze.

The corrected source was exercised before this evidence update:

- Harness source commit: `afcef6f4cdbd3a1851c43ec0a34f6708ac3ae841`
- Harness source tree: `9ee1e0c64cb9aee070e48aa7469d04f9df597304`
- Environment: Godot `4.7-stable (official)`, `gl_compatibility`, macOS;
  `render_loop_enabled=true`.
- Result: `dark_mage_accessibility_modes_test: PASS (12 cells, windowed)` in
  33.157 seconds. All 12 real production cells completed their assertions and
  cleanup, restored persisted settings, and recorded 1,272 framebuffer
  luminance samples with zero watchdog diagnostics or timed-out cells.

```sh
FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=180 \
  DARK_MAGE_ACCESSIBILITY_REPORT=<path> \
  python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 \
  --script res://tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd
```

### Limits

These are still images, not a substitute for audio or continuous-motion review.
The three named beats record representative release, active, and recovery
states; they do not claim every in-between frame. The visual review must still
be performed by the independent qa_high reviewer at the exact candidate, and
the legacy timeline sheets remain separate historical evidence.
