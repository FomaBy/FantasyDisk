# ART/ANIM: Перерисовать «Солдат» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: blocked
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-434
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## PM Unhold / Current Queue State (2026-06-30)

Пользователь снял `user-hold` с задач в `К выполнению`: SCRUM-434 снова доступна
для автономного Jira-pull/dispatch. Историческая отмена 2026-06-15 ниже
сохранена как контекст, но больше не блокирует старт.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Солдат** (`soldier`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Солдат: дисциплинированный боец, чёткая форма, яркие тактические акценты; героично. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Солдат» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Солдат» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Солдат» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (soldier), current_game_state.

## Историческая отмена 2026-06-15 (перекрыта 2026-06-30)
Широкий редизайн персонажей v2 был отменён — пользователю не нравился подход.
2026-06-30 пользователь снял `user-hold` с To Do задач; текущий статус SCRUM-434
снова `new` / `К выполнению`.

## Blocker — Codex Design 2026-06-30

SCRUM-434 был claim-first взят `codex-design-board-watcher`, но производство
Soldier v2 source заблокировано доступностью PixelLab MCP. Активный
`fantasydisk-asset-generator` требует PixelLab MCP для новых production ассетов
и запрещает fallback на legacy `generate_asset.py`, OpenAI/image_gen или ручную
дорисовку без явного Jira override. `tool_search pixellab` вернул 0 доступных
tools.

В task mirror и ожидаемых source/runtime папках нет accepted/provisional Soldier
v2 source, который можно было бы честно принять или продвинуть без новой
генерации. Задача возвращена в Jira `К выполнению` с labels `blocked` и
`pixellab-blocked`. Unblock: подключить PixelLab MCP для Codex или явно создать
Jira override на non-PixelLab пайплайн, затем requeue Design/Codex или разделить
Design source и Animator integration.

## Blocker Refresh — Codex Design 2026-06-30

SCRUM-434 снова был выдан Jira-pull после PM readiness/unhold. Текущий Jira
definition of ready требует mandatory PixelLab character generation for
`soldier` plus 8-direction idle/move source pack; старый legacy Soldier PNG/cutout
набор не покрывает этот acceptance scope.

Codex Design проверил live PixelLab доступ перед генерацией:
- direct Codex tool discovery для `pixellab` вернул 0 exposed tools;
- локальный PixelLab MCP bridge из Codex config стартует, `initialize` успешен;
- `tools/list` возвращает 49 tools, включая `create_character`,
  `create_character_state`, `animate_character`, `get_character`,
  `list_characters`;
- реальный вызов `list_characters(tags="soldier", limit=5)` возвращает
  `401: Missing Authorization header`;
- stderr bridge указывает на отсутствующий `AUTH_HEADER`.

По активным `fantasydisk-asset-generator` и
`fantasydisk-pixellab-animation-integrator` fallback на legacy
`generate_asset.py`, OpenAI/image_gen, ручную дорисовку или не-PixelLab source
запрещён без явного Jira override. Поэтому source/runtime ассеты не создавались,
Godot smoke не запускался: runtime/assets/code не изменялись. Jira возвращена в
`К выполнению` с labels `blocked` + `pixellab-blocked`; claim не удерживается.

Unblock: настроить PixelLab MCP auth для Codex (`AUTH_HEADER="Bearer ..."` или
эквивалентный безопасный секрет в окружении) либо добавить в Jira явный override
на non-PixelLab/reuse pipeline с обновлёнными acceptance criteria.
