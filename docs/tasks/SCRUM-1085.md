# SCRUM-1085 — Projectile setup visual order regression

Jira: SCRUM-1085
Статус: in_progress
Контур: Codex
Owner: Back-end/Codex
Thread/Worker: `/root/scrum1066_projectile_backend`

## Result

`Projectile.setup()` now reapplies every non-empty canonical visual override
when the node is already inside the scene tree. Pre-tree and post-tree setup
therefore produce identical metadata, texture, scale, rotation offset and trail
palette. Empty overrides preserve the current/default profile. Invalid IDs fail
closed by clearing canonical metadata and sprite state and restoring the neutral
trail, so an old valid sprite cannot masquerade under an invalid ID.

## Verification

- `tests/projectile_setup_visual_order_test.gd` — PASS: pre/post-tree parity for
  Thief smoke bomb and Ranger storm arrow; empty compatibility; invalid
  fail-safe.
- `tests/projectile_visual_registry_test.gd` — PASS (20/31 contract).
- `tests/projectile_smoke_test.gd` — PASS.
- macOS `--export-pack` — PASS; compiled `Projectile.tscn`/script and runtime
  profile data are present.
- `tests/runtime_smoke_test.gd` — PASS (known non-fatal dummy-renderer
  screenshot texture warning only).
