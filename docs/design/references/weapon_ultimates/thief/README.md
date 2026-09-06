# Thief weapon ultimate presentation pack

This class-local pack presents the three frozen Thief weapon IDs without
changing gameplay, balance, the shared manifest, or the eventual runtime
adapter. It reuses the accepted transparent PixelLab weapon-signature plates;
no new isolated PNG was generated for this issue.

| Weapon | Timeline | Silhouette | Motion | Impact |
| --- | --- | --- | --- | --- |
| `thief_coin_pouch` | Джекпот Короля | gold coin burst and pouch | 13 staggered ricochets across a zig-zag target field, returning as a crown | inward gold jackpot |
| `thief_shadow_cloak` | Безмолвный Приговор | violet cloak/dagger crescent | 8 marked positions receive sequential phantom stabs | tightening red-line collapse |
| `thief_smoke_bomb` | Идеальное Ограбление | blue-grey smoke dome | central cover expands while 6 edge pressure marks drift, then collapses | outward snap burst |

## Frozen phase bindings

Each timeline covers `[windup] [release] [active] [recovery] [cancel]` and
reads its exact phase IDs from `data/ultimates/schema/v1/classes/thief.json`:
`windup -> windup`, `release -> execute`, `active -> active`,
`recovery -> recover`, `cancel -> cleanup`. Timelines are 4.85 s, 3.74 s, and
5.82 s respectively, each inside the schema limit of 10.0 s. These are
presentation rhythms, not mechanics or damage windows.

## Lifecycle and budgets

`thief_ultimate_timeline_scene.gd` delegates to
`WeaponUltimatePresentationTimeline`: `begin()`, `set_paused()`, and
`finish("cancel"|"death"|"node_end")` are covered by the focused test. One cast
is bounded to 13 sprites (13 coins, 8 shadow marks, 7 dome marks), and the
test samples all phases at 648p, 720p, 1080p, and 2K readability scales.

## Evidence

`contact_sheet_thief_ultimates.png` has 15 columns × 3 rows: five phases with
three samples each, ordered `thief_coin_pouch`, `thief_shadow_cloak`,
`thief_smoke_bomb`. It is rendered headlessly from the same
`formation_points()` function the local timeline scene uses.

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/thief_ultimate_presentation_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://scenes/vfx/ultimates/thief/thief_ultimate_contact_sheet.gd
```

The shared `scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd`
remains intentionally untouched; FAN-1541 owns shared runtime integration.

## FAN-3890 four-viewport victim-impact capture

`fan3890_capture_manifest.json` is a separate, reproducible evidence package
for the integrated Thief victim-impact delivery. Its four Git-LFS PNG sheets
each contain the same 3 × 4 matrix: the canonical Coin Pouch, Shadow Cloak,
and Smoke Bomb scenes in normal, crowded, reduced-motion, and
photosensitivity-safe presentation. The windowed renderer samples shipped
timeline scenes and the current per-victim flipbooks, then freezes the sampled
frame so the player HUD and hazard read remain reviewable.

```bash
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --windowed \
  --script res://tests/ultimates/presentation/thief_ultimate_four_viewport_capture.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/thief_ultimate_four_viewport_capture_test.gd
```

The new manifest pins the FAN-3886 integration and capture-base SHA/tree,
canonical IDs, modes, viewport sizes, and LFS object IDs. It intentionally
does not alter the legacy class manifest or shared adoption registry; those
remain owned by their dedicated contract work.
