# UI Mockup Spec - SCRUM-331 Progression And Codex

Status: ready_for_integration
Role owner: Design
Task: `docs/tasks/art_ui_overhaul_progression_codex_task.md`
Jira: SCRUM-331
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/mockups/scrum331_progression_codex/scrum331_progression_codex_mockup.png`
Reference mockup PNG: `docs/design/references/ui_overhaul_progression_codex/scrum331_progression_codex_mockup.png`
Frame kit preview: `docs/design/previews/scrum331_progression_frame_kit_contact.png`
Generated with: OpenAI Images API via `fantasydisk-asset-generator`

## Source Request

SCRUM-331 covers the progression and Codex cluster: skill tree / ascension
progression, Codex sections, and glossary tooltip popups. Codex already has an
accepted texture kit from SCRUM-345/SCRUM-403; this pass adds the missing
progression/skill-tree frame language and documents how it coexists with Codex.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| skill_tree_backdrop | TextureRect | codex/system backdrop | `0,0,1920,1080` | full | `1280x720` | 0 | default | viewport |
| skill_tree_panel | PanelContainer | whole skill tree surface | `48,72,1240,900` | full with margins | `900x560` | 10 | default | progression_main_panel |
| skill_tree_header | HBox | title, points, back | `96,96,1144,96` | panel top | `720x80` | 20 | default | progression_main_panel content |
| points_badge | Badge | skill point count | `980,102,128,96` | header right | `96x80` | 30 | default | progression_points_badge |
| class_panel | PanelContainer | selected class wins/bonuses | `96,206,480,210` | panel left | `360x160` | 20 | default | progression_class_panel |
| branch_panel_0 | PanelContainer | branch title + node stack | `620,220,260,650` | panel grid | `190x430` | 20 | default | progression_branch_panel |
| branch_panel_1 | PanelContainer | branch title + node stack | `892,220,260,650` | panel grid | `190x430` | 20 | default | progression_branch_panel |
| branch_panel_2 | PanelContainer | branch title + node stack | `1164,220,260,650` | panel grid | `190x430` | 20 | default | progression_branch_panel |
| skill_node_available | Button | node icon/title/cost/desc | `branch relative 78,110,96,96` | branch stack | `72x72` | 35 | available/hover/focus | progression_node_available/focus |
| skill_node_locked | Button | node icon/title/cost/desc | `branch relative 78,250,96,96` | branch stack | `72x72` | 35 | locked/disabled | progression_node_locked |
| skill_node_purchased | Button | node icon/title/cost/desc | `branch relative 78,390,96,96` | branch stack | `72x72` | 35 | purchased | progression_node_purchased |
| codex_main_panel | PanelContainer | existing Codex main UI | `1060,72,812,840` | right | `680x600` | 10 | default | SCRUM-345 codex_main_panel |
| codex_tabs | Button row | section tabs | `1160,120,620,82` | codex top | `520x62` | 20 | default/hover/pressed/disabled | SCRUM-345 codex tabs |
| codex_entry_list | ScrollContainer | entry cards | `1160,230,470,590` | codex left/content | `360x420` | 20 | scroll | SCRUM-345 section panel |
| codex_detail_panel | PanelContainer | selected/detail content | `1640,230,210,430` | codex right | `170x320` | 20 | default | SCRUM-345 section panel |
| glossary_tooltip | PanelContainer | term title + desc | `700,766,620,270` | near anchor, clamped | `420x180` | 80 | visible/hidden | progression_tooltip or Codex tooltip |
| back_button | Button | return to main menu | `1510,938,260,104` | bottom/right | `240x104` | 60 | default/hover/pressed/focus | red_gold_back_l |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| progression_main_panel | `assets/sprites/ui/frames/progression/ui_frame_progression_main_panel.png` | `1024x640` | `78,92,78,86` | `112,128,112,118` | top dragon crest, red gems, side metal | yes |
| progression_branch_panel | `assets/sprites/ui/frames/progression/ui_frame_progression_branch_panel.png` | `384x768` | `54,88,54,92` | `78,126,78,130` | top/bottom gems, side ornaments | proportional or vertical 9-slice after QA |
| progression_node_available | `assets/sprites/ui/frames/progression/ui_frame_progression_node_available.png` | `256x256` | n/a | circular inner radius <= `82px` | four spikes/gems, ring ornament | no, square proportional |
| progression_node_locked | `assets/sprites/ui/frames/progression/ui_frame_progression_node_locked.png` | `256x256` | n/a | circular inner radius <= `82px` | four spikes/gems, ring ornament | no, square proportional |
| progression_node_purchased | `assets/sprites/ui/frames/progression/ui_frame_progression_node_purchased.png` | `256x256` | n/a | circular inner radius <= `78px` | red ring/gems/spikes | no, square proportional |
| progression_node_focus | `assets/sprites/ui/frames/progression/ui_frame_progression_node_focus.png` | `256x256` | n/a | circular inner radius <= `78px` | gold glow ring/gems/spikes | no, square proportional |
| progression_class_panel | `assets/sprites/ui/frames/progression/ui_frame_progression_class_panel.png` | `1024x320` | irregular | content rect `Rect2(250,72,650,176)` | left dragon/round portrait, bottom gem, right cloth | no full-frame 9-slice |
| progression_points_badge | `assets/sprites/ui/frames/progression/ui_frame_progression_points_badge.png` | `256x320` | n/a | content rect `Rect2(58,58,140,150)` | bottom cloth tails, top gem, shield points | proportional |
| progression_tooltip | `assets/sprites/ui/frames/progression/ui_frame_progression_tooltip.png` | `640x320` | `58,58,76,76` | `84,78,112,100` | parchment strip, top/bottom gems, right ribbon | yes |

Codex frames remain SCRUM-345/SCRUM-403 source of truth:
`assets/sprites/ui/frames/codex/ui_frame_codex_*.png` with metadata in
`docs/design/references/codex/codex_ui_texture_kit_metadata.json`.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| cluster_mockup | `docs/design/mockups/scrum331_progression_codex/scrum331_progression_codex_mockup.png` | skill tree + codex + tooltip visual reference | `1920x1088` | opaque mockup | n/a | n/a | Use bottom 8px as bleed |
| frame_asset_sheet | `docs/design/references/ui_overhaul_progression_codex/scrum331_progression_frame_asset_sheet.png` | OpenAI source sheet | `1792x1024` | opaque with baked checkerboard | n/a | n/a | Alpha-cleaned by builder |
| progression_main_panel | `assets/sprites/ui/frames/progression/ui_frame_progression_main_panel.png` | skill tree main panel | `1024x640` | RGBA transparent outside | `78,92,78,86` | `112,128,112,118` | Reference copy under runtime_assets |
| progression_branch_panel | `assets/sprites/ui/frames/progression/ui_frame_progression_branch_panel.png` | branch column frame | `384x768` | RGBA transparent outside | `54,88,54,92` | `78,126,78,130` | Use for each branch |
| progression_node_available | `assets/sprites/ui/frames/progression/ui_frame_progression_node_available.png` | available node | `256x256` | RGBA transparent outside | n/a | inner circle | Keep square |
| progression_node_locked | `assets/sprites/ui/frames/progression/ui_frame_progression_node_locked.png` | locked node | `256x256` | RGBA transparent outside | n/a | inner circle | Keep square |
| progression_node_purchased | `assets/sprites/ui/frames/progression/ui_frame_progression_node_purchased.png` | purchased node | `256x256` | RGBA transparent outside | n/a | inner circle | Keep square |
| progression_node_focus | `assets/sprites/ui/frames/progression/ui_frame_progression_node_focus.png` | focus/hover node | `256x256` | RGBA transparent outside | n/a | inner circle | Same rect as base |
| progression_class_panel | `assets/sprites/ui/frames/progression/ui_frame_progression_class_panel.png` | class progression summary | `1024x320` | RGBA transparent outside | irregular | `Rect2(250,72,650,176)` | Do not place text under dragon head |
| progression_points_badge | `assets/sprites/ui/frames/progression/ui_frame_progression_points_badge.png` | points count badge | `256x320` | RGBA transparent outside | n/a | `Rect2(58,58,140,150)` | Numeric count only |
| progression_tooltip | `assets/sprites/ui/frames/progression/ui_frame_progression_tooltip.png` | glossary/skill tooltip option | `640x320` | RGBA transparent outside | `58,58,76,76` | `84,78,112,100` | Codex may keep existing tooltip |

## Responsive Rules

- 1280x720: skill tree should keep all branch columns visible. If node text does
  not fit inside circular nodes, use icon+cost in the node and show title/desc in
  `progression_tooltip` on hover/focus.
- 1920x1080: use base rectangles above. Branch columns fit without horizontal
  scroll; codex keeps SCRUM-345/403 layout.
- 2560x1440: scale the skill-tree panel up to max width `1700px`, then increase
  column gaps. Keep node frames square and do not stretch circular rings.

## Interaction States

- Skill node available: `progression_node_available`; enabled/focusable.
- Skill node locked: `progression_node_locked`; disabled, no purchase action.
- Skill node purchased: `progression_node_purchased`; enabled only for tooltip,
  no repeat purchase.
- Skill node hover/focus: same rect, swap/tint to `progression_node_focus`.
- Codex tabs/cards/tooltips: keep SCRUM-345/403 states unless Back-end finds a
  mismatch with this spec.

## Implementation Notes

- Godot owner: Back-end UI (`scripts/ui_screens.gd`).
- Suggested skill tree implementation:
  - wrap `_show_skill_tree_screen` content in `progression_main_panel`;
  - use `progression_class_panel` for `SkillTreeClassPanel`;
  - render each `SkillTreeBranches` column inside `progression_branch_panel`;
  - represent node status with the four circular node frames and keep text in
    tooltip or adjacent content rows, not on the ornate ring.
- Keep Codex runtime on existing `assets/sprites/ui/frames/codex/` paths. SCRUM-331
  is not a request to replace the already accepted Codex texture kit.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] Generated progression assets are alpha-cleaned into runtime `assets/` and reference copies.
- [x] Codex pre-existing accepted kit is preserved in the spec.
- [x] Safe zones and forbidden ornament zones are documented.
- [ ] Runtime screenshot comparison is pending Back-end integration.
- [ ] UI no-overlap/runtime smoke is pending Back-end integration.

## Deviations

- The OpenAI mockup was auto-corrected to `1920x1088`; treat bottom 8px as bleed.
- The generated source sheet baked a checkerboard background; the deterministic
  builder removes light low-saturation checker pixels and writes transparent PNGs.
- SCRUM-331 is Design-scope in this pass. Runtime wiring is handed off to
  Back-end because live skill tree purchase state, Codex lazy section building,
  glossary popup positioning, focus and escape behavior are code-owned.
