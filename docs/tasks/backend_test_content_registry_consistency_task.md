# Back-end Task: Content Registry Consistency Test

Статус: done 2026-06-13 (Claude Backend)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-178 / SCRUM-175
Jira: SCRUM-200
Эпик: epic_full_project_quality_pass

## Scope

Add automated registry-vs-code-vs-assets checks for canonical IDs and resource paths.

## Requirements

- Validate character IDs, weapon IDs, boss/enemy IDs, artifact IDs and shop IDs.
- Validate static resource paths with `ResourceLoader.exists`.
- Support dynamic path patterns with an explicit manifest.
- Do not delete files in this task.

## Verification

- New test passes headless.
- False positives are documented and allowlisted.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.


## Результат — 2026-06-13

Новый изолированный тест tests/content_registry_consistency_test.gd: сверяет канонические данные
реестра/кода с ассетами через ResourceLoader.exists.
- Character sprite_path (17 классов), weapon scene_path (51 вариант), codex monster sprite
  (26: боссы/элитки/мини/обычные), artifact icon (artifact_<id>.png по ARTIFACTS).
- ID-проверки: уникальность/непустота character/weapon/monster/artifact id; weapon без определения.
- Статические пути — ResourceLoader.exists; динамика/осознанные расхождения — const ALLOWLIST
  (сейчас пуст — реестр чист, 0 пропавших). Защита от вакуумного прохода (мин. счётчики).
Прогон headless зелёный, 0 пропавших ресурсов, 0 ID-ошибок. Done.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-200)

Проверено фактически:
- Тест `tests/content_registry_consistency_test.gd` проходит headless:
  «Content registry consistency test passed (0 allowlisted)» — 0 пропавших ресурсов,
  0 ID-ошибок. Реестр консистентен с ассетами.
- НЕ вакуумный (ключевая проверка): явный анти-вакуум гейт (стр. 26) — падает если
  `character_ids<9 OR MONSTERS<20 OR ARTIFACTS<40` («gate would pass vacuously»).
  Реальные проверки через `ResourceLoader.exists` (60): character sprite_path (17,
  стр.77), weapon scene_path (51, стр.93), codex monster sprite (26), artifact icon
  (artifact_<id>.png, стр.108) + ID-уникальность/непустота (46), weapon-без-определения.
- `ALLOWLIST` const пуст — реестр чист, осознанных расхождений нет.
- Тест file-изолирован (не часть 6 базовых smoke); базовый smoke не затронут.
Багов нет.
