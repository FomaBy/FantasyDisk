# SCRUM-895 — Berserk Axe/Hammer attack readability

Статус: in_progress
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: `/root/animator_loop_924`
Thread/Worker: `/root/animator_loop_924`
Jira: SCRUM-895

## Animator scope

- Keep Sword entirely unchanged.
- Make every Axe sweep show a readable two-handed axe ghost and an arc aligned
  with the accepted `180° / 250px` attack.
- Make Hammer show an overhead weapon, ground impact and shock/dust aligned to
  the actual close-AoE center/radius.
- Use PixelLab MCP sources/animation, isolated scene-specific visual bridges,
  transparent runtime frames, contact/runtime captures and focused tests.
- Do not edit shared damage, targeting, cooldown, growth or balance code.

## Backend dependency

The lower-side Hammer hit-zone correction is split Jira-first to SCRUM-1043.
Animator does not change hit membership. The Hammer visual bridge consumes an
optional backend `_circle_attack_center()` / `_circle_attack_visual_scale()`
contract and otherwise uses the current owner center / unit scale.

## Evidence

- Axe PixelLab: object `d5452069-7d6e-4646-8b9d-379f0c332f17`, v3 group
  `7e9c7287-d8f0-4461-844e-c1e0bfc5e817`, animation
  `b318ca47-840b-49d4-ab74-32be1d0c9c5a`.
- Hammer PixelLab: object `b1fed1f3-71b6-47d5-a1eb-e3e4b8db65b5`, v3 group
  `4515832c-5217-444d-a1a4-b25f1090d435`, animation
  `11ced058-204f-48dc-bfcb-c0aee7665917` (impact frame 5).
- Source/contact: `docs/design/references/scrum895_berserk_axe_hammer_vfx/`
  and `docs/design/previews/scrum895_berserk_axe_hammer_pixellab_contact.png`.
- Actual Godot runtime capture:
  `docs/design/previews/scrum895_berserk_axe_hammer_runtime.png`.
- PASS: focused SCRUM-895 smoke, animation smoke, attack-VFX smoke,
  runtime weapon mechanics, Berserk DPS runaway and full runtime smoke.
- Parent remains `in_progress` until backend SCRUM-1043 lands the lower-side
  Hammer membership fix and the combined gate is rerun.
- Disk cleanup: pending final combined routing.
