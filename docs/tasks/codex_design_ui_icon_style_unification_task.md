# Codex Design Task: UI Icon Style Unification

Статус: done (Design review approved 2026-06-13)
Версия: 0.1.5
Создано: 2026-06-13
Роль: Design / Codex image generation
Jira: SCRUM-182
Parent audit: `docs/tasks/audit_sprites_visual_consistency.md` / SCRUM-177

## Goal

Bring derived stat icons, shop-only icons, and shop UI state sprites closer to the current D&D/dark-fantasy raster quality of artifact icons and character art.

## Scope

Review and redraw as needed:

- `assets/sprites/ui/icons/derived/*.png`
- `assets/sprites/ui/icons/shop/*.png`
- `assets/sprites/ui/shop/*.png`

Do not redraw artifact icons in this task unless a specific artifact regression is found; the current artifact raster pass is accepted by this audit.

## Art Direction

- Avoid flat/vector/pictogram feel.
- Use small but material-rich fantasy objects, runes, engraved metal, parchment, crystal, bone, leather, and painterly light.
- Maintain clear 40px readability in Escape stats, level-up, shop, and tooltips.
- Transparent background, no text, no watermark.

## Acceptance

- Before/after contact sheet in `docs/design/previews/`.
- 40px readability preview.
- `scripts/ui_icon_registry.gd` mapping changes are Back-end scope; create handoff if filenames or mappings need to change.

## Dispatcher Note (2026-06-13)
Dispatched to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` after user confirmed no feature freeze / backlog is eligible.

## Result (2026-06-13)

Design pass completed for the active derived/shop UI icon set. The update preserves all existing filenames and mapping paths, so no `scripts/ui_icon_registry.gd` changes or Back-end integration changes are required.

Updated assets:

- 20 derived stat icons in `assets/sprites/ui/icons/derived/` (`64x64`);
- 7 shop item icons in `assets/sprites/ui/icons/shop/` (`128x128`);
- 5 shop state/frame sprites in `assets/sprites/ui/shop/`.

Review previews:

- `docs/design/previews/ui_icon_unification_before_contact.png`;
- `docs/design/previews/ui_icon_unification_after_contact.png`;
- `docs/design/previews/ui_icon_unification_40px_preview.png`.

Validation:

- PNG validation: all 32 updated assets are RGBA, preserve their previous dimensions, and have non-empty alpha.
- Godot import: passed.
- 40px readability preview created for Escape stats/level-up/shop tooltip usage.
- Full `runtime_smoke_test` was not rerun as a passing gate because the current workspace already has an unrelated Back-end/runtime blocker in noncombat shop stock persistence, recorded in SCRUM-181 validation notes.

Design decision:

- Kept the icons compact and object-based rather than adding decorative UI junk. The style now favors readable fantasy silhouettes, dark outlines, brass/parchment/stone/wood material hints, and transparent backgrounds while avoiding text, watermarks, emoji, and default Godot-looking controls.


## Design Review / 2026-06-13 — ПРИНЯТО (Claude-Designer)
- SCRUM-182: 20 derived(64) + 7 shop(128) + 5 shop-state унифицированы, имена/маппинг без изменений.
- Единый dark-fantasy канон: тёмная обводка, мягкая тень, материал на металл/гем/дерево-иконках.
- Читаемость 40px подтверждена (Escape stats/level-up/shop/tooltip) — силуэты различимы, не вектор-дефолт.
- Замечание (не блокер): абстрактные концепты (attack_speed/crit/health) намеренно проще — оправданный
  компромисс ради 40px-читаемости; дальнейшее усложнение нанесёт вред мелкому размеру. Бар выполнен.
- Маппинг ui_icon_registry не трогался — Back-end-интеграция не требуется. Ассеты закоммичены.
