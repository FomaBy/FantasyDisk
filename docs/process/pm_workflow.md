# PM Workflow — FantasyDisk

Обновлено: 2026-07-03

Этот документ описывает работу PM-чата (проджект-менеджер) и правила, по которым формируются и выдаются задачи чатам `Design`, `Back-end` и `Animator`.

## Полная Автономия Всех Агентов (директива пользователя, 2026-06-12)

Все агенты (PM, Back-end, Design, Animator, QA, воркеры, Codex) работают
самостоятельно: вопросов пользователю не задают и его инпут не ждут. Спорные
требования доформулируются самим агентом разумным образом, решение и обоснование
фиксируются в отчёте задачи. Невозможность продолжить = `blocked` с точной
причиной + handoff, затем следующая задача; blocked разбирает PM.

## Jira-first Workflow (директива пользователя, 2026-06-27)

С этого момента все задачи создаются, назначаются и берутся из Jira. Jira
является единым источником очереди, статуса, владельца, sprint/release tracking
и cross-device синхронизации для всех AI-агентов.

Локальные файлы:

- `docs/tasks/*.md` — подробная спецификация, handoff/evidence и результат,
  привязанные к Jira issue;
- `docs/process/task_board.md` — локальный dashboard/cache для удобства аудита;
- `docs/process/jira_sync_map.json` — техническая карта соответствия.

Они не являются источником новых задач. Если Jira и локальный mirror расходятся,
агент обязан считать Jira authoritative, затем привести `.md`/board mirror в
соответствие.

## Роль PM

PM-чат:

1. Принимает пожелания и требования от пользователя в свободной форме.
2. Превращает их в четкие, проверяемые требования.
3. Создает задачу в Jira проекте `SCRUM` и сразу добавляет ее в live active
   sprint; локальный `.md` создаётся/обновляется только как spec/evidence mirror
   после появления Jira key.
4. Назначает каждую задачу правильному исполнителю (Design / Back-end / Animator).
5. Ведет Jira board как источник очереди и статусов; локальную доску
   `docs/process/task_board.md` держит как read-only dashboard/cache.
6. Синхронизирует локальные mirrors с Jira по правилам `docs/process/jira_sync.md`:
   issue key в `.md`, строка на локальном dashboard, активный спринт и комментарии/статусы.
7. Следит, чтобы документация в `docs/design/` обновлялась вместе с изменениями.
8. Работает автономно: не задает пользователю вопросы, если требование можно разумно доформулировать самому. Спрашивает только при противоречии с текущим дизайном игры или при выборе, меняющем направление продукта.
9. Проверяет себя: перед выдачей задачи сверяется с `current_game_state.md`, `content_registry.md` и `mechanics_extract.md`, чтобы требования не противоречили уже реализованному.

PM не пишет код, не рисует ассеты и не делает анимацию сам — только требования, декомпозиция, приоритеты и документация процесса.
PM/dispatcher не закрывает задачи за исполнителя. Исполнитель сам переводит
Jira issue и локальные mirrors в `done`/`review` с результатом. PM/dispatcher
может только синхронизировать Jira/board, если в Jira или task-файле уже есть
явный результат исполнителя или QA-вердикт, либо пометить расхождение.
Codex Documentation dispatcher может создавать новые Jira issues для активного
Jira sprint по обычному порядку после проверки зависимостей, дублей и активных
владельцев; `.md` task-файл создаётся после Jira key как mirror/spec.
Dispatcher маршрутизирует существующие Jira issues в конкретные role threads,
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
  фиксациями. Codex работает самостоятельно после успешного Jira-pull claim в
  конкретном role thread или после явного dispatch в этот thread. Codex
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
- Правила одни для всех: один owner на задачу, статусы в task-файле, Jira sync,
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

Фриз 0.1.5 снят релизом v0.1.5 (2026-06-15). Активен live Jira sprint
на board 1 (`Спринт 0.2.1` на 2026-07-03; всегда проверять live Jira перед
dispatch/claim). Плановые версии `0.1.8` и `0.1.9` отменены/superseded;
PM/dispatcher не создают новые tasks, fixVersions или sprint notes под эти
номера.
Директива пользователя 2026-07-03: все задачи, которые пользователь добавляет
в любые чаты, считаются текущим sprint scope и сразу добавляются в active sprint
с fixVersion активного sprint/release. Backlog используется только при явной
freeze/hold директиве.
Задачи текущего sprint можно брать в работу обычным порядком через Jira-pull
claim-first, если они не заблокированы, не ждут PM/QA acceptance и не имеют
активного владельца. Перед стабилизацией следующего релиза PM снова включает
фриз отдельной директивой.

## Этап QA (с 2026-06-12, обязательный)

КАЖДАЯ задача после `done` проходит детальное QA-тестирование по
`docs/process/qa_protocol.md` (чат «QA testing chat» + воркер
`fantasydisk-qa-board-worker`, прогон каждые ~5 минут). Задача закрыта полностью
только с блоком «## QA-Вердикт: PASSED» в файле. Найденные баги QA заводит
**bug-issue в Jira** (проект SCRUM), затем зеркалит строкой на доске (секция «Баги
от QA»); исполнители берут чинить **Jira-issue**, не строку доски. PM при сверках
учитывает QA-статусы в Jira.

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
серьёзно обновить визуал. Jira issue и локальный task mirror должны прямо
указывать PixelLab как источник, expected source/runtime paths, transparent PNG,
runtime-safe sizing/readability evidence, pivots and 8-direction/animation
contract when relevant.

`fantasydisk-ui-director` и `content-zone-image-compositor` остаются
обязательными для UI planning, safe margins, text/content zones and compositing
checks. PixelLab-first означает источник redraw art, а не разрешение класть текст,
иконки, кнопки или портреты поверх орнамента. Hard frame/content-zone rule
остаётся acceptance gate.

Старый generic OpenAI/`fantasydisk-asset-generator` путь для redraw не является
fallback. Его можно использовать только если Jira/task заранее или в blocker
comment явно записывает исключение и причину: например `OpenAI Images override`,
reuse of an accepted existing source, or PixelLab unavailable. Такое исключение
должно попасть в result/evidence, чтобы QA и следующие агенты не считали его
молчаливым обходом процесса.

## Jira Sync (с 2026-06-12, обязательный)

Все задачи ведутся в Jira проекте `SCRUM`; локальные task-файлы дополнительно
дублируют подробную спецификацию и evidence. Source-of-truth по очереди,
статусу, owner и sprint/release tracking — Jira. Задачи текущего релиза
добавляются в активный спринт. PM/другая LLM создает обычные задачи в Jira;
Codex Documentation dispatcher может создавать/sync'ить current-sprint Jira
issues по обычному порядку только после lane/owner/locked-path audit.
Если перед будущим релизом PM снова включает freeze, новые не-баговые feature
requests уходят в backlog следующей версии только при явной freeze/hold
директиве. При dispatch, блокировке, review, done и QA verdict dispatcher
обновляет соответствующие Jira issue status/comment и task/board строки.

Полный регламент: `docs/process/jira_sync.md`.

## Feature Block / Freeze

На 2026-07-03 feature block 0.1.5 снят; текущий активный sprint берётся из Jira
board 1 (`Спринт 0.2.1` на момент обновления). Если
PM включает новый freeze перед релизом, dispatcher и role agents возвращаются к
режиму: только уже заведённые rows, баги, QA defects, regressions, release
blockers и owner nudges; новые не-баговые запросы уходят в backlog следующей
версии без dispatch до PM override только если PM явно поставил freeze/hold
marker.

## Локальные Зеркала Jira (с 2026-06-12)

Jira board: https://fantasydisk.atlassian.net (проект SCRUM, доска 1) —
источник истины для задач. `docs/tasks/*.md` и `docs/process/task_board.md` —
локальные mirrors/spec/evidence. Синхронизация — `python3 tools/jira_board_sync.py`
(идемпотентен, map в docs/process/jira_sync_map.json), автоматически выполняется
QA-воркером в конце каждого прогона (~5 мин).
Статусы: new/blocked → «К выполнению», in_progress/review → «В работе»,
done → «Контроль качества», done+QA PASSED → «Готово»; bug_* → тип «Баг».
Креды: macOS Keychain, сервис `fantasydisk-jira` (НЕ хранить токен в файлах репозитория).
Метки исполнителя (правило пользователя, 2026-06-12): каждый тикет несет лейбл
`codex` (файлы codex_* или строка «Исполнитель: Codex») либо `claude` — по ним
фильтруется, кто какой контур делает. Лейблы роли (backend/design/qa/bug) сохраняются.

## Фоновые Воркеры (с 2026-06-11; ИСТОЧНИК ЗАДАЧ — JIRA)

> **Статус 2026-06-27:** Jira-pull включён как стандартный режим. Активные
> role workers/heartbeats берут задачи **только из Jira current sprint** через
> claim-first, а НЕ из локальной доски. Доска — сверочный кэш, не очередь задач.

Когда флот активен, запланированные воркера (Claude Desktop → раздел Scheduled;
работают, пока приложение открыто):

- backend-воркеры ×3: `fantasydisk-backend-board-worker` (0),
  `-worker-2` (+3), `-worker-3` (+1, добавлен 2026-06-13 под Quality Pass 0.1.4) —
  каждые
  ~5 минут: берут по одному **Jira-issue** из active sprint с matching role/lane
  label, claim-first через Jira (`tools/jira_next_task.py`), выполняют полностью
  (клейм в Jira → код → тесты → документация → коммит/push в dev → done).
- `fantasydisk-designer-board-worker` (+2) — то же для роли Design + Design-ревью.
  Для Codex Design pool auto-pull PM обязан добавлять worker-scope label:
  `design-main` или `designer2`; общий label `design` без этого не забирается
  автоматически.
- QA-воркеры ×2: `fantasydisk-qa-board-worker` (+4) и `-worker-2` (+2, добавлен
  2026-06-13) — приёмка done по qa_protocol, claim-first против гонок.
  Итого флот: backend×3, design×1, qa×2 (работают пока открыт Claude Desktop).

**Анти-коллизия (урок сломанного HEAD SCRUM-171, 2026-06-13):** два backend-воркера
не берут задачи с пересекающимися основными файлами — особенно
`scripts/progression_data.gd` и `scripts/ui_screens.gd` (общие точки сборки).
Параллелятся только файл-изолированные задачи; работа по общим файлам
сериализуется. Если file-изолированного Jira-issue нет, второй воркер пропускает прогон.

**Дисциплина коммита (для всех исполнителей):** «done = закоммичено И HEAD
компилируется». Вызовы новых функций и их определения коммитятся вместе; нельзя
помечать задачу done, оставив её код в незакоммиченном рабочем дереве (именно это
сломало HEAD: combat_director вызывал `drop_class_rewards`, а определение жило
в несведённом дереве). Release-гейт: пост-коммит smoke на ЧИСТОМ
`git worktree HEAD` (+ `--import`), а не только на рабочем дереве.

Следствия для PM: чтобы задача ушла в Claude-воркеры, недостаточно локально
поставить `new`; нужно создать/обновить Jira issue и явно указать `Контур: Claude`
и locked paths в Jira + local mirror. Claude воркеры берут её через Jira-pull
(`--lane claude`) и не трогают `Контур: Codex`, `in_progress`, `blocked`,
review-gated или чужие owner issues. Один прогон — одна задача.

## Documentation Dispatcher И Role Heartbeats (Codex)

Codex Documentation dispatcher регулярно смотрит Jira как authoritative queue и
сверяет local mirrors, но обычные свободные current-sprint задачи role windows
могут брать сами через Jira-pull claim-first. Dispatcher не пишет код, не рисует
ассеты, не делает анимации и не запускает release flow; он проверяет зависимости,
дубли, active owner state, Jira/local mirror sync, спорные cases и ручные handoff.

Существующие role windows:

- Back-end: `019eabd9-780b-78a2-9f4b-e7203d659ef2`;
- Design main: `019eabf1-6d54-7561-8af9-ce25cdf483a9`;
- Designer 2: `019ec7a6-55a5-7bc3-a397-606ce046308d`;
- Animator: `019eb156-710c-71f0-8903-eada762dceb3`.

Role heartbeat в этих окнах не является разрешением брать любую свободную строку
из локальной доски. Он может:

- claim'ить одну eligible Jira issue из active sprint через
  `python3 tools/jira_next_task.py --role <role> --lane codex --claim --worker <thread-id> --json`
  (для Design main/Designer 2 добавить `--required-label design-main|designer2`);
- продолжать уже назначенную/claimed этому thread задачу (`Контур: Codex`,
  совпадающий `Owner/Thread`, непересекающиеся dirty files);
- синхронизировать явно записанный результат/QA verdict;
- отвечать `DONT_NOTIFY`, если Jira-pull не нашёл eligible issue и нет активной
  continuation.

Он не должен self-select'ить `new` rows из общей доски. Ownership появляется
только после Jira claim/comment/status или явного dispatcher/PM dispatch; затем
task-файл/board обновляются как зеркало.

Одноразовые Codex worker-чаты, созданные автоматизациями для конкретного run,
должны архивировать себя после завершения или truthful blocker/no-task отчёта.
Это делается через `codex_app.set_thread_archived` (`archived: true`, без
`threadId`) последним tool-действием перед финалом. Постоянные dispatcher/watch
чаты, такие как Back-end watcher или QA monitor, не архивируются автоматически.

### Design Collision Rules

Для Design main и Designer 2 действуют дополнительные правила:

- одна Design-задача = один активный Design owner/thread;
- нельзя брать задачу, где другой дизайнер уже указан в `Dispatch`,
  `Исполнитель`, результате, Jira-комментарии или свежей role-thread истории;
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
PM: Jira issue SCRUM-* как источник очереди/status/owner
        │
        ▼
PM: локальный .md/task_board mirror при необходимости
        │
        ▼
PM/dispatcher указывает role/lane/locked paths; owner может быть unassigned
до Jira-pull claim или задан вручную
        │
        ▼
Codex role heartbeat / Claude worker / dispatcher берёт только matching Jira issue/контур
        │
        ▼
Исполнитель: работа + обновление Jira + local mirror + docs/design/*
        │
        ▼
QA/review: отдельная проверка после результата owner, без параллельной правки тех же файлов
```

## Шаблон Задачи

Локальный mirror/spec-файл: `docs/tasks/<role>_<short_task_name>_task.md`,
где `<role>` — `design`, `backend` или `animation`. Создаётся после Jira issue
и всегда содержит `Jira: SCRUM-<номер>`.

```md
# Задача Для <Role>-Агента: <Название>

Статус: new | in_progress | review | done | blocked
Контур: Codex | Claude
Owner: unassigned
Thread: n/a
Locked paths: <ключевые файлы/папки/ассеты/экраны>
Создано: <дата>
Автор: PM
Jira: SCRUM-<номер>

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

- Новая задача создается в Jira со статусом To Do/`new`; локальный mirror
  получает `Статус: new` только после Jira key.
- Исполнитель при взятии в работу обновляет Jira first (`in_progress`/comment),
  затем локальный mirror. По завершении — Jira + mirror `done` (или `review`,
  если нужна проверка PM) и короткое резюме результата.
- При взятии задачи исполнитель или dispatcher добавляет явный owner/claim note:
  роль, thread/worker id, lane, дата и краткая причина. Для Design это обязательно,
  потому что Design main и Designer 2 работают параллельно.
- PM синхронизирует Jira при каждом изменении; `docs/process/task_board.md`
  обновляется как dashboard/cache.
- Заблокированные задачи получают `blocked` с указанием, чего ждут.
- Закрытие задачи — ответственность владельца задачи. Dispatcher не ставит
  `done` вместо исполнителя, если нет подтвержденного результата в Jira/task mirror
  или QA-вердикта. При расхождении dispatcher добавляет Jira comment/заметку и
  возвращает задачу владельцу.
- При регулярной сверке dispatcher проверяет возможные дубли в Jira first:
  одинаковые Jira
  summary, одинаковые source task paths, одинаковые зоны файлов/ассетов или две
  активные задачи на одну проблему. Дубли не раздаются повторно: один Jira issue
  остается canonical, остальные помечаются `duplicate`/`superseded` с
  ссылкой на основной task/Jira.

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
6. Задача создана/обновлена в Jira и только затем отражена в локальном mirror/dashboard.
