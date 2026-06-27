# SCRUM-536 — Map Icon: Chest Artifact

Статус: done
Контур: Codex
Owner: Design / Designer 2
Thread: codex-background-designer-agent
Locked paths: `assets/sprites/map_icons/map_chest_artifact.png`, `docs/design/references/map_icons/chest_artifact/`, `docs/design/previews/map_chest_artifact_contact_sheet.png`
Jira: SCRUM-536

## Scope

Design-only delivery for the future `chest` route-map special node. No route generation, reward logic, UI runtime hook, GDScript, balance, or animation changes were made.

## Result

- Runtime icon: `assets/sprites/map_icons/map_chest_artifact.png`
- Source/reference: `docs/design/references/map_icons/chest_artifact/map_chest_artifact_source.png`
- Alpha-clean source: `docs/design/references/map_icons/chest_artifact/map_chest_artifact_alpha.png`
- Alpha/readability report: `docs/design/references/map_icons/chest_artifact/map_chest_artifact_alpha_report.json`
- Contact/readability preview: `docs/design/previews/map_chest_artifact_contact_sheet.png`

## Validation

- Generated with `fantasydisk-asset-generator` (`gpt-image-2`) as a 1024x1024 source reference.
- Final runtime PNG is `128x128` RGBA with transparent background.
- Alpha audit PASS: `edge_alpha_max=0`, `white_opaque_pixels=0`, `green_opaque_pixels=0`, no clipped important silhouette.
- Contact sheet checks readability against existing battle/event/shop icons at 64px, 40px, and 32px.

## Notes For Back-end

Use `assets/sprites/map_icons/map_chest_artifact.png` for the `chest` route node when the runtime node/reward hook is implemented in a separate Back-end task.
