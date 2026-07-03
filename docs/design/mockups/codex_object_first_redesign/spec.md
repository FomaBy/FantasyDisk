# UI Mockup Spec - Codex Object-First Redesign

Status: ready_for_integration
Role owner: Design
Task: `docs/tasks/design_codex_object_first_redesign_task.md`
Jira: SCRUM-849
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/mockups/codex_object_first_redesign/pixellab_mockup_v1.png`
Preview PNG: `docs/design/previews/codex_object_first_redesign_mockup_v1.png`
Generated with: PixelLab MCP UI panel; source ID: `e55602bb-9328-4427-bbad-f3df60aa1e82`

## Source Request

Redesign the in-game Codex as an object-first screen inspired by the Hero Atlas
and Settings v6: large readable object images, a quiet left category rail, a
concise center selected/list area, and a right detail area where the selected
object image is the dominant visual. Remove decorative frames that do not carry
meaning.

## Design Intent

- Preserve all six live sections: Characters, Monsters, Artifacts, Stats,
  Glossary, Ascensions.
- Keep a single dark fantasy dragon/library shell instead of three competing
  ornate frames.
- Left rail is navigation only. Center area is quick recognition and selection.
  Right area is the full reading/detail surface.
- The right object stage must be the largest image placement on the screen.
- Runtime text, icons, portraits, scrollbars, and hitboxes live only in the
  declared safe zones.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| screen_shell | Background frame | dark Codex library shell | `72,54,1776,972` | full centered | `1184x648` | 0 | static | none |
| title_strip | Label zone | `Кодекс` + active section subtitle | `360,72,1200,96` | top centered | `720x72` | 5 | static | screen_shell |
| left_category_panel | Panel | category rail | `96,210,300,700` | left/full height | `210x466` | 10 | static | screen_shell |
| category_button_1..6 | Button | section label + optional icon | `126,250/340/430/520/610/700,240,72` | left stack | `168x48` | 20 | normal/hover/focus/pressed/selected | left_category_panel |
| back_button | Button | back action | `126,820,240,66` | left bottom | `168x44` | 20 | normal/hover/focus/pressed | left_category_panel |
| center_overview_panel | Panel | selected/list overview | `438,210,490,700` | center-left | `340x466` | 10 | static | screen_shell |
| center_object_stage | Texture stage | selected object image | `510,264,346,292` | top center | `240x200` | 20 | selected/locked/empty | center_overview_panel |
| center_title_summary | Text zone | title + one short summary | `500,590,366,128` | below object | `250x86` | 20 | selected/empty | center_overview_panel |
| center_list_strip | Selector/list | compact entry list or selector | `500,742,366,118` | bottom center | `250x78` | 20 | focus/selected/scroll | center_overview_panel |
| right_detail_panel | Panel | full selected detail | `960,210,840,700` | right/full height | `560x466` | 10 | static | screen_shell |
| right_object_stage | Texture stage | largest selected object image | `1080,258,600,360` | top right | `400x240` | 20 | selected/locked/empty | right_detail_panel |
| right_chip_row | Chip row | 2-4 metadata chips | `1110,642,540,64` | below object | `360x42` | 20 | optional chips | right_detail_panel |
| right_text_scroll | Scroll text | full body/detail text | `1050,730,660,134` | bottom right | `440x90` | 20 | scroll/focus | right_detail_panel |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| screen_shell | TBD from PixelLab package or existing `codex_pl_backdrop` reuse | 1920x1080 design layer | 72/54/72/54 | 120/150/120/120 | outer shell, dragon corners, brass rails | no for full-screen art |
| left_category_panel | TBD or existing compatible panel | 300x700 design zone | 24/28/24/28 | 30/30/30/30 | bevel, rivets, side accents | yes if generated as panel asset |
| category_button | TBD or existing button family | 240x72 design zone | 26/14/26/14 | 34/16/34/16 | end caps, rivets | yes if generated as button state sheet |
| center_overview_panel | TBD or existing minimal panel | 490x700 design zone | 28/28/28/28 | 34/34/34/34 | border, top crest | yes |
| center_object_stage | panel-internal stage | 346x292 | 22/22/22/22 | 28/28/28/28 | edge filigree | no crop; object-fit contain |
| right_detail_panel | TBD or existing minimal panel | 840x700 design zone | 36/36/36/36 | 44/44/44/44 | border, corners, separator caps | yes |
| right_object_stage | panel-internal stage | 600x360 | 30/30/30/30 | 36/36/36/36 | edge filigree | no crop; object-fit contain |
| right_text_scroll | parchment/scroll content zone | 660x134 | 22/18/28/18 | 28/20/34/20 | scrollbar gutter, parchment edge | yes |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pixellab_mockup_v1 | `docs/design/mockups/codex_object_first_redesign/pixellab_mockup_v1.png` | PixelLab reference mockup | 688x384 | opaque reference | n/a | see zones | generated in UI panel mode |
| safe_overlay_v1 | `docs/design/previews/codex_object_first_redesign_safe_zones_v1.png` | debug safe-zone overlay | 1920x1080 | opaque preview | n/a | green rectangles | local annotation over planned geometry |

## Responsive Rules

- 1280x720: scale all base rects by `0.6667`; minimum category button height
  `48`, center object stage `240x200`, right object stage `400x240`.
- 1920x1080: use base rects above.
- 2560x1440: scale by `1.3333`; cap text sizes to existing Codex font maxima,
  but keep image stages scaled so object art remains primary.
- Aspect is fixed 16:9. For non-16:9 windows, center the 16:9 safe layout inside
  the usable viewport and keep background art cover-cropped only behind safe
  zones.

## Interaction States

- Category buttons: normal, hover, focus, pressed, selected; no state may resize
  or move the button.
- Center selector/list: focusable entries; selected entry updates both center
  and right detail.
- Back button: normal, hover, focus, pressed.
- Empty/locked entries: object stage may show silhouette/fallback, but body text
  remains inside the same safe zones.
- Gamepad: first category focused on open; LB/RB cycles categories; B/Escape/back
  returns to main menu.

## Implementation Notes For SCRUM-850

- Keep `scripts/codex_data.gd` as the source of truth.
- Do not crop object art to fill a rectangle. Use contained object-fit with
  nearest filtering and alpha-bbox centering where possible.
- Hero images: prefer `ProgressionData.character_config().sprite_path`.
- Artifact images: `assets/sprites/ui/icons/artifacts/artifact_<id>.png`.
- Shop-only item images: `assets/sprites/ui/icons/shop/shop_<id>.png`.
- Monster/boss images: use `CodexData.MONSTERS[*].sprite` and document low
  quality fallbacks as separate Design follow-ups.
- Stats: use `scripts/ui_icon_registry.gd`.
- The center area must not duplicate the full detail text. It is only image,
  title, and one short summary/selector.

## Acceptance Checks

- [x] Mockup generated through PixelLab MCP.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No UI content is assigned to frame border, ornament, gem, metal, or corner.
- [x] Runtime content zones are declared at 1280x720, 1920x1080, and 2560x1440.
- [x] Hover/focus/pressed/disabled states must not resize or shift layout.
- [ ] Screenshot comparison completed after implementation by SCRUM-850.
- [ ] Task/Jira updated when applicable.

## Deviations

- PixelLab UI panel output is `688x384` because the tool caps 16:9 UI panel
  generation at that size. The geometry contract is authored at `1920x1080` and
  the PixelLab image is a style/layout reference, not a 1:1 runtime texture.
- No new production frame/button sprites are promoted by this design task.
  SCRUM-850 should first try existing Codex/Settings-family assets against this
  safe-zone contract, then create a small follow-up or generate production
  sprites only if the existing assets cannot preserve the object-first layout.
