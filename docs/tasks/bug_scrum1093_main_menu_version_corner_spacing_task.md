# Main Menu: tighten the lower-right version cluster at large resolutions

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1093
Контур: Codex
Owner: Back-end / Codex subagent
Thread: /root/scrum1093_main_menu_version
Locked paths: `scripts/ui_screens.gd`, Main Menu utility-cluster tests, `docs/design/mockups/scrum1093_main_menu_version_corner/**`, `docs/design/previews/scrum1093_main_menu_version_corner/**`, this mirror and relevant UI docs

## Context

The user-provided large-resolution screenshot shows that the visible version
text remains too far from the lower-right yellow rail. The icon is technically
left of `MainMenuVersionLabel`, but the label's oversized empty width creates a
large visual gap between the icon and the glyphs.

This is a follow-up regression bug to `SCRUM-1080`. Existing production art,
callbacks, focus graph, tooltip/accessibility metadata and SFX stay unchanged.

## Required change

- Keep the version dynamically sourced from `application/config/version`.
- Size the runtime version rect from the actual rendered string instead of a
  large fixed placeholder width.
- Anchor the compact utility cluster to a dedicated lower-right rail-safe point,
  closer to the real frame opening than the general page `inner_rect`.
- Keep the bounded glow and icon immediately left of the visible version text.
- Update the accepted source-reuse mockup/spec before runtime implementation.

## Acceptance criteria

- The cluster is visually compact at 1280×720, 1920×1080, 2048×1152 and
  2560×1440, including live resize.
- The visible version sits immediately before the lower-right yellow frame with
  at least 8 px reserve from the authored frame-safe boundary.
- The visible icon-to-version gap is no larger than the documented compact tier
  and contains no oversized hidden label area.
- No content overlaps the frame rails, corner ornaments or other Main Menu
  controls.
- Focus, callback, tooltip/accessibility metadata, SFX and dynamic version
  behavior remain unchanged.
- Focused Main Menu, gold-shell, no-overlap, UI smoke and full runtime smoke
  tests pass.

## Evidence input

- User screenshot:
  `docs/design/references/scrum1093_main_menu_version_corner/user_large_resolution_before.png`.
- Existing accepted PixelLab-lineage art/package reused from
  `docs/design/mockups/scrum1081_main_menu_bottom_corners/`; no new production
  bitmap is required.

## Result

- `MainMenuVersionLabel` now uses the measured live string width plus 6 px
  effect reserve instead of a fixed empty 128–184 px placeholder and never
  silently clamps a future semantic version.
- The compact cluster anchors to `frame_safe.end - Vector2(8,8)` with an exact
  4 px glow-to-label rect gap and tested `0..20 px` hitbox-to-glyph gap.
  Icon/glow/font tiers remain unchanged.
- Logo/actions keep the conservative authored inner rect; no production art,
  callback, focus, tooltip/accessibility or SFX behavior changed.
- Added the user's 2048×1152 tier and a future-version regression using
  `v0.2.10-beta`.
- Source-reuse package:
  `docs/design/mockups/scrum1093_main_menu_version_corner/` and
  `docs/design/previews/scrum1093_main_menu_version_corner/`; all six UI plans
  are `ready_for_image` with zero errors/warnings and all six text layout guides
  are `ok=true`. PixelLab provenance is Gratitude object
  `c1c1c353-e56e-405b-9adf-f1e6bd993152`; production bitmaps are unchanged.
- Runtime evidence:
  `docs/design/previews/scrum1093_main_menu_version_corner/runtime/main_menu_2048x1152.png`
  and `runtime/main_menu_2560x1440.png`.

## Verification

- `tests/scrum1093_main_menu_version_corner_test.gd` — PASS, four targets,
  future long version and live resize.
- `tests/scrum1059_main_menu_single_column_test.gd` — PASS, six targets + resize.
- `tests/scrum981_gold_menu_shell_test.gd` — PASS.
- `tests/ui_no_overlap_matrix_test.gd` — PASS.
- `tests/scrum1051_ui_button_family_test.gd` — PASS.
- `tests/gamepad_menu_focus_test.gd` — PASS.
- `tests/runtime_smoke_ui_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS.
- Windowed Metal `tools/capture_scrum1059_main_menu.gd` — PASS at six targets.

The UI/full runtime tests retain the known dummy-renderer
`texture_2d_get: Parameter "t" is null` test-only screenshot diagnostic; both
exit 0 with explicit PASS.

Ready for independent QA on `origin/dev`.

Implementation commit: `ca9b4ed5a` in `origin/dev`. The focused future-semver
and full runtime gates passed again after integrating fresh independent QA base
`0b069dd6c`.

Disk cleanup: removed disposable `.godot` (~446 MiB), transient six-target
`build/qa/scrum1093`, isolated user-data roots and generated `.uid`/`.import`
sidecars; committed previews/runtime evidence were preserved.

## QA-Вердикт (2026-07-12)

Статус: FAILED

PASS на `origin/dev 2c8b60c86`: dynamic future `v0.2.10-beta`, exact 8px
rail reserve, 4px glow-to-label rect gap, frame/ornament safety,
focus/callback/a11y/SFX, owner focused/gold-shell/no-overlap/gamepad/runtime
gates и fresh Metal matrix.

FAIL: owner tests меряют transparent Button hitbox, а не visible PNG.
Independent `tests/scrum1093_independent_visible_gap_test.gd` мерит
rightmost non-zero alpha и получает `33.75 / 37.47 / 37.47 / 42.91
px` на 1280/1920/2048/2560 при контракте `<=20 px`.

Баг: SCRUM-1095. Jira вернут в `К выполнению`; QA реализацию
не менял.

After QA routing, SCRUM-1093 + SCRUM-1095 were claimed as one identical-lock
fix by `/root/scrum1095_visible_icon_gap`; Jira now truthfully shows active work.
