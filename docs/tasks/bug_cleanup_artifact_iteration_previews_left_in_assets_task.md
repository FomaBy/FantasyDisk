# BUG: Чистка проекта не вынесла старые artifact-preview итерации из assets/ (категория #2 не закрыта)

Статус: done 2026-06-12. Вынесено 10 preview/concept файлов арт-итераций (+ парные .import, 0 runtime-ссылок) в build/cleanup_backup_2026_06_12/. Починена логика аудита (tools/audit_unused_assets.py): для preview/_source/contact/concept ссылка из tools/-генератора (output-путь) больше не считается runtime-usage — проверяется отдельный collect_runtime_source_text() без tools/. escape_stats_visual_kit_preview оставлен осознанно (документированный design-reference, whitelist), berserk_walk_sheet_v2 не трогался (живой ассет). Отчёт project_cleanup_report_2026_06_12.md дополнен разделом расхождений (вынесенное + оставленное + остаточный риск повторной генерации). Проверка: повторный аудит флагает только .DS_Store, import+runtime smoke зелёные.
Приоритет: normal
Роль: Back-end
Jira: SCRUM-63
Найдено QA при тестировании: `docs/tasks/qa_review_backend_project_folder_cleanup_unused_files_task.md`
(исходная фича: `docs/tasks/backend_project_folder_cleanup_unused_files_task.md`)

## Воспроизведение
1. `find assets -iname "*preview*" -o -iname "*_source*" -o -iname "*contact*"`.
2. В `assets/sprites/ui/icons/` остаются preview-листы разных проходов арта:
   `artifact_concept_cut_preview.png`, `artifact_dark_fantasy_40px_preview.png`,
   `artifact_final_dark_fantasy_40px_preview.png`,
   `artifact_generated_concept_40px_preview.png`, `artifact_rpg_40px_preview.png`,
   `artifact_per_item_preview.png`, `artifact_realistic_dnd_preview.png`,
   `artifact_shop_cursor_preview.png`, `artifact_dark_artifacts_40px_preview.png`
   (+ парные `.import`). Также `assets/reference/artifact_concept_sheet.png` и
   `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png`.
3. Ни один из них не грузится игрой: `grep` по `scripts/`+`scenes/`+`project.godot`
   даёт ссылки только из `tools/` (скрипты-генераторы, для которых это выходной
   путь), либо из whitelist аудита (`tools/audit_unused_assets.py:60-63`).

## Ожидание / Реальность
- Ожидание (категория #2 + критерий «старых превью в assets/ нет»): старые
  превью/контрольные листы арт-итераций (`artifact_*_preview.png` разных проходов)
  вынесены в `build/cleanup_backup_2026_06_12/` или `docs/design/previews/`.
- Реальность: они остались в `assets/`. Причина — `tools/audit_unused_assets.py`
  считает файл «используемым», если на его путь ссылается ЛЮБОЙ `tools/`-скрипт
  (генератор как output). Поэтому аудит их не флагует (текущий прогон: «кандитатов: 3»
  — только `.DS_Store`). Отчёт `project_cleanup_report_2026_06_12.md` эти оставленные
  превью в разделе расхождений не объясняет.

## Влияние
Безопасность чистки НЕ нарушена (игра грузится, бэкап цел, осиротевших .import/.uid
нет). Но это bloat арт-итераций, который шипится в assets/ и прямо нарушает явный
acceptance-критерий «старых превью в assets/ нет». ~9 артефактных preview-проходов
дублируют функцию (dark_fantasy → final_dark_fantasy → rpg → realistic_dnd → …),
актуальные иконки живут отдельно в `assets/sprites/ui/icons/artifacts/artifact_<id>.png`.

## Предлагаемое направление фикса (для исполнителя)
1. Перенести перечисленные `artifact_*_preview.png` (+`.import`), `artifact_concept_sheet.png`
   и при ненадобности `escape_stats_visual_kit_preview.png` в backup/`docs/design/previews/`.
   (`berserk_walk_sheet_v2.png` НЕ трогать — это живой ассет, `player.gd:12` preload.)
2. Починить логику аудита: не считать ссылку из `tools/`-генератора (output-путь)
   за runtime-usage для `*_preview*`/`*_contact*`/`*_source*` файлов — либо вынести их
   в `FORCE_UNUSED`.
3. Дописать в отчёт раздел расхождений (что оставлено осознанно и почему).

## Окружение
Godot 4.6.3.stable. Чистка закоммичена в 8913860 (dev). macOS.
