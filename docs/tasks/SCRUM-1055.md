# SCRUM-1055 Pause confirmation text fit

Статус: done
Версия: 0.2.1
Jira: SCRUM-1055
Контур: Codex
Owner: Back-end/root
Thread: /root
Locked paths: `scripts/ui_screens.gd` End Run confirmation, focused/runtime tests, related UI docs/spec

## Scope

- Keep the final soft sign in `Завершить` fully visible.
- Treat `Завершить` and `Отмена` symmetrically.
- Preserve the accepted modal frame, safe content zone, focus, Escape/B and
  destructive-action behavior.

## Decision

Use equal 240x72 native slots (`text/continue_240x72`) for both actions instead
of reducing readability. The 600px panel fits 240 + 18 + 240 inside its content
zone.

## Verification

- PASS `tests/scrum1055_end_run_confirmation_fit_test.gd` at 1152x648,
  1280x720, 1920x1080, and 2560x1440.
- PASS `tests/runtime_smoke_ui_test.gd`, `tests/gamepad_inrun_ui_test.gd`, and
  full `tests/runtime_smoke_test.gd`.
- All five visual states keep a 146px content lane. Runtime font tiers are 21px,
  22px, and 23px; every state satisfies `rendered width + 4px <= content width`.
- The 498px button pair stays centered in the 544px worst-case modal inner zone,
  with exact 18px gap and unchanged 600x340 panel.
- Disk cleanup: generated `.gd.uid` sidecars and worktree `.godot/` cache removed after final gates.
- Thread cleanup: not a disposable worker thread.

## Independent production QA

- Verdict: **PASSED** on fresh `origin/dev` `784f03c7233808bb58e23a7c739b7b46f95e60dd`; implementation commit `0286b05970ff486b4de145d0255fdb3244265687` is an ancestor.
- Static review confirmed the corrective diff is limited to the End Run confirmation contract, its focused/runtime oracles, and matching documentation. Destructive behavior, Escape/B cancellation, outside-click cancellation, modal size and safe Cancel focus are preserved.
- Metal captures at 1152x648, 1280x720, 1920x1080 and 2560x1440 confirmed complete `Завершить`/`Отмена` labels, equal 240x72 plates and hitboxes, an exact 18px gap, stable centering, and no contact with panel/frame decoration.
- PASS: `tests/scrum1055_end_run_confirmation_fit_test.gd`, `tests/runtime_smoke_ui_test.gd`, `tests/ui_no_overlap_matrix_test.gd`, `tests/scrum983_escape_dossier_test.gd`, `tests/gamepad_inrun_ui_test.gd`, `tests/gamepad_menu_focus_test.gd`, `tests/gamepad_full_flow_smoke_test.gd`, and full `tests/runtime_smoke_test.gd` through `tools/godot_gate.py` under isolated HOME/XDG.
- The dummy-renderer null-texture screenshot diagnostic in `runtime_smoke_ui_test.gd` and full smoke is pre-existing and non-fatal; both gates exited 0.
- QA worker: `/root/qa_scrum1055`; disk cleanup removed temporary Metal captures/script, generated untracked UID sidecars, isolated HOME/XDG data, and the disposable QA worktree after routing.
