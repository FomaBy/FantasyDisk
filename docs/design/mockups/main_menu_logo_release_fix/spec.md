# UI Mockup Spec - Main Menu Release Logo

Status: implemented
Role owner: Design + Back-end
Task: direct user release fix, 2026-07-02
Jira: SCRUM-680
Base resolution: 1920x1080
Responsive targets: 1920x1080, 2560x1440, 1080x1920
Mockup PNG: docs/design/mockups/main_menu_logo_release_fix/pixellab_logo_art_source.png
Preview PNG: docs/design/previews/main_menu_logo_release_fix/main_menu_logo_release_fix_1920x1080_preview.png
Generated with: PixelLab MCP via fantasydisk-ui-director/fantasydisk-asset-generator; source ID `5e9501ff-3c55-45fe-873a-c6d5be4677c6`

## Source Request

Create a new from-scratch main menu logo for FantasyDisk, inspired by the game's characters/reference art, realistic and beautiful, with exact text `Fantasy Disk`; place it on the main/start screen and lower the menu so it no longer overlaps the logo on 1080p/2K targets.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MainMenuTitleLabel | TextureRect | `main_menu_title_fantasy_disk.png` | `56, 44, 720, 270` | top-left | `720x270` | 10 | static | root |
| MainMenuActions | VBoxContainer | six action buttons | `72, 362, 380, 674` | left, top computed | `380x674` | 20 | normal/hover/focus/pressed/disabled buttons | root |
| MainMenuVersionLabel | Label | version | bottom-right | bottom-right | `104x24` | 20 | static | root |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| main_menu_logo | `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` | `960x360` source, displayed as `720x270` | n/a, transparent full image | `title_text_zone = 320,82,600,154` in source | crest ornament, dragon wing arcs, outer glow | no |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| main_menu_logo_pixellab_source | `docs/design/references/main_menu_logo_release_fix/pixellab_logo_art_source.png` | PixelLab textless art layer | `688x288` | yes | n/a | right side reserved for text | source/reference |
| main_menu_logo_runtime | `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` | main menu title logo | `960x360` | yes | n/a | `320,82,600,154` | exact text rendered locally |

## Responsive Rules

- 1920x1080: logo at `56,44,720,270`; menu starts at least `80px` below the logo and clamps to the bottom margin.
- 2560x1440: same relative top-left family; menu starts below the logo instead of full-height centering.
- 1080x1920: logo and left menu stay top-left; tall viewport keeps the same non-overlap rule and leaves generous lower space.

## Interaction States

- Buttons keep existing SCRUM-657 text-button state textures.
- Logo is non-interactive and ignores mouse input.

## Implementation Notes

- Godot scene/script: `scripts/ui_screens.gd::_show_main_menu`.
- Runtime text remains baked only in the static logo image by explicit user request.
- Menu top is computed from viewport height and logo bottom: preferred center, minimum `logo_bottom + 80`, maximum `viewport_h - button_column_h - 10`.

## Acceptance Checks

- [x] Mockup/source art generated through PixelLab MCP.
- [x] Layout plan exists before runtime changes.
- [x] Title text zone is declared.
- [x] Runtime content does not overlap the logo at `1920x1080`, `2560x1440`, or `1080x1920`.
- [x] Runtime screenshots/tests completed after implementation.

## Deviations

- The exact `Fantasy Disk` lettering is rendered locally rather than baked by PixelLab to avoid AI text corruption.
