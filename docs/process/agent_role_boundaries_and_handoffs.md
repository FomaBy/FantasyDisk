# Agent Role Boundaries And Handoffs

Обновлено: 2026-06-27

Этот документ задает правило работы для всех специализированных чатов FantasyDisk:
`Design`, `Back-end`, `Animator`, `QA`.

Задачи формирует PM-чат/другая LLM по регламенту `docs/process/pm_workflow.md`.
Активен текущий Jira sprint на board 1 (на 2026-06-27 локальные mirrors показывают
`Спринт 0.1.7`): v0.1.5 выпущен, feature block 0.1.5 снят. С 2026-06-27
Jira проект `SCRUM` является authoritative task queue/status/owner source.
Новые задачи текущего спринта берутся только из активного Jira sprint. PM/Documentation
dispatcher может маршрутизировать задачи вручную, но role agents также могут
автоматически брать одну eligible задачу своей роли/контура через Jira-pull
claim-first, с проверкой зависимостей и активного владельца.
`docs/tasks/*.md` и `docs/process/task_board.md` — локальные mirrors/spec/evidence
и dashboard/cache.

При взятии задачи исполнитель сначала обновляет Jira issue/comment/status, затем
локальный task mirror (`Статус: in_progress`) при наличии. По завершении —
Jira + mirror `done` (или `review`) с коротким резюме результата. Закрытие
задачи — ответственность исполнителя/ревьюера: dispatcher не ставит `done` за
агента, а только синхронизирует уже записанный в Jira/task результат или QA-вердикт.

Любой агент, меняющий task status или создающий handoff/bug/QA task, обязан
сначала проверить/создать `Jira: SCRUM-*`, обновить Jira status/comment, затем
обновить локальный mirror. Jira API token нельзя записывать в репозиторий или
task-файлы.

## Живая Синхронизация Jira (директива пользователя 2026-06-13)

Пользователь управляет разработкой по Jira — она ОБЯЗАНА всегда отражать
реальность. На каждом шаге работы агент держит Jira синхронной:
- новая задача → сначала Jira issue, затем локальный `.md`/board mirror;
- взял задачу → Jira `in_progress`/comment с owner/thread/locked paths, затем mirror;
- завершил → `done` + sync (тикет «Контроль качества» → после QA PASSED «Готово»);
- **передаёшь основную работу другому агенту** → создаёшь/обновляешь Jira issue
  handoff'а И комментарием в ИСХОДНОМ Jira-тикете отмечаешь, кому и что передано
  (ключ handoff'а), затем локальный handoff-`.md` mirror при необходимости;
- заблокировал/дубль/superseded → отрази статусом и комментарием в Jira.
Правило: «не закрыл/не передал в Jira — работа не считается сделанной».

## Главное Правило

Каждый агент делает только свою часть работы. Если для завершения задачи нужен кусок работы другого специалиста, агент не должен сам делать чужую часть "как получится". Он должен:

1. Выполнить свою часть.
2. Создать или обновить Jira issue/handoff comment для другого специалиста.
3. Создать или обновить локальную `.md` mirror-задачу в `docs/tasks/`, если
   нужны подробная спецификация или evidence.
4. Четко описать, что нужно другому специалисту.
5. Передать задачу в нужный чат.
6. В своей финалке указать, что передано и куда.

Пользователь заранее одобрил in-scope изменения, поэтому агенты не спрашивают разрешение на работу. Но cross-discipline работу нужно передавать правильному агенту.

## Single-owner / Jira-pull Lock

Новая работа попадает к исполнителю только из Jira current sprint. Локальная
доска не является очередью. Роль-агенты не выбирают `new` rows из
`docs/process/task_board.md`, но могут автоматически claim'ить ровно одну
eligible Jira issue своей роли/контура через:

```bash
python3 tools/jira_next_task.py \
  --role <backend|design|animator|qa> \
  --lane <codex|claude|otherai> \
  [--required-label <worker-scope>] \
  --claim \
  --worker <thread-or-worker-id> \
  --json
```

Jira-pull разрешён только для issue в активном sprint, status category `To Do`,
с role label, matching lane label, без `hold/user-hold/blocked`, без assignee и
без признаков чужого owner/locked-path overlap. Claim-first comment/status в
Jira является lock. После успешного claim агент обновляет локальный `.md`/board
mirror только как bookkeeping.

PM/Documentation dispatcher остаётся нужен для декомпозиции, handoff, спорных
owner cases, duplicate cleanup, зеркал и ручного назначения задач, но он больше
не является единственным способом выдать обычную unowned current-sprint задачу.

Для параллельной работы Codex и Claude каждая активная задача должна иметь
execution-lane metadata:

```text
Контур: Codex | Claude
Owner: <роль>/<thread или worker> | unassigned
Thread: <Codex thread id> | <Claude chat/worker id> | n/a
Locked paths: <основные файлы/папки/ассеты/экраны>
```

Перед dispatch или взятием задачи обязательно проверить:

- Jira issue: status, assignee, labels, sprint, comments, linked issues;
- строку `docs/process/task_board.md`;
- `Статус`, `Исполнитель`, `Dispatch`, `Owner`, `Thread` и свежие логи в task-файле;
- `Контур` и `Locked paths` в task-файле или board note;
- Jira key/status/комментарии через `docs/process/jira_sync.md` и локальный sync map;
- последние сообщения всех role threads этой роли;
- dirty worktree и пересекающиеся файлы/ассеты/экраны.

Задачу нельзя брать или повторно отправлять, если есть хотя бы один сигнал
активного владельца: `in_progress`, свежий dispatch note, thread id, Jira
assignee/comment, незавершённый role-thread heartbeat по этой задаче, или
пересечение основных файлов/ассетов с активной задачей. В сомнительном случае
dispatcher оставляет задачу без dispatch и пишет Jira/PM/board note вместо параллельной
работы.

При dispatch или Jira-pull claim owner фиксируется в явном виде:

- в task-файле: `Dispatch: отправлено <Role>/<Thread name> (<thread id>) <YYYY-MM-DD HH:MM>`;
- в task-файле: `Контур`, `Owner`, `Thread`, `Locked paths` должны совпадать с
  фактическим исполнителем и scope;
- на board: роль/примечание должны показывать конкретного владельца, если таких
  владельцев несколько;
- в Jira: status/comment должен отражать, кто взял работу, каким способом
  (`dispatch` или `Jira-pull`), lane/role/thread-or-worker и какой handoff
  создан, если работа передана.

Active claim health is mandatory. `В работе` means a live worker is still
responsible now, not that somebody once intended to work on the issue.

- The claim/start comment must include owner/thread, lane, locked paths,
  branch/worktree, and next verification step.
- Long work requires a Jira heartbeat at least every 60 minutes and before the
  worker switches context or ends the run.
- A worker may hold only one unrelated active issue. Multiple active Jira issues
  require an explicit dispatcher comment that they are one combined scope with
  shared locked paths.
- Before stopping, the worker must move the issue to a truthful state:
  `Контроль качества` with branch/commit/tests, `Готово` only after QA PASSED,
  `К выполнению` if released, or blocked/handoff with a precise reason.
- Dispatcher cleanup may release stale claims back to `К выполнению` when Jira
  lacks a fresh heartbeat/result, active worker evidence, or single-owner
  consistency.

## Codex И Claude Параллельно

Codex и Claude могут работать одновременно в одной ветке `dev`, но не над одной
задачей, проблемой или locked path.

- Codex role thread работает автономно только если задача явно помечена
  `Контур: Codex`/label `codex`, была dispatched на этот thread или успешно
  claimed этим thread через Jira-pull, и не имеет свежего Claude/OtherAI
  owner/comment по тому же scope.
- Claude Code/Claude worker работает автономно только если задача явно помечена
  `Контур: Claude`/label `claude`, была assigned/claimed этим worker, или
  является отдельной review/bug задачей после Codex-result.
- Нельзя превращать review в параллельную реализацию. Claude review Codex-работы
  начинается после Codex `done/review`, а найденные проблемы оформляются как
  отдельные `bug_` или follow-up tasks с собственным owner.
- Если Codex видит, что Claude уже изменяет один из locked paths, Codex не
  начинает работу: помечает задачу `blocked` или оставляет `new` с note о
  конфликте owner/scope.
- Если Claude видит `Контур: Codex`, `Dispatch` на Codex thread или Codex WIP в
  Jira/task mirror, он не берёт этот issue и не правит те же файлы без
  отдельной review/bug задачи.
- Если оба контура нужны в одной фиче, PM делит работу на цепочку задач:
  source/design -> runtime/backend -> animation -> QA/review. Каждая задача имеет
  свой owner и свои locked paths; handoff связывает их через Jira comments.
- Documentation dispatcher не делает реализацию и не закрывает работу за role
  agents. Его автономия ограничена routing/sync/dedupe/owner notes.

Dirty worktree считается активным контекстом разработки. Агент может продолжать
только свои изменения или явно связанные файлы своей задачи. Любые чужие dirty
files в locked paths другого контура блокируют старт до результата owner или
новой dispatcher-разбивки.

## Design Pool: Design main и Designer 2

`Design main` и `Designer 2` — два отдельных исполнителя, а не одна общая
очередь. У Design-задачи в любой момент может быть только один активный владелец.
Для auto-pull Design-задачи должны иметь дополнительный Jira label:
`design-main` для Design main или `designer2` для Designer 2. Обычный общий
label `design` без worker-scope label не даёт права автоматического взятия
Design-задачи; её должен разметить PM/dispatcher.

- `Design main` обычно получает крупные visual direction/UI-source/style-anchor
  задачи, где важны цельный арт-дирекшен, mockup/spec, источники и handoff.
- `Designer 2` обычно получает параллельные, файл-изолированные Design-задачи:
  cleanup, отдельные asset packs, visual QA fixes, source-sheet preparation,
  повторяемые генерации по уже принятому стилю.
- Designer 2 не берёт задачу, если Design main уже упомянут в `Dispatch`,
  `Исполнитель`, результате или свежей role-thread истории, даже если board row
  всё ещё выглядит `new/review`.
- Design main не берёт задачу, если Designer 2 уже указан владельцем или есть
  активная Designer 2 работа с тем же экраном, source pack, frame kit, character
  set или asset directory.
- Второй дизайнер может делать review только по явному dispatch/review note от
  PM/dispatcher. Review не означает право переписывать source package без новой
  задачи или handoff.

## Asset Backup Hygiene

Архивные копии игровых PNG/ресурсов внутри репозитория не должны входить в
Godot import scope и не должны включать Godot `.import` sidecars.
`docs/design/backups/` держит `.gdignore`, а `build/` уже исключен из импорта;
новые backup-папки должны сохранять это правило. При создании backups копируйте
исходный ассет и служебные manifest/preview-файлы, но не копируйте
`<asset>.import`: эти sidecar файлы содержат UID живого ресурса и при попадании
в import scope создают `UID duplicate detected` warnings. Если backup уже
содержит `.import`, его нужно удалить или держать вне Godot import scope; живой
ассет при необходимости перегенерирует свой `.import` сам.

## Design

ПРАВИЛО «UI не наползает» (пользователь, 2026-06-12): любой UI/HUD-лейаут
проектируется так, чтобы элементы не пересекались ни на одном поддерживаемом
разрешении (включая узкие 1152x648 и широкие-низкие окна). Это требование
acceptance для Design И Back-end UI-работ; QA проверяет фактические rect'ы
и заваливает задачу при пересечении.

ПРАВИЛО «контент только в пустой зоне фрейма» (пользователь, 2026-06-14):
нельзя накладывать элементы интерфейса на декоративную рамку фрейма ни при
каких обстоятельствах. Кнопки, герои/портреты, области выбора, иконки, текст,
карточки, радары, миниатюры и любые интерактивные или информационные элементы
размещаются только во внутренней пустой зоне фрейма: прозрачном центре, плоской
внутренней подложке или явно заданной safe-area. Декоративные борта, углы,
самоцветы, шипы, печати, гребни, металл и орнамент должны оставаться полностью
видимыми и не перекрытыми. Design обязан задавать content-zone/margins для
каждого UI frame; Back-end обязан соблюдать их в layout; QA обязан завалить
задачу при любом наложении контента на рамку, даже если no-overlap между
отдельными плашками прошёл.

Design отвечает за:

- арт-дирекшен;
- спрайты персонажей, монстров, элиток, боссов;
- иконки характеристик, предметов, узлов карты;
- UI visual style, panels, frames, buttons, backgrounds;
- event/shop/campfire backgrounds;
- route map visuals;
- projectiles/VFX visual assets;
- sprite quality audit;
- исправление visual artifacts: лишние куски текстуры, dirty pixels, halos, crop issues;
- content registry для asset paths и visual entities.

Design не должен самостоятельно делать:

- gameplay logic;
- баланс урона/HP/спавна;
- route map click/scroll logic;
- Godot backend systems;
- cleanup runtime objects;
- сложную animation state machine, если это не просто подготовка ассетов.

Если Design нужно подключить ассеты в игру, но требуется логика или сцены/скрипты:

- подготовить ассеты;
- описать file paths и asset IDs;
- создать handoff для `Back-end`.

Если Design видит, что спрайт нельзя красиво анимировать без другой нарезки/rig:

- подготовить части/референсы;
- создать handoff для `Animator`.

## Back-end

Back-end отвечает за:

- Godot/GDScript gameplay logic;
- route map, clicks, scroll/pan, node transitions;
- combat systems;
- balance numbers and formulas;
- characters/weapons/enemies/boss behavior;
- spawn/waves;
- pause/game state;
- UI integration;
- cleanup/lifecycle of nodes/effects;
- performance/code quality;
- tests;
- documentation updates for implemented systems.

Back-end не должен самостоятельно делать:

- финальный арт;
- перерисовку персонажей/монстров;
- полноценную animation polish/art motion design;
- visual style decisions beyond integration and layout;
- complex rig animation, если это не техническая интеграция готовых animation assets.

Если Back-end нужны новые картинки, иконки, фоны, VFX или исправление спрайта:

- создать handoff для `Design`;
- указать размеры, IDs, paths, где будут использоваться ассеты.

Если Back-end видит, что движение выглядит плохо и нужна animation work:

- создать handoff для `Animator`;
- указать сцены, персонажей, состояния, acceptance criteria.

## Animator

Animator отвечает за:

- движение персонажей и врагов;
- rig/cutout/skeleton/sprite sheet animation;
- AnimationPlayer/AnimationTree setup;
- animation states: idle, walk, attack, cast, hit, death;
- pivot points;
- плавность, направление взгляда, body lean, secondary motion;
- animation smoke tests;
- совместимость animation с pause/game state;
- handoff требований к ассетам, если текущие спрайты нельзя анимировать красиво.
- применение skill `~/.codex/skills/fantasydisk-animation-director/` для всех
  задач по персонажам, монстрам, элиткам и боссам: минимум `move/walk` 5+ кадров
  и `attack_primary` 5+ кадров; для элиток/боссов — full-frame sprite-sheet без
  production cutout-разрезания статичного спрайта и отдельные attack-паттерны
  под разные skill/phase.

Animator не должен самостоятельно делать:

- финальную перерисовку персонажей в новом стиле;
- баланс классов/урона/спавна;
- route map/gameplay systems;
- UI visual design;
- крупные backend refactors вне animation needs.

Если Animatorу нужны новые или перерисованные спрайты:

- создать handoff для `Design`;
- описать нужные poses, parts, directions, pivots, размеры и file naming.

Если Animatorу нужна поддержка кода, cleanup, pause integration или scene lifecycle:

- создать handoff для `Back-end`;
- описать, какая API/scene structure нужна.

## QA

QA отвечает за:

- приемочное ревью задач после реализации;
- проверку acceptance criteria из task-файлов;
- проверку smoke/regression результатов, логов и артефактов;
- поиск регрессий в бою, карте, меню, UI, анимациях, арте и балансе;
- фиксацию найденных багов отдельными `backend_`, `design_` или `animation_`
  handoff-задачами;
- подтверждение, что документация и CHANGELOG обновлены для выполненной работы.

QA не должен самостоятельно делать:

- gameplay/code implementation;
- перерисовку ассетов;
- animation/rig правки;
- баланс-изменения;
- коммиты релизов или merge/tag операции.

Парные qa_review-задачи НЕ создаются (упразднено PM 2026-06-12): каждая задача
после `done` автоматически тестируется QA-воркером по `docs/process/qa_protocol.md`.
Исключение — повторная проверка после вердикта FAILED: на нее заводится отдельная
qa_review-задача (QA-воркер не перепроверяет файлы с уже выданным вердиктом).

## Handoff Формат

Любой cross-agent handoff должен сначала быть Jira issue/comment chain, а затем
локальным `.md` mirror-файлом в `docs/tasks/`, если нужны подробная спецификация
или evidence.

Название:

```text
docs/tasks/<role>_<short_task_name>.md
```

Где `<role>`:

- `design`
- `backend`
- `animation`
- `qa`

Минимальная структура:

```md
# Задача Для <Role>-Агента: <Название>

Статус: new
Контур: Codex | Claude
Owner: unassigned
Thread: n/a
Locked paths: <ключевые файлы/папки/ассеты/экраны>
Jira: SCRUM-<номер>

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи...
Directive 2026-06-28: agents should not ask the user for routine confirmations.
For a claimed Jira issue, the agent has full in-repository approval to pull,
claim/update Jira, edit project files, run tests, update docs, commit, and push
its own task files. Escalate only platform-enforced approval gates, secrets,
destructive external actions, or true blockers.

## Контекст

## Что Уже Сделано

## Что Нужно От Другого Агента

## Files / Assets / IDs

## Acceptance Criteria

## Документация
```

## Правило Передачи В Чат

После создания handoff-файла агент должен отправить задачу в соответствующий чат:

- `Design` для визуала и ассетов;
- `Back-end` для кода, логики, интеграции, тестов;
- `Animator` для движения и animation systems.
- `QA` для приемочного ревью и регрессий; если отдельного QA-чата нет, задача
  фиксируется на доске для Claude-QA board worker.

Сообщение в чат должно содержать:

- путь к `.md` файлу;
- короткое резюме;
- что уже готово;
- что требуется;
- зависимости;
- напоминание, что пользователь дал approval на in-scope изменения.

## Если Задача Смешанная

Если задача затрагивает несколько областей:

1. Главный агент делает свою часть.
2. Создает отдельные handoff tasks для остальных.
3. Не делает чужую работу "на глаз".
4. Документирует зависимости.
5. После получения результата другого агента интегрирует только свою часть, если это его зона ответственности.

## Когда Можно Коснуться Чужой Области

Допустимо минимально коснуться чужой области только если это нужно для связи:

- Back-end может подключить готовый asset в сцену.
- Animator может добавить технические animation nodes.
- Design может создать preview scene/reference layout без gameplay logic.

Но агент не должен принимать ключевые решения за другую роль.

## Документация

Каждый агент обновляет документы только в части своей работы:

- Design: `content_registry.md`, `visual_style_assets.md`, visual sections.
- Back-end: `current_game_state.md`, system docs, mechanics/balance docs, tests.
- Animator: `animation.md`, animation architecture, animation asset status.
- QA: результат проверки в task-файле, найденные дефекты отдельными handoff
  задачами; продуктовую документацию QA не переписывает вместо владельца.

Если документация еще не разбита по доменам, обновить существующие документы и отметить, что после batch changes нужно выполнить `docs/tasks/documentation_post_changes_domain_split_task.md`.
