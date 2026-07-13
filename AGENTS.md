# FantasyDisk Agent Instructions

This repository is a Godot 4 project for FantasyDisk.

Before making gameplay, balance, character, enemy, UI, or progression changes, read:
- `docs/process/ai_agent_memorandum.md` for the compact onboarding protocol for any AI agent.
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/gdd_source.md` when exact GDD wording matters.
- `docs/design/mechanics_extract.md` when formulas, classes, stats, weapons, or MVP screens matter.
- `docs/design/current_game_state.md` for the implemented game state.
- `docs/design/content_registry.md` for canonical entity IDs and names.
- `docs/process/agent_role_boundaries_and_handoffs.md` for Design/Back-end/Animator ownership and cross-chat handoff rules.
- `docs/process/versioning_and_branching.md` for the active version/branch policy.

Autonomy and approval:
- The user pre-approves all in-scope project changes requested in task files or direct prompts.
- Full in-repository autonomy is granted by user directive (2026-06-28). Agents must not stop for confirmation before commands or file operations needed for claimed FantasyDisk tasks inside this repository: read/write/edit/create/delete project files, run shell helpers, Godot/Python tests/imports, asset/mockup generation required by skills, Jira helpers/REST calls, and normal Git task workflow (`fetch`, `pull`, `rebase`, `status`, `diff`, `add`, `commit`, `push`). Do not ask for permission on Codex approval prompts for in-scope project work. Hard limits remain: never expose or commit secrets/tokens, do not perform destructive actions outside the project, do not damage external accounts/payments, and avoid force-push/history rewrite unless there is no normal Git alternative and the task explicitly requires it. If a claimed task requires deleting or replacing project files, do it and record the rationale in Jira/task evidence.
- Do not stop to ask for confirmation when the requirement is clear enough to implement. Make a reasonable product/engineering decision, implement it, test it, and document it.
- Full in-repo execution access is user-approved for all agents (directive 2026-06-28): do not ask for confirmation for normal Jira/task work, including GitHub sync, Jira claim/status updates, file edits inside the project, tests, documentation updates, commits, and pushes of the agent's own task files.
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

Role boundaries:
- A PM chat forms requirements and issues tasks; its workflow is `docs/process/pm_workflow.md`. Since 2026-06-27 Jira is the authoritative task queue/status/ownership source; `docs/process/task_board.md` and `docs/tasks/*.md` are local mirrors/spec/evidence, not the source of new work.
- Design, Back-end, and Animator agents must do only their own discipline-specific work: Design owns art/sprites/UI visuals, Back-end owns logic/code/balance/tests, Animator owns motion/rigs/animation states.
- New work is taken from Jira current sprint, not from the local board. Role agents may auto-pull exactly one eligible Jira issue for their role/lane by running `python3 tools/jira_next_task.py --role <backend|design|animator|qa> --lane <codex|claude|otherai> --claim --worker <agent-id> --json`, then updating local mirrors only as bookkeeping. They must not self-select a local `new` row, a wrong-lane Jira issue, a blocked/hold/review-gated issue, or any issue with active owner/locked-path overlap.
- Single-owner rule: before taking or routing work, check the Jira issue/status/comments/assignee/labels first, then local task file, board row, recent role-thread messages, and dirty worktree. If any recent dispatch note, `in_progress` status, owner/thread id, Jira assignee/comment, or overlapping active file/asset scope exists, do not take or resend the task.
- Parallel Codex/Claude rule: every active task belongs to exactly one execution lane, `Контур: Codex`, `Контур: Claude`, or `Контур: OtherAI`, and must record `Owner`, `Thread/Worker`, and locked files/assets/screens before work starts. Codex/Claude/other AI work autonomously only on tasks whose Jira labels/comments match their lane and which they have claimed in Jira; every other lane must skip them. Review/fix work across lanes requires a separate review or bug task after the owner records a result; do not edit the same files in both lanes at the same time.
- Design pool rule: Design main and Designer 2 are separate owners, not a shared queue. A Design task must name exactly one active Design owner/thread while in progress. The other Design thread may review only when explicitly asked, and must not start the same task or a task with overlapping source assets/screens.
- If a task needs another discipline, create/update a `.md` handoff task in `docs/tasks/` and send it to the correct chat instead of doing that specialist's work directly.
- Use `docs/process/agent_role_boundaries_and_handoffs.md` as the source of truth for ownership and handoff format.
- When taking a task, update Jira status/comment first, then set local mirror `Статус: in_progress` if a task file exists; when finishing, update Jira and set local mirror `done` (or `review`) with a short result summary so PM/dispatcher can sync mirrors.
- Jira is mandatory and authoritative for task tracking. Follow `docs/process/jira_sync.md`: every task starts as a Jira issue (`SCRUM-*`), belongs to the live current sprint by default, and only then may have a local `.md` spec/evidence mirror. Jira status/comment/assignee/labels must match reality. Never store Jira API tokens in the repository.

**ЖИВАЯ СИНХРОНИЗАЦИЯ JIRA — ОБЯЗАТЕЛЬНА (директива пользователя 2026-06-13).**
Пользователь управляет разработкой по Jira, поэтому Jira ВСЕГДА должна отражать
реальность. Каждый агент, который берёт, двигает или завершает работу, ОБЯЗАН:
0. **Новая задача** → сначала Jira issue в проекте `SCRUM`; локальные `.md` и
   task board обновляются только как spec/evidence mirror. Не брать работу из
   локальной доски, если Jira не содержит эту задачу и owner/status.
1. **Взял в работу** → Jira issue переведён/прокомментирован как «В работе»
   с owner/thread/locked paths + локальный `.md` mirror `in_progress` при наличии.
   Не работать «в тени», не отразив это в Jira.
   Авто-взятие задач делается только через Jira current sprint и claim-first:
   `python3 tools/jira_next_task.py --role <role> --lane <lane> --claim --worker <id> --json`.
2. **Завершил** → Jira comment/status + `.md` mirror `done` с резюме, если есть
   локальная спецификация (тикет → «Контроль качества»;
   после QA-вердикта PASSED → «Готово»). Закрытая работа ОБЯЗАНА быть закрыта в Jira.
3. **Передаёшь работу другому агенту (handoff)** → сначала создай/обнови Jira
   issue handoff'а и комментарий в исходном тикете, затем локальный handoff-`.md`
   как mirror/spec при необходимости. Передача основной задачи без отражения в Jira запрещена.
4. **Заблокировал / переименовал / дублировал** → отрази статус и причину в Jira
   (status/comment), не оставляй расхождений `.md`↔Jira.
5. В КОНЦЕ ЛЮБОГО прогона со сменой статусов — `python3 tools/jira_board_sync.py`
   (идемпотентен); если изменился `jira_sync_map.json` — закоммить.
Правило: «не закрыл/не передал в Jira — работа не считается сделанной». Держи
синхронизацию Jira с реальностью в голове на каждом шаге.

**NO STALE IN-PROGRESS — MANDATORY (user directive 2026-06-28).**
Jira must show the live truth, not old intent. An issue may stay in `В работе`
only while a named worker is actively responsible for it and the latest Jira
comment proves current ownership.
- When claiming, the first Jira comment must include: `Owner`, `Thread/Worker`,
  `Lane`, `Locked paths/screens/assets`, branch/worktree, and the next concrete
  verification step.
- During long work, post a Jira heartbeat at least every 60 minutes or before
  switching context. The heartbeat must say whether work is continuing, blocked,
  handed off, pushed, or ready for QA.
- A worker may not keep more than one active `В работе` issue unless the
  dispatcher comment explicitly states a combined scope and identical locked
  paths, as with paired backend/data tasks. Otherwise claim only one issue,
  finish or release it, then take the next.
- Before ending any run, the worker must leave the Jira issue in one truthful
  state: `Контроль качества` with branch/commit/tests evidence, `Готово` only
  after QA PASSED, `К выполнению` if released for another worker, or blocked
  with a precise reason and handoff. Leaving a stale `В работе` claim is a
  process failure.
- Dispatcher/PM cleanup is allowed and expected: if an issue has no fresh
  heartbeat/result, no reachable active worker, or a worker owns multiple
  unrelated issues, return it to `К выполнению` with a cleanup comment instead
  of letting Jira lie.

**ЖИВАЯ СИНХРОНИЗАЦИЯ GITHUB — ОБЯЗАТЕЛЬНА (директива пользователя 2026-06-28).**
Разработка ведётся с разных устройств и разными AI-агентами, поэтому GitHub
должен быть синхронизирован на границах КАЖДОЙ задачи:
1. **Перед стартом новой задачи** агент обязан проверить ветку/dirty tree,
   выполнить `git fetch origin --prune` и подтянуть актуальный `dev`
   (`git pull --ff-only origin dev` или эквивалентную безопасную интеграцию).
   Если pull невозможен из-за локального WIP/конфликта/расхождения — НЕ начинать
   новую задачу; зафиксировать blocker в Jira/comment и попросить dispatcher/PM
   развести owner/locked paths.
2. **После завершения задачи** агент обязан прогнать проверки, обновить Jira и
   локальные mirrors, затем сразу сделать intentional commit и `git push` своей
   работы. Нельзя оставлять выполненную задачу только в dirty tree.
3. Jira issue нельзя переводить в финальный `done`/`review-ready` как завершённый,
   пока результат не закоммичен и не запушен (или пока blocker push failure явно
   не записан в Jira).
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
  task-owned changes. If unsure, leave it and record the path/status in the Jira
  final comment.
- QA agents that only verify code should delete their disposable QA worktree or
  at least its `.godot/` cache after posting the Jira verdict. Implementation
  agents should keep only committed/pushed source changes and committed evidence;
  local build/import/userdata artifacts must not remain as disk debt.
- Final Jira/task reports must include `Disk cleanup:` with one of:
  `removed <paths>`, `none created`, or `blocked by lock <path> <approx size>`.
  A task is process-incomplete if it leaves a disposable FantasyDisk checkout or
  multi-hundred-MB cache without this note.

**CODEX THREAD HYGIENE — MANDATORY (user directive 2026-07-01).**
Codex chats created as one-off automation/agent worker threads must archive
themselves after the task run is truthfully finished. Codex currently exposes
archive/unarchive, not hard deletion, so "delete finished worker chat" means
archive it from the active thread list.
- After Jira/GitHub sync, local mirrors, memory updates, test evidence, disk
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

Auto-land to dev (user directive, 2026-07-03):
- КАЖДЫЙ чат/агент сразу лендит свой коммит в `dev` — локально И на `origin` —
  но ТОЛЬКО если коммит зелёный (проходит `tests/runtime_smoke_test.gd`).
- Механизм: repo-tracked `post-commit` хук `.githooks/post-commit`, включённый
  через `core.hooksPath` (ставит `scripts/onboard.sh` в каждом клоне/worktree).
  Хук фоновый: коммит агента возвращается мгновенно, smoke+ленд идут в фоне,
  живую ветку чата НЕ трогают (ff-пуш или merge в одноразовом temp worktree).
- Красный smoke → коммит НЕ лендится, остаётся на ветке чата до следующего
  зелёного. Лог: `<git-common-dir>/autoland.log`.
- Выключатели: `FSD_NO_AUTOLAND=1` (разово/сессионно), `git config --unset
  core.hooksPath` (в клоне), `FSD_AUTOLAND_SKIP_SMOKE=1` (лендить без smoke).
- Это НЕ отменяет QA-борд: смоук — минимальный green-gate, не полноценная
  приёмка; статусы Jira/доски ведём как раньше.

Full autonomy (user directive, 2026-06-12):
- ALL agents (Claude chats, board workers, QA, Codex threads) work autonomously:
  do NOT ask the user questions, do NOT wait for user input or confirmation.
- User directive 2026-06-28: all agents have approval to work with full
  in-repository access for their claimed Jira issue. Pull before starting,
  edit/test/docs autonomously, then commit and push task-owned files without
  asking the user. If the platform shows an approval prompt that cannot be
  bypassed by instruction, stop only long enough to satisfy the runtime; do not
  turn routine task decisions into user questions.
- The user pre-approved all in-scope changes. If a requirement is ambiguous,
  make the most reasonable product decision yourself, implement it, and record
  the decision + rationale in the task file report.
- If something truly cannot proceed (missing asset, broken dependency,
  conflicting requirement), do not stall: mark the task `blocked` with a precise
  reason on the board, create a handoff if another role can unblock it, and move
  to the next task. PM reviews blocked items.
- Questions for the user are allowed ONLY for destructive/irreversible actions
  outside the repo (deleting user files, external accounts, payments) — these
  are out of scope for executors anyway.

Feature block:
- **ФРИЗ СНЯТ релизом v0.1.5 (2026-06-15).** Пользовательская директива
  2026-07-03: все задачи, добавляемые пользователем в любые чаты, сразу
  заводятся в live active Jira sprint на board 1 и получают fixVersion активного
  спринта/релиза. На 2026-07-03 live sprint: `Спринт 0.2.1`; всегда проверяй
  live Jira active sprint перед auto-pull/dispatch. Current-sprint Jira issues
  берутся обычным порядком через Jira-pull claim-first. Плановые версии `0.1.8`
  и `0.1.9` отменены/superseded; далее используется SemVer patch-линия
  `0.2.1`, `0.2.2`, ...
- Механизм сохраняется: перед стабилизацией следующего релиза PM снова включает
  фриз явной директивой/hold-marker; без такого marker sync держит новые задачи
  в активном спринте, а не в бэклоге.

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
  внедрением/перерисовкой UI сначала создать OpenAI-API-generated mockup страницы
  со всеми элементами, точными зонами контента, safe margins и responsive-правилами,
  показать превью в чате при наличии PNG, затем воспроизводить расположение в
  Godot по mockup/spec. Единый стиль всех экранов: D&D + Dark Fantasy Dragon,
  отталкиваться от текущих красивых кнопок; старые/ручные пайплайны генерации
  макетов не использовать как fallback.
- **PixelLab-first для будущих redraw-задач (SCRUM-689).** Перерисовки
  персонажей, монстров, элиток, боссов, animation/source packs, UI frame/source
  kits и других redraw source assets по умолчанию идут через PixelLab MCP /
  PixelLab-ориентированные skills. Старый generic OpenAI/asset-generator путь
  нельзя использовать как fallback для redraw, если Jira/task прямо не записывает
  исключение с причиной (`OpenAI Images override`, `existing source reuse`,
  `PixelLab unavailable`, и т.п.). Исключение должно быть видно в Jira comment,
  task mirror/result и evidence.
- **Генерация графики/ассетов — через `fantasydisk-asset-generator` только для
  задач вне PixelLab-redraw scope или при явном Jira override**
  (Codex skill, `~/.codex/skills/fantasydisk-asset-generator/`, SCRUM-324):
  `scripts/generate_asset.py --prompt "<...>" --output <тема/файл> --size <WxH>
  --quality high` (OpenAI Images API, модель `gpt-image-2`, PNG). Для разрешённых
  non-redraw/override задач все ассеты — на ПРОЗРАЧНОМ фоне; исходник сохраняется
  в `docs/design/references/<тема>/` (для единообразия на будущее), затем
  внедряется в `assets/`. Стиль — D&D + Dark Fantasy Dragon (см. UI Overhaul
  SCRUM-327).
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
