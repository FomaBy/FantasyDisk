# SCRUM-992 — independent QA: Artifact Reward gold hall and resolved badges

Статус: done
Приоритет: high
Роль: QA
Контур: Codex
Owner: `/root/qa_scrum992`
Thread/Worker: `/root/qa_scrum992`
Jira: SCRUM-992
Read-only implementation: SCRUM-990 and SCRUM-991 at `715fc0aba`

## Scope

Independent acceptance of the shared elite/chest/boss Artifact Reward screen,
resolved current-class descriptions, deterministic comparison badges, mandatory
choice flow and responsive frame-safe layout. Implementation files remained
read-only throughout QA.

## QA-Вердикт — 2026-07-11

Статус: PASSED

Проверено:

- fresh isolated checkout of `origin/dev` at `ca61e83e8`;
- PixelLab source/reference identity, three `ready_for_image` plans,
  compositor `ok=true`, canonical production-source reuse and independent
  review closure;
- six committed runtime captures: elite and boss at 1280x720, 1920x1080 and
  2560x1440; dimensions and visual content were checked independently;
- exactly one final hollow gold shell, no redundant panel, one non-overlapping
  three-card row, readable text and no content over decorative ornament;
- mixed modeled/unmodelled source semantics, complete Guardian/Counterwave
  conditions and cooldowns, Doctor no-op copy, unique/tie/hybrid/unsafe badge
  rules, exact selected artifact id, initial focus and mandatory no-Escape flow.

Фактические гейты через `tools/godot_gate.py`:

- `tests/scrum990_991_artifact_reward_test.gd` — PASS;
- `tests/ui_no_overlap_matrix_test.gd` — PASS;
- `tests/runtime_smoke_progression_economy_test.gd` — PASS;
- `tests/route_chest_artifact_test.gd` — PASS;
- `tests/boss_act_reward_heal_test.gd` — PASS;
- `tests/gamepad_full_flow_smoke_test.gd` — PASS, 3/3 consecutive runs;
- `tests/runtime_smoke_test.gd` — PASS, exit 0 (known dummy-renderer screenshot
  diagnostic did not affect the verdict);
- regression: `animation_smoke_test.gd`, `meta_progression_smoke_test.gd`,
  `melee_weapon_targeting_test.gd` — PASS.

Краевые случаи: live resize 2560x1440 -> 1280x720 -> 1920x1080 for both reward
flows; compact long Counterwave copy; exact positive tie; unsafe effect; hybrid
winner; Doctor-blocked sustain; duplicate/stale choose continuation.

Баги: нет.

Disk cleanup: disposable QA `.godot` cache, generated UID sidecars, worktree and
local QA branch removed after Jira/Git synchronization.
