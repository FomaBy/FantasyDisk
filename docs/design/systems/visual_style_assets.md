# Visual Style Assets

Обновлено: 2026-06-11

Этот файл фиксирует reusable visual assets FantasyDisk после domain split. Подробные таблицы сущностей остаются в `docs/design/content_registry.md`.

## Artifact And Shop Icons

All artifacts from `ProgressionData.ARTIFACTS` and all shop-only items from `ProgressionData.SHOP_ITEMS` have unique stylized PNG icons. Artifact icons were replaced on 2026-06-11 with `256x256` final epic dark fantasy transparent item icons after direct user feedback: one centered artifact object per icon, no built-in UI frame, blackened metal, bone/stone, dark leather, cursed paper, crystals, runes, scratches/cracks and bright controlled magical accents. Shop-only icons keep the earlier fantasy-medallion treatment.

Canonical folders:

- `assets/sprites/ui/icons/artifacts/` - `artifact_<artifact_id>.png` (`256x256`);
- `assets/sprites/ui/icons/shop/` - `shop_<shop_item_id>.png`;
- `assets/sprites/ui/icons/artifact_final_dark_fantasy_40px_preview.png` - active 40px artifact preview sheet;
- `assets/sprites/ui/icons/artifact_generated_concept_40px_preview.png` - legacy preview path updated to the same active icon set;
- `assets/sprites/ui/icons/artifact_dark_artifacts_40px_preview.png` - legacy preview path updated to the same active icon set;
- `tools/final_redesign_artifact_icons.py` - final artifact icon polish/extraction pipeline;
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
- artifact icons use centered epic dark fantasy items on transparent backgrounds; shop-only icons use ornate fantasy-medallion frames, strong dark outlines, fantasy-metal/gem accents, glow and transparent background;
- avoid reusing the exact same icon with only a recolor for distinct items.

## Shop Frames And Cursor

Shop frame assets live in `assets/sprites/ui/shop/`. Cursor assets live in `assets/sprites/ui/cursor/`. Back-end hooks are already ready; these PNGs are the active Design target and fallback should remain fail-safe only.

## Screen And Map Backgrounds

- `assets/backgrounds/route_map_backdrop.png` - 2560x1440 eerie neutral route map background. It should stay darker and calmer than combat arenas, with low-contrast fog in the central route column and heavier silhouettes pushed to the edges.
