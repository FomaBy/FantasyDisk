# Escape Stats Visual Kit

Обновлено: 2026-06-10

Этот документ описывает Design-ready visual kit для compact Escape stats menu FantasyDisk. Back-end layout уже реализован в `scripts/pause_stats_menu.gd`; этот kit нужен для визуальной интеграции без изменения gameplay logic.

## Asset Paths

Все PNG лежат в:

```text
assets/sprites/ui/frames/escape/
```

| Asset ID | File | Runtime use |
| --- | --- | --- |
| `ui_escape_panel_frame` | `assets/sprites/ui/frames/escape/ui_escape_panel_frame.png` | `EscapeStatsPanelFrame`, outer menu frame |
| `ui_escape_button_frame` | `assets/sprites/ui/frames/escape/ui_escape_button_frame.png` | `PauseControlButtons` button normal/hover basis |
| `ui_stat_basic_row_frame` | `assets/sprites/ui/frames/escape/ui_stat_basic_row_frame.png` | `BaseStatRow_<stat_id>` |
| `ui_stat_group_frame` | `assets/sprites/ui/frames/escape/ui_stat_group_frame.png` | `DerivedStatGroup_<group_id>` |
| `ui_stat_chip_frame` | `assets/sprites/ui/frames/escape/ui_stat_chip_frame.png` | `DerivedStatChip_<stat_id>` |
| `ui_stat_tooltip_frame` | `assets/sprites/ui/frames/escape/ui_stat_tooltip_frame.png` | custom tooltip panel |
| `ui_stat_section_divider` | `assets/sprites/ui/frames/escape/ui_stat_section_divider.png` | optional group/header divider |
| `ui_stat_value_state_swatches` | `assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png` | reference swatches, not required at runtime |
| `escape_stats_visual_kit_preview` | `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png` | design reference only |

## StyleBoxTexture Margins

Recommended `StyleBoxTexture` patch margins:

| Asset ID | Left | Top | Right | Bottom |
| --- | ---: | ---: | ---: | ---: |
| `ui_escape_panel_frame` | 40 | 40 | 40 | 40 |
| `ui_escape_button_frame` | 28 | 24 | 28 | 28 |
| `ui_stat_basic_row_frame` | 20 | 12 | 20 | 14 |
| `ui_stat_group_frame` | 34 | 30 | 34 | 34 |
| `ui_stat_chip_frame` | 20 | 12 | 20 | 14 |
| `ui_stat_tooltip_frame` | 34 | 30 | 34 | 34 |
| `ui_stat_section_divider` | 14 | 4 | 14 | 4 |

If `StyleBoxTexture` creates too much GPU/texture overhead for tiny rows, keep rows/chips as `StyleBoxFlat` but copy the colors and border widths from this document.

## Color Tokens

| Token | Hex | Use |
| --- | --- | --- |
| `ui_stat_value_high` | `#70F2A6` | strong/high value |
| `ui_stat_value_low` | `#FF6B6B` | weak/low value or danger action |
| `ui_stat_value_neutral` | `#E9DCA7` | normal value |
| `ui_stat_value_effective` | `#FFDC5C` | especially effective for current build |
| `ui_escape_text_primary` | `#EFE2B2` | titles and important labels |
| `ui_escape_text_secondary` | `#97A5B8` | descriptions and formulas |
| `ui_escape_panel_bg` | `#070A12F2` | dark panel fill |
| `ui_escape_row_bg` | `#161926DC` | base stat row fill |
| `ui_escape_chip_bg` | `#191E2BDC` | derived stat chip fill |
| `ui_escape_gold_border` | `#E0B046` | primary frame border |
| `ui_escape_cyan_border` | `#50DCE6` | tooltip/hover accent |
| `ui_escape_violet_border` | `#A076D8` | derived group frame |

## Group Accent Colors

Use these accents for `DerivedStatGroup_<group_id>`:

| Group ID | Hex | Reason |
| --- | --- | --- |
| `physical_damage` | `#F26138` | melee, steel impact, physical burst |
| `magic_damage` | `#8C6BFF` | dark magic / arcane |
| `sound_control` | `#4DDCFF` | sonic/cyan control |
| `dot_poison` | `#72F06F` | poison / ticking damage |
| `survival` | `#F2C752` | HP, defense, endurance |
| `summons_support` | `#E69EFF` | support, summons, aura |

## Compact Layout Metrics

For `1600x900`:

| Element | Recommended size |
| --- | --- |
| screen margin | 30 left/right, 24 top/bottom |
| main panel content padding | 24 |
| left column width | 330-360 |
| column separation | 18 |
| control button height | 48 |
| basic stat row height | 36 |
| basic stat icon | 28x28 |
| derived group min width | 430 |
| derived chip height | 44 |
| derived chip icon | 30x30 |
| group grid columns | 2 |
| group spacing | 12 horizontal / 12 vertical |
| tooltip target width | 360-430 |

For `2560x1440`:

- Keep content max width around `1760-1900` instead of stretching to the full screen.
- Left column can grow to `380`.
- Derived group min width can grow to `520`.
- Keep text sizes mostly unchanged; increase only section titles by 2-4 px if needed.

## Typography

Recommended font sizes:

| Element | Font size |
| --- | ---: |
| pause title | 34-38 |
| right panel title | 28-30 |
| group title | 18 |
| group description | 12 |
| basic stat name | 15 |
| basic stat value | 16 |
| chip name | 13 |
| chip value | 15 |
| tooltip title | 18 |
| tooltip body/formula | 13-14 |

## Icons

Use the existing `UIIconRegistry` icon pack:

- base stats: `assets/sprites/ui/icons/stats/`;
- derived stats: `assets/sprites/ui/icons/derived/`;
- HUD resource icons: `assets/sprites/ui/hud/`.

Do not add emoji fallbacks to the visible UI. If an icon is missing, use `UIIconRegistry` fallback only as a technical fail-safe.

## Tooltip Rules

`ui_stat_tooltip_frame` should wrap:

- stat name;
- current value;
- short description;
- formula/source text;
- influence/effectiveness note.

Tooltip should clamp inside viewport. Back-end owns tooltip positioning and clamping.

## Preview

Design reference:

```text
assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png
```

The preview is not a runtime layout file; it is a visual target for Back-end integration.
