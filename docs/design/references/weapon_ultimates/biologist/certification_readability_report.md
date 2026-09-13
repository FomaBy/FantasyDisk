# Biologist Ultimate 0.3.1 Certification Readability Report

## Outcome

FAN-3936 records 48 fresh, native-resolution live captures for the three canonical Biologist ultimates. Every image is an `active`-beat render from a real `Player.tscn` activation through `ultimate_player_host.gd`; it is not a composited contact sheet or a stand-in effect. Before each PNG was saved, the runner observed the release, active, and recovery beats and asserted that a visible authored presentation descendant, shipped ultimate HUD, representative `HazardVfx` telegraph, and at least one real target impact were present. The Sample Injector rework additionally freezes the real active scene long enough to compare the shown and hidden authored sprite in the native render; that proof rejects an empty or pre-beam frame instead of treating node visibility alone as readability.

Coverage is complete: three weapons × four modes × four native viewports (`1152x648`, `1280x720`, `1920x1080`, and `2560x1440`) = 48 PNGs. The full per-image provenance, dimensions, SHA-256 values, and LFS object IDs are in `certification_capture_manifest.json`.

## Captured runtime

| Weapon | Authored scene | Release observed | Active image | Recovery observed | Crowded target cap |
| --- | --- | ---: | ---: | ---: | ---: |
| `biologist_spore_lens` | `BiologistSporeLensWorldMycelium.tscn` | 0.80 s | 1.55 s | 2.80 s | 18 |
| `biologist_sample_injector` | `BiologistSampleInjectorPerfectSample.tscn` | 0.70 s | 2.20 s | 2.50 s | 16 |
| `biologist_symbiote_seed` | `BiologistSymbioteSeedMatriarch.tscn` | 0.90 s | 1.85 s | 3.20 s | 22 |

Times are elapsed from the real `PlayerHost.activate(player)` call. Standard modes use four `Enemy.tscn` targets and two live poison-zone telegraphs; crowded mode uses the declared weapon target cap and five telegraphs. The deterministic fixture uses seed `3936`, the shipped Player `Camera2D`, the normal ultimate HUD adapter, `field_misty_marsh.png`, and the authored Biologist scene from the class-local manifest.

## Readability observations

The active captures retain a distinct focal silhouette in every native viewport:

- World Mycelium reads through its bright branching ground network and separated mushroom blooms while the upper-right ultimate HUD remains visible.
- Perfect Sample is captured at its first actual analysis pulse (`2.20 s`, authored frame `6`), where the cyan extraction beam and endpoint glyph are distinct from player, HUD, hazard, and target layers. The frozen shown-vs-hidden native-frame probe requires at least 1,500 changed samples across a minimum `80 × 220` native-pixel bound, then restores the shipped sprite before recovery. The old `1.45 s` / frame-4 capture is rejected as pre-beam.
- Symbiote Matriarch keeps the large pod, radial tendrils, and orbiting larvae legible against both the marsh underlay and the live hazard rings.

At the smallest viewport, the runner verifies actual native dimensions rather than relying on a downscaled larger capture. At the two 1080p-class viewports, the player camera frames the player, hazards, effects, and HUD together; there is no map-edge framing substitute.

## Mode interpretation and accessibility boundary

| Mode | Runtime configuration captured | Reading result |
| --- | --- | --- |
| `normal` | `screen_shake=true`; four targets; two hazards | Baseline shipped presentation. |
| `crowded` | `screen_shake=true`; declared weapon crowd cap; five hazards | Central weapon identity remains visible under representative pressure. |
| `reduced_motion` | `screen_shake=false`; four targets; two hazards | Same release/active/recovery assertions and visual beats were retained. The delivered Biologist scenes have no class-local shake branch, so this is a configuration capture, not a claim of an added substitute effect. |
| `photosensitivity_safe` | Native declared no-repeating-fullscreen-flash strategy; four targets; two hazards | The shipped visual was rendered without a capture-only filter or scene mutation. |

No capture-only visual override was applied. The photosensitivity-safe row is evidence for the existing declared strategy: all three weapons declare `0 Hz` repeating full-screen flashes; Perfect Sample may use one non-repeating extraction flash. This is visual-review evidence, not a medical photosensitivity certification, and it does not represent a new accessibility feature or a gameplay/presentation behavior change.

## Provenance and reproduction

The pre-artifact rework harness source is commit `79ce2dc87df396691c7041ea806517645c8a0dde`, tree `88546b916c192d81371aecb7713c2b2114dc817c`. It includes the Sample Injector active-beat and native-frame readability gate, and was committed before the regenerated PNG artifacts and their manifest, avoiding self-referential evidence.

Capture environment: Godot Engine `v4.7.stable.official.5b4e0cb0f`; non-headless windowed Compatibility renderer; `OpenGL API 4.1 Metal - 90.5 - Compatibility - Using Device: Apple - Apple M4 Pro`; fixed 60 FPS on macOS.

```sh
FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_MAXWAIT=5400 FSD_GODOT_RUN_TIMEOUT=900 \
python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 \
  --script res://tests/ultimates/presentation/biologist_certification_live_capture.gd \
  -- --output-dir=res://docs/design/reference-assets-lfs/ultimate-certification/biologist
```

Run the saved-evidence integrity gate after LFS hydration:

```sh
FSD_GODOT_RUN_TIMEOUT=180 python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/biologist_certification_capture_test.gd
```

The integrity gate validates the exact 48-cell matrix, native PNG IHDR dimensions, hydrated file bytes, SHA-256/LFS identity, class-local scene mapping, runtime harness hooks, the declared active capture times, and the Sample Injector frame-and-pixel gate. Its fail-closed negative probes cover missing assets, an LFS pointer, a wrong dimension, an omitted/incorrect mode, an omitted capture, a pre-beam frame threshold, and a weakened pixel-delta threshold.

## Scope

This package adds only certification evidence, a reproducible renderer harness, and integrity checks. It does not alter production presentation, gameplay, balance, registry data, shared UI, or any class adoption behavior.
