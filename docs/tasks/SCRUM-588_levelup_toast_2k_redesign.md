# SCRUM-588: UI-редизайн: Тост повышения уровня (@2K, раскладка -> генерация)

Jira: SCRUM-588
Статус: done
Контур: Codex
Owner: design-codex-SCRUM-588
Thread: design-codex-SCRUM-588
Locked paths: `scripts/level_up_toast.gd`, `scripts/ui/ui_theme_paths.gd`, `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png`, `docs/design/mockups/scrum588_levelup_toast/`, `docs/design/references/scrum588_levelup_toast/`, `docs/design/previews/scrum588_levelup_toast_safe_zone.png`, `tests/level_up_toast_smoke_test.gd`, relevant UI smoke/no-overlap sections.

## Result

- Generated an OpenAI API mockup and isolated source frame for the level-up toast.
- Added runtime frame `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png` (`480x300`, transparent RGBA, edge alpha 0).
- Registered `lut_toast` in `UIThemePaths.OVERHAUL_2K_FRAME_*`.
- Updated `LevelUpToast` to render a textless framed sparkle/ring accent inside strict content margins `70/112/70/112`.
- Kept the existing world-space `LevelUpEffect` badge as the only visible `Level Up` text/icon callout.

## Evidence

- Mockup/spec: `docs/design/mockups/scrum588_levelup_toast/spec.md`
- Mockup PNG: `docs/design/mockups/scrum588_levelup_toast/mockup.png`
- Runtime asset audit: `docs/design/mockups/scrum588_levelup_toast/asset_audit.json`
- Safe-zone preview: `docs/design/previews/scrum588_levelup_toast_safe_zone.png`

## Validation

- `tests/level_up_toast_smoke_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `tests/runtime_smoke_ui_test.gd`

## Disk Cleanup

Temporary generation artifacts were not kept outside the project. Generated source/reference, preview, audit and runtime files are intentional evidence or deliverables.
