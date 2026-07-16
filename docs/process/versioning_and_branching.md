# Versioning And Branching Policy

Обновлено: 2026-07-16

## Текущее Правило

FantasyDisk использует SemVer до 1.0:

- `main` - стабильная линия выпущенных версий;
- `dev` - активная рабочая ветка текущей линии `0.2.x`;
- Multica проект `FantasyDisk` (issues `FAN-*`) - authoritative task
  queue/status/owner source; local task files and task board are
  mirrors/spec/evidence only. Legacy Jira (SCRUM-*) — read-only historical
  archive (см. docs/process/jira_to_multica_cutover.md).
- текущая разработка: активная Multica board / release target `0.2.3` на `dev`
  (на 2026-07-16); релиз `0.2.3` проходит финализацию перед слиянием в `main`.
- `0.1.8` и `0.1.9` отменены как плановые версии: новые Multica issues, mirrors,
  fixVersions и release/freeze notes не должны использовать эти номера.
- после `0.2.0` patch-линия идет как `0.2.1`, `0.2.2`, `0.2.3`, ...
- **Кадэнс спринтов — короткий, ~2 дня** (агентная скорость разработки), НЕ недельный.

## Feature Block

Feature block 0.1.5 снят релизом `v0.1.5` (2026-06-15). Сейчас активна
Multica board / release target `0.2.3` (на 2026-07-16): задачи ведутся через
Multica (task board — локальное зеркало), с обязательной проверкой `Контур`,
owner, locked paths и dirty worktree. Директива пользователя 2026-07-03: все
задачи, добавляемые в любые чаты, сразу попадают в active Multica board с
fixVersion активного release. На время FAN-1128 действует release freeze:
новые продуктовые изменения не входят в 0.2.3 и ждут следующего SemVer; разрешены
только доказанные release blockers и их QA.

## Branch Ownership

| Branch | Назначение | Правило |
| --- | --- | --- |
| `main` | Стабильная выпущенная линия | Не вести обычную разработку напрямую |
| `dev` | Активная рабочая ветка `0.2.x` | Работать по Multica (task board — зеркало); параллельные Codex/Claude задачи разводить через owner и locked paths |

## Правила Для Агентов

Перед началом любой задачи агент должен проверить текущую ветку:

```bash
git branch --show-current
git status --short --branch
git fetch origin --prune
git pull --ff-only origin dev
```

Ожидаемая ветка для разработки:

```text
dev
```

Если агент находится на `main`:

- не начинать разработку в `main`;
- переключиться на `dev`, если это безопасно;
- если есть незакоммиченные изменения и переключение рискованно, остановиться и явно описать ситуацию.

Если ветки `dev` нет:

- создать `dev` от актуального `main`, если это безопасно и соответствует задаче;
- зафиксировать действие в финальном ответе.

## GitHub Sync На Границах Задачи

Директива пользователя 2026-06-28: вся работа AI-агентов должна сразу
синхронизироваться с GitHub.

- Перед началом новой задачи агент обязан подтянуть актуальный `dev` из GitHub:
  `git fetch origin --prune` и `git pull --ff-only origin dev` или эквивалентная
  безопасная интеграция без переписывания истории.
- Если pull невозможен из-за dirty WIP, diverged history, locked-path overlap или
  конфликта, агент не начинает новую задачу. Он фиксирует blocker/owner note в
  Multica и ждёт routing/sync решения.
- После завершения задачи агент обязан обновить Multica/local mirrors, выполнить
  проверки, затем сделать intentional commit и `git push` сразу в рамках того же
  прогона.
- Задача не считается завершённой, если изменения остались только локально в
  dirty tree. Multica `done`/`in_review` разрешены только после успешного push или
  после явного blocker-комментария о failed push.
- Коммитить можно только файлы своей задачи/locked paths. Чужой WIP, `.godot/`,
  caches, secrets, tokens и случайные generated sidecars не добавлять.

## Release Flow

Текущий ожидаемый flow:

1. `main` хранит последнюю проверенную стабильную версию.
2. `dev` используется для активной разработки текущего live Multica board/release.
3. Активные задачи, баги, QA defects и release blockers закрываются в текущем
   release-цикле; Codex и Claude могут работать параллельно только при разных
   owner/locked paths.
4. После проверки `dev` можно будет слить в `main` как новую стабильную версию.
5. После релиза документация должна быть обновлена и отражать новую стабильную версию.

## Документация Версий

Документы должны явно понимать текущую линию разработки:

- `docs/design/current_game_state.md` описывает активное состояние `dev`, если не указано иначе.
- Multica issues по умолчанию создаются для `dev`/активной board; `docs/tasks/*.md`
  создаются только как local spec/evidence mirrors.
- release/finalization tasks должны явно указывать, какую версию готовят.

## Запреты

- Не коммитить `.godot/`.
- Не делать обычные feature changes напрямую в `main`.
- Не переносить изменения между `main` и `dev` destructive-командами без явного запроса.
- Не делать `git reset --hard`, `git checkout -- <file>` или похожие destructive operations без явного разрешения.
- Не начинать новую задачу без предварительного безопасного pull из GitHub.
- Не оставлять завершённую задачу незапушенной.

## Текущий Статус На 2026-07-16

- Активная ветка: `dev`.
- `main` получает проверенный релиз `0.2.3` после release merge.
- `dev` заморожен для финализации release target `0.2.3`; `0.1.8` и `0.1.9`
  skipped/superseded, существующий `v0.2.2` остаётся immutable.
