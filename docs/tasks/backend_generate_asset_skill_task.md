# Задача Для Back-end/Codex: Скилл генерации ассетов через OpenAI Images API

Статус: done
Создано: 2026-06-14
Автор: пользователь / Codex
Исполнитель: Codex
Версия: 0.1.5
Jira: SCRUM-324

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Нужно создать Codex skill для FantasyDisk, который дает воспроизводимый Python-инструмент генерации PNG-референсов через OpenAI Images API и сразу заводит follow-up task на внедрение сгенерированного контента.

## Требования
- Создать skill в автоподхватываемом каталоге Codex.
- Добавить Python-скрипт `generate_asset.py`.
- Скрипт принимает `--prompt`, `--output`, `--size`, `--quality`.
- Использовать OpenAI Images API, модель `gpt-image-2`.
- Сохранять PNG в `docs/design/references/` в папку, зависящую от `--output`/задачи.
- Создавать новую `.md` задачу по внедрению сгенерированного контента.
- По возможности синхронизировать новую задачу с Jira через `tools/jira_board_sync.py`.

## Acceptance Criteria
- [x] Skill имеет валидные `SKILL.md` и `agents/openai.yaml`.
- [x] `generate_asset.py --help` показывает обязательные параметры.
- [x] Скрипт компилируется Python без syntax errors.
- [x] В skill-инструкции описан путь сохранения, Jira/task behavior и ограничения `gpt-image-2`.
- [x] Jira sync запущен после смены статуса.

## Результат 2026-06-14

- Создан Codex skill: `/Users/sergeyfomin/.codex/skills/fantasydisk-asset-generator/`.
- Добавлен `/Users/sergeyfomin/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py`.
- Скрипт принимает `--prompt`, `--output`, `--size`, `--quality`, вызывает OpenAI Images API с `model="gpt-image-2"` и `output_format="png"`, сохраняет относительные outputs в `docs/design/references/`.
- После генерации скрипт создает `docs/tasks/design_integrate_generated_<slug>_task.md`, пытается запустить `tools/jira_board_sync.py` и подставить Jira key в task-файл.
- Проверки: `python3 -m py_compile` PASS; `generate_asset.py --help` PASS. `quick_validate.py` не запустился из-за отсутствия `PyYAML` в доступных Python runtime, но frontmatter/metadata проверены вручную и файл создан через штатный `init_skill.py`.
