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
