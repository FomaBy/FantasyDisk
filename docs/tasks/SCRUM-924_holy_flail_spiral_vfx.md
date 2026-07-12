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

## QA-Вердикт (2026-07-11)

Статус: PASSED

Независимый QA проверил `origin/dev` `1bfebaa71` с implementation
`bd838e434` и routing `690cff7f8`. Production-код в QA не
изменялся.

Проверено:

- PixelLab provenance совпадает с manifest: object
  `b1089fd9-a4c7-49ce-aec2-af62fb0317b6`, group
  `50cb9b87-58b3-411e-af3e-caabce8b4cb4`, animation
  `0ff0ce1e-e95c-409a-b542-e50b606fd928`; OpenAI/manual fallback не
  использовался;
- независимый pixel/hash audit всех восьми runtime PNG: 256×256
  RGBA, `edge_visible_pixels=0`, minimum gutter 20–25 px, max alpha 190,
  SHA-256 совпадает с report;
- `tests/scrum924_holy_flail_spiral_vfx_test.gd` — PASS: 7 шагов по
  0.085 s, radius 22%→235 px, one-turn centre-out geometry, exact active
  front, frame-per-step, 29 chain samples и isolation sibling weapons;
- `knight_kit_test.gd`, `attack_vfx_smoke_test.gd`,
  `unique_weapon_vfx_assets_test.gd` (51 plates), `animation_smoke_test.gd`
  и `runtime_smoke_test.gd` — PASS; full runtime duplicate guard scanned
  14,798 files;
- свежий Metal/OpenGL 4.1 capture и PixelLab contact sheet проверены
  вручную: inner/mid/outer closure читается, растёт от центра,
  не подменена ring/beam, не клипается и не скачет по pivot;
- diff подтверждает, что `scripts/berserk_weapon.gd`, ProgressionData,
  damage/timing/radius/dedup/balance не менялись; scene-specific subclass
  вызывает `super` и добавляет только visual-only VFX.

Краевые случаи: first/last step, monotonic all-step geometry, exact outer
closure, stale-VFX replacement на step 0, LongSpear/TowerShield isolation,
fresh import и all-weapon equip в full runtime.

Баги: нет.
