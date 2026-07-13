---
name: perenos-chata
description: "Перенос рабочего чата между контекстами с правдивым Markdown handoff и безопасным архивированием. Use when the user asks to 'перенеси этот чат', 'суммаризируй чат и создай новый', 'continue this chat in a new thread', or needs a Codex/Claude task transferred while preserving the repository's authoritative tracker ownership, Git/push state, verification, cleanup, and the exact next action."
---

# Перенос чата

## Цель

Перенести разговор и проверяемое рабочее состояние в новый чат: собрать
контекст, создать самостоятельный Markdown snapshot, доставить его новому
thread, синхронизировать активную работу и только затем безопасно архивировать
исходный чат.

## Порядок

1. Определи платформу, workspace и доступные thread tools.
   - Для Codex найди `read_thread`, `create_thread`, `send_message_to_thread`,
     `set_thread_archived` и при необходимости `set_thread_title`.
   - Для Claude используй доступный chat/thread connector. Если его нет,
     подготовь snapshot и явно отметь недоступные операции.

2. Перечитай актуальные правила до действий.
   - В репозитории найди и полностью прочитай применимые `AGENTS.md` от корня
     до затрагиваемых путей. Не полагайся на старую сводку их содержимого.
   - Проверь authoritative tracker из актуального `AGENTS.md`. Для FantasyDisk
     это Multica project `FantasyDisk`: issue status, comments, assignee,
     parent/children, active runs, owner/thread и locked paths. Tracker имеет
     приоритет над локальными mirrors и legacy Jira history.
   - Выполняй разрешённые prompt/`AGENTS.md` in-scope действия автономно: не
     запрашивай рутинные подтверждения для чтения, правок в locked scope,
     tracker sync, тестов, commit/push или явно запрошенного переноса thread.
   - Не расширяй scope. Остановись только при объективной невозможности,
     нехватке credentials/authority или destructive external action вне repo;
     зафиксируй точный blocker вместо догадки.

3. Собери факты из исходного контекста.
   - Предпочитай полный read thread/chat. При недоступности используй видимую
     историю и пометь ограничение.
   - Проверь текущие файлы и внешнее состояние, если они могли измениться.
   - Не включай secrets, tokens, cookies, credentials или лишние логи.

4. Приведи активную задачу к правдивому состоянию.
   - Не оставляй issue в stale active state за архивируемым worker/thread.
   - При продолжении тем же owner запиши heartbeat/handoff с новым thread id и
     следующим шагом. При остановке переведи задачу в разрешённое правилами
     ready, QA/review или blocked state с причиной согласно live workflow.
   - Не заявляй completion без требуемых tests, commit и push. Отметь
     uncommitted/unpushed work явно.

5. Создай Markdown snapshot.
   - Сохрани `docs/chat_transfers/YYYY-MM-DD_HHMM_<slug>.md`, только если запись
     разрешена task scope и правилами repo. Иначе используй разрешённый
     `chat_transfers/` путь или передай snapshot текстом без repo mutation.
   - Пиши самостоятельную сводку, пригодную для продолжения без старого чата.

6. Создай и наполни новый чат.
   - Назови его `Перенос: <краткая тема>`.
   - Отправь инструкцию продолжать с сохранённого состояния, затем snapshot
     или поддерживаемую ссылку/вложение.
   - Проверь успешную доставку. При ошибке не архивируй источник.

7. Заверши sync и cleanup, затем архивируй источник.
   - Выполни обязательные tracker/Git/docs/tests/disk операции или запиши
     правдивый blocker и next owner/state.
   - Архивируй только успешно переданный, не постоянный dispatcher/PM/control
     thread. Для disposable worker сделай archive последним tool action перед
     финальным ответом.
   - Если архивирование недоступно, оставь источник активным и сообщи об этом.

## Формат Snapshot

```markdown
# Перенос чата: <тема>

- Дата: <YYYY-MM-DD HH:MM TZ>
- Источник: <Codex/Claude + thread/chat id>
- Новый чат: <id/link>
- Источник контекста: <full read | visible history only | unavailable>
- Прочитанные правила: <актуальные AGENTS.md и task/process docs>

## Цель и краткое резюме

<текущая цель, что сделано, ключевые решения>

## Tracker / ownership

- Tracker/issue/status: <system, key, live status>
- Owner/worker/lane: <значения>
- Locked paths: <точные пути>
- Последний heartbeat/handoff: <время и смысл>
- Следующий tracker state/owner: <значение>

## Git / workspace

- Repo/worktree/branch: <absolute path, branch>
- HEAD/upstream: <commit, ahead/behind>
- Commit/push: <hash и destination | uncommitted/unpushed + причина>
- Dirty paths: <список или clean>

## Проверки и документация

- Tests: <команды и PASS/FAIL/not run + причина>
- Docs/mirrors: <обновлённые пути или not needed>

## Cleanup

- Disk cleanup: <removed paths | none created | blocker + size>
- Thread cleanup: <archive pending/complete/unavailable и почему>

## Решения, риски и незавершённое

- <важные ограничения и блокеры>
- <точный следующий шаг>

## Инструкция новому чату

Продолжай с этого состояния. Сначала перепроверь live tracker, Git и применимые
AGENTS.md, затем выполни указанный следующий шаг автономно в locked scope.
```

## Качество

- Используй язык пользователя; сохраняй команды, ids, пути и API дословно.
- Не делай transcript dump. Сжимай до решений, фактов, evidence и next action.
- Помечай `не проверено` вместо предположений.
- Не архивируй источник до подтверждённой доставки snapshot и правдивого
  tracker/Git/cleanup состояния.
