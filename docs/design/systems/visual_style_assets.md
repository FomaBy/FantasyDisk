# Visual Style Assets

Обновлено: 2026-06-12

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

Shop frame assets live in `assets/sprites/ui/shop/`. Cursor assets live in `assets/sprites/ui/cursor/`. Back-end hooks are already ready; these PNGs are the active Design target and fallback should remain fail-safe only.

SCRUM-182 refreshed the active derived stat icons, shop-only icons, and shop state sprites on 2026-06-13 without changing registry paths. Derived icons in `assets/sprites/ui/icons/derived/` stay `64x64`; shop item icons in `assets/sprites/ui/icons/shop/` stay `128x128`; shop frames/badges/overlays in `assets/sprites/ui/shop/` keep their previous canvas sizes. The style target is compact readable fantasy object art with dark outlines, small material cues, transparent alpha, no text, no emoji, and no meaningless decorative filler. Review sheets: `docs/design/previews/ui_icon_unification_before_contact.png`, `docs/design/previews/ui_icon_unification_after_contact.png`, and `docs/design/previews/ui_icon_unification_40px_preview.png`.

## Character Pipeline Asset Handoffs

SCRUM-165 adds Priest with canonical Design assets `assets/sprites/characters/priest.png`, `assets/sprites/weapons/priest_reliquary.png`, `assets/sprites/weapons/priest_censer.png`, and `assets/sprites/weapons/priest_chime.png`; source/result details are tracked in `docs/tasks/codex_design_priest_art_task.md`. Priest rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_priest_rig_motion_task.md`.

SCRUM-162 adds Biologist gameplay with canonical Design assets ready: `assets/sprites/characters/biologist.png`, `assets/sprites/weapons/biologist_spore_lens.png`, `assets/sprites/weapons/biologist_sample_injector.png`, and `assets/sprites/weapons/biologist_symbiote_seed.png`; contact preview is `docs/design/previews/biologist_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_biologist_art_task.md`. Biologist rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_biologist_rig_motion_task.md`.

SCRUM-166 adds Robot gameplay with canonical Design assets ready: `assets/sprites/characters/robot.png`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `assets/sprites/weapons/robot_hydraulic_press.png`, and `assets/sprites/weapons/robot_reactor_core.png`; contact preview is `docs/design/previews/robot_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_robot_art_task.md`. Robot rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_robot_rig_motion_task.md`.

SCRUM-164 adds Engineer gameplay with canonical Design assets ready: `assets/sprites/characters/engineer.png`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `assets/sprites/weapons/engineer_repair_drone.png`, and `assets/sprites/weapons/engineer_pressure_mines.png`; contact preview is `docs/design/previews/engineer_art_contact.png`, and source/result notes live in `docs/tasks/codex_design_engineer_art_task.md`. Engineer rig/cutout/motion ownership is tracked separately in `docs/tasks/animation_engineer_rig_motion_task.md`.

## Global UI Kit

The 2026-06-12 UI overhaul adds a reusable texture-frame kit in `assets/sprites/ui/frames/global/`. Source of truth for frames + system icons is now `tools/generate_ui_tavern_theme.py` (the frame/icon part of `generate_ui_overhaul_visual_assets.py` is superseded — re-running it would overwrite the warm theme with the old cold one).

Per the user's 2026-06-12 art direction, the kit is a warm Dungeons & Dragons tavern theme: dark wood / worn leather panels, brass trim with corner studs, candle-amber accents, no cyan gems. Panels stay dark ("tavern at night") so the light in-game text stays readable; buttons use a warm brown tint base; the coldest blue-white text colors were shifted to warm parchment.

Canonical assets:

- `ui_panel_frame.png` - large panels for menus, codex, event/reward/death/victory layouts;
- `ui_button_frame.png` - shared button frame, tinted per normal/hover/pressed/danger/level-up variant;
- `ui_card_frame.png` - character cards, route node buttons, compact cards;
- `ui_level_panel_frame.png` - level-up/reward panel;
- `ui_hud_panel_frame.png` and `ui_hud_card_frame.png` - combat HUD shell/cards;
- `ui_tooltip_frame.png` - generic tooltip/system frame.

System icons live in `assets/sprites/ui/icons/system/`: close, back, settings, arrows, checkbox checked/unchecked, slider track/grabber and scrollbar grabber. `scripts/ui_icon_registry.gd` exposes them as `system_*` IDs. Settings sliders and checkboxes are styled with these textures; default grey Godot controls should remain fail-safe only.

## Contextual UI Direction

`docs/design/ui_contextual_concept.md` defines the next UI-frame direction: the current tavern kit becomes a utility/shop fallback, while new context kits should carry screen meaning. The generated review kit in `assets/sprites/ui/frames/contextual/` contains Wild Start (main/hero/weapon), Grave Defeat (death/danger), Laurel Reward (victory/level-up/rewards), and Parchment/Codex/Map (codex/event/route). After user feedback on the first simple pass, the active PNGs were redrawn into a richer realistic D&D/tabletop raster style using current FantasyDisk artifacts/characters/weapons/backgrounds as references for material depth, dark outline, bevels and worn fantasy surfaces. The audit found that repeated brass studs and curved corner strokes are meaningful in merchant/utility contexts but become decoration without purpose on death, victory, codex and route screens.

Hard no-junk rule from the user: contextual UI work must not add abstract
decorative lines, circles, squares, dots, grids or filler marks. Every visible
detail must read as a UI affordance or a believable D&D/tabletop material detail;
otherwise it is a Design review defect.

Generated assets:

- `ui_wild_panel_frame.png`, `ui_wild_button_frame.png`, `ui_wild_card_frame.png`, `ui_wild_tooltip_frame.png`;
- `ui_grave_panel_frame.png`, `ui_grave_button_frame.png`, `ui_grave_card_frame.png`, `ui_grave_tooltip_frame.png`;
- `ui_laurel_panel_frame.png`, `ui_laurel_button_frame.png`, `ui_laurel_card_frame.png`, `ui_laurel_tooltip_frame.png`;
- `ui_parchment_panel_frame.png`, `ui_parchment_button_frame.png`, `ui_parchment_card_frame.png`, `ui_parchment_tooltip_frame.png`, `ui_parchment_tab_frame.png`;
- preview sheet: `assets/sprites/ui/frames/contextual/contextual_ui_kits_preview.png`.
- reference contact sheet used for the rework: `docs/design/previews/contextual_ui_dnd_reference_contact.png`.

Generation task: `docs/tasks/codex_design_contextual_ui_frame_kits_generation_task.md` is done after Design owner review and QA SCRUM-120. Back-end integration handoff: `docs/tasks/backend_contextual_ui_frame_theme_integration_task.md` / SCRUM-118 remains backlog `0.1.4` under the 0.1.3 feature block.

## Characters And Weapons

The 0.2 class weapon visual set was completed on 2026-06-11 for the first 9 classes and 27 starting weapons. New class full-art PNGs live in `assets/sprites/characters/` (`assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png`) at `512x512` with transparent background and separated readable legs for future cutout/walk rig work. SCRUM-168 adds Soldier with canonical `soldier.png`, `soldier_rifle.png`, `soldier_grenade.png`, and `soldier_bayonet.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_soldier_rig_motion_task.md`. SCRUM-169 adds Thief with canonical `thief.png`, `thief_coin_pouch.png`, `thief_shadow_cloak.png`, and `thief_smoke_bomb.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_thief_rig_motion_task.md`. SCRUM-163 adds Elementalist with canonical `elementalist.png`, `elementalist_orb_ring.png`, `elementalist_prism_focus.png`, and `elementalist_meteor_core.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_elementalist_rig_motion_task.md`. SCRUM-167 adds Sniper with canonical `sniper.png`, `sniper_deadeye_rifle.png`, `sniper_spotter_scope.png`, and `sniper_shatter_rounds.png`; rig/cutout/motion is tracked separately in `docs/tasks/animation_sniper_rig_motion_task.md`. Later Class Sheet additions Priest, Biologist, Robot and Engineer also have canonical kits; Engineer is the final 17th Back-end class, with rig/cutout/motion tracked in `docs/tasks/animation_engineer_rig_motion_task.md`.

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

Review previews:

- `docs/design/previews/elite_boss_upscale_before_contact.png`;
- `docs/design/previews/elite_boss_upscale_after_contact.png`;
- `docs/design/previews/elite_boss_upscale_rig_debug_contact.png`.

## Combat VFX Assets

Attack VFX sprites live in `assets/sprites/effects/` and are transparent PNGs intended for tinted `Sprite2D`/tween-based effects, not raw Godot primitive circles. On 2026-06-12 the first weapon VFX polish block replaced the visible persistent pool placeholders with raster fantasy effects:

- `poison_pool.png` - green bubbling acid/poison puddle for Acid Flask and poison pools;
- `spark_pool.png` - warm ember/spark chemical cloud for Blast Powder;
- `briar_pool.png` - thorny green bramble pool for Druid/Druidic zone effects.

`scripts/class_weapon.gd` now selects these by `pool_element` and animates them with pause-aware node-bound tweens. The gameplay radius, tick interval and duration stay data-driven from weapon config. QA preview: `docs/design/previews/vfx_pool_assets_contact.png`.

SCRUM-181 refreshed the full active VFX set again on 2026-06-13 after the sprite audit: all 19 `assets/sprites/effects/*.png` files now use a restrained painterly D&D/tabletop treatment with softer alpha edges, earthy gold/green/violet accents, readable silhouettes, and no acid-neon or baked pure-white overexposure. Tintable assets (`hazard_zone.png`, `elite_telegraph_circle.png`) remain warm-neutral so code modulation can recolor them. QA/reference previews live in `docs/design/previews/vfx_polish_before_contact.png`, `docs/design/previews/vfx_polish_after_contact.png`, `docs/design/previews/vfx_polish_before_after_contact.png`, `docs/design/previews/vfx_polish_readability_field_meadow.png`, and `docs/design/previews/vfx_polish_readability_field_marsh.png`.

## Screen And Map Backgrounds

- `assets/backgrounds/route_map_backdrop.png` - 2560x1440 eerie neutral route map background. It should stay darker and calmer than combat arenas, with low-contrast fog in the central route column and heavier silhouettes pushed to the edges.
- SCRUM-158 dark fantasy UI backdrops live in `assets/backgrounds/ui/`: `ui_backdrop_system_cathedral.png`, `ui_backdrop_merchant_archive.png`, `ui_backdrop_arcane_lab.png`, `ui_backdrop_reward_hall.png`, `ui_backdrop_defeat_crypt.png`. Each is `2560x1440` with a calm low-contrast center for central panels and richer material detail pushed to the edges. Active compatibility copies were written to `assets/sprites/ui/screens/screen_shop_background.png`, `screen_event_background.png`, and `screen_campfire_background.png`; broader screen-to-role mapping is handed off in `docs/tasks/backend_ui_screen_backdrops_integration_task.md`. Preview: `docs/design/previews/ui_screen_backdrops_dark_fantasy_contact.png`.
- `assets/backgrounds/main_menu_epic_battle.png` is the active start-screen art. SCRUM-158 replaced it with a dark fantasy battle scene using FantasyDisk heroes/bosses as references, keeping the left third calmer for the three menu buttons.
- `assets/backgrounds/field_stone_garden.png`, `field_marsh.png`, `field_dry_road.png`, `field_meadow.png` - active 2560x1440 combat backgrounds. Redrawn 2026-06-12 as professional D&D tabletop battlemaps (`tools/generate_dnd_battlemaps.py`, supersedes the earlier `generate_detailed_flat_backgrounds.py` circle-pebble pass which the user rejected as amateurish): stone_garden = irregular bevelled flagstone courtyard with dark mortar grooves and moss; dry_road = packed offset cobblestone with earth gaps and faint wheel ruts; meadow = painterly grass turf (layered brush blades) with soil patches, flower clumps and a few flush angular field stones; marsh = wet peat with irregular water pools, reed clumps and moss. Still flat top-down (no tall objects / false perspective), low contrast so characters/enemies/projectiles read on top. Featureless flat versions kept at `build/bg_backup/flat_*.png`.
- 2026-06-12 D&D expansion backgrounds: `field_ruined_courtyard.png`, `field_misty_marsh.png`, `field_dusty_badlands.png`, `field_enchanted_meadow.png`, `field_ashen_rift.png`, `field_cursed_grove.png`. All are 2560x1440 top-down battlefields with small, flush-to-ground details and fewer large rocks/bushes per user direction. They are connected in `scripts/main.gd::ARENA_BACKGROUND_OPTIONS`; QA sheet: `docs/design/previews/arena_backgrounds_6_dnd_contact.png`.
