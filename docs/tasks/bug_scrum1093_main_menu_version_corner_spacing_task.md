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

## Implementation result

- Source-reuse mockup/spec was regenerated before runtime integration from the
  accepted gold shell and PixelLab Gratitude object
  `c1c1c353-e56e-405b-9adf-f1e6bd993152`; production bitmap assets are unchanged.
- Six UI plans pass `ready_for_image` with zero errors/warnings; six runtime
  text layout guides pass `ok=true`.
- `MainMenuVersionLabel` now has intrinsic `measured glyph width + 6px`
  geometry with no silent future-semver clamp and ends exactly 8px inside the
  frame-safe opening. Glow-to-label gap is 4px and hitbox-to-glyph gap is
  asserted in the `0..20px` band.
- Gratitude callback, tooltip/accessibility, focus graph and UI SFX are unchanged.
- Windowed Metal capture passed all six targets under
  `build/qa/scrum1093/` (transient evidence); committed deterministic previews
  for the same six targets live in
  `docs/design/previews/scrum1093_main_menu_version_corner/`.

Pre-integration PASS: `scrum1093_main_menu_version_corner_test`,
`scrum1059_main_menu_single_column_test`, `scrum981_gold_menu_shell_test`,
`scrum1051_ui_button_family_test`, `ui_no_overlap_matrix_test`,
`runtime_smoke_ui_test`, `runtime_smoke_test`.
