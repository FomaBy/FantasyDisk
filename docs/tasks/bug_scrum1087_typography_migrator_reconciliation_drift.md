# SCRUM-1087 — Typography migrator accepts semantic behavior drift

Статус: new
Версия: 0.2.1
Jira: SCRUM-1087
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Parent QA: SCRUM-1073
Locked paths: `tools/migrate_scrum1073_typography.py`; focused negative tests;
SCRUM-1073 verifier evidence only.

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
