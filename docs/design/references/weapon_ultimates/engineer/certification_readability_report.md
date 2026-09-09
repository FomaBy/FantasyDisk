# Engineer ultimate certification readability report (FAN-3939)

Four-mode live capture evidence for the three canonical Engineer weapon
ultimates, replacing the four single-mode legacy timeline sheets that FAN-3877
rejected. Every observation below comes from the captured PNG sheets listed in
`certification_capture_manifest.json`, rendered by
`tests/ultimates/presentation/engineer_certification_live_capture.gd` from dev
`d192be10bbe52dd89971cab0acc66eb92ccab37f` (tree `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf`)
with Godot 4.7.stable.official.5b4e0cb0f, windowed, seed 3939.

## Coverage

Each of the four sheets is a 3-row (canonical weapons) × 4-column
(presentation modes) matrix; a sheet exists for every required viewport, so
all 3 weapons × 4 modes × 4 viewports = 48 combinations have traceable live
runtime evidence in a single reproducible pass:

| Mode | Beat sampled | Victims | What the panel proves |
|---|---|---|---|
| normal | active | 3 | Shipped timeline scene at its frozen active beat with HUD, player and hazard fixtures visible. |
| crowded | release | 39 | Release beat under the production degraded ripple path (above the 38-victim threshold) while HUD/hazard probes stay readable. |
| reduced_motion | active | 3 | Held frame after a deterministic seek; scene processing frozen, camera-shake meta off; the weapon read is preserved without motion. |
| photosensitivity_safe | recovery | 3 | Held low-contrast recovery frame; impact bursts stay local to victims, no full-screen flash cycle. |

Across the matrix every weapon is sampled at its release, active and recovery
beats (crowded → release, normal/reduced_motion → active,
photosensitivity_safe → recovery), taken from the frozen `timing_seconds` in
`manifest.json`, not ad-hoc skip points.

## Observed readability

- **Sentry Wrench (Гнездо Часовых).** The 256×256 flipbook reads clearly at
  every viewport including 1152×648: the nest silhouette stays disjoint from
  the HUD strips and the player/hazard fixtures. At the release beat under 39
  victims the degraded impact ripples remain distinguishable from the nest
  itself because the burst scale (0.6) and the crowd layout keep the nest's
  center clear.
- **Repair Drone (Рой Ремонтников).** The swarm frames keep distinct drone
  clusters at all four viewports. In crowded mode at 648p the victim markers
  in the lower half of the panel approach the 8-column marker lattice, but the
  panel outline, mode marker and hazard triangle remain separable — the
  weakest readability point of the set, still above the 6-px minimum feature
  size enforced by the gate.
- **Pressure Mines (Минное Поле).** The mine lattice frames are the
  highest-contrast of the trio; even in the dimmed photosensitivity-safe
  recovery frame (modulate 0.82/0.84/0.96) individual mines remain
  identifiable at 648p, and no panel relies on a flash cycle to be legible.
- **HUD and fixtures.** The HP/ult status strip and the footer strip stay
  readable in all 16 sheet/mode combinations; the deterministic player
  diamond and hazard triangle probes are verified pixel-exact by
  `engineer_certification_capture_test.gd` for every weapon/mode/viewport
  cell, so readability is checked, not asserted.

## Limitations

- Each panel holds one deterministic beat, not an animation; motion-related
  claims (reduced-motion parity, flash frequency) are enforced separately by
  the focused timeline gate (`engineer_ultimate_timelines.gd`) and the shared
  visual-direction contract, not by these stills.
- Fixture HUD, player, and hazards are capture-side fixtures, not the shipped
  HUD scene; the shipped scenes' own content is unchanged production
  material.
- The crowded column exercises the victim-impact service's degraded path with
  marker nodes standing in for enemies, matching the production API surface
  (`play(frames, victims, cast_position)`); it is not a full 39-enemy
  combat simulation.

## Reproduction

Commands are pinned in `certification_capture_manifest.json` under
`verification`. The windowed capture must run through `tools/godot_gate.py`
(a headless run skips with a message and produces no evidence). The integrity
gate fails closed on a missing mode, a missing canonical weapon key, a missing
file, an unsmudged LFS pointer, and wrong PNG dimensions.
