# SCRUM-924 — Holy Flail expanding-spiral VFX

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: `/root/animator_loop_924`
Thread/Worker: `/root/animator_loop_924`
Jira: SCRUM-924

## Scope

Replace the obsolete instant-circle presentation with a readable centre-out
holy chain spiral matching the already accepted SCRUM-923 gameplay contract.
Damage, timing, radius, target deduplication and balance remain unchanged.

## Result

- PixelLab object `b1089fd9-a4c7-49ce-aec2-af62fb0317b6`, v3 group
  `50cb9b87-58b3-411e-af3e-caabce8b4cb4`, animation
  `0ff0ce1e-e95c-409a-b542-e50b606fd928` provide eight transparent-source
  holy-flail motion frames.
- Runtime uses a scene-specific `HolyFlailWeapon` bridge and isolated
  `HolyFlailSpiralVfx`; the shared `BerserkWeapon` implementation is untouched.
- Every live step advances the PixelLab frame and grows a curved chain from the
  hero centre to the exact active front. The seventh step closes one turn at
  the full `235px` radius.
- Frame QA: all runtime frames are `256x256 RGBA`, alpha max `190`, gutter
  `>=16px`, no edge-visible pixels, stable centre pivot `(128,128)`.
- Preview: `docs/design/previews/scrum924_holy_flail_spiral_vfx_contact.png`.
- Live runtime capture:
  `docs/design/previews/scrum924_holy_flail_spiral_vfx_runtime.png` (inner,
  mid and outer-closure geometry from the actual Godot VFX scene).
- Verification PASS through `tools/godot_gate.py`:
  `scrum924_holy_flail_spiral_vfx_test.gd`, `knight_kit_test.gd`,
  `attack_vfx_smoke_test.gd`, `unique_weapon_vfx_assets_test.gd` (51 plates),
  and `runtime_smoke_test.gd`. Runtime smoke emitted its pre-existing dummy
  renderer null-texture diagnostic during screenshot fallback, then printed
  `Runtime smoke test passed.` and exited `0`.
- Disk cleanup: pending final routing.
