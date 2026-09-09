# Ranger weapon-ultimate certification readability report (FAN-3941)

Independent-review evidence for the Ranger ultimate trio (`ranger/moon_crossbow`, `ranger/storm_longbow`, `ranger/hunter_trap`) in the four presentation modes at the four supported viewports. Every frame is a real render of the shipped `scenes/vfx/ultimates/ranger/*.tscn` timeline scene driven through its `begin()`/`step()` runtime path, composed with the hero, hazards, a crowd and the real ultimate HUD widget at the on-screen scale the game uses. The frames are the evidence; this report records what they show and what they do not.

## Provenance

- Source ref/commit/tree the shipped scenes were rendered from: `dev` / `d192be10bbe52dd89971cab0acc66eb92ccab37f` / `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf`. Integrated origin/dev revision whose shipped Ranger scenes, pack and assets were rendered; the capture tooling, frames and this manifest are added by FAN-3941 on top of it and change no production scene.
- Engine: Godot 4.7-stable (official) (gl_compatibility, opengl3, Apple M4 Pro), macOS 26.5.1, display server macOS, captured 2026-09-09 02:59:29 UTC.
- Renderer: `tests/ultimates/presentation/ranger_certification_live_capture.gd`; gate: `tests/ultimates/presentation/ranger_certification_capture_test.gd`; capture manifest: `docs/design/references/weapon_ultimates/ranger/certification_capture_manifest.json` (every frame path, size, byte count and sha256).
- Capture command: `FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --script res://tests/ultimates/presentation/ranger_certification_live_capture.gd`
- Gate command: `python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/ranger_certification_capture_test.gd`
- Seed: 3941 (seed() is set for completeness; the capture path draws no random value (no camera exists for the shake device, the crowd is a fixed grid and the impact ripple is distance-ordered).)
- Exclusive process admission during the committed run: no. The exclusive admission (`FSD_GODOT_EXCLUSIVE=1`) was requested first and waited behind another agent's live P3 measurement run on this host; because a frame here is a fixed-step deterministic render with no time-dependent quantity, the committed run used the shared slot admission of `tools/godot_gate.py` instead and the manifest records `exclusive_gate: false` truthfully. Re-running the capture command reproduces byte-identical frames.
- On-screen scale: logical canvas 2560x1440 with `canvas_items` stretch and combat camera zoom 1.12; hero at Player visual scale 0.64; HUD widget `res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn` at the UI scale of each viewport with state from ultimate_hud_view_model.gd build() of tests/ultimates/hud_fixture_library.gd weapon_profile_snapshot(class, weapon) with charge fraction 1.0, active true and keyboard input.
- Method: Each frame is a SubViewport at the exact viewport size: floor, two striped hazards, the hero full frame at the Player combat scale, a crowd grid at the declared crowd cap (crowded), the shipped scene instantiated and driven with begin()/step() in fixed 1/120 s steps to the beat and held, the weapon's victim-impact flipbook on the crowd (crowded), the real UltimateHudWidget fed a registry snapshot, and a caption band with mode/weapon swatches. The scene is placed at the game's on-screen scale (viewport_height / 1440 * combat camera zoom 1.12) and never fitted. Opaque coverage is measured on a scene-only transparent render of the same composition with the veil hidden (alpha >= 0.5, stride 2). The photosensitivity-safe variant hides the authored backdrop veil after the beat is drawn; reduced motion applies the shipped screen_shake toggle on the tree root.

## Coverage

- Weapon x mode x viewport combinations: 48 (3 canonical weapons x 4 modes x 4 viewports), every one committed as a native-size frame at the active beat.
- Frames committed: 72 of 72 expected (midpoint of the declared phase window; the active beat is committed at every viewport, release and recovery at 648p).
- Modes: `normal` (crowd none, screen_shake on, backdrop veil kept, victim impacts off); `crowded` (crowd declared crowd_cap per weapon, screen_shake on, backdrop veil kept, victim impacts on); `reduced_motion` (crowd none, screen_shake off, backdrop veil kept, victim impacts off); `photosensitivity_safe` (crowd none, screen_shake off, backdrop veil suppressed/none, victim impacts off).
- Viewports: `648p` 1152x648 (scene scale 0.504, UI scale 0.45), `720p` 1280x720 (scene scale 0.56, UI scale 0.5), `1080p` 1920x1080 (scene scale 0.84, UI scale 0.75), `2k` 2560x1440 (scene scale 1.12, UI scale 1.0).

## Measurements

| Weapon | Declared max_viewport_coverage_ratio | Measured peak opaque coverage (frames + full-envelope sweep) | Sweep | Full-screen surface / flash | Declared flash (Hz / coverage) |
|---|---|---|---|---|---|
| `ranger/moon_crossbow` | 0.01 | 0.0039 (peak at 0.67 s) | 94 samples every 0.0333 s over 3.1 s at 648p normal | arena-wide darken veil, translucent, peak alpha 0.30, rises once per cast (not a flash) | 0.0 / 0.0 |
| `ranger/storm_longbow` | 0.01 | 0.0042 (peak at 0.73 s) | 104 samples every 0.0333 s over 3.45 s at 648p normal | arena-wide veil flash, translucent, peak alpha 0.28, 60 ms rise, one rise per cast | 0.0 / 1.0 |
| `ranger/hunter_trap` | 0.02 | 0.0112 (peak at 1.8 s) | 115 samples every 0.0333 s over 3.8 s at 648p normal | arena-wide darken veil, translucent, peak alpha 0.34, rises once per cast (not a flash) | 0.0 / 0.0 |

Opaque coverage counts pixels at alpha >= 0.5 on a scene-only render with the veil hidden, sampled at stride 2, at the game's on-screen scale: the formation elements are the opaque surface, the veil is a translucent tint that the FAN-3889 gate and this gate hold under a 0.35 alpha ceiling and that rises exactly once per cast (0 Hz repetition; `storm_longbow` declares its single-shot full-viewport flash as coverage 1.0, the darken veils declare 0.0). The declared caps leave headroom above the measured peaks and stay far under the shared 0.35 readability ceiling.

## Observed readability at release, active and recovery

### `ranger/moon_crossbow`

Beats sampled: release 0.88 s, active 1.83 s, recovery 2.85 s (declared timing {"windup": 0.0, "release": 0.7, "active": 1.05, "recovery": 2.6, "cancel": 3.1}).

- **release** — The aimed bolt is a ~40 px silver streak at 648p (~80 px at 2K) travelling toward the mark under a 0.21-alpha night veil; the hero cast pose is fading. The bolt is legible as a bolt; the mark itself is small at 648p.
- **active** — Four split bolts fan out from the mark in a cross (~130 px across at 648p, ~260 px at 2K); the silhouette is unmistakable at every viewport and at 648p the individual bolts stay above the 6 px readability floor.
- **recovery** — The bolts rejoin and fade to ~0.3 alpha; the read at 648p is a faint cross that the frame still carries above the floor.
- **crowded** — Twelve crowd members at the declared crowd cap around the formation; the nearest three carry the moon-bolt impact burst in the committed first wave, the formation stays inside its zone and no crowd member is occluded by an opaque element.
- **reduced motion** — Identical formation and timing to the normal frame (the gate proves the formation signature is equal); the shipped `screen_shake` toggle is off so the 0.35 s camera shake device is not applied, the veil and hitstop remain.
- **photosensitivity-safe** — Motion off and the arena-wide veil suppressed at capture time (VEIL OFF in the caption, `veil_alpha` 0.0 in the manifest); the formation is unchanged and stands on the plain floor.

### `ranger/storm_longbow`

Beats sampled: release 0.77 s, active 1.9 s, recovery 3.15 s (declared timing {"windup": 0.0, "release": 0.6, "active": 0.95, "recovery": 2.85, "cancel": 3.45}).

- **release** — The charged arrow corridor draws horizontally (~160 px wide at 648p) with the cast pose overlapping its tail; the corridor is readable as a lane at every viewport.
- **active** — Seven lightning beats walk tail to tip; at the mid-active beat the corridor is ~400 px wide at 2K and ~190 px at 648p with the bright beat at its centre.
- **recovery** — The corridor thins and fades below the opaque threshold (measured coverage 0.0000 at recovery); the veil tail (alpha 0.05) is the only remaining presence and the read is intentionally gone.
- **crowded** — Twelve crowd members at the declared crowd cap; the corridor runs between the crowd rows and the storm impact burst lands on the nearest members; every crowd disc stays readable through the veil.
- **reduced motion** — Identical formation and timing to the normal frame; the 0.50 s shake device is off, the release veil flash and the 120 ms hitstop remain.
- **photosensitivity-safe** — Motion off and the single-shot veil flash suppressed; the corridor is unchanged and no full-screen surface is drawn.

### `ranger/hunter_trap`

Beats sampled: release 1.17 s, active 2.05 s, recovery 3.25 s (declared timing {"windup": 0.0, "release": 0.95, "active": 1.4, "recovery": 2.7, "cancel": 3.8}).

- **release** — Three trap rings close toward the centre at ~180 px across at 648p under a 0.21-alpha forest veil; the rings are the largest Ranger silhouette and read clearly.
- **active** — The jaws lock in a tight three-ring cluster (~110 px at 648p); the rune centres are visible at every viewport and the crowd impacts in the crowded variant are the trap-jaw flipbook on the nearest members.
- **recovery** — The rune bleeds out at ~0.3 alpha; at 648p it is a dim three-lobe mark that still reads as the trap.
- **crowded** — Twelve crowd members at the declared crowd cap; the trap-jaw impact burst lands on the nearest three; the crowd rows stay readable above and below the formation.
- **reduced motion** — Identical formation and timing to the normal frame; the 0.65 s shake device is off, the veil and the 145 ms hitstop remain.
- **photosensitivity-safe** — Motion off and the veil suppressed; the rings are unchanged.

## Probe results recorded on every frame

- HUD band contrast ratio (share of band samples at luma delta >= 0.25 against the band background; floor 0.004): min 0.0127, max 0.0169.
- Hero contrast ratio (share of the drawn hero pixels at luma delta >= 0.15 against the floor; floor 0.15): min 0.2083, max 0.2320.
- Hazard stripe contrast against the floor (floor 0.15, warm hue required): min 0.595, max 0.616.
- Effect inside the effect zone on every frame: True; mode and weapon swatches verified on every frame: True.
- The gate recomputes every one of these numbers from the committed PNGs and fails closed on a missing, pointer-only, wrong-size, wrong-hash, unreadable or off-spec frame.

## Limitations

- At the game's true on-screen scale the Ranger formations are small at 1152x648 (the moon mark cluster is ~130 px across, the storm corridor ~190 px wide, the trap cluster ~110 px); the silhouettes stay above the 6 px readability floor the FAN-1474 test holds, but they are not large. Earlier FAN-3889 sheets fitted the effect to a panel and therefore looked larger than the game shows it; these frames do not.
- The release and recovery beats are committed at 1152x648 (the viewport the shared contract judges readability on) and the active beat at all four viewports; the manifest records the coverage and readability probes for every committed frame and the full-envelope sweep for the peak.
- The camera shake device needs a current Camera2D, which the capture arena does not contain; reduced motion is therefore proven by the shipped toggle being read by the scene and by formation/timing parity, not by a visible shake difference in a still frame.
- The photosensitivity-safe variant suppresses the authored veil at capture time; the shipped game has no dedicated photosensitivity setting beyond the screen_shake toggle, and this package changes no production scene.
- Victim impacts are the weapon's flipbook played on the crowd through the shared UltimateVictimImpactPlayer with the same distance-ordered ripple the executors use, advanced 0.12 s, so only the first wave is visible in a still frame.
- The hero is the Ranger idle full frame at the Player combat scale standing in the arena, with the real ultimate HUD widget fed a registry snapshot; the live Player node, combat damage and enemy AI are not exercised by a still capture.

## Committed frames

| Weapon | Mode | Beat | Viewport | Path | Bytes | sha256 |
|---|---|---|---|---|---|---|
| moon_crossbow | normal | release 0.88 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__normal__release__648p.png` | 31574 | `7898991ae9c44922a52dfb650b2b6ea749b567d1b44fad516b0b639318a0e8b0` |
| moon_crossbow | normal | active 1.83 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__normal__active__648p.png` | 52352 | `f281be11dcebb33c807cccebcc6b81afea022a09259a9207b8d16baa666dad1f` |
| moon_crossbow | normal | recovery 2.85 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__normal__recovery__648p.png` | 35934 | `2e6a75dce7f3e4a1f9142549dfe9aa7635db1fd074221f06835619e692fcd550` |
| moon_crossbow | normal | active 1.83 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__normal__active__720p.png` | 60164 | `59733b653b637581f80c9602f4b87e60495269925fc062d692c6cfb30e4b6997` |
| moon_crossbow | normal | active 1.83 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__normal__active__1080p.png` | 107699 | `3d70c0f9760d9ab45ba74ec656717a4432f8eb161c52fc18633fedb1c2104976` |
| moon_crossbow | normal | active 1.83 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__normal__active__2k.png` | 154824 | `a5c9e040b9f58b11f88eacfb9ecc874c2d3d91a14ffd63c026fe24467665bde7` |
| moon_crossbow | crowded | release 0.88 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__crowded__release__648p.png` | 90966 | `eb813b3acae1993726ca74db004196c36e11a8d6b96a419070013907fffb18b1` |
| moon_crossbow | crowded | active 1.83 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__crowded__active__648p.png` | 98970 | `2e726f95beb6181487b7b34124b893168da1ebc254487f636922e5d3329e962e` |
| moon_crossbow | crowded | recovery 2.85 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__crowded__recovery__648p.png` | 82533 | `061e12ba3f3d31cdf681a6b846aa658d65e497dbeb04f432af9ee1d6a99c641d` |
| moon_crossbow | crowded | active 1.83 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__crowded__active__720p.png` | 116487 | `c4143a91216b979d9fb52a234b531433739354770a7250ebb203be9cc34f5e93` |
| moon_crossbow | crowded | active 1.83 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__crowded__active__1080p.png` | 223210 | `6e2614658c56875d9b806981e7069052775451f957486f8e4e06813a821db51a` |
| moon_crossbow | crowded | active 1.83 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__crowded__active__2k.png` | 343501 | `93677e95b7ee7287229167f73266548e269ea704d7f9efdd9bb99066a72a2da1` |
| moon_crossbow | reduced_motion | release 0.88 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__reduced_motion__release__648p.png` | 46705 | `44d016c2e6812f4ca2c54b0931039503506758ad7ca948aec35f24f90ad7ebb6` |
| moon_crossbow | reduced_motion | active 1.83 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__reduced_motion__active__648p.png` | 54585 | `43beccd3fddc52a3475a924e1a4291e5106a38e84d837af34760df283bbec469` |
| moon_crossbow | reduced_motion | recovery 2.85 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__reduced_motion__recovery__648p.png` | 38126 | `fdaabe1a6aa4f402873cc5a8a7d29f6f1750a41394bdffeba8e8fe903e13b4c5` |
| moon_crossbow | reduced_motion | active 1.83 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__reduced_motion__active__720p.png` | 59246 | `95674c547bacee0ef84a83ead7d6321e806e97ca3943ea1b3149695962b9842a` |
| moon_crossbow | reduced_motion | active 1.83 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__reduced_motion__active__1080p.png` | 105784 | `fed53aeeb4ce2dc989303ebd8294b398a17ca8b65641a1baad268318b6234d90` |
| moon_crossbow | reduced_motion | active 1.83 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__reduced_motion__active__2k.png` | 152893 | `3a1247438dbeff179051bb47c613ad5db0101d574ef6683ba385b82f075626ca` |
| moon_crossbow | photosensitivity_safe | release 0.88 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__photosensitivity_safe__release__648p.png` | 38230 | `322eb48d632c9b16bba7980efa7f3d4551cc142b305de95e821726c5fcad81c1` |
| moon_crossbow | photosensitivity_safe | active 1.83 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__photosensitivity_safe__active__648p.png` | 45044 | `70ddfb2e9df76953a6e3fcbc1e70d35fce3387962d7de4acdd8c16a097a87f49` |
| moon_crossbow | photosensitivity_safe | recovery 2.85 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__photosensitivity_safe__recovery__648p.png` | 33938 | `aa4df974d4b034280a6f0c50095ee756ae6c648e74f6ce966da7928d12510c03` |
| moon_crossbow | photosensitivity_safe | active 1.83 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__photosensitivity_safe__active__720p.png` | 49188 | `4947d18d1f860c5a0f06e94d7b0055271edbb85f8edb6fb38f649ac95f5d450d` |
| moon_crossbow | photosensitivity_safe | active 1.83 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__photosensitivity_safe__active__1080p.png` | 90747 | `cb123f195faa4100b99486d7d6cf626c8c05a3276dd9052731e051bd8bb67108` |
| moon_crossbow | photosensitivity_safe | active 1.83 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/moon_crossbow__photosensitivity_safe__active__2k.png` | 133225 | `051710ab1ed68178071c2e0ac53adc01eaffca558fa127a2742bd550d7b894c3` |
| storm_longbow | normal | release 0.77 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__normal__release__648p.png` | 111965 | `ebe68a9ac662e5b6acbb050b8af49604e31b5377ff22cf84ca21d8be1c344cb9` |
| storm_longbow | normal | active 1.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__normal__active__648p.png` | 60469 | `c6f010d47b0f4146f168333880205ccccd58985fb7d0fd11638a12cf7fd3b3fb` |
| storm_longbow | normal | recovery 3.15 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__normal__recovery__648p.png` | 39329 | `f7cfbe27c5c760a5a5a9385df730787ba2aaa3b957ed0f2cd416bd711733cf4a` |
| storm_longbow | normal | active 1.9 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__normal__active__720p.png` | 69262 | `d89df7d08aaf09f30febfbd4b89385956e6020f7f0f1466c96bfa89f098900cd` |
| storm_longbow | normal | active 1.9 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__normal__active__1080p.png` | 119578 | `fbf8c42eab3a407f968794ddafb8ddce37036cd7e78d064a6f84d0040b1d4a91` |
| storm_longbow | normal | active 1.9 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__normal__active__2k.png` | 166551 | `00c497ca2cd00e1f70227b2be65fc537a79fceb106d1c416c6ba2c46b5d0ddfe` |
| storm_longbow | crowded | release 0.77 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__crowded__release__648p.png` | 157699 | `cb08fc4ff214af1c545b342f67004d251a3d8719c9ef7adb2949c6fbbee6c6b7` |
| storm_longbow | crowded | active 1.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__crowded__active__648p.png` | 101004 | `a5c3f730e1e8b5fe197b2680c8d8be583723d52ccfdf19bb73a3a4ab5857c201` |
| storm_longbow | crowded | recovery 3.15 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__crowded__recovery__648p.png` | 79119 | `c4538928f56ed3ac69c9e22dda9367fb5ebedd872fd4d2b0d65269d085f2b540` |
| storm_longbow | crowded | active 1.9 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__crowded__active__720p.png` | 117467 | `0c2f67cb0c80c6ded3d33081b16de65db804e4fbd65f7947e7e68e48a7ea8b78` |
| storm_longbow | crowded | active 1.9 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__crowded__active__1080p.png` | 216645 | `a64f9439ccdc80e5b7bf1e03843b3beb7cbe5bd07c5317baeccc1106bbcf826c` |
| storm_longbow | crowded | active 1.9 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__crowded__active__2k.png` | 325015 | `aa5f03bf0b3ec089a787c3facc2404b848277709891f625daf9821d66e1be200` |
| storm_longbow | reduced_motion | release 0.77 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__reduced_motion__release__648p.png` | 113743 | `caa946d6bf07f0146b4d7752a844c7aefcb8a25d1e91e5e1d713aa9f97e34d2f` |
| storm_longbow | reduced_motion | active 1.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__reduced_motion__active__648p.png` | 62004 | `c7d3614fddbbf66f068bc8fb58a289e639c52b32dbf030ebde12ab79049a5ef0` |
| storm_longbow | reduced_motion | recovery 3.15 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__reduced_motion__recovery__648p.png` | 40556 | `8e5b5a3b2a677535a1a565d6cc24c18abdc69602d809be0cd48678a9be96e82c` |
| storm_longbow | reduced_motion | active 1.9 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__reduced_motion__active__720p.png` | 68458 | `74a94554ac50672a57a9294620fa27b71db2f895d99af8d583445df0d82a54ed` |
| storm_longbow | reduced_motion | active 1.9 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__reduced_motion__active__1080p.png` | 117774 | `f8c48e1763567449aefeec5bd9e6a4fc028e07b4938e73d43b127b62d0261e2f` |
| storm_longbow | reduced_motion | active 1.9 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__reduced_motion__active__2k.png` | 165720 | `69d823ffa76197bb6c7ad260f3cd45e404e11eab094553cb004f44476cf65d54` |
| storm_longbow | photosensitivity_safe | release 0.77 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__photosensitivity_safe__release__648p.png` | 42870 | `deceaaf6361277f6ab410c7774ce7cd1b685298789630c20156b24ffdd0e92ea` |
| storm_longbow | photosensitivity_safe | active 1.9 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__photosensitivity_safe__active__648p.png` | 38119 | `38941fc6ba60e5f328dad9d2378dd7fa679a08c23e318f494e5fcc32a985b259` |
| storm_longbow | photosensitivity_safe | recovery 3.15 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__photosensitivity_safe__recovery__648p.png` | 37051 | `39d68578de96adcfb311683a5c54a3b7a5101f8ae57017d1bf64d9c113aad30f` |
| storm_longbow | photosensitivity_safe | active 1.9 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__photosensitivity_safe__active__720p.png` | 41553 | `1ac47ab7c22256161338be8fccc7759247e79d47dea490b6aaf014a5a7a42248` |
| storm_longbow | photosensitivity_safe | active 1.9 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__photosensitivity_safe__active__1080p.png` | 72779 | `5ddda1e79c279dde4ba7b19dbf9068a63bb5f7694b775bfa4770a77c1db5ecae` |
| storm_longbow | photosensitivity_safe | active 1.9 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/storm_longbow__photosensitivity_safe__active__2k.png` | 102825 | `0e2b81e6f1fcbf078d161659d5f3281151e54f544b70edf4527073160d5e451e` |
| hunter_trap | normal | release 1.17 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__normal__release__648p.png` | 60036 | `6bad1272ab2ae11ca392f3a2c3aa89ec8607eeb1c44c5232abdd8a1428b1e91d` |
| hunter_trap | normal | active 2.05 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__normal__active__648p.png` | 70130 | `717ff57938a925de999b9ecbc93c93dbff90d7486eac3d15b5cc5efedf9394b2` |
| hunter_trap | normal | recovery 3.25 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__normal__recovery__648p.png` | 46365 | `924530eb18b839706b58f8d61ee66ec97f8421b17c16f4b0e7543d7155ac4d4f` |
| hunter_trap | normal | active 2.05 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__normal__active__720p.png` | 81775 | `147b4f6a29f69c4df37ca94bccf24a287aa1a2ffc08472fc3344273ee2ea1f6b` |
| hunter_trap | normal | active 2.05 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__normal__active__1080p.png` | 155157 | `20897363f258763426ebfc6ae76b24e7e3517d8c33c6ea1687f4d6da8ce5857f` |
| hunter_trap | normal | active 2.05 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__normal__active__2k.png` | 233372 | `54725917d2184ce55857be145d66d7e73d20ee745a20280515868835be167e1d` |
| hunter_trap | crowded | release 1.17 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__crowded__release__648p.png` | 119323 | `b7b598da238cdb2e642e1dcc4ca1f23362988c1fdc12235b987aac3ef3550c1d` |
| hunter_trap | crowded | active 2.05 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__crowded__active__648p.png` | 130099 | `c750ffb40495b8b37b014e80c1a4468bdb4dae0369a0083a65854c907ec51654` |
| hunter_trap | crowded | recovery 3.25 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__crowded__recovery__648p.png` | 105853 | `594c06552b28b57903002d3d3d885aab64aa9bb72e7f020e8a087034cf1f5c95` |
| hunter_trap | crowded | active 2.05 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__crowded__active__720p.png` | 154545 | `baf089759227f8081040c936f542a4421494ab8cea226ff1f4c2df9cf8c2a053` |
| hunter_trap | crowded | active 2.05 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__crowded__active__1080p.png` | 292368 | `6de2a8a83c778eb4daf48a8eafd3f057740534d537a9d143d9b15b5eb581894c` |
| hunter_trap | crowded | active 2.05 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__crowded__active__2k.png` | 452033 | `26602b8eb3ecb72ccb4304686d33a96452a88a582c1bcf27c33260206a7b289a` |
| hunter_trap | reduced_motion | release 1.17 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__reduced_motion__release__648p.png` | 59525 | `80b1167280193a8277118bc4d86c270b6bc345461b9541754df209d0a6719c50` |
| hunter_trap | reduced_motion | active 2.05 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__reduced_motion__active__648p.png` | 69674 | `61007910ca6a57c4110ecc25eb9ae9a25bd016eb163cf83ef490170845a2049b` |
| hunter_trap | reduced_motion | recovery 3.25 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__reduced_motion__recovery__648p.png` | 47544 | `716ee7934cd822792f18a89af807a7ae0a80f858a462bd25aacbf05b29049408` |
| hunter_trap | reduced_motion | active 2.05 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__reduced_motion__active__720p.png` | 81112 | `e3f3839c7762e709220f21f9634a24fb652789985993b5ac5c17e47330cb475c` |
| hunter_trap | reduced_motion | active 2.05 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__reduced_motion__active__1080p.png` | 153049 | `9658878e1ab9edb4ef65192c6f71589061fe3bbb133a19cab09923199eddcd31` |
| hunter_trap | reduced_motion | active 2.05 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__reduced_motion__active__2k.png` | 231800 | `a6e74ce1a044198271fd1efbd2af9073c14cc505036d2e8dc802829edab9892e` |
| hunter_trap | photosensitivity_safe | release 1.17 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__photosensitivity_safe__release__648p.png` | 53481 | `1daa3059555377c2e4084345a417559a3d72b1ff70d2f5ec9fa77581ed022012` |
| hunter_trap | photosensitivity_safe | active 2.05 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__photosensitivity_safe__active__648p.png` | 62556 | `d65163e874ac4a56a97834062cfa911e0a075df2b8764aa7fb822628d97a25b6` |
| hunter_trap | photosensitivity_safe | recovery 3.25 s | 1152x648 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__photosensitivity_safe__recovery__648p.png` | 42766 | `5aa79831db33f6381f533d18c1136ca93bbb56f74eafff3fe2566436a1494c9a` |
| hunter_trap | photosensitivity_safe | active 2.05 s | 1280x720 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__photosensitivity_safe__active__720p.png` | 71638 | `1c7a451f7ba1d01520ba0d2736a1b2d6bd2031c13b664d2748ba60411ffb0131` |
| hunter_trap | photosensitivity_safe | active 2.05 s | 1920x1080 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__photosensitivity_safe__active__1080p.png` | 138687 | `3d82f8e4984ceb44cae044d13e8d8917dcfe8d94635d7e89c3847717fb630dc0` |
| hunter_trap | photosensitivity_safe | active 2.05 s | 2560x1440 | `docs/design/reference-assets-lfs/ultimate-certification/ranger/hunter_trap__photosensitivity_safe__active__2k.png` | 216813 | `975633bac20e92e5d8181d1ebcd51ce1b960e0f165a1b146f7dcb6397ccc0cf8` |
