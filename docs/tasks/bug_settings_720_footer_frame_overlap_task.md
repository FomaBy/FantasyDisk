# BUG: Settings 720p footer overlaps bottom Atlas ornament

Статус: new
Приоритет: high
Роль: Back-end (UI)
Версия: 0.2.1
Jira: SCRUM-1053
Контур: Codex
Owner: unassigned
Найдено QA при тестировании: `docs/tasks/qa_settings_batch_scrum977_task.md`

## Воспроизведение

1. Start fresh `origin/dev` `15ff065930` with Godot 4.7 Metal at 1280x720.
2. Open Settings.
3. Select Screen, Sound or Controls.
4. Inspect disabled Apply/Revert at the bottom of the inner Settings field.

## Ожидание / Реальность

Expected: the complete footer plates, labels, focus/hit areas and safety margin
remain in the empty inner field above the Atlas frame. Decorative border pixels
stay visible and unobstructed.

Actual: the footer plates extend beneath the bottom Atlas ornament and are
visibly clipped/covered. Screen is most severe; Sound and Controls reproduce
the same collision. The Game tab is safe because it hides the irrelevant
footer. 1920x1080 and 2560x1440 are clear.

This is a hard failure under `docs/process/qa_protocol.md` section “Content only
in the empty frame zone”. Existing focused/no-overlap tests pass because they
do not assert `SettingsBottomActions` against the frame-safe bottom boundary.

## Evidence

Jira SCRUM-1053 contains the three preserved Metal attachments from the
independent SCRUM-977 run:

- `settings_sound_top_1280x720.png`;
- `settings_tab2_1280x720.png`;
- `settings_tab0_1920x1080.png` (passing wide comparison).

## Fix contract

- Restrict implementation to the Settings footer/layout hunk in
  `scripts/ui_screens.gd` and focused Settings tests/docs.
- Keep Apply/Revert usable and frame-safe on Screen/Sound/Controls at 720p.
- Preserve the accepted SCRUM-1025 Game-tab `892x242` visible scroll,
  `878x520` canvas, exclusive 14px lane and hidden footer.
- Add a focused 1280x720 footer-vs-safe-area/frame regression assertion.
- Rerun the Metal 720/1080/1440 Settings matrix, UI/no-overlap/gamepad suites
  and full runtime smoke.
- Do not change SCRUM-976 sandbox persistence or combat semantics.

## Окружение

macOS, Godot 4.7 Metal, isolated QA worktree from `origin/dev` `15ff065930`.

