# ART/ANIM: Перерисовать «Снайпер» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: done
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-433
Контур: Codex
Owner: Codex Animator worker
Thread/Worker: codex-animator-auto
Locked paths: `assets/sprites/characters/pixellab/sniper/`, `assets/sprites/characters/full_frame/sniper_pixellab/`, `assets/sprites/characters/sniper_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.
QA: ready for QA after Codex Animator integration on 2026-07-01
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## PM/Codex Reactivation — PixelLab Final Runtime Pass (2026-07-01)

Директива пользователя 2026-07-01: не все игровые персонажи находятся в новой
PixelLab-графике. SCRUM-433 переиспользуется как актуальный ticket для `sniper`
вместо создания дубля.

Актуальный scope: Codex Design main через `fantasydisk-pixellab-animation-integrator`
создаёт/интегрирует PixelLab 8-direction idle + 6-frame move/walk pack по текущим
референсам `docs/design/references/characters_v2/sniper/sniper_v2_source_clean.png`,
`docs/design/references/characters/sniper/sniper_sheet_source.png` и
`assets/sprites/characters/sniper.png`.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Codex Animator Claim — 2026-07-01

SCRUM-433 взят `codex-animator-auto` через Jira-pull для серийной Animator/runtime
интеграции после QA-возврата. Scope этого pass: влить уже созданный PixelLab
Sniper pack из `origin/codex/scrum-433-sniper-pixellab` в dev-based worktree,
подключить live `sprite_path`, обновить docs/tests/evidence, прогнать focused
animation/Hero Select smokes, закоммитить и запушить в `origin/dev`.

Locked paths:
- `assets/sprites/characters/pixellab/sniper/`
- `assets/sprites/characters/full_frame/sniper_pixellab/`
- `assets/sprites/characters/sniper_spriteframes.tres`
- `scripts/progression_data_characters.gd`
- character docs/tests/evidence for SCRUM-433

Next verification step: import existing PixelLab pack, wire Sniper portrait/runtime
to `sniper_pixellab/sniper_idle_south.png`, then run focused animation and Hero
Select registry checks.

## Codex Animator Result — 2026-07-01

SCRUM-433 Animator/runtime integration completed and ready for QA. The previously
created PixelLab Sniper pack from `origin/codex/scrum-433-sniper-pixellab`
(`PixelLab character_id: 74c4f7db-ed7f-4b6a-b9b3-bc18e417563c`) is now present
in the dev-based worktree and wired as the live Sniper runtime.

Implemented:
- Source pack: `assets/sprites/characters/pixellab/sniper/` (56 PNG frames + manifest/import metadata).
- Runtime pack: `assets/sprites/characters/full_frame/sniper_pixellab/` (56 transparent normalized PNG frames).
- SpriteFrames: `assets/sprites/characters/sniper_spriteframes.tres` with 8-direction idle plus 6-frame move/walk rows.
- Runtime portrait/path: `scripts/progression_data_characters.gd` now uses `res://assets/sprites/characters/full_frame/sniper_pixellab/sniper_idle_south.png`.
- Hero Select and registry tests include Sniper in PixelLab directional coverage.
- Docs updated in `CHANGELOG.md`, `docs/design/content_registry.md`,
  `docs/design/current_game_state.md`, and `docs/design/systems/animation.md`.

Verification passed:
- `python3 tools/godot_gate.py --headless --path . --script res://build/qa/scrum433_sniper_pixellab/sniper_spriteframes_validate.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`

Disk cleanup: generated Godot `.godot/` import cache removed before final report;
unrelated generated `.import` sidecars from test import were discarded; no
disposable external checkout created.

## PM Unhold / Current Queue State (2026-06-30)

Пользователь снял `user-hold` с задач в `К выполнению`: SCRUM-433 снова доступна
для автономного Jira-pull/dispatch. Историческая отмена 2026-06-15 ниже
сохранена как контекст, но больше не блокирует старт.

## Designer 2 Takeover (2026-06-15)

Взято Designer 2 после heartbeat/board check. SCRUM-422 anchor завершён,
SCRUM-427 Elementalist v2 Design-source отправлен в review, следующий свободный
Design-row — Sniper v2. Scope этого pass: подготовить accepted bright+epic
Design source-pack для `sniper` с transparent 512-cell source и source-sheet
handoff; runtime SpriteFrames/Animation smoke остаются Animator / Back-end
handoff после acceptance.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Снайпер** (`sniper`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Снайпер: элитный стрелок, холодные сине-стальные тона + яркий оптический блик; чётко, эпично. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Снайпер» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Снайпер» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Снайпер» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (sniper), current_game_state.

## Design Result (Designer 2 / 2026-06-15)

Готов Design-source pack для `sniper` и передан в review для Animator/Back-end
handoff. Scope намеренно ограничен исходниками/спеком: runtime SpriteFrames,
живые idle/move кадры, Godot import и smoke tests остаются следующему
Animator/Back-end pass.

Принятые пути:
- Raw source: `docs/design/references/characters_v2/sniper/sniper_v2_source_raw.png`
- Clean source: `docs/design/references/characters_v2/sniper/sniper_v2_source_clean.png`
- 512-cell source: `docs/design/references/characters_v2/sniper/sniper_v2_idle_cell_512.png`
- Source-sheet handoff: `docs/design/references/characters_v2/sniper/sniper_v2_sheet_source_handoff.png`
- Asset-side handoff copies: `assets/sprites/characters/v2/sniper/sniper_v2_idle_source.png`,
  `assets/sprites/characters/v2/sniper/sniper_v2_sheet_source_handoff.png`,
  `assets/sprites/characters/v2/sniper/sniper_v2_sheet.png`
- Preview: `docs/design/previews/scrum433_sniper_v2_contact.png`
- Handoff spec: `docs/design/references/characters_v2/sniper/sniper_v2_design_handoff.md`
- QA report: `build/qa/scrum433_sniper_v2/scrum433_sniper_v2_alpha_size_report.json`

Acceptance notes:
- Bright/epic cold blue-steel Sniper silhouette with optical targeting light.
- Empty hands; no rifle, gun, bow, crossbow, scope, weapon, tool or held object
  baked into the character source.
- Transparent RGBA after strict cleanup; no checker/background, no baked shadow.
- Normalized `512x512` source cell, pivot `[256,470]`, visible bbox
  `[146,96,367,470]`, visible height `374 px`.
- White/neutral matte QA passed: `0` opaque-white pixels, `0` neutral-light
  visible pixels and `0` edge-visible pixels in source/cell/sheet outputs.
- The `2560x1024` sheet is a source handoff placeholder repeating the accepted
  cell for idle/move rows; Animator must produce real idle and move/walk frames
  before SpriteFrames/runtime integration.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-source: sniper v2 ярко/эпично + 512-cell + source-sheet handoff); Animator-фаза (idle/move) — pending

Проверено (фактически):
- **sniper v2 source прозрачный**: `sniper_v2_source_clean` (1024²), `_idle_cell_512`
  (512²), `_sheet_source_handoff` (2560×1024) — все RGBA, corner_alpha=0, прозрачные
  (raw 1024² opaque — сырьё).
- **Визуал** `scrum433_sniper_v2_contact.png`: снайпер-марксман в сине-тёмном плаще с
  синим энергетическим свечением, прицельная поза (класс-идентичность дальнобойного),
  насыщенные акценты (консистентно с анкором SCRUM-422, ярче 0.1.5 dark), прозрачность ✓.
- **Source-sheet handoff**: idle row + move row, 5 columns placeholder-слотов каждый
  (motion — Animator-owned).

⚠️ **Реальная idle/move анимация + SpriteFrames + runtime ещё НЕ сделаны** — Animator-фаза
(pending). НЕ промоутил в Готово.

Acceptance (Design-source scope):
- [x] sniper v2 перерисован ярко/эпично, прозрачный (нет белого/каймы/карманов).
- [x] Design-source handoff: 512-cell, source-sheet layout, contact preview.
- [~] idle+move анимация, 2× монстра, виден/анимирован в игре — Animator follow-up (pending).

Статус: Design-source PASS, ждёт Animator-фазу. Баги: нет (Design-scope).

## Историческая отмена 2026-06-15 (перекрыта 2026-06-30)
Широкий редизайн персонажей v2 был отменён — пользователю не нравился подход.
2026-06-30 пользователь снял `user-hold` с To Do задач; текущий статус SCRUM-433
снова `new` / `К выполнению`.

## Codex Design Claim Audit / Release — 2026-06-30

`codex-design-board-watcher` claim-first взял SCRUM-433 и проверил mirror/Jira
историю. Новую Design-генерацию начинать нельзя и не нужно: Design-source scope
уже записан выше как PASSED by Designer 2, accepted source paths и QA evidence
присутствуют в репозитории.

Оставшаяся работа — Animator/runtime integration: реальные idle/move кадры,
SpriteFrames, Godot import/runtime hookup и animation/runtime smoke. Jira
возвращена в `К выполнению`; Design claim снят, stale `В работе` owner не
оставлен. Для очереди это должно идти как Animator/Codex follow-up, а не как
новая Design/Codex генерация.

## Blocker Refresh — Codex Design 2026-06-30

SCRUM-433 был повторно claim-first взят `codex-design-board-watcher` после PM
readiness/unhold. Текущая Jira readiness уже требует не acceptance старого
Designer 2 source handoff, а обязательный PixelLab character generation +
8-direction idle/move source pack для `sniper`.

Повторная проверка показала, что PixelLab MCP bridge виден через локальный
Codex config и отдаёт `tools/list` (`49` tools, включая `list_characters`,
`create_character`, `animate_character`), но реальный вызов
`list_characters(tags="sniper")` возвращает:

`401: Missing Authorization header. Please configure your MCP client with 'Authorization: Bearer YOUR_API_TOKEN'`.

Дополнительное evidence: `mcp-remote` stderr указывает, что custom header
настроен как `Authorization: ${AUTH_HEADER}`, но environment variable
`AUTH_HEADER` не задана. Без валидного PixelLab auth нельзя получить или создать
обязательный PixelLab source/motion pack для `sniper`, а активные skills
запрещают fallback на legacy OpenAI/manual assets без явного Jira override.

Задача возвращена в Jira `К выполнению` с labels `blocked` и
`pixellab-blocked`; stale `В работе` owner не оставлен. Unblock: передать Codex
runtime переменную `AUTH_HEADER` с валидным `Bearer ...` для PixelLab MCP либо
добавить явный Jira override на non-PixelLab path / повторное использование
старого Design-source handoff.

## Unblocked — PixelLab MCP 2026-06-30

PM/Codex cleanup rechecked PixelLab after the Codex config fix. The local
`mcp-remote` bridge now starts with the Codex bundled `node` in `PATH`,
`initialize` succeeds against `PixelLab MCP Server 0.2.0`, and authenticated
`get_balance` returns the active subscription/generation balance. The previous
`401 Missing Authorization header` / missing `AUTH_HEADER` blocker is stale.

Jira labels `blocked` and `pixellab-blocked` were removed; SCRUM-433 remains
`К выполнению`, unassigned, and ready for normal claim-first Design/Codex work.
Already-open Codex threads may still need restart/new thread tool discovery to
expose PixelLab tools. Disk cleanup: none created.
