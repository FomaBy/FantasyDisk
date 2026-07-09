# Обновить skill «Перенос чата» под автономный Jira/Git/thread workflow

Статус: done
Приоритет: high
Контур: Codex
Owner: Backend/Codex
Thread/Worker: /root/audit_repo
Jira: SCRUM-1003
Locked paths: `skills/codex/perenos-chata/SKILL.md`, `skills/codex/perenos-chata/agents/openai.yaml`, `docs/tasks/codex_perenos_chata_autonomy_update_task.md`, `docs/process/jira_sync_map.json` только при изменении scoped sync.

## Контекст

Предыдущая локальная реализация не попала в `origin/dev`, поэтому QA вернул
тикет в «К выполнению». Skill должен переносить не только разговор, но и
правдивое рабочее состояние автономного FantasyDisk/Jira/Git worker.

## Требования

- Перед переносом перечитывать актуальный применимый `AGENTS.md`.
- Не запрашивать рутинные подтверждения для разрешённых in-scope действий.
- Сохранять Jira/Git/tests/docs/disk/thread cleanup state и следующий шаг.
- Не оставлять Jira в stale `В работе` и архивировать исходный thread только
  после успешной передачи контекста и завершения обязательного cleanup/sync.
- Сохранить компактный переносимый `SKILL.md`; frontmatter — только `name` и
  `description`; синхронизировать `agents/openai.yaml` через `skill-creator`.

## Acceptance

- Skill mirror обновлён и валиден.
- `agents/openai.yaml` соответствует skill и проходит генерацию/валидацию.
- Runtime smoke проходит на актуальной ветке.
- Результат закоммичен с `SCRUM-1003`, отправлен в `origin/dev` и передан QA.

## Результат

- `perenos-chata` теперь перечитывает актуальные `AGENTS.md`, проверяет live
  Jira ownership и выполняет разрешённые repo/Jira/Git/thread действия
  автономно без рутинных подтверждений.
- Добавлены no-stale-in-progress guard, правдивая фиксация uncommitted/unpushed
  работы и безопасный порядок archive-last после доставки контекста, sync и
  cleanup.
- Snapshot сохраняет Jira/sprint/status/owner/lane/locks, Git worktree/branch/
  commit/push/dirty state, tests, docs, disk cleanup, thread cleanup и точный
  следующий шаг.
- `agents/openai.yaml` детерминированно пересоздан генератором `skill-creator`.

## Проверки

- `python3 .../skill-creator/scripts/quick_validate.py skills/codex/perenos-chata`
  — PASS.
- `git diff --check` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
  — PASS, exit 0 (`Runtime smoke test passed.`).
- Commit/push, scoped Jira QA transition и фактический disk cleanup фиксируются
  в финальном Jira comment после отправки результата в `origin/dev`.

QA выполняет отдельный исполнитель; самостоятельный QA-вердикт не добавлялся.
