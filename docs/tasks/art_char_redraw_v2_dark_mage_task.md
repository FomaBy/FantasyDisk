# ART/ANIM: Перерисовать «Тёмный маг» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: review
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-424
QA: in_progress (2026-06-15)
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Designer 2 Takeover (2026-06-15)

Взято Designer 2 после SCRUM-439 heartbeat/board check. SCRUM-422 anchor
принят, SCRUM-420 Berserk v2 занят Design main, поэтому следующий свободный
Design-row — Dark Mage v2. Scope this pass: подготовить accepted bright+epic
Design source pack для `dark_mage` по anchor-формату (`512x512`, pivot
`(256,470)`, visible body `360-380px`, transparent RGBA, idle/move source
reference, no attack/no held weapon). Runtime SpriteFrames/player wiring and
Godot smokes остаются Animator/Back-end scope unless a safe existing project
pipeline can consume the accepted source without touching gameplay logic.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Тёмный маг** (`dark_mage`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Тёмный маг: эффектный чародей, насыщенная фиолетово-пурпурная магия, светящиеся руны; эпично, ярко. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Тёмный маг» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Тёмный маг» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Тёмный маг» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (dark_mage), current_game_state.

## Design Result (Designer 2 / 2026-06-15)

Статус: Design-source ready for review; Animator/Back-end integration pending.

Produced the Dark Mage v2 bright+epic source pack through the required
`fantasydisk-asset-generator` flow and SCRUM-422 anchor format:

- raw OpenAI source:
  `docs/design/references/characters_v2/dark_mage/dark_mage_v2_source_raw.png`;
- alpha-clean source:
  `docs/design/references/characters_v2/dark_mage/dark_mage_v2_source_clean.png`;
- normalized 512-cell source:
  `docs/design/references/characters_v2/dark_mage/dark_mage_v2_idle_cell_512.png`;
- Design-source sheet handoff:
  `docs/design/references/characters_v2/dark_mage/dark_mage_v2_sheet_source_handoff.png`;
- asset-side source copies:
  `assets/sprites/characters/v2/dark_mage/dark_mage_v2_idle_source.png` and
  `assets/sprites/characters/v2/dark_mage/dark_mage_v2_sheet_source_handoff.png`;
- contact / dark-background preview:
  `docs/design/previews/scrum424_dark_mage_v2_contact.png`;
- handoff note:
  `docs/design/references/characters_v2/dark_mage/dark_mage_v2_design_handoff.md`;
- alpha/size report:
  `build/qa/scrum424_dark_mage_v2/scrum424_dark_mage_v2_alpha_size_report.json`.

Design acceptance notes:

- Class fantasy: bright epic violet/purple void caster with glowing runes and
  dark-gold robe trim.
- Hands are empty; no staff, wand, book, orb, weapon, tool or held object.
- Source format matches SCRUM-422: `512x512`, pivot `(256,470)`, visible bbox
  `[142,94,369,470]`, visible height `376 px`.
- Alpha QA: raw source was opaque/checker-backed; cleaned source and normalized
  cell are RGBA with alpha extrema `(0,255)`, edge white pixels after cleanup
  `0`.
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
- Preserve the no-weapon/no-held-object rule and bottom-center pivot.
- Run manifest validation, animation smoke, runtime smoke and attach GIF/contact
  previews before replacing live paths.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-source: dark_mage v2 ярко/эпично + 512-cell + source-sheet handoff); Animator-фаза (idle/move) — pending

Проверено (фактически):
- **dark_mage v2 source прозрачный**: `dark_mage_v2_source_clean` (1024²), `_idle_cell_512`
  (512²), `_sheet_source_handoff` (2560×1024) — все RGBA, corner_alpha=0, прозрачные
  (raw 1024² opaque — сырьё). Alpha-report: clean_bbox, pivot (256,470).
- **Визуал** `scrum424_dark_mage_v2_contact.png`: яркий эпичный маг — насыщенный
  фиолетовый/violet магический огонь и энергия, орнаментальные тёмно-золотые робы,
  свечение (консистентно с анкором SCRUM-422, ярче 0.1.5 dark), руки пустые (магия,
  без оружия), прозрачность на тёмном ✓.
- **Source-sheet handoff**: row 0 — 5 idle placeholder, row 1 — 5 move placeholder
  (motion drawing — Animator-owned). Handoff-док `dark_mage_v2_design_handoff.md`.

⚠️ **Реальная idle/move анимация + SpriteFrames + runtime ещё НЕ сделаны** — Animator-фаза
(placeholder-слоты заменить нарисованными кадрами, собрать/подключить, gif, animation_smoke).
НЕ промоутил в Готово.

Acceptance (Design-source scope):
- [x] dark_mage v2 перерисован ярко/эпично, прозрачный (нет белого/каймы/карманов).
- [x] Design-source handoff: 512-cell, pivot/report, source-sheet layout, contact preview.
- [~] idle+move анимация (loop), 2× монстра, виден/анимирован в игре — Animator follow-up (pending).
- [~] animation+runtime smoke + gif — Animator follow-up.

Статус: Design-source PASS, ждёт Animator-фазу. Баги: нет (Design-scope).
