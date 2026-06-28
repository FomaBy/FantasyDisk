# SCRUM-570 - Level-Up Overlay 2K Mockup Spec

Status: blocked
Role owner: Design
Task: docs/tasks/SCRUM-570_level_up_2k_redesign.md
Jira: SCRUM-570
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Mockup PNG: blocked - OpenAI Images API generation could not start because `OPENAI_API_KEY` is not configured.
Preview PNG: blocked - no generated PNG exists.
Generated with: intended OpenAI Images API via `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`

## Source Request

Design-only stage for the FantasyDisk level-up overlay: create an OpenAI-API-generated 2K mockup/spec/source assets for the level-up screen, with strict frame safe zones and no runtime integration changes.

## Current Blocker

The required OpenAI Images API generation failed before any image request was sent:

```text
error: OPENAI_API_KEY is not set (looked in env and C:\Users\FomaE\.codex\.env, C:\Users\FomaE\OneDrive\Documents\Fantasy Disk SCRUM-570\.env)
```

Per `fantasydisk-ui-director` rule 4, this package is blocked rather than substituting a manual or non-API mockup.

## Planned Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| level_up_overlay | Control | dimmed level-up screen | x=0, y=0, w=2560, h=1440 | full rect | 2560x1440 | 0 | visible | viewport |
| level_up_panel | PanelContainer/frame | modal shell | x=760, y=420, w=1040, h=600 | center | 960x560 | 10 | intro/default | viewport |
| level_up_safe | Content zone | all runtime content | x=818, y=492, w=924, h=462 | inside panel | 820x396 | 11 | n/a | level_up_panel |
| hero_header | HBoxContainer | portrait + level badge/title group | x=940, y=504, w=680, h=118 | top center | 520x88 | 20 | default | level_up_safe |
| hero_portrait | TextureRect | current hero portrait | x=1002, y=512, w=88, h=88 | top center | 64x64 | 21 | default | hero_header |
| level_badge | Label | pending/level context | x=1112, y=506, w=336, h=28 | top center | 260x24 | 21 | default | hero_header |
| level_title | Label | "Повышение уровня" | x=1112, y=540, w=336, h=54 | top center | 320x42 | 21 | default | hero_header |
| level_subtitle | Label | instruction copy | x=896, y=620, w=768, h=42 | center | 640x34 | 21 | default | level_up_safe |
| reward_card_0 | Button/card frame | upgrade icon/title/body/preview | x=865, y=684, w=238, h=210 | center row | 202x160 | 30 | default/hover/focus/pressed/disabled | level_up_safe |
| reward_card_1 | Button/card frame | upgrade icon/title/body/preview | x=1115, y=684, w=238, h=210 | center row | 202x160 | 30 | default/hover/focus/pressed/disabled | level_up_safe |
| reward_card_2 | Button/card frame | upgrade icon/title/body/preview | x=1365, y=684, w=238, h=210 | center row | 202x160 | 30 | default/hover/focus/pressed/disabled | level_up_safe |
| later_button | Button frame | defer choice | x=1150, y=908, w=260, h=72 | bottom center | 240x56 | 30 | default/hover/focus/pressed/disabled | level_up_safe |
| burst_sparks | Decorative particles | noninteractive intro sparks | x=0, y=0, w=2560, h=1440 | full rect | 2560x1440 | 5 | intro/fade | viewport |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| level_up_panel | intended `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_level_up_panel.png` | 1040x600 | L/R/T/B 38/52/38/48 | L/R/T/B 58/72/58/66 | outer rails, claw corners, ruby pins, brass seams | yes |
| reward_card | intended `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_level_up_card.png` | 238x210 | L/R/T/B 28/32/28/30 | L/R/T/B 40/44/40/42 | card border, corner notches, rare-state accent | yes, if generated with flat stretch center |
| hero_portrait_frame | intended inside panel or small separate frame | 88x88 | estimated 10/10/10/10 | estimated 14/14/14/14 | ring border and gem pins | no, keep proportional |
| later_button | intended `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_level_up_later_btn.png` | 260x72 | L/R/T/B 42/18/42/18 | L/R/T/B 54/22/54/22 | side caps, bevels, pins | yes |

## Intended OpenAI Prompt

```text
FantasyDisk UI screen mockup, 2D game interface, exact 2560x1440 canvas, D&D dark fantasy dragon style, bright minimal metal 2K UI family. Screen: level-up overlay during roguelite run. Full-screen arcane laboratory backdrop with a dark readable dim overlay. Centered ornate but restrained metal modal frame at x=760 y=420 w=1040 h=600, transparent/dark empty center content zone, no runtime text baked into art. The frame has thin obsidian steel rails, aged brass hairlines, small ruby pins, subtle dragon claw corner notches, restrained blue-gold arcane sparks around panel, no decorative clutter in the content area. Inside the modal: a small hero portrait medallion safe slot near top center, a title safe band below it, subtitle safe band, three upgrade card frames in a row inside the panel safe zone, each card has an empty flat dark center for runtime icon/title/body text; cards are separate frames with visible borders and safe interiors, no labels; one card can have a subtle rare cyan/gold accent but still empty center. Bottom center: one compact defer button frame with empty label safe band. Show faint content-zone guides as clean translucent dark placeholders only, not text. Do not put buttons, icons, text, portraits, or cards on frame borders, gems, claws, metal rails, or ornaments. Orthographic flat UI layout, crisp 2K game mockup, no perspective, no watermark, no logo, no fake letters, no readable words.
```

## Responsive Rules

- 1920x1080: uniform scale 0.75 from 2560x1440. Panel becomes 780x450 at x=570, y=315. Content uses the scaled safe rect; cards become about 179x158 with text reduced and preview lines limited.
- 2560x1440: use the base rectangles above 1:1. Three cards plus gaps fit inside `LU_SAFE_2K` with 198 px spare horizontal breathing room.
- 3840x2160: uniform scale 1.5 from 2560x1440. Asset must remain crisp through 9-slice; ornaments stay in margin bands and content containers scale from source content margins.

## Interaction States

- Card hover/focus: neutral brighter metal and a subtle cyan/gold inner rim. No yellow glow and no layout shift.
- Card pressed: darker inner plate, same content rect.
- Disabled/locked: desaturated card, readable but non-emissive; tooltip explains reason if runtime ever disables a choice.
- Rare card: one card may use a restrained cyan/gold accent strip inside the border area, never under runtime text.
- Later button: compact minimal-metal state family, label stays inside the safe band.

## Implementation Notes

- Godot scene/script: Back-end integration must happen in a separate task; this Design stage does not edit `scripts/ui_screens.gd`.
- Control node structure: preserve `LevelUpOverlay`, `LevelUpPanel`, `LevelUpHeroHeader`, `LevelUpRewardButton0..2`, and `LevelUpLaterButton`.
- Runtime text/icon containers: all labels/icons/previews must stay inside the card and panel content margins above.
- Asset registry: if generated later, register new frame paths/content margins in `scripts/ui/ui_theme_paths.gd` only in a Back-end integration task.

## Acceptance Checks

- [ ] Mockup generated through OpenAI Images API.
- [ ] Preview shown in chat when generated.
- [x] All planned visible elements are listed in the elements table.
- [x] Every planned frame has texture margins and content margins.
- [x] Spec keeps UI content away from frame borders, ornaments, gems, metal, and decorative corners.
- [x] Runtime integration files were not edited in this Design-only blocked pass.

## Deviations

No mockup PNG or source asset was produced because the required OpenAI API key is unavailable.
