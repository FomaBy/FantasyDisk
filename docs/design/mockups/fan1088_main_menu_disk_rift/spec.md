# UI Mockup Spec - FAN-1088 Main Menu Disk Rift

Status: implemented and QA-ready
Role owner: Design/Codex Sol
Multica issue: FAN-1088 (`36101914-56ef-4032-b4b3-7a2a25f6e448`)
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440, 1080x1920
Mockup: `docs/design/previews/fan1088_main_menu_disk_rift_mockup.png`
Safe-zone evidence: `docs/design/previews/fan1088_main_menu_disk_rift_safe_zones.png`
Landscape runtime preview: `docs/design/previews/fan1088_main_menu_disk_rift_runtime_1280x720.png`
Portrait runtime preview: `docs/design/previews/fan1088_main_menu_disk_rift_runtime_1080x1920.png`

## Source Request

Replace the main-menu picture with a new image showing one game character on a
cliff in front of a disk-shaped rift below. Keep the existing runtime menu UI.

The current FantasyDisk production policy routes new art through PixelLab MCP.
PixelLab does not expose a general scenic-background endpoint, so the accepted
mockup composites two newly generated PixelLab transparent object layers with
the existing canonical PixelLab Berserk. The previous background contributes
only a character-free calm sky/mountain crop as atmospheric underlay.

## Composition

The north-facing Berserk stands at the tip of a monumental basalt ledge and
looks down toward a luminous violet disk rift. The focal triangle is confined to
the center-right and lower-right. The left third remains dark, low-detail, and
free of key silhouettes for the runtime logo and six-action column.

| Art layer | Rect at 2560x1440 | Z | Notes |
| --- | --- | --- | --- |
| Calm sky underlay | `0,0,2560,1440` | 0 | Character-free crop, cold graded |
| Disk rift | `990,930,1390,370` | 10 | Oblique ellipse below cliff |
| Cliff | `1120,245,1800,1800` | 20 | Cropped by right/bottom canvas edges |
| Berserk | `1180,4,590,590` | 30 | North-facing; feet aligned to ledge |

## Runtime UI Safe Zones

The background contains no baked text, buttons, logo, labels, panels, frames, or
watermark. Existing Godot controls remain separate nodes.

| Runtime content | Rect at 2560x1440 | Requirement |
| --- | --- | --- |
| Main-menu title texture | `299,257,480,180` | Calm dark sky; no focal silhouettes |
| Six-action column | `299,457,380,646` | Calm dark sky; high contrast for buttons |
| Gratitude/version cluster | `2110,1091,175,116` | Dark cliff face; no bright rift linework |

The general left safe column is `x=0..900`. The stricter title and action rects
above are the acceptance source of truth. These coordinates come from the live
SCRUM-1059/1093 layout rather than the superseded SCRUM-1001 background spec.

## Screen Elements

| ID | Type | Runtime content | Rect at 2560x1440 | Anchors | Z |
| --- | --- | --- | --- | --- | --- |
| MainMenuBackground | TextureRect | `main_menu_epic_battle_v3.png` | `0,0,2560,1440` | full rect | 0 |
| MainMenuTitleLabel | TextureRect | `main_menu_title_fantasy_disk.png` | `299,257,480,180` | authored inner/top-left | 10 |
| MainMenuActions | VBoxContainer | six runtime buttons | `299,457,380,646` | authored inner/left | 20 |
| MainMenuVersionLabel | Label | runtime version text | bottom-right | bottom-right | 20 |

## Responsive Rules

- 2560x1440: logo `299,257,480,180`; actions `299,457,380,646`; utility
  cluster `2110,1091,175,116`.
- 1920x1080: logo `224,193,331,124`; actions `224,329,380,506`; utility
  cluster `1563,807,149,96`.
- 1280x720: logo `157,137,192,72`; actions `157,215,340,361`; utility
  cluster `1007,515,132,84`; PixelLab silhouette edges stay readable.
- 1080x1920: `STRETCH_KEEP_ASPECT_COVERED` center-crops the source to roughly
  `x=875..1685`; live logo `145,332,480,180`, actions `145,532,380,646`, and
  utility cluster `784,1496,175,116` remain readable while the hero stays to
  their right. The committed portrait runtime preview confirms this crop.

## Asset Contract

| Role | Path | Size | Alpha |
| --- | --- | --- | --- |
| PixelLab cliff source | `docs/design/references/fan1088_main_menu_disk_rift/pixellab_cliff_source.png` | 400x400 | reported RGBA |
| Clean cliff layer | `docs/design/references/fan1088_main_menu_disk_rift/pixellab_cliff_alpha.png` | 400x400 | RGBA |
| PixelLab rift source | `docs/design/references/fan1088_main_menu_disk_rift/pixellab_disk_rift_source.png` | 400x400 | reported RGBA |
| Clean rift layer | `docs/design/references/fan1088_main_menu_disk_rift/pixellab_disk_rift_alpha.png` | 400x400 | RGBA |
| Canonical Berserk | `assets/sprites/characters/full_frame/berserk_pixellab/berserk_idle_north.png` | 512x512 | RGBA |
| Final runtime background | `assets/backgrounds/main_menu_epic_battle_v3.png` | 2560x1440 | RGB |

## Implementation Contract

- Keep `scripts/main.gd::MAIN_MENU_BACKGROUND` unchanged.
- Keep `scripts/ui_screens.gd::_show_main_menu` layout and controls unchanged.
- Promote the accepted mockup to the existing runtime texture path.
- Preserve the pre-FAN-1088 runtime image under
  `docs/design/backups/fan1088_main_menu_disk_rift/`.
- Validate the rendered menu, not only the standalone PNG, at the complete
  responsive matrix.

## Acceptance Checklist

- [x] PixelLab MCP authentication and generation completed.
- [x] PixelLab source/export IDs, prompts, alpha outputs, and manifest recorded.
- [x] Exactly one recognizable canonical character appears.
- [x] Character stands on a cliff above a disk-shaped rift.
- [x] No baked UI text, labels, logo, controls, or watermark.
- [x] Title/action safe zones contain no focal art.
- [x] Mockup is 2560x1440 RGB PNG and has been visually inspected.
- [x] Runtime texture promoted and rendered in Godot.
- [x] 1280x720, 1920x1080, 2560x1440, and 1080x1920 captures inspected.

## Validation

- `tests/main_menu_title_no_overlap_test.gd`: passed 18 button checks across
  three viewports.
- `tests/scrum1059_main_menu_single_column_test.gd`: passed six viewports and
  live resize.
- `tests/scrum1093_main_menu_version_corner_test.gd`: passed four viewports,
  future-version sizing, and live resize.
- `tests/runtime_smoke_ui_test.gd`: passed.
- `python3 tools/quality_gate.py --profile changed --changed-ref origin/dev`:
  passed.
- A real-renderer capture matrix was inspected at 1280x720, 1920x1080,
  2560x1440, and 1080x1920. The committed landscape and portrait previews are
  the durable visual evidence; ephemeral full-matrix captures were cleaned up.
