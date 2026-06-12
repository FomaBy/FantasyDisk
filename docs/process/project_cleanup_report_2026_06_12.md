# FantasyDisk Project Cleanup Report — 2026-06-12

## Scope

Back-end cleanup task: `docs/tasks/backend_project_folder_cleanup_unused_files_task.md`.

Branch: `dev`.

Backup directory: `build/cleanup_backup_2026_06_12/`.

The cleanup was intentionally conservative. Protected development areas were not used as cleanup candidates: `docs/**`, `tools/*`, `tests/**`, `source_docs/**`, `releases/**`, `.claude/**`, `keep-awake.sh`, `build/qa/`.

## Audit Tool

Updated `tools/audit_unused_assets.py`:

- Uses the dated backup target `build/cleanup_backup_2026_06_12/`.
- Ignores protected development folders and the current backup folder.
- Keeps dynamic runtime folders:
  - `assets/sprites/*/cutout/`
  - `assets/sprites/map_icons/`
  - `assets/sprites/ui/cursor/`
  - `assets/sprites/ui/frames/`
  - `assets/sprites/ui/shop/`
- Validates dynamic artifact/shop icon naming against IDs from `scripts/progression_data.gd` and `scripts/event_data.gd`.
- Detects orphan `.import` / `.uid` files.
- Avoids counting references inside the audit script itself as runtime usage.

Last audit summary before cleanup:

```text
Всего проверено файлов: 764; кандидатов: 16; dynamic keep: 203; explicit keep: 2
```

## Moved Files

All files below were copied or moved to `build/cleanup_backup_2026_06_12/` with the same relative path.

| Path | Category | Reason |
| --- | --- | --- |
| `.DS_Store` | temporary_file | macOS workspace metadata |
| `.keep-awake.sh.swp` | temporary_file | editor swap file, not `keep-awake.sh` |
| `assets/.DS_Store` | temporary_file | macOS workspace metadata |
| `assets/sprites/.DS_Store` | temporary_file | macOS workspace metadata |
| `assets/sprites/bosses/.DS_Store` | temporary_file | macOS workspace metadata |
| `assets/sprites/effects/effects_dnd_preview.png` | art_iteration_preview | Design QA contact sheet; not loaded at runtime |
| `assets/sprites/effects/effects_dnd_preview.png.import` | orphan_import | import pair for moved preview sheet |
| `assets/sprites/enemies/.DS_Store` | temporary_file | macOS workspace metadata |
| `assets/sprites/ui/.DS_Store` | temporary_file | macOS workspace metadata |
| `assets/sprites/ui/frames/.DS_Store` | temporary_file | macOS workspace metadata |
| `assets/sprites/ui/icons/.DS_Store` | temporary_file | macOS workspace metadata |
| `assets/sprites/ui/icons/artifact_realistic_dnd_source_contact.png` | art_iteration_source | old artifact source/contact sheet after icon iterations; not loaded at runtime |
| `assets/sprites/ui/icons/artifact_realistic_dnd_source_contact.png.import` | import_pair | import pair for moved source/contact sheet |
| `assets/sprites/visual_redesign_preview.png` | registry_obsolete | listed as obsolete in `content_registry`; not loaded at runtime |
| `assets/sprites/visual_redesign_preview.png.import` | import_pair | import pair for moved obsolete preview |
| `build/.DS_Store` | temporary_file | macOS workspace metadata |
| `build/dmg/.DS_Store` | temporary_file | macOS workspace metadata |
| `build/macos_app/.DS_Store` | temporary_file | macOS workspace metadata |
| `build/unused_assets_backup/assets/.DS_Store` | temporary_file | leftover metadata inside old cleanup backup |

Tracked candidates removed with `git rm` after backup:

- `assets/sprites/ui/icons/artifact_realistic_dnd_source_contact.png`
- `assets/sprites/ui/icons/artifact_realistic_dnd_source_contact.png.import`
- `assets/sprites/visual_redesign_preview.png`
- `assets/sprites/visual_redesign_preview.png.import`

Untracked candidates were moved directly to backup.

Note: `assets/.DS_Store` and `assets/sprites/.DS_Store` can be regenerated immediately by macOS/workspace indexing. They are untracked and have backup copies. They may reappear locally without affecting Godot or git state.

## Content Registry Cross-Check

Removed files are not canonical runtime entities:

- `assets/sprites/visual_redesign_preview.png` was already documented as obsolete in `docs/design/content_registry.md`.
- `effects_dnd_preview.png` was a QA contact sheet, not a VFX runtime sprite.
- `artifact_realistic_dnd_source_contact.png` was an intermediate artifact source/contact sheet; active artifact icons remain under `assets/sprites/ui/icons/artifacts/artifact_<id>.png` and are checked against `ProgressionData.ARTIFACTS`.

Kept dynamic/runtime assets:

- 203 dynamic files were kept by the updated audit.
- Active artifact/shop icons remain covered by canonical IDs.
- Cutout rig parts remain covered by `scripts/sliced_rig_manifest.gd`.
- Active map icons, UI frames, shop visuals and cursor assets remain in place.

No orphan `.import` or `.uid` files remained in runtime folders after moving the preview import pair.

## Missing Resource Fix

The cleanup audit found two active backgrounds missing from the working tree while still referenced by `scripts/main.gd`, `docs/design/content_registry.md` and `docs/design/current_game_state.md`:

- `assets/backgrounds/field_dry_road.png`
- `assets/backgrounds/field_stone_garden.png`

Both were restored from `build/bg_backup/` and their `.import` files were restored so Godot does not start with missing background resources.

## Verification

Passed:

```text
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
Runtime smoke test passed.

/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
Animation smoke test passed.

/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/attack_vfx_smoke_test.gd
Attack VFX smoke test passed.

/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/hazard_vfx_smoke_test.gd
Hazard VFX smoke test passed.

/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/meta_progression_smoke_test.gd
Meta progression smoke test passed.
```

Godot editor import was run after restoring `field_dry_road.png` and `field_stone_garden.png`; both backgrounds were reimported successfully.

Windowed launch:

```text
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --path /Users/sergeyfomin/Documents/AI\ Agent --quit-after 8
Exit code: 0
No missing resources, no texture/resource leak errors in final run.
```

Additional debug cleanup performed while verifying:

- `scripts/main.gd` now clears custom cursor textures and the runtime texture cache on shutdown.
- `scripts/audio_manager.gd` now stops and detaches audio streams on shutdown, preventing exit-time `music_menu.wav` resource leak spam.

## Дополнение 2026-06-12: вынос артефактных preview-итераций (категория #2)

QA нашёл (`bug_cleanup_artifact_iteration_previews_left_in_assets_task.md`), что первый проход чистки НЕ вынес старые preview-листы арт-итераций — аудит считал их «используемыми», потому что на их путь ссылаются `tools/`-генераторы (output-путь, а не runtime-usage).

Вынесено в `build/cleanup_backup_2026_06_12/` (10 файлов + парные `.import`, 0 runtime-ссылок):

- `assets/sprites/ui/icons/artifact_concept_cut_preview.png`
- `assets/sprites/ui/icons/artifact_dark_artifacts_40px_preview.png`
- `assets/sprites/ui/icons/artifact_dark_fantasy_40px_preview.png`
- `assets/sprites/ui/icons/artifact_final_dark_fantasy_40px_preview.png`
- `assets/sprites/ui/icons/artifact_generated_concept_40px_preview.png`
- `assets/sprites/ui/icons/artifact_per_item_preview.png`
- `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png`
- `assets/sprites/ui/icons/artifact_rpg_40px_preview.png`
- `assets/sprites/ui/icons/artifact_shop_cursor_preview.png`
- `assets/reference/artifact_concept_sheet.png`

Логика аудита починена (`tools/audit_unused_assets.py`): для файлов с паттернами `preview/_source/contact/concept` ссылка из `tools/`-генератора больше не считается runtime-использованием — проверяется только runtime-source (scenes/scripts/tests/project.godot/export_presets) через `collect_runtime_source_text()`. Категория кандидата — `art_iteration_leftover`.

### Оставлено осознанно (раздел расхождений)

- `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png` — задокументированный design-reference в `docs/design/escape_stats_visual_kit.md` («design reference, not required at runtime»), в whitelist аудита `KEEP_FILES`. Не runtime-ассет, но осознанно сохранён как референс.
- `assets/sprites/characters/berserk_walk_sheet_v2.png` — ЖИВОЙ ассет (`player.gd` preload анимации берсерка), к preview не относится, не трогался.
- Остаточный риск: `tools/`-генераторы артефактных иконок по-прежнему пишут preview в `assets/` при повторном запуске. На будущее — при доработке генераторов выводить preview в `docs/design/previews/` или `build/`. На текущем дереве previews вынесены, повторный аудит флагает только `.DS_Store`.

Проверка: import + runtime smoke зелёные, missing-текстур нет.
