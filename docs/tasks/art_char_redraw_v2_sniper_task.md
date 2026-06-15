# ART/ANIM: Перерисовать «Снайпер» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: cancelled
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-433
QA: in_progress (2026-06-15)
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

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

## ОТМЕНЕНО 2026-06-15 (пользователь)
Широкий редизайн персонажей v2 отменён — пользователю не нравится подход. Работаем по одному классу заново (старт — Берсерк, отдельная задача).
