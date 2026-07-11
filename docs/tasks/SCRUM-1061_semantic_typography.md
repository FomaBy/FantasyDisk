# SCRUM-1061 — Semantic typography

Статус: in_progress
Контур: Codex
Owner: /root/scrum1061_semantic_typography
Thread: /root/scrum1061_semantic_typography
Jira: SCRUM-1061
Branch: `codex/scrum1061-semantic-typography`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1061-semantic-typography`

## Locked paths

- `scripts/ui/semantic_typography.gd`;
- typography-only hunks in `scripts/ui_screens.gd`, route-map, pause dossier,
  global tooltip, toast, threat indicator, player/enemy feedback and HUD;
- SCRUM-1061 spec/inventory/tests/docs.

Excluded: SCRUM-1062 Continue Run geometry; Atlas topology owned by SCRUM-1068;
Atlas reset-footer owned by SCRUM-1070; the 139-site legacy cross-band geometry
follow-up SCRUM-1073; new art/assets.

## UI Director package

- Contact sheet:
  `docs/design/mockups/scrum1061_semantic_typography/accepted_frames_contact_sheet.png`.
- Geometry/spec: `docs/design/mockups/scrum1061_semantic_typography/spec.md`.
- Token/overflow contract:
  `docs/design/mockups/scrum1061_semantic_typography/token_contract.md`.
- Inventory:
  `docs/design/mockups/scrum1061_semantic_typography/typography_inventory.json`.
- Accepted PixelLab source screens are reused; no new art generation and no
  frame/content-zone changes.

## Result in progress

- canonical 12-role semantic typography API implemented;
- route-map duplicate formula removed;
- readable/Settings/Codex/pause compatibility helpers delegate centrally;
- tooltips, toast, threat/world feedback and raw HUD routed centrally;
- stable fingerprint inventory and Russian/token matrix test added.
- all runtime compatibility helper calls carry an explicit semantic role;
  schema-2 inventory records exact reviewed bounds for 245 sites (104 in-band,
  141 accepted cross-band allowlist contracts) without weakening native tokens.
- allowlist routing is truthful: two Atlas-canvas fingerprints route to
  SCRUM-1068 and the exact remaining 139-site manifest routes to the dedicated,
  unassigned current-sprint follow-up SCRUM-1073; SCRUM-1070 owns no inventory
  fingerprint.

Final commit/tests/Jira routing are recorded after the full gate.
