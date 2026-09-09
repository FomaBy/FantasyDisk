## FAN-3937 Chemist ultimate certification

This package certifies the three canonical Chemist ultimates in the shipped
presentation scenes. It is a capture-and-review artifact only: it does not
change production scenes, gameplay, balance, HUD behavior, overlays, or
adoption paths.

The certification renderer is
`tests/ultimates/presentation/chemist_certification_live_capture.gd`. It
fails if started headless and creates its PNGs only from a windowed Godot
render. Every matrix cell contains a shipped Chemist V2 presentation scene,
the shipped ultimate-HUD widget with a production view-model state, the
Chemist player visual, live victim-impact targets, and project hazard art.

## Capture provenance

| Field | Value |
| --- | --- |
| Source ref / commit / tree | `dev` / `d192be10bbe52dd89971cab0acc66eb92ccab37f` / `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf` |
| Engine / renderer | Godot `4.7.stable.official.5b4e0cb0f` / `gl_compatibility` |
| Deterministic seed | `3937` |
| Windowed capture command | `FSD_GODOT_RUN_TIMEOUT=600 python3 tools/godot_gate.py --quiet --path . --windowed --script res://tests/ultimates/presentation/chemist_certification_live_capture.gd` |
| Output root | `docs/design/reference-assets-lfs/ultimate-certification/chemist` |

The initial checkout's import cache was warmed through `tools/godot_gate.py`.
The final renderer ran in a normal gated windowed slot because an unrelated
workspace probe held the machine-wide exclusive lane; no headless output was
used as image evidence.

## Coverage and assessment

Each output is a 3×4 matrix: rows are `blast_powder`, `acid_flask`, and
`homunculus_vial`; columns are `normal`, `crowded`, `reduced_motion`, and
`photosensitivity_safe`. Normal, reduced-motion, and photosensitivity-safe
cells contain three real victim probes. Crowded cells use the declaration's
actual cap: 18, 16, and 14 respectively.

| Weapon | Release / active / recovery checks | Normal and crowded read | Reduced motion / photosensitivity-safe read |
| --- | --- | --- | --- |
| `blast_powder` | 0.95s / 1.45s / 3.15s | Gold pentagram remains distinct; the 18-target cell visibly shows the denser live-impact field. | `screen_shake` is off for reduced motion; the safe cell removes the instantiated veil and identifies that state in its persistent caption. |
| `acid_flask` | 0.85s / 1.20s / 3.55s | Flask, acid lake, player lane, and hazard lane remain separated; the 16-target cell visibly carries additional impact feedback. | The reduced variant keeps the damped shipped fade without shake; the safe cell has the veil disabled. |
| `homunculus_vial` | 0.90s / 2.85s / 3.65s | Fusion silhouette stays centered and distinct; the 14-target cell visibly has the largest target-feedback cluster. | The reduced state turns shake off; the safe state removes the veil while retaining the readable fusion silhouette. |

The focused gate runs all 144 release/active/recovery combinations
(4 viewports × 3 weapons × 4 modes × 3 beats). It verifies that each cell uses
the actual animation timeline and required scene nodes; contains visible
non-backdrop content in the reserved effect zone; keeps player, hazard, and
caption bands outside that zone; reads the shipped `screen_shake` setting; and
uses the real victim-impact player. It also fail-closes for a missing mode,
provenance field, image file, LFS pointer, wrong dimension, or wrong SHA-256.

The final chrome pass deliberately draws the mode/state captions after each
arena viewport. Shipped victim-impact sprites are top-level so their crowded
feedback is visible; the chrome pass keeps the evidence caption readable above
that feedback instead of hiding it.

## Native outputs

| ID | Native dimensions | SHA-256 |
| --- | --- | --- |
| `648p` | 1152×648 | `e905865252e3e1fd6e1a59b39979b4ee61ab3e798e38a3aea620793c754c707a` |
| `720p` | 1280×720 | `a12b7d13f8ae36afda937861a6901949ba04e6c225c07bd24c5fecd90b1a0afc` |
| `1080p` | 1920×1080 | `59b8b0097d26b97bab31fd4a456c301902c9a27d7ea111ff4148ba26113fb000` |
| `2k` | 2560×1440 | `406236f888a51bff72de1520f1a890298ff3ba6bdfb297bc12860dc0ddb8102b` |

Native visual inspection covered the 1152×648 and 2560×1440 sheets. At the
smallest sheet, all twelve panel headers, colored mode markers, HUD, player
lane, hazard lane, and persistent state captions remain visible; at 2K the
same labels and fixture bands have clear separation. The four native images
and their hashes are recorded in
`certification_capture_manifest.json` and are Git LFS assets.

## Verification performed

```text
python3 tools/godot_gate.py --headless --quiet --path . --script res://tests/ultimates/presentation/chemist_certification_capture_test.gd
python3 tools/godot_gate.py --headless --quiet --path . --script res://tests/ultimates/presentation/chemist_ultimate_timelines.gd
python3 tools/godot_gate.py --headless --quiet --path . --script res://tests/ultimates/presentation/visual_direction_contract_test.gd
python3 tools/godot_gate.py --headless --quiet --path . --script res://tests/ultimates/presentation/weapon_ultimate_presentation_budget_test.gd
python3 tools/godot_gate.py --headless --quiet --path . --script res://tests/ultimates/presentation/weapon_ultimate_contact_sheet_beats_test.gd
python3 tools/godot_gate.py --headless --quiet --path . --script res://tests/ultimates/presentation/weapon_ultimate_timing_distinctness_test.gd
```

All commands above passed after Git LFS hydration. The headless commands are
integrity and runtime gates only; the certification images themselves come
from the separate windowed renderer.

## Review limits

The contact sheets are deterministic active-beat stills. They show spatial
readability and the declared mode state; they do not attempt to show temporal
camera shake or audio ducking in a single frame. The focused runtime gate
covers release, active, and recovery timing and verifies the production mode
settings independently. Reviewers should use the windowed sheets for visual
readability and the gate output for phase and mode behavior.
