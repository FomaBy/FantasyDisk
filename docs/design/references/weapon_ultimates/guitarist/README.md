# Guitarist weapon ultimate presentation pack

FAN-1492 adds three isolated, class-local presentation timelines. It does not
change damage, targeting, crowd-control mechanics, cooldowns, balance data, or
the shared runtime adapter.

| Weapon | Presentation | Timeline |
| --- | --- | --- |
| `electric_guitar` | Five alternating riff strips, then one crossing lightning chord | 5.40 s |
| `bass_guitar` | Pull, heavy compression, lift ripple, black-gold subwoofer shock | 5.80 s |
| `sound_amp` | Four cardinal amps, square cable wall, speaker cones, feedback overload | 6.00 s |

Each scene binds the frozen Cast IDs as `windup`, `release→execute`,
`active→active`, `recovery→recover`, and `cancel→cleanup`. Integration must
forward pause and `cancel` / `death` / `node_end` to
`WeaponUltimatePresentationTimeline`; that shared adapter remains FAN-1541.

No new raster asset was needed. The manifest records the accepted source and
runtime VFX for every weapon; vector composition supplies the new silhouettes,
so PixelLab was not invoked and no PixelLab source or export ID exists.

The integrated Guitarist executors now select every live enemy for their
primary effects (FAN-2533). The `performance.crowd_cap` values this manifest
declares are unchanged and stay a PRESENTATION budget: they bound how many
visual nodes a timeline may draw and are matched against each scene's own
`crowd_cap` metadata by the focused test below. They have never been an enemy
count, so the coverage-v2 conversion leaves them — and the scenes they are
checked against — untouched.

The four contact sheets use the actual local scenes at 648p, 720p, 1080p, and
2K. Their title placement is measured with `ThemeDB.fallback_font` before
centering; the focused test proves the measured title rectangle remains inside
the sheet at every declared resolution.

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/guitarist_ultimate_timelines.gd
python3 tools/godot_gate.py --path . \
  --script res://tests/ultimates/presentation/guitarist_ultimate_contact_capture.gd
```
