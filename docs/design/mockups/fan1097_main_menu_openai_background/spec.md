# UI Mockup Spec - FAN-1097 Main Menu OpenAI Background

Status: implemented and QA-ready
Role owner: Design/Codex Sol
Multica issue: FAN-1097 (`7cc0bbb5-cf82-4516-b4f0-672ebe2cedd9`)
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440, 1080x1920
Runtime asset: `assets/backgrounds/main_menu_epic_battle_v3.png`
Mockup: `docs/design/previews/fan1097_main_menu_openai_background_mockup.png`
Safe-zone evidence: `docs/design/previews/fan1097_main_menu_openai_background_safe_zones.png`
Landscape runtime preview: `docs/design/previews/fan1097_main_menu_openai_background_runtime_1280x720.png`
Portrait runtime preview: `docs/design/previews/fan1097_main_menu_openai_background_runtime_1080x1920.png`

## Source Request

Change the main-menu background. Keep the existing runtime menu UI.

The user explicitly requires this full-screen scenic background to be generated
with the built-in OpenAI Image Generator in Codex. PixelLab must not be used for
generation or editing of this asset, and the OpenAI Images API is reserved for a
separate explicit user request.

## Art Direction

Regenerate the active cliff-and-rift idea as one cohesive cinematic illustration
rather than a collage of separately composed objects. A lone rugged barbarian,
seen from behind and without a visible weapon, stands on a jagged basalt cliff
and looks toward a vast violet disk-shaped dimensional rift in the valley below.
Storm clouds, distant ruined spires, and layered mountains provide depth.

The focal silhouette and brightest rift energy stay center-right/right. The left
35 percent remains dark, calm, low-detail atmospheric space for the live logo and
six-action column. The image uses polished hand-painted dark-fantasy key-art
rendering with smooth materials and restrained violet highlights; it must not
look like pixel art or a cut-and-paste composite.

## Runtime UI Safe Zones

The background contains no baked text, buttons, logo, labels, panels, frames,
cursor, version copy, or watermark. Existing Godot controls remain separate
nodes.

| Runtime content | Rect at 2560x1440 | Requirement |
| --- | --- | --- |
| Main-menu title texture | `299,257,480,180` | Calm dark atmosphere; no focal silhouette or bright rift |
| Six-action column | `299,457,380,646` | Calm dark atmosphere; high contrast for live buttons |
| Gratitude/version cluster | `2110,1091,175,116` | No bright rift rim or character silhouette |

The general left safe column is `x=0..900`. The stricter title and action rects
above remain the acceptance source of truth.

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
  cluster `1007,515,132,84`.
- 1080x1920: cover scaling center-crops the 2560x1440 source to roughly
  `x=875..1685`; live logo `145,332,480,180`, actions `145,532,380,646`, and
  utility cluster `784,1496,175,116` must remain legible.

## Asset Contract

| Role | Path | Size | Alpha |
| --- | --- | --- | --- |
| Initial built-in OpenAI source | `docs/design/references/fan1097_main_menu_openai_background/main_menu_openai_builtin_initial.png` | 1672x941 | RGB |
| Accepted built-in OpenAI source | `docs/design/references/fan1097_main_menu_openai_background/main_menu_openai_builtin_source.png` | 1672x941 | RGB |
| Accepted mockup | `docs/design/previews/fan1097_main_menu_openai_background_mockup.png` | 2560x1440 | RGB |
| Safe-zone evidence | `docs/design/previews/fan1097_main_menu_openai_background_safe_zones.png` | 2560x1440 | RGB |
| Previous runtime backup | `docs/design/backups/fan1097_main_menu_openai_background/main_menu_epic_battle_v3_pre_fan1097.png` | 2560x1440 | RGB |
| Final runtime background | `assets/backgrounds/main_menu_epic_battle_v3.png` | 2560x1440 | RGB |

## Implementation Contract

- Keep `scripts/main.gd::MAIN_MENU_BACKGROUND` unchanged.
- Keep `scripts/ui_screens.gd::_show_main_menu` layout and controls unchanged.
- Crop the generated source proportionally to 16:9 and resize to 2560x1440;
  do not stretch it.
- Promote only the visually accepted mockup to the existing runtime path.
- Preserve the pre-FAN-1097 runtime image in the task backup folder.
- Validate the rendered menu, not only the standalone PNG, at the responsive
  matrix.

## Acceptance Checklist

- [x] Built-in OpenAI Image Generator source is recorded with the final prompt.
- [x] PixelLab and the OpenAI Images API were not used.
- [x] One cohesive dark-fantasy scene replaces the prior composited background.
- [x] No baked UI text, labels, logo, controls, frame, cursor, or watermark.
- [x] Title/action safe zones contain no focal art.
- [x] Mockup is a proportionally prepared 2560x1440 RGB PNG.
- [x] Runtime texture is promoted and rendered in Godot.
- [x] 1280x720, 1920x1080, 2560x1440, and 1080x1920 captures are inspected.

## Validation

- The first built-in generation was retained as provenance. A second built-in
  edit moved high-contrast rift energy away from the live lower-right utility
  cluster; the accepted source and both prompts are recorded in the manifest.
- The generated 1672x941 source was center-cropped to an exact 1664x936 16:9
  image and resized proportionally to 2560x1440 RGB. The runtime PNG and accepted
  mockup share SHA-256
  `5ca67f60dda660518a16a5ae8d6fe510c01850f96f537c5f6b57936ee2477975`.
- A real-renderer capture matrix was inspected at 1280x720, 1920x1080,
  2560x1440, and 1080x1920. The committed landscape and portrait captures are
  durable visual evidence; both keep runtime content inside the gold shell.
- `tests/main_menu_title_no_overlap_test.gd`: passed 18 button checks across
  three viewports.
- `tests/scrum1059_main_menu_single_column_test.gd`: passed six viewports and
  live resize.
- `tests/scrum1093_main_menu_version_corner_test.gd`: passed four viewports,
  a future-version label, and live resize.
- `tests/scrum981_gold_menu_shell_test.gd`: passed 1280x720, 1920x1080, and
  2560x1440.
- `tests/runtime_smoke_ui_test.gd`: passed.
