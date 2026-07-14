# Handoff → Codex / Back-end: Codex Atlas/Settings art integration

Source Design issue: FAN-1066 (parent FAN-1065). This is Design output only — a
new **art skin** for the existing Codex screen. Geometry is the accepted
SCRUM-954/FAN-1047 contract and must stay unchanged. Runtime promotion + wiring
is a separate Back-end child issue.

## What to integrate

Promote these Design candidates (currently under `docs/design/references/fan1065_codex_atlas_settings_redesign/`)
into runtime assets (suggested `assets/sprites/ui/atlas_style/codex/`) and bind
them in `scripts/ui_screens.gd` (`_show_codex_screen`, `_codex_update_detail`).

| Runtime use | Asset | Import / draw | Texture margins | Content margins (L,T,R,B) |
| --- | --- | --- | --- | --- |
| Nav / Content / Detail / Title panels | `derived/panel_9slice.png` | StyleBoxTexture 9-slice | 46/46/46/46 | title 36/22/36/22 · nav 32/38/32/50 · content&detail 32/36/32/44 |
| Center entry row (516x154) | `derived/entry_card_516x154.png` | TextureRect / StyleBoxTexture (aspect-matched, no ornament stretch) | — | reserve 20/20/30/20; left image well 122x114, image 88x96 |
| Dossier image well (236x248 in 300x300 rail) | `derived/dossier_well_236x248.png` (or `source/dossier_parchment_kit.png`) | TextureRect behind portrait; portrait STRETCH_KEEP_ASPECT_CENTERED | — | slot 32/26/32/26 |
| Dossier chips (330x70) | `derived/chip_bar.png` | StyleBoxTexture 9-slice | 40/20/40/20 | 18/14/18/14 |
| Dossier lore parchment (684x356) | `source/dossier_parchment_kit.png` | NinePatchRect (wide) | 96/96/96/96 | 32/26/42/26 |
| Header crest (104x104) | `source/codex_crest.png` | TextureRect at (908,24) | — | — |
| Sanctum backdrop | `source/codex_sanctum_backdrop.png` | TextureRect COVERED; crop inner scene (inset ~30/26) | — | — |

Buttons: the six tabs and Back **stay in the existing main-menu button family**
(`assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_codex_tab*`
and `..._main_menu*`) — do not regenerate or restyle them.

## Rules to preserve

- Do NOT change any rect, tab count, scroll-lane count, or `CodexStage` uniform
  scaling. Copy rects from `layout.json`.
- Content (text, portrait, name, icons) only in the empty inner zones; never on
  a bronze bracket, bevel, dragon-scale corner, or parchment rim
  (AGENTS.md global frame rule, `qa_protocol.md` "Контент только в пустой зоне").
- Round frames are absent; everything is 9-slice-safe except the entry card and
  the near-square dossier well (aspect-match those; do not 9-slice their divider
  / corners).
- After swap, run `tests/ui_no_overlap_matrix_test.gd`,
  `tests/runtime_smoke_ui_test.gd`, `tests/dark_fantasy_ui_theme_test.gd`, and
  `tests/codex_scrum954_layout_test.gd` across the responsive matrix, then a real
  screenshot at 1280x720 / 1920x1080 / 2560x1440.

## Provenance

PixelLab MCP source IDs, prompts, seeds, export dims:
`docs/design/references/fan1065_codex_atlas_settings_redesign/manifest.json`.
Note: PixelLab-side storage auto-expires ~8h after generation — the committed
PNGs are the durable copies.
