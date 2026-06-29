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

## QA-Вердикт 2026-06-27
Статус: PASSED

Проверено:
- Runtime/source/evidence files are present:
  `assets/sprites/map_icons/map_chest_artifact.png`,
  `docs/design/references/map_icons/chest_artifact/map_chest_artifact_source.png`,
  `docs/design/references/map_icons/chest_artifact/map_chest_artifact_alpha.png`,
  `docs/design/references/map_icons/chest_artifact/map_chest_artifact_alpha_report.json`,
  `docs/design/previews/map_chest_artifact_contact_sheet.png`.
- Independent PIL audit of the runtime icon: 128x128 RGBA, alpha extrema `[0, 255]`,
  alpha bbox `[7, 12, 121, 116]`, edge alpha max `0`, safe padding
  left/top/right/bottom `7/12/7/12`, visible pixels `7794`.
- Matte/spill audit: white-like pixels with alpha > 8 = `0`, partial-alpha white-like
  pixels = `0`, green spill pixels with alpha > 8 = `0`.
- Visual QA: icon is not clipped, reads as a treasure/artifact chest, and remains
  readable at 64/40/32 px on a dark route-map-like background.
- Comparison QA: visually distinct from existing battle skull, event question,
  shop tent and rest campfire route icons.

Scope note: no route-map runtime logic, chest event logic, gameplay, balance,
`scripts/route_map_screen.gd`, or `tests/runtime_smoke_test.gd` was touched.
