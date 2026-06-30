# Hero Select Black Minimal Redesign

Date: 2026-06-30
Runtime entry: `scripts/ui_screens.gd` → `_build_character_select_v4()`

## Source Request

User requested a black-background character select redesign:

- remove all old UI elements;
- show the selected character model on the left at `250x250`, rotating when possible;
- show character description, strengths, weaknesses and main stats in the center;
- stats must expose hover tooltips explaining dependent attributes;
- remove the compass rose/radar on the right;
- show ascension descriptions and allow ascension selection on the right;
- show a bottom character carousel with `150x150` slots, as many as fit, scrolled by arrow buttons.

## Mockup Status

The FantasyDisk UI workflow requires a PixelLab/UI-director mockup before major UI implementation. PixelLab generation was attempted for this screen, but the service rejected new `create_ui_asset` jobs with `rate limit exceeded (10/10 jobs)`. No manual or alternate-image fallback mockup was used. This spec is the source-of-truth layout contract for the implemented direct user request until a later design pass can generate a visual mockup.

## Runtime Layout Contract

- Root: `HeroSelectScreen`.
- Background: `HS4BlackBackground`, pure black, full viewport.
- Removed active elements: PixelLab backdrop, title frame, compass rose, `HeroStatRadar`, old frame atlas layout.
- Left: `HS4PortraitFrame` / `HS4Portrait`, fixed `250x250`.
- Center: `HS4DossierFrame` with name, description, strengths, weaknesses, weapon names, class identity and `HS4StatsGrid`.
- Stats: `HS4Stat_strength`, `HS4Stat_agility`, `HS4Stat_intelligence`, `HS4Stat_perception`, `HS4Stat_energy`, `HS4Stat_knowledge`, `HS4Stat_endurance`, `HS4Stat_leadership`; every stat button has a tooltip beginning with its formula definition and listing dependent derived attributes.
- Right: `HS4AscensionFrame`, `AscensionMinusButton`, `AscensionPlusButton`, `AscensionModsLabel`, `HS4ChooseButton`.
- Bottom: `HS4CarouselFrame` / `HS4Carousel`; visible `HS4CarouselSlot_*` buttons are fixed `150x150`.
- Carousel arrows: `HS4CarouselPrevButton`, `HS4CarouselNextButton`, cyclic paging through `ProgressionData.character_ids()`.

## Verification

Focused coverage:

- `tests/hero_select_pixellab_layout_test.gd` asserts the minimal black layout, absence of radar/PixelLab backdrop, `250x250` portrait, stat tooltips, ascension panel, dynamic `150x150` carousel slots and no major-zone overlap.
- Existing Hero Select preview smokes assert Berserk, Dark Mage and Guitarist directional preview rotation.
- `tests/runtime_smoke_test.gd` and `tests/runtime_smoke_ui_test.gd` now assert the active black minimal screen instead of the old radar contract.
- `tests/ui_no_overlap_matrix_test.gd` tracks the active Hero Select node set: portrait, dossier, ascension, carousel and choose button.
