# FantasyDisk Content Safe Cleanup Follow-up — 2026-06-13

Task: `docs/tasks/backend_content_safe_cleanup_followup_task.md` / SCRUM-193.

## Scope

This follow-up verifies the 2026-06-13 legacy asset cleanup after the 0.1.4
data/UI refactors and keeps the cleanup conservative:

- no irreversible deletion;
- all removed legacy assets have backup copies in `build/cleanup_backup_2026_06_13/`;
- live runtime folders, Design previews, tests, tools, docs, releases and QA
  artifacts stay protected;
- cleanup decisions use the SCRUM-183 Design-safe list plus runtime reference
  checks, not raw audit output alone.

## Verified Removed Or Already Absent

The previous SCRUM-193 cleanup removed root prototype sprites and `.DS_Store`
files with backup:

- `player_berserk.png`, `player_ranger.png`, `player_summoner.png`;
- `enemy_bone_shaman.png`, `enemy_bruiser.png`, `enemy_melee.png`,
  `enemy_runner.png`, `enemy_shooter.png`, `enemy_summoner.png`;
- `boss_warden.png`;
- five `.DS_Store` files under `assets/`.

The old character placeholder candidates from the SCRUM-183 list are also
absent from active runtime folders, with backup copies present:

- `assets/sprites/characters/assassin_placeholder.png`;
- `assets/sprites/characters/chemist_placeholder.png`;
- `assets/sprites/characters/doctor_placeholder.png`;
- `assets/sprites/characters/druid_placeholder.png`;
- `assets/sprites/characters/knight_placeholder.png`;
- `assets/sprites/characters/ranger_placeholder.png`;
- the paired `.import` files for each placeholder.

Canonical live character art remains in `assets/sprites/characters/<class>.png`
and cutout rig parts remain under `assets/sprites/characters/cutout/`.

## Audit Tool State

`tools/audit_unused_assets.py` now scans the split ProgressionData domain files
introduced by SCRUM-198:

- `scripts/progression_data_characters.gd`;
- `scripts/progression_data_weapons.gd`;
- `scripts/progression_data_content.gd`;
- `scripts/progression_data_shop.gd`;
- `scripts/progression_data_ascension.gd`;
- `scripts/progression_data_enemies.gd`.

The audit target is `build/cleanup_backup_2026_06_13/`, and that backup folder
is protected from follow-up cleanup scans.

The current raw audit still reports some weapon, boss and mini-elite PNGs as
unused because those source sprites are tied to pending/runtime integration
paths. They were intentionally not removed by SCRUM-193.

## Verification

Passed:

```text
python3 tools/test_audit_unused_assets.py
Asset audit self-test passed (проверено 984, динамических защищено 291, кандидатов 35, отчёт build/asset_audit_manifest.md).

python3 tools/audit_unused_assets.py
Всего проверено файлов: 984; кандидатов: 35; dynamic keep: 289; explicit keep: 2

/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
Animation smoke test passed.

/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
Runtime smoke test passed.
```

