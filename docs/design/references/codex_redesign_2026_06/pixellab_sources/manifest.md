# SCRUM-725 Codex PixelLab Source Manifest

Phase 3 generated a textless Codex frame/source set through PixelLab MCP, then
used `../build_scrum725_codex_assets.py` as a deterministic cleanup/build pass
for runtime PNGs. The cleanup is intentionally reproducible: it removes baked
labels/checker artifacts from raw generation outputs and confines ornament to
the documented 9-slice margin bands from
`docs/design/mockups/codex_redesign_2026_06/layout_map.md`.

Runtime output paths:
- `assets/sprites/ui/frames/codex_pl/codex_pl_main_shell.png`
- `assets/sprites/ui/frames/codex_pl/codex_pl_nav_panel.png`
- `assets/sprites/ui/frames/codex_pl/codex_pl_grid_panel.png`
- `assets/sprites/ui/frames/codex_pl/codex_pl_detail_panel.png`
- `assets/sprites/ui/frames/codex_pl/codex_pl_entry_card.png`
- `assets/sprites/ui/frames/codex_pl/codex_pl_category_button.png`
- `assets/sprites/ui/frames/codex_pl/codex_pl_back_button.png`
- `assets/sprites/ui/frames/codex_pl/codex_pl_backdrop.png`
- Matching `assets/sprites/ui/frames/codex_pl/fit/*.png` copies for existing runtime imports.

PixelLab source IDs:
- `scrum725_codex_main_shell`: `706df0ba-e05a-4891-b27b-6aeddaf6363e`, 688x384.
- `scrum725_codex_nav_panel`: `28f4d788-f456-4cb0-9234-a41d4ea60293`, 384x688.
- `scrum725_codex_list_panel`: `5630c5aa-5186-42df-9fda-864b28d8037c`, 512x512.
- `scrum725_codex_detail_panel`: `5c5bd5dc-a451-4bcd-b2f5-2428eda7257d`, 384x688.
- `scrum725_codex_entry_card`: `39fae457-3ba8-4036-a1e8-b5d1492fb47f`, 688x192.
- `scrum725_codex_category_button`: `f6b8c941-b3a8-4568-872f-558b432297c4`, 512x192.
- `scrum725_codex_back_button`: `56f2289a-aebb-4810-822e-e59c5d9cfd4e`, 384x192.
- `scrum725_codex_backdrop_library`: `7ed510e5-65bb-43fd-b770-5e7bf6e73851`, 688x384.

Preview/evidence:
- Raw PixelLab contact: `docs/design/previews/codex_redesign_2026_06_pixellab_contact.png`.
- Runtime cleanup contact: `docs/design/previews/codex_redesign_2026_06_runtime_contact.png`.
- Runtime asset audit: `docs/design/references/codex_redesign_2026_06/runtime_asset_audit.md`.
