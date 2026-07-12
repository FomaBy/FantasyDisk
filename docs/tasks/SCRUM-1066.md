# SCRUM-1066 — Data-driven player projectile visuals

Jira: SCRUM-1066
Статус: done
Контур: Codex
Owner: Back-end/Codex
Thread/Worker: `/root/scrum1066_projectile_backend`
Branch/worktree: `codex/scrum1066-projectile-backend` at
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1066-projectile-backend`

## Scope

Integrate the accepted SCRUM-1065 manifest into player projectile runtime. No
asset regeneration, PNG edits, balance, targeting, damage, timing, projectile
count, speed, collision or hit geometry changes.

## Runtime contract

- `ProjectileVisualRegistry` reads the export-safe normalized contract at
  `assets/data/projectile_visual_profiles.json`, generated from and regression-
  checked against the accepted 17-class/51-weapon SCRUM-1065 manifest, and
  resolves exactly 20 projectile/projectile-like profiles by `weapon_id`.
- `ClassWeapon`, sentry fire and the deprecated `Projectile.tscn` path consume
  the registry. Canonical weapons never use `void_orb.png` or
  `player_projectile_spark_64.png`.
- Scale, forward orientation, rotation offset, trail and impact palette come
  from the manifest. The sprite transform does not alter hit geometry.
- Missing/invalid IDs fail safe to an empty profile; the procedural fallback is
  retained only for direct dev/test calls without a canonical weapon context.
- All spawned visuals stay in the existing `player_weapon_effects` cleanup
  lifecycle; tracer-only sprites self-release after their short visual flight.

## Verification

Post-rebase gates on fresh `origin/dev`:

- `projectile_visual_registry_test.gd` — PASS: 17/51 inventory, 20 mapped,
  31 intentional non-projectile, source/runtime manifest parity, canonical
  texture selection, forbidden fallback rejection, missing-ID fail-safe and
  orphan cleanup.
- `attack_vfx_smoke_test.gd`, `projectile_smoke_test.gd`,
  `projectile_chain_pierce_identity_test.gd`,
  `unique_weapon_vfx_assets_test.gd` — PASS.
- affected Dark Mage/Doctor/Chemist/Druid/Soldier/Thief/Sniper/Ranger/
  Biologist/Engineer kit tests — PASS.
- `runtime_smoke_weapon_mechanics_test.gd` — PASS.
- `runtime_smoke_test.gd` — PASS (known dummy-renderer screenshot texture
  warning remains non-fatal).
- macOS `--export-pack` — PASS; log confirms
  `res://assets/data/projectile_visual_profiles.json`, compiled registry and
  projectile scenes are included despite the project-wide `docs/*` exclusion.

No source PNG, gameplay config or balance data changed.

Implementation commit: `7fe9191994ac704221b3e17ff7d1d3286500df8d`
on `origin/dev`.

## QA-Вердикт

Статус: PASSED

Independent re-verification on `origin/dev@adc819db4` includes the SCRUM-1085
late-setup regression fix (`1cafb8ad0`): setup-order, visual registry,
projectile smoke and cold import all passed. Jira SCRUM-1066 was accepted on
2026-07-12.
