# ART/ANIM: Перерисовать «Инженер» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: new
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-428
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## PM Unhold / Current Queue State (2026-06-30)

Пользователь снял `user-hold` с задач в `К выполнению`: SCRUM-428 снова доступна
для автономного Jira-pull/dispatch. Историческая отмена 2026-06-15 ниже
сохранена как контекст, но больше не блокирует старт.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Инженер** (`engineer`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Инженер: изобретатель, тёплая медь+латунь, искры, светящиеся гаджеты; ярко, харизматично. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Инженер» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Инженер» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Инженер» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (engineer), current_game_state.

## Dispatcher Handoff To Designer 2 (2026-06-15)

Передано Designer 2 thread `019ec7a6-55a5-7bc3-a397-606ce046308d` как следующий
свободный 0.1.6 character v2 Design-source row.

Scope for this pass: produce only Engineer v2 Design/source artifacts in the
SCRUM-422 bright/epic style: transparent source PNG, strict alpha/white/neutral
cleanup validation, normalized 512-cell, source-sheet handoff, contact/dark-bg
preview, pivot/height report, task/docs/board/Jira updates. Do not build
SpriteFrames, runtime integration, AnimationPlayer/AnimationTree, animation
smoke, gameplay logic, balance, or attack frames. Animator starts only after the
Engineer source handoff is accepted. Keep reasoning High/no low.

## Историческая отмена 2026-06-15 (перекрыта 2026-06-30)
Широкий редизайн персонажей v2 был отменён — пользователю не нравился подход.
2026-06-30 пользователь снял `user-hold` с To Do задач; текущий статус SCRUM-428
снова `new` / `К выполнению`.

## Designer 2 Conflict Audit (2026-06-15)

Получен поздний dispatcher handoff на SCRUM-428, но локальный task-файл и board
уже содержат пользовательскую отмену broad character v2 redesign. Designer 2 не
переводит задачу в `review` и не создаёт Animator/runtime handoff.

До обнаружения отмены были сгенерированы provisional Engineer source artifacts:
`docs/design/references/characters_v2/engineer/`,
`assets/sprites/characters/v2/engineer/`,
`docs/design/previews/scrum428_engineer_v2_contact.png`,
`docs/design/previews/scrum428_engineer_v2_dark_bg.png`,
`build/qa/scrum428_engineer_v2/`.
Strict PNG QA по provisional outputs: `white=0`, `neutral=0`, `pale=0`,
`edge=0`. Эти файлы оставлены на месте для dispatcher/PM reconciliation, но
**не считались accepted source handoff** на момент отмены; после снятия hold
следующий Design/Animator worker должен переоценить эти provisional artifacts
перед использованием.

## Blocker — Codex Design 2026-06-30

SCRUM-428 был claim-first взят `codex-design-board-watcher`, но производство или
acceptance Engineer v2 source заблокированы текущей доступностью PixelLab MCP.
Активный `fantasydisk-asset-generator` требует PixelLab MCP для новых production
ассетов и запрещает fallback на legacy `generate_asset.py`, OpenAI/image_gen или
ручную дорисовку без явного Jira override. `tool_search pixellab` вернул 0
доступных tools.

В репозитории уже есть provisional Engineer v2 artifacts, но этот же task mirror
помечает их как не принятый source handoff после отмены 2026-06-15; принимать
или продвигать их в production без PixelLab означало бы обойти активный skill.
Задача возвращена в Jira `К выполнению` с labels `blocked` и
`pixellab-blocked`. Unblock: подключить PixelLab MCP для Codex или явно создать
Jira override на acceptance существующих provisional artifacts / non-PixelLab
пайплайн, затем requeue Design/Codex или разделить Design source acceptance и
Animator integration.

## Blocker Refresh — Codex Design 2026-06-30

SCRUM-428 был повторно claim-first взят `codex-design-board-watcher` после PM
readiness/unhold. Повторная проверка показала, что PixelLab MCP bridge теперь
виден через локальный Codex config и отдаёт `tools/list` (`49` tools, включая
`list_characters`, `create_character`, `animate_character`), но реальный вызов
`list_characters(tags="engineer")` возвращает:

`401: Missing Authorization header. Please configure your MCP client with 'Authorization: Bearer YOUR_API_TOKEN'`.

Дополнительное evidence: `mcp-remote` stderr сообщает, что custom header
настроен как `Authorization: ${AUTH_HEADER}`, но environment variable
`AUTH_HEADER` не задана. Без валидного PixelLab auth нельзя получить или создать
обязательный PixelLab source/motion pack для `engineer`, а активные skills
запрещают fallback на legacy OpenAI/manual/provisional assets без явного Jira
override.

Задача снова возвращена в Jira `К выполнению` с labels `blocked` и
`pixellab-blocked`. Unblock: передать Codex runtime переменную `AUTH_HEADER`
с валидным `Bearer ...` для PixelLab MCP либо оставить явный Jira override на
использование существующих provisional Engineer artifacts / non-PixelLab path.

## Unblocked — PixelLab MCP 2026-06-30

PM/Codex cleanup rechecked PixelLab after the Codex config fix. The local
`mcp-remote` bridge now starts with the Codex bundled `node` in `PATH`,
`initialize` succeeds against `PixelLab MCP Server 0.2.0`, and authenticated
`get_balance` returns the active subscription/generation balance. The previous
`401 Missing Authorization header` / missing `AUTH_HEADER` blocker is stale.

Jira labels `blocked` and `pixellab-blocked` were removed; SCRUM-428 remains
`К выполнению`, unassigned, and ready for normal claim-first Design/Codex work.
Already-open Codex threads may still need restart/new thread tool discovery to
expose PixelLab tools. Disk cleanup: none created.
