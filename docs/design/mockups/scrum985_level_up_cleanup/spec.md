# UI Mockup Spec — SCRUM-985 Level Up cleanup

Status: implemented
Role owner: combined UI Design + Back-end integration
Task: `docs/tasks/SCRUM-985_level_up_icon_frame_background_fix.md`
Jira: SCRUM-985
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/previews/scrum985_level_up_cleanup/mockup_1920x1080.png`
Preview PNG: `docs/design/previews/scrum985_level_up_cleanup/mockup_1920x1080.png`
Generated with: PixelLab MCP via `create_ui_asset`; accepted source ID `d3e5030c-b61d-4899-83ba-04fd6ccafaa9`

## Source Request

Убрать самую большую внешнюю раму экрана повышения уровня, исправить предметные
иконки, которые визуально выходят за свой слот, и сделать фон заметно ярче.

## Content Inventory

- title and subtitle;
- three fixed reward cards;
- optional advisor badge per card;
- one reward icon per card;
- one-line title, two-line description and one-to-three effect delta rows;
- `Позже` button;
- default, hover, focus and pressed card/button states;
- no scrollbar.

## Screen Elements @1920x1080

| ID | Type | Runtime content | Rect | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| content_field | translucent panel | all screen content | 96,24,1728,1032 | center/full | 1152x648 | 2 | static | viewport |
| title | Label | screen title | 480,42,960,72 | center/top | 640x48 | 10 | static | content_field |
| subtitle | Label | instruction | 420,126,1080,46 | center/top | 720x34 | 10 | static | content_field |
| card_1..3 | Button | reward card | 135/700/1265,315,520,445 | center | 320x300 | 8 | normal/hover/focus/pressed | content_field |
| icon_slot_1..3 | icon slot | frame/halo only | card center,380,120,120 | local center | 88x88 | 10 | glow only | card |
| icon_safe_1..3 | TextureRect | reward icon | slot inset 24, 72x72 | local center | 56x56 | 11 | static | icon_slot |
| later_button | Button | `Позже` | 790,900,340,76 | center/bottom | 260x72 | 12 | normal/hover/focus/pressed | content_field |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| outer screen frame | removed | n/a | n/a | n/a | entire outer border absent | n/a |
| content_field | runtime `StyleBoxFlat` | responsive | 2px border | 28/20/28/20 @2K scaled | border and corners | yes |
| reward card | runtime `StyleBoxFlat` | responsive | 2px border | 16.8/12/16.8/12 @2K scaled | border and corners | yes |
| icon slot | existing atlas socket or calm halo | 120x120 @1080p plan | visual ring only | 24px on every side | entire ring/ornament | no; square contain |

The reward image itself is constrained to `72x72` inside `120x120`; caller must
lower `custom_minimum_size` before assigning `size`, otherwise the registry's
small-icon readability expansion can leave the Control larger than its safe rect.

## Responsive Rules

- 1280x720: uniform scale from the safe viewport; card description remains two lines; icon safe rect not below 56x56; button 260x72.
- 1920x1080: use the base rectangles above.
- 2560x1440: scale to current 2K design metrics; icon safe rect 72px inside 128px socket; no outer frame.

## Visual Direction

- no decorative border around the viewport;
- brighter visible arcane-laboratory background with indigo/teal magic and warm gold highlights;
- central content field remains dark translucent for contrast, not opaque black;
- thin local card borders only;
- icon art stays inside a quiet inner square and never crosses the socket/ring;
- no baked text, pseudo-text, logo or watermark in PixelLab source.

## Acceptance Checks

- [x] Planning report is `ready_for_image`.
- [x] Mockup generated through PixelLab MCP and provenance recorded.
- [x] Preview shown in chat.
- [x] Outer frame is absent.
- [x] Every icon stays inside the 72x72 safe rect.
- [x] Content never overlaps ornament.
- [x] Runtime screenshot matrix matches the material visual direction.

## Deviations

PixelLab candidate `87b81cec-94a2-41cd-be7e-c2177dd8bc2a` was rejected because
the generated full panel reintroduced the forbidden outer frame despite the
prompt. The accepted second candidate is a transparent component-only layer;
the current accepted arcane-laboratory background is reused underneath it and
brightened in the preview. No generated bitmap is promoted to runtime assets.
Runtime keeps the existing Atlas card/socket assets instead of the generated
component layer, removes `LevelUpFrame`, and uses the generated layer only as
design reference. Verified captures are `runtime_1280x720.png`,
`runtime_1920x1080.png`, and `runtime_2560x1440.png` in the sibling preview
directory.
