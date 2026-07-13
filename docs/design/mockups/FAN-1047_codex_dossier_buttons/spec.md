# FAN-1047 — Supplemental PixelLab Exploration

Status: reference-only; canonical runtime contract implemented and verified
Canonical spec: `docs/design/mockups/fan1047_unified_action_buttons/spec.md`
Task: `docs/tasks/FAN-1047.md`
Generated with: PixelLab MCP `create_ui_asset`
Provenance: `docs/design/references/FAN-1047_codex_dossier_buttons/manifest.json`

## Purpose

These two PixelLab outputs were generated before implementation to verify the
visual direction requested by the source screenshot: remove the yellow Codex
exception, use one heroic Main Menu plate language, and keep all four dossier
actions fully bounded by their safe zone. They are layout references only.

The exact runtime geometry and asset decision are defined by the canonical
lower-case spec linked above:

- all ten actions use `text/main_menu_380x104` in five states;
- Codex tabs render at `260×72` with compact Russian captions;
- 648p/720p/900p dossier actions form a ratio-preserving right rail;
- 1080p/2K dossier actions form a ratio-preserving horizontal footer;
- texture and content margins scale uniformly with the plate.

## Generated References

| Asset | PixelLab source ID | Runtime use |
| --- | --- | --- |
| `pixellab_codex_main_menu_family_688x384.png` | `68ae588d-1191-4a7b-875b-70668c84a623` | reference only |
| `pixellab_dossier_actions_688x384.png` | `719436ba-2b67-4424-ae7f-d0e4199e5415` | reference only |

The original Multica screenshot is preserved as `image.png`. No image in this
folder is promoted to `assets/`; production reuses the existing five-state
`text_buttons_unique` kit.

## Acceptance

- [x] References generated and previewed before runtime edits.
- [x] Runtime uses the exact Main Menu family, not a new generated bitmap.
- [x] Old `minimal/codex_tab` runtime path is gone.
- [x] Canonical five-target/live-resize, focus and smoke gates pass.
