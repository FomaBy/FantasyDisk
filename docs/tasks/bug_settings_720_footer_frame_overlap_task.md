# BUG: Settings 720p footer overlaps bottom Atlas ornament

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.2.1
Jira: SCRUM-1053
Контур: Codex
Owner: Back-end/Codex `/root/fix_scrum1053`
Thread/Worker: `/root/fix_scrum1053`
Locked paths: Settings footer/layout hunk in `scripts/ui_screens.gd`; focused
SCRUM-1053 regression test; this mirror; Settings footer paragraphs in
`docs/design/current_game_state.md` and `docs/design/systems/menus_ui.md`
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

## UI Director / Mockup gate

No new art or visual direction is required. The fix reuses the already accepted
PixelLab/UI Director package
`docs/design/mockups/scrum972_settings_seamless_content/`: its canonical footer
zone is inside the empty Atlas field and its responsive contract explicitly
requires footer actions to remain clear of the outer ornament. The fourth-tab
package `docs/design/references/scrum975_settings_game_tab/spec.md` remains the
authoritative compact Game geometry; its `892x242` runtime scroll and hidden
footer must not move. SCRUM-1053 only restores the first accepted contract for
Screen/Sound/Controls, so regenerating the accepted page art would add no design
information.

## Result (2026-07-11)

- Runtime now gives Screen/Sound/Controls a structural `88px` compact footer
  slot: `64px` native plates + `24px` empty Atlas reserve. Compact Screen is
  vertically scrollable so preserved native row minima cannot overflow the
  slot. The complete wrapper collapses on Game.
- Actual 1280x720 Metal geometry: `SettingsContentPanel=[160,353,960,154]`,
  `SettingsBottomActions=[160,519,960,64]`,
  `gold_shell_inner_rect=[157,137,966,446]`. The content/footer gap is `12px`;
  footer and inner boundary both end at `y=583`; the outer texture-safe edge is
  `y=607`.
- SCRUM-1025 remains unchanged: Game uses `892x242`, `878x520`, 14px lane and
  no footer. No SCRUM-976 persistence/combat code was touched.
- Independent read-only review: PASS after the structural correction; it
  separately reran the new focused test and SCRUM-972.

Verification (isolated HOME/XDG through `tools/godot_gate.py`):

- Godot 4.7 Metal: `tests/settings_footer_scrum1053_test.gd` at 1280x720,
  1280x760, 1920x1080 and 2560x1440 — PASS; Screen/Sound/Controls captures
  inspected frame-safe.
- Headless PASS: SCRUM-1053 focused; SCRUM-972 seamless; SCRUM-1025 Game;
  SCRUM-974 Sound UI; runtime UI; UI no-overlap; gamepad settings/menu/full
  flow; full `tests/runtime_smoke_test.gd` (known dummy-renderer null-texture
  diagnostic only).

Next owner/status: independent QA; Jira remains out of `Готово` until
that QA passes.
