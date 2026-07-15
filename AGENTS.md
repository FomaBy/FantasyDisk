# FantasyDisk Agent Instructions

This repository is a Godot 4 project for FantasyDisk.

Before making gameplay, balance, character, enemy, UI, or progression changes, read:
- `docs/process/ai_agent_memorandum.md` for the compact onboarding protocol for any AI agent.
- `docs/process/multica_workflow.md` for the authoritative task intake, ownership,
  execution, QA, evidence, and recovery workflow.
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/gdd_source.md` when exact GDD wording matters.
- `docs/design/mechanics_extract.md` when formulas, classes, stats, weapons, or MVP screens matter.
- `docs/design/current_game_state.md` for the implemented game state.
- `docs/design/content_registry.md` for canonical entity IDs and names.
- `docs/process/agent_role_boundaries_and_handoffs.md` for Design/Back-end/Animator ownership and cross-chat handoff rules.
- `docs/process/versioning_and_branching.md` for the active version/branch policy.

Autonomy and approval:
- The user pre-approves all in-scope project changes requested in task files or direct prompts.
- Full in-repository autonomy is granted by user directive (2026-06-28). Agents must not stop for confirmation before commands or file operations needed for claimed FantasyDisk tasks inside this repository: read/write/edit/create/delete project files, run shell helpers, Godot/Python tests/imports, asset/mockup generation required by skills, `multica` CLI calls, and normal Git task workflow (`fetch`, `pull`, `rebase`, `status`, `diff`, `add`, `commit`, `push`). Do not ask for permission on Codex approval prompts for in-scope project work. Hard limits remain: never expose or commit secrets/tokens, do not perform destructive actions outside the project, do not damage external accounts/payments, and avoid force-push/history rewrite unless there is no normal Git alternative and the task explicitly requires it. If a claimed task requires deleting or replacing project files, do it and record the rationale in the Multica issue / task evidence.
- Do not stop to ask for confirmation when the requirement is clear enough to implement. Make a reasonable product/engineering decision, implement it, test it, and document it.
- Full in-repo execution access is user-approved for all agents (directive 2026-06-28): do not ask for confirmation for normal Multica-tracked task work, including GitHub sync, Multica claim/status updates, file edits inside the project, tests, documentation updates, commits, and pushes of the agent's own task files.
- Ask the user only when the task is impossible without missing information, would change the product direction outside the request, or would require a dangerous/destructive action.
- Still obey Codex/runtime safety rules: request required sandbox escalation, do not expose secrets, do not use destructive git/file commands unless explicitly requested, and do not modify files outside the project without approval.
- For every future task that changes functionality, balance, content, UI, progression, visuals, or animation, update the relevant documentation in the same task.
- After large multi-agent change batches, run the documentation split/update task in `docs/tasks/documentation_post_changes_domain_split_task.md` and keep domain docs under `docs/design/systems/` up to date.

**UI/ВИЗУАЛ — ГЛОБАЛЬНОЕ ПРАВИЛО ФРЕЙМОВ (директива пользователя 2026-06-14, ОБЯЗАТЕЛЬНО для ВСЕХ агентов).**
Ни при каких обстоятельствах нельзя накладывать элементы интерфейса — кнопки,
портреты/героев, области выбора (карусели, списки, слоты), иконки, текст — на
текстуру/окантовку/орнамент рамки (frame). Контент размещается ТОЛЬКО в пустой
зоне фрейма: в прозрачной/тёмной внутренней области или на подложке фона.
Декоративная рамка всегда остаётся видимой и не перекрытой контентом.
- Технически: у текстурных стилей (StyleBoxTexture / 9-slice) **content margins ≥
  texture margins (толщины окантовки) + запас**. Для радиальных/фигурных рамок
  content-зона = реальная внутренняя пустая область, не bounding box.
- Это hard-правило приёмки: наложение контента на орнамент рамки = QA FAILED
  (см. `docs/process/qa_protocol.md` «Контент только в пустой зоне фрейма»).

**ФОНОВЫЕ ИЗОБРАЖЕНИЯ — ТОЛЬКО ВСТРОЕННЫЙ OPENAI IMAGE GENERATOR
(директива пользователя 2026-07-14, ОБЯЗАТЕЛЬНО для ВСЕХ агентов).**
Все новые и редактируемые full-canvas backgrounds, scenic backdrops,
environment art, фоны меню/экранов, loading/splash art и illustrated underlays
создаются встроенным OpenAI Image Generator в Codex через
`fantasydisk-builtin-image-generator`. PixelLab для таких фоновых слоёв
запрещён. OpenAI Images API разрешён только после отдельного явного указания
Сергея Фомина, если результат встроенного генератора его не устроил. Требование
прозрачного фона у изолированной иконки, спрайта, рамки или персонажа не делает
такой ассет фоновым изображением и не меняет его профильный pipeline.

Role boundaries:
- A PM chat forms requirements and issues tasks; its workflow is `docs/process/pm_workflow.md`. Since the 2026-07-13 cutover Multica is the authoritative task queue/status/ownership source (workspace/project `FantasyDisk`, issues `FAN-*`, `multica` CLI); `docs/process/task_board.md` and `docs/tasks/*.md` are local mirrors/spec/evidence, not the source of new work. Legacy Jira (`SCRUM-*`) is a read-only historical archive (see `docs/process/jira_to_multica_cutover.md`).
- Design, Back-end, and Animator agents must do only their own discipline-specific work: Design owns art/sprites/UI visuals, Back-end owns logic/code/balance/tests, Animator owns motion/rigs/animation states.
- New work is taken from the live Multica board (project `FantasyDisk`), not from the local board or Jira. A daemon role agent works exactly the one `FAN-*` issue assigned to its exact agent UUID and never self-selects an unassigned issue. The single dispatcher reserves implementation ownership before enqueue; a direct user control chat may own an unassigned issue only after a duplicate/lock audit and an explicit owner comment. The sole exception is the autonomous QA queue-owner contract below: QA Codex Sol may select one eligible implementation parent already in `in_review`, but must own the review through a separate QA child and never replace the implementation assignee. Local mirrors are bookkeeping only. All other agents must not self-select a local `new` row, a wrong-lane issue, a blocked/hold/review-gated issue, or any issue with active owner/locked-path overlap.
- Single-owner rule: before taking or routing work, check the Multica issue status/comments/assignee/labels first, then local task file, board row, recent role-thread messages, and dirty worktree. If any recent dispatch note, `in_progress` status, owner/thread id, Multica assignee/comment, or overlapping active file/asset scope exists, do not take or resend the task.
- Parallel Codex/Claude rule: every active task belongs to exactly one execution lane, `Контур: Codex`, `Контур: Claude`, or `Контур: OtherAI`, and must record `Owner`, `Thread/Worker`, and locked files/assets/screens before work starts. Codex/Claude/other AI work autonomously only on tasks whose exact Multica assignee/owner comment matches their lane; every other lane must skip them. Review/fix work across lanes requires a separate review or bug issue after the owner records a result; do not edit the same files in both lanes at the same time.
- Design pool rule: Design main and Designer 2 are separate owners, not a shared queue. A Design task must name exactly one active Design owner/thread while in progress. The other Design thread may review only when explicitly asked, and must not start the same task or a task with overlapping source assets/screens.
- If a task needs another discipline, create/update a `.md` handoff task in `docs/tasks/` (mirroring a Multica handoff issue) and send it to the correct chat instead of doing that specialist's work directly.
- Use `docs/process/agent_role_boundaries_and_handoffs.md` as the source of truth for ownership and handoff format.
- When taking a task, update the Multica issue status/comment first, then set local mirror `Статус: in_progress` if a task file exists; when finishing, update Multica and set local mirror `done` (or `review`) with a short result summary so PM/dispatcher can sync mirrors.
- Multica is mandatory and authoritative for task tracking. Every task is a Multica issue (`FAN-*`) in the live `FantasyDisk` project, and only then may have a local `.md` spec/evidence mirror. Multica status/comment/assignee/labels must match reality. Do not create, claim, or sync work in legacy Jira. Never store any API tokens in the repository.

**АВТОНОМНАЯ QA-ОЧЕРЕДЬ — ОБЯЗАТЕЛЬНЫЙ КОНТРАКТ (директива пользователя 2026-07-15).**
QA Codex Sol (`f992a646-a8ea-4935-ba94-212595803052`) является единственным
writer/owner очереди независимого QA. В QA queue-sweep run он может сам выбрать
ровно один eligible parent `FAN-*` в `in_review`, но только после проверки
priority, dependencies, comments, existing QA children/verdicts, active runs,
exact candidate SHA в `origin/dev`, reviewer independence и locked-path
overlap. Runtime concurrency QA должен оставаться `1`; второй QA claim или
параллельный QA-dispatch запрещён.

- QA не переназначает implementation parent. Он пишет claim-comment в parent и
  создаёт или безопасно переиспользует отдельную QA child issue. Поскольку live
  Multica ACL не разрешает agent actor назначить child самому себе, штатный
  queue-sweep claim оставляет child unassigned и до `in_progress` записывает в
  неё metadata `qa_owner_id=f992a646-a8ea-4935-ba94-212595803052`,
  `qa_run_id=<current-task-id>`, `qa_candidate_sha=<exact-sha>` и
  `qa_claim_mode=autonomous_unassigned`, а также owner/run/SHA claim-comment.
  Только полный набор exact metadata + comment + текущий live run считается
  ownership. После записи QA повторно читает parent, child, metadata и comments;
  при любом конфликте отменяет собственную duplicate child. Уникальную child он
  ведёт напрямую `backlog → in_progress` в текущем run, не используя `todo` и не
  создавая второй daemon task. Это исключение не даёт право self-claim другим
  unassigned workers или implementation issues.
- Общий dispatcher может разбудить QA/сообщить о новой review-очереди, но не
  создаёт конкурирующую QA child и не назначает ту же проверку другому агенту.
- QA самостоятельно формирует risk-based plan и выполняет всю необходимую
  acceptance, focused, regression, edge-case, integration, manual/windowed,
  performance, platform и visual проверку на exact SHA. Developer report, code
  review и CI сами по себе не являются QA evidence. Тесты нужно прочитать и
  убедиться, что они действительно доказывают acceptance.
- Для визуального/UI/runtime поведения QA делает скриншоты или видео, когда они
  materially подтверждают результат, сохраняет evidence в task-owned
  `build/qa/<FAN-id>/` либо прикладывает его к Multica comment и указывает пути,
  viewport/platform/timestamp. Логи, дампы rect'ов, traces и profiler output
  прикладываются, когда они являются лучшим доказательством.
- Итоговый отчёт обязан содержать: exact SHA и environment, traceability
  acceptance→checks, фактические команды/results, manual scenarios, evidence,
  findings, `passed/failed/blocked/not tested`, residual risks, `Disk cleanup:`
  и ровно одну recommendation: `Go`, `Go with known risks` или `No-Go`.
- Каждый подтверждённый дефект или обязательное улучшение QA оформляет отдельной
  linked Multica child issue (`BUG:` / `IMPROVEMENT:`) с reproduction,
  expected/actual, environment/SHA, severity/priority, evidence, affected scope,
  acceptance criteria и recommended implementation role. QA не чинит production
  implementation в review scope; disposable probes разрешены и удаляются до
  verdict.
- `QA verdict: PASSED` переводит QA child и parent в `done`. `FAILED` завершает
  QA child с правдивым отчётом, оставляет parent в `in_review` и линкует все
  follow-up issues. Непроверенное нельзя объявлять пройденным.

**ЖИВАЯ СИНХРОНИЗАЦИЯ MULTICA — ОБЯЗАТЕЛЬНА (директива пользователя 2026-06-13, обновлено при cutover 2026-07-13).**
Пользователь управляет разработкой по Multica, поэтому Multica ВСЕГДА должна
отражать реальность. Каждый агент, который берёт, двигает или завершает работу,
ОБЯЗАН (всё через `multica` CLI; проект `FantasyDisk`, issues `FAN-*`):
0. **Новая задача** → сначала Multica issue в проекте `FantasyDisk`; локальные
   `.md` и task board обновляются только как spec/evidence mirror. Не брать работу
   из локальной доски, если в Multica нет этой задачи с owner/status.
1. **Взял в работу** → сначала `multica issue get <FAN-id> --output json` и
   подтвердить точный assignee/owner, затем `multica issue status <FAN-id>
   in_progress` + start-comment через `--content-file` с owner/thread/locked
   paths + локальный `.md` mirror `in_progress` при наличии. Не работать «в
   тени». Daemon worker берёт только назначенную ему issue; свободные issues
   резервирует и назначает единственный dispatcher.
2. **Завершил** → Multica comment + `multica issue status <FAN-id> in_review` и
   `.md` mirror `done` с резюме, если есть локальная спецификация (после
   QA-вердикта PASSED issue → `done`). Закрытая работа ОБЯЗАНА быть отражена в Multica.
3. **Передаёшь работу другому агенту (handoff)** → сначала создай/обнови Multica
   issue handoff'а и комментарий в исходной issue, затем локальный handoff-`.md`
   как mirror/spec при необходимости. Передача основной задачи без отражения в Multica запрещена.
4. **Заблокировал / переименовал / дублировал** → отрази статус и причину в
   Multica (status/comment), не оставляй расхождений `.md`↔Multica.
Правило: «не закрыл/не передал в Multica — работа не считается сделанной». Держи
синхронизацию Multica с реальностью в голове на каждом шаге. Legacy Jira
(`SCRUM-*`) — read-only архив: не создавать, не claim'ить и не синкать там работу.

**NO STALE IN-PROGRESS — MANDATORY (user directive 2026-06-28).**
Multica must show the live truth, not old intent. An issue may stay `in_progress`
only while a named worker is actively responsible for it and the latest Multica
comment proves current ownership.
- When claiming, the first Multica comment must include: `Owner`, `Thread/Worker`,
  `Lane`, `Locked paths/screens/assets`, branch/worktree, and the next concrete
  verification step.
- During long work, post a Multica heartbeat comment at least every 60 minutes or
  before switching context. The heartbeat must say whether work is continuing,
  blocked, handed off, pushed, or ready for QA.
- A worker may not keep more than one active `in_progress` issue unless the
  dispatcher comment explicitly states a combined scope and identical locked
  paths, as with paired backend/data tasks. Otherwise claim only one issue,
  finish or release it, then take the next.
- Before ending any run, the worker must leave the Multica issue in one truthful
  state: `in_review` with branch/commit/tests evidence, `done` only after QA
  PASSED, `todo` if released for another worker, or `blocked` with a precise
  reason and handoff. Leaving a stale `in_progress` claim is a process failure.
- Dispatcher/PM cleanup is allowed and expected: if an issue has no fresh
  heartbeat/result, no reachable active worker, or a worker owns multiple
  unrelated issues, return it to `todo` with a cleanup comment instead of letting
  Multica lie.

**ЖИВАЯ СИНХРОНИЗАЦИЯ GITHUB — ОБЯЗАТЕЛЬНА (директива пользователя 2026-06-28).**
Разработка ведётся с разных устройств и разными AI-агентами, поэтому GitHub
должен быть синхронизирован на границах КАЖДОЙ задачи:
1. **Перед стартом новой задачи** агент обязан проверить ветку/dirty tree,
   выполнить `git fetch origin --prune` и подтянуть актуальный `dev`
   (`git pull --ff-only origin dev` или эквивалентную безопасную интеграцию).
   Если pull невозможен из-за локального WIP/конфликта/расхождения — НЕ начинать
   новую задачу; зафиксировать blocker в Multica issue (comment/status) и попросить
   dispatcher/PM развести owner/locked paths.
2. **После завершения задачи** агент обязан прогнать проверки, обновить Multica
   issue и локальные mirrors, затем сразу сделать intentional commit и `git push`
   своей работы. Нельзя оставлять выполненную задачу только в dirty tree.
3. Multica issue нельзя переводить в финальный `done`/`in_review` как завершённый,
   пока результат не закоммичен и не запушен (или пока blocker push failure явно
   не записан в Multica).
4. Коммитить только файлы своей задачи/locked paths; чужой WIP, `.godot/`, caches,
   секреты, tokens и случайные sidecars не добавлять.
5. Force push, destructive reset/checkout и переписывание чужой истории запрещены
   без явной пользовательской команды.

**ПУШ СРАЗУ В DEV, БЕЗ ВЕТОК-ХВОСТОВ (директива пользователя 2026-07-04, все lane).**
Готовая работа НЕ хранится в дополнительных ветках — она сразу уезжает в `dev`:
1. Зелёный green-gate → немедленно `git push origin HEAD:dev` (при расхождении —
   merge/rebase от свежего `origin/dev`, повторный gate, push). Не копить готовые
   коммиты в `claude/*`/`codex/*` ветках «на потом».
2. После влития своей работы в `origin/dev` агент обязан убрать за собой:
   удалить свою рабочую ветку на origin (`git push origin --delete <branch>`,
   если она пушилась), локальную ветку в основном чекауте (`git branch -d`),
   и свой worktree с диска (`git worktree remove` + `git worktree prune`;
   собственный текущий cwd — в конце сессии или следующим прогоном).
3. Периодическая уборка хвостов разрешена и желательна: remote-ветки, полностью
   влитые в dev (`git branch -r --merged origin/dev`), локальные merged-ветки и
   worktree с чистым статусом, HEAD которых — ancestor `origin/dev`. ЖИВЫЕ
   (dirty tree / невлитые коммиты / активный владелец) ветки и worktree НЕ трогать.
4. `dev` и `main` не удалять никогда; это правило дополняет DISK HYGIENE ниже,
   не заменяет его гарды.

**СИНК ЛОКАЛЬНОГО GODOT ПОСЛЕ ПУША В DEV (директива пользователя 2026-07-14, все lane).**
Пользователь проверяет актуальную сборку в своём **локальном** Godot-редакторе, а
номер версии в углу меню читается вживую из `project.godot → config/version`
(`scripts/ui_screens.gd`). Поэтому после КАЖДОГО успешного `git push origin HEAD:dev`
агент обязан подтянуть операторскую локальную рабочую копию проекта до только что
запушенного `origin/dev`, чтобы там сразу была актуальная версия:
1. Целевой путь на этом runtime-хосте: `/Users/sergeyfomin/Documents/AI Agent`
   (канонический локальный Godot-проект оператора; это отдельный clone того же
   репозитория, НЕ agent-worktree). Если пути нет — тихо пропустить (значит хост другой).
2. Синк только безопасным fast-forward:
   `git -C "/Users/sergeyfomin/Documents/AI Agent" fetch origin` затем
   `git -C "/Users/sergeyfomin/Documents/AI Agent" merge --ff-only origin/dev`.
   НИКОГДА не делать `reset --hard`, `checkout -f`, force-pull или иное затирание —
   незакоммиченную работу оператора терять нельзя.
3. Если ff не проходит из-за рабочего дерева: застэшить/убрать ТОЛЬКО очевидный
   редакторский шум (пересейвы `project.godot` без смысловых правок, побайтово
   идентичные апстриму `*.uid`/`*.import` сайдкары) и повторить ff. При реальном
   расхождении или чужом WIP — НЕ форсить: оставить как есть и записать в финальном
   комментарии Multica, что локальный mirror требует ручного `pull`.
4. Godot можно не закрывать; оператор увидит новую версию после `Project → Reload
   Current Project`. В финальном комментарии задачи указать, что локальный Godot
   синкнут на `<sha>` (в углу меню — актуальный `config/version`).

**DISK HYGIENE — MANDATORY (user directive 2026-06-28).**
Agents must clean up their own temporary disk usage before reporting a task as
done, blocked, or handed off. Disk space is part of task completion.
- Prefer one clearly named task worktree/clone under `D:\FantasyDisk_worktrees\`
  or `D:\FantasyDisk-QA-<issue>`; do not create multiple abandoned clones for
  retries. Reuse the task worktree when possible.
- At the end of the task, remove transient caches created only for the task:
  `.godot/` in disposable worktrees, Godot `--user-data-dir` folders, temporary
  QA clones, generated import caches, `%TEMP%` scratch files, Python
  `__pycache__`, and tool logs that are not committed evidence.
- If the worktree contains no unpushed task result and is not needed for an
  active handoff, remove it with `git worktree remove --force <path>` (for
  registered worktrees) or delete the disposable clone directory. Then run
  `git worktree prune` from the main repository.
- Never delete the main project checkout, another active worker's worktree,
  locked Claude/Codex worktrees, or any directory with uncommitted/unpushed
  task-owned changes. If unsure, leave it and record the path/status in the
  Multica issue final comment.
- QA agents that only verify code should delete their disposable QA worktree or
  at least its `.godot/` cache after posting the Multica verdict. Implementation
  agents should keep only committed/pushed source changes and committed evidence;
  local build/import/userdata artifacts must not remain as disk debt.
- Final Multica/task reports must include `Disk cleanup:` with one of:
  `removed <paths>`, `none created`, or `blocked by lock <path> <approx size>`.
  A task is process-incomplete if it leaves a disposable FantasyDisk checkout or
  multi-hundred-MB cache without this note.

**CODEX THREAD HYGIENE — MANDATORY (user directive 2026-07-01).**
Codex chats created as one-off automation/agent worker threads must archive
themselves after the task run is truthfully finished. Codex currently exposes
archive/unarchive, not hard deletion, so "delete finished worker chat" means
archive it from the active thread list.
- After Multica/GitHub sync, local mirrors, memory updates, test evidence, disk
  cleanup, and final status are complete, the worker must use `tool_search` if
  needed to expose `set_thread_archived`, then call `codex_app.set_thread_archived`
  with `archived: true` and no `threadId` to archive its current thread.
- This must be the last tool action before the final response for cron-created
  role workers (`fantasydisk-codex-*-agent`) and other one-task Codex workers.
- Do not archive permanent dispatcher/watch chats, PM chats, user-facing control
  chats, active/running workers, or unclear threads. Archive only the current
  worker thread or another thread that is clearly idle/notLoaded and completed.
- Final reports should include `Thread cleanup:` with `archived current worker
  thread`, `not a disposable worker thread`, or `archive unavailable`.

Versioning:
- `main` is the stable `0.1` line.
- `dev` is the active working branch for the current `0.1.x` line.
- All implementation tasks should be done on `dev` unless a task explicitly says otherwise.
- Check the current branch before making changes; do not do ordinary feature work directly on `main`.

Synchronous landing to dev (updated 2026-07-13):
- Repo-owned background autoland is retired. Do not install `post-commit`
  landing hooks or detach smoke/test/push processes.
- Run the task-required quality gate synchronously, fetch current `origin/dev`,
  integrate safely, push the verified commit to `dev`, then wait for exact-SHA
  GitHub checks and record their result in Multica.
- A red local or GitHub gate is not landed/complete evidence. Fix it on the task
  branch and rerun; never rely on a future background notification after the
  owning Multica turn exits.
- This is still only the engineering green gate. Independent QA and truthful
  Multica status remain mandatory.

Full autonomy (user directive, 2026-06-12):
- ALL agents (Claude chats, board workers, QA, Codex threads) work autonomously:
  do NOT ask the user questions, do NOT wait for user input or confirmation.
- User directive 2026-06-28: all agents have approval to work with full
  in-repository access for their claimed Multica issue. Pull before starting,
  edit/test/docs autonomously, then commit and push task-owned files without
  asking the user. If the platform shows an approval prompt that cannot be
  bypassed by instruction, stop only long enough to satisfy the runtime; do not
  turn routine task decisions into user questions.
- The user pre-approved all in-scope changes. If a requirement is ambiguous,
  make the most reasonable product decision yourself, implement it, and record
  the decision + rationale in the task file report.
- If something truly cannot proceed (missing asset, broken dependency,
  conflicting requirement), do not stall: mark the task `blocked` with a precise
  reason in Multica, create a child handoff issue if another role can unblock it,
  release stale assignment, and move to the next eligible task. PM reviews blocked items.
- Questions for the user are allowed ONLY for destructive/irreversible actions
  outside the repo (deleting user files, external accounts, payments) — these
  are out of scope for executors anyway.

Feature block:
- **ФРИЗ СНЯТ релизом v0.1.5 (2026-06-15).** Пользовательская директива
  2026-07-03: все задачи, добавляемые пользователем в любые чаты, сразу
  заводятся в активный Multica-проект `FantasyDisk` (issues `FAN-*`) и получают
  metadata `release` активного релиза. Активный релиз-таргет — `0.2.2`; всегда
  проверяй live Multica board перед auto-pull/dispatch. Активные issues берутся
  обычным порядком из Multica. Плановые версии `0.1.8` и `0.1.9`
  отменены/superseded; далее используется SemVer patch-линия `0.2.1`, `0.2.2`, ...
- Механизм сохраняется: перед стабилизацией следующего релиза PM снова включает
  фриз явной директивой/hold-marker; без такого marker новые задачи идут в
  Multica `todo`, а не в `backlog`.

Use Godot 4 GDScript and keep systems compatible with the source design:
- FantasyDisk is a 2D top-down loot-action survival roguelite with RPG buildcraft.
- The MVP prioritizes Berserk, Dark Mage, Guitarist, melee enemy, shooter enemy, and summoner enemy.
- Berserk should trend toward melee cone/AoE weapons, not generic permanent bullet shooting.
- Spreadsheet stat names and formulas are the long-term authority for balancing.

Project practices:
- Keep code split into focused scenes and scripts.
- Prefer data-driven character/enemy/weapon configuration where practical.
- Keep prototype visuals simple until art direction exists.
- **Создание/редактирование скиллов — через `skill-creator`.** Держи
  `SKILL.md` коротким, переносимым между Windows/Mac/Linux, и синхронизируй
  локальные скиллы в git под `skills/`.
- **Код-ревью, performance, Windows stutter и quality-process — через
  `fantasydisk-code-quality-director`** (repo mirror:
  `skills/codex/fantasydisk-code-quality-director/`). После любых изменений
  code/test/tool/export запускай `python3 tools/quality_gate.py --profile changed`;
  полный набор — `--profile full`, Windows-профиль обязан выполняться нативно на
  Windows. Все Godot-команды автоматизации идут через `tools/godot_gate.py`,
  проверки и landing выполняются синхронно, без фонового autoland.
- **Изменения интерфейса — ТОЛЬКО через скилл `fantasydisk-ui-director`**
  (Codex skill, `~/.codex/skills/fantasydisk-ui-director/`). Перед любым
  внедрением/перерисовкой UI сначала создать generator-routed mockup package со
  всеми элементами, точными зонами контента, safe margins и
  responsive-правилами: фон/illustrated underlay — встроенный OpenAI Image
  Generator, нефоновые рамки/панели/кнопки/иконки — PixelLab MCP. Показать
  превью в чате при наличии PNG, затем воспроизводить расположение в Godot по
  mockup/spec. Единый стиль всех экранов: D&D + Dark Fantasy Dragon,
  отталкиваться от текущих красивых кнопок; старые/ручные пайплайны генерации
  макетов не использовать как fallback.
- **PixelLab-first для будущих redraw-задач (SCRUM-689).** Перерисовки
  персонажей, монстров, элиток, боссов, animation/source packs, UI frame/source
  kits и других redraw source assets по умолчанию идут через PixelLab MCP /
  PixelLab-ориентированные skills. Фоновые изображения из глобального правила
  2026-07-14 явно исключены из PixelLab redraw scope. Старый generic
  OpenAI/asset-generator путь
  нельзя использовать как fallback для redraw, если Multica issue/task прямо не
  записывает исключение с причиной (`OpenAI Images override`, `existing source
  reuse`, `PixelLab unavailable`, и т.п.). Исключение должно быть видно в Multica
  comment, task mirror/result и evidence.
- **Генерация нефоновой графики/ассетов — через
  `fantasydisk-asset-generator` только для задач вне PixelLab-redraw scope или
  при явном Multica issue override**
  (Codex skill, `~/.codex/skills/fantasydisk-asset-generator/`, SCRUM-324):
  нефоновые персонажи, объекты, спрайты, иконки, рамки и UI-компоненты следуют
  PixelLab-маршруту навыка. Исторический `scripts/generate_asset.py` (OpenAI
  Images API) не является fallback и используется только по отдельному явному
  указанию пользователя. Для разрешённых non-redraw/override задач все
  изолированные ассеты — на ПРОЗРАЧНОМ фоне; исходник сохраняется в
  `docs/design/references/<тема>/`, затем внедряется в `assets/`. Стиль — D&D +
  Dark Fantasy Dragon (см. UI Overhaul SCRUM-327).
- **Постеры/инфографика/UI-элементы с текстом поверх AI-картинки — через скилл
  `content-zone-image-compositor`** (Codex skill,
  `~/.codex/skills/content-zone-image-compositor/`, repo mirror:
  `skills/codex/content-zone-image-compositor/`). Для UI-элементов сначала
  создать `ui_plan.json`: что где находится, размеры, min/max шрифты,
  content-зоны, нужен ли scrollbar, помещается ли весь контент или задачу нужно
  пересмотреть. Прогнать `validate_ui_layout_plan.py` и продолжать генерацию
  только при `decision: ready_for_image`; при `revise_task` сначала менять
  размеры/скролл/состав. Затем создать `layout.json` с точными content zones,
  генерировать картинку как неизменяемый frame/layout layer вокруг этих зон и
  вставлять текст/иконки только внутрь зон bundled-скриптом. Стиль UI-элементов:
  dark fantasy / dragon specific / D&D, строго, красиво, брутально, эпично, но
  без крика и лишней детализации. После генерации запрещено дорисовывать новые
  карточки, рамки, панели или подложки поверх красивого layout, если пользователь
  явно не запросил новый дизайн-проход.
- **Анимации персонажей/монстров/элиток/боссов — через скилл
  `fantasydisk-pixellab-animation-integrator`**
  (Codex skill, `~/.codex/skills/fantasydisk-pixellab-animation-integrator/`).
  Основной путь: брать готовые idle/move анимации из PixelLab по tag/name,
  импортировать 8 направлений, нормализовать full-frame PNG, собрать
  `SpriteFrames`, подключить direction-aware movement/idle и animated Hero Select
  preview. Минимум для каждой анимированной сущности: движение `move/walk` 5+
  кадров; для playable character preview — clockwise 8-direction rotation на
  экране выбора. Animator прогоняет focused animation/Hero Select smoke tests.
- **Баланс классов и оружия — через скилл
  `fantasydisk-class-balance-director`**
  (Codex skill, `~/.codex/skills/fantasydisk-class-balance-director/`). Каждый
  класс балансируется как сумма трёх selectable weapons, а не как отдельное
  оружие: суммарная эффективность кита должна быть сопоставима по solo-target,
  AoE/crowd-clear и defensive/survivability механикам. Все классы сравниваются
  между собой по total kit score трёх оружий. При провале оси сначала менять
  механику оружия/кита (геометрия удара, target pattern, контроль, sustain,
  defensive window, summon behavior и т.п.), а не только множители урона; при
  этом каждое из трёх оружий должно сохранять отличающийся gameplay/niche.
- Run the certifying changed profile after code/gameplay/test/tool changes:
  `python3 tools/quality_gate.py --profile changed --changed-ref origin/dev`.
  Для итерации отдельный smoke можно запустить через
  `python3 tools/godot_gate.py --headless --path . --script res://tests/<smoke>.gd`.
  Прямой запуск Godot из автоматизации запрещён даже для одиночного теста:
  semaphore защищает параллельных агентов, а timeout не оставляет зависший run.
  Бинарь сейчас **Godot 4.7** (`config/features="4.7"`).
- Do not commit `.godot/`.
