# SCRUM-955 — split Codex Characteristics and Attributes

Статус: done
Версия: 0.2.1
Jira: SCRUM-955
Owner: Codex `/root`
Контур: Codex
Design source: SCRUM-1013 (independent QA PASSED)

## Решение

- `CodexData.characteristics()` projects exactly the eight canonical base
  characteristics in `BASE_STAT_ORDER`.
- `CodexData.attributes()` projects exactly the 26 current derived/build
  attributes in `DERIVED_STAT_ORDER`; `stats()` remains a compatibility
  concatenation for non-UI diagnostics.
- The live rail now has six Russian sections: Персонажи, Монстры, Артефакты,
  Характеристики, Атрибуты, Возвышение.
- Base and derived entries never cross sections. Each uses the canonical icon,
  Russian title/description/influence, semantic chip, structured formula/detail
  text and canonical related-parameter projection.
- The accepted SCRUM-1013 dossier zones are represented by a contained preview
  plus independent related-scroll rail on the left and title/chips/body scroll
  on the right. Both remain inside the empty dark panel interior.
- Raw ids were removed from player-facing character/monster/stat rows and
  chips. The canonical identifiers remain internal data keys only.

## Verification

Passed on Godot 4.7 through `tools/godot_gate.py`:

- `tests/codex_data_smoke_test.gd` — 31 monsters, 17 characters, 161
  artifact/shop rows, 5 ascensions, 8 characteristics, 26 attributes;
- `tests/stat_formulas_smoke_test.gd` — 34 definitions;
- `tests/stat_formulas_derived_sync_test.gd` — 17 classes × 26 attributes;
- `tests/codex_discovery_contract_test.gd`;
- `tests/codex_unlock_tracking_test.gd`;
- `tests/runtime_smoke_ui_test.gd` — six tabs, exact counts and related zones;
- `tests/ui_no_overlap_matrix_test.gd` — full matrix plus split-specific
  1280x720 / 1920x1080 / 2560x1440 gates.
- `tests/display_resolution_test.gd`;
- `tests/dark_fantasy_ui_theme_test.gd`;
- `tests/asset_reference_integrity_test.gd` — 195 files / 2424 references;
- `tests/runtime_smoke_test.gd` — PASSED (the known dummy-renderer null-texture
  screenshot warning remains non-fatal).

Windowed visual QA covered both split sections at 1280×720, 1920×1080 and
2560×1440. It found and fixed two real responsive defects before handoff: the
selected-entry title could collapse to one pixel and the semantic chip could
collapse to a sliver. The final captures show all six Russian tabs, both
independent scroll zones and the dossier rails inside the empty frame interior;
no raw ids or Latin player-facing formulas remain. Capture files were temporary
QA evidence and are intentionally not committed.

The final latest-`origin/dev` verification and commit hashes are recorded in
the Jira implementation handoff. This implementation report is not the final
independent QA verdict.

## QA-Вердикт (2026-07-10, `/root/audit_repo`) — FAILED

Статус: FAILED

Независимая проверка выполнена в отдельном fresh worktree на
`origin/dev@1a5c211579d1723b435b84cf6cae0460cf2dc777`; production-код и тесты
не изменялись. Реализация SCRUM-955 — `ff8f2e2ba731a740f85dd7178db0425e95a16245`.

Подтверждено:

- шесть вкладок имеют точные русские подписи; проекции содержат ровно 8
  `BASE_STAT_ORDER` и 26 `DERIVED_STAT_ORDER` записей без пересечения;
- player-facing названия, описания, влияния и формулы проекций русские, raw id
  не отображаются;
- title/chip не схлопываются, related/detail scroll — разные контролы, обе
  rail-зоны находятся внутри пустой области рамы на 1280×720, 1920×1080 и
  2560×1440;
- compositor-перепроверка SCRUM-1013: planning gate
  `ready_for_image/ok=true`, layout/final render `ok=true`, без warnings/errors;
- PASS: `codex_data_smoke_test`, `stat_formulas_smoke_test`,
  `stat_formulas_derived_sync_test`, `codex_discovery_contract_test`,
  `codex_unlock_tracking_test`, `runtime_smoke_ui_test`,
  `ui_no_overlap_matrix_test`, `display_resolution_test`,
  `dark_fantasy_ui_theme_test`, `asset_reference_integrity_test`,
  `gamepad_menu_focus_test`, `gamepad_full_flow_smoke_test`, полный
  `runtime_smoke_test`. В headless screenshot-helper остаётся известный
  нефатальный dummy-renderer warning `texture_2d_get`; тесты завершаются PASS.

Блокер приёмки — related-проекция не канонична. Для `ultimate_multiplier`
player-facing формула прямо содержит «Энергия × 0,02 + остальные базовые
характеристики × 0,002», а влияние — «малый вклад всех базовых характеристик».
Однако `CodexData.attributes()` возвращает только
`ultimate_multiplier.related = [energy]`, и живой rail показывает только
«Энергия». Причина — `_related_stats()` ищет точные русские названия внутри
prose-строк; обобщённые канонические зависимости теряются. Текущий data smoke
проверяет лишь тип/принадлежность related-id, но не точную матрицу, поэтому
ошибка проходит все зелёные гейты.

Remediation Bug: **SCRUM-1021** — `Codex: related characteristics omit
canonical stat dependencies`; bug добавлен в активный спринт 0.2.1,
fixVersion 0.2.1 и связан как blocker SCRUM-955. До его исправления и повторной
независимой QA задача SCRUM-955 не принимается.

Disk cleanup: удалены одноразовые windowed captures/logs/scripts из
`/tmp/scrum955_qa`, импорт-кэш `.godot/` и только ignored QA-артефакты этого
worktree; сам QA-worktree удаляется после commit/push evidence.

Thread cleanup: collaboration subagent, не отдельный disposable top-level
Codex worker; архивирование текущего пользовательского task не требуется.

## QA-Вердикт (повторный, 2026-07-10, `/root/audit_repo`) — FAILED

Статус: FAILED

SCRUM-1021 исправляет исходный data-блокер: независимый численный probe и все
focused/runtime тесты подтверждают каноническую матрицу 26×8, точную обратную
проекцию, все восемь характеристик у `ultimate_multiplier` и отсутствие
лексических false positives.

Полная приёмка SCRUM-955 всё ещё не проходит обязательный 1280×720 visual
gate. В обоих split-разделах выбранный заголовок не рисуется: rect `284×34`,
шрифт 30 px даёт glyph height 42 px, `line_count=1`, `visible_lines=0`. Дефект
повторён в fresh-процессах после 120 settle-кадров; 1920×1080, ultrawide,
2560×1440 и 4K зелёные. Frame safe zones, шесть русских вкладок, два
независимых scroll-контрола и связанные списки иначе корректны.

Blocking Bug: **SCRUM-1023**. SCRUM-955 остаётся `К выполнению` до исправления
и повторной независимой QA. Production-код и тесты QA не изменяла; скриншоты
блокера сохранены в `docs/design/previews/scrum1023_codex_title_missing_*`.

Disk cleanup: removed временные captures/logs/probes в `/tmp/scrum1021_qa`,
ignored `build/qa` и `.godot`; удаление QA-worktree после evidence push
фиксируется финальным Jira-комментарием.

Thread cleanup: collaboration subagent, не disposable top-level worker.

## Финальный независимый QA (2026-07-10, `/root/audit_repo`) — PASSED

SCRUM-1021 и SCRUM-1023 приняты на fresh `origin/dev`. Шесть русских вкладок,
точные проекции 8/26, canonical related matrix/inverse, Russian-only текст,
раздельные related/detail scroll и frame-safe rails подтверждены. Два fresh
1280×720 windowed capture показывают «Лидерство» и «Сила ульты» с
`visible_lines=1`; 1080p, ultrawide, 1440p и 4K также прошли visual review.
Последовательный stat/Codex/UI/display/theme/assets/gamepad/full-runtime suite
через `tools/godot_gate.py` — PASS. Production-код и тесты QA не изменяла.
