# SCRUM-968 — Audio integration independent QA mirror

Статус: done
Роль: QA
Контур реализации: Claude
Контур QA: Codex
Owner реализации: released
QA Owner: /root/qa_1041_968
Thread/Worker: /root/qa_1041_968
Jira: SCRUM-968
Версия: 0.2.1
Locked paths: production code/docs/tests/assets read-only; this QA mirror and
scoped Jira sync bookkeeping only

## Объём повторной приёмки

Parent audio integration re-QA после устранения единственного документационного
блокера `SCRUM-1041`. Implementation commits `3bb3e611f`, `0e63ee301`,
`e6a53b8cf`, `9884e2f46`, `c1f1334ec` и frame-safe Credits fix `9f04dc59e`
остаются предками проверенного `dev`.

## QA-Вердикт (2026-07-11)

Статус: PASSED

Проверено:

- live runtime oracle: `purchase`/`ui_error`, централизованные
  `ui_click`/`ui_back`, `artifact_reveal` для victory и elite/boss reward,
  `MainMenuCreditsButton` → `CreditsScreen` → `CreditsBackButton`/Escape;
- Credits содержат шесть канонических CC BY 4.0 треков Kevin MacLeod,
  канонический license block, CC0 contributors и Godot attribution;
- child `SCRUM-1041` — PASSED: удалённых ссылок и stale deferral statements нет;
- `python3 tools/godot_gate.py --headless --path . --script
  res://tests/audio_integration_test.gd` — PASS;
- `python3 tools/godot_gate.py --headless --path . --script
  res://tests/ui_no_overlap_matrix_test.gd` — PASS;
- `python3 tools/godot_gate.py --headless --path . --script
  res://tests/runtime_smoke_test.gd` — PASS на финальном серийном прогоне.

Краевые случаи: полная пересборка свежего import cache после инфраструктурного
SIGSEGV первого параллельного OGG import; serial runtime rerun после общей
`user://` autosave-гонки; лицензии сверены одновременно с SOURCES, mastering
manifest и runtime Credits text.

Баги: нет.

Jira: `SCRUM-968` → `Готово`.
