# SCRUM-951 — Hero Select Stat Identity Colors

Status: implemented  
Role owner: Back-end integration (Codex), PixelLab art layer generated first  
Task: `docs/tasks/SCRUM-951_hero_stat_colors.md`  
Jira: SCRUM-951  
Base resolution: 1920×1080  
Responsive targets: 1280×720, 1920×1080, 2560×1440  
Mockup PNG: `docs/design/references/scrum951_hero_stat_colors/pixellab_stat_color_art_layer_448x600.png`  
Preview PNG: `docs/design/previews/scrum951_hero_stat_colors/pixellab_stat_color_art_layer_448x600.png`  
Generated with: PixelLab MCP `create_ui_asset`; source ID `395cbafb-358b-4f46-9b95-019b67bf5c48`, seed `951`

Compact 720p mockup: `docs/design/references/scrum951_hero_stat_colors/pixellab_stat_color_compact_2x4_688x384.png`  
Compact preview: `docs/design/previews/scrum951_hero_stat_colors/pixellab_stat_color_compact_2x4_688x384.png`  
Generated with: PixelLab MCP `create_ui_asset`; source ID `c02b9d90-d4c0-431d-af5d-560cb4c3625b`, seed `9511`

## Source Request

Give every right-side Hero Select attribute a stable RPG-readable identity
color without removing the stat name/value or the existing concise tooltip.
Keep the palette reusable and keep all content inside the existing dossier and
global frame safe zones.

## Mockup Decision

The PixelLab outputs are textless **styling art layers**, not new production
frames. The primary layer establishes eight stacked dark-fantasy row treatments
and their color order. The compact layer establishes the 720p 2×4 reflow needed
to retain visible names/numbers after the real screenshot exposed the old
bar-only compact mode. Runtime continues to use the accepted Hero
Select composition and existing hollow `HeroSelectFrame`; no raster asset from
this task is promoted into `assets/`. Labels, values, fill lengths, focus and
tooltips remain live Godot controls.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920×1080 | Anchors | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `HS4StatsColumn` | `Control` | title + eight stat rows | existing right lane of `HS4DossierFrame`, width 220–320 | dossier right/top/bottom | existing | normal | `HS4DossierFrame` interior |
| `HS4Stat_<id>` | `Button` | semantic row + tooltip | one vertical row at 1080p/2K; 2×4 cells at 720p | responsive grid cell | existing | normal/hover/focus | `HS4StatsColumn` |
| `HS4StatName_<id>` | `Label` | localized stat name | left row lane, min width 72 | left/center | existing | visible at supported matrix | stat row interior |
| `HS4StatBar_<id>` | `ColorRect` | dark track | expandable center lane | fill horizontally | existing | normal | stat row interior |
| `HS4StatBarFill_<id>` | `ColorRect` | canonical accent + numeric fill | 4–100% of bar track | left/full height | existing | hero refresh | bar track |
| `HS4StatValue_<id>` | `Label` | numeric value | right row lane, min width 22 | right/center | existing | hero refresh | stat row interior |

Outer screen/dossier geometry is intentionally unchanged. Implementation
inspection found that the previous 1080p 12 px stat typography had a 26 px
combined line minimum inside 21 px rows, and the old 720p branch hid all names
and values. The spec therefore requires a compact stat-only font step plus a
2-column × 4-row grid when the vertical single-column budget cannot retain
visible semantics. The focused test records and encloses every live rectangle
at all three targets.

## Palette And Contrast

| Stat | Bar accent | Label/value | Contrast on `#171613` |
| --- | --- | --- | --- |
| Strength | `#D84A3A` | `#E05B4C` | 4.97:1 text (accessible adjustment) |
| Agility | `#4CC66A` | same | 8.27:1 |
| Intelligence | `#4C8DFF` | same | 5.65:1 |
| Perception | `#F4C542` | same | 11.13:1 |
| Energy | `#38D6E8` | same | 10.30:1 |
| Knowledge | `#A675FF` | same | 5.70:1 |
| Endurance | `#D98236` | same | 6.20:1 |
| Leadership | `#D8B24A` | same | 8.95:1 |

Canonical Strength red is retained on the non-text bar. Its direct 4.27:1
ratio on the live row surface is below the 4.5:1 normal-text target, so only
the label/value variant is lightened to `#E05B4C`. Full data is recorded in
`palette.json`.

### Research references

- [RPG community stat-color discussion](https://forums.giantitp.com/showthread.php?516594-Stat-Color-Associations)
  supplied by the Jira task as the genre-convention starting point.
- [Interaction Design Foundation: Color Symbolism](https://ixdf.org/literature/topics/color-symbolism)
  notes that symbolism is contextual/cultural while associating red with
  strength/energy, green with nature/growth, yellow with intellect, and purple
  with wisdom/nobility.
- [ZevenDesign: Color Association & Meaning](https://zevendesign.com/color-association/)
  connects gold with prestige, wisdom and high quality.

These references inform recognition only; the canonical mapping is a product
contract, and localized names, values, bar lengths and tooltips remain the
authoritative meaning carriers.

## Frames And Safe Zones

| Frame | Asset | Texture margins | Content margins | Forbidden zones |
| --- | --- | --- | --- | --- |
| global Hero Select | existing `assets/sprites/ui/meta40/frame_border.png` | existing 160 px source rail | existing 160 px rail + layout reserve | outer frame rail and all ornaments |
| dossier/stat rows | existing runtime StyleBoxes | unchanged | current row padding 6–8 px H, 1–5 px V | row edge and focus rail |
| PixelLab art layer | reference PNG only | not runtime | eight empty virtual row interiors | generated outer metal/dragon decoration |

## Responsive Rules

- 1280×720: reflow the same eight buttons to **2 columns × 4 rows**, row-major
  in canonical stat order. Every cell retains visible localized name, bar,
  numeric value and the complete tooltip hitbox. No abbreviations and no
  color-only state.
- 1920×1080: canonical base inspection; stats column stays 220–320 px wide.
- At 1920×1080 the stat-only text step is 10 px so its real 22 px line box fits
  the 21 px row with the existing one-pixel antialias reserve; no adjacent-frame
  or outer-ornament crossing is allowed.
- 2560×1440: same one-column order and palette; no font, row, or bar growth
  may cross the dossier or hollow global frame content rails.
- Hover/focus changes style only; row geometry and fill identity do not move.

## Interaction States

- Mouse hover and keyboard/gamepad focus retain the existing concise tooltip.
- Hero carousel refresh updates values and fill lengths but never recolors a
  stat by class; the identity color belongs to the stat ID.
- Color is redundant information: localized name, number, bar length and
  tooltip all remain visible.

## Implementation Notes

- Central palette: `scripts/ui/hero_select_constants.gd`.
- Runtime application: only HS4 stat row construction/refresh in
  `scripts/ui_screens.gd`.
- No new runtime texture, frame, node reflow, or input behavior.

## Acceptance Checks

- [x] Full-size and compact PixelLab art layers completed, exported and shown.
- [x] Shared map exposes canonical accent and accessible text colors.
- [x] Eight cells use stable stat colors independent of selected hero.
- [x] Names, values, bar lengths and concise tooltips remain visible/present.
- [x] 1280×720, 1920×1080 and 2560×1440 stay inside content zones.
- [x] Hover/focus does not resize or shift rows.
- [x] Metal screenshot comparison completed after implementation.

## Deviations

No outer-screen or dossier-zone geometry change is planned. The compact
stat-only font step and 720p 2×4 grid are the documented fit corrections
discovered during implementation screenshot inspection.
The PixelLab result is deliberately a
style reference layer rather than a replacement frame because SCRUM-951 changes
semantic color identity, not the accepted Hero Select layout or ornaments.
