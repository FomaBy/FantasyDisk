## Engineer accessibility runtime report

FAN-3947 implements and measures the production `ultimate_reduced_motion` and
`ultimate_photosensitivity_safe` modes for all three canonical Engineer weapon
ultimates. This is focused runtime evidence, not the 48-cell certification pack
owned by FAN-3939.

### Source and configuration

- Source ref: `agent/codex-dev-sol-5-6/cc980638d8a5`
- Integrated source base: `6b76adfc0dba4fcad64c34f094ef3f9f79b7e405`
- Runtime driver SHA-256: `6987f0b9ff3e1a57f3407d1d278906ee476131790227cbe25c385c538b98f681`
- Measurement test SHA-256: `629d1ca9d250041659e8246cd966b5606d3c35c06985f635807be9c56f94ec79`
- Godot: `4.7.stable.official.5b4e0cb0f`
- Display server: `macOS`
- Renderer: Apple M4 Pro, OpenGL 4.1 Metal compatibility, `gl_compatibility`
- Native measured viewport: `1152x648`
- Controlled seed: `394720260910`
- Root feedback configuration: `combat_feedback=true`, `screen_shake=true`
- Mode source: the coherent root snapshot applied/read through
  `ultimate_accessibility_settings.gd`; no additional metadata convention is
  used.

The test activates every weapon through `Player.activate_ultimate()`, the real
`UltimatePlayerHost`, registry, controller, activation and presentation runtime.
Its 12-cast matrix covers default, reduced motion, photosensitivity safe, and
both options together. It also covers 39-target repeated victim beats, real
Player/Enemy ordinary feedback, release, active and recovery state, pause and
resume, natural completion, explicit cancellation, death and node removal.

### Implemented mode behavior

Reduced motion disables the authored `AnimationPlayer`, stops the class
`AnimatedSprite2D`, and holds the admitted canonical frame for the entire
presentation envelope. The sentry uses deployed pylons and frame 3; repair drone
uses its deployed swarm and frame 4; pressure mines uses its armed lattice and
frame 4. A steady texture-backed backdrop and weapon sigil remain visible.
Temporary devices keep the executor-owned positions and movement; only their
class-local sprite treatment changes. Engineer camera shake and time-scale
hitstop are not acquired in this mode.

Photosensitivity-safe mode uses the same steady caster/backdrop envelope. Its
victim flipbooks are stopped on the canonical held frame at scale `0.24` and
alpha `0.12`. The executor retains ordinary combat feedback and damage numbers,
but synchronously restores the enemy body tint and bounds only the newly created
Engineer hit marker to 22 px reach and alpha `0.10`. It does not change the root
combat-feedback switch and does not suppress unrelated damage feedback. Normal
mode retains the existing authored timeline, ordinary victim flash, crowd
degradation, targeting and mechanics.

### Temporal method and results

The exclusive windowed run samples the actual root framebuffer at 30 Hz over
each complete photosafe gameplay activation, including repeated executor beats
after the shorter presentation envelope. Three real enemies and their enabled
ordinary feedback are in every measured run. Every fourth pixel in each axis is
inspected. A candidate flash transition is a positive Rec.709 luminance rise of
at least `0.18` covering at least `0.01` of sampled pixels. A
full-screen event uses coverage `>=0.80`; full-screen Hz is event count divided
by the complete envelope duration. These thresholds and observed values are
printed as `ENGINEER_ACCESSIBILITY_TEMPORAL` by the test.

| Weapon | Envelope | Samples | Flash events | Max observed coverage | Declared maximum | Full-screen flash Hz |
|---|---:|---:|---:|---:|---:|---:|
| `engineer_sentry_wrench` | 4.6 s | 138 | 0 | 0.000000 | 0.06 | 0.0 |
| `engineer_repair_drone` | 5.5 s | 165 | 0 | 0.000000 | 0.0 | 0.0 |
| `engineer_pressure_mines` | 4.0 s | 120 | 0 | 0.000000 | 0.0 | 0.0 |

The held visuals remain unchanged at the frozen release/active/recovery phase
times: sentry `0.8/1.15/3.1/3.8`, repair drone `0.7/1.2/3.35/4.0`, and pressure
mines `0.9/1.7/3.1/3.6`. Gameplay lifetimes remain independently configured and
are not retimed to those presentation envelopes.

### Reproduction

State and lifecycle pass:

```sh
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/engineer_accessibility_modes_test.gd
```

Windowed temporal pass:

```sh
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --windowed --fixed-fps 60 --path . --script res://tests/ultimates/presentation/engineer_accessibility_modes_test.gd
```

Both runs pass. The windowed run reports 423 samples and the values above. The
existing Engineer timeline, presentation, mechanics, live activation and
balance suites also pass unchanged. After normal Git LFS materialization, the
shared visual-direction contract passes, including 17/17 victim-impact wiring
and the Engineer phase, cleanup, budget, direction, capture, provenance,
quality and telegraph gates.
