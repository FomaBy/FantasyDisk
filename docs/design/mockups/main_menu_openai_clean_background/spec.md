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
removing grain, adding texture smoothing, smoothing ragged linework and removing
orange spark/ember dot noise. Latest follow-up requested a full regeneration
from scratch without using previous screens/backgrounds as references, while
still using current runtime character and boss sprites as visual references.
The first local from-scratch candidate was rejected before push because the
guitarist read as back-facing while playing; the accepted reimagined pass uses
3/4 front/side party key-art poses and a clearly readable guitarist.

## Runtime Asset Contract

| Asset role | Path |
| --- | --- |
| Runtime background | `assets/backgrounds/main_menu_epic_battle_v3.png` |
| OpenAI source image | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_source.png` |
| First smoothed reference | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_smooth.png` |
| Smooth-lines OpenAI edit source | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_smooth_lines_source.png` |
| Final smooth-lines reference | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_smooth_lines.png` |
| Final no-orange-noise reference | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_no_orange_noise.png` |
| Reimagined OpenAI source | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_reimagined_source.png` |
| Final reimagined character/boss reference background | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_reimagined_character_boss_refs.png` |
| Sprite reference sheet | `docs/design/references/main_menu_openai_clean_background/current_sprite_reference_contact_sheet.png` |
| Reimagined clean character/boss reference sheet | `docs/design/references/main_menu_openai_clean_background/current_character_boss_reference_sheet_generation_clean.png` |
| From-scratch annotated character/boss reference sheet | `docs/design/references/main_menu_openai_clean_background/current_character_boss_reference_sheet_annotated.png` |
| From-scratch reference manifest | `docs/design/references/main_menu_openai_clean_background/current_character_boss_reference_sheet_manifest.md` |
| Previous runtime backup | `docs/design/backups/main_menu_openai_clean_background/main_menu_epic_battle_v3_pre_scrum1001.png` |
| Safe-zone overlay | `docs/design/previews/main_menu_openai_clean_background_safe_zones.png` |
| Smoothing comparison | `docs/design/previews/main_menu_openai_smoothing_comparison.png` |
| Smooth-lines comparison | `docs/design/previews/main_menu_openai_smooth_lines_comparison.png` |
| Orange-noise mask | `docs/design/previews/main_menu_openai_orange_noise_mask.png` |
| No-orange-noise comparison | `docs/design/previews/main_menu_openai_no_orange_noise_comparison.png` |
| Reimagined source/runtime comparison | `docs/design/previews/main_menu_openai_reimagined_comparison.png` |

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
| main_menu_openai_final_smooth | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_smooth.png` | first denoised/smoothed source | 2560x1440 | RGB | n/a | safe zones preserved | edge-aware smoothing applied after first user feedback |
| main_menu_openai_smooth_lines_source | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_smooth_lines_source.png` | OpenAI edit source for smoother contours | 1672x941 | RGB | n/a | n/a | generated after follow-up feedback about ragged edges |
| main_menu_openai_final_smooth_lines | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_smooth_lines.png` | final smooth-lines runtime source | 2560x1440 | RGB | n/a | safe zones preserved | smoother clouds, silhouettes, platform edges and boss contours |
| main_menu_openai_final_no_orange_noise | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_no_orange_noise.png` | final no-orange-noise runtime source | 2560x1440 | RGB | n/a | safe zones preserved | small isolated orange/yellow ember/spark components removed |
| current_character_boss_reference_sheet_generation_clean | `docs/design/references/main_menu_openai_clean_background/current_character_boss_reference_sheet_generation_clean.png` | accepted reimagined generation visual reference input | 1536x1152 | RGB | n/a | n/a | current runtime heroes and bosses only; no previous screens/backgrounds, no card/grid borders |
| current_character_boss_reference_sheet_annotated | `docs/design/references/main_menu_openai_clean_background/current_character_boss_reference_sheet_annotated.png` | evidence reference sheet | 1536x1200 | RGB | n/a | n/a | annotated for traceability, not used as generation layout |
| main_menu_openai_reimagined_source | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_reimagined_source.png` | raw OpenAI reimagined source | 1672x941 | RGB | n/a | n/a | generated from the clean character/boss sheet only, no previous screen/background input |
| main_menu_openai_final_reimagined_character_boss_refs | `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_reimagined_character_boss_refs.png` | active final reimagined runtime source | 2560x1440 | RGB | n/a | safe zones preserved | 3/4 front/side party key art with readable guitarist and calm left UI space |
| main_menu_epic_battle_v3 | `assets/backgrounds/main_menu_epic_battle_v3.png` | live runtime background | 2560x1440 | RGB | n/a | safe zones preserved | keeps existing `MAIN_MENU_BACKGROUND` code path |

## Reimagined From-Scratch Regeneration Pass

The latest runtime background is a full OpenAI Images regeneration from scratch.
The previous main-menu images, old screen previews and prior generated
backgrounds were not used as input references. The only visual reference image
used for this pass was
`current_character_boss_reference_sheet_generation_clean.png`, built from
current runtime character and boss sprites. The accepted composition is a cold
moonlit mountain-pass/citadel key-art scene with the hero party in 3/4
front/side poses on the center-right/right side. The guitarist is visible from
the front/3/4 side with the guitar held naturally across the torso. Bosses are
atmospheric threats in the distant citadel/clouds, while the left menu/title
safe zones remain dark and low-detail.

## Smoothing Pass

The first runtime image used the stronger smoothing candidate from
`main_menu_openai_smoothing_comparison.png`: a local edge-aware PIL/NumPy pass
that reduced grain in clouds, sky, magic haze, lava speckles and stone texture.

The final revision uses an additional OpenAI edit plus a light anti-ragged
postprocess, tracked in `main_menu_openai_smooth_lines_comparison.png`. This
revision specifically smooths uneven/ragged contours on clouds, ruins, capes,
stone platform edges, boss armor and monster silhouettes while keeping the same
main-menu composition and safe zones.

## Orange Dot Cleanup

The orange dots came from the generated background as ember/spark/lava-particle
noise. The cleanup pass builds a warm orange/yellow candidate mask, keeps large
connected golden linework such as portal circles and music curves, and
color-neutralizes only small isolated components into the darker cool palette
without blurring the surrounding texture. Evidence:
`main_menu_openai_orange_noise_mask.png` and
`main_menu_openai_no_orange_noise_comparison.png`.

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
- [x] Latest pass uses current character/boss reference sheet only and excludes
      previous screen/background images as generation references.
- [x] Guitarist reads front/3/4 side with visible guitar, not back-facing.
- [x] Grain reduction and smoothing pass applied after user feedback.
- [x] Orange spark/ember dot noise removed after follow-up feedback.
- [x] No UI content overlaps frame decoration; this background has no UI frame.
- [x] Main-menu title/actions safe zones remain free of key art.
- [x] Godot smoke/UI verification completed.

## Deviations

The active FantasyDisk UI pipeline is PixelLab-first, but this task intentionally
uses OpenAI Images because the direct user request explicitly asked for OpenAI
image generation. The exception is recorded in SCRUM-1001 and this spec.
