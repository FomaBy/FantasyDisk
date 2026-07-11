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
