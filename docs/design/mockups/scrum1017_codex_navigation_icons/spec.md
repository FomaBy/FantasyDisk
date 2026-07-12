# UI Mockup Spec — Codex Navigation And Enlarged Real Images

Status: ready_for_independent_design_qa

Role owner: Designer2/Codex (`/root/audit_qa`)

Task: `docs/tasks/SCRUM-1017_codex_navigation_icons_handoff.md`

Jira: SCRUM-1017

Backend handoff: SCRUM-954 and SCRUM-958

Base resolution: 1920x1080

Responsive targets: 1280x720, 1920x1080, 2560x1440

Generated with: PixelLab MCP `create_ui_asset`

PixelLab source ID/name: `27b4e50d-3d97-470d-bb7a-e11eecfb0c5f` /
`scrum1017_codex_navigation_icons_v1`

## Source Request

Define one accepted Codex visual and geometry contract before either navigation
work (SCRUM-954) or enlarged-image integration (SCRUM-958) begins. The screen
must keep six Russian categories, use only real entry images with centered
Russian names in the list, provide a large right-side preview and readable deep
detail, and remove the old stray bars below the preview. This task is Design
source only; runtime code and tests are read-only.

## Skill-Enforced Workflow

- `fantasydisk-ui-director` required a full-page PixelLab source before any
  runtime work, one dark-fantasy product family, exact safe zones and a shown
  preview.
- `content-zone-image-compositor` required `ui_plan.json`, a successful
  `ready_for_image` planning gate and `layout*.json` before image generation.
  After PixelLab generation it permitted only text and real images inside
  declared zones, plus separate debug overlays.
- `fantasydisk-asset-generator` required PixelLab MCP provenance, transparent
  source export and no OpenAI/manual/legacy fallback.

The first planning pass correctly returned `revise_task` because nested frames
were over-marked as independent collision surfaces. Parent/child collision
semantics were fixed without shrinking content. The generation gate then
returned `ready_for_image`, `ok=true`, 51/51 elements and zero errors/warnings.
After inspecting the accepted PixelLab frame, only the declared label/image
insets were tightened to its real dark interiors; no generated frame, card,
panel or ornament was redrawn.

## Content And Control Inventory

| Surface | Fixed content | Dynamic content | Controls/states | Overflow |
| --- | --- | --- | --- | --- |
| Header | `КОДЕКС`, `НАЗАД` | none | Back default/hover/pressed/focus/disabled; Esc/B | none |
| Navigation | `Персонажи`, `Монстры`, `Артефакты`, `Характеристики`, `Атрибуты`, `Возвышение` | selected section | six buttons; mouse, focus, LB/RB; selected tint without resize | none; all six rows fit |
| Center | active Russian section title | four visible entry rows, each one real image plus one centered Russian display-name | default/hover/focus/selected/locked/loading/empty | required vertical scroll; four visible rows |
| Detail header | selected Russian display-name | category/kind/rarity/role chips | selected/locked | none |
| Detail preview | none baked | large real character, monster or artifact image | available/locked silhouette/missing fallback | none; contain/crop policy below |
| Detail body | player-facing headings | description, skills/abilities, traits, gameplay notes, formulas/unlock text | focus-follow text scroll | required vertical scroll |

Semantic split follows the accepted SCRUM-1013 contract: `Характеристики`
contains only the eight base entries from `StatFormulas.BASE_STAT_ORDER`;
`Атрибуты` contains derived entries from `DERIVED_STAT_ORDER`; `Возвышение`
contains the player-facing progression levels. Raw IDs and English duplicates
are forbidden everywhere.

## Exact Geometry At 1920x1080

| ID | Authored frame rect `x,y,w,h` | Safe live-content rect | Min at 1280x720 | Notes |
| --- | --- | --- | --- | --- |
| `title_frame` | `72,36,340,112` | `108,58,268,68` | `179x45` content | top-left |
| `back_frame` | `1580,46,268,96` | `1610,66,208,54` | `139x36` content | top-right |
| `nav_panel` | `72,172,324,840` | `104,210,260,752` | `216x560` panel | fixed left rail |
| six nav buttons | `104,y,260,104`; `y=222,340,458,576,694,812` | `146,y+26,212,52` | `141x35` text zone | gaps 14px; longest label uses 15–22px |
| `center_panel` | `420,172,620,840` | `452,208,556,760` | `413x560` panel | expands between rail/detail |
| `center_header` | — | `540,222,380,44` | `253x29` | clear of top claws/gem |
| `center_list_scroll` | `452,278,556,690` | rows end at `x=976`; lane `990,290,18,664` | `371x460` | required scroll; 17-character sample content height 2874px |
| four row frames | `460,y,516,154`; `y=290,460,630,800` | repeated zones below | `344x103` | 16px gaps |
| row image well | `480,y+20,122,114` | `502,y+30,88,96` | `59x64` image zone | large actual image; no category emblem |
| row display-name | — | `616,y+47,330,60` | `220x40` | centered; Russian only |
| `detail_panel` | `1064,172,784,840` | `1096,208,720,760` | `523x560` panel | largest column |
| `detail_title` | — | `1200,222,508,46` | `339x31` | clear of corner claws |
| preview well | `1108,284,300,300` | `1140,310,236,248` | `157x165` image zone | no bars below it |
| two chip frames | `1432,310,330,70`; `1432,396,330,70` | `1450,331,268,32`; `1450,417,268,32` | `179x21` | maximum two sample chips; runtime may wrap to two rows |
| `detail_scroll` | `1108,606,684,356` | body `1140,632,610,304`; lane `1776,632,16,304` | `407x203` body | `content_h=640`; required scroll |

The only vertical scrollbar lanes are at the far right of the center scroll and
inside the lower detail-text well. There is no scrollbar, separator or stray
vertical bar below the preview image.

## Frame Margins And Forbidden Ornament Zones

Values are measured against the accepted PixelLab layer at the 1920 anchor.
The source is a full-page reference, not a baked runtime atlas.

| Frame | Texture/ornament margin L/T/R/B | Required content margin L/T/R/B | Reserve | Forbidden zones |
| --- | --- | --- | --- | --- |
| title | `24/16/24/16` | `36/22/36/22` | `12/6/12/6` | ruby sockets, pointed caps, gold lip |
| Back | `18/14/18/14` | `30/20/30/22` | `12/6/12/8` | violet sockets, outer bevel |
| navigation shell | `24/28/24/34` | `32/38/32/50` | `8/10/8/16` | top diamonds, corner claws, side rails, bottom crest |
| nav button | `12/12/12/12` | real empty label interior `20/18/20/18` from visible ornament | `8/6/8/6` | side gems, caps, gold rim |
| center shell | `28/30/28/30` | `32/36/32/44` | `4/6/4/14` | top crest/gem/claws, side rails, bottom sockets |
| list row | `10/10/10/10` | name starts 156px after row left; image inset 42px from row left | `12px` minimum | row bevel, image-well rim |
| detail shell | `28/30/28/30` | irregular sub-zones above | `8–20px` | top gem/claws, side rails, bottom corner sockets |
| preview well | `12/12/12/12` | image `32/26/32/26` | `14px` minimum | square gold rim and dark bevel |
| detail body | `12/12/12/12` | text `32/26/42/26` | `14px` minimum | body bevel; scrollbar lane |

Every live Control, hitbox, label, icon and image must stay inside these content
rectangles. Bounding-box containment in the outer panel alone is insufficient.

## Real Image And Name Policy

Center rows use exactly one canonical entry image and one centered Russian
display-name. They never show internal IDs, English duplicates, descriptions,
category emblems or secondary micro-icons.

- Character source: `ProgressionData.CHARACTER_CONFIGS[*].sprite_path`.
  Transparent 512 canvases must be alpha-bbox cropped for display with 8% clear
  reserve, bottom-center aligned. The preview-only crops in
  `../../references/scrum1017_codex_navigation_icons/character_samples/` are
  deterministic derivatives of the canonical pixels, not new art.
- Monster source: `CodexData.MONSTERS[*].sprite`; use contain, centered, no crop
  unless the source includes transparent outer canvas.
- Artifact source: `assets/sprites/ui/icons/artifacts/artifact_<id>.png`; use
  contain, centered. The artifact preview demonstrates the accepted SCRUM-957
  real icons, not generic fallback art.
- Row image zone is `88x96` at 1080p (`59x64` at 720p, `117x128` at 1440p),
  visibly larger than the live 56px Codex row slot.
- Detail preview is `236x248` at 1080p (`157x165` at 720p, `315x331` at 1440p).
- Names use centered word-smart wrapping, maximum two lines. Runtime font
  target is 24px at 1080p, clamped to 15px at 720p and 30px at 1440p. If a
  canonical Russian name still cannot fit in two lines, shrink to the minimum;
  never substitute a raw ID.

## Responsive Rules

The supported matrix is 16:9, so use uniform scale
`s=min(viewport_width/1920, viewport_height/1080)` and preserve aspect.
`geometry.report.json` independently verifies every panel remains in canvas and
all three state layouts have pixel-identical zone rectangles.

- **1280x720 (`s=0.6667`)**: nav/center/detail are
  `48,115,216,560`, `280,115,413,560`, `709,115,523,560`; inter-panel gaps are
  16px. Row image zone is at least `59x64`; preview is `157x165`; nav buttons
  are `173x69`. Fonts clamp to 15px for the longest tab/name and 17px for body.
- **1920x1080 (`s=1`)**: exact rectangles above; inter-panel gaps are 24px.
- **2560x1440 (`s=1.3333`)**: nav/center/detail are
  `96,229,432,1120`, `560,229,827,1120`, `1419,229,1045,1120`; gaps are 32px.
  Cap tab/name fonts at 30px and body at 32px so ornament density stays calm.
- For narrower/non-16:9 windows Backend must letterbox this 16:9 composition or
  introduce an explicit compact layout; it must not compress columns across
  frame borders.

Responsive visual evidence:
`../../previews/scrum1017_codex_navigation_icons_responsive_contact.png` plus
the full `1280x720` and `2560x1440` character mockups/debug overlays in this
folder.

## Interaction States

- Selected nav/row: gold rim or tint only; exact rect and baseline do not move.
- Hover/focus/pressed: contrast/rim change only; no scale pulse that could touch
  ornament or a sibling.
- Locked entry: contained silhouette, `Заперто` chip and player-facing unlock
  condition in detail; keep the Russian name visible when product rules allow.
- Empty/loading/error: preserve the three panels and put one short message only
  inside the corresponding content zone.
- Center and detail scroll follow keyboard/gamepad focus. Scrollbars never
  overlap text, image wells or frame ornament.
- Default focus is the first nav button. LB/RB cycles all six sections; Esc/B
  and `НАЗАД` return to the main menu.

## Generated Assets And Evidence

| Asset | Path | Size/mode | Purpose |
| --- | --- | --- | --- |
| PixelLab source | `../../references/scrum1017_codex_navigation_icons/pixellab_scrum1017_codex_navigation_icons_v1_672x378.png` | `672x378 RGBA`, true binary alpha | direct source frame layer |
| 1920 base | `../../references/scrum1017_codex_navigation_icons/pixellab_scrum1017_codex_navigation_icons_base_1920x1080.png` | `1920x1080 RGBA` | nearest-neighbour scale only |
| Character mockup | `codex_characters_mockup_1920x1080.png` | `1920x1080` | character path/crop example |
| Monster mockup | `codex_monsters_mockup_1920x1080.png` | `1920x1080` | monster path/abilities example |
| Artifact mockup | `codex_artifacts_mockup_1920x1080.png` | `1920x1080` | real artifact-icon example |
| Debug overlays | `codex_*_mockup_debug_1920x1080.png` | `1920x1080` | frame-safe zone inspection |
| Provenance | `../../references/scrum1017_codex_navigation_icons/manifest.json` | JSON | IDs, requests, hashes, alpha and no-fallback record |

PixelLab source alpha: 72,393 transparent, 181,623 opaque, zero partial pixels.
No OpenAI Images, manual frame drawing or legacy generator was used.

## Backend Handoff — SCRUM-954

Runtime integration remains Back-end-owned. Exact read targets:

- `scripts/ui_screens.gd::_show_codex_screen`
- `CODEX_SECTIONS`, `_show_codex_section`, `_codex_entry_panel`
- `_codex_update_tab_selection`, `_codex_set_selected_entry`
- `_codex_update_detail`, `_codex_character_sections`,
  `_codex_monster_sections`, `_codex_artifact_sections`, `_codex_stat_sections`
- `_build_codex_characters`, `_build_codex_monsters`, `_build_codex_artifacts`,
  `_build_codex_stats`, `_build_codex_ascensions`
- `scripts/codex_data.gd`, `scripts/stat_formulas.gd`

Implementation requirements:

1. Recreate the exact three-column geometry with responsive Controls; do not
   bake a final mockup PNG as the interactive UI.
2. Replace the current five-entry `CODEX_SECTIONS` with the accepted six labels
   and preserve the SCRUM-1013 base/derived semantic split.
3. Center each row display-name and remove summary/raw-ID/English text from the
   center row. Keep deep data only in the right scroll.
4. Remove both old stray preview bars; render only the two declared scrollbar
   lanes.
5. Preserve lazy section build, focus-follow, mouse/keyboard/gamepad navigation,
   locked-state projection and discovery data.

## Backend Handoff — SCRUM-958

Exact data/image targets:

- `scripts/progression_data_characters.gd::CHARACTER_CONFIGS[*].sprite_path`
- `scripts/codex_data.gd::MONSTERS[*].sprite`
- `scripts/ui_screens.gd::_artifact_icon_texture`
- `assets/sprites/ui/icons/artifacts/artifact_<id>.png`
- `_codex_entry_portrait_size`, `_codex_portrait`, `_codex_icon_slot`
- `CodexPortraitSlot`, `CodexArtifactIconSlot`, `CodexDetailPortraitSlot`,
  `CodexDetailPortraitTexture`

Implementation requirements:

1. Apply the row/detail sizes and crop/contain policy above to canonical images.
2. Never insert `CODEX_PL_ICONS` or fallback category emblems into entry rows.
3. Keep artifact icons alpha-contained and characters bottom-centered after
   transparent-canvas crop/zoom.
4. Do not change gameplay data, unlock rules or artifact stats.

## Required Backend Verification

Run through `tools/godot_gate.py`:

- `tests/codex_data_smoke_test.gd`
- `tests/runtime_smoke_ui_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `tests/dark_fantasy_ui_theme_test.gd`
- `tests/asset_reference_integrity_test.gd`
- `tests/runtime_smoke_test.gd`

Add focused assertions for six tabs, centered Russian-only row text, canonical
image paths, minimum row/preview sizes, absent preview bars and content-zone
containment at 1280x720 / 1920x1080 / 2560x1440.

## Acceptance Checks

- [x] Full content/control/state inventory exists.
- [x] Planning gate is `ready_for_image`, `ok=true`, 51/51.
- [x] PixelLab MCP source and provenance are recorded; no fallback.
- [x] All six Russian labels fit in real dark interiors.
- [x] Character, monster and artifact states use actual images and Russian names.
- [x] Three final compositor reports are `ok=true`, 22/22 zones each.
- [x] Debug overlays pass the strict empty-frame-zone rule.
- [x] 1280/1920/2560 geometry and preview evidence exist.
- [x] Backend handoff names exact paths, policies and tests for SCRUM-954/958.
- [ ] Independent Design QA accepts the package.

## Deviations

PixelLab rejected the initial `688x387` size before creating an asset because
the service limit for this aspect is `688x384`. The accepted generation uses
the proven exact 16:9 `672x378` size and is scaled to 1920x1080 without aspect
distortion. The right-edge vertical line in the source is part of the outer
detail-frame side treatment and lies outside all declared content zones; there
are no lines or bars below the preview well.
