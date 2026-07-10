# SCRUM-990 — Artifact Reward gold-frame hall

Статус: done
Контур: Codex
Owner: `/root/scrum990_artifact_reward`
Combined scope: `SCRUM-990` + `SCRUM-991`
Locked screen: elite/chest/boss Artifact Reward only.

## Contract

- One hollow shared gold shell and the polished reward-hall background.
- No redundant central ornamental panel.
- Three cards remain in one row and inside the true shell inner rect at
  1280×720, 1920×1080 and 2560×1440, including live resize.
- Existing elite/chest/boss grant and return callbacks remain intact.

## Work evidence

- UI plans: `ready_for_image`, zero errors/warnings at all target viewports.
- PixelLab MCP config smoke: PASS; source `3929f7e7-8182-495e-a794-7565cb51afda`
  was reviewed as the required textless composition reference.
- Production asset decision: explicit reuse of the canonical reward-hall
  background and `meta40/frame_border.png`; no generated bitmap promotion.
- Runtime matrix: six captures (elite/boss at 1280×720, 1920×1080 and
  2560×1440), all with the exact shell inner rect, one three-card row and the
  hollow mouse-ignore frame as the final child.
- Verification PASS: `scrum990_991_artifact_reward_test.gd`,
  `ui_no_overlap_matrix_test.gd`, `runtime_smoke_progression_economy_test.gd`,
  `route_chest_artifact_test.gd`, `boss_act_reward_heal_test.gd`,
  `gamepad_full_flow_smoke_test.gd`, and `runtime_smoke_test.gd`.

Disk cleanup: removed task `.godot` import cache (445 MB), Python caches and
unrelated import-generated UID sidecars; only the task capture tool UID is kept.
