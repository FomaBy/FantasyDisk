# SCRUM-1087 — Typography migrator accepts semantic behavior drift

Статус: done
Версия: 0.2.1
Jira: SCRUM-1087
Контур: Codex
Owner: Backend/Codex
Thread/Worker: `/root/scrum1079_route_backend`
Parent QA: SCRUM-1073
Locked paths: `tools/migrate_scrum1073_typography.py`;
`tests/test_scrum1087_migrator_fail_closed.py`; this mirror; scoped Jira sync
metadata only.

## Context / problem

The SCRUM-1073 fingerprint verifier treats same path/function/kind cardinality
and line order as sufficient for format-only reconciliation. A source change
that removes the semantic resolver and role can therefore inherit the previous
reviewed mapping and replacement fingerprint.

## Reproduction

Call `_reconcile_format_only_fingerprints()` with one reviewed action-role
entry, then provide a current entry in the same group/order whose source is
`add_theme_font_size_override("font_size", 1)`. The function returns `true`,
copies the old role/status/effective bounds and rewrites the migration
replacement fingerprint instead of rejecting the behavior drift.

## Acceptance criteria

- reconciliation fails closed for changed values/control expressions, removed
  resolvers and missing expected role literals;
- accepted formatting-only drift is proven token/AST equivalent, or any
  fingerprint change is rejected;
- negative tests cover a literal `font_size = 1`, removed role/resolver and a
  changed call/control; a positive whitespace-only reformat remains accepted;
- the existing `139/139` original/replacement audit and clean-tree idempotence
  remain green;
- SCRUM-1073 receives independent re-QA after the fix lands.

Disk cleanup: no bug-implementation cache or worktree created by QA.

## Backend result

- Replaced line-order/role-hint reconciliation with a fail-closed comparison
  that accepts only token-equivalent GDScript expressions.
- Preserved adjacency-sensitive numbers, operators, StringName/NodePath
  prefixes, node paths, unique-node references and annotations; only
  leading/trailing and delimiter-adjacent formatting whitespace is ignored.
- Made manifest reconciliation transactional: reviewed metadata and migration
  fingerprints are written only after the complete candidate passes inventory
  validation. Semantic drift leaves the manifest bytes unchanged.
- Added focused negative coverage for literal, resolver, role, control/call,
  ordering, fingerprint-spoof and exponent-splitting drift, plus the required
  positive whitespace-only reflow case.
- Runtime UI files were not changed.

## Verification

- `python3 -m unittest -v tests.test_scrum1087_migrator_fail_closed` — PASS
  (`9/9`).
- `python3 tools/typography_inventory.py --check` — PASS.
- `python3 tools/migrate_scrum1073_typography.py --check` twice — PASS and
  idempotent.
- `python3 tools/godot_gate.py --headless --path . --script
  res://tests/semantic_typography_scrum1061_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script
  res://tests/runtime_smoke_test.gd` — PASS.

Disk cleanup: generated Godot import sidecars, disposable `.godot/` cache and
isolated `/tmp/fsd-scrum1087-*` userdata removed before handoff.
