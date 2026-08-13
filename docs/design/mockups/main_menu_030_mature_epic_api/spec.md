# UI Mockup Spec - FAN-2488 Mature Epic Main Menu Background

Status: implemented, awaiting independent exact-SHA QA
Role owner: Multica developer (medium lane)
Multica issue: FAN-2488 (`c98387b5-5d70-4d63-851b-d6213edec3d7`)
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440, 1080x1920
Runtime asset: `assets/backgrounds/main_menu_epic_battle_v3.png`
Clean preview: `docs/design/previews/main_menu_030_mature_epic_api/main_menu_030_preview.png`
Safe-zone evidence: `docs/design/previews/main_menu_030_mature_epic_api/main_menu_030_safe_zones.png`
Renderer captures: `docs/design/previews/main_menu_030_mature_epic_api/main_menu_030_runtime_*.png`
Capture geometry report: `docs/design/previews/main_menu_030_mature_epic_api/capture_matrix.md`
Generator provenance: `docs/design/references/main_menu_030_mature_epic_api/manifest.json`

## Source Request

Replace the active main-menu background with a mature cinematic dark-fantasy
scene. Keep every existing runtime control, the title asset, the layout geometry
and the runtime texture path unchanged.

The user explicitly selected the paid OpenAI Images API route for this asset on
2026-08-13. Generation goes through the repository helper
`skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` with model
`gpt-image-2` and `quality=high`. PixelLab and the built-in image generator are
not used for this asset.

## Art Direction

One cohesive hand-painted dark-fantasy key-art illustration, "Последний рубеж у
Расколотого Диска". Three adult, weathered heroes in worn plate and leather
stand together on the shattered rampart of a ruined mountain bastion, seen from
behind and dwarfed by the scene. A colossal skeletal bone dragon rises in front
of them, and an immense cracked obsidian disk split by a violet dimensional rift
hangs above the valley behind it.

Realistic painterly materials, restrained black / slate-steel / deep-violet
palette with a narrow ember-gold accent, volumetric storm light, tragic
monumental mood. The focal silhouettes and the strongest contrast live in the
right and center-right band. The left column stays dark, calm and low-detail
storm haze so the live logo and six-action column read cleanly on top of it.

## Runtime UI Safe Zones

The background contains no baked text, logo, label, button, panel, frame,
cursor, watermark or any other interface element. Every live control remains a
separate Godot node.

| Runtime content | Rect at 2560x1440 | Requirement |
| --- | --- | --- |
| Main-menu title texture | `299,257,480,180` | Calm dark atmosphere; no focal silhouette or bright rift |
| Six-action column | `299,457,380,646` | Calm dark atmosphere; high contrast for live buttons |
| Gratitude/version cluster | `2110,1091,175,116` | Smooth low-detail mist; no rubble edges, ember sparks or bright rim light |

The general left safe column is `x=0..900`. The stricter title, action and
utility rects above remain the acceptance source of truth.

Measured on the accepted 2560x1440 source (mean edge energy over the whole
image is `9.89`):

| Zone | Luminance | Luminance sd | Edge energy | p99 luminance |
| --- | --- | --- | --- | --- |
| Title `299,257,480,180` | 13.19 | 3.29 | 3.59 | 24 |
| Actions `299,457,380,646` | 22.65 | 5.24 | 3.63 | 35 |
| Utility `2110,1091,175,116` | 34.33 | 8.25 | 6.47 | 51 |
| Left column `x=0..900` | 15.48 | 9.48 | 3.69 | 43 |
| Focus band `x=1400..2560` | 49.08 | 34.49 | 15.92 | 184 |

Every live safe zone sits below the image-wide edge-energy mean, while the focal
band sits well above it.

## Screen Elements

| ID | Type | Runtime content | Rect at 2560x1440 | Anchors | Z |
| --- | --- | --- | --- | --- | --- |
| MainMenuBackground | TextureRect | `main_menu_epic_battle_v3.png` | `0,0,2560,1440` | full rect, `STRETCH_KEEP_ASPECT_COVERED` | 0 |
| MainMenuTitleLabel | TextureRect | `main_menu_title_fantasy_disk.png` | `299,257,480,180` | authored inner/top-left | 10 |
| MainMenuActions | GridContainer | six runtime buttons | `299,457,380,646` | authored inner/left | 20 |
| MainMenuVersionLabel | Label | runtime version text | `2228,1175,57,32` | bottom-right | 20 |

## Responsive Rules

Authored contract, confirmed against the committed capture geometry report.

- 2560x1440: logo `299,257,480,180`; actions `299,457,380,646`; utility cluster
  `2110,1091,175,116` with the version label measured at `2228,1175,57,32`.
- 1920x1080: logo `224,193,331,124`; actions `224,329,380,506`; utility cluster
  `1563,807,149,96` with the version label measured at `1661,875,51,28`.
- 1280x720: logo `157,137,192,72`; actions `157,215,340,361`; utility cluster
  `1007,515,132,84` with the version label measured at `1093,575,46,24`.
- 1080x1920: `STRETCH_KEEP_ASPECT_COVERED` center-crops the 2560x1440 source to
  the source band `x=875..1685`; logo `145,332,480,180`, actions
  `145,532,380,646` and the version label `902,1580,57,32` stay legible. The
  visible portrait band keeps the dragon wing, the ruined spire, the bastion,
  the left hero and the lower arc of the rift; the dragon head and the full disk
  fall outside the centered crop, which is inherent to cover-cropping 16:9 key
  art into 9:16 and unchanged from the previous background contract.

## Asset Contract

| Role | Path | Size | Alpha |
| --- | --- | --- | --- |
| Initial API source (rejected) | `docs/design/references/main_menu_030_mature_epic_api/main_menu_030_openai_api_source.png` | 2560x1440 | RGB |
| Accepted API source | `docs/design/references/main_menu_030_mature_epic_api/main_menu_030_openai_api_accepted.png` | 2560x1440 | RGB |
| Clean preview | `docs/design/previews/main_menu_030_mature_epic_api/main_menu_030_preview.png` | 2560x1440 | RGB |
| Safe-zone evidence | `docs/design/previews/main_menu_030_mature_epic_api/main_menu_030_safe_zones.png` | 2560x1440 | RGB |
| Renderer captures | `docs/design/previews/main_menu_030_mature_epic_api/main_menu_030_runtime_{1280x720,1920x1080,2560x1440,1080x1920}.png` | as named | RGB |
| Previous runtime backup | `docs/design/backups/main_menu_030_mature_epic_api/main_menu_epic_battle_v3_pre_fan2488.png` | 2560x1440 | RGB |
| Final runtime background | `assets/backgrounds/main_menu_epic_battle_v3.png` | 2560x1440 | RGB |

The accepted API source, the clean preview and the runtime PNG are byte-identical
(`sha256 f8057689bb03f01f738f96a00ca42f6bc7d6a7be464658fde3fe1e6038c8ac9b`).

## Implementation Contract

- Keep `scripts/main.gd::MAIN_MENU_BACKGROUND` unchanged.
- Keep `scripts/ui_screens.gd::_show_main_menu` controls, title asset, buttons
  and layout geometry unchanged.
- Generate through the helper with `--no-task`; the `docs/tasks/` mirror is out
  of this issue's write-set.
- The API source is requested natively at exact 16:9 `2560x1440`, so the
  proportional crop and resize are identity operations and nothing is stretched.
- Promote only the visually accepted source to the existing runtime path and
  preserve the pre-FAN-2488 runtime bitmap in the task backup folder.
- Validate the rendered menu, not only the standalone PNG, at the responsive
  matrix.

## Acceptance Checklist

- [x] OpenAI Images API route recorded with model, quality, prompts, sizes and
      SHA-256; no credential printed or committed.
- [x] PixelLab and the built-in image generator were not used.
- [x] One cohesive mature dark-fantasy scene with three adult heroes, a colossal
      bone dragon and a cracked obsidian disk rift.
- [x] No baked text, logo, label, button, panel, frame, cursor or watermark.
- [x] Title, action and utility safe zones and the left column are calm and
      free of focal silhouettes and high-energy edges.
- [x] Runtime PNG is 2560x1440 RGB, exact 16:9, unstretched.
- [x] Previous runtime bitmap backed up; runtime path unchanged.
- [x] 1280x720, 1920x1080, 2560x1440 and 1080x1920 real captures inspected and
      committed.

## Validation

- The first API generation was kept as provenance. Its utility rect landed on
  high-contrast masonry rubble (`edge energy 17.01` against an image mean of
  `9.72`), so a second generation added an explicit lower-right quiet-rectangle
  constraint; the accepted result measures `6.47` against an image mean of
  `9.89`. Both prompts are committed beside the manifest.
- Real windowed Metal captures were taken at 1280x720, 1920x1080, 2560x1440 and
  1080x1920 with `DisplayServer` reporting `macOS`. The measured logo, action
  and version rects match the authored contract at every target and are recorded
  in `capture_matrix.md`.
- Focused gates executed on this candidate:
  `tests/main_menu_title_no_overlap_test.gd`,
  `tests/scrum1059_main_menu_single_column_test.gd`,
  `tests/scrum1093_main_menu_version_corner_test.gd`,
  `tests/scrum981_gold_menu_shell_test.gd` and
  `tests/runtime_smoke_ui_test.gd`.
