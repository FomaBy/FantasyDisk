# UI Mockup Spec — SCRUM-1088 Priest prayer via Level Up picker

Status: implemented
Role owner: Back-end /root (existing visual family reuse)
Task: `docs/tasks/backend_scrum1088_priest_prayer_attribute_picker_reuse.md`
Jira: SCRUM-1088
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/previews/scrum1088_priest_prayer_attribute_picker/mockup_688x384.png`
Preview PNG: `docs/design/previews/scrum1088_priest_prayer_attribute_picker/mockup_688x384.png`
Generated with: PixelLab MCP `create_ui_asset`; source ID `fde0eec4-3323-47eb-9e29-cb23c048218f`

## Source Request

Стартовый выбор молитвы Священника должен выглядеть и работать как уже
существующий выбор атрибутов/усилений при повышении уровня. Отдельный интерфейс
для молитв не создаётся и больше не является runtime-источником layout/style.

## Inventory And Decision

- Title: `Молитва перед боем`.
- Subtitle: обязательный выбор одного благословения на текущий бой.
- Three prayer cards in canonical order: wrath, mending, aegis.
- Each card uses the live Level Up card builder: socket/icon, title, short
  description and effect-summary field.
- Default, hover, focus and pressed states are the existing Level Up states.
- Cancel is consumed because the pre-battle choice is mandatory.
- No `Позже` button, no scrollbar, no large outer modal and no prayer-specific
  frame/background/card family.

## Screen Elements @1920x1080

| ID | Type | Runtime content | Rect | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| level_up_overlay | Control | backdrop/dim | 0,0,1920,1080 | full rect | viewport | 0 | static/intro | viewport |
| level_up_panel | transparent layout host | all picker content | 96,24,1728,1032 | center | 1152x648 | 2 | static/intro | viewport |
| title | Label | `Молитва перед боем` | 480,42,960,72 | center/top | 640x48 | 10 | intro | level_up_panel |
| divider | TextureRect | existing Atlas divider | 720,112,480,28 | center/top | 320x18 | 9 | static | level_up_panel |
| subtitle | Label | mandatory-choice hint | 420,142,1080,46 | center/top | 720x34 | 10 | static | level_up_panel |
| prayer_card_0..2 | Button | icon/title/description/effect | 135/700/1265,315,520,445 | center | 320x300 | 8 | normal/hover/focus/pressed | level_up_panel |

Runtime uses `_level_up_layout_metrics()` as the exact responsive source; the
rectangles above document the accepted 1080p composition rather than creating
a second geometry implementation.

## Frames And Safe Zones

| Frame ID | Runtime source | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- |
| screen outer frame | none | n/a | viewport safe inset | no outer ornament exists | n/a |
| level_up_panel | live transparent Level Up layout host | 0 | scaled panel pad | viewport edges | n/a |
| prayer/reward card | live Level Up card atlas/theme | 2px visual border equivalent | 17/12/17/12 @1080 plan, scaled from live metrics | border, corners, gems, socket ring | existing Level Up contract |
| icon socket | existing Atlas socket | visual ring | icon contained at 56.25% of socket box | complete ring/ornament | keep square |

All labels, icons and effect text remain in the dark inner zones. Content never
touches gold/ruby/metal ornament. The generated PixelLab layer is design evidence
only and is not promoted to `assets/`.

## Responsive Rules

- 1280x720: use the existing compact Level Up plan; three cards stay disjoint,
  minimum semantic fonts remain readable and no cancel/defer control is shown.
- 1920x1080: use the documented composition.
- 2560x1440: use the live 2K Level Up metrics with the same three cards; no
  prayer-specific frame is introduced.
- Each supported target is built from the same live Level Up metrics; the
  prayer flow intentionally inherits the canonical Level Up resize behavior
  instead of keeping the removed modal's separate resize implementation.

## Interaction States

- Hover/focus/pressed: existing Level Up card theme; no geometry shift.
- Selected: the screen closes after exactly one successful player selection.
- Disabled/locked: root `selection_locked` prevents double-submit while closing.
- Cancel: Escape/keyboard cancel/gamepad B are consumed and cannot bypass the
  required choice.

## Implementation Notes

- Reuse `_create_level_up_menu_box()`, `_level_up_layout_metrics()`,
  `_level_up_card_plan()`, `_make_level_up_reward_button()`,
  `_wire_run_ui_focus()` and `_start_level_up_intro()`.
- Prayer dictionaries may provide an explicit display icon ID, but player
  selection still receives the canonical prayer ID.
- Remove runtime reliance on `BATTLE_PRAYER_FRAME_PATH`, fixed 688x384 card
  rectangles and the bespoke prayer card/label/focus styles.
- Display-only effect summaries are compact enough to render in full at 720p:
  `+20% ко всему урону`, `+2 HP/с`, `−20% вход. урона`. Canonical mechanics and
  progression descriptions are unchanged.

## Runtime Evidence

- `docs/design/previews/scrum1088_priest_prayer_attribute_picker/runtime/priest_prayer_level_up_1280x720.png`
- `docs/design/previews/scrum1088_priest_prayer_attribute_picker/runtime/priest_prayer_level_up_1920x1080.png`
- `docs/design/previews/scrum1088_priest_prayer_attribute_picker/runtime/priest_prayer_level_up_2560x1440.png`

The Metal capture helper waits 75 frames, so the matrix records the stable
picker after Level Up intro particles have faded. All three effect summaries
are complete and contain no ellipsis.

## Acceptance Checks

- [x] PixelLab MCP config smoke passed without printing secrets.
- [x] Mockup generated through PixelLab MCP and preview shown in chat.
- [x] All elements, responsive targets and safe zones are specified.
- [x] Runtime uses the live Level Up shell/card builders.
- [x] Prayer-specific frame/card layout no longer renders.
- [x] Focused/input/no-overlap/runtime tests pass.
- [x] Runtime screenshots at all three targets match the reuse decision and
  contain no clipped/ellipsized effect text.

## Deviations

The PixelLab layout layer visually explores the three-card reuse and is not a
new production asset. Exact runtime art remains the already accepted Level Up
card/socket family, which is the user's requested source of truth.
