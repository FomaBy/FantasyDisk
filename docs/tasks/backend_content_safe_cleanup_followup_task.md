# Back-end Task: Safe Cleanup Follow-up For Legacy Asset Candidates

Статус: done (2026-06-13, Claude Fable 5)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-193
Эпик: epic_full_project_quality_pass

## Scope

Review and safely move likely unused legacy assets after the dynamic asset manifest task is complete.

## Candidate Groups

- `.DS_Store` under assets.
- old `*_placeholder.png` character sprites.
- legacy root enemy duplicates under `assets/sprites/`.
- legacy `assets/sprites/boss_warden.png`.

## Requirements

- No irreversible delete.
- Tracked candidates use `git rm` only after backup.
- Untracked candidates move to backup.
- Runtime and animation smoke pass after cleanup.

## Dependency

Blocked until `backend_content_unused_asset_audit_manifest_task.md` is done.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress. Sequence after `backend_content_unused_asset_audit_manifest_task.md`.

## Design Handoff Update (SCRUM-183, 2026-06-13)

Design audit/spec completed in `docs/design/reviews/legacy_sprite_cleanup_spec_2026_06.md`.

Design confirms these groups are visually obsolete and safe to treat as cleanup candidates after Back-end reference/runtime checks:

- old `assets/sprites/characters/*_placeholder.png` files for Assassin/Chemist/Doctor/Druid/Knight/Ranger;
- root prototype player sprites `assets/sprites/player_berserk.png`, `player_ranger.png`, `player_summoner.png`;
- root prototype enemy duplicates `assets/sprites/enemy_bone_shaman.png`, `enemy_bruiser.png`, `enemy_melee.png`, `enemy_runner.png`, `enemy_shooter.png`, `enemy_summoner.png`;
- legacy root `assets/sprites/boss_warden.png`.

Explicit keep list from Design:

- `assets/sprites/characters/berserk_walk_sheet_v2.png` remains live via `scripts/player.gd`;
- `assets/sprites/projectiles/enemy_projectile_magic_64.png` remains live via `scenes/EnemyProjectile.tscn`;
- `assets/sprites/enemies/*.png` remains active runtime/codex/rig source.

No deletion or move was performed by Design.

## Blocked (2026-06-13)

Blocked for a clean cleanup window. The prerequisite manifest task SCRUM-194 is
done, but the workspace currently contains active/rejected SCRUM-147 UI asset
iteration files and refreshed UI frame assets. Because this task moves/removes
tracked asset candidates with backup, executing it during visual-kit churn risks
mixing cleanup with unrelated Design changes.

Next unblock: run after SCRUM-147/SCRUM-222 UI asset dependency is accepted or
the asset worktree is clean enough to produce an isolated backup/removal diff.
No files were moved or deleted by this task.

## PM Override / Redispatch (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Redispatch в существующий Back-end thread
`019eabd9-780b-78a2-9f4b-e7203d659ef2` как последовательный queue item после
SCRUM-230, SCRUM-198 и SCRUM-199. Keep reasoning High/no low. Выполнять только
как безопасный cleanup: без необратимого удаления, с backup/manifest checks,
после закрытия/синхронизации предыдущих queued задач, чтобы diff был
изолированным.

## Done (2026-06-13, Claude)

Удалено 10 корневых legacy-прототипных спрайтов + их `.import` сайдкары (20
файлов) + 5 `.DS_Store`, с бэкапом в `build/cleanup_backup_2026_06_13/`
(необратимого удаления нет):
`player_berserk/ranger/summoner`, `enemy_bone_shaman/bruiser/melee/runner/
shooter/summoner`, `boss_warden` — каждый верифицирован как 0 рантайм-ссылок
(только генератор `generate_prototype_sprites.py`). Коммит `88304f41`.

Соответствует Design-списку SCRUM-183. Keep-лист соблюдён: живые
`assets/sprites/enemies/*.png` (Enemy.tscn/codex/риг-манифест), новые боссы/
мини-элитки, иконки артефактов — НЕ тронуты. Placeholder-спрайты персонажей
из спеки уже отсутствовали (удалены ранее).

ВАЖНО: чистка шла по верифицированному Design-списку, НЕ по сырому аудиту —
аудит после сплита `progression_data` (SCRUM-198) даёт ложные срабатывания
(флагует артефакт-иконки/новых боссов как unused). `known_game_ids()` аудита
требует обновления под доменные файлы (отдельный воркер уже правит
`tools/audit_unused_assets.py`).

Верифицировано: `runtime_smoke` + `animation_smoke` + `content_registry`
зелёные после удаления.

## Back-end Follow-up Verification (2026-06-13, Codex)

Проверен итог cleanup после SCRUM-198/SCRUM-199: старые placeholder-кандидаты
персонажей из SCRUM-183 отсутствуют в активной папке
`assets/sprites/characters/`, backup-копии лежат в
`build/cleanup_backup_2026_06_13/assets/sprites/characters/`.

Аудит ассетов готов к split-данным SCRUM-198: `tools/audit_unused_assets.py`
считывает `scripts/progression_data_*` domain files, защищает
`build/cleanup_backup_2026_06_13/` и больше не флагает динамические artifact/shop
семейства как мусор. Оставшиеся raw candidates (новые boss/mini-elite/weapon
PNG и временные файлы) не удалялись в SCRUM-193, потому что это не legacy
root/placeholder cleanup и требует отдельной content-integration проверки.

Отчет: `docs/process/content_safe_cleanup_report_2026_06_13.md`.

Проверки:
- `python3 tools/test_audit_unused_assets.py` — passed.
- `python3 tools/audit_unused_assets.py` — report generated, 35 conservative candidates.
- `tests/animation_smoke_test.gd` — passed.
- `tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 361e45c7 (ветка dev)

Проверено (фактически):
- **Обратимость**: бэкап `build/cleanup_backup_2026_06_13/` — 26 файлов
  (удалённые PNG/.import + `.DS_Store`); необратимого удаления нет, всё
  восстановимо. Отчёт `content_safe_cleanup_report_2026_06_13.md` на месте.
- **Нет битых ссылок** (acceptance): `content_registry_consistency_test` — passed
  **0 allowlisted** (ни одной отсутствующей/осиротевшей ссылки); `animation_smoke`
  + `runtime_smoke_*` зелёные после удаления.
- **Проверка моей находки SCRUM-183**: `boss_warden.png` удалён и забэкаплен;
  alias `cutout_rig_2d.gd:26 "boss_warden"→"rift_warden"` остался, но это
  строковый key-мапинг (не PNG-load) — поломки нет (подтверждено зелёным
  content_registry + smoke). Находка отработана корректно.
- **`generate_prototype_sprites.py`** — это ручной legacy-генератор (не рантайм-
  потребитель); удалённые файлы он не регенерит автоматически. Безопасно.

Acceptance:
- [x] Tracked-кандидаты — `git rm` только после backup; untracked → backup.
- [x] Runtime + animation smoke зелёные после cleanup; content registry чист.

Баги: нет.
