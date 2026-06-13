# Content And Docs Consistency Audit — 2026-06

Дата: 2026-06-13  
Версия аудита: 0.1.5  
Источник: SCRUM-175 / `docs/tasks/audit_content_docs_consistency.md`  
Scope: read-only audit; assets/docs/code were not cleaned or renamed.

## Summary

The canonical docs mostly track the current 17-class / 51-weapon state, but there are concrete drift risks:

- `progression_data.gd` still points several newer class `sprite_path` values at older class art.
- `content_registry.md` and `current_game_state.md` state that final canonical art/cutout rigs are connected for all 17 classes.
- Exact-reference asset scans produce many false positives because dynamic paths and family wildcards are not centrally declared.
- Real cleanup candidates remain, including `.DS_Store`, old placeholder character sprites and legacy enemy duplicates.

## Registry And Code Drift

### P1 — several character configs use older class sprite paths

Evidence in `scripts/progression_data.gd`:

| Character ID | Configured `sprite_path` | Expected from registry/docs |
| --- | --- | --- |
| `thief` | `res://assets/sprites/characters/assassin.png` | `res://assets/sprites/characters/thief.png` |
| `elementalist` | `res://assets/sprites/characters/dark_mage.png` | `res://assets/sprites/characters/elementalist.png` |
| `sniper` | `res://assets/sprites/characters/ranger.png` | `res://assets/sprites/characters/sniper.png` |
| `priest` | `res://assets/sprites/characters/doctor.png` | `res://assets/sprites/characters/priest.png` |
| `biologist` | `res://assets/sprites/characters/chemist.png` | `res://assets/sprites/characters/biologist.png` |
| `engineer` | `res://assets/sprites/characters/druid.png` | `res://assets/sprites/characters/engineer.png` |

Line evidence: `scripts/progression_data.gd:151-205`.

Impact:
- The UI may display older proxy portraits despite final assets existing.
- Docs claim canonical art is connected, but code is not fully aligned.

Recommended task:
- Update character `sprite_path` values and add tests that every `CHARACTER_CONFIGS[id].sprite_path` matches content registry and exists.

### P2 — exact asset reference audit produces expected false positives

Observed rough scan:
- 461 `res://` references.
- 471 asset files.
- 7 "missing" references are directory or pattern references such as `res://assets/sprites/ui/icons/artifacts/artifact_%s.png`.
- 130 assets are not exact-referenced, but many are intentional dynamic assets: artifact icons, shop icons, cutout families, UI kits and generated previews.

Impact:
- Existing cleanup process can be unsafe unless it understands dynamic path patterns and docs-only assets.

Recommended task:
- Extend `tools/audit_unused_assets.py` with:
  - dynamic pattern manifest (`artifact_%s.png`, `shop_%s.png`, cutout families, route icons);
  - docs-only preview allowlist;
  - generated/import sidecar grouping;
  - protected directories from process docs.

### P2 — real cleanup candidates should be isolated, not deleted in audit

Examples from scan:
- `.DS_Store` files under `assets/` and sprite subdirectories.
- old placeholder character sprites: `assassin_placeholder.png`, `chemist_placeholder.png`, `doctor_placeholder.png`, `druid_placeholder.png`, `knight_placeholder.png`, `ranger_placeholder.png`.
- legacy root enemy duplicates: `assets/sprites/enemy_bone_shaman.png`, `enemy_bruiser.png`, `enemy_melee.png`, `enemy_runner.png`, `enemy_shooter.png`, `enemy_summoner.png`.
- legacy `assets/sprites/boss_warden.png`.

Impact:
- These are likely cleanup candidates, but should go through backup-based cleanup task, not this audit.

### P2 — docs split exists but current state is still dense

Evidence:
- `current_game_state.md` contains project overview, UI, characters, weapons, combat, audio, tests and detailed history.
- It already points at system docs, but new feature/task updates still often append to current state.

Impact:
- Readers need domain docs as source of truth. `current_game_state.md` should be a concise index plus deltas, not a full changelog.

Recommended task:
- Run a domain-doc update pass after active 0.1.4 tasks settle:
  - `docs/design/systems/characters_weapons.md`
  - `docs/design/systems/combat.md`
  - `docs/design/systems/progression_economy.md`
  - `docs/design/systems/ui_menus.md`
  - `docs/design/systems/audio.md`

## Proposed Child Tasks

Created in `docs/tasks/`:

1. `backend_content_character_sprite_registry_alignment_task.md`
2. `backend_content_unused_asset_audit_manifest_task.md`
3. `backend_content_safe_cleanup_followup_task.md`
4. `backend_docs_domain_consistency_update_task.md`
