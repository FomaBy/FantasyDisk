# Visual Style Assets

Обновлено: 2026-06-11

Этот файл фиксирует reusable visual assets FantasyDisk после domain split. Подробные таблицы сущностей остаются в `docs/design/content_registry.md`.

## Artifact And Shop Icons

All artifacts from `ProgressionData.ARTIFACTS` and all shop-only items from `ProgressionData.SHOP_ITEMS` have unique stylized PNG icons with transparent backgrounds. Artifact icons were regenerated on 2026-06-11 as `256x256` dark-fantasy item art: one centered object, no built-in frame, muted painted materials, top-left light, deep shadows and colored magical glow. Shop-only icons keep the earlier fantasy-medallion treatment.

Canonical folders:

- `assets/sprites/ui/icons/artifacts/` - `artifact_<artifact_id>.png` (`256x256`);
- `assets/sprites/ui/icons/shop/` - `shop_<shop_item_id>.png`;
- `assets/sprites/ui/icons/artifact_shop_cursor_preview.png` - preview sheet;
- `tools/generate_dark_fantasy_artifact_icons.py` - deterministic artifact icon generator;
- `tools/generate_artifact_shop_cursor_assets.py` - deterministic shop/cursor source generator.

Canonical mapping:

```text
docs/design/artifact_shop_cursor_visual_kit.md
```

Visual rules:

- no emoji/default placeholders;
- no text inside icons;
- keep artifact silhouettes readable at `40x40`;
- artifact icons use centered dark-fantasy item art without built-in frames; shop-only icons use ornate fantasy-medallion frames, strong dark outlines, fantasy-metal/gem accents, glow and transparent background;
- avoid reusing the exact same icon with only a recolor for distinct items.

## Shop Frames And Cursor

Shop frame assets live in `assets/sprites/ui/shop/`. Cursor assets live in `assets/sprites/ui/cursor/`. Back-end hooks are already ready; these PNGs are the active Design target and fallback should remain fail-safe only.

## Screen And Map Backgrounds

- `assets/backgrounds/route_map_backdrop.png` - 2560x1440 eerie neutral route map background. It should stay darker and calmer than combat arenas, with low-contrast fog in the central route column and heavier silhouettes pushed to the edges.
