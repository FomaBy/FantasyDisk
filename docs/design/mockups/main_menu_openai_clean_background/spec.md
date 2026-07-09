# UI Mockup Spec - Main Menu OpenAI Clean Background

Status: implemented
Role owner: Design/Codex
Task: `docs/tasks/codex_design_main_menu_openai_clean_background_task.md`
Jira: SCRUM-1001
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440, 1080x1920
Mockup PNG: `docs/design/previews/main_menu_openai_clean_background_preview.png`
Preview PNG: `docs/design/previews/main_menu_openai_clean_background_preview.png`
Generated with: OpenAI Images built-in `image_gen` via explicit user `OpenAI Images override`

## Source Request

User requested a new main-menu picture made with OpenAI image generation, using
current character/monster/boss sprites as references. The image must be clean,
less grainy, cartoon-realistic and beautiful. Follow-up feedback requested
removing grain and adding texture smoothing.

## Runtime Asset Contract

| Asset role | Path |
| --- | --- |
| Runtime background | `assets/backgrounds/main_menu_epic_battle_v3.png` |
| OpenAI source image | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_source.png` |
| Final smoothed reference | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_smooth.png` |
| Sprite reference sheet | `docs/design/references/main_menu_openai_clean_background/current_sprite_reference_contact_sheet.png` |
| Previous runtime backup | `docs/design/backups/main_menu_openai_clean_background/main_menu_epic_battle_v3_pre_scrum1001.png` |
| Safe-zone overlay | `docs/design/previews/main_menu_openai_clean_background_safe_zones.png` |
| Smoothing comparison | `docs/design/previews/main_menu_openai_smoothing_comparison.png` |

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MainMenuBackground | TextureRect | `main_menu_epic_battle_v3.png` | 0,0,2560,1440 | full rect | viewport | 0 | static | root |
| MainMenuTitleLabel | TextureRect | `main_menu_title_fantasy_disk.png` | 56,44,720,270 | top-left | 720x270 | 10 | static | root |
| MainMenuActions | VBoxContainer | six runtime buttons | 72,394,380,674 | left/top computed | 380x674 | 20 | button states | root |
| MainMenuVersionLabel | Label | version text | bottom-right | bottom-right | 104x24 | 20 | static | root |

## Frames And Safe Zones

The new asset is a background, not a UI frame, and contains no baked text,
buttons, logos or panels. Runtime controls remain separate Godot nodes.

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| main_menu_background | `assets/backgrounds/main_menu_epic_battle_v3.png` | 2560x1440 | n/a | left safe column x=0..520; title rect 56,44,720,270; actions rect 72,394,380,674 | no key faces/silhouettes under title/actions; no baked UI | no |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| main_menu_openai_source | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_source.png` | raw OpenAI source | 1672x941 | RGB | n/a | n/a | generated from current sprite sheet and old layout reference |
| main_menu_openai_final_smooth | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_smooth.png` | final denoised/smoothed source | 2560x1440 | RGB | n/a | safe zones preserved | edge-aware smoothing applied after user feedback |
| main_menu_epic_battle_v3 | `assets/backgrounds/main_menu_epic_battle_v3.png` | live runtime background | 2560x1440 | RGB | n/a | safe zones preserved | keeps existing `MAIN_MENU_BACKGROUND` code path |

## Smoothing Pass

The final runtime image uses the stronger smoothing candidate from
`main_menu_openai_smoothing_comparison.png`: a local edge-aware PIL/NumPy pass
that applies stronger median/Gaussian smoothing to low-edge texture fields and
lighter smoothing on silhouettes. This reduces grain in clouds, sky, magic haze,
lava speckles and stone texture while preserving character/boss readability.

## Responsive Rules

- 1280x720: background uses `STRETCH_KEEP_ASPECT_COVERED`; left button column
  and title stay over the calm dark left side.
- 1920x1080: proportional cover crop keeps the party/boss focus to the
  center-right and keeps the menu column clear.
- 2560x1440: native size; safe-zone overlay is exact.
- 1080x1920: existing title/actions top calculation still applies; background
  may crop side detail, but the left/top UI areas remain dark and low-detail.

## Implementation Notes

- Godot scene: `MainMenuScreen` in `scripts/ui_screens.gd::_show_main_menu`.
- Code path unchanged: `scripts/main.gd::MAIN_MENU_BACKGROUND` still points to
  `res://assets/backgrounds/main_menu_epic_battle_v3.png`.
- Runtime text/buttons/logo remain separate controls.
- Generated image contains no baked UI text, buttons, frames, labels or watermark.

## Acceptance Checks

- [x] OpenAI Images override recorded because the user explicitly requested OpenAI.
- [x] Preview shown in chat.
- [x] Runtime asset exists at `assets/backgrounds/main_menu_epic_battle_v3.png`.
- [x] Runtime asset is 2560x1440 RGB PNG.
- [x] Current character/monster/boss sprites were used in a reference sheet.
- [x] Grain reduction and smoothing pass applied after user feedback.
- [x] No UI content overlaps frame decoration; this background has no UI frame.
- [x] Main-menu title/actions safe zones remain free of key art.
- [x] Godot smoke/UI verification completed.

## Deviations

The active FantasyDisk UI pipeline is PixelLab-first, but this task intentionally
uses OpenAI Images because the direct user request explicitly asked for OpenAI
image generation. The exception is recorded in SCRUM-1001 and this spec.
