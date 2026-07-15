# UI Mockup Spec - FAN-1098 Codex OpenAI Background

Status: implemented, runtime-verified, ready for independent QA
Role owner: Design/Codex Sol
Multica issue: FAN-1098 (`36e3263c-1af0-4ced-bf78-a9eae755e5f1`)
Base resolution: 1920x1080 stage over a 2560x1440 runtime background
Responsive targets: 1280x720, 1920x1080, 2560x1440
Runtime asset: `assets/sprites/ui/atlas_style/codex/bg_codex_sanctum.png`
Generated source: `docs/design/references/fan1098_codex_openai_background/codex_openai_builtin_source.png`
Mockup/accepted background: `docs/design/previews/fan1098_codex_openai_background/codex_background_mockup_2560x1440.png`
Safe-zone evidence: `docs/design/previews/fan1098_codex_openai_background/codex_background_safe_zones_2560x1440.png`
Runtime previews: `docs/design/previews/fan1098_codex_openai_background/codex_runtime_{1280x720,1920x1080,2560x1440}.png`
Generator: background=built-in OpenAI Image Generator; non-background UI=existing

## Source Request

Replace the Codex menu background while preserving the current Codex layout,
controls, panels, content, and interaction behavior.

This is a full-canvas menu background. Per the project directive, it must be
generated with the built-in OpenAI Image Generator in Codex. PixelLab is
forbidden for this layer. The OpenAI Images API is not authorized for this task.

## Art Direction

Create a cohesive dark-fantasy D&D illustration of an ancient draconic archive
inside a ruined cathedral crypt: blackened stone, towering shadowed bookcases,
dragon-carved pillars, a distant sealed circular disk door, muted bronze and
worn-gold details, sparse violet-blue arcane light, and drifting dust. The scene
is empty of characters and presented frontally as a deep architectural interior.

The content field is calm, dark, and low-frequency. Architectural detail and
light accents stay near the extreme edges, upper vault, and narrow gaps between
the live panels. The background must not compete with the three information
columns, title, crest, or Back button.

## Screen Elements And Safe Zones

The runtime Codex uses a fixed 1920x1080 stage that scales uniformly and
letterboxes. These exact source-stage rectangles remain unchanged:

| ID | Runtime content | Rect at 1920x1080 | Background requirement |
| --- | --- | --- | --- |
| `CodexTitleFrame` | live `КОДЕКС` title | `72,36,340,112` | dark, low-detail, no bright edge |
| `CodexCrest` | existing crest art | `908,24,104,104` | quiet halo only; no competing symbol |
| `CodexBackButton` | live `НАЗАД` action | `1580,46,268,96` | dark, low-detail, no bright edge |
| `CodexNavPanel` | seven section buttons | `72,172,324,840` | calm, no focal object |
| `CodexContent` | section title and entry list | `420,172,620,840` | calm, no focal object |
| `CodexDetailPanel` | selected-entry dossier | `1064,172,784,840` | calm, no focal object |

The background is a full-rect `TextureRect` at z=0. All panels, labels, buttons,
portraits, scroll areas, and the crest remain separate runtime nodes above it.
No UI content is baked into the image.

## Frames And Content Margins

This task changes no frame texture or content geometry. Existing frame contracts
remain authoritative:

| Frame | Texture margins | Live content margins | Forbidden zones |
| --- | --- | --- | --- |
| `panel_9slice.png` | `46/46/46/46` | title `36/22/36/22`; nav `32/38/32/50`; content/detail `32/36/32/44` | bronze corners and bevel |
| `chip_bar.png` | `40/20/40/20` | `18/14/18/14` | bronze ends |
| `dossier_frame.png` | `96/96/96/96` | lore `32/26/42/26` | dragon-scale corners and parchment rim |

## Responsive Rules

- 1280x720: stage scale `0.6667`, centered; all background safe rectangles scale
  uniformly with the live stage.
- 1920x1080: stage scale `1.0`; rectangles above are exact.
- 2560x1440: stage scale `1.3333`; rectangles scale uniformly.
- The generated background remains 16:9, so no landscape target requires crop
  drift. Runtime cover scaling must not stretch it.

## Interaction States

Existing default, hover, pressed, focus, disabled, selected, locked, empty, and
scroll states are unchanged. No state changes the background or layout.

## Implementation Contract

- Replace only the already-wired `CODEX_SANCTUM_BG_PATH` bitmap.
- Do not edit `scripts/main.gd`, `scripts/ui_screens.gd`, frames, controls, text,
  layout rectangles, focus behavior, or Codex data.
- Preserve the previous runtime bitmap in the FAN-1098 backup folder.
- Normalize the selected built-in source proportionally to exact 2560x1440 RGB;
  do not stretch it.
- Validate the actual rendered Codex at 1280x720, 1920x1080, and 2560x1440.

## Acceptance Checks

- [x] Built-in OpenAI generation source, prompt, dimensions, and hash recorded.
- [x] PixelLab and OpenAI Images API not used.
- [x] New cohesive dark-fantasy draconic archive background.
- [x] No text, labels, logo, watermark, frame, buttons, characters, or baked UI.
- [x] All six runtime safe rectangles stay dark and low-detail.
- [x] Final runtime bitmap is RGB 2560x1440 and promoted at the existing path.
- [x] Runtime Codex inspected at the full responsive matrix.
- [x] Focused Codex/UI tests pass.
- [x] Changed-profile quality gate passes before integration.

## Implemented Result

The built-in generator returned a 1672x941 RGB source. It was center-cropped to
1664x936 and proportionally resized to exact 2560x1440 RGB; no stretch, paint,
collage, PixelLab operation, or OpenAI Images API call was used. The accepted
runtime and mockup SHA-256 is
`145ce19aca8e64aada150003f2b7316236e1120e307e277339cb84a2b8a660cb`.
The previous 488x274 bitmap is preserved with SHA-256
`03026f8d1640e2ad3da6d47794ea10638fc5e16fbd83f939df7767ecd38a9300`.

Safe-zone mean luminance is 18 title, 24 crest, 19 Back, 25 navigation, 29
content, and 25 detail on the 0-255 scale. The exact machine-readable report is
`docs/design/previews/fan1098_codex_openai_background/safe_zone_report.json`.

Real Godot renderer captures at 1280x720, 1920x1080, and 2560x1440 confirm the
unchanged three-column composition, readable title/actions, and ornament-safe
panel content. Focused validation passed `codex_scrum954_layout_test.gd`,
`codex_scrum958_image_fit_test.gd`, `lore_screens_test.gd`,
`ui_no_overlap_matrix_test.gd`, and `runtime_smoke_ui_test.gd`.
The changed-profile quality gate passed all 13 static and 7 Godot checks; its
pre-commit report was correctly non-certifying only because the task files were
still uncommitted.

## Deviations

None. This is a background-only replacement with unchanged runtime
geometry and interaction behavior.
