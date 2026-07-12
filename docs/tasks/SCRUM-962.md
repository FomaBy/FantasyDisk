# ART Artifact Icons: полный пак иконок редизайна артефактов (100 NEW)

Статус: done
Приоритет: p1
Роль: Design
Версия: 0.2.1
Создано: 2026-07-09
Jira: SCRUM-962
Контур: Claude
Owner: claude-fable-orchestrator
Thread/Worker: claude-design-scrum962-artifact-icons-20260709
Locked paths: `assets/sprites/ui/icons/artifacts/artifact_<100 новых id>.png` (+`.png.import`), `docs/design/references/icons/artifacts/<100 новых id>/` + `scrum962_icons_manifest.json`, `docs/design/previews/artifact_icons_scrum962_{universal,class}_contact.png`, `docs/design/reports/artifact_icons_scrum962_qa.md`, `tools/build_scrum962_artifact_icons.py`
Branch/worktree: `wt/scrum962-icons` at `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/wt-scrum962-icons`

## Context / Problem

Редизайн системы артефактов (SCRUM-959) вводит 100 новых id: 15 универсальных
атрибут-семей без донора (§2.2 матрицы) и 85 классовых (17 классов × 5, §4).
Каждому нужна уникальная читаемая иконка в стиле существующего пака
(D&D + Dark Fantasy Dragon, изолированный предмет, тёмная палитра с одним
акцентом, без текста/рамок/фона).

## Required Change

Сгенерировать 100 иконок 256x256 RGBA по канону путей:
рантайм `assets/sprites/ui/icons/artifacts/artifact_<id>.png`, референсы
`docs/design/references/icons/artifacts/<id>/`. Evidence: контакт-щиты в
`docs/design/previews/`, QA-отчёт в `docs/design/reports/`.

Override-решения (зафиксированы в Jira-комментарии):

- **Генератор**: OpenAI `gpt-image-2` через `fantasydisk-asset-generator` —
  явный override PixelLab-правила (метка тикета `openai-image-generator`,
  прецедент SCRUM-690, существующий пак 71 иконки сделан этим пайплайном).
- **Удаление 17 легаси-иконок перенесено в SCRUM-961** (атомарно с данными) —
  оркестраторский override §7.3 матрицы. Здесь только добавление; 54 REUSE
  не тронуты.

## Acceptance Criteria

- Каждый из 100 финальных id имеет рантайм PNG 256x256 RGBA + `.png.import`.
- Референс-евиденс (source 1024 + prompt_notes.md) на каждый id.
- Контакт-щиты полного пака с 40px-рядом читаемости.
- Без текста/цифр/рамок/панелей/запечённого фона; предмет изолирован и центрирован.
- Тесты `no_duplicate_artifact_files_test` и `asset_reference_integrity_test` зелёные.

## Result / Evidence

Выполнено 2026-07-09, сдано в «Контроль качества».

- **100/100 сгенерировано** (4 чанка по 25, workers 4, quality high), фейлов нет,
  модерация не отбила ни один промпт.
- Перегенераций: 7 id, 13 доп. вызовов (систематический дефект — запечённая
  «шахматка прозрачности» в замкнутых полостях; лечение — void-free мотив):
  root_snare ×2, return_arc_rune ×2, impact_string ×3, feedback_loop ×2,
  drone_gyroscope ×3, elemental_recoil ×1, anchor_core ×1.
- Рантайм: 171 PNG в `assets/sprites/ui/icons/artifacts/` (71 было + 100 новых),
  SHA-дублей нет; 15 placeholder-PNG универсалов от SCRUM-960 замещены реальными
  генерациями при rebase (конфликты add/add решены в пользу генераций).
- Манифест: `docs/design/references/icons/artifacts/scrum962_icons_manifest.json`
  (100 записей, мотивы дословно из матрицы; 7 уточнены при выбраковке).
- Контакт-щиты: `docs/design/previews/artifact_icons_scrum962_universal_contact.png` (15),
  `docs/design/previews/artifact_icons_scrum962_class_contact.png` (85) — 96px + 40px ряд.
- QA-отчёт (формат прецедента SCRUM-690): `docs/design/reports/artifact_icons_scrum962_qa.md` —
  таблица всех 100 (padding/corner alpha/SHA/readability), дубль-чек, свип-детектор шахматки.
- Инструмент: `tools/build_scrum962_artifact_icons.py` (генерация → flood-fill
  чистка матта → кроп по альфе → 256x256 с паддингом ~28px → отчёт-JSON → дубль-чек → контакт-щит).

Validation:

- PASS: `python3 tools/godot_gate.py --headless --path . --import` — 100/100 новых PNG получили `.png.import`.
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/no_duplicate_artifact_files_test.gd` (15203 файлов, дублей нет).
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/asset_reference_integrity_test.gd` (195 файлов, 2406 res://-ссылок).
- INFO: `tools/validate_artifact_icons.py` — замечания только по 3 легаси-иконкам SCRUM-690; по 100 новым чисто (полноценный гейт — после данных 960/961).

Коммиты (dev): чанк 1/4, чанк 2/4, чанк 3/4 (+root_snare regen), чанк 4/4,
выбраковка 6 + контакт-щиты, evidence/import/отчёт/зеркало (финальный).

## QA-Вердикт (SCRUM-964)

Статус: PASSED
Дата: 2026-07-09
Проверил: claude-fable-orchestrator (claude-qa-scrum964-artifact-validation-20260709).
154/154 `artifact_<id>.png` + 154 `.png.import`, git-tree пары в origin/dev сходятся,
17 легаси-PNG отсутствуют; `validate_artifact_icons.py` exit 0. Контакт-щиты
(universal 15 + class 85) отсмотрены глазами: предметы изолированы, без текста/
рамок/запечённого фона, один акцент, классовая идентичность и 40px-ряд читаемы.
Detached-components на 6 иконках (3 легаси SCRUM-690 + magnetic_purse/tower_slam/
arquebus_shrapnel) — accepted-minor, без follow-up. no_duplicate_artifact_files,
asset_reference_integrity, ui_icon_registry_smoke — PASSED.
