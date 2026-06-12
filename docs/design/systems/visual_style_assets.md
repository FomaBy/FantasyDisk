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

## Characters And Weapons

The 0.2 class weapon visual set was completed on 2026-06-11 for all 9 classes and 27 starting weapons. New class full-art PNGs live in `assets/sprites/characters/` (`assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png`) at `512x512` with transparent background and separated readable legs for future cutout/walk rig work.

All weapon visuals live in `assets/sprites/weapons/` at `256x256` with transparent background. The active style target is polished cartoon dark fantasy: strong black silhouette, readable object shape at `40x40`, compact controlled glow, material detail, and no text/watermark/built-in UI frame. Weapon art v2 pass 2026-06-12 replaced the Knight trio (`long_spear.png`, `tower_shield.png`, `holy_flail.png`) with polished noble equipment, removed fallback texture links from weapon scenes, and reduced socket display scale across oversized weapons. The raw and socket QA sheets are `docs/design/previews/weapon_v2_assets_contact.png` and `docs/design/previews/weapon_v2_socket_contact.png`.

Per-weapon socket/display notes are tracked in `docs/design/systems/characters_weapons.md` and the Design handoff task `docs/tasks/design_all_classes_three_weapons_visual_upgrade_task.md`.

## Combat VFX Assets

Attack VFX sprites live in `assets/sprites/effects/` and are transparent PNGs intended for tinted `Sprite2D`/tween-based effects, not raw Godot primitive circles. On 2026-06-12 the first weapon VFX polish block replaced the visible persistent pool placeholders with raster fantasy effects:

- `poison_pool.png` - green bubbling acid/poison puddle for Acid Flask and poison pools;
- `spark_pool.png` - warm ember/spark chemical cloud for Blast Powder;
- `briar_pool.png` - thorny green bramble pool for Druid/Druidic zone effects.

`scripts/class_weapon.gd` now selects these by `pool_element` and animates them with pause-aware node-bound tweens. The gameplay radius, tick interval and duration stay data-driven from weapon config. QA preview: `docs/design/previews/vfx_pool_assets_contact.png`.

Codex D&D VFX restyle pass 2026-06-12 replaced all 19 active PNGs in `assets/sprites/effects/` with restrained tabletop-style raster effects: muted noble palette, soft alpha glow, no acid-neon colors, no pure-white overexposure, and simpler silhouettes for fast combat readability. Tintable assets (`hazard_zone.png`, `elite_telegraph_circle.png`) remain warm-neutral so code modulation can recolor them. The non-runtime review sheet was moved out of `assets/` by the 2026-06-12 cleanup and is recoverable from `build/cleanup_backup_2026_06_12/assets/sprites/effects/effects_dnd_preview.png`.

## Screen And Map Backgrounds

- `assets/backgrounds/route_map_backdrop.png` - 2560x1440 eerie neutral route map background. It should stay darker and calmer than combat arenas, with low-contrast fog in the central route column and heavier silhouettes pushed to the edges.
- `assets/backgrounds/field_stone_garden.png`, `field_marsh.png`, `field_dry_road.png`, `field_meadow.png` - active 2560x1440 combat backgrounds. Redrawn 2026-06-12 as professional D&D tabletop battlemaps (`tools/generate_dnd_battlemaps.py`, supersedes the earlier `generate_detailed_flat_backgrounds.py` circle-pebble pass which the user rejected as amateurish): stone_garden = irregular bevelled flagstone courtyard with dark mortar grooves and moss; dry_road = packed offset cobblestone with earth gaps and faint wheel ruts; meadow = painterly grass turf (layered brush blades) with soil patches, flower clumps and a few flush angular field stones; marsh = wet peat with irregular water pools, reed clumps and moss. Still flat top-down (no tall objects / false perspective), low contrast so characters/enemies/projectiles read on top. Featureless flat versions kept at `build/bg_backup/flat_*.png`.
- 2026-06-12 D&D expansion backgrounds: `field_ruined_courtyard.png`, `field_misty_marsh.png`, `field_dusty_badlands.png`, `field_enchanted_meadow.png`, `field_ashen_rift.png`, `field_cursed_grove.png`. All are 2560x1440 top-down battlefields with small, flush-to-ground details and fewer large rocks/bushes per user direction. They are connected in `scripts/main.gd::ARENA_BACKGROUND_OPTIONS`; QA sheet: `docs/design/previews/arena_backgrounds_6_dnd_contact.png`.
