# UI Mockup Spec - Pause And Result Screens

Status: ready_for_integration
Role owner: Design
Task: `docs/tasks/art_ui_overhaul_pause_end_task.md`
Jira: SCRUM-330
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/references/ui_overhaul_pause_end/pause_end_cluster_mockup.png`
Preview PNG: `docs/design/previews/ui_overhaul_pause_end_contact.png`
Generated with: OpenAI Images API via `fantasydisk-asset-generator`

## Source Request

Redesign the pause menu, pause dossier/stats, victory screen and death screen in
the FantasyDisk D&D + Dark Fantasy Dragon UI family. Runtime content must stay
inside empty content zones; no text, buttons, icons or hit areas may overlap
decorative metal, dragon heads, wings, gems, crests or frame borders.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pause_modal_frame | TextureRect or verified 9-slice frame | pause title, body/buttons | `Rect2(360, 140, 1200, 800)` target | center | `720x576` | 20 | default | `pause_end_modal_frame` |
| pause_title_zone | Label container | Pause title | `Rect2(520, 285, 880, 60)` target | inside modal | `320x44` | 30 | default | `pause_end_modal_safe` |
| pause_body_zone | VBox/Grid container | pause buttons or stats content | `Rect2(520, 360, 880, 420)` target | inside modal | `360x280` | 30 | hover/focus on children | `pause_end_modal_safe` |
| pause_action_zone | Button row/column | Resume, stats, menu/end run | `Rect2(650, 785, 620, 86)` target | inside modal | `280x60` | 32 | default/hover/focus/pressed/disabled | `pause_end_modal_safe` |
| victory_crest | TextureRect | decorative victory crest | top of victory box | center | `144x144` | 35 | default | decorative only |
| defeat_crest | TextureRect | decorative defeat crest | top of defeat box | center | `144x144` | 35 | default | decorative only |
| result_title_zone | Label container | Victory/defeat title | below crest | center | `320x52` | 36 | default | modal safe area |
| result_body_zone | Label container | result summary | below title | center | `520x180` | 36 | default | modal safe area |
| result_action_zone | Button container | New run / back to menu | bottom safe area | center | `280x60` | 38 | default/hover/focus/pressed | modal safe area |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| `pause_end_modal_frame` | `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png` | `1280x1024` | estimate `160,170,160,164` | `170,180,170,174` | top dragon head/wings, side dragon columns, ruby gems, bottom crest, outer metal border | Prefer proportional whole-image `TextureRect`; 9-slice only after Back-end verifies center stretch does not distort ornaments |
| `ui_crest_victory` | `assets/sprites/ui/result_crests/ui_crest_victory.png` | `870x1002` | none | decorative only | entire crest ring and gems | no |
| `ui_crest_defeat` | `assets/sprites/ui/result_crests/ui_crest_defeat.png` | `935x1004` | none | decorative only | entire crest ring, skull, blade and gems | no |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `pause_end_cluster_mockup` | `docs/design/references/ui_overhaul_pause_end/pause_end_cluster_mockup.png` | UI direction mockup sheet | `1920x1088` source, `1920x1080` preview crop | opaque mockup | n/a | n/a | Reference only; no runtime text baked |
| `ui_frame_pause_end_modal` | `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png` | Pause/result modal frame candidate | `1280x1024` | RGBA, transparent | `160,170,160,164` estimate | `170,180,170,174` | Derived from generated source `frame_modal.png`, magenta key removed |
| `ui_crest_victory` | `assets/sprites/ui/result_crests/ui_crest_victory.png` | Victory decorative crest | `870x1002` | RGBA, transparent | n/a | decorative only | Existing SCRUM-330 runtime crest accepted |
| `ui_crest_defeat` | `assets/sprites/ui/result_crests/ui_crest_defeat.png` | Defeat decorative crest | `935x1004` | RGBA, transparent | n/a | decorative only | Existing SCRUM-330 runtime crest accepted |

## Responsive Rules

- 1280x720: modal target should be no larger than roughly `800x640`; scale the
  full frame proportionally from its `1.25` source aspect and keep runtime
  content inside the scaled safe rect. If the result screen crest consumes too
  much height, cap crest display at `144-176px` and keep title/body below it.
- 1920x1080: modal target `1200x800` is the design baseline. The action row sits
  in the lower safe field; it must not overlap the lower ruby/crest.
- 2560x1440: modal may scale to `1600x1280` if the viewport allows, but content
  remains inside scaled safe rect. Keep the backdrop visible around the frame.

## Interaction States

- Button/slot hover: use active Red & Gold button theme semantics; do not add
  baked glow over frame ornament.
- Button/slot pressed: preserve layout size; no frame shift.
- Disabled/locked: dim button content only; do not dim the whole modal frame.
- Selected/focus: focus rings must stay inside button content zones.
- Empty/loading: keep empty dark parchment fields, not default Godot panels.

## Implementation Notes

- Godot scene/script owner: Back-end/UI integration in `scripts/ui_screens.gd`.
- Recommended structure: backdrop -> dim -> centered modal frame TextureRect ->
  safe-zone `MarginContainer` -> title/body/actions.
- Do not use one-axis stretching on the whole frame. If the frame is integrated
  as `StyleBoxTexture`, Back-end must verify texture margins against the
  source metadata and use content margins above.
- Existing result crests are decorative header art only. Runtime text/buttons
  should not be placed inside their circular openings in this pass.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview/contact sheet created.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] Design package forbids content overlap on frame border, ornament, gem, metal, or decorative corner.
- [ ] Runtime content fits inside safe zones at every responsive target.
- [ ] Hover/focus/pressed/disabled states do not resize or shift layout.
- [ ] Screenshot comparison completed after implementation.
- [ ] Task/Jira updated when applicable.

## Deviations

Runtime implementation is intentionally handed to Back-end. Design did not edit
`scripts/ui_screens.gd` in this pass to avoid cross-discipline writes in the
shared dev worktree.
