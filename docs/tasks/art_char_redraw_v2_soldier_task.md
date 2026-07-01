# ART/ANIM: Перерисовать «Солдат» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: blocked
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-434
Контур: Codex
Owner: Codex character serial integration worker
Thread/Worker: codex-character-serial-integration-20260701
Locked paths: `assets/sprites/characters/pixellab/soldier/`, `assets/sprites/characters/full_frame/soldier_pixellab/`, `assets/sprites/characters/soldier_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Result / Serial Integration — 2026-07-01

Combined integration branch: `codex/character-pixellab-serial-integration-20260701`.
Integration commit: `PENDING_FIRST_COMMIT` (first functional integration commit on this branch).

Source branch/commit: preferred clean Soldier source
`origin/codex/SCRUM-434-soldier-pixellab` @ `74d82284`; task-owned pack paths
were verified identical to alternate
`origin/codex/SCRUM-434-soldier-pixellab-dev` @ `44821f82`, which avoided stale
non-task branch diff while preserving the same Soldier assets.

Integrated:
- PixelLab source/manifest under `assets/sprites/characters/pixellab/soldier/`.
- Normalized runtime `512x512` frames under `assets/sprites/characters/full_frame/soldier_pixellab/`.
- `assets/sprites/characters/soldier_spriteframes.tres` with generic `idle`/`move`/`walk` plus 8-direction `idle_*`, 6-frame `move_*`, and 6-frame `walk_*` rows.
- `scripts/progression_data_characters.gd` now points `soldier.sprite_path` to `res://assets/sprites/characters/full_frame/soldier_pixellab/soldier_idle_south.png`.
- `docs/design/current_game_state.md`, `docs/design/content_registry.md`, `tests/animation_smoke_test.gd`, `tests/character_sprite_registry_alignment_test.gd`, and `tests/hero_select_pixellab_layout_test.gd` updated for the live PixelLab contract.

PixelLab source id: `72b487d3-feea-4012-b39f-b59ba24f7f11`.

Tests/evidence:
- PASS: static integration validator checked 56 source PNGs, 56 runtime PNGs, `512x512` RGBA runtime frames, manifest, SpriteFrames directional names, canonical sprite path, and no `.import`/`.uid` sidecars for Soldier/Thief/Elementalist/Robot.
- BLOCKED: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` waited for the shared semaphore but did not launch Godot because all default slots were held by unrelated `unique_weapon_vfx_assets_test.gd` import processes. The queued gate was interrupted with exit 130 to avoid an indefinite wait; after fast-forwarding to `origin/dev` (`39fca93c`), static validation still passed and a process recheck still showed multiple unrelated `unique_weapon_vfx_assets_test.gd` Godot/gate jobs occupying or waiting on the shared gate. No Soldier test failure was observed.
- Restored source-branch QA evidence under `build/qa/scrum434_soldier_pixellab/`.

Disk cleanup: none created by this integration run; no `.godot/`, Python cache, or temp download directory was created here. Imported QA evidence is intentionally kept.

## PM/Codex Reactivation — PixelLab Final Runtime Pass (2026-07-01)

Директива пользователя 2026-07-01: не все игровые персонажи находятся в новой
PixelLab-графике. SCRUM-434 переиспользуется как актуальный ticket для
`soldier` вместо создания дубля.

Актуальный scope: Codex Design main через `fantasydisk-pixellab-animation-integrator`
создаёт/интегрирует PixelLab 8-direction idle + 6-frame move/walk pack по текущим
референсам `assets/sprites/characters/soldier.png` и
`docs/design/references/characters/soldier/soldier_sheet_source.png`.

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

## Unblocked — PixelLab MCP 2026-06-30

PM/Codex cleanup rechecked PixelLab after the Codex config fix. The local
`mcp-remote` bridge now starts with the Codex bundled `node` in `PATH`,
`initialize` succeeds against `PixelLab MCP Server 0.2.0`, and authenticated
`get_balance` returns the active subscription/generation balance. The previous
`401 Missing Authorization header` / missing `AUTH_HEADER` blocker is stale.

Jira labels `blocked` and `pixellab-blocked` were removed; SCRUM-434 remains
`К выполнению`, unassigned, and ready for normal claim-first Design/Codex work.
Already-open Codex threads may still need restart/new thread tool discovery to
expose PixelLab tools. Disk cleanup: none created.
