# ART/ANIM: Перерисовать «Рыцарь» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: done
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-430
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## PM Unhold / Current Queue State (2026-06-30)

Пользователь снял `user-hold` с задач в `К выполнению`: SCRUM-430 снова доступна
для автономного Jira-pull/dispatch. Историческая отмена 2026-06-15 ниже
сохранена как контекст, но больше не блокирует старт.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Рыцарь** (`knight`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Рыцарь: благородный латник, СВЕТЛАЯ полированная сталь + яркий плюмаж/геральдика; величественно, эпично. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Рыцарь» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Рыцарь» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Рыцарь» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (knight), current_game_state.

## Историческая отмена 2026-06-15 (перекрыта 2026-06-30)
Широкий редизайн персонажей v2 был отменён — пользователю не нравился подход.
2026-06-30 пользователь снял `user-hold` с To Do задач; текущий статус SCRUM-430
снова `new` / `К выполнению`.

## Blocker — Codex Design 2026-06-30

SCRUM-430 был claim-first взят `codex-design-board-watcher`, но производство
Knight v2 source заблокировано доступностью PixelLab MCP. Активный
`fantasydisk-asset-generator` требует PixelLab MCP для новых production ассетов
и запрещает fallback на legacy `generate_asset.py`, OpenAI/image_gen или ручную
дорисовку без явного Jira override. `tool_search pixellab` вернул 0 доступных
tools.

В task mirror нет accepted/provisional Knight v2 source, который можно было бы
честно принять или продвинуть без новой генерации. Задача возвращена в Jira
`К выполнению` с labels `blocked` и `pixellab-blocked`. Unblock: подключить
PixelLab MCP для Codex или явно создать Jira override на non-PixelLab пайплайн,
затем requeue Design/Codex или разделить Design source и Animator integration.

## Blocker Refresh — Codex Design 2026-06-30

SCRUM-430 был повторно claim-first взят `codex-design-board-watcher` после PM
readiness/unhold. Повторная проверка показала, что PixelLab MCP bridge теперь
виден через локальный Codex config и отдаёт `tools/list` (`49` tools, включая
`list_characters`, `create_character`, `animate_character`), но реальный вызов
`list_characters(tags="knight")` возвращает:

`401: Missing Authorization header. Please configure your MCP client with 'Authorization: Bearer YOUR_API_TOKEN'`.

Дополнительное evidence: `mcp-remote` stderr указывает, что custom header
настроен как `Authorization: ${AUTH_HEADER}`, но environment variable
`AUTH_HEADER` не задана. Без валидного PixelLab auth нельзя получить или создать
обязательный PixelLab source/motion pack для `knight`, а активные skills
запрещают fallback на legacy OpenAI/manual assets без явного Jira override.

Задача снова возвращена в Jira `К выполнению` с labels `blocked` и
`pixellab-blocked`. Unblock: передать Codex runtime переменную `AUTH_HEADER`
с валидным `Bearer ...` для PixelLab MCP либо добавить явный Jira override на
non-PixelLab path.

## Unblocked — PixelLab MCP 2026-06-30

PM/Codex cleanup rechecked PixelLab after the Codex config fix. The local
`mcp-remote` bridge now starts with the Codex bundled `node` in `PATH`,
`initialize` succeeds against `PixelLab MCP Server 0.2.0`, and authenticated
`get_balance` returns the active subscription/generation balance. The previous
`401 Missing Authorization header` / missing `AUTH_HEADER` blocker is stale.

Jira labels `blocked` and `pixellab-blocked` were removed; SCRUM-430 remains
`К выполнению`, unassigned, and ready for normal claim-first Design/Codex work.
Already-open Codex threads may still need restart/new thread tool discovery to
expose PixelLab tools. Disk cleanup: none created.

## Result — Codex Design 2026-06-30

Status: review / QA-ready after PixelLab generation and runtime resource wiring.

Owner: Design/Codex (`codex-design-scrum-430-knight-pixellab`)
Branch/worktree: `codex/scrum-430-knight-pixellab` at
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-430-knight-pixellab`

Delivered:
- PixelLab MCP config/auth smoke PASS (`get_balance` active subscription; no
  token printed).
- Created Knight PixelLab source character
  `c1a7d633-7353-4861-aea3-8d937b601cba`
  (`FantasyDisk Knight PixelLab SCRUM-430 no-shield 2026-06-30`), after
  superseding first pass `7441d877-05f4-46da-9768-6b6be6f3b8dd` because the
  contact sheet read as a baked shield silhouette.
- Downloaded 8-direction idle rotations and 8-direction `walking-6-frames`
  movement rows (6 frames per direction) into
  `assets/sprites/characters/pixellab/knight/`.
- Built normalized 512x512 runtime PNGs under
  `assets/sprites/characters/full_frame/knight_pixellab/`.
- Rebuilt `assets/sprites/characters/knight_spriteframes.tres` with generic
  `idle`/`walk`/`move` plus `idle_<dir>`, `walk_<dir>`, `move_<dir>` rows for
  all 8 directions.
- Updated Knight portrait path to
  `res://assets/sprites/characters/full_frame/knight_pixellab/knight_idle_south.png`.
- Updated content/current-state/animation/visual-style docs, changelog, and
  focused tests for the PixelLab Knight pack.

QA evidence:
- Contact sheet: `build/qa/scrum430_knight_pixellab/knight_pixellab_contact.png`.
- Alpha report: `build/qa/scrum430_knight_pixellab/alpha_report.json`.
- Source manifest: `assets/sprites/characters/pixellab/knight/manifest.json`.

Notes:
- The accepted source has no baked weapon or shield; spear, tower shield and
  holy flail remain separate weapon visuals.
- `player.gd` still contains the existing Knight skeleton-rig path from prior
  work; this Design pass did not refactor backend/skeleton ownership.
