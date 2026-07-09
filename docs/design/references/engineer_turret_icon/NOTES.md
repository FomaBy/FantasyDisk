# SCRUM-904 — Engineer sentry wrench icon → turret visual

## Runtime asset
- Path (unchanged, replaced in place): `assets/sprites/weapons/engineer_sentry_wrench.png`
- Size: 256×256 RGBA, transparent background (border flood-fill alpha cleanup), same `.import` reused.
- Internal id `engineer_sentry_wrench` and all data untouched (save compatibility).

## Display name recommendation
- Current title in `scripts/progression_data_weapons.gd`: «Ключ Часового».
- Recommended: **«Часовая турель»** (alt: «Турель часового») — matches the turret-deployment gameplay.
- Backend keeps internal id `engineer_sentry_wrench`; title change is a separate content edit.

## Generation (PixelLab MCP, create_map_object)
- Chosen: `9c3d207c-2492-4ec0-b95d-b0004aa2356c` (`turret_v2_cannon.png`) — brass cannon turret
  on tripod, rhymes with `assets/sprites/weapons/engineer_turret/sentry_turret.png` silhouette.
  Prompt: "ornate dark fantasy sentry turret, automated ballista-like brass cannon on three iron
  tripod legs, steampunk engineer contraption with glowing turquoise crystal core, bronze barrel
  with rivets and gears, item icon, no text, transparent background"; 256×256, low top-down,
  high detail, detailed shading, selective outline.
- Rejected alt: `8f7bb01c-2c1c-4ed3-a3ed-18b89920ee90` (`turret_v1_pod.png`) — symmetric
  multi-barrel pod, reads as beacon/lamp at small scale.

## Files here (gdignore zone, no .import)
- `turret_v1_pod.png` / `turret_v2_cannon.png` — raw PixelLab downloads (baked checkerboard bg).
- `turret_v1_pod_alpha.png` / `turret_v2_cannon_alpha.png` — after alpha cleanup.
- `old_wrench_icon.png` — previous runtime icon (wrench) for reference.
- Preview/contact sheet: `docs/design/previews/engineer_sentry_wrench_icon_v2.png`
  (old vs new vs in-game turret sprite ×4, plus 64/48/32 px readability strip).

## Crop/padding
- Content bbox 224×234 within 256×256 (margins ≥11 px) — same occupancy class as neighbor icons
  (wrench 198×220, mines 220×169); no layout/crop issues in weapon select/codex/cards.
