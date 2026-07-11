# SCRUM-977 — Settings batch umbrella QA

Статус: done
Версия: 0.2.1
Jira: SCRUM-977
Контур: Codex
Owner: QA/Codex `/root/scrum977_umbrella`
Locked paths: released; production Settings/runtime paths were read-only

## Scope

Release-gate verification for the Settings batch delivered by SCRUM-972,
SCRUM-974, SCRUM-975, SCRUM-976 and SCRUM-1025: seamless frame surface,
monitor/video behavior, expanded Sound controls, four-tab Game page, persisted
sandbox modifiers, next-run snapshot semantics and neutral gameplay regression.

## QA-Вердикт (2026-07-11)

Статус: FAILED

Fresh baseline: `origin/dev` `15ff065930`, including the landed SCRUM-1025
implementation and Jira routing. All production code, assets, implementation
tests and dependency evidence were inspected read-only.

Passed functional and regression coverage:

- Display: deterministic one-monitor and virtual three-monitor visibility,
  labels, clamping, Apply/Revert, persistence/restart; video entries and
  resolution behavior.
- Sound: all four volume controls, two real toggles, persistence, eight-key
  Reset, `UI -> SFX -> Master`, focus mute/restore, low-HP requested/effective
  loop behavior and audio integration.
- Game: four tabs, compact 2x2 and wide 4x1 navigation, five authoritative
  ranges, neutral/custom status, immediate persistence, atomic Reset,
  next-run-only immutable snapshot and compact focus-scroll.
- Gameplay: exact ordinary/summoned/elite/boss HP, outgoing damage and cadence
  factors; player damage/attack speed; neutral parity; custom progression and
  balance-evidence guards.
- UI/input/regression: runtime UI, no-overlap matrix, dark-fantasy theme,
  gamepad menu/settings/full-flow, progression/economy, combat, asset integrity
  and full runtime smoke all exited `0`. The familiar headless dummy-renderer
  null-texture diagnostic remained non-fatal.

Windowed Godot 4.7 Metal capture suites ran at 1280x720, 1920x1080 and
2560x1440 for the seamless Settings shell, Sound page and Game page. Wide
layouts and the Game compact page are frame-safe. At 1280x720, however,
`SettingsBottomActions` on Screen, Sound and Controls extends beneath the
bottom Atlas ornament; the Apply/Revert plates are visibly clipped/covered.
This violates the mandatory content-only-in-empty-frame-zone acceptance rule.
Game is unaffected because SCRUM-1025 intentionally hides the irrelevant
Screen footer on that tab.

Evidence is attached to Jira SCRUM-1053:

- `settings_sound_top_1280x720.png` — Sound footer/frame collision;
- `settings_tab2_1280x720.png` — Controls footer/frame collision;
- `settings_tab0_1920x1080.png` — wide Screen comparison.

Commands used the semaphore wrapper with isolated `HOME`, `XDG_DATA_HOME` and
`user://` roots:

- focused Settings/Display/Audio/Game/Sandbox suites;
- `tests/runtime_smoke_ui_test.gd`;
- `tests/ui_no_overlap_matrix_test.gd`;
- `tests/gamepad_menu_focus_test.gd`;
- `tests/gamepad_settings_rebind_test.gd`;
- `tests/gamepad_full_flow_smoke_test.gd`;
- `tests/dark_fantasy_ui_theme_test.gd`;
- `tests/runtime_smoke_progression_economy_test.gd`;
- `tests/runtime_smoke_combat_test.gd`;
- `tests/asset_reference_integrity_test.gd`;
- `tests/runtime_smoke_test.gd`.

Баги: SCRUM-1053 — 720p Settings footer overlaps the bottom Atlas ornament.
SCRUM-977 remains blocked until that bug is fixed and the 720p Metal matrix is
rechecked. No implementation was changed during QA.

Disk cleanup: disposable Metal captures, `.godot`, isolated HOME/XDG/userdata
roots, worktree and local branch are removed after the evidence commit is
pushed and Jira is released from stale `В работе`.

## Финальный QA-Вердикт после SCRUM-1053 (2026-07-11)

Статус: PASSED

Fresh current source: `origin/dev` `c19474b3a`. All dependencies are accepted
in Jira: SCRUM-972, SCRUM-974, SCRUM-975, SCRUM-976, SCRUM-1025 and the footer
blocker SCRUM-1053 are `Готово`. The tested HEAD contains SCRUM-1053 fix
`c47ca182c`, its independent QA routing `239050313`, the SCRUM-1025
implementation/documentation corrections and later current-dev UI changes.

Proportional final re-verification passed without production edits:

- `tests/settings_footer_scrum1053_test.gd`, headless and Godot 4.7 Metal;
- `tests/settings_game_scrum1025_test.gd`, headless and Metal;
- `tests/settings_scrum972_seamless_content_test.gd`;
- `tests/settings_audio_scrum974_ui_test.gd`;
- `tests/ui_no_overlap_matrix_test.gd`;
- full `tests/runtime_smoke_test.gd` (the known non-fatal headless
  dummy-renderer null-texture diagnostic only).

Metal captures were inspected at the fixed compact boundary. At 1280x720,
Screen, Sound and Controls now keep the complete Apply/Revert plates, text and
hit regions above the Atlas bottom ornament with the authored reserve visible.
The Game tab remains unchanged and safe: footer hidden, `892x242` visible
scroll, `878x520` canvas and exclusive `14px` scrollbar lane. The focused
SCRUM-1053 suite also covered 1280x760, 1920x1080 and 2560x1440; no overlap or
clipping returned.

The first FAILED verdict above remains as historical evidence of the defect
that led to SCRUM-1053. The release gate is now green; bugs: none open for this
acceptance scope.

Disk cleanup: final `.godot`, Metal captures, isolated `/tmp/fsd-scrum977-*`
HOME/XDG/userdata/log roots, generated UID sidecars, disposable worktree and
local branch are removed after this evidence is pushed and Jira is closed.
