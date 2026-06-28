# Visual Style Assets

Обновлено: 2026-06-13

Этот файл фиксирует reusable visual assets FantasyDisk после domain split. Подробные таблицы сущностей остаются в `docs/design/content_registry.md`.

## Artifact And Shop Icons

All artifacts from `ProgressionData.ARTIFACTS` and all shop-only items from `ProgressionData.SHOP_ITEMS` have unique PNG assets. Artifact icons were replaced on 2026-06-12 as `256x256` RGBA transparent realistic epic D&D/tabletop fantasy raster magic items after direct user feedback: one finished painted object per icon, no pentagram-style pictograms, no built-in UI frame, no pedestal, no background tile, no loose shards or particles, and readable object lighting/materials. Shop-only icons keep the earlier fantasy-medallion treatment.

Canonical folders:

- `assets/sprites/ui/icons/artifacts/` - `artifact_<artifact_id>.png` (`256x256`);
- `assets/sprites/ui/icons/shop/` - `shop_<shop_item_id>.png`;
- `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png` - active artifact QA preview sheet with large and 40px samples;
- `assets/sprites/ui/icons/artifact_per_item_preview.png` - superseded per-item pictogram preview retained as legacy reference only;
- `assets/sprites/ui/icons/artifact_final_dark_fantasy_40px_preview.png` - legacy 40px artifact preview from the previous pass;
- `assets/sprites/ui/icons/artifact_generated_concept_40px_preview.png` - legacy preview path updated to the same active icon set;
- `assets/sprites/ui/icons/artifact_dark_artifacts_40px_preview.png` - legacy preview path updated to the same active icon set;
- SCRUM-340 `fantasydisk-asset-generator` pass - active artifact icon source pipeline; source references live in `docs/design/references/icons/artifacts/artifact_<id>_source.png`;
- `tools/extract_realistic_dnd_artifact_icons.py` - superseded raster source sheet extraction and validation pipeline kept for reference;
- `tools/regenerate_artifact_icons_per_item.py` - superseded per-item artifact icon regeneration pipeline kept for reference;
- `tools/validate_artifact_icons.py` - artifact icon technical validation and QA preview builder;
- `tools/final_redesign_artifact_icons.py` - superseded artifact icon polish/extraction pipeline kept for reference;
- `tools/generate_reference_dark_artifact_icons.py` - superseded deterministic artifact icon generator kept for reference only;
- `tools/generate_artifact_shop_cursor_assets.py` - deterministic shop/cursor source generator.

Canonical mapping:

```text
docs/design/artifact_shop_cursor_visual_kit.md
```

Visual rules:

- no emoji/default placeholders;
- no text inside icons;
- keep artifact silhouettes readable at `40x40`;
- artifact icons use centered realistic D&D/tabletop fantasy magic items generated through `fantasydisk-asset-generator` on transparent backgrounds, with one complete painted object per icon, stable `artifact_<id>.png` paths, and 40px readability previews; shop-only icons use ornate fantasy-medallion frames, strong dark outlines, fantasy-metal/gem accents, glow and transparent background;
- avoid reusing the exact same icon with only a recolor for distinct items.

## Shop Frames And Cursor

Shop frame assets live in `assets/sprites/ui/shop/`. Cursor assets live in `assets/sprites/ui/cursor/`. Back-end hooks are already ready; these PNGs are the active Design target and fallback should remain fail-safe only. Current cursor canon after SCRUM-223: `game_cursor.png`, `game_cursor_hover.png` and `game_cursor_attack.png` are a unified dark steel dragon/clawed fire pointer set with hotspot `(2, 2)`.

SCRUM-182 refreshed the active derived stat icons, shop-only icons, and shop state sprites on 2026-06-13 without changing registry paths. Derived icons in `assets/sprites/ui/icons/derived/` stay `64x64`; shop item icons in `assets/sprites/ui/icons/shop/` stay `128x128`; shop frames/badges/overlays in `assets/sprites/ui/shop/` keep their previous canvas sizes. The style target is compact readable fantasy object art with dark outlines, small material cues, transparent alpha, no text, no emoji, and no meaningless decorative filler. Review sheets: `docs/design/previews/ui_icon_unification_before_contact.png`, `docs/design/previews/ui_icon_unification_after_contact.png`, and `docs/design/previews/ui_icon_unification_40px_preview.png`.

## Character Pipeline Asset Handoffs

SCRUM-456 defines the new 0.1.6 **cartoon/anime playable-character restyle
anchor** after the broad bright+epic v2 direction was rejected for future rollout.
The source package lives under `docs/design/references/chars_cartoon/`: style
sheet `character_cartoon_anime_style_sheet.md`, Berserk handoff
`berserk_cartoon_anchor_design_handoff.md`, corrected transparent source
`berserk_cartoon_anchor_source_raw.png`, clean source
`berserk_cartoon_anchor_source_clean.png`, normalized
`berserk_cartoon_anchor_idle_cell_512.png`, safe-gutter source handoff
`berserk_cartoon_anchor_sheet_source_handoff.png`, preview
`docs/design/previews/scrum456_chars_cartoon_anchor_contact.png`, and QA report
`build/qa/scrum456_chars_cartoon/scrum456_chars_cartoon_alpha_motion_report.json`.
The active source style target is D&D dark fantasy adapted into modern
cartoon/anime cel-shading: thicker contour, saturated class palettes, larger
readable shapes, strong class-specific silhouettes, transparent RGBA only, empty
hands/no baked weapons, and visible arms/legs for future idle + walk/move
animation. The exemplar is Berserk; Animator integration is blocked until this
source package is accepted.

SCRUM-422 starts the 0.1.6 **Character redraw v2 bright+epic anchor** for the
next playable character art wave. The accepted Design exemplar is Berserk:
source/raw `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_source_raw.png`,
alpha-clean source `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_source_clean.png`,
512-cell exemplar `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_idle_cell_512.png`,
and asset-side source copy
`assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png`. The
canonical v2 style/spec is
`docs/design/references/characters_v2/bright_epic_anchor/character_v2_bright_epic_style_sheet.md`.
V2 playable sources use bright class-specific D&D fantasy colors, stronger
silhouette/readability than the 0.1.5 sheets, transparent RGBA, no baked
background, no baked weapon/focus/orb in base hero hands, `512x512` cells,
bottom-center pivot `(256, 470)`, and target body height around `360-380 px`
inside the cell so runtime scale `0.39-0.40` reads about twice the average
standard monster screen height.

SCRUM-424 adds the Dark Mage v2 per-class source handoff in the same format:
`docs/design/references/characters_v2/dark_mage/dark_mage_v2_source_clean.png`,
`dark_mage_v2_idle_cell_512.png`, `dark_mage_v2_sheet_source_handoff.png`,
`dark_mage_v2_design_handoff.md`, contact preview
`docs/design/previews/scrum424_dark_mage_v2_contact.png` and QA report
`build/qa/scrum424_dark_mage_v2/scrum424_dark_mage_v2_alpha_size_report.json`.
The accepted source is a bright violet/purple unarmed void caster with empty
glowing hands, transparent RGBA, visible height `376 px` and pivot `(256,470)`;
it is a source handoff only until Animator/Back-end builds real idle/move
SpriteFrames.

SCRUM-429 adds the Guitarist v2 per-class source handoff in the same format:
`docs/design/references/characters_v2/guitarist/guitarist_v2_source_clean.png`,
`guitarist_v2_idle_cell_512.png`, `guitarist_v2_sheet_source_handoff.png`,
`guitarist_v2_design_handoff.md`, contact preview
`docs/design/previews/scrum429_guitarist_v2_contact.png` and QA report
`build/qa/scrum429_guitarist_v2/scrum429_guitarist_v2_alpha_size_report.json`.
The accepted source is a bright magenta/gold unarmed stage-warlock performer
with empty hands and no baked guitar/instrument/microphone/weapon, transparent
RGBA, visible height `374 px` and pivot `(256,470)`. After user feedback, the
cleanup revision removes white/neutral matte pixels globally (`0` in source and
cell QA). It is a source handoff only until Animator/Back-end builds real
idle/move SpriteFrames.

SCRUM-435 adds the Thief v2 per-class source handoff in the same format:
`docs/design/references/characters_v2/thief/thief_v2_source_clean.png`,
`thief_v2_idle_cell_512.png`, `thief_v2_sheet_source_handoff.png`,
`thief_v2_design_handoff.md`, contact preview
`docs/design/previews/scrum435_thief_v2_contact.png` and QA report
`build/qa/scrum435_thief_v2/scrum435_thief_v2_alpha_size_report.json`. The
accepted source is a bright amber unarmed rogue with empty hands and no baked
dagger/weapon/tool/coin pouch/bomb, transparent RGBA, visible height `374 px`
and pivot `(256,470)`. White/neutral matte pixels are `0` in source/cell QA. It
is a source handoff only until Animator/Back-end builds real idle/move
SpriteFrames.

SCRUM-427 adds the Elementalist v2 per-class source handoff in the same format:
`docs/design/references/characters_v2/elementalist/elementalist_v2_source_clean.png`,
`elementalist_v2_idle_cell_512.png`,
`elementalist_v2_sheet_source_handoff.png`,
`elementalist_v2_design_handoff.md`, contact preview
`docs/design/previews/scrum427_elementalist_v2_contact.png` and QA report
`build/qa/scrum427_elementalist_v2/scrum427_elementalist_v2_alpha_size_report.json`.
The accepted source is a bright multi-element unarmed caster with empty hands
and no baked staff/orb/focus/weapon, transparent RGBA, visible height `374 px`
and pivot `(256,470)`. White/neutral matte pixels are `0` in source/cell QA. It
is a source handoff only until Animator/Back-end builds real idle/move
SpriteFrames.

SCRUM-433 adds the Sniper v2 per-class source handoff in the same format:
`docs/design/references/characters_v2/sniper/sniper_v2_source_clean.png`,
`sniper_v2_idle_cell_512.png`, `sniper_v2_sheet_source_handoff.png`,
`sniper_v2_design_handoff.md`, contact preview
`docs/design/previews/scrum433_sniper_v2_contact.png` and QA report
`build/qa/scrum433_sniper_v2/scrum433_sniper_v2_alpha_size_report.json`. The
accepted source is a bright cold blue-steel unarmed marksman with empty hands,
optical targeting light and no baked rifle/gun/bow/crossbow/scope/weapon,
transparent RGBA, visible height `374 px` and pivot `(256,470)`. White/neutral
matte pixels are `0` in source/cell/sheet QA, with `0` edge-visible pixels after
the edge-alpha fix. It is a source handoff only until Animator/Back-end builds
real idle/move SpriteFrames.

SCRUM-431 adds the Priest v2 per-class source handoff in the same format:
`docs/design/references/characters_v2/priest/priest_v2_source_clean.png`,
`priest_v2_idle_cell_512.png`, `priest_v2_sheet_source_handoff.png`,
`priest_v2_design_handoff.md`, contact preview
`docs/design/previews/scrum431_priest_v2_contact.png` and QA report
`build/qa/scrum431_priest_v2/scrum431_priest_v2_alpha_size_report.json`. The
accepted source is a bright white-gold unarmed holy healer with halo, empty hands
and no baked staff/mace/reliquary/censer/chime/book/weapon, transparent RGBA,
visible height `376 px` and pivot `(256,470)`. White/neutral matte pixels are
`0` in source/cell/sheet QA, with `0` edge-visible pixels after strict
edge-connected checker/white cleanup. It is a source handoff only until
Animator/Back-end builds real idle/move SpriteFrames.

SCRUM-421 adds the Biologist v2 per-class source handoff in the same format:
`docs/design/references/characters_v2/biologist/biologist_v2_source_clean.png`,
`biologist_v2_idle_cell_512.png`, `biologist_v2_sheet_source_handoff.png`,
`biologist_v2_design_handoff.md`, contact preview
`docs/design/previews/scrum421_biologist_v2_contact.png` and QA report
`build/qa/scrum421_biologist_v2/scrum421_biologist_v2_alpha_size_report.json`.
The accepted source is a bright emerald bioluminescent scientist-naturalist with
empty hands and no baked syringe/vial/flask/tool/orb/weapon, transparent RGBA,
visible height `380 px` and pivot `(256,470)`. White/neutral matte pixels are
`0` in source/cell/sheet QA, with `0` edge-visible pixels after strict
edge-connected checker/white cleanup. It is a source handoff only until
Animator/Back-end builds real idle/move SpriteFrames.

SCRUM-165 adds Priest with canonical Design assets `assets/sprites/characters/priest.png`, `assets/sprites/weapons/priest_reliquary.png`, `assets/sprites/weapons/priest_censer.png`, and `assets/sprites/weapons/priest_chime.png`; source/result details are tracked in `docs/tasks/codex_design_priest_art_task.md`. Priest rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_priest_rig_motion_task.md`.

SCRUM-162 adds Biologist gameplay with canonical Design assets ready: `assets/sprites/characters/biologist.png`, `assets/sprites/weapons/biologist_spore_lens.png`, `assets/sprites/weapons/biologist_sample_injector.png`, and `assets/sprites/weapons/biologist_symbiote_seed.png`; contact preview is `docs/design/previews/biologist_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_biologist_art_task.md`. Biologist rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_biologist_rig_motion_task.md`.

SCRUM-166 adds Robot gameplay with canonical Design assets ready: `assets/sprites/characters/robot.png`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `assets/sprites/weapons/robot_hydraulic_press.png`, and `assets/sprites/weapons/robot_reactor_core.png`; contact preview is `docs/design/previews/robot_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_robot_art_task.md`. Robot rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_robot_rig_motion_task.md`.

SCRUM-164 adds Engineer gameplay with canonical Design assets ready: `assets/sprites/characters/engineer.png`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `assets/sprites/weapons/engineer_repair_drone.png`, and `assets/sprites/weapons/engineer_pressure_mines.png`; contact preview is `docs/design/previews/engineer_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_engineer_art_task.md`. Engineer rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_engineer_rig_motion_task.md`.

## Global UI Kit

SCRUM-586 adds the Design-source package for the 2K stat tooltip frame used by
`StatTooltipPanel` / `_make_custom_tooltip` in `scripts/pause_stats_menu.gd`;
SCRUM-593 makes it live in runtime.
The OpenAI source lives at
`docs/design/references/scrum586_stat_tooltip/stat_tooltip_frame_source.png`,
the spec at `docs/design/mockups/scrum586_stat_tooltip/spec.md`, and the
runtime asset at
`assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png`
(`430x288` RGBA, texture margins `32/32/32/32`, content margins
`44/42/44/42`). Runtime registers it as `stat_tooltip` in
`UIThemePaths.OVERHAUL_2K_FRAME_*`, and the tooltip label uses the documented
`342 px` safe width.

SCRUM-588 adds `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png`,
the level-up toast frame. It is a generated transparent RGBA `480x300` asset
with texture margins `58/48/58/48` and content margins `70/112/70/112`. It must
remain textless: runtime `LevelUpToast` draws only a small sparkle/ring inside
the empty safe zone, while `LevelUpEffect` remains the single source of the
visible `Level Up` badge.

SCRUM-574 adds the live Codex v2 2K frame family under
`assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_*.png`. Slots are
`codex_main`, `codex_nav`, `codex_list`, `codex_detail`, `codex_entry_card`,
`codex_tab_btn` and `codex_back_btn`, all registered in
`scripts/ui/ui_theme_paths.gd` and generated through
`tools/build_ui_2k_frame_kit.py --all`. Source/mockup evidence lives at
`docs/design/references/scrum574_codex_2k/codex_2k_mockup.png`; the layout and
content-margin contract lives at `docs/design/mockups/scrum574_codex_2k/spec.md`.
The older `assets/sprites/ui/frames/codex/` package remains a historical Codex
component kit, while runtime `CodexScreen` now uses the slot-exact 2K family for
its shell, panels, entry cards, tabs and compact back button.

SCRUM-273 superseded the SCRUM-147 button-only Parchment & Wax Seal kit with the
historical **Red & Gold Dragon button kit** from
`docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png`. Live
Red & Gold button assets remain in `assets/sprites/ui/frames/red_gold/` as 15
button types with four states each, but SCRUM-462 promotes the SCRUM-450 Minimal
Metal kit as the active runtime action-button canon. The old parchment/wax
button kit is backed up outside live assets at
`build/cleanup_backup_red_gold_buttons_2026_06_14/`; the Red & Gold promotion
backup lives at `build/qa/scrum450_minimal_metal_buttons/red_gold_button_backup/`.

SCRUM-274 supersedes the SCRUM-229 leather+gold runtime panel direction with the
active **Ornate Dark / Red frame kit** from
`docs/design/references/UiFrame/frame_kit_ornate_dark_sheet_b_spec.png`.
Non-button generic panels/windows/cards/tooltips/HUD/timer frames now resolve
through the SCRUM-382 unified master frame builder. The old leather+gold and
previous dark_fantasy/escape panel textures are backed up outside live assets at
`build/cleanup_backup_ornate_frames_2026_06_14/`; the ornate pause/stat family
remains available for the specialized compact Escape stats menu until that menu
receives its own safe-area migration.

SCRUM-373/SCRUM-382 provide the active **Unified Master Frame kit** for
projectwide generic UI centralization. SCRUM-384 revises the same preserved
runtime paths into the active thin metallic version: slim dark-steel rails,
small red corner gems and separate optional dragon overlays. Runtime-ready
assets live in
`assets/sprites/ui/frames/unified/`:
`ui_frame_unified_master.png`, `ui_frame_unified_master_fill.png`,
`ui_frame_unified_inner_fill.png`, `ui_frame_unified_ornament_top.png`,
`ui_frame_unified_ornament_bottom.png` and `ui_frame_unified_hover_overlay.png`.
Back-end integration lives in `UIThemePaths` and `scripts/ui_screens.gd`:
generic StyleBoxTextures use source size `1024x1024`, texture margins
`72/72/72/72`, strict content margins `88/88/88/88`, safe rect
`Rect2(88, 88, 848, 848)` and `AXIS_STRETCH_MODE_TILE` for both axes.
`ui_frame_unified_master_fill.png` is used for readable filled
panels/cards/HUD; `ui_frame_unified_master.png` remains the border-only variant.
The top/bottom ornaments are optional overlays for large windows only and are
not applied to compact HUD cards/tooltips/chips. Runtime content, click zones,
labels, portraits, icons and meters must remain inside the frame content area.

SCRUM-448/SCRUM-449 make the 0.1.6 **Minimalist UI restyle** the active
non-button frame direction where safe. Source/mockup assets live under
`docs/design/references/ui_minimal/` and the UI-director mirror package under
`docs/design/mockups/scrum448_ui_minimalist/`. Runtime assets live in
`assets/sprites/ui/frames/minimal/`: `ui_frame_minimal_modal.png`,
`ui_frame_minimal_panel.png`, `ui_frame_minimal_card.png`,
`ui_frame_minimal_tooltip.png`, `ui_frame_minimal_hud_strip.png` and
`ui_frame_minimal_field.png`. Exact source sizes, texture margins, content
rects and alpha audit are recorded in
`docs/design/references/ui_minimal/scrum448_minimal_ui_frame_metadata.json`.
All six frame PNGs are transparent RGBA with `white_opaque_pixels=0` and
`pale_visible_pixels_after_cleanup=0`; contact preview:
`docs/design/previews/scrum448_minimal_ui_frame_contact.png`. SCRUM-449 wires
the kit into live generic panels/cards/tooltips, Settings, Codex, economy
choice cards/price badges, reward cards, pause/result shells and compact combat
HUD wrappers. SCRUM-462 separately replaces the action-button canon with
Minimal Metal buttons under `assets/sprites/ui/frames/minimal_metal_buttons/`.
Hero Select v3 authored frames, progression circular nodes and combat bar fills stay
screen-specific exceptions. Old ornamental assets were not archived in this pass
because several remain live or historical/screen-specific refs; cleanup should
only remove them after a fresh no-live-ref audit.

SCRUM-452 adds the next **Minimal Metal UI anchor** for the UI simplification
series. SCRUM-459 wires the frame side as runtime-selectable candidates with
exact metadata-backed helpers in
`docs/tasks/backend_ui_minimal_metal_anchor_integration_task.md`.
The style is stricter than SCRUM-448: graphite/obsidian fills, thin dark-steel
rails, aged-brass hairlines and rare ruby pins only. Source assets live under
`docs/design/references/ui_minimal_metal/`, the UI-director mirror is
`docs/design/mockups/scrum452_ui_minimal_metal/spec.md`, and production
candidates live in `assets/sprites/ui/frames/minimal_metal/`:
`ui_frame_minimal_metal_modal.png`, `panel.png`, `card.png`, `tooltip.png`,
`hud_strip.png` and `field.png`. Exact source sizes, texture margins, content
rects and alpha audit are recorded in
`docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`.
`scripts/ui/ui_theme_paths.gd` exposes the six `MINIMAL_METAL_*` paths, source
sizes, texture margins, content margins and safe rects; `scripts/ui_screens.gd`
exposes `_minimal_metal_frame_style()` for future rollout tasks.
All six frame PNGs are transparent RGBA with `white_opaque_pixels=0` and
`pale_visible_pixels_after_cleanup=0`; previews:
`docs/design/previews/scrum452_minimal_metal_anchor_contact.png` and
`docs/design/previews/scrum452_minimal_metal_safe_zones.png`. SCRUM-459 does not
promote these frames over the current SCRUM-448 live generic surfaces; SCRUM-462
separately promotes the SCRUM-450 button redraw, and full frame rollout remains
SCRUM-451/SCRUM-463.

SCRUM-450 adds a Design-ready **Minimal Metal button kit** for the same series,
and SCRUM-462 promotes it into live runtime action-button routing.
The source is an OpenAI-generated sheet at
`docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_source_sheet.png`;
the production candidates live in
`assets/sprites/ui/frames/minimal_metal_buttons/` as 15 current runtime button
types with five states each: normal, hover, pressed, focus and disabled. Exact
sizes, texture margins, content rects, state paths and alpha audit are recorded
in
`docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`.
Previews are `docs/design/previews/scrum450_minimal_metal_button_contact.png`
and `docs/design/previews/scrum450_minimal_metal_button_safe_zones.png`. All 75
candidate PNGs are transparent RGBA with `white_opaque_pixels=0` and
`pale_visible_pixels_after_cleanup=0`. Runtime constants and guards live in
`scripts/ui/ui_theme_paths.gd`, `scripts/ui_screens.gd`,
`scripts/pause_stats_menu.gd`, `tests/dark_fantasy_ui_theme_test.gd` and
`tests/runtime_smoke_test.gd`; QA evidence lives in
`build/qa/scrum450_minimal_metal_buttons/`.

SCRUM-451 adds the **Minimal Metal frame rollout** Design-source contract for
all UI frame families/screens. It does not introduce new runtime images beyond
the accepted SCRUM-452 frame set; instead it maps every target surface to one of
six families: `modal`, `panel`, `card`, `tooltip`, `hud_strip` and `field`.
Source of truth:
`docs/design/mockups/scrum451_ui_minimal_frames_rollout/spec.md` and
`docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_matrix.json`;
preview:
`docs/design/previews/scrum451_minimal_metal_rollout_contact.png`. The rollout
covers menu, settings, hero select, codex, shop, rewards, level-up, events,
pause, results, combat HUD, tooltips and dialogs. Back-end integration,
old-kit backup/no-live-ref audit, screenshots and no-overlap smokes are tracked
in `docs/tasks/backend_ui_minimal_frames_rollout_integration_task.md`.
SCRUM-463 makes the rollout live for generic runtime surfaces: `scripts/ui/ui_theme_paths.gd`
promotes the six minimal-metal frame paths as the active global generic set,
`scripts/ui_screens.gd` applies their metadata to menu/Settings/Codex/economy/
reward/pause/result/HUD wrappers, and `scripts/pause_stats_menu.gd` uses the
same minimal-metal modal/panel/field/tooltip family. Screen-authored exceptions
remain for Hero Select v3, progression nodes and combat bar fills/icons. QA and
the old-kit live-reference audit live under
`build/qa/scrum451_minimal_metal_rollout/`.

SCRUM-478 starts the next **Bright Minimalist full-game UI redesign** direction.
It is a Design-source anchor only, not a runtime promotion. Source references
live under `docs/design/references/minimalist_full_ui_redesign/`: a bright
button anchor sheet, an exact-size frame family sheet, a full-screen mockup
board, `scrum478_minimalist_full_ui_metadata.json` with exact dimensions for
`1280x720`, `1600x900` and `1920x1080`, and
`scrum478_self_qa_evidence.md`. The UI-director spec is
`docs/design/mockups/scrum478_minimalist_full_ui_redesign/spec.md`. The visual
target is obsidian/charcoal interiors, thin silver outlines, vivid cyan/magenta
button accents and small gold ticks. It deliberately moves away from beige,
parchment, heavy dragon ornament and the older metal-heavy frame look. Runtime
content may only use the declared `content_rect_xywh`; frame rails, accent
diamonds, glow caps and gold ticks are forbidden content zones. Final runtime
slicing, `ui_screens.gd` integration, screenshot capture and no-overlap/text
overflow verification are Back-end scope via
`docs/tasks/backend_minimalist_full_ui_redesign_runtime_handoff_task.md`.

SCRUM-390 prepared a dedicated **Combat HUD redraw kit** and SCRUM-400 wires it
into the live runtime HUD. It was generated through
`fantasydisk-asset-generator` from current D&D/dark-fantasy UI references, then
alpha-cleaned and cut into runtime candidates. Source and margins are recorded
in `docs/design/references/combat_hud_redraw/combat_hud_redraw_metadata.json`;
previews are `docs/design/previews/combat_hud_redraw_contact.png` and
`docs/design/previews/combat_hud_redraw_safe_zones.png`; 720p/1080p/1440p mock
screens live in `build/qa/scrum390/`.

Canonical SCRUM-390 candidate assets:

- `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_resource_panel.png`
  (`1024x144`, texture margins `96/44/96/44`, content margins `92/30/92/30`);
- `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_card_hp.png`,
  `_xp.png`, `_gold.png`, `_ult.png` (`256x144`, texture margins
  `48/42/48/38`, content margins `32/24/32/22`);
- `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_timer.png`
  (`384x128`, texture margins `92/42/92/38`, content margins `82/32/82/28`);
- `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_ascension_badge.png`
  (`128x128`, content margins `40/34/40/34`);
- `assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus.png` plus
  `_hover`, `_pressed`, `_disabled` (`128x128`, content margins `36/34/36/36`);
- `assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_hp.png`, `_xp.png`,
  `_ult.png`, `_gold.png` (`512x32`) and
  `ui_hud_gold_medallion.png` (`128x128`).

SCRUM-338/SCRUM-404 provide the active **Reward Card frame kit** for battle
reward offers and elite artifact choices. Runtime assets live in
`assets/sprites/ui/frames/rewards/`:
`ui_frame_reward_card.png`, `ui_frame_reward_card_hover.png`,
`ui_frame_reward_elite_artifact_card.png` and
`ui_frame_reward_elite_artifact_card_hover.png`. Source size is `768x1024`;
Back-end uses texture margins `96/112/96/112` and content margins
`132/170/132/164` for battle reward cards, and texture margins
`108/130/108/130` plus content margins `150/202/150/190` for elite artifact
cards. Runtime content containers are proportionally scaled to the card control
size; labels, icons, artifact tier text and action labels must stay inside the
safe area while the whole card remains clickable/focusable. Runtime QA dumps are
written to `build/qa/scrum338/`.

SCRUM-437 adds a Design-ready **wide economy choice-card frame** for long
reward/event/upgrade/rest option copy. New candidates live in
`assets/sprites/ui/frames/economy/` as
`ui_frame_economy_choice_card_wide.png` and
`ui_frame_economy_choice_card_wide_hover.png` (`960x640`, RGBA transparent).
Use source size `960x640`, base texture margins `[96,88,96,96]`, base content
margins `[132,118,132,128]`, hover texture margins `[104,96,104,104]`, hover
content margins `[140,126,140,136]`, and safe rect `[132,118,696,394]`.
Back-end integration is pending; do not point live economy choice constants to
the wide assets until `scripts/ui_screens.gd` source size, display sizes and
no-overlap matrix are updated. Spec and previews:
`docs/design/mockups/scrum437_wide_economy_choice_card/spec.md`,
`docs/design/previews/scrum437_wide_economy_choice_card_safe_zone.png`.

SCRUM-330 provides the Design-ready **Pause / Victory / Defeat modal kit** for
the pause and result-screen cluster. The accepted runtime candidate is
`assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png` (`1280x1024`,
RGBA transparent), derived from `fantasydisk-asset-generator` reference art and
alpha-cleaned from its magenta key background. Source metadata lives in
`docs/design/references/ui_overhaul_pause_end/scrum330_pause_end_metadata.json`;
mockup/spec lives in
`docs/design/mockups/ui_overhaul_pause_end/scrum330_pause_end_mockup_spec.md`;
previews are `docs/design/previews/ui_overhaul_pause_end_contact.png` and
`docs/design/previews/ui_overhaul_pause_end_safe_zones.png`. The modal frame
must use source safe rect `[170,180,940,670]` / content margins
`[170,180,170,174]`; runtime content, buttons, labels, click/focus zones and
icons must stay out of the dragon heads, side columns, ruby gems, bottom crest
and outer metal. Existing result crests
`assets/sprites/ui/result_crests/ui_crest_victory.png` and
`assets/sprites/ui/result_crests/ui_crest_defeat.png` remain decorative header
art only. SCRUM-407 wires this kit into runtime pause menu, pause dossier/stats,
victory and death screens through scaled `StyleBoxTexture` margins; result
screens keep crest art outside text/buttons, and smaller 720p viewports use
adaptive crest/action button sizing so interactive content stays inside the
modal safe zone. Runtime QA dump:
`build/qa/scrum330/pause_end_ui_no_overlap_matrix.md`.

SCRUM-345/SCRUM-403 provide the active **Codex texture kit** for the in-game
encyclopedia and glossary tooltip. Assets live in
`assets/sprites/ui/frames/codex/` and are wired only to Codex runtime surfaces:
`CodexMainPanel`, `CodexContent`, `CodexTab_*`, Codex entry cards,
portrait/artifact icon slots and `GlossaryTooltipPanel`. Safe-zone metadata is
canonical in `docs/design/references/codex/codex_ui_texture_kit_metadata.json`;
runtime uses those content margins instead of placing labels, icons, portraits
or click/focus areas on dragon/metal/gem ornament. QA dump:
`build/qa/scrum345/codex_texture_runtime_dump.md`.

These are live UI paths for the combat HUD after
`docs/tasks/backend_combat_hud_redraw_integration_task.md`. Back-end keeps
HP/XP/money/ultimate/timer logic unchanged and keeps labels, icons, bars,
badges, plus glyph and click/focus zones inside the recorded content zones; QA
runtime rect dumps live in `build/qa/scrum390/`.

SCRUM-338 adds a Design-ready **reward card frame kit** for battle reward and
elite artifact reward screens. Assets live in `assets/sprites/ui/frames/rewards/`:
`ui_frame_reward_card.png`, `ui_frame_reward_card_hover.png`,
`ui_frame_reward_elite_artifact_card.png` and
`ui_frame_reward_elite_artifact_card_hover.png`. Each is `768x1024` RGBA with
transparent corners, a dark empty content field and ornate D&D/dark-fantasy
metal border. Source and runtime margins live in
`docs/design/references/rewards/reward_frames_scrum338_metadata.json`; Back-end
must keep reward text, icons, buttons, hover/focus hit areas and artifact tier
labels inside those content margins. Runtime integration is handed off in
`docs/tasks/backend_reward_screens_per_reward_frames_integration_task.md`.

SCRUM-281 adds a screen-specific **Hero Select frame kit** from
`docs/design/references/herouiframe/`. It is used only by `HeroSelectScreen`,
because the portrait/dossier/radar ornaments need custom safe areas. Live
assets resolve to `assets/sprites/ui/frames/hero_select/`; QA screenshots and
rect dumps live in `build/qa/scrum281/`.

Specialized ornate frame assets remain in `assets/sprites/ui/frames/ornate/`:

- `ui_frame_ornate_global_panel.png`, `ui_frame_ornate_level_panel.png`,
  `ui_frame_ornate_card_frame.png`, `ui_frame_ornate_hero_card.png`;
- `ui_frame_ornate_card_hover.png`, `ui_frame_ornate_tooltip.png`,
  `ui_frame_ornate_hud_panel.png`, `ui_frame_ornate_hud_card.png`,
  `ui_frame_ornate_timer_panel.png`;
- `ui_frame_ornate_pause_main.png`, `ui_frame_ornate_pause_stat_group.png`,
  `ui_frame_ornate_pause_stat_chip.png`, `ui_frame_ornate_pause_stat_tooltip.png`.

Canonical live Hero Select frame assets live in
`assets/sprites/ui/frames/hero_select/`:

- `ui_frame_hero_select_portrait.png`, `ui_frame_hero_select_dossier.png`,
  `ui_frame_hero_select_radar.png`, `ui_frame_hero_select_thumbnail_strip.png`;
- `ui_frame_hero_select_thumbnail.png`, `ui_frame_hero_select_asc_button.png`,
  `ui_frame_hero_select_asc_label.png`, `ui_frame_hero_select_asc_mods.png`.

Canonical live button assets live in `assets/sprites/ui/frames/minimal_metal_buttons/`:

- `ui_btn_minimal_metal_standard.png`, `ui_btn_minimal_metal_max.png`,
  `ui_btn_minimal_metal_main_menu.png`, `ui_btn_minimal_metal_hero_confirm.png`;
- `ui_btn_minimal_metal_reset_audio.png`, `ui_btn_minimal_metal_reset_bindings.png`,
  `ui_btn_minimal_metal_codex_tab.png`, `ui_btn_minimal_metal_rebind.png`;
- `ui_btn_minimal_metal_back_s.png`, `ui_btn_minimal_metal_back_m.png`,
  `ui_btn_minimal_metal_back_l.png`, `ui_btn_minimal_metal_attr_selector.png`;
- `ui_btn_minimal_metal_fab.png`, `ui_btn_minimal_metal_utility.png`,
  `ui_btn_minimal_metal_pause.png`;
- every file has `_hover`, `_focus`, `_pressed` and `_disabled` state variants.

State language:

- all visible action Button styleboxes use the Minimal Metal kit unless a control is
  intentionally a card/hit-area rather than an action button;
- hover/focus: neutral bright metal read, no yellow baked glow;
- pressed: darker center and slightly lower-contrast metal read;
- disabled: desaturated, dimmed version of the same button type.

SCRUM-450 minimal-metal button assets mirror the same 15 runtime button types.
They add a fifth `_focus` PNG state and runtime keeps SCRUM-318 neutral focus
tint semantics. Use metadata in
`docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`
for content zones; labels/icons must stay inside each `content_rect_xywh` and
never overlap side caps, rubies, bevels or back-arrow ornaments.

Runtime button sizing (SCRUM-263/SCRUM-264):

- standard action buttons use a 104px minimum height through `_make_button()` / `_set_action_button_size()`;
- the main menu uses `main_menu` 380x104 buttons;
- wide action buttons cap their visual width at 560px so button ends do not visibly stretch into a strip;
- pause menu buttons use 280x60, rebind/dropdown-style controls use 420x62,
  compact utility uses 54x42 and upgrade FAB uses 50x50;
- text-heavy choices use an information frame above a short standard button instead of placing paragraphs inside a large button;
- route nodes, shop item hit areas, hero thumbnails and weapon/reward cards are
  intentional exceptions and should not receive the heavy action button frame.

Runtime frame sizing (SCRUM-274):

- `UIThemePaths.ORNATE_FRAME_MARGINS` and `ORNATE_FRAME_CONTENT` mirror the
  signed texture/content margins from the user spec sheet;
- global panels use 34px texture margins and 28/26 content padding;
- level panels use 46px texture margins and 34/30 content padding;
- cards use the card/hero/hover-specific margins from the sheet instead of
  stretching one generic frame everywhere;
- HUD and timer panels use their dedicated horizontal frame assets;
- Escape stats uses `pause_main`, `pause_stat_group`, `pause_stat_chip` and
  `pause_stat_tooltip` frames; its buttons use the SCRUM-450 minimal-metal
  `pause` button.
- Hero Select uses the SCRUM-281 `ui_frame_hero_select_*` kit with custom
  `HERO_SELECT_FRAME_MARGINS` and `HERO_SELECT_FRAME_CONTENT` in
  `scripts/ui_screens.gd`; the bottom thumbnail strip uses compressed thumbnail
  safe margins so 18 class previews fit inside 1280x720.

Rebuild/QA assets:

- `tools/build_red_gold_button_kit.py` - SCRUM-273 active button kit pipeline from the Red & Gold Dragon sheet;
- `tools/build_ornate_ui_frame_kit.py` - SCRUM-274 active panel/frame pipeline from the Ornate Dark spec sheet;
- `tools/build_hero_select_frame_kit.py` - SCRUM-281 Hero Select frame pipeline from `references/herouiframe`;
- `tools/capture_hero_select_qa.gd` - SCRUM-281 screenshot/rect QA capture for 1280x720, 1920x1080 and 2560x1440;
- `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png` - SCRUM-325 design-ready Settings tab switcher frame (`1280x256`, RGBA);
- `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_main_modal.png` - SCRUM-439 Settings v2 main modal candidate (`1536x1024`, RGBA; texture margins `96/118/96/96`, content margins `144/192/144/128`);
- `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_tab_switcher_3slot.png` - SCRUM-439 Settings v2 three-slot switcher candidate (`1280x256`, RGBA; slot safe rects `Rect2(150,78,275,92)`, `Rect2(502,78,275,92)`, `Rect2(854,78,275,92)`);
- `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_section_panel.png` - SCRUM-439 Settings v2 nested section panel candidate (`1024x384`, RGBA; content margins `104/96/104/92`);
- `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_control_row.png` - SCRUM-439 Settings v2 control-row frame candidate (`1536x192`, RGBA; content margins `96/54/96/54`);
- `tools/apply_button_only_ui_revert.py` - SCRUM-147 correction pipeline: taller wax-seal buttons + restored legacy panels;
- `tools/build_leather_gold_ui_kit.py` - superseded SCRUM-229 panel/window pipeline from user interface references;
- `tools/build_parchment_wax_ui_kit.py` - superseded full-frame parchment builder, protected from direct use;
- `docs/design/previews/red_gold_button_kit_contact.png` - active SCRUM-273 button state/type contact sheet;
- `docs/design/previews/ornate_dark_frame_kit_contact.png` - active SCRUM-274 frame contact sheet;
- `docs/design/previews/hero_select_frame_kit_contact.png` - active SCRUM-281 Hero Select frame contact sheet;
- `docs/design/previews/settings_tab_switcher_frame_content_zone.png` - SCRUM-325 Settings tab switcher safe-area overlay;
- `docs/design/previews/scrum439_settings_v2_safe_zones.png` - SCRUM-439 Settings v2 safe-zone overlay for all three tabs;
- `docs/design/previews/scrum439_settings_v2_assets_contact.png` - SCRUM-439 Settings v2 transparent frame candidate contact sheet;
- `docs/design/previews/unified_master_frame_9slice_contact.png` - SCRUM-373 unified master frame contact sheet;
- `docs/design/previews/unified_master_frame_safe_zone.png` - SCRUM-373 strict content-zone overlay;
- `docs/design/previews/unified_master_frame_thin_revision_contact.png` - SCRUM-384 thin metallic unified frame revision contact sheet;
- `docs/design/previews/unified_master_frame_thin_safe_zone.png` - SCRUM-384 `72px` texture / `88px` content margin overlay;
- `docs/design/previews/ui_button_only_legacy_panels_contact.png` - SCRUM-147 side-by-side correction sheet;
- `docs/design/previews/interface_leather_gold_panel_kit_contact.png` - superseded SCRUM-229 leather+gold panel kit sheet;
- `build/qa/interface_leather_gold_panel_kit_contact.png` - historical QA copy of the SCRUM-229 leather+gold kit sheet;
- `docs/design/previews/ui_parchment_wax_scrum147_reference_match_contact.png` - compatibility copy of the active correction sheet;
- `docs/design/previews/ui_parchment_kit_reference_contact.png` - contact sheet of the six fullscreen parchment-kit references.

System icons live in `assets/sprites/ui/icons/system/`: close, back, settings, arrows, checkbox checked/unchecked, slider track/grabber and scrollbar grabber. `scripts/ui_icon_registry.gd` exposes them as `system_*` IDs. Default grey Godot controls should remain fail-safe only.

## Contextual UI Direction

`docs/design/ui_contextual_concept.md` and the generated contextual kit are superseded by the SCRUM-273/SCRUM-274 UI canon. SCRUM-418 confirmed no live references and removed the contextual frame PNGs from runtime `assets/`; historical backup lives under `build/qa/scrum418/removed_assets_backup/`. Context may still influence role color and button/frame selection, but only through the new Red & Gold Dragon + Ornate Dark canon.

Hard no-junk rule from the user: UI work must not add abstract decorative lines, circles, squares, dots, grids or filler marks. Every visible detail must read as a UI affordance or a believable D&D/tabletop material detail; otherwise it is a Design review defect.

Historical assets:

- `ui_wild_*_frame`, `ui_grave_*_frame`, `ui_laurel_*_frame`, `ui_parchment_*_frame` archived under `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/`;
- preview sheet archived under `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/contextual_ui_kits_preview.png`;
- reference contact sheet: `docs/design/previews/contextual_ui_dnd_reference_contact.png`.

Generation task: `docs/tasks/codex_design_contextual_ui_frame_kits_generation_task.md` was completed as historical work; SCRUM-111/SCRUM-118 are superseded by SCRUM-147. Active Back-end integration is `docs/tasks/backend_ui_dark_fantasy_theme_integration_task.md`.

## Characters And Weapons

The expanded 0.1.4 class weapon visual set covers 17 classes and 51 starting weapons. New class full-art PNGs live in `assets/sprites/characters/` at `512x512` with transparent background and cutout-ready silhouettes. SCRUM-168 adds Soldier with canonical `soldier.png`, `soldier_rifle.png`, `soldier_grenade.png`, and `soldier_bayonet.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_soldier_rig_motion_task.md`. SCRUM-169 adds Thief with canonical `thief.png`, `thief_coin_pouch.png`, `thief_shadow_cloak.png`, and `thief_smoke_bomb.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_thief_rig_motion_task.md`. SCRUM-163 adds Elementalist with canonical `elementalist.png`, `elementalist_orb_ring.png`, `elementalist_prism_focus.png`, and `elementalist_meteor_core.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_elementalist_rig_motion_task.md`. SCRUM-167 adds Sniper with canonical `sniper.png`, `sniper_deadeye_rifle.png`, `sniper_spotter_scope.png`, and `sniper_shatter_rounds.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_sniper_rig_motion_task.md`. Later Class Sheet additions Priest, Biologist, Robot and Engineer also have canonical kits; Engineer is the final 17th Back-end class, with rig/cutout/motion tracked in `docs/tasks/animation_engineer_rig_motion_task.md`.

Playable full-frame animation PNGs under
`assets/sprites/characters/full_frame/<class>/` must be `384x384` RGBA with
real transparent alpha, not a white/checkerboard matte hidden inside the
visible bounds. SCRUM-412 cleaned all 255 current playable frames and established
`tools/alpha_clean_full_frame_characters.py` as the validation/fix tool;
`tools/build_character_sheet.py` calls the same edge-connected matte removal
and de-halo pass for future full-frame character sheet slices. QA proof:
`build/qa/scrum412_character_alpha/final_character_alpha_dark_bg_contact.png`
and `build/qa/scrum412_character_alpha/final_alpha_validation_report.json`.
Back-end animation smoke keeps a representative per-class alpha/matte assertion
so future white or checkerboard matte regressions fail before release QA.

All weapon visuals live in `assets/sprites/weapons/` at `256x256` with transparent background. The active style target is polished cartoon dark fantasy: strong black silhouette, readable object shape at `40x40`, compact controlled glow, material detail, and no text/watermark/built-in UI frame. Weapon art v2 pass 2026-06-12 replaced the Knight trio (`long_spear.png`, `tower_shield.png`, `holy_flail.png`) with polished noble equipment, removed fallback texture links from weapon scenes, and reduced socket display scale across oversized weapons. The raw and socket QA sheets are `docs/design/previews/weapon_v2_assets_contact.png` and `docs/design/previews/weapon_v2_socket_contact.png`.

Per-weapon socket/display notes are tracked in `docs/design/systems/characters_weapons.md` and the Design handoff task `docs/tasks/design_all_classes_three_weapons_visual_upgrade_task.md`.

## Summoned Allies And Deployables

SCRUM-152 on 2026-06-12 added the first canonical ally/deployable raster set in `assets/sprites/allies/`. These are `256x256` RGBA transparent painterly D&D sprites with warm/green allied accents:

- `ally_druid_beast.png` - active fallback visual for `scenes/AllyMinion.tscn`;
- `ally_druid_pack_spirit.png` - alternate druid pack/ultimate visual;
- `ally_homunculus.png` - Chemist homunculus visual;
- `ally_leadership_echo.png` - Leadership echo ally visual;
- `deploy_sound_amp_field.png` - Guitarist sound amp field object;
- `deploy_raven_totem_field.png` - Druid raven totem field object.

Preview sheets: `docs/design/previews/summon_allies_asset_contact.png`, `docs/design/previews/summon_allies_scale_meadow_preview.png`. Source-specific runtime selection is tracked in `docs/tasks/backend_summon_allies_source_sprite_integration_task.md`.

## Elites And Bosses

SCRUM-135 anti-blur pass 2026-06-12 moved the 4 active elites (`iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`) and 2 active bosses (`boss_rift_warden`, `boss_disk_devourer`) from 256px source art to native `512x512` RGBA PNGs while preserving pose, silhouette and facing 1:1. The cutout pipeline now slices these six entities in 512px coordinate space and `scripts/sliced_rig_manifest.gd` records `size = Vector2(512, 512)` for them.

SCRUM-156 added final source sprites for the SCRUM-155 roster expansion:
`assets/sprites/bosses/boss_bone_archon.png`,
`boss_brood_mother.png`, `boss_ashen_colossus.png`, plus
`assets/sprites/elites/mini_scavenger_reaper.png`,
`mini_plague_bellringer.png`, `mini_bone_warden.png`,
`mini_spark_wight.png`, `mini_rot_hound.png`, and
`mini_shadow_devourer.png`. All nine are `512x512` RGBA transparent painterly
D&D source sprites. Runtime scene/codex wiring remains Back-end scope; cutout
slicing, pivots, manifest updates and motion profiles remain Animator scope.

Review previews:

- `docs/design/previews/elite_boss_upscale_before_contact.png`;
- `docs/design/previews/elite_boss_upscale_after_contact.png`;
- `docs/design/previews/elite_boss_upscale_rig_debug_contact.png`.
- `docs/design/previews/boss_elite_style_refs_contact.png`;
- `docs/design/previews/new_bosses_mini_elites_contact.png`;
- `docs/design/previews/new_bosses_mini_elites_scale_preview.png`.

## Combat VFX Assets

Attack VFX sprites live in `assets/sprites/effects/` and are transparent PNGs intended for tinted `Sprite2D`/tween-based effects, not raw Godot primitive circles. On 2026-06-12 the first weapon VFX polish block replaced the visible persistent pool placeholders with raster fantasy effects:

- `poison_pool.png` - green bubbling acid/poison puddle for Acid Flask and poison pools;
- `spark_pool.png` - warm ember/spark chemical cloud for Blast Powder;
- `briar_pool.png` - thorny green bramble pool for Druid/Druidic zone effects.

`scripts/class_weapon.gd` now selects these by `pool_element` and animates them with pause-aware node-bound tweens. The gameplay radius, tick interval and duration stay data-driven from weapon config. QA preview: `docs/design/previews/vfx_pool_assets_contact.png`.

SCRUM-181 refreshed the full active VFX set again on 2026-06-13 after the sprite audit: all 19 `assets/sprites/effects/*.png` files now use a restrained painterly D&D/tabletop treatment with softer alpha edges, earthy gold/green/violet accents, readable silhouettes, and no acid-neon or baked pure-white overexposure. Tintable assets (`hazard_zone.png`, `elite_telegraph_circle.png`) remain warm-neutral so code modulation can recolor them. QA/reference previews live in `docs/design/previews/vfx_polish_before_contact.png`, `docs/design/previews/vfx_polish_after_contact.png`, `docs/design/previews/vfx_polish_before_after_contact.png`, `docs/design/previews/vfx_polish_readability_field_meadow.png`, and `docs/design/previews/vfx_polish_readability_field_marsh.png`.

SCRUM-258 extends this with a full unique weapon signature set for sprint 0.1.5: `assets/sprites/effects/vfx_weapon_<weapon_id>.png` for every current weapon ID in `ProgressionData.WEAPONS_BY_CLASS` (51 files, `256x256` RGBA transparent). These are not inventory icons: they are short-lived combat plates used by `AttackVfx.weapon_signature()` to make each unique class/weapon mechanic visually distinct while preserving the exact Back-end mechanics. SCRUM-335 routes the same signature layer through `BerserkWeapon`, covering Berserk and Knight melee scenes that do not use `ClassWeapon`. Style rules: restrained D&D/tabletop magic, readable at combat scale, no UI frame, no text, no watermark, no acid-neon; silhouettes should stay simple enough to read under tint and tween fade. Rebuild pipeline is superseded for new art by `fantasydisk-asset-generator`; the old script remains historical for this existing generated set. Previews: `docs/design/previews/scrum258_unique_weapon_vfx_contact.png` and `docs/design/previews/scrum258_unique_weapon_vfx_readability.png`.

SCRUM-337 is the current full attack VFX art baseline. Six generated source sheets in `docs/design/references/attack_vfx_realistic_dark_fantasy/` were produced with `fantasydisk-asset-generator` / `gpt-image-2`, then cut and alpha-cleaned by `tools/build_scrum337_attack_vfx_from_sources.py` into all active runtime VFX paths: 83 files in `assets/sprites/effects/` and 2 files in `assets/sprites/projectiles/`. The pack keeps the same filenames/canvas sizes/API expectations while replacing older placeholder-looking circles and flat plates with more dimensional D&D/dark-fantasy slashes, rings, pools, portals, hazards, projectiles and per-weapon combat signatures. Previews: `docs/design/previews/scrum337_attack_vfx_core_contact.png`, `docs/design/previews/scrum337_attack_vfx_weapon_contact.png`; readability QA: `build/qa/scrum337/field_meadow_readability.png`, `build/qa/scrum337/field_marsh_readability.png`.

## Screen And Map Backgrounds

- `assets/backgrounds/route_map_backdrop.png` - 2560x1440 eerie neutral route map background. It should stay darker and calmer than combat arenas, with low-contrast fog in the central route column and heavier silhouettes pushed to the edges.
- SCRUM-563 adds the route-map 2K UI Director mockup/source package:
  `docs/design/references/scrum563_route_map_2k/route_map_2k_mockup.png` with
  safe-zone previews in `docs/design/previews/scrum563_route_map_2k_*` and the
  exact geometry/spec in `docs/design/mockups/scrum563_route_map_2k/`. This is
  the visual source for future route-map 2K frame/runtime wiring; it contains no
  baked runtime text and preserves empty interiors for header, HUD, tooltip,
  route nodes/lines and FAB content.
- SCRUM-158 dark fantasy UI backdrops live in `assets/backgrounds/ui/`: `ui_backdrop_system_cathedral.png`, `ui_backdrop_merchant_archive.png`, `ui_backdrop_arcane_lab.png`, `ui_backdrop_reward_hall.png`, `ui_backdrop_defeat_crypt.png`. Each is `2560x1440` with a calm low-contrast center for central panels and richer material detail pushed to the edges. SCRUM-418 removed the old compatibility copies from `assets/sprites/ui/screens/`; runtime mapping now points directly at this canonical backdrop set. Preview: `docs/design/previews/ui_screen_backdrops_dark_fantasy_contact.png`.
- `assets/backgrounds/main_menu_epic_battle_v3.png` is the active start-screen art. SCRUM-560 refreshed the 2560x1440 D&D/dark fantasy composition: the left column stays calm for the six runtime menu buttons, the top-center stays readable for the title, and the battle detail sits center-right/lower-right. The runtime background contains no baked UI text/buttons/frames.
- SCRUM-369 (2026-06-14) replaced the active combat arena set with 10
  `2560x1440` realistic D&D/dark fantasy battle backgrounds generated through
  `fantasydisk-asset-generator` and normalized for gameplay readability:
  `field_marsh.png`, `field_meadow.png`, `field_misty_marsh.png`,
  `field_ruined_courtyard.png`, `field_dusty_badlands.png`,
  `field_enchanted_meadow.png`, `field_ashen_rift.png`,
  `field_cursed_grove.png`, `field_dry_road.png`, `field_stone_garden.png`.
  All are top-down arena floors with richer material detail, restrained central
  contrast, no tall blockers and no UI/text. The two previously missing runtime
  files (`field_dry_road`, `field_stone_garden`) now exist. Source references:
  `docs/design/references/backgrounds/`; previews:
  `docs/design/previews/arena_backgrounds_scrum369_contact.png` and
  `docs/design/previews/arena_backgrounds_scrum369_readability.png`.
