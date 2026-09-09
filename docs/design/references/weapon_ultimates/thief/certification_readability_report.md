# Thief weapon-ultimate certification readability report (FAN-3941)

Independent-review evidence for the Thief ultimate trio (`thief/thief_coin_pouch`, `thief/thief_shadow_cloak`, `thief/thief_smoke_bomb`) in the four presentation modes at the four supported viewports. Every frame is a real render of the shipped `scenes/vfx/ultimates/thief/*.tscn` timeline scene driven through its `begin()`/`step()` runtime path, composed with the hero, hazards, a crowd and the real ultimate HUD widget at the on-screen scale the game uses. This card also normalises the Thief class manifest (per-weapon direction fields, frozen `phase_ids`, `generator_provenance`, `evidence.capture_script`) so the shared visual-direction contract reads it like every other class package.

## Provenance

- Source ref/commit/tree the shipped scenes were rendered from: `dev` / `d192be10bbe52dd89971cab0acc66eb92ccab37f` / `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf`. Integrated origin/dev revision whose shipped Thief scenes, pack and assets were rendered; the capture tooling, frames and this manifest are added by FAN-3941 on top of it and change no production scene.
- Engine: Godot 4.7-stable (official) (gl_compatibility, opengl3, Apple M4 Pro), macOS 26.5.1, display server macOS, captured 2026-09-09 03:02:13 UTC.
- Renderer: `tests/ultimates/presentation/thief_certification_live_capture.gd`; gate: `tests/ultimates/presentation/thief_certification_capture_test.gd`; capture manifest: `docs/design/references/weapon_ultimates/thief/certification_capture_manifest.json` (every frame path, size, byte count and sha256).
- Capture command: `FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --script res://tests/ultimates/presentation/thief_certification_live_capture.gd`
- Gate command: `python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/thief_certification_capture_test.gd`
- Seed: 3941 (seed() is set for completeness; the capture path draws no random value (no camera exists for the shake device, the crowd is a fixed grid and the impact ripple is distance-ordered).)
- Exclusive process admission during the committed run: no. Exclusive admission (`FSD_GODOT_EXCLUSIVE=1`) waited behind another agent's live P3 measurement run on this host; a frame here is a fixed-step deterministic render with no time-dependent quantity, so the committed run used the shared slot admission of `tools/godot_gate.py` and the manifest records `exclusive_gate: false` truthfully.
- On-screen scale: logical canvas 2560x1440 with `canvas_items` stretch and combat camera zoom 1.12; hero at Player visual scale 0.64; HUD widget `res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn` at the UI scale of each viewport with state from ultimate_hud_view_model.gd build() of tests/ultimates/hud_fixture_library.gd weapon_profile_snapshot(class, weapon) with charge fraction 1.0, active true and keyboard input.
- Method: Each frame is a SubViewport at the exact viewport size: floor, two striped hazards, the hero full frame at the Player combat scale, a crowd grid at the declared crowd cap (crowded), the shipped scene instantiated and driven with begin()/step() in fixed 1/120 s steps to the beat and held, the weapon's victim-impact flipbook on the crowd (crowded), the real UltimateHudWidget fed a registry snapshot, and a caption band with mode/weapon swatches. The scene is placed at the game's on-screen scale (viewport_height / 1440 * combat camera zoom 1.12) and never fitted. Opaque coverage is measured on a scene-only transparent render of the same composition (alpha >= 0.5, stride 2). The Thief scenes author no arena-wide surface, so the photosensitivity-safe variant is the shipped scene with the screen_shake toggle off (the gate counts full-screen surfaces and requires zero); reduced motion applies the shipped screen_shake toggle on the tree root.

## Coverage

- Weapon x mode x viewport combinations: 48 (3 canonical weapons x 4 modes x 4 viewports), every one committed as a native-size frame at the active beat.
- Frames committed: 72 of 72 expected (midpoint of the declared phase window; the active beat is committed at every viewport, release and recovery at 648p).
- Modes: `normal` (crowd none, screen_shake on, backdrop veil kept, victim impacts off); `crowded` (crowd declared crowd_cap per weapon, screen_shake on, backdrop veil kept, victim impacts on); `reduced_motion` (crowd none, screen_shake off, backdrop veil kept, victim impacts off); `photosensitivity_safe` (crowd none, screen_shake off, backdrop veil suppressed/none, victim impacts off).
- Viewports: `648p` 1152x648 (scene scale 0.504, UI scale 0.45), `720p` 1280x720 (scene scale 0.56, UI scale 0.5), `1080p` 1920x1080 (scene scale 0.84, UI scale 0.75), `2k` 2560x1440 (scene scale 1.12, UI scale 1.0).

## Measurements

| Weapon | Declared max_viewport_coverage_ratio | Measured peak opaque coverage (frames + full-envelope sweep) | Sweep | Full-screen surface / flash | Declared flash (Hz / coverage) |
|---|---|---|---|---|---|
| `thief/thief_coin_pouch` | 0.01 | 0.0043 (peak at 2.57 s) | 92 samples every 0.0333 s over 3.05 s at 648p normal | none authored (gate counts zero full-screen surfaces); no element alpha rises more than once per cast | 0.0 / 0.0 |
| `thief/thief_shadow_cloak` | 0.01 | 0.0033 (peak at 2.6 s) | 97 samples every 0.0333 s over 3.2 s at 648p normal | none authored (zero full-screen surfaces); no element alpha rises more than once per cast | 0.0 / 0.0 |
| `thief/thief_smoke_bomb` | 0.01 | 0.0014 (peak at 2.13 s) | 103 samples every 0.0333 s over 3.42 s at 648p normal | none authored (zero full-screen surfaces); no element alpha rises more than once per cast | 0.0 / 0.0 |

Opaque coverage counts pixels at alpha >= 0.5 on a scene-only render sampled at stride 2 at the game's on-screen scale. The Thief timeline scenes author only their sprite formation: no backdrop veil, no camera-shake device, no hero pose. The gate proves the zero full-screen surface count on every driven scene and reads the pack's own formation envelope at 240 Hz for element alpha rises, so the declared 0.0 Hz / 0.0 flash values are the scene's numbers, not a claim. The smoke dome is translucent (alpha 0.46-0.74), so its opaque count understates a visual footprint of about 230 px at 2560x1440.

## Observed readability at release, active and recovery

### `thief/thief_coin_pouch`

Beats sampled: release 0.9 s, active 1.7 s, recovery 2.68 s (declared timing {"windup": 0.0, "release": 0.7, "active": 1.1, "recovery": 2.3, "cancel": 3.05}).

- **release** — The coins have left the pouch seed and sit at 35 % of their targets (~70 px cluster at 648p); the gold plate reads as a scatter of pouches, the hero column, HUD and hazards are untouched.
- **active** — Thirteen coins hop between their target glints across a ~120 px band at 648p (~270 px at 2K); each plate is above the 6 px readability floor at every viewport.
- **recovery** — The coins return inward and scale up toward the crown burst (~105 px cluster at 648p, alpha fading to ~0.7); the read is a closing gold cluster.
- **crowded** — Thirteen crowd members at the declared crowd cap; the nearest three carry the coin-pouch impact burst (the weapon's own flipbook) in the committed first wave; the formation stays inside its zone and every crowd disc remains readable.
- **reduced motion** — Identical formation and timing to the normal frame (the gate proves formation-signature equality); the shipped `screen_shake` toggle is off and the scene authors no shake device, so nothing else changes.
- **photosensitivity-safe** — Motion off; the scene authors no full-screen surface (the gate counts zero), so there is nothing to suppress and the frame equals the reduced-motion frame by construction.

### `thief/thief_shadow_cloak`

Beats sampled: release 1.02 s, active 1.9 s, recovery 2.89 s (declared timing {"windup": 0.0, "release": 0.82, "active": 1.22, "recovery": 2.57, "cancel": 3.2}).

- **release** — Eight marks fan out on the ellipse at ~85 px across at 648p with the first stabs arriving; the violet plate is dim (alpha rising from 0.28) and small at 648p, readable at 1080p and 2K.
- **active** — Sequential phantom backstabs pulse on their marks across a ~170 px ellipse at 648p; the arriving stabs are bright, the others hold at ~0.26 alpha.
- **recovery** — The marks collapse toward the centre at ~0.5 alpha (~78 px at 648p); the read is a dim inward pull, intentionally fading.
- **crowded** — Thirteen crowd members at the declared crowd cap; the shadow-cloak impact burst lands on the nearest members; the ellipse of marks reads between the crowd rows.
- **reduced motion** — Identical formation and timing to the normal frame; the toggle is off and no shake device exists in the scene.
- **photosensitivity-safe** — Motion off; zero full-screen surfaces; frame equals the reduced-motion frame by construction.

### `thief/thief_smoke_bomb`

Beats sampled: release 1.14 s, active 2.09 s, recovery 3.13 s (declared timing {"windup": 0.0, "release": 0.94, "active": 1.34, "recovery": 2.84, "cancel": 3.42}).

- **release** — The dome is expanding (~110 px at 648p) with the six pressure marks drifting outward; the blue-grey plate is translucent and reads as smoke rather than as an opaque disc.
- **active** — The dome holds at ~135 px at 648p (~230 px at 2K) with the marks at its rim; the hero column, HUD and hazards are untouched and the translucent dome keeps the floor visible through it.
- **recovery** — The dome grows to ~160 px at 648p while fading toward zero alpha (measured opaque coverage 0.0000); the snap collapse is read as the fade-out.
- **crowded** — Thirteen crowd members at the declared crowd cap; the smoke impact burst lands on the nearest members; the translucent dome does not hide the crowd discs behind it.
- **reduced motion** — Identical formation and timing to the normal frame; the toggle is off and no shake device exists in the scene.
- **photosensitivity-safe** — Motion off; zero full-screen surfaces; frame equals the reduced-motion frame by construction.

## Probe results recorded on every frame

- HUD band contrast ratio (share of band samples at luma delta >= 0.25 against the band background; floor 0.004): min 0.0127, max 0.0167.
- Hero contrast ratio (share of the drawn hero pixels at luma delta >= 0.15 against the floor; floor 0.15): min 0.2713, max 0.2774.
- Hazard stripe contrast against the floor (floor 0.15, warm hue required): min 0.613, max 0.613.
- Effect inside the effect zone on every frame: True; mode and weapon swatches verified on every frame: True.
- The gate recomputes every one of these numbers from the committed PNGs and fails closed on a missing, pointer-only, wrong-size, wrong-hash, unreadable or off-spec frame.

## Limitations

- The Thief class manifest declares `presence` devices (darken backdrop, camera shake, 100 ms hitstop, 0.4 time-scale dip) and a crouched-toss cast pose, but the shipped timeline scenes author only the sprite formation: no backdrop veil, no camera-shake device, no hero pose node, and no shared runtime consumer of those presence fields exists outside the schema. The reduced-motion and photosensitivity-safe variants are therefore identical to the normal frame by construction; this package records that and changes no production scene.
- At the game's true on-screen scale the Thief formations are small at 1152x648 (coin band ~120 px, stab ellipse ~170 px, dome ~135 px); the plates stay above the 6 px readability floor the FAN-1470 test holds at every supported height.
- The release and recovery beats are committed at 1152x648 and the active beat at all four viewports; the manifest records coverage and readability probes for every committed frame and the full-envelope sweep for the peak.
- Victim impacts are the weapon's flipbook played on the crowd through the shared UltimateVictimImpactPlayer with the executors' distance-ordered ripple, advanced 0.12 s, so only the first wave is visible in a still frame.
- The hero is the Thief idle full frame at the Player combat scale with the real ultimate HUD widget fed a registry snapshot; the live Player node, combat damage and enemy AI are not exercised by a still capture.
- The legacy FAN-3890 four-viewport contact sheets and the FAN-1470 3600x552 strip remain in the manifest as history; the certification package is the new per-combination evidence.

## Committed frames

| Weapon | Mode | Beat | Viewport | Path | Bytes | sha256 |
|---|---|---|---|---|---|---|
| thief_coin_pouch | normal | release 0.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__normal__release__648p.png` | 31581 | `451260051d17769be539db339e6db2d57895a0e4727a08d9d8d9b03046a05675` |
| thief_coin_pouch | normal | active 1.7 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__normal__active__648p.png` | 37839 | `ec9a5e9d1532b27f7e6fcf5fd493cba36ea06636644c40e945a273a16f2f0a7b` |
| thief_coin_pouch | normal | recovery 2.68 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__normal__recovery__648p.png` | 38940 | `6745a3682f16fa0338863ab85d3d81a0302594fed239ea7db6d483c7bae74cfa` |
| thief_coin_pouch | normal | active 1.7 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__normal__active__720p.png` | 43046 | `94dd707f929fc0fd12bab850d287e04c7d972f84a4c03e7e019aa1e119e665f5` |
| thief_coin_pouch | normal | active 1.7 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__normal__active__1080p.png` | 78257 | `e87cb9d0a0ae2024b2064925a22ee06bc1d667f61e60d291bf99dd0ad7734d99` |
| thief_coin_pouch | normal | active 1.7 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__normal__active__2k.png` | 116105 | `d0ee463f70ef77adfb30069333c338ffea568b487ea94406474702664733fa45` |
| thief_coin_pouch | crowded | release 0.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__crowded__release__648p.png` | 95837 | `d1366f2f5fb42138e6d7dd1c19d84085c64cf21b2a43cc8195b1f5c4ef0fdc0a` |
| thief_coin_pouch | crowded | active 1.7 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__crowded__active__648p.png` | 99368 | `fdb7c30244bc65e5179fc8997d36dd35c0e047fa0c21300a90fbdd2b32d8a695` |
| thief_coin_pouch | crowded | recovery 2.68 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__crowded__recovery__648p.png` | 101227 | `24dc30ffbae0349a073d6f8d77a100f371c244980e0c4c8ed6923e82b7dd1f9a` |
| thief_coin_pouch | crowded | active 1.7 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__crowded__active__720p.png` | 118213 | `55af6cb4a6bfcd42f924338ff9a3e938fa85cb7a830673d876341ce39870cb47` |
| thief_coin_pouch | crowded | active 1.7 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__crowded__active__1080p.png` | 228372 | `dd9a6d35d82387d94e58699da03bcd50432d26d7569eab72d74711595c89b465` |
| thief_coin_pouch | crowded | active 1.7 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__crowded__active__2k.png` | 351646 | `716f1375b0f23cc3e0c10af22d444d80b0b423e37c3e4d7a84a82b761f8f633f` |
| thief_coin_pouch | reduced_motion | release 0.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__reduced_motion__release__648p.png` | 32117 | `758c60f849ed73168ca19923092967bf6bdba5f3c2d596d850fac541269ccf2b` |
| thief_coin_pouch | reduced_motion | active 1.7 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__reduced_motion__active__648p.png` | 38973 | `7cfecddc96b5be9d41d346128a1265643903498fb37d6e360549539c1bad4a21` |
| thief_coin_pouch | reduced_motion | recovery 2.68 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__reduced_motion__recovery__648p.png` | 39447 | `bc6dc6efaee619b6adb88f1d1df0c836dd55a1a0e4252dc6fefa0e495e2382ba` |
| thief_coin_pouch | reduced_motion | active 1.7 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__reduced_motion__active__720p.png` | 42214 | `08c4d5158fdbc189a293ed70eb8a1d4a9ced9a8b5d8a9df6c2ffebab2eed0b00` |
| thief_coin_pouch | reduced_motion | active 1.7 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__reduced_motion__active__1080p.png` | 76436 | `b978cd31f41178bb90987313fb9109cf924fcd35ee0a7971d2d06c4266841ee0` |
| thief_coin_pouch | reduced_motion | active 1.7 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__reduced_motion__active__2k.png` | 114146 | `9639c425f420ffcbd6ba4de0d260e4d07e8da79aaf0bac765b9add2f38a26e32` |
| thief_coin_pouch | photosensitivity_safe | release 0.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__photosensitivity_safe__release__648p.png` | 32826 | `67d2f4c08a9747076c4ff63c0114e7b510a9a45709ca09522f744eb5a58b12c1` |
| thief_coin_pouch | photosensitivity_safe | active 1.7 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__photosensitivity_safe__active__648p.png` | 38781 | `70ed87cd3801254084e7d243d78ca67d9b2460fb3f312649b89034675e32ee6d` |
| thief_coin_pouch | photosensitivity_safe | recovery 2.68 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__photosensitivity_safe__recovery__648p.png` | 40071 | `c6234876de6d89f54120fed67ccef8f1dd91ed86f9938ccf8e9c07358daaa30a` |
| thief_coin_pouch | photosensitivity_safe | active 1.7 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__photosensitivity_safe__active__720p.png` | 41982 | `44653b3f716791214cd2af68c63af13593f3f470d660a1a54b434da807a81d87` |
| thief_coin_pouch | photosensitivity_safe | active 1.7 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__photosensitivity_safe__active__1080p.png` | 75805 | `9203e6794f1bf1dacdca2df466ddd60257ab5770627ced23cbce0b489ec43712` |
| thief_coin_pouch | photosensitivity_safe | active 1.7 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_coin_pouch__photosensitivity_safe__active__2k.png` | 113396 | `8610b8592fae31f1032e2859059935b6688c3d52d2677db4d735fe430f4b19fd` |
| thief_shadow_cloak | normal | release 1.02 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__normal__release__648p.png` | 34125 | `c1edbff3d2d474845956150be08e6eaaac71ebf44071b66afe0615d7061a9e1d` |
| thief_shadow_cloak | normal | active 1.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__normal__active__648p.png` | 48553 | `e35043c8395115d56718b52267e4772eff63e19d1035547f45272a2dac5b1cd9` |
| thief_shadow_cloak | normal | recovery 2.89 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__normal__recovery__648p.png` | 33457 | `8d678cbf6e6193ed439806b1fdd85d2f42214081ebf6058c0cc37eb1a5724731` |
| thief_shadow_cloak | normal | active 1.9 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__normal__active__720p.png` | 55424 | `144b22391734628e23ec544d200bdd6b58f99d7b3ad3fcbf1ede75857c7f9d41` |
| thief_shadow_cloak | normal | active 1.9 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__normal__active__1080p.png` | 100369 | `9aed3f18d78b1c93c8dd6d8111fb8b5ddaf154599f03126a1a610955fbc005eb` |
| thief_shadow_cloak | normal | active 1.9 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__normal__active__2k.png` | 151782 | `09c2f5694742032646e397abdfb77fc1077aeb57b10968ef54e6ae735ad21239` |
| thief_shadow_cloak | crowded | release 1.02 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__crowded__release__648p.png` | 56343 | `f85a69abe5d07e377e9f699bcf205dd6dfb12988474a858b9208158f4d2d0b9b` |
| thief_shadow_cloak | crowded | active 1.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__crowded__active__648p.png` | 63281 | `3149893bdd365bd448638dbdbbfcd3dec1a4b1f3b1ba3ecefd4a2045d96ca5ce` |
| thief_shadow_cloak | crowded | recovery 2.89 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__crowded__recovery__648p.png` | 55748 | `d0d788aace8a7a2980030e0e238259e2f8b30a46a4ecee958661bbc00ff14240` |
| thief_shadow_cloak | crowded | active 1.9 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__crowded__active__720p.png` | 73570 | `85b7ef8352a907055093477e56571a28c91269b13fbd7ef90bc069dc0a7c3f5e` |
| thief_shadow_cloak | crowded | active 1.9 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__crowded__active__1080p.png` | 132348 | `4d4bbe30864e19a691375151dcb244f479d77f51d4a88648b44770460673c518` |
| thief_shadow_cloak | crowded | active 1.9 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__crowded__active__2k.png` | 199638 | `acb2a9af7c8e630c147396600fb497b53e99deb3a7052cb817740f123f2da7c8` |
| thief_shadow_cloak | reduced_motion | release 1.02 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__reduced_motion__release__648p.png` | 35939 | `37cdc4dd201c83a1fb40cba826d313c8069ad9e79fdede7feb41ee96e5d879c6` |
| thief_shadow_cloak | reduced_motion | active 1.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__reduced_motion__active__648p.png` | 50011 | `445c0f4c12be46bc60c1235f42705092383ebbbc019897540e3316ddf8cb4947` |
| thief_shadow_cloak | reduced_motion | recovery 2.89 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__reduced_motion__recovery__648p.png` | 34981 | `3c56f3654e8c8e8bd64dbc0c80ea7fae64fd0f829cf61fb73cd428071ca6a3e6` |
| thief_shadow_cloak | reduced_motion | active 1.9 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__reduced_motion__active__720p.png` | 55015 | `711149c2a1e2e36fdece71de18fbe809e791c54af3ca66872bdfa6ba372bfcc3` |
| thief_shadow_cloak | reduced_motion | active 1.9 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__reduced_motion__active__1080p.png` | 99863 | `8969719bd16a16c46fdd608ad9fe74a3eecfed84f6e779cf5c53dddc4263ee4c` |
| thief_shadow_cloak | reduced_motion | active 1.9 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__reduced_motion__active__2k.png` | 150963 | `6db8d8168fccc48efbdf9799bc5c4cf8f9e1f41d7a7dc422fcb80160ddcd9986` |
| thief_shadow_cloak | photosensitivity_safe | release 1.02 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__photosensitivity_safe__release__648p.png` | 35717 | `df227c99d15480d1618665948307781844226a7b87d3d2c8fd7ab43cd03a032a` |
| thief_shadow_cloak | photosensitivity_safe | active 1.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__photosensitivity_safe__active__648p.png` | 49968 | `04f7ab0770c93c0439b48e23e6b77798beb391633012739cb97cf981063a7e37` |
| thief_shadow_cloak | photosensitivity_safe | recovery 2.89 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__photosensitivity_safe__recovery__648p.png` | 34542 | `5fc71ca443fd681f4ab6277fc820ce39fa20d0fde1621f0bc2984864b0452f0b` |
| thief_shadow_cloak | photosensitivity_safe | active 1.9 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__photosensitivity_safe__active__720p.png` | 56449 | `3174dcea21410ee3a79afc5c91729d9e42c5a427c4e2594b3f40bc7eceaae412` |
| thief_shadow_cloak | photosensitivity_safe | active 1.9 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__photosensitivity_safe__active__1080p.png` | 99226 | `70cc3cf3e50ced0bc8de6b128f0eb9e052d53c5045ca6b2fe79309df40dd318a` |
| thief_shadow_cloak | photosensitivity_safe | active 1.9 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_shadow_cloak__photosensitivity_safe__active__2k.png` | 150471 | `e9608ff230b83596c3e0195a83f1a27b03ebfcd8cb84ee8b4e92d21430f7dbe5` |
| thief_smoke_bomb | normal | release 1.14 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__normal__release__648p.png` | 35414 | `592c9585540a757c66ce71d4b1ba10bceeffdb108c1ee08296bca6bc8b616c0b` |
| thief_smoke_bomb | normal | active 2.09 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__normal__active__648p.png` | 44188 | `92e40fad58cceaa155da4f1cc16d24f6cd832c2d52d674077c4f42f3709cf94f` |
| thief_smoke_bomb | normal | recovery 3.13 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__normal__recovery__648p.png` | 40248 | `0c7294d332eb3c150f549d8a7b0feeeff1e38e6a7a9d73abe3d9547bd6229a1e` |
| thief_smoke_bomb | normal | active 2.09 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__normal__active__720p.png` | 49911 | `c4336c17450e652437c2c368c94ae2335c140c2d458802f655dc8f9ac921cde8` |
| thief_smoke_bomb | normal | active 2.09 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__normal__active__1080p.png` | 88397 | `0583cd79a3ed3e63e542b4a4d0add861643ae12ad39770242e3417ab514d4f4a` |
| thief_smoke_bomb | normal | active 2.09 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__normal__active__2k.png` | 123750 | `33603702c9f91188761195e3ca79414a25fcf65f08fa2d7872e59afa0af7ed17` |
| thief_smoke_bomb | crowded | release 1.14 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__crowded__release__648p.png` | 58266 | `898be155362c0e48d5ebb4cf675c223ce23d9004eacc6cb6505308a02ff0f204` |
| thief_smoke_bomb | crowded | active 2.09 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__crowded__active__648p.png` | 65819 | `53b3d1d241824f1f4157ff1799121c4f93ff6fd220d10d046c4046e2de54d147` |
| thief_smoke_bomb | crowded | recovery 3.13 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__crowded__recovery__648p.png` | 61466 | `1fcab55d639b0143b2e69d3e36efc49e02fe4a23fb5756391a9fe298d6cd1f41` |
| thief_smoke_bomb | crowded | active 2.09 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__crowded__active__720p.png` | 75752 | `ef11b94fc3d27dc6aad9996a2caca8711808dd8c76a4fc492df66e1b06ef34e8` |
| thief_smoke_bomb | crowded | active 2.09 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__crowded__active__1080p.png` | 135446 | `4f5646109f87bc144a1835216d9a65e937f300910f94cc2fcf4a95871a15d8c8` |
| thief_smoke_bomb | crowded | active 2.09 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__crowded__active__2k.png` | 197660 | `f3f602c2a08f9ef9d59255017609af5803344ce53faf644d9df59e6c06e6da18` |
| thief_smoke_bomb | reduced_motion | release 1.14 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__reduced_motion__release__648p.png` | 35632 | `45670110bf5af8a3a88d67f6a8e255e0f2fe6444ab3083b138858319f12d4104` |
| thief_smoke_bomb | reduced_motion | active 2.09 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__reduced_motion__active__648p.png` | 46245 | `3b17c32d76cd5ecdd08a8eca303c74aec978313cf3070f4094bc59c94a89ebf8` |
| thief_smoke_bomb | reduced_motion | recovery 3.13 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__reduced_motion__recovery__648p.png` | 40048 | `a1d3fe03e7e9be53b0ca17eba20a5cdb7aa70630b75a2b3a38f357d8ea994521` |
| thief_smoke_bomb | reduced_motion | active 2.09 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__reduced_motion__active__720p.png` | 49673 | `eae6d5097447d771f2c8fd69b777de3a0dd8905af195226c1ec0a77526d6ba2a` |
| thief_smoke_bomb | reduced_motion | active 2.09 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__reduced_motion__active__1080p.png` | 87269 | `e93e7b74714701b50984cfc92156dfc859b6f7ddacd840cd50f40217dfc9cc9c` |
| thief_smoke_bomb | reduced_motion | active 2.09 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__reduced_motion__active__2k.png` | 121972 | `60896aa7a37ae5cc70bf6ecfccaa159bba0e64b321ef09e9dcf1fe8c373d7bab` |
| thief_smoke_bomb | photosensitivity_safe | release 1.14 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__photosensitivity_safe__release__648p.png` | 36201 | `9e2a4cd729b198922fab0f05b599aba239894e3563d9e2b5b25fd6c6a8d9ce28` |
| thief_smoke_bomb | photosensitivity_safe | active 2.09 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__photosensitivity_safe__active__648p.png` | 44998 | `fb4ead78bde2222f2c4ef8ed4a41732d46886f1f7b4e1a18aee5ff15cd961bb8` |
| thief_smoke_bomb | photosensitivity_safe | recovery 3.13 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__photosensitivity_safe__recovery__648p.png` | 41410 | `504736607356e77285a5a239168b62c54cfb0d88bd0cdb8af4496c4e0db91820` |
| thief_smoke_bomb | photosensitivity_safe | active 2.09 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__photosensitivity_safe__active__720p.png` | 49835 | `f0774544ba673638d8313d5b78b49e0838865760099b6f85a1d65fc9c05f3ede` |
| thief_smoke_bomb | photosensitivity_safe | active 2.09 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__photosensitivity_safe__active__1080p.png` | 87206 | `a853b322dab28b3cd82218fe77a7ad82875f41c975356c0a865121a28b0022c7` |
| thief_smoke_bomb | photosensitivity_safe | active 2.09 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/thief/thief_smoke_bomb__photosensitivity_safe__active__2k.png` | 121799 | `f33710d874e516ca1e68ef04a29fadd6a385b218c77ecc391e8b219d54f061d4` |
