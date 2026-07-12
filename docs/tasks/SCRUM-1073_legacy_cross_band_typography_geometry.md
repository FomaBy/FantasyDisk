# SCRUM-1073 — Legacy cross-band typography geometry migration

Статус: review
Контур: Codex
Owner: Design/Codex
Thread: /root/scrum1079_route_backend
Jira: SCRUM-1073
Спринт: 0.2.1

Locked paths: exact 139-fingerprint SCRUM-1073 allowlist scope in
`scripts/ui_screens.gd`, `scripts/pause_stats_menu.gd`,
`scripts/route_map_screen.gd`, `scripts/threat_indicators.gd`; typography
inventory/migrator/verifier, focused tests and UI-domain evidence only.

## Result

All 139 locked fingerprints were deterministically migrated into their selected
semantic bands. The schema-3 inventory records every original/replacement pair,
effective before/after ranges and final disposition; no original fingerprint is
live, all 139 replacements are live, and SCRUM-1073 routing is zero. The two
Atlas topology entries remain correctly routed to SCRUM-1068; SCRUM-1070 owns no
inventory site. `scripts/ui_icon_registry.gd` contained no claimed site and was
not changed.

Geometry was reallocated per family instead of lowering typography floors:
Prayer lanes, compact Attribute Shop copy/tooltips, Pause aliases/value reserve,
Codex transformed title lane, Artifact Reward spacing, Shop tooltip band,
Settings Reset focus reveal, Route badge placement and compact Event lower cards.
The 35 sites without prior screen-specific PixelLab coverage use the approved
eight-zone PixelLab contact sheet and content-zone compositor package in
`docs/design/mockups/scrum1073_semantic_band_migration/`.

## Exact scope

The authoritative per-site manifest is the set of 139 `allowlist` entries whose
`next_issue` is `SCRUM-1073` in
`docs/design/mockups/scrum1061_semantic_typography/typography_inventory.json`.
Every entry records a stable 16-character fingerprint, path, function, semantic
role, exact effective range, owner/reason and legacy range contract. Jira
SCRUM-1073 contains the same explicit fingerprint/component list. Two
Atlas-canvas entries remain with SCRUM-1068; SCRUM-1070 owns only the Atlas
reset-footer button and no current inventory entry.

## Required change

- Use `fantasydisk-ui-director` for each affected screen family and preserve
  PixelLab frame content zones.
- Migrate each listed cross-band contract into its selected semantic band by
  adapting layout, wrapping, scrolling, responsive geometry or component size;
  never lower native token floors.
- Update the fingerprint inventory and record the final disposition of every
  site, including any replacement fingerprint created by a source edit.
- Verify the six-size no-overlap matrix, keyboard/gamepad flows, focused screen
  tests and full runtime smoke before routing to independent QA.

## Acceptance criteria

- All 139 listed sites are removed from the cross-band allowlist or replaced by
  reviewed in-band fingerprints.
- Inventory reports zero unreviewed sites and no false SCRUM-1068/1070 routing.
- Text remains readable and inside empty frame zones at 1152×648, 1280×720,
  1600×900, 1920×1080, 2048×1152 and 2560×1440, including live resize.
- Jira, this mirror and UI-domain docs contain per-site result and QA evidence.

## Verification

- inventory generator/check: PASS (`245` total, `243` mapped, `2` SCRUM-1068
  allowlist, `0` unreviewed, `0` SCRUM-1073);
- deterministic migration idempotence: PASS (`139/139`);
- semantic typography tier test: PASS at 648/720/900/1080/1152/2K/4K;
- UI no-overlap matrix: PASS at 1152×648, 1280×720, 1600×900, 1920×1080,
  2048×1152 and 2560×1440;
- focused Prayer, Attribute Shop, Pause dossier, Settings, Hero Select, Codex,
  Artifact Reward, Shop, Route Map, Victory and End Run gates: PASS;
- compact Event windowed exact-rect/containment gate and captures: PASS at
  1152×648 and 1280×720;
- runtime UI smoke and full runtime smoke: PASS.
