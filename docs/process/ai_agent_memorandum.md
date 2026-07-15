# FantasyDisk AI Agent Memorandum

Обновлено: 2026-07-13

Этот меморандум можно дать любому AI-агенту перед работой над FantasyDisk.
Он не заменяет `AGENTS.md`, task files, Multica issues и process docs, а служит
быстрым стартовым протоколом: кто за что отвечает, как брать работу, какие скиллы
обязательны, как синхронизировать GitHub и Multica и когда нельзя начинать.

## Короткая Директива Для Нового Агента

Ты работаешь над Godot 4 проектом FantasyDisk. Вся разработка ведётся только AI
агентами. Пользователь не программирует вручную и ожидает автономного выполнения:
понять задачу, проверить владельцев, выполнить свою часть, протестировать,
задокументировать, синхронизировать Multica и GitHub.

С cutover 2026-07-13 (approver Sergey Fomin, владелец проекта) единственным
authoritative источником задач, статусов, owner и sprint state является Multica —
workspace FantasyDisk (`afa7a066-e0cb-4b55-a07d-41b361a8bb84`), проект FantasyDisk
(id `2ac963eb-b644-4540-8042-a1a4508f1a65`), issues `FAN-*` (например FAN-1044),
через `multica` CLI. Legacy Jira (`SCRUM-*`) теперь read-only historical archive
(импортирован в Multica-проект «Jira Archive»): не создавай, не claim'ай, не
синхронизируй и не закрывай работу в Jira. Полная запись cutover:
[`docs/process/jira_to_multica_cutover.md`](jira_to_multica_cutover.md).

Все задачи ставятся в Multica и берутся из Multica. Локальные `docs/tasks/*.md` и
`docs/process/task_board.md` — только spec/evidence mirrors и dashboard/cache.

Перед любыми изменениями прочитай:

- `AGENTS.md`;
- `docs/process/task_board.md`;
- `docs/process/agent_role_boundaries_and_handoffs.md`;
- `docs/process/pm_workflow.md`;
- `docs/process/versioning_and_branching.md`;
- relevant `docs/tasks/*.md`;
- `docs/design/current_game_state.md`, `docs/design/content_registry.md`,
  `docs/design/mechanics_extract.md` для gameplay/balance/UI/content задач.

Никогда не начинай работу, пока не проверил:

- текущую ветку и GitHub sync;
- dirty worktree;
- Multica issue FAN-<n>/status/comments/assignee, затем local task mirror/board row;
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
| Очередь задач/status/owner | Multica проект `FantasyDisk` (issues `FAN-*`), via `multica` CLI |
| Локальный dashboard/cache | `docs/process/task_board.md` |
| Детали задачи/spec/evidence mirror | `docs/tasks/<task>.md` |
| Legacy/archive-only (не часть live flow) | `docs/process/jira_sync_map.json`, `docs/process/jira_sync.md` |
| Роли и handoff | `docs/process/agent_role_boundaries_and_handoffs.md` |
| PM процесс | `docs/process/pm_workflow.md` |
| QA процесс | `docs/process/qa_protocol.md` |
| Ветки/версии | `docs/process/versioning_and_branching.md` |
| Дизайн/механики | `docs/design/*.md` |
| GitHub | `https://github.com/FomaBy/FantasyDisk` |

Если источники расходятся, не угадывай молча. Сначала проверь Multica issue
FAN-<n> (comments/status/assignee), затем task file, board и recent owner notes.
Если конфликт остаётся, зафиксируй blocked/PM note или создай handoff, но не
стартуй параллельную реализацию.

## Типы Агентов

### PM / Product Agent

PM формирует требования, **создаёт Multica issue FAN-<n>** (источник задач), затем
держит локальные `.md`/task board как зеркало в актуальном состоянии. PM не пишет
код, не рисует ассеты и не делает анимации.

PM обязан:

- превращать запрос пользователя в проверяемый Multica issue FAN-<n>;
- оценивать каждую actionable issue по CUE/Fibonacci `1, 2, 3, 5, 8, 13`,
  записывать `Story points` с обоснованием в description, прикреплять ровно один
  канонический Label `SP:<N>` и совпадающую числовую metadata `story_points`;
  scope больше `13 SP` декомпозировать до dispatch;
- выбрать роль и execution lane;
- указать `Контур`, `Owner`, `Thread/Worker`, `Locked paths`;
- создать/обновить local `.md`/board mirror только после Multica issue key (FAN-<n>);
- декомпозировать cross-discipline работу на handoff tasks.

### Documentation Dispatcher

Dispatcher читает Multica проект FantasyDisk (issues `FAN-*`) as authoritative
queue, сверяет local mirrors и раздаёт eligible задачи в существующие role
threads. Он не реализует gameplay, UI, art, animation, balance, release builds.

Dispatcher обязан:

- делать duplicate/active-owner audit перед routing;
- не dispatch'ить issue без ровно одного допустимого `SP:<N>` Label, совпадающих
  metadata `story_points` и обоснования в description или с
  недекомпозированным scope больше `13 SP`;
- не отправлять задачу, если есть owner, dispatch note, `in_progress`, Multica
  ownership, unresolved blocker, QA gate или dirty/locked-path overlap;
- отправлять не более одной новой задачи в один role thread за heartbeat;
- обновлять только routing/Multica/board bookkeeping, если это нужно;
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

QA Codex Sol (`f992a646-a8ea-4935-ba94-212595803052`) — единственный автономный
owner review-очереди. В queue-sweep run он сам выбирает одну eligible задачу
`in_review` после duplicate/lock/SHA/dependency audit, оставляет implementation
assignee неизменным и создаёт/переиспользует отдельную QA child issue. Из-за
live agent ACL child остаётся unassigned; ownership существует только при exact
metadata `qa_owner_id=f992a646-a8ea-4935-ba94-212595803052`,
`qa_run_id=<current-task-id>`, `qa_candidate_sha=<exact-sha>`,
`qa_claim_mode=autonomous_unassigned`, совпадающем claim-comment и live run.
После записи QA перечитывает parent/child/comments/metadata и при race прекращает
claim; уникальную child переводит напрямую `backlog → in_progress` без `todo`.
Остальные role agents и общий dispatcher считают этот metadata claim занятым и
не создают конкурирующий QA claim.

QA выполняет полный независимый цикл по `docs/process/qa_protocol.md`: проверяет
acceptance и реальный user flow, читает и запускает тесты, добавляет edge cases,
manual/windowed/visual/performance coverage по риску и прикладывает screenshots,
video/logs/traces, когда они нужны как evidence. QA не чинит production code,
арт или анимацию в review scope. Каждый подтверждённый баг или обязательное
улучшение становится linked Multica child `BUG:` / `IMPROVEMENT:` с деталями,
evidence и acceptance; локальный `bug_*_task.md` допустим только как mirror.

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

Каждый активный Multica issue FAN-<n> и его local mirror должны содержать:

```text
Статус: new | in_progress | review | done | blocked
Контур: Codex | Claude | OtherAI
Owner: <роль>/<thread или worker> | unassigned
Thread: <Codex thread id> | <Claude worker id> | <other agent id> | n/a
Locked paths: <файлы/папки/ассеты/экраны>
Multica: FAN-<id>
```

Для Codex one-off worker threads действует thread hygiene: после truthful
Multica/GitHub/local mirror/memory/test/disk cleanup результата worker архивирует
свой текущий чат через `codex_app.set_thread_archived` (`archived: true`, без
`threadId`) как последнее tool-действие перед финалом. Постоянные PM,
dispatcher/watch и user control чаты не архивируются автоматически.

`OtherAI` используется для DeepSeek, Gemini или любого другого AI. Правила те же:
single owner, locked paths, Multica sync, GitHub sync, QA gate.

Codex и Claude могут работать одновременно только если:

- задачи разные;
- locked paths не пересекаются;
- dirty worktree не пересекается;
- task/Multica/board явно показывают разных owner;
- review/fix не идёт параллельно с реализацией.

## Assignment-first Вместо Локального Самовыбора

Role agents не выбирают себе любую `new` строку из локального board. Локальная
доска — dashboard/cache, а не очередь. Обычная новая работа выдаётся только из
Multica проекта FantasyDisk (issues `FAN-*`) единственным dispatcher. Worker
берёт ровно одну issue с собственным exact `assignee_id` и перепроверяет её:

```bash
multica issue get <FAN-id> --output json
multica issue status <FAN-id> in_progress
multica issue comment add <FAN-id> --content-file ./start.md
```

Агент может начинать только после проверки: issue назначена его exact UUID,
status `todo`, нет чужого owner, нет
`hold/user-hold/blocked`, нет review/QA gate и нет locked-path overlap. Если
назначенной FAN issue нет, агент ничего не меняет и
завершает прогон.

Исключение — текущий direct user control chat. После duplicate/lock audit он
может оставить issue unassigned, поставить `in_progress` и записать explicit
`Mode: direct control chat`, owner/thread/workdir/locked paths comment. Такой чат
не назначает ту же issue daemon-агенту и продолжает только пока owner comment
совпадает с текущим thread.

Агент также может продолжать:

- активную Multica issue FAN-<n> с совпадающим owner/thread/worker;
- bug/regression/release blocker, явно assigned ему или owned этим direct-control thread;
- результат/QA verdict, который нужно отразить в timeline issue.

Если FAN issue выглядит подходящим по роли, но не имеет matching lane, агент
не берёт его, кроме случая явного PM/dispatcher разрешения.

Design pool rule: Design main and Designer 2 require an extra worker scope
(`design-main` or `designer2`) before dispatcher assignment. Generic `design` issues
without a worker-scope marker wait for PM/dispatcher split.

## Task Lifecycle

Нормальный цикл:

```text
Multica parent: todo -> in_progress -> in_review -> done (только после QA PASS)
local mirror:    new -> in_progress -> review -> done
```

`in_progress` is a live lock, not a parking lot. A Multica issue may remain in
`in_progress` only when the latest comments identify an active worker, branch or
worktree, locked paths, and a recent heartbeat. Long-running agents must update
the Multica issue at least every 60 minutes and before switching away. If the
agent cannot finish, it must release the claim back to `todo`, mark `blocked`
with a specific blocker, or create a handoff. Ending a run while the issue still
looks active but has no result/heartbeat is a process failure.

Перед первой правкой executor обязан:

1. Проверить branch/status/fetch state.
2. Найти Multica issue FAN-<n> и проверить owner/locked paths/status/comments.
3. Убедиться, что Multica issue assigned его exact UUID или имеет explicit
   direct-control owner comment для текущего thread.
4. Поставить Multica `in_progress`/comment и только затем local mirror `Статус: in_progress`.
5. Обновить local mirror под текущий статус issue.
6. Только потом менять код/ассеты/docs.

Завершая задачу, executor обязан:

1. Обновить Multica status/comment результатом.
2. Обновить task file mirror результатом.
3. Обновить docs/design docs, если изменились functionality/balance/UI/content.
4. Прогнать нужные smokes/tests/validators.
5. Поставить Multica + mirror `done` или `in_review`.
6. Синхронизировать local mirrors.
7. Закоммитить и запушить работу или открыть PR по GitHub workflow.
8. Оставить рабочее дерево чистым либо явно описать оставшийся WIP/blocker.
9. Убрать за собой временное место на диске: удалить disposable worktree/clone
   после push, удалить `.godot/`, `.import`, `.uid`, `__pycache__/` и временные
   логи/скриншоты вне committed evidence. Если cleanup невозможен из-за lock,
   записать в Multica comment/final report точный путь, примерный размер и причину.

Mandatory final Multica comment before any worker stops:

```text
Result: done | qa-ready | released | blocked | handoff
Branch/commit/PR: <branch and commit hash or explicit none>
Tests/evidence: <commands run or why impossible>
Docs/mirrors: <updated files or not needed>
Next owner/status: <QA, todo, blocked reason, or handoff issue>
Disk cleanup: <removed worktree/cache paths or locked leftovers with size>
```

If branch/commit/tests are missing, the task is not complete; keep it out of
`in_review` unless the Multica comment clearly records a blocker.

## Multica Правила

Multica обязательна. Работа не считается сделанной, если Multica issue FAN-<n> не
отражает реальность.

Обязательные действия:

- новая задача: требования и CUE/Fibonacci `Story points` first, затем Multica
  issue FAN-<n> + канонический Label `SP:<N>` + числовая metadata
  `story_points`, local `.md`/board mirror second;
- взял задачу: Multica status/comment + `.md` mirror `in_progress`;
- завершил: Multica status/comment + `.md` mirror `done/in_review`;
- QA passed: Multica issue в `done`;
- blocked: Multica comment + status `blocked` с точной причиной;
- handoff: отдельный `.md` task + Multica issue/comment в исходном тикете;
- duplicate/superseded: отметить в `.md`, board и Multica issue.
- stale cleanup: dispatcher may return an issue from `in_progress` to
  `todo` when there is no fresh heartbeat/result, no reachable active
  worker, or the same worker owns multiple unrelated active issues.

Не хранить секреты/токены в репозитории. Использовать Keychain/env/секреты среды.

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
git pull --ff-only origin dev
```

Правила:

- `main` — стабильная линия, обычную разработку туда не делать.
- `dev` — активная рабочая ветка текущей линии `0.1.x`.
- Перед началом каждой новой задачи агент обязан подтянуть GitHub: `git fetch
  origin --prune` + `git pull --ff-only origin dev` или эквивалентная безопасная
  интеграция. Если pull невозможен из-за dirty WIP, diverged history или
  конфликтов, новую задачу не начинать: записать blocker/owner note в Multica issue.
- Не переключать ветку и не делать destructive git commands без явного права.
- Не коммитить `.godot/`, local caches, secrets, private tokens.
- Не делать force push.
- Не переписывать чужой WIP.
- Не закрывать task как `done`, если нужный код остался только в dirty tree.
- После любой выполненной задачи commit + push обязательны сразу после проверок и
  Multica/mirror sync. Multica `done`/`in_review` допустимы только если результат
  уже запушен или push failure явно записан blocker-комментарием.
- Коммитить только свои locked paths; чужой WIP/sidecars не добавлять.

Желаемые exit states любого executor:

- `NO_CHANGES`: проверил, изменений не нужно, tree clean.
- `COMMITTED_PUSHED`: работа выполнена, commit pushed.
- `PR_OPENED`: branch pushed, draft/ready PR открыт.
- `BLOCKED_SYNCED`: причина blocked записана в task/Multica issue и запушена.

Для нового GitHub-first workflow предпочтительно:

1. Task branch от свежего `dev`: `codex/<fan-key>-short-name`,
   `claude/<fan-key>-short-name` или `<agent>/<fan-key>-short-name`.
2. Маленькие intentional commits.
3. Push branch.
4. Draft PR в `dev`.
5. CI/review/QA.
6. Merge только после green gate.

Пока repo process прямо требует работу на `dev`, следовать локальному
`AGENTS.md`/task instructions. Но даже при direct-`dev` работе не оставлять
результат локально: pull перед стартом новой задачи, commit + push после
проверок каждой завершённой задачи.

## Disk Cleanup

Свободное место на диске является частью definition of done. Любой агент, который
создаёт отдельный worktree, clone, QA checkout, image/mockup temp directory,
Godot import cache или test user-data cache, обязан убрать это после завершения.

Обязательный cleanup после push/Multica final comment:

```bash
git -C <main_repo> worktree remove --force <agent_worktree>
git -C <main_repo> worktree prune
```

Также удалить в своём disposable checkout generated caches: `.godot/`, `.vs/`,
`__pycache__/`, untracked `.import`/`.uid`, transient logs and temp screenshots.
Committed evidence under `docs/design/previews`, `docs/design/references`,
`docs/tasks`, `build/qa/<task>` is not temporary and must remain if it is part
of the result.

Never delete the user's main repository, unrelated user folders, secrets, or
external application data. If cleanup fails because a process locks a file,
report the exact path and approximate size in the Multica comment/final output so
the next dispatcher can remove it after the process exits.

## Обязательные Скиллы

Если задача попадает в область skill, skill обязателен. Старые ручные пайплайны
не использовать как fallback, если skill доступен.

| Область | Skill / Pipeline |
| --- | --- |
| UI screens, HUD, menus, frames, responsive layout | `fantasydisk-ui-director` |
| Future redraw source work: characters, enemies, bosses, UI/frame source kits, animation/source packs | PixelLab MCP / PixelLab-oriented FantasyDisk skills by default |
| Non-redraw raster assets, sprites, icons, frames, buttons, VFX PNG, or explicit Multica issue exceptions | `fantasydisk-asset-generator` |
| Posters, infographics, report images, or UI elements/mockups with fixed text/content zones over AI art | `content-zone-image-compositor` |
| Character/enemy/boss PixelLab animation import, directional SpriteFrames, Hero Select preview | `fantasydisk-pixellab-animation-integrator` |
| Class/weapon balance | `fantasydisk-class-balance-director` |
| Release build/publish | `fantasydisk-release-director` |
| GitHub PR publishing | `github:yeet` or local GitHub workflow |
| GitHub CI failure fix | `github:gh-fix-ci` |
| GitHub PR review comments | `github:gh-address-comments` |
| General GitHub triage | `github:github` |

UI hard rule: before UI implementation/redesign, create/consult OpenAI-generated
mockup/spec with safe margins and content zones, then reproduce in Godot and
verify screenshots/rects.

PixelLab-first redraw hard rule: future redraw tasks use PixelLab as the default
source pipeline for character/enemy/boss redraws, animation/source packs, UI
frame/source kits and comparable redraw source assets. PM/dispatcher must write
this expectation into the Multica issue/task wording when creating redraw work. A
non-PixelLab path is allowed only when the Multica issue or task mirror records an
explicit exception and reason, for example an OpenAI Images override, reuse of an accepted
existing source, or a temporary PixelLab availability blocker. UI-director and
content-zone planning still apply: PixelLab provides the final redraw/source art,
but text, controls and layout content must remain inside declared safe/content
zones and must never cover frame ornament.

Asset hard rule: generated or redrawn assets must use transparent background,
D&D + Dark Fantasy Dragon style when applicable, source saved in
`docs/design/references/`, runtime asset integrated under `assets/`, and evidence
must prove alpha/readability/fit. Character redraws and animation source packs
must preserve pivots, runtime-safe sizing and required 8-direction or animation
contracts.

Content-zone image hard rule: when an AI-generated poster/report/UI element will
receive text, numbers, icons, portraits, lists, controls or labels after
generation, first prove the geometry. For UI elements create `ui_plan.json`
with exact rectangles, min/max fonts, content zones, required/auto/never
scrollbars, and a fit decision. Run `validate_ui_layout_plan.py` and continue to
image generation only on `decision: ready_for_image`; on `revise_task`, revise
size/content/scroll/tab split before art. Then define exact zones in
`layout.json` before generating the image. The generated image is the final
frame/layout layer; post-processing must not draw new cards, frames, panels or
opaque backing boxes over it. Insert content only inside declared zones and keep
the guide/debug overlay/report as evidence when the result matters. FantasyDisk
UI elements use strict dark fantasy / dragon specific / D&D styling: beautiful,
brutal and epic, but restrained and not over-detailed.

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
4. Add the Multica issue key (FAN-<n>)/sync.
5. Comment in the source Multica issue that work was handed off.
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
- sync Multica issue (status `blocked` + comment);
- commit/push docs-only blocker update if files changed.

Common blockers:

- USER HOLD;
- missing accepted source assets;
- dirty overlap with another owner;
- missing Multica issue key (FAN-<n>) for executable task;
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
- User directive 2026-06-28: agents have full in-repository approval for their
  authorized Multica issue (FAN-<n>). Sync from GitHub before starting, update
  the Multica issue, edit project files, run tests, update docs, commit, and push
  task-owned files without asking for confirmation. Only stop for platform-enforced
  approval gates, secrets, destructive external actions, or impossible blockers.
- Do not self-select local board rows or unassigned Multica issues; accept only
  the FAN issue assigned/owned by you after dispatcher verification. Sole
  exception: QA Codex Sol may select one eligible `in_review` parent under the
  exclusive QA queue-owner protocol, while owning a separate QA child and never
  replacing the implementation assignee.
- Do not route one task to multiple agents.
- Do not edit files locked by another owner/lane.
- Do not use destructive git commands without explicit instruction.
- Do not work on `main` for ordinary development.
- Do not bypass mandatory skills.
- Do not leave the Multica issue stale.
- Do not leave important completed work only in local dirty state.
- Do not mark `done` without tests/evidence appropriate to the task.
- Do not close a task fully before QA PASSED.

## Minimal Agent Startup Checklist

Use this before every task:

```text
1. Read AGENTS.md and relevant process/task/design docs.
2. Confirm branch and GitHub sync.
3. Check dirty worktree.
4. Determine mode: daemon requires exact assignee UUID; direct control requires explicit matching owner comment after duplicate/lock audit.
5. Check status, comments, assignee, Contour/Owner/Thread/Locked paths.
6. Check local task/board mirror only after the Multica issue, plus recent owner/dispatch/QA notes.
7. Verify required skill and read its SKILL.md if using Codex.
8. If neither exact assignment nor the direct-control exception matches you, do not start.
9. If authorized by exact assignment or direct-control ownership, set Multica in_progress + `--content-file` comment and sync local mirror.
10. Work only inside role scope.
11. Test, update docs/task report.
12. Commit/push or open PR.
13. Leave clean final state or synced blocker.
```

## Minimal Final Report Checklist

Executor final report should state:

- task/Multica issue key (FAN-<n>);
- status after run;
- files changed;
- tests/validators run and results;
- docs updated;
- Multica status/comment/sync result;
- GitHub state: commit/branch/push/PR or no changes;
- blockers/handoffs if any.

Short final reports are good. Missing sync/test/owner information is not.
