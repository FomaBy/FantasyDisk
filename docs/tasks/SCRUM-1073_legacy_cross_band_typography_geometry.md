# SCRUM-1073 — Legacy cross-band typography geometry migration

Статус: done
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

- inventory generator/check: PASS (`246` total, `244` mapped, `2` SCRUM-1068
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

## Historical QA verdict (2026-07-12, independent QA) — FAILED

Статус: FAILED

Independent QA on fresh `origin/dev@7a69a7712704efc33a0726aa606af63f23db7f8e`
confirmed the delivered UI/source evidence but found a blocking weakness in the
mandatory migration verifier.

Passed before the blocker:

- `tools/typography_inventory.py --check`: current; schema 3 records `246`
  total / `244` mapped / `2` truthful SCRUM-1068 allowlist / `0` unreviewed /
  `0` routed SCRUM-1073, with `139` unique original/replacement pairs;
- clean-tree migrator idempotence and replacement liveness: PASS;
- post-rebase main-menu version captions remain separate `semantic_native`
  mappings; SCRUM-1070 owns no inventory site;
- live PixelLab MCP provenance for approved `6e512c63-5c42-44ee-a6b3-09a3ed69189d`
  and rejected `c60357ee-05ee-43bd-939c-a8ece7c82ef5` is accurate and
  byte-identical to the committed files;
- planning/compositor recheck: `ready_for_image`, `8/8` zones, deterministic
  composite/debug output; visual 1152×648 and 1280×720 Event screenshots remain
  readable and frame-safe;
- the four locked runtime scripts match their pre-task `>220`-character line
  counts and contain no nested `resolve_fixed` or deprecated `clamp_to_role`.

Blocking negative control:

`tools/migrate_scrum1073_typography.py::_reconcile_format_only_fingerprints()`
accepted a same-group replacement that removed the semantic resolver and role
literal entirely (`add_theme_font_size_override("font_size", 1)`). It returned
`true`, copied the old `role: action` / `status: mapped`, and rewrote the
migration replacement fingerprint. Therefore the claimed fingerprint-first
gate can silently bless behavioral drift and print PASS; no negative regression
test covers this path.

Linked current-sprint bug: SCRUM-1087, which blocks this issue. SCRUM-1073 stays
in `Контроль качества` until the verifier fails closed, receives negative drift
tests, and independent re-QA passes. The remaining expensive runtime matrix was
not repeated after this deterministic acceptance blocker was confirmed.

Disk cleanup: pending removal of the disposable QA worktree and `/tmp` evidence
after Jira/mirror sync is pushed.

## QA-Вердикт (2026-07-12, independent combined re-QA) — PASSED

Статус: PASSED

Re-QA on fresh `origin/dev@0dc31f79dc94fa575489ace823f7e21a1bcef7a0`
confirmed that SCRUM-1087 closes the only blocking verifier weakness without
changing runtime UI files.

- original same-group/order `font_size = 1` drift now fails closed with
  `refusing to rewrite`; the manifest remains byte- and SHA-identical;
- SCRUM-1087 focused Python suite: `9/9` PASS, covering numeric/exponent drift,
  missing role/resolver, changed call/control, adjacency-sensitive forms,
  spoofed fingerprints, ordering and whitespace-only positive reconciliation;
- independent transactional negatives confirmed validation failure and a late
  multi-entry mismatch cannot commit earlier candidate changes; migration
  replacement fingerprints update only after complete token equivalence;
- inventory and migrator twice: PASS and byte-identical; schema 3 remains `246`
  total / `244` mapped / `2` truthful SCRUM-1068 allowlist / `0` unreviewed /
  `0` routed SCRUM-1073, with `139/139` unique replacements live and originals
  absent;
- live PixelLab provenance remains byte-identical for approved `6e512c63` and
  rejected `c60357ee`; planning/compositor is deterministic and `8/8`;
- compact Event 1152×648 and 1280×720 evidence remains readable, contained and
  frame-safe;
- semantic typography, six-tier no-overlap including 2048×1152, gamepad
  full-flow, runtime UI and full runtime smoke all PASS on Godot 4.7; only the
  known non-fatal dummy-renderer screenshot warning appeared.

SCRUM-1073 and linked SCRUM-1087 may transition to `Готово`.

Disk cleanup: pending removal of disposable re-QA worktree, `.godot` and
`/tmp/fsd_qa_scrum1087` after the verdict/sync commits are pushed.
