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


## Результат — 2026-06-13

Новый изолированный тест tests/content_registry_consistency_test.gd: сверяет канонические данные
реестра/кода с ассетами через ResourceLoader.exists.
- Character sprite_path (17 классов), weapon scene_path (51 вариант), codex monster sprite
  (26: боссы/элитки/мини/обычные), artifact icon (artifact_<id>.png по ARTIFACTS).
- ID-проверки: уникальность/непустота character/weapon/monster/artifact id; weapon без определения.
- Статические пути — ResourceLoader.exists; динамика/осознанные расхождения — const ALLOWLIST
  (сейчас пуст — реестр чист, 0 пропавших). Защита от вакуумного прохода (мин. счётчики).
Прогон headless зелёный, 0 пропавших ресурсов, 0 ID-ошибок. Done.
