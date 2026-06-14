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
- `tools/extract_realistic_dnd_artifact_icons.py` - active raster source sheet extraction and validation pipeline;
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
- artifact icons use centered realistic D&D/tabletop fantasy magic items on transparent backgrounds, with one complete painted object per icon; shop-only icons use ornate fantasy-medallion frames, strong dark outlines, fantasy-metal/gem accents, glow and transparent background;
- avoid reusing the exact same icon with only a recolor for distinct items.

## Shop Frames And Cursor

Shop frame assets live in `assets/sprites/ui/shop/`. Cursor assets live in `assets/sprites/ui/cursor/`. Back-end hooks are already ready; these PNGs are the active Design target and fallback should remain fail-safe only. Current cursor canon after SCRUM-223: `game_cursor.png`, `game_cursor_hover.png` and `game_cursor_attack.png` are a unified dark steel dragon/clawed fire pointer set with hotspot `(2, 2)`.

SCRUM-182 refreshed the active derived stat icons, shop-only icons, and shop state sprites on 2026-06-13 without changing registry paths. Derived icons in `assets/sprites/ui/icons/derived/` stay `64x64`; shop item icons in `assets/sprites/ui/icons/shop/` stay `128x128`; shop frames/badges/overlays in `assets/sprites/ui/shop/` keep their previous canvas sizes. The style target is compact readable fantasy object art with dark outlines, small material cues, transparent alpha, no text, no emoji, and no meaningless decorative filler. Review sheets: `docs/design/previews/ui_icon_unification_before_contact.png`, `docs/design/previews/ui_icon_unification_after_contact.png`, and `docs/design/previews/ui_icon_unification_40px_preview.png`.

## Character Pipeline Asset Handoffs

SCRUM-165 adds Priest with canonical Design assets `assets/sprites/characters/priest.png`, `assets/sprites/weapons/priest_reliquary.png`, `assets/sprites/weapons/priest_censer.png`, and `assets/sprites/weapons/priest_chime.png`; source/result details are tracked in `docs/tasks/codex_design_priest_art_task.md`. Priest rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_priest_rig_motion_task.md`.

SCRUM-162 adds Biologist gameplay with canonical Design assets ready: `assets/sprites/characters/biologist.png`, `assets/sprites/weapons/biologist_spore_lens.png`, `assets/sprites/weapons/biologist_sample_injector.png`, and `assets/sprites/weapons/biologist_symbiote_seed.png`; contact preview is `docs/design/previews/biologist_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_biologist_art_task.md`. Biologist rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_biologist_rig_motion_task.md`.

SCRUM-166 adds Robot gameplay with canonical Design assets ready: `assets/sprites/characters/robot.png`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `assets/sprites/weapons/robot_hydraulic_press.png`, and `assets/sprites/weapons/robot_reactor_core.png`; contact preview is `docs/design/previews/robot_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_robot_art_task.md`. Robot rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_robot_rig_motion_task.md`.

SCRUM-164 adds Engineer gameplay with canonical Design assets ready: `assets/sprites/characters/engineer.png`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `assets/sprites/weapons/engineer_repair_drone.png`, and `assets/sprites/weapons/engineer_pressure_mines.png`; contact preview is `docs/design/previews/engineer_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_engineer_art_task.md`. Engineer rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_engineer_rig_motion_task.md`.

## Global UI Kit

SCRUM-273 supersedes the SCRUM-147 button-only Parchment & Wax Seal kit with the
active **Red & Gold Dragon button kit** from
`docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png`. Live
button assets are sliced into `assets/sprites/ui/frames/red_gold/` as 15 button
types with four states each: idle/base, hover, pressed and disabled. The old
parchment/wax button kit is backed up outside live assets at
`build/cleanup_backup_red_gold_buttons_2026_06_14/`.

SCRUM-274 supersedes the SCRUM-229 leather+gold runtime panel direction with the
active **Ornate Dark / Red frame kit** from
`docs/design/references/UiFrame/frame_kit_ornate_dark_sheet_b_spec.png`.
Non-button panels/windows/cards/tooltips/HUD/pause stat frames now resolve to
`assets/sprites/ui/frames/ornate/`. The old leather+gold and previous
dark_fantasy/escape panel textures are backed up outside live assets at
`build/cleanup_backup_ornate_frames_2026_06_14/`.

SCRUM-281 adds a screen-specific **Hero Select frame kit** from
`docs/design/references/herouiframe/`. It is used only by `HeroSelectScreen`,
because the portrait/dossier/radar ornaments need custom safe areas. Live
assets resolve to `assets/sprites/ui/frames/hero_select/`; QA screenshots and
rect dumps live in `build/qa/scrum281/`.

Canonical live ornate frame assets live in `assets/sprites/ui/frames/ornate/`:

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

Canonical live button assets live in `assets/sprites/ui/frames/red_gold/`:

- `ui_btn_red_gold_standard.png`, `ui_btn_red_gold_max.png`,
  `ui_btn_red_gold_main_menu.png`, `ui_btn_red_gold_hero_confirm.png`;
- `ui_btn_red_gold_reset_audio.png`, `ui_btn_red_gold_reset_bindings.png`,
  `ui_btn_red_gold_codex_tab.png`, `ui_btn_red_gold_rebind.png`;
- `ui_btn_red_gold_back_s.png`, `ui_btn_red_gold_back_m.png`,
  `ui_btn_red_gold_back_l.png`, `ui_btn_red_gold_attr_selector.png`;
- `ui_btn_red_gold_fab.png`, `ui_btn_red_gold_utility.png`,
  `ui_btn_red_gold_pause.png`;
- every file has `_hover`, `_pressed` and `_disabled` state variants.

State language:

- all visible Button styleboxes use the Red & Gold Dragon kit unless a control is
  intentionally a card/hit-area rather than an action button;
- hover: stronger red/gold glow and brighter metal bevel;
- pressed: darker center and slightly lower-contrast metal read;
- disabled: desaturated, dimmed version of the same button type.

Runtime button sizing (SCRUM-263/SCRUM-264):

- standard action buttons use a 104px minimum height through `_make_button()` / `_set_action_button_size()`;
- the main menu uses `main_menu` 380x104 buttons;
- wide action buttons cap their visual width at 560px so dragon ends do not visibly stretch into a strip;
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
  `pause_stat_tooltip` frames; its buttons use the SCRUM-273 `pause` button.
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
- `tools/apply_button_only_ui_revert.py` - SCRUM-147 correction pipeline: taller wax-seal buttons + restored legacy panels;
- `tools/build_leather_gold_ui_kit.py` - superseded SCRUM-229 panel/window pipeline from user interface references;
- `tools/build_parchment_wax_ui_kit.py` - superseded full-frame parchment builder, protected from direct use;
- `docs/design/previews/red_gold_button_kit_contact.png` - active SCRUM-273 button state/type contact sheet;
- `docs/design/previews/ornate_dark_frame_kit_contact.png` - active SCRUM-274 frame contact sheet;
- `docs/design/previews/hero_select_frame_kit_contact.png` - active SCRUM-281 Hero Select frame contact sheet;
- `docs/design/previews/settings_tab_switcher_frame_content_zone.png` - SCRUM-325 Settings tab switcher safe-area overlay;
- `docs/design/previews/ui_button_only_legacy_panels_contact.png` - SCRUM-147 side-by-side correction sheet;
- `docs/design/previews/interface_leather_gold_panel_kit_contact.png` - superseded SCRUM-229 leather+gold panel kit sheet;
- `build/qa/interface_leather_gold_panel_kit_contact.png` - historical QA copy of the SCRUM-229 leather+gold kit sheet;
- `docs/design/previews/ui_parchment_wax_scrum147_reference_match_contact.png` - compatibility copy of the active correction sheet;
- `docs/design/previews/ui_parchment_kit_reference_contact.png` - contact sheet of the six fullscreen parchment-kit references.

System icons live in `assets/sprites/ui/icons/system/`: close, back, settings, arrows, checkbox checked/unchecked, slider track/grabber and scrollbar grabber. `scripts/ui_icon_registry.gd` exposes them as `system_*` IDs. Default grey Godot controls should remain fail-safe only.

## Contextual UI Direction

`docs/design/ui_contextual_concept.md` and the generated contextual kit in `assets/sprites/ui/frames/contextual/` are superseded by the SCRUM-273/SCRUM-274 UI canon. Their files may remain as historical/reference assets until Back-end cleanup confirms no live references, but they are no longer the UI direction for new screens. Context may still influence role color and button/frame selection, but only through the new Red & Gold Dragon + Ornate Dark canon.

Hard no-junk rule from the user: UI work must not add abstract decorative lines, circles, squares, dots, grids or filler marks. Every visible detail must read as a UI affordance or a believable D&D/tabletop material detail; otherwise it is a Design review defect.

Historical assets:

- `ui_wild_*_frame`, `ui_grave_*_frame`, `ui_laurel_*_frame`, `ui_parchment_*_frame` in `assets/sprites/ui/frames/contextual/`;
- preview sheet: `assets/sprites/ui/frames/contextual/contextual_ui_kits_preview.png`;
- reference contact sheet: `docs/design/previews/contextual_ui_dnd_reference_contact.png`.

Generation task: `docs/tasks/codex_design_contextual_ui_frame_kits_generation_task.md` was completed as historical work; SCRUM-111/SCRUM-118 are superseded by SCRUM-147. Active Back-end integration is `docs/tasks/backend_ui_dark_fantasy_theme_integration_task.md`.

## Characters And Weapons

The expanded 0.1.4 class weapon visual set covers 17 classes and 51 starting weapons. New class full-art PNGs live in `assets/sprites/characters/` at `512x512` with transparent background and cutout-ready silhouettes. SCRUM-168 adds Soldier with canonical `soldier.png`, `soldier_rifle.png`, `soldier_grenade.png`, and `soldier_bayonet.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_soldier_rig_motion_task.md`. SCRUM-169 adds Thief with canonical `thief.png`, `thief_coin_pouch.png`, `thief_shadow_cloak.png`, and `thief_smoke_bomb.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_thief_rig_motion_task.md`. SCRUM-163 adds Elementalist with canonical `elementalist.png`, `elementalist_orb_ring.png`, `elementalist_prism_focus.png`, and `elementalist_meteor_core.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_elementalist_rig_motion_task.md`. SCRUM-167 adds Sniper with canonical `sniper.png`, `sniper_deadeye_rifle.png`, `sniper_spotter_scope.png`, and `sniper_shatter_rounds.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_sniper_rig_motion_task.md`. Later Class Sheet additions Priest, Biologist, Robot and Engineer also have canonical kits; Engineer is the final 17th Back-end class, with rig/cutout/motion tracked in `docs/tasks/animation_engineer_rig_motion_task.md`.

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

## Screen And Map Backgrounds

- `assets/backgrounds/route_map_backdrop.png` - 2560x1440 eerie neutral route map background. It should stay darker and calmer than combat arenas, with low-contrast fog in the central route column and heavier silhouettes pushed to the edges.
- SCRUM-158 dark fantasy UI backdrops live in `assets/backgrounds/ui/`: `ui_backdrop_system_cathedral.png`, `ui_backdrop_merchant_archive.png`, `ui_backdrop_arcane_lab.png`, `ui_backdrop_reward_hall.png`, `ui_backdrop_defeat_crypt.png`. Each is `2560x1440` with a calm low-contrast center for central panels and richer material detail pushed to the edges. Active compatibility copies were written to `assets/sprites/ui/screens/screen_shop_background.png`, `screen_event_background.png`, and `screen_campfire_background.png`; broader screen-to-role mapping is handed off in `docs/tasks/backend_ui_screen_backdrops_integration_task.md`. Preview: `docs/design/previews/ui_screen_backdrops_dark_fantasy_contact.png`.
- `assets/backgrounds/main_menu_epic_battle.png` is the active start-screen art. SCRUM-158 replaced it with a dark fantasy battle scene using FantasyDisk heroes/bosses as references, keeping the left third calmer for the three menu buttons.
- `assets/backgrounds/field_stone_garden.png`, `field_marsh.png`, `field_dry_road.png`, `field_meadow.png` - active 2560x1440 combat backgrounds. Redrawn 2026-06-12 as professional D&D tabletop battlemaps (`tools/generate_dnd_battlemaps.py`, supersedes the earlier `generate_detailed_flat_backgrounds.py` circle-pebble pass which the user rejected as amateurish): stone_garden = irregular bevelled flagstone courtyard with dark mortar grooves and moss; dry_road = packed offset cobblestone with earth gaps and faint wheel ruts; meadow = painterly grass turf (layered brush blades) with soil patches, flower clumps and a few flush angular field stones; marsh = wet peat with irregular water pools, reed clumps and moss. Still flat top-down (no tall objects / false perspective), low contrast so characters/enemies/projectiles read on top. Featureless flat versions kept at `build/bg_backup/flat_*.png`.
- 2026-06-12 D&D expansion backgrounds: `field_ruined_courtyard.png`, `field_misty_marsh.png`, `field_dusty_badlands.png`, `field_enchanted_meadow.png`, `field_ashen_rift.png`, `field_cursed_grove.png`. All are 2560x1440 top-down battlefields with small, flush-to-ground details and fewer large rocks/bushes per user direction. They are connected in `scripts/main.gd::ARENA_BACKGROUND_OPTIONS`; QA sheet: `docs/design/previews/arena_backgrounds_6_dnd_contact.png`.
