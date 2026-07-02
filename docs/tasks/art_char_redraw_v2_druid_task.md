# ART/ANIM: Перерисовать «Друид» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: done
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-426
Контур: Codex
Owner: Design/Codex
Thread/Worker: codex-design-druid-rescue-20260701
Locked paths: `assets/sprites/characters/pixellab/druid/`, `assets/sprites/characters/full_frame/druid_pixellab/`, `assets/sprites/characters/druid_spriteframes.tres`, `scripts/progression_data_characters.gd`, `tests/animation_smoke_test.gd`, `tests/character_sprite_registry_alignment_test.gd`, `tests/hero_select_pixellab_layout_test.gd`, `docs/tasks/art_char_redraw_v2_druid_task.md`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/animation.md`, `CHANGELOG.md`, `build/qa/scrum426_druid_pixellab/`
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## PM Unhold / Current Queue State (2026-06-30)

Пользователь снял `user-hold` с задач в `К выполнению`: SCRUM-426 снова доступна
для автономного Jira-pull/dispatch. Историческая отмена 2026-06-15 ниже
сохранена как контекст, но больше не блокирует старт.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Друид** (`druid`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Друид: друид природы, ЯРКАЯ зелень с золотистым свечением, листва/цветы; живо, тепло. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Друид» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Друид» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Друид» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (druid), current_game_state.

## Историческая отмена 2026-06-15 (перекрыта 2026-06-30)
Широкий редизайн персонажей v2 был отменён — пользователю не нравился подход.
2026-06-30 пользователь снял `user-hold` с To Do задач; текущий статус SCRUM-426
снова `new` / `К выполнению`.

## Blocker — Codex Design 2026-06-30

Jira-pull claim by `codex-design-board-watcher` confirmed SCRUM-426 is eligible
again, but production work is blocked before asset creation: current
`fantasydisk-asset-generator` requires PixelLab MCP for new character art and
forbids legacy OpenAI/`generate_asset.py`/`image_gen` fallback. PixelLab tools
were not exposed in this Codex session; the same configured local
`mcp_servers.pixellab` bridge was tested immediately before on SCRUM-423 and
did not complete MCP `initialize/tools/list` handshake. No character files were
generated or modified. Jira labels `blocked` and `pixellab-blocked` were added,
and the issue was returned to `К выполнению` to avoid a stale `В работе` owner.

## PM Readiness Update — PixelLab 2026-06-30

PM/Jira повторно открыл SCRUM-426 для Design/Codex: Druid должен быть пересобран
через PixelLab по актуальному runtime-пайплайну, аналогично Dark Mage PixelLab
Hero Select/runtime примеру (SCRUM-685). Обязательный scope: PixelLab character
source/fetch для `druid`, 8-direction idle poses, 8-direction move/walk
animation, transparent normalized 512x512 runtime pack under
`assets/sprites/characters/full_frame/druid_pixellab/`, source manifest under
`assets/sprites/characters/pixellab/druid/`, `druid_spriteframes.tres`,
runtime/Hero Select integration, docs and focused smokes. Non-PixelLab fallback
is not allowed unless Jira explicitly records an override.

## Blocker Update — Codex Design 2026-06-30

`codex-design-board-watcher` claim-first взял SCRUM-426 after PM readiness and
rechecked PixelLab availability. The local `mcp_servers.pixellab` bridge now
initializes and returns the PixelLab tool list (`49` tools), but actual tool
calls fail with `401 Missing Authorization header`; no token/secret was printed.

Because `fantasydisk-asset-generator` and
`fantasydisk-pixellab-animation-integrator` both require PixelLab for this
production character source/animation scope and forbid legacy/OpenAI/manual
fallback, no asset/runtime integration was started. Jira was returned to
`К выполнению` with labels `blocked` and `pixellab-blocked`. Unblock: configure
PixelLab MCP Authorization for Codex Desktop `mcp-remote`, then requeue
SCRUM-426 for Design/Codex.

## Unblocked — PixelLab MCP 2026-06-30

PM/Codex cleanup rechecked PixelLab after the Codex config fix. The local
`mcp-remote` bridge now starts with the Codex bundled `node` in `PATH`,
`initialize` succeeds against `PixelLab MCP Server 0.2.0`, and authenticated
`get_balance` returns the active subscription/generation balance. The previous
`401 Missing Authorization header` / missing `AUTH_HEADER` blocker is stale.

Jira labels `blocked` and `pixellab-blocked` were removed; SCRUM-426 remains
`К выполнению`, unassigned, and ready for normal claim-first Design/Codex work.
Already-open Codex threads may still need restart/new thread tool discovery to
expose PixelLab tools. Disk cleanup: none created.

## Result — Codex Design 2026-06-30

SCRUM-426 completed the PixelLab directional Druid pass and is ready for QA.

- PixelLab character: `4078113b-fece-4087-a035-9ed3714a6514`
  (`FantasyDisk SCRUM-426 druid`), tagged/name-matched for `druid` / `SCRUM-426`.
- Source pack: `assets/sprites/characters/pixellab/druid/` with 8 idle poses,
  8-direction walk/move animation at 6 frames per direction, transparent PNGs,
  and `manifest.json`.
- Runtime pack: `assets/sprites/characters/full_frame/druid_pixellab/` with 56
  normalized 512x512 transparent PNGs.
- SpriteFrames: `assets/sprites/characters/druid_spriteframes.tres` exposes
  generic `idle`/`move`/`walk` plus 8-direction `idle_*`, `move_*`, and `walk_*`
  rows; attack animations are intentionally absent.
- Runtime integration: `scripts/progression_data_characters.gd` points Druid to
  `res://assets/sprites/characters/full_frame/druid_pixellab/druid_idle_south.png`.
- Docs/tests updated: `content_registry`, `current_game_state`,
  `docs/design/systems/animation.md`, `CHANGELOG.md`,
  `tests/character_sprite_registry_alignment_test.gd`,
  `tests/hero_select_pixellab_layout_test.gd`, and
  `tests/animation_smoke_test.gd`.
- QA evidence: `build/qa/scrum426_druid_pixellab/` includes contact sheets and
  alpha/dimension report (`source_png_count: 56`, `runtime_png_count: 56`,
  `errors: []`).

Checks:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` — exit 0 / final pass line printed; existing unrelated dirty Biologist SpriteFrames emitted pre-existing `attack`/`attack_primary` errors and were not modified under SCRUM-426.
- `git diff --check` — passed.

Disk cleanup: removed `.godot`; no `__pycache__` found; removed ignored QA
`.png.import` sidecars from `build/qa/scrum426_druid_pixellab/`.

## Rescue Result — Codex Design 2026-07-01

Fresh dispatcher claim `codex-design-druid-rescue-20260701` rescued the previous
stranded SCRUM-426 result by replaying the Druid PixelLab pack onto a dedicated
worktree from `origin/dev`, then merging the latest `origin/dev` before
verification. The stale/wrong-lane Claude claims are ignored per Jira dispatcher
comment 2026-07-01.

- Branch/worktree: `codex/scrum-426-druid-rescue` at
  `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-426-druid-rescue`.
- PixelLab character: `4078113b-fece-4087-a035-9ed3714a6514`
  (`FantasyDisk SCRUM-426 druid`).
- Source/runtime pack remains PixelLab-only: 56 source PNGs under
  `assets/sprites/characters/pixellab/druid/`, 56 normalized transparent
  `512x512` runtime PNGs under
  `assets/sprites/characters/full_frame/druid_pixellab/`, manifest included.
- `druid_spriteframes.tres` exposes generic `idle`/`move`/`walk` plus all
  8-direction `idle_*`, `move_*`, and `walk_*` rows; body attack rows remain
  absent by weapon-owned visual scope.
- Druid `sprite_path` points to
  `res://assets/sprites/characters/full_frame/druid_pixellab/druid_idle_south.png`.
- Rescue merge preserved newer `origin/dev` PixelLab Doctor/Priest/Guitarist/
  Dark Mage docs and tests while adding Druid to the current directional roster.

Checks:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd` — passed (`17 characters`).
- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` — passed.

Disk cleanup: pending final cleanup after Jira sync/commit/push; `.godot` import
cache was created by the focused Godot smokes and must be removed before final
report.
