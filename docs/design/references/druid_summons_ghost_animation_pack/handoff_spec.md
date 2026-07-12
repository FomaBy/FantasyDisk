# SCRUM-1016 Animator → QA / Backend Handoff

## Runtime contract

- IDs: `druid_ghost_wolf`, `druid_ghost_bear`, `druid_ghost_panther`,
  `druid_ghost_stag`, `druid_ghost_lion`.
- Canvas/pivot: transparent `256x256`; center X `128`; shared visual baseline Y
  `232`; minimum measured exterior gutter `20px`.
- Rows: `move_left`, `move_right` (6f, 10fps, loop) and `attack_left`,
  `attack_right` (6f, 12fps, one-shot). Compatibility aliases `move` and
  `attack` resolve to the left source rows.
- Direction: west = left, east = right. The five explicit-horizontal entries
  must use their authored rows with `flip_h=false`; north/south/diagonal assets
  do not exist in this repository pack.
- `cast` resolves through the existing registry candidate contract to the
  relevant `attack_left/right` row for stag/lion.

## Ownership boundary

SCRUM-1016 integrates visuals only. SCRUM-902 owns Summon Amulet roster IDs,
spawn weighting, targeting/projectiles, damage, aura, balance and any gameplay
mechanic. Backend may select one of these exact visual IDs through
`AllyMinion.set_visual_id`; it must not rename or mirror the authored rows.

## QA evidence

- Exact PixelLab characters and 20 selected job UUIDs:
  `pixellab_job_ids.json`.
- All requests, rejected candidates and retake rationale:
  `pixellab_requests.json` and `pixellab_jobs.json`.
- Per-frame source/runtime paths, bboxes, gutters, scale and role:
  `manifest.json`.
- Automated pack result: `qa_report.json`.
- Manual all-frame review:
  `../../previews/druid_summons_ghost_animation_pack_contact.png`.
- Focused gate: `tests/animation_smoke_test.gd`.
- Full gate: `tests/runtime_smoke_test.gd`.

Independent QA must still inspect the contact sheet and runtime direction/action
selection before posting a Jira PASSED/FAILED verdict. This handoff does not
declare independent QA.
