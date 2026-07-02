# UI Mockup Spec - HS4 Hero Select Portrait Crop And Carousel Labels

Status: implemented
Role owner: Back-end UI
Task: `docs/tasks/ui_hero_select_portrait_scale_labels_task.md`
Jira: SCRUM-822
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: existing accepted HS4 black-minimal runtime direction, no new frame art
Preview PNG: runtime screenshot evidence under `build/qa/scrum-798/` when capture tests run
Generated with: existing accepted HS4 runtime layout; no new PixelLab art because this pass changes runtime placement/crop/labels only

## Source Request

User requested a second Hero Select polish pass: make the large left character
preview slightly bigger and aligned, make bottom carousel characters slightly
bigger, crop empty left/right transparent canvas, and show character names in
the carousel.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `HS4PortraitFrame` | clipped Control | selected hero preview zone | approx `143,56,482,482` | left/top | `320x320` | 10 | selected/animated | black screen interior |
| `HS4Portrait` | TextureRect | selected animated/static hero frame | alpha-bbox positioned inside `HS4PortraitFrame` | top-left inside frame | texture-derived | 11 | animated | `HS4PortraitFrame` |
| `HS4Carousel` | Control | carousel rail | approx `67,722,1786,332` | bottom full width | 3 slots | 20 | default/focus | black screen interior |
| `HS4CarouselSlot_*` | Button | hero selectable slot | approx `305x305` at 1080p | bottom rail | `184x184` | 21 | default/hover/focus/selected | `HS4Carousel` |
| `HS4CarouselPortrait_*` | TextureRect | hero thumbnail frame | alpha-bbox positioned above label strip | slot-local | texture-derived | 22 | selected/dimmed | `HS4CarouselSlot_*` |
| `HS4CarouselLabel_*` | Label | localized class name | bottom `34px` strip inside slot | slot bottom | `24px` high | 23 | selected/dimmed | `HS4CarouselSlot_*` |

## Frames And Safe Zones

No new decorative frames are introduced. The screen remains the accepted
SCRUM-798 black-minimal Hero Select. The safe zones are plain clipped runtime
Controls, not ornate frames; therefore the key rule is that portraits and text
stay inside their clipped slot/preview interiors and do not overlap other major
zones.

## Generated Assets

None. All portraits reuse existing character `sprite_path` and SpriteFrames
resources.

## Responsive Rules

- 1280x720: carousel slots are about `203px`; label strip `~30px`; at least 5
  visible slots should fit with reduced slot-gap. Big preview frame stays at
  least `320x320`, but the visible alpha body is scaled much larger than the
  old full-canvas fit.
- 1920x1080: carousel slots are about `305px`; label strip `34px`; 5 visible
  slots should fit. Big preview alpha body targets about `92%` of preview-frame
  height while respecting visible bbox width.
- 2560x1440: carousel slots cap near `320px` to protect major-zone overlap.
  Big preview frame can reach the wider left column cap, with the visible body
  centered and bottom-aligned.

## Interaction States

- Slot selected: existing HS4 selected button theme + full-opacity portrait +
  bright name label.
- Slot unselected: existing dim portrait behavior + dimmer label.
- Hover/focus/pressed: existing Button theme; label and portrait bounds do not
  change.
- Empty/off-page slot: hidden.

## Implementation Notes

- Godot script: `scripts/ui_screens.gd`.
- Use a cached alpha-bbox scan per texture to ignore transparent canvas padding.
- Position previews by visible alpha bbox:
  - horizontal: visible bbox center aligns to preview/slot center;
  - vertical: visible bbox bottom aligns to preview floor or carousel label top;
  - scale: visible bbox targets the available visible area, not the full
    `512x512` texture.
- Carousel labels use `ProgressionData.character_config(id).title`.
- Runtime labels remain outside baked art and inside button slots.

## Acceptance Checks

- [x] Spec exists before runtime layout commit.
- [x] No new art/frame asset is required for this layout-only pass.
- [x] Big preview visible alpha body is enlarged and bottom-centered.
- [x] Carousel portraits use alpha-bbox crop/scale and remain baseline-aligned.
- [x] Carousel names are visible, readable, and do not resize slots.
- [x] Focus/click behavior remains on `HS4CarouselSlot_*` buttons.

## Deviations

The UI Director full-art mockup rule is intentionally handled as a geometry spec
amendment because the user requested runtime scale/crop/label polish on the
already accepted HS4 black-minimal page. Generating new PixelLab frame/mockup art
would change visual direction and add unnecessary art scope.
