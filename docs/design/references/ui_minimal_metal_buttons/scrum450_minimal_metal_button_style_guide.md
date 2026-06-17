# SCRUM-450 Minimal Metal Button Kit

Статус: ready_for_integration
Владелец: Designer 2 (Codex)
Дата: 2026-06-17

## Цель

SCRUM-450 задаёт новый Design-ready button kit для серии UI Simplification:
строгий минимал-металлик, опирающийся на пользовательские референсы
`button_obsidian_brass_runed`, `button_warplate_iron` и точечный рубиновый
акцент из `button_royal_crimson_gold`.

Kit intentionally avoids the old heavy dragon-claw look while preserving the
same runtime type matrix and button sizes from SCRUM-273/SCRUM-263/SCRUM-264.
The current Red & Gold runtime buttons are not replaced by this Design pass;
Back-end integration is a separate handoff.

## Источники

- OpenAI source sheet: `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_source_sheet.png`
- Production RGBA candidates: `assets/sprites/ui/frames/minimal_metal_buttons/`
- Source-candidate copies: `docs/design/references/ui_minimal_metal_buttons/buttons_raw/`
- Metadata: `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`
- Alpha audit: `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_alpha_audit.md`
- Contact preview: `docs/design/previews/scrum450_minimal_metal_button_contact.png`
- Safe-zone preview: `docs/design/previews/scrum450_minimal_metal_button_safe_zones.png`
- UI-director spec mirror: `docs/design/mockups/scrum450_ui_minimal_metal_buttons/spec.md`

## Visual Rules

- Materials: graphite/obsidian center, dark forged steel caps, thin aged-brass
  rails, rare deep ruby pins.
- No baked labels, letters, icons or symbols in the button art.
- Hover/focus states are neutral-bright and cool-metal; no yellow glow.
- Pressed state darkens the internal plate without changing layout size.
- Disabled state is desaturated/dim but keeps silhouette and hit-area readable.
- Side caps, ruby pins, bevels and border rails are decoration only and are
  forbidden for runtime text/icon placement.

## States

Each type has five PNG states:

- `normal`: base `ui_btn_minimal_metal_<type>.png`
- `hover`: `_hover.png`
- `pressed`: `_pressed.png`
- `focus`: `_focus.png`
- `disabled`: `_disabled.png`

Focus state includes a cool steel/cyan-safe internal focus ring. It stays inside
the content zone and must not change button min size or layout.

## Production Type Matrix

| Type | Size | Texture margins L/T/R/B | Content rect x/y/w/h | Notes |
| --- | ---: | --- | --- | --- |
| `standard` | `420x104` | `[50,28,50,28]` | `[64,32,292,40]` | standard action |
| `max` | `560x104` | `[58,28,58,28]` | `[72,32,416,40]` | wide action cap |
| `main_menu` | `380x104` | `[48,28,48,28]` | `[62,32,256,40]` | main menu action |
| `hero_confirm` | `320x104` | `[42,28,42,28]` | `[56,32,208,40]` | hero select confirm |
| `reset_audio` | `420x104` | `[50,28,50,28]` | `[64,32,292,40]` | settings reset |
| `reset_bindings` | `440x104` | `[50,28,50,28]` | `[64,32,312,40]` | settings reset |
| `codex_tab` | `170x104` | `[34,28,34,28]` | `[48,32,74,40]` | compact tab/action |
| `back_s` | `170x104` | `[34,28,34,28]` | `[48,32,74,40]` | back/action S |
| `back_m` | `280x104` | `[42,28,42,28]` | `[56,32,168,40]` | back/action M |
| `back_l` | `380x104` | `[48,28,48,28]` | `[62,32,256,40]` | back/action L |
| `attr_selector` | `560x104` | `[58,28,58,28]` | `[72,32,416,40]` | long selector/offer |
| `fab` | `50x50` | `[12,12,12,12]` | `[15,15,20,20]` | fixed round icon button |
| `utility` | `54x42` | `[12,10,12,10]` | `[15,12,24,18]` | fixed compact icon button |
| `pause` | `280x60` | `[34,16,34,16]` | `[46,18,188,24]` | slim pause action |
| `rebind` | `420x62` | `[34,16,34,16]` | `[46,18,328,26]` | slim rebind/dropdown |

All rectangular/slim types are safe for `StyleBoxTexture`/9-slice with the
declared texture margins. `fab` and `utility` are fixed-size icon controls and
should not be arbitrarily 9-sliced.

## Validation

All 75 production PNGs are RGBA and audit at:

- `white_opaque_pixels=0`
- `pale_visible_pixels_after_cleanup=0`
- `pale_edge_visible_pixels=0`

The OpenAI source sheet is retained as the art-direction source. The production
files are strict transparent candidates rebuilt from that direction to avoid
opaque backgrounds, white fringe pixels and accidental baked labels.

