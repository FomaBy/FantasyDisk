# Dark Mage weapon ultimate presentation pack

This class-local package authors three presentation timelines for the frozen
`dark_mage/dark_book`, `dark_mage/cursed_skull`, and `dark_mage/dark_wand`
ultimate profiles. It changes no gameplay, balance, shared manifest, registry,
resolver, controller, or runtime adapter.

## Visual identities

| Weapon | Title | Silhouette | Motion | Impact |
| --- | --- | --- | --- | --- |
| `dark_book` | Зеркало Бездны | open grimoire, vertical black mirror, opposed enemy shadows | mirror unfolds and separates original/reflection across its axis | one synchronized violet pair detonation |
| `cursed_skull` | Корона Проклятых | giant raised skull crown with three hanging chains | crown ascends while soul wisps relay between chained targets | the crown jaw harvests every remaining mark |
| `dark_wand` | Нить Исчезновения | one thin zigzag spine with branching nodes | the wand draws a forward line and adds filaments through targets | all nodes contract into black afterimages at once |

The scenes are not a ring-only template or three color variants. Their
silhouettes, paths, rhythms, and impact shapes are different scene geometry, and
the focused test fails if their declarations or timing signatures collapse.

## Frozen phase bindings

Values are phase start times. The profiles on `dev` are still
`implementation_state = "declared"` with unbound strategies and empty params,
so this pack binds presentation to the immutable Cast phase IDs rather than to
nonexistent numeric mechanics windows.

| Weapon | windup | release → execute | active → active | recovery → recover | cancel → cleanup |
| --- | ---: | ---: | ---: | ---: | ---: |
| `dark_book` | 0.00 | 0.60 | 1.05 | 4.55 | 5.20 |
| `cursed_skull` | 0.00 | 0.85 | 1.35 | 5.55 | 6.35 |
| `dark_wand` | 0.00 | 0.28 | 0.62 | 3.25 | 3.85 |

Every total stays below the schema cap of 10 seconds. Mechanics values,
reflection recursion, curse transfer, target ramping, and damage remain owned by
FAN-1479.

## Assets and runtime boundary

No new raster source was needed. The scenes reuse the accepted 256×256 weapon
sprites and attack-VFX textures for all three IDs. Those VFX assets retain their
historical explicit OpenAI generator override and source records under
`docs/design/references/weapon_attack_animations/`; no PixelLab object was
created, so there is no new PixelLab ID. `manifest.json` records source
references, immutable runtime paths, SHA-256 digests, SFX paths, pivots, and the
three class-local scene paths.

The shared `weapon_ultimate_presentation_manifest.gd` remains untouched.
FAN-1541 owns the adapter that will bind these class-local scenes by exact weapon
ID. That adapter must forward pause and call
`WeaponUltimatePresentationTimeline.finish("cancel"|"death"|"node_end")`.

## Readability and budgets

Four contact sheets are rendered from the actual scenes at 648p, 720p, 1080p,
and 2K. The capture test fits every visible item into a labeled content zone and
requires the identity-defining nodes to remain visible. Per-cast scene caps are
7/12 nodes for the book, 8/14 for the skull, and 8/10 for the wand
(`max_visual_nodes` / `crowd_cap`). Runtime crowd enforcement remains owned by
FAN-1541.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/dark_mage_ultimate_timelines.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation_contract_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation_contract_validator_test.gd
```

The focused test verifies frozen IDs, required channels, monotonic timing,
lifecycle pause/cleanup, distinct silhouettes/paths/rhythms/impacts, scene
length, pivots, visual-node budgets, and the four evidence resolutions.
