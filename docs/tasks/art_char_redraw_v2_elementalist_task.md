# ART/ANIM: Перерисовать «Элементалист» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: done
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-427
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Designer 2 Takeover (2026-06-15)

Взято Designer 2 после heartbeat/board check. SCRUM-422 anchor завершён,
SCRUM-435 Thief v2 Design-source отправлен в review, следующий свободный
Design-row — Elementalist v2. Scope этого pass: подготовить accepted
bright+epic Design source-pack для `elementalist` с transparent 512-cell source
и source-sheet handoff; runtime SpriteFrames/Animation smoke остаются Animator /
Back-end handoff после acceptance.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Элементалист** (`elementalist`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Элементалист: маг стихий, ЯРКИЕ потоки огня/льда/молнии вокруг рук, многоцветно и эффектно. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Элементалист» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Элементалист» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [x] «Элементалист» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [x] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [x] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (elementalist), current_game_state.

## Design Result (Designer 2 / 2026-06-15)

Статус: Design-source ready for review; Animator/Back-end integration pending.

Produced the Elementalist v2 bright+epic source pack through the required
`fantasydisk-asset-generator` flow and SCRUM-422 anchor format:

- raw OpenAI source:
  `docs/design/references/characters_v2/elementalist/elementalist_v2_source_raw.png`;
- alpha-clean source:
  `docs/design/references/characters_v2/elementalist/elementalist_v2_source_clean.png`;
- normalized 512-cell source:
  `docs/design/references/characters_v2/elementalist/elementalist_v2_idle_cell_512.png`;
- Design-source sheet handoff:
  `docs/design/references/characters_v2/elementalist/elementalist_v2_sheet_source_handoff.png`;
- asset-side source copies:
  `assets/sprites/characters/v2/elementalist/elementalist_v2_idle_source.png`,
  `assets/sprites/characters/v2/elementalist/elementalist_v2_sheet_source_handoff.png`
  and `assets/sprites/characters/v2/elementalist/elementalist_v2_sheet.png`;
- contact / dark-background preview:
  `docs/design/previews/scrum427_elementalist_v2_contact.png`;
- handoff note:
  `docs/design/references/characters_v2/elementalist/elementalist_v2_design_handoff.md`;
- alpha/size report:
  `build/qa/scrum427_elementalist_v2/scrum427_elementalist_v2_alpha_size_report.json`.

Design acceptance notes:

- Class fantasy: bright epic multi-element caster with fire, ice, lightning and
  stone/earth streams.
- Hands are empty; no staff, wand, book, orb, focus, weapon, tool or held object
  is baked into the base body art.
- Source format matches SCRUM-422: `512x512`, pivot `(256,470)`, visible bbox
  `[130,96,382,470]`, visible height `374 px`.
- Alpha QA: raw source was opaque/checker-backed; cleaned source and normalized
  cell are RGBA with alpha extrema `(0,255)`. Global opaque-white pixels are
  `0`, neutral-light matte pixels are `0`, and edge visible pixels are `0`.
- The `2560x1024` source handoff sheet intentionally repeats the accepted source
  in all 5 idle + 5 move placeholder cells. It is a sizing/pivot/layout handoff,
  not final motion.

Not done in this Designer 2 pass:

- No final idle/move animation frames.
- No SpriteFrames, player runtime wiring, backups of live assets, Godot
  animation smoke or runtime smoke.

Animator/Back-end follow-up:

- Derive or redraw real `idle` and `move/walk` loops from the accepted source,
  then assemble the final v2 sheet/SpriteFrames.
- Preserve the no-orb/no-staff/no-held-object rule and bottom-center pivot.
- Run manifest validation, animation smoke, runtime smoke and attach GIF/contact
  previews before replacing live paths.

## QA-Вердикт (2026-06-15)

Статус: PASSED (Design-source: elementalist v2 bright/epic + 512-cell + source-sheet handoff); Animator-фаза (idle/move) — pending

Проверено (фактически):

- **elementalist v2 source прозрачный**: `elementalist_v2_source_clean`
  (1024²), `_idle_cell_512` (512²), `_sheet_source_handoff` / `_sheet`
  (2560×1024) — все RGBA. Source/cell `opaque_white_pixels_after = 0`,
  `neutral_light_pixels_after = 0`, `edge_visible_pixels_after = 0`.
- **Визуал** `scrum427_elementalist_v2_contact.png`: яркий эпичный
  multi-element caster, fire/ice/lightning/stone streams, hands empty, без baked
  staff/orb/focus/weapon, прозрачность на тёмном ✓.
- **Source-sheet handoff**: row 0 — 5 idle placeholder, row 1 — 5 move
  placeholder. Motion drawing — Animator-owned. Handoff-док
  `elementalist_v2_design_handoff.md`.

⚠️ **Реальная idle/move анимация + SpriteFrames + runtime ещё НЕ сделаны** —
Animator/Back-end phase.

Acceptance (Design-source scope):

- [x] elementalist v2 перерисован ярко/эпично, прозрачный (нет белого/каймы/карманов).
- [x] Design-source handoff: 512-cell, pivot/report, source-sheet layout, contact preview.
- [~] idle+move анимация (loop), 2× монстра, виден/анимирован в игре — Animator follow-up (pending).
- [~] animation+runtime smoke + gif — Animator follow-up.

Статус: Design-source PASS, ждёт Animator-фазу. Баги: нет (Design-scope).

## Animator Takeover (2026-06-15)

Статус: `in_progress` — беру Animator-фазу после accepted Design-source PASS.
Scope: собрать реальные idle + move/walk v2 loop-кадры из accepted
`elementalist_v2_idle_cell_512.png`, обновить live SpriteFrames/runtime путь
`assets/sprites/characters/elementalist_spriteframes.tres`, положить старые live
ассеты в docs backup, создать manifest/contact/GIF QA artifacts, прогнать
animation smoke и runtime smoke. Attack остаётся отсутствующим по требованиям
этой v2 строки.

## Animator Result (2026-06-15)

Статус: done — Elementalist v2 live Animator integration complete.

Completed Animator-owned scope:

- Consumed accepted Design-source cell
  `docs/design/references/characters_v2/elementalist/elementalist_v2_idle_cell_512.png`
  without changing source art direction.
- Built real 5-frame full-frame `idle` loop and 5-frame `walk` / `move` loop
  from the accepted 512-cell source. Attack remains intentionally absent per
  SCRUM-427 scope.
- Updated live runtime resource
  `assets/sprites/characters/elementalist_spriteframes.tres`; it now exposes
  only `idle`, `walk`, and `move`, each looping with 5 frames.
- Wrote runtime frames under
  `assets/sprites/characters/full_frame/elementalist/elementalist_idle_00..04.png`
  and
  `assets/sprites/characters/full_frame/elementalist/elementalist_walk_00..04.png`.
- Exported safe 48px-gutter / 48px-padding QA sheet
  `assets/sprites/characters/v2/elementalist/elementalist_v2_anim_sheet.png`.
- Backed up previous live SpriteFrames/frame assets outside Godot import scope:
  `docs/design/backups/scrum427_elementalist_v2_pre_anim/`.
- Added QA artifacts under `build/qa/scrum427_elementalist_v2_anim/`:
  `animation_manifest.json`, `manifest_validator_output.txt`,
  `alpha_size_report.json`, `scrum427_elementalist_v2_anim_contact.png`,
  `elementalist_v2_idle.gif`, and `elementalist_v2_walk.gif`.

Validation:

- Alpha safety: `edge_alpha_pixels = 0`, `below_pivot_alpha_pixels = 0` for all
  generated runtime frames; pivot remains `(256,470)`.
- Godot import: PASS.
- Animation smoke:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd`
  → PASS.
- Runtime smoke:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
  → PASS.
- Bundled manifest validator was run and recorded the expected generic failure
  `elementalist: missing attack_primary animation`; this is accepted for
  SCRUM-427 because the task explicitly excludes attack animation.
