# PM Workflow — FantasyDisk

Обновлено: 2026-07-13

Этот документ описывает работу PM-чата (проджект-менеджер) и правила, по которым формируются и выдаются задачи чатам `Design`, `Back-end` и `Animator`.

## Полная Автономия Всех Агентов (директива пользователя, 2026-06-12)

Все агенты (PM, Back-end, Design, Animator, QA, воркеры, Codex) работают
самостоятельно: вопросов пользователю не задают и его инпут не ждут. Спорные
требования доформулируются самим агентом разумным образом, решение и обоснование
фиксируются в отчёте задачи. Невозможность продолжить = `blocked` с точной
причиной + handoff, затем следующая задача; blocked разбирает PM.

## Multica-first Workflow (cutover 2026-07-13)

Как из cutover 2026-07-13 (approver Sergey Fomin, владелец проекта; см.
`docs/process/jira_to_multica_cutover.md`) единым authoritative источником
очереди, статуса, владельца, sprint/release tracking и cross-device
синхронизации для всех AI-агентов является **Multica** (проект `FantasyDisk`,
id `2ac963eb-b644-4540-8042-a1a4508f1a65`, issues `FAN-*`) через `multica` CLI.
Все задачи создаются, назначаются и берутся из Multica. Legacy Jira (`SCRUM-*`)
теперь read-only исторический архив — в нём нельзя создавать, claim'ить, синкать
или закрывать работу.

Локальные файлы:

- `docs/tasks/*.md` — подробная спецификация, handoff/evidence и результат,
  привязанные к Multica issue;
- `docs/process/task_board.md` — локальный dashboard/cache для удобства аудита.

Они не являются источником новых задач. Если Multica и локальный mirror
расходятся, агент обязан считать Multica authoritative, затем привести
`.md`/board mirror в соответствие.

## Роль PM

PM-чат:

1. Принимает пожелания и требования от пользователя в свободной форме.
2. Превращает их в четкие, проверяемые требования.
3. Создает задачу в Multica проекте `FantasyDisk` (issues `FAN-*`) и сразу
   добавляет ее в live active sprint; локальный `.md` создаётся/обновляется
   только как spec/evidence mirror после появления Multica key.
4. Назначает каждую задачу правильному исполнителю (Design / Back-end / Animator).
5. Ведет Multica board (проект `FantasyDisk`) как источник очереди и статусов;
   локальную доску `docs/process/task_board.md` держит как read-only dashboard/cache.
6. Синхронизирует локальные mirrors с Multica: issue key в `.md`, строка на
   локальном dashboard, активный спринт и комментарии/статусы.
7. Следит, чтобы документация в `docs/design/` обновлялась вместе с изменениями.
8. Работает автономно: не задает пользователю вопросы, если требование можно разумно доформулировать самому. Спрашивает только при противоречии с текущим дизайном игры или при выборе, меняющем направление продукта.
9. Проверяет себя: перед выдачей задачи сверяется с `current_game_state.md`, `content_registry.md` и `mechanics_extract.md`, чтобы требования не противоречили уже реализованному.

PM не пишет код, не рисует ассеты и не делает анимацию сам — только требования, декомпозиция, приоритеты и документация процесса.
PM/dispatcher не закрывает задачи за исполнителя. Исполнитель сам переводит
Multica issue и локальные mirrors в `done`/`in_review` с результатом.
PM/dispatcher может только синхронизировать Multica/board, если в Multica или
task-файле уже есть явный результат исполнителя или QA-вердикт, либо пометить
расхождение.
Codex Documentation dispatcher может создавать новые Multica issues для активного
sprint по обычному порядку после проверки зависимостей, дублей и активных
владельцев; `.md` task-файл создаётся после Multica key как mirror/spec.
Dispatcher маршрутизирует существующие Multica issues в конкретные role threads,
проверяет дубли и синхронизирует статусы/комментарии.

## Распределение Ролей (краткая памятка)

- `Design` — дизайн, спрайты, иконки, фоны, UI-визуал, VFX-ассеты, арт-дирекшен.
- `Back-end` — логика, GDScript-код, баланс, системы, интеграция ассетов, тесты.
- `Animator` — движение, риги, AnimationPlayer/AnimationTree, анимационные состояния.
- `QA` — приемка результата, регрессии, заведение bug/handoff-задач; не чинит
  код/арт/анимацию вместо владельца.

## Два Контура Исполнителей (Claude + Codex)

Решение пользователя (2026-06-11): задачи распределяются между двумя контурами,
все работают над одним проектом в одной ветке `dev`.

- **Codex** — автономный исполнитель для задач с исчерпывающим ТЗ, точными
  файлами/ассетами, проверяемыми acceptance criteria, рутинной интеграцией,
  механическими правками, генерацией ассетов, animation batches и тестовыми
  фиксациями. Codex работает самостоятельно после verified dispatcher assignment
  в конкретный role thread или explicit direct-control owner comment. Codex
  Documentation остаётся диспетчером для ручной разбивки, handoff, спорных owner
  cases и синхронизации зеркал.
  Команда отправки (CLI из приложения Codex):
  ```bash
  /Applications/Codex.app/Contents/Resources/codex exec resume \
    019eabf7-42e9-7a71-b83d-9ba413289cfb \
    --cd "/Users/sergeyfomin/Documents/AI Agent" "сообщение"
  ```
- **Claude Code / Claude-чаты / Claude-воркеры** — контур для сложных решений:
  архитектура, баланс, неочевидная отладка, продуктовые развилки, ревью,
  релизные проверки и задачи, где нужен широкий контекст. Claude может ревьюить
  Codex-результат только после того, как Codex-owner записал `done/review` и
  результат в task-файл; ревью оформляется отдельной review/bug/follow-up
  задачей и не начинается параллельно в тех же файлах.
- Правила одни для всех: один owner на задачу, статусы в task-файле, Multica sync,
  коммиты в `dev` там, где роль/среда это разрешает, smoke-тесты, обновление
  документации, handoff при чужой работе, cleanup одноразовых worker-чатов.

## Контур, Owner И Locked Paths

Каждая новая задача должна явно указывать, какой контур имеет право ее брать:

```text
Контур: Codex | Claude
Owner: <роль>/<thread или worker> | unassigned
Thread: <Codex thread id> | <Claude chat/worker id> | n/a
Locked paths: <основные файлы/папки/ассеты/экраны>
```

Правила:

1. `Контур: Codex` означает: Claude Code/воркеры пропускают эту строку, пока
   Codex-owner не запишет результат или не пометит `blocked/handoff`.
2. `Контур: Claude` означает: Codex dispatcher и role heartbeats не маршрутизируют
   эту строку в Codex, кроме отдельной handoff/review-задачи.
3. Если контур не указан, PM/dispatcher обязан выбрать его перед dispatch или
   разрешением auto-pull. До этого задача считается неготовой к автономному
   исполнению.
4. `Locked paths` обязательны для задач, которые меняют код, тесты, UI layout,
   frame/source pack, character set или asset directory. Второй контур не берёт
   задачу с пересекающимися locked paths, даже если роль формально подходит.
5. Review across lanes идёт только после результата владельца: `Codex done/review`
   → отдельная Claude review/bug task, либо `Claude done/review` → отдельная
   Codex handoff. Нельзя одновременно чинить одну и ту же проблему из двух
   контуров.

## Feature Freeze / Sprint Policy

Фриз 0.1.5 снят релизом v0.1.5 (2026-06-15). Активен live sprint
в Multica (проект `FantasyDisk`; `Спринт 0.2.1` на 2026-07-03; всегда проверять
live Multica board перед dispatch/claim). Плановые версии `0.1.8` и `0.1.9`
отменены/superseded;
PM/dispatcher не создают новые tasks, fixVersions или sprint notes под эти
номера.
Директива пользователя 2026-07-03: все задачи, которые пользователь добавляет
в любые чаты, считаются текущим sprint scope и сразу добавляются в active sprint
с fixVersion активного sprint/release. Backlog используется только при явной
freeze/hold директиве.
Задачи текущего sprint можно брать в работу обычным порядком: взять одну
назначенную/eligible FAN issue, заклеймить через `multica issue status <FAN-id>
in_progress` + стартовый комментарий, если она не заблокирована, не ждёт PM/QA
acceptance и не имеет активного владельца. Перед стабилизацией следующего релиза
PM снова включает фриз отдельной директивой.

## Этап QA (с 2026-06-12, обязательный)

КАЖДАЯ задача после `done` проходит детальное QA-тестирование по
`docs/process/qa_protocol.md` (чат «QA testing chat» + воркер
`fantasydisk-qa-board-worker`, прогон каждые ~5 минут). Задача закрыта полностью
только с блоком «## QA-Вердикт: PASSED» в файле. Найденные баги QA заводит
**bug-issue в Multica** (проект `FantasyDisk`, `FAN-*`), затем зеркалит строкой
на доске (секция «Баги от QA»); исполнители берут чинить **Multica issue**, не
строку доски. PM при сверках учитывает QA-статусы в Multica.

## Глобальное UI-правило: контент только внутри фрейма (2026-06-14)

При постановке любой задачи на UI-фреймы, панели, карточки, кнопки или экранные
области PM/dispatcher обязан явно указывать content-zone/safe-area. Кнопки,
герои/портреты, области выбора, иконки, тексты, миниатюры, радары и любой другой
контент нельзя накладывать на декоративные рамки фреймов. Разрешенная зона —
только пустая внутренняя область фрейма: прозрачный центр, плоская подложка фона
или специально выделенная safe-area с margins. Design фиксирует эти margins в
результате, Back-end соблюдает их при layout, QA считает наложение на рамку
дефектом.

## PixelLab-first Redraw Intake (SCRUM-689)

Будущие redraw-задачи PM/dispatcher формулирует как PixelLab-first по умолчанию.
Это касается перерисовки персонажей, врагов, элиток, боссов, animation/source
packs, UI/frame source kits и похожих source assets, где цель — заменить или
серьёзно обновить визуал. Multica issue и локальный task mirror должны прямо
указывать PixelLab как источник, expected source/runtime paths, transparent PNG,
runtime-safe sizing/readability evidence, pivots and 8-direction/animation
contract when relevant.

`fantasydisk-ui-director` и `content-zone-image-compositor` остаются
обязательными для UI planning, safe margins, text/content zones and compositing
checks. PixelLab-first означает источник redraw art, а не разрешение класть текст,
иконки, кнопки или портреты поверх орнамента. Hard frame/content-zone rule
остаётся acceptance gate.

Старый generic OpenAI/`fantasydisk-asset-generator` путь для redraw не является
fallback. Его можно использовать только если Multica issue/task заранее или в
blocker comment явно записывает исключение и причину: например `OpenAI Images override`,
reuse of an accepted existing source, or PixelLab unavailable. Такое исключение
должно попасть в result/evidence, чтобы QA и следующие агенты не считали его
молчаливым обходом процесса.

## Multica Sync (с cutover 2026-07-13, обязательный)

Все задачи ведутся в Multica проекте `FantasyDisk` (`FAN-*`); локальные
task-файлы дополнительно дублируют подробную спецификацию и evidence.
Source-of-truth по очереди, статусу, owner и sprint/release tracking — Multica.
Задачи текущего релиза добавляются в активный спринт. PM/другая LLM создает
обычные задачи в Multica; Codex Documentation dispatcher может создавать/sync'ить
current-sprint Multica issues по обычному порядку только после
lane/owner/locked-path audit.
Если перед будущим релизом PM снова включает freeze, новые не-баговые feature
requests уходят в backlog следующей версии только при явной freeze/hold
директиве. При dispatch, блокировке, review, done и QA verdict dispatcher
обновляет соответствующие Multica issue status/comment и task/board строки.

Полный регламент cutover: `docs/process/jira_to_multica_cutover.md`.

## Feature Block / Freeze

На 2026-07-03 feature block 0.1.5 снят; текущий активный sprint берётся из
Multica board (проект `FantasyDisk`; `Спринт 0.2.1` на момент обновления). Если
PM включает новый freeze перед релизом, dispatcher и role agents возвращаются к
режиму: только уже заведённые rows, баги, QA defects, regressions, release
blockers и owner nudges; новые не-баговые запросы уходят в backlog следующей
версии без dispatch до PM override только если PM явно поставил freeze/hold
marker.

## Локальные Зеркала Multica (с cutover 2026-07-13)

Multica board: проект `FantasyDisk` (id `2ac963eb-b644-4540-8042-a1a4508f1a65`,
issues `FAN-*`) через `multica` CLI — источник истины для задач.
`docs/tasks/*.md` и `docs/process/task_board.md` — локальные mirrors/spec/evidence;
Multica timeline сам является record, отдельного end-of-run sync-скрипта нет.
Legacy Jira board https://fantasydisk.atlassian.net (проект SCRUM, доска 1)
после cutover — read-only исторический архив, не источник задач.
Статусы Multica: `todo`, `in_progress`, `in_review`, `blocked`, `backlog`,
`done`; local mirror может отображать `new`/`review`. Parent получает `done`
только после QA PASSED; bug scope фиксируется в title/description/parent links.
Authoritative routing задают exact assignee и свежий dispatcher/owner comment с
lane и locked paths. Labels `codex`/`claude`/role могут использоваться как
необязательные подсказки поиска, но их отсутствие не блокирует назначенную issue.

## Фоновые Воркеры (с 2026-06-11; ИСТОЧНИК ЗАДАЧ — MULTICA)

> **Статус 2026-07-13 (cutover):** источник задач — Multica (проект `FantasyDisk`,
> `FAN-*`). Активные role workers получают задачи **только через single
> dispatcher assignment** в Multica, а НЕ из локальной доски. Доска — сверочный
> кэш, не очередь задач.

Legacy Claude Desktop scheduled workers больше не являются task-pull флотом.
Активный флот запускается через Multica daemon:

- dispatcher проверяет `todo`/`in_review`/`in_progress`, assignee, comments и
  locked paths;
- свободную issue он одним update паркует в `backlog` с exact agent UUID,
  перепроверяет ownership, пишет assignment comment и переводит в `todo`;
- daemon worker принимает только назначенную issue, переводит её в
  `in_progress`, выполняет один scope, пушит и останавливается;
- QA получает отдельную child review issue, чтобы не перезаписывать owner
  реализации.

Несколько dispatchers запрещены: CLI пока не имеет atomic
`claim-if-unassigned/expected-status`.

**Анти-коллизия (урок сломанного HEAD SCRUM-171, 2026-06-13):** два backend-воркера
не берут задачи с пересекающимися основными файлами — особенно
`scripts/progression_data.gd` и `scripts/ui_screens.gd` (общие точки сборки).
Параллелятся только файл-изолированные задачи; работа по общим файлам
сериализуется. Если file-изолированного Multica issue нет, второй воркер пропускает прогон.

**Дисциплина коммита (для всех исполнителей):** «done = закоммичено И HEAD
компилируется». Вызовы новых функций и их определения коммитятся вместе; нельзя
помечать задачу done, оставив её код в незакоммиченном рабочем дереве (именно это
сломало HEAD: combat_director вызывал `drop_class_rewards`, а определение жило
в несведённом дереве). Release-гейт: пост-коммит smoke на ЧИСТОМ
`git worktree HEAD` (+ `--import`), а не только на рабочем дереве.

Следствия для PM: чтобы задача ушла в Claude-воркеры, недостаточно локально
поставить `new`; нужно создать/обновить Multica issue и явно указать
`Контур: Claude` и locked paths в Multica + local mirror. Claude воркеры берут её
из Multica (lane `claude`) и не трогают `Контур: Codex`, `in_progress`,
`blocked`, review-gated или чужие owner issues. Один прогон — одна задача.

## Documentation Dispatcher И Role Heartbeats (Codex)

Codex Documentation dispatcher регулярно смотрит Multica как authoritative queue
и сверяет local mirrors. Он является единственным writer для назначения свободных
задач: резервирует exact agent UUID, перепроверяет ownership и enqueue'ит issue.
Role windows не берут unassigned задачи сами. Dispatcher не пишет код, не рисует
ассеты, не делает анимации и не запускает release flow; он проверяет зависимости,
дубли, active owner state, Multica/local mirror sync и handoff.

Существующие role windows:

- Back-end: `019eabd9-780b-78a2-9f4b-e7203d659ef2`;
- Design main: `019eabf1-6d54-7561-8af9-ce25cdf483a9`;
- Designer 2: `019ec7a6-55a5-7bc3-a397-606ce046308d`;
- Animator: `019eb156-710c-71f0-8903-eada762dceb3`.

Role heartbeat в этих окнах не является разрешением брать любую свободную строку
из локальной доски или Multica. Он может:

- принять одну Multica issue (`FAN-*`) только если exact `assignee_id` совпадает
  с worker; затем поставить `in_progress` и стартовый `--content-file` comment;
- продолжать уже назначенную этому thread задачу (`Контур: Codex`,
  совпадающий `Owner/Thread`, непересекающиеся dirty files);
- синхронизировать явно записанный результат/QA verdict;
- отвечать `DONT_NOTIFY`, если в Multica не нашлось eligible issue и нет активной
  continuation.

Он не должен self-select'ить `new` rows или unassigned Multica issues. Ownership
появляется только после verified dispatcher assignment; затем task-файл/board
обновляются как зеркало.

Одноразовые Codex worker-чаты, созданные автоматизациями для конкретного run,
должны архивировать себя после завершения или truthful blocker/no-task отчёта.
Это делается через `codex_app.set_thread_archived` (`archived: true`, без
`threadId`) последним tool-действием перед финалом. Постоянные dispatcher/watch
чаты, такие как Back-end watcher или QA monitor, не архивируются автоматически.

### Design Collision Rules

Для Design main и Designer 2 действуют дополнительные правила:

- одна Design-задача = один активный Design owner/thread;
- нельзя брать задачу, где другой дизайнер уже указан в `Dispatch`,
  `Исполнитель`, результате, Multica-комментарии или свежей role-thread истории;
- нельзя параллелить два Design tasks с одним экраном, frame kit, source pack,
  character set или asset directory без явной PM/dispatcher разбивки;
- review вторым дизайнером разрешён только отдельным review dispatch; review не
  превращает задачу в совместную реализацию.

Полное описание границ и правил передачи: `docs/process/agent_role_boundaries_and_handoffs.md`.

Ключевое правило для всех исполнителей: **если в ходе задачи встречается работа другой роли — не делать ее самому, а создать handoff-задачу в `docs/tasks/` и передать в нужный чат.**

## Поток Работы

```text
Пользователь (пожелание)
        │
        ▼
PM: уточнение требований против docs/design/*
        │
        ▼
PM: Multica issue FAN-* как источник очереди/status/owner
        │
        ▼
PM: локальный .md/task_board mirror при необходимости
        │
        ▼
PM/dispatcher указывает role/lane/locked paths и exact assignee; direct-control
chat вместо assignee фиксирует explicit owner comment после duplicate audit
        │
        ▼
Codex role heartbeat / Claude worker принимает только назначенную matching Multica issue/контур
        │
        ▼
Исполнитель: работа + обновление Multica + local mirror + docs/design/*
        │
        ▼
QA/review: отдельная проверка после результата owner, без параллельной правки тех же файлов
```

## Шаблон Задачи

Локальный mirror/spec-файл: `docs/tasks/<role>_<short_task_name>_task.md`,
где `<role>` — `design`, `backend` или `animation`. Создаётся после Multica issue
и всегда содержит `Multica: FAN-<номер>`.

```md
# Задача Для <Role>-Агента: <Название>

Статус: new | in_progress | review | done | blocked
Контур: Codex | Claude
Owner: unassigned
Thread: n/a
Locked paths: <ключевые файлы/папки/ассеты/экраны>
Создано: <дата>
Автор: PM
Multica: FAN-<номер>

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи.
Не останавливаться для подтверждений, если требование понятно.

## Роль И Границы
Ты — <Role>-агент. Делай только работу своей роли.
Если встретишь работу другой роли (Design / Back-end / Animator) —
создай handoff-задачу в docs/tasks/ по правилам
docs/process/agent_role_boundaries_and_handoffs.md и укажи это в финальном отчете.

## Контекст
<зачем это нужно, ссылка на документы дизайна>

## Требования
<нумерованный список конкретных, проверяемых требований>

## Files / Assets / IDs
<точные пути, имена сущностей из content_registry.md, размеры>

## Acceptance Criteria
<чек-лист, по которому PM примет задачу>

## Документация
<какие файлы в docs/design/ обновить в этой же задаче>

## Самопроверка
<что прогнать: smoke tests для backend/animation, визуальная проверка для design>
```

## Правила Статусов

- Новая задача создается в Multica со статусом `todo`; значение `new` существует
  только в локальном mirror, который создаётся после получения Multica key.
- Исполнитель при взятии в работу обновляет Multica first (`in_progress`/comment),
  затем локальный mirror. По завершении — Multica + mirror `done` (или
  `in_review`, если нужна проверка PM) и короткое резюме результата.
- При взятии задачи исполнитель или dispatcher добавляет явный owner/claim note:
  роль, thread/worker id, lane, дата и краткая причина. Для Design это обязательно,
  потому что Design main и Designer 2 работают параллельно.
- PM синхронизирует Multica при каждом изменении; `docs/process/task_board.md`
  обновляется как dashboard/cache.
- Заблокированные задачи получают `blocked` с указанием, чего ждут.
- Закрытие задачи — ответственность владельца задачи. Dispatcher не ставит
  `done` вместо исполнителя, если нет подтвержденного результата в Multica/task
  mirror или QA-вердикта. При расхождении dispatcher добавляет Multica
  comment/заметку и возвращает задачу владельцу.
- При регулярной сверке dispatcher проверяет возможные дубли в Multica first:
  одинаковые Multica
  summary, одинаковые source task paths, одинаковые зоны файлов/ассетов или две
  активные задачи на одну проблему. Дубли не раздаются повторно: один Multica issue
  остается canonical, остальные помечаются `duplicate`/`superseded` с
  ссылкой на основной task/Multica issue.

## Документация

- Каждая задача, меняющая геймплей, баланс, контент, UI, визуал или анимацию, обязана обновлять соответствующие документы в `docs/design/` в той же задаче.
- Новые сущности обязаны попадать в `content_registry.md`.
- Фактическое состояние игры — `current_game_state.md`; PM проверяет, что исполнители его обновили.
- После крупных пакетов изменений PM инициирует задачу `documentation_post_changes_domain_split_task.md`.

## Самопроверка PM

Перед выдачей каждой задачи PM проверяет:

1. Задача назначена правильной роли (по границам ролей).
2. Требования не противоречат `current_game_state.md` и GDD.
3. Acceptance Criteria проверяемы без догадок.
4. Указаны точные пути/ID, а не «где-то в проекте».
5. Указано, какую документацию обновить.
6. Задача создана/обновлена в Multica и только затем отражена в локальном mirror/dashboard.
