# Codex Design Task: UI Icon Style Unification

Статус: in_progress (Codex Design, dispatched 2026-06-13)
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
