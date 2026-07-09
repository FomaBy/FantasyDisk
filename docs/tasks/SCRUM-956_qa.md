# SCRUM-956 — independent localization/content QA

Статус: done
Дата: 2026-07-10
QA owner: Codex `/root/audit_repo`
Lane: Codex
Implementation commits: `083a8b84`, `e1d24f87`
Jira: SCRUM-956

## Precondition And Scope

Live Jira was `Контроль качества`; the implementation owner and paths were
released, and no competing QA claim or QA-evidence lock existed. QA claimed the
issue before creating a fresh worktree from `origin/dev`.

QA writes are limited to this evidence mirror and the scoped SCRUM-956 entry in
`docs/process/jira_sync_map.json`. Production data, scripts, tests, UI and
authority docs were inspected read-only. No localization, data or UI correction
was made.

## QA-Вердикт

Статус: PASSED

All artifact/shop titles and live Codex projections satisfy the Russian-only
contract. The five requested mappings are exact, the shop decisions remain
separate, stable gameplay fields and icon paths are preserved, and no defect was
found.

## Independent Data Audit

Direct parsing of the current ProgressionData source found:

- exactly 154 unique artifact records and seven unique shop records;
- every player-facing artifact and shop title is non-empty, contains Cyrillic
  text and contains no Latin letter;
- all 154 `artifact_<id>.png` and all seven `shop_<id>.png` convention paths
  exist.

Exact requested artifact titles:

| ID | Title |
| --- | --- |
| `red_whetstone` | Точильный камень |
| `field_kit` | Полевой бинт |
| `magnetic_buckle` | Магнитный талисман |
| `fast_boots` | Легкие сапоги |
| `hawk_lens` | Линза охоты |

`quickstring` remains the separate artifact «Быстрая струна».

The seven shop records remain:

- `shop_damage` — «Точильный камень»;
- `shop_heal` — «Полевой бинт»;
- `shop_pickup` — «Магнитный талисман»;
- `shop_speed` — «Легкие сапоги»;
- `shop_weapon_cooldown` — «Масло темпа»;
- `shop_range` — «Линза охоты»;
- `shop_artifact` — «Пыльный артефакт».

No `dusty_artifact` id, data record or icon path exists.

The implementation diff in `scripts/progression_data_content.gd` changes only
the five `title` string values above. After replacing each changed title with a
placeholder, its before/after record line is byte-identical; therefore ids,
stats, mods, tier, cost, affinities, triggers and other gameplay fields remain
unchanged. `scripts/progression_data_shop.gd` and `scripts/codex_data.gd` were
not modified by the implementation commits.

## Codex Projection And Runtime UI

`CodexData.artifacts()` copies `title` from the canonical artifact and shop
records. `_build_codex_artifacts()` binds that title to both the center card and
right dossier; raw ids are used internally only for definition/icon lookup and
are not appended to player-facing chips or labels.

An independent temporary QA probe instantiated the live Codex at `1536x864`,
opened the artifacts tab, and checked all 161 center cards against all 161
projections. For every row it selected the card and verified:

- the center row contains the localized title and does not expose its raw id;
- `CodexDetailTitle` exactly equals the localized title;
- detail chips do not expose the raw id.

The probe passed `161/161` and was deleted together with its generated UID; it
is not part of the committed product/test suite.

## Documentation Consistency

The current authority rows in `docs/design/content_registry.md`,
`docs/design/systems/artifact_system_matrix.md` and
`docs/design/artifact_shop_cursor_visual_kit.md` contain the exact requested
titles and the `quickstring` / shop-only decisions. The replaced titles
«Красный оселок», «Полевой набор», «Магнитная пряжка», «Быстрые сапоги» and
«Линза ястреба» are absent from those authority paths and current data.

## Verification

All Godot commands ran through `tools/godot_gate.py` and exited 0 on the latest
relevant `origin/dev` content:

- temporary `scrum956_codex_localization_qa_probe.gd` — PASS, 161 live
  center/detail rows; removed after the run;
- `tests/codex_data_smoke_test.gd` — PASS, 161 artifact/shop projections;
- `tests/artifact_family_roll_test.gd` — PASS, 32 families / 300 rolls;
- `tests/class_artifacts_test.gd` — PASS, 85 entries / 17 classes;
- `tests/artifact_ascension_gate_test.gd` — PASS, 154 artifacts / 17 classes;
- `tests/artifacts_606_609_test.gd` — PASS, 10 data/icon records;
- `tests/content_registry_consistency_test.gd` — PASS, zero allowlisted drift;
- `tests/runtime_smoke_triggered_artifacts_test.gd` — PASS;
- `tests/ui_no_overlap_matrix_test.gd` — PASS, including Codex safe-zone and
  center/detail containment checks;
- `tests/runtime_smoke_test.gd` — PASS. The dummy-renderer `texture_2d_get`
  screenshot diagnostic is known and non-fatal.

Final tested content head was `d62eb642`; the later fast-forward to
`origin/dev` `08905e3b` contains only audio and task/Jira evidence changes
outside SCRUM-956 data/UI/test scope.

Git/Jira: QA evidence commit `09a61aa7` was pushed to `origin/dev`; live Jira
was moved from `Контроль качества` to `Готово` after the PASS verdict.

Disk cleanup: removed the generated `.godot` cache (`445 MB`) and Python
caches. The now-clean disposable QA worktree and local branch are removed after
the scoped Jira-map sync commit is pushed.
