# SCRUM-1073 — Legacy cross-band typography geometry migration

Статус: new
Контур: Codex
Owner: unassigned
Thread: n/a
Jira: SCRUM-1073
Спринт: 0.2.1

## Coordination

This follow-up stays unassigned and does not lock any path until SCRUM-1061 is
landed in `origin/dev` and releases its typography locks. The future claimant
must pull current `dev`, re-audit live owners and claim a non-overlapping screen
slice before editing. Planned scope includes typography geometry in
`scripts/ui_screens.gd`, `scripts/pause_stats_menu.gd`,
`scripts/route_map_screen.gd`, `scripts/threat_indicators.gd` and
`scripts/ui_icon_registry.gd`.

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
