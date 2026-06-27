# FantasyDisk AI Agent Memorandum

Обновлено: 2026-06-27

Этот меморандум можно дать любому AI-агенту перед работой над FantasyDisk.
Он не заменяет `AGENTS.md`, task files, Jira и process docs, а служит быстрым
стартовым протоколом: кто за что отвечает, как брать работу, какие скиллы
обязательны, как синхронизировать GitHub/Jira и когда нельзя начинать.

## Короткая Директива Для Нового Агента

Ты работаешь над Godot 4 проектом FantasyDisk. Вся разработка ведётся только AI
агентами. Пользователь не программирует вручную и ожидает автономного выполнения:
понять задачу, проверить владельцев, выполнить свою часть, протестировать,
задокументировать, синхронизировать Jira и GitHub.

С 2026-06-27 Jira является единым источником задач, статусов, owner и sprint state.
Все задачи ставятся в Jira и берутся из Jira. Локальные `docs/tasks/*.md` и
`docs/process/task_board.md` — только spec/evidence mirrors и dashboard/cache.

Перед любыми изменениями прочитай:

- `AGENTS.md`;
- `docs/process/task_board.md`;
- `docs/process/agent_role_boundaries_and_handoffs.md`;
- `docs/process/pm_workflow.md`;
- `docs/process/jira_sync.md`;
- `docs/process/versioning_and_branching.md`;
- relevant `docs/tasks/*.md`;
- `docs/design/current_game_state.md`, `docs/design/content_registry.md`,
  `docs/design/mechanics_extract.md` для gameplay/balance/UI/content задач.

Никогда не начинай работу, пока не проверил:

- текущую ветку и GitHub sync;
- dirty worktree;
- Jira issue/status/comments/assignee/labels/sprint, затем local task mirror/board row;
- `Контур`, `Owner`, `Thread/Worker`, `Locked paths`;
- свежие dispatch/result/QA notes;
- пересечение файлов, ассетов, экранов или задачи с другим активным owner.

Главное правило: одна задача = один owner = один execution lane = один набор
locked paths. Codex, Claude, DeepSeek, Gemini или любой другой AI могут работать
параллельно только над разными задачами и непересекающимися файлами.

## Источники Правды

| Область | Источник |
| --- | --- |
| Общие правила агента | `AGENTS.md` |
| Очередь задач/status/owner | Jira проект `SCRUM` |
| Локальный dashboard/cache | `docs/process/task_board.md` |
| Детали задачи/spec/evidence mirror | `docs/tasks/<task>.md` |
| Jira sync map | `docs/process/jira_sync_map.json` |
| Роли и handoff | `docs/process/agent_role_boundaries_and_handoffs.md` |
| PM процесс | `docs/process/pm_workflow.md` |
| QA процесс | `docs/process/qa_protocol.md` |
| Ветки/версии | `docs/process/versioning_and_branching.md` |
| Дизайн/механики | `docs/design/*.md` |
| GitHub | `https://github.com/FomaBy/FantasyDisk` |

Если источники расходятся, не угадывай молча. Сначала проверь Jira issue,
comments/status/assignee/labels, затем task file, board, sync map и recent owner notes. Если конфликт остаётся, зафиксируй
blocked/PM note или создай handoff, но не стартуй параллельную реализацию.

## Типы Агентов

### PM / Product Agent

PM формирует требования, **создаёт Jira issue** (источник задач), затем держит
локальные `.md`/task board как зеркало в актуальном состоянии. PM не пишет код, не
рисует ассеты и не делает анимации.

PM обязан:

- превращать запрос пользователя в проверяемый Jira issue;
- выбрать роль и execution lane;
- указать `Контур`, `Owner`, `Thread/Worker`, `Locked paths`;
- создать/обновить local `.md`/board mirror только после Jira key;
- декомпозировать cross-discipline работу на handoff tasks.

### Documentation Dispatcher

Dispatcher читает Jira as authoritative queue, сверяет local mirrors и раздаёт eligible задачи в существующие role
threads. Он не реализует gameplay, UI, art, animation, balance, release builds.

Dispatcher обязан:

- делать duplicate/active-owner audit перед routing;
- не отправлять задачу, если есть owner, dispatch note, `in_progress`, Jira
  ownership, unresolved blocker, QA gate или dirty/locked-path overlap;
- отправлять не более одной новой задачи в один role thread за heartbeat;
- обновлять только routing/Jira/board bookkeeping, если это нужно;
- отвечать `DONT_NOTIFY`, если eligible задач нет.

### Back-end Agent

Back-end отвечает за Godot/GDScript runtime:

- gameplay logic;
- combat, enemies, bosses, events;
- balance implementation;
- UI runtime/layout integration;
- tests/smokes;
- data-driven configs;
- docs for implemented systems.

Back-end не рисует final art, не делает source sprite packs и не занимается
animation polish/rig motion. Если нужна чужая часть, создаёт handoff.

### Design Main

Design main отвечает за крупный visual direction:

- full-screen mockups/specs;
- UI source/style anchors;
- broad art direction packages;
- big frame/source packs;
- visual handoff specs.

### Designer 2

Designer 2 отдельный owner, не общая очередь с Design main. Обычно берёт:

- isolated asset cleanup;
- visual QA fixes;
- source-sheet preparation;
- frame/button/icon packs по принятому стилю;
- repeatable generation tasks.

Design main и Designer 2 нельзя ставить на один экран, source pack, frame kit,
character set или asset directory без явной PM-разбивки.

### Animator

Animator отвечает за:

- movement, pivots, direction-facing;
- SpriteFrames;
- Skeleton2D/Bone2D, AnimationPlayer/AnimationTree;
- animation states: idle/walk/move/attack/hit/death;
- timing/VFX sync;
- animation smoke and manifests.

Animator стартует только после accepted Design source/handoff. USER HOLD всегда
сильнее формально готовой зависимости.

### QA Agent

QA проверяет `done` задачи по `docs/process/qa_protocol.md`. QA не чинит код,
арт или анимацию в исходной задаче. Если найден дефект, QA создаёт отдельный
`bug_*_task.md`, board row и Jira issue/comment.

Задача полностью закрыта только после `## QA-Вердикт: PASSED`.

### Review / Audit / Security Agents

Review, audit и security agents работают как отдельная роль или отдельная
задача. Они не должны чинить owner work параллельно. Любая правка после review
оформляется как отдельный bug/follow-up task с новым owner и locked paths.

Security/audit agents обязаны:

- не выводить секреты в чат;
- не хранить токены в репозитории;
- проверять `.env`, logs, generated reports, configs, Git history risk;
- отличать read-only audit от fix task;
- заводить отдельные tickets для исправлений.

### Release Agent

Release делает только release flow: version bump, changelog, builds, release
notes, publication. Release не добавляет новые gameplay/art features. Используй
release skill только когда задача явно про релиз.

## Execution Lanes

Каждый активный Jira issue и его local mirror должны содержать:

```text
Статус: new | in_progress | review | done | blocked
Контур: Codex | Claude | OtherAI
Owner: <роль>/<thread или worker> | unassigned
Thread: <Codex thread id> | <Claude worker id> | <other agent id> | n/a
Locked paths: <файлы/папки/ассеты/экраны>
Jira: SCRUM-<номер>
```

`OtherAI` используется для DeepSeek, Gemini или любого другого AI. Правила те же:
single owner, locked paths, Jira sync, GitHub sync, QA gate.

Codex и Claude могут работать одновременно только если:

- задачи разные;
- locked paths не пересекаются;
- dirty worktree не пересекается;
- task/Jira/board явно показывают разных owner;
- review/fix не идёт параллельно с реализацией.

## Запрет На Самовыбор

Role agents не выбирают себе любую `new` строку из локального board или
неassigned Jira backlog. Они продолжают только:

- Jira issue, явно dispatched в их thread/worker;
- активную задачу с совпадающим owner/thread;
- bug/regression/release blocker, явно assigned им;
- результат/QA verdict, который нужно синхронизировать.

Если Jira issue выглядит подходящим по роли, но не имеет явного owner/dispatch,
агент ждёт dispatcher/PM.

## Task Lifecycle

Нормальный цикл:

```text
new -> in_progress -> done/review -> QA -> QA PASSED -> Jira Done
```

Перед первой правкой executor обязан:

1. Проверить branch/status/fetch state.
2. Найти Jira issue и проверить owner/locked paths/status/comments.
3. Убедиться, что Jira issue явно assigned ему.
4. Поставить Jira `in_progress`/comment и только затем local mirror `Статус: in_progress`.
5. Запустить/обновить sync.
6. Только потом менять код/ассеты/docs.

Завершая задачу, executor обязан:

1. Обновить Jira status/comment результатом.
2. Обновить task file mirror результатом.
3. Обновить docs/design docs, если изменились functionality/balance/UI/content.
4. Прогнать нужные smokes/tests/validators.
5. Поставить Jira + mirror `done` или `review`.
6. Синхронизировать local mirrors.
7. Закоммитить и запушить работу или открыть PR по GitHub workflow.
8. Оставить рабочее дерево чистым либо явно описать оставшийся WIP/blocker.

## Jira Правила

Jira обязательна. Работа не считается сделанной, если Jira не отражает реальность.

Обязательные действия:

- новая задача: Jira issue first, local `.md`/board mirror second;
- взял задачу: Jira status/comment + `.md` mirror `in_progress`;
- завершил: Jira status/comment + `.md` mirror `done/review`;
- QA passed: Jira в «Готово»;
- blocked: Jira comment/status с точной причиной;
- handoff: отдельный `.md` task + Jira issue/comment в исходном тикете;
- duplicate/superseded: отметить в `.md`, board и Jira.

Не хранить Jira token в репозитории. Использовать Keychain/env/секреты среды.

## GitHub И Git Sync

GitHub repository: `https://github.com/FomaBy/FantasyDisk`.

Цель пользователя: вся разработка AI-агентов должна синхронно попадать в GitHub,
а не жить локальным WIP. Локальные незакоммиченные изменения допустимы только
как временное состояние во время активного выполнения.

Перед началом:

```bash
git branch --show-current
git status --short --branch
git fetch origin --prune
git rev-list --left-right --count HEAD...origin/dev
```

Правила:

- `main` — стабильная линия, обычную разработку туда не делать.
- `dev` — активная рабочая ветка текущей линии `0.1.x`.
- Не переключать ветку и не делать destructive git commands без явного права.
- Не коммитить `.godot/`, local caches, secrets, private tokens.
- Не делать force push.
- Не переписывать чужой WIP.
- Не закрывать task как `done`, если нужный код остался только в dirty tree.
- После значимой работы commit + push обязательны, если среда/роль разрешает.

Желаемые exit states любого executor:

- `NO_CHANGES`: проверил, изменений не нужно, tree clean.
- `COMMITTED_PUSHED`: работа выполнена, commit pushed.
- `PR_OPENED`: branch pushed, draft/ready PR открыт.
- `BLOCKED_SYNCED`: причина blocked записана в task/Jira и запушена.

Для нового GitHub-first workflow предпочтительно:

1. Task branch от свежего `dev`: `codex/<scrum-key>-short-name`,
   `claude/<scrum-key>-short-name` или `<agent>/<scrum-key>-short-name`.
2. Маленькие intentional commits.
3. Push branch.
4. Draft PR в `dev`.
5. CI/review/QA.
6. Merge только после green gate.

Пока repo process прямо требует работу на `dev`, следовать локальному
`AGENTS.md`/task instructions. Но даже при direct-`dev` работе не оставлять
результат локально: commit + push после проверок.

## Обязательные Скиллы

Если задача попадает в область skill, skill обязателен. Старые ручные пайплайны
не использовать как fallback, если skill доступен.

| Область | Skill / Pipeline |
| --- | --- |
| UI screens, HUD, menus, frames, responsive layout | `fantasydisk-ui-director` |
| Raster assets, sprites, icons, frames, buttons, VFX PNG | `fantasydisk-asset-generator` |
| Character/enemy/boss animation, SpriteFrames, rigs | `fantasydisk-animation-director` |
| Class/weapon balance | `fantasydisk-class-balance-director` |
| Release build/publish | `fantasydisk-release-director` |
| GitHub PR publishing | `github:yeet` or local GitHub workflow |
| GitHub CI failure fix | `github:gh-fix-ci` |
| GitHub PR review comments | `github:gh-address-comments` |
| General GitHub triage | `github:github` |

UI hard rule: before UI implementation/redesign, create/consult OpenAI-generated
mockup/spec with safe margins and content zones, then reproduce in Godot and
verify screenshots/rects.

Asset hard rule: generated assets must use transparent background, D&D + Dark
Fantasy Dragon style when applicable, source saved in `docs/design/references/`,
runtime asset integrated under `assets/`.

Animation hard rule: animated entities need at least `move/walk` 5+ frames and
main `attack_primary` 5+ frames unless the task explicitly narrows scope.

Balance hard rule: balance classes as three-weapon kits, compare total kit score
by solo-target, AoE/crowd-clear and survivability/utility.

## UI / Visual Acceptance Rules

These are hard QA gates:

- UI elements must not overlap at supported resolutions.
- Content must never cover frame ornament/border/texture.
- Content goes only inside the empty content zone of a frame.
- `StyleBoxTexture` content margins must be at least texture margins plus safety.
- For non-rectangular/radial frames, content zone is the actual empty interior,
  not the bounding box.
- Visual tasks need screenshot/contact sheet/alpha/readability evidence when
  applicable.

Violation = QA FAILED + bug task.

## Tests And Verification

Use task acceptance criteria first. Common checks:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/sergeyfomin/Documents/AI\ Agent \
  --script res://tests/runtime_smoke_test.gd
```

Also run focused tests mentioned by task/skill:

- UI no-overlap matrix for UI work;
- runtime UI smoke for UI screens;
- animation smoke and manifest validation for animation;
- balance harness/reports for balance;
- security/secret scans for audit/security work;
- CI checks after GitHub PR/push when available.

Do not claim green gate from dirty-only local state if task requires committed
clean HEAD verification.

## Handoff Rules

If your role needs another discipline:

1. Finish your part.
2. Create/update a handoff task in `docs/tasks/`.
3. Include exact scope, paths, acceptance criteria, dependencies and locked paths.
4. Add Jira key/sync.
5. Comment in source Jira issue that work was handed off.
6. Do not do the other role's work yourself.

Examples:

- Design creates source pack -> Back-end runtime integration handoff.
- Design creates animation-ready parts -> Animator rig/SpriteFrames handoff.
- Back-end finds missing art -> Design asset handoff.
- QA finds bug -> role-specific `bug_*_task.md`.

## Blockers

Do not stall silently. If work cannot proceed:

- mark task `blocked` with precise reason;
- record what was checked;
- create handoff if another role can unblock;
- sync Jira;
- commit/push docs-only blocker update if files changed.

Common blockers:

- USER HOLD;
- missing accepted source assets;
- dirty overlap with another owner;
- missing Jira key for executable task;
- ambiguous lane/owner/locked paths;
- failed required external credential/access;
- conflict between task and current design docs.

## Security Rules

- Never commit secrets, tokens, passwords, API keys or private credentials.
- Do not paste secrets into task files, changelog, logs or final reports.
- Use Keychain/env/secret manager.
- If secret exposure is suspected, report it and rotate/revoke externally.
- Generated logs/reports must be scanned before commit if they may include env,
  request headers, webhooks or API output.
- Security fixes should be separate tasks/PRs unless they are tiny and directly
  required by the current task.

## What Not To Do

- Do not ask the user for routine approvals; decide autonomously in scope.
- Do not self-select unowned board rows.
- Do not route one task to multiple agents.
- Do not edit files locked by another owner/lane.
- Do not use destructive git commands without explicit instruction.
- Do not work on `main` for ordinary development.
- Do not bypass mandatory skills.
- Do not leave Jira stale.
- Do not leave important completed work only in local dirty state.
- Do not mark `done` without tests/evidence appropriate to the task.
- Do not close a task fully before QA PASSED.

## Minimal Agent Startup Checklist

Use this before every task:

```text
1. Read AGENTS.md and relevant process/task/design docs.
2. Confirm branch and GitHub sync.
3. Check dirty worktree.
4. Find Jira issue and check status, comments, assignee, labels, sprint.
5. Check Contour/Owner/Thread/Locked paths.
6. Check local task/board mirror only after Jira, plus recent owner/dispatch/QA notes.
7. Verify required skill and read its SKILL.md if using Codex.
8. If Jira issue is not explicitly assigned, do not start.
9. If assigned, set Jira in_progress/comment + sync local mirror.
10. Work only inside role scope.
11. Test, update docs/task report.
12. Commit/push or open PR.
13. Leave clean final state or synced blocker.
```

## Minimal Final Report Checklist

Executor final report should state:

- task/Jira key;
- status after run;
- files changed;
- tests/validators run and results;
- docs updated;
- Jira status/comment/sync result;
- GitHub state: commit/branch/push/PR or no changes;
- blockers/handoffs if any.

Short final reports are good. Missing sync/test/owner information is not.
