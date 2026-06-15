# ART/ANIM: Перерисовать «Берсерк» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: review
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-420
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Берсерк** (`berserk`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Берсерк: свирепый бесстрашный воин-варвар, мощный, боевой раскрас, меховые элементы; ЯРКИЙ героический, не мрачный. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Берсерк» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Берсерк» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [x] «Берсерк» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.
- [x] Design-source handoff prepared: 512-cell source, pivot/height report, placeholder source-sheet layout, dark-bg preview.

## Документация
docs/design/content_registry.md (berserk), current_game_state.

## Dispatcher Design Dispatch (2026-06-15)

Передано Design main (`019eabf1-6d54-7561-8af9-ce25cdf483a9`) как первая
per-class v2 строка после принятого SCRUM-422 bright+epic source anchor.

Scope for this pass: Design/source work only. Use `fantasydisk-asset-generator`
and the SCRUM-422 style/spec to produce accepted Berserk v2 transparent source
art/source-sheet handoff, alpha/size/pivot QA, previews and documentation. Do not
perform Animator-owned SpriteFrames/AnimationPlayer/AnimationTree/runtime wiring,
animation smoke, or Back-end scale/collision changes in this Design pass. Animator
starts only after the Berserk source handoff is accepted. Keep reasoning High/no low.

## Design Source Result (2026-06-15)

Статус: `review` — Berserk v2 Design-source handoff готов для PM/Animator review.
Runtime-код, SpriteFrames, AnimationPlayer/AnimationTree, scale/collision и smoke
tests не выполнялись в этом pass.

Artifacts:
- Raw OpenAI source: `docs/design/references/characters_v2/berserk/berserk_v2_source_raw.png`
- Alpha-clean source: `docs/design/references/characters_v2/berserk/berserk_v2_source_clean.png`
- Normalized 512-cell source: `docs/design/references/characters_v2/berserk/berserk_v2_idle_cell_512.png`
- Design-source sheet handoff: `docs/design/references/characters_v2/berserk/berserk_v2_sheet_source_handoff.png`
- Asset-side idle source copy: `assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png`
- Asset-side sheet handoff copy: `assets/sprites/characters/v2/berserk/berserk_v2_sheet_source_handoff.png`
- Handoff spec: `docs/design/references/characters_v2/berserk/berserk_v2_design_handoff.md`
- Contact/dark-bg preview: `docs/design/previews/scrum420_berserk_v2_contact.png`
- QA report: `build/qa/scrum420_berserk_v2/scrum420_berserk_v2_alpha_size_report.json`

Visual acceptance:
- Bright epic Berserk: fierce unarmed barbarian/warrior with battle paint, fur
  elements, leather wraps, crimson/gold/orange rage aura and empty glowing fists.
- No held weapon, shield, tool, orb, focus or gameplay prop.
- Visible feet and grounded stance for bottom-center pivot.

Technical acceptance:
- Raw source was opaque with baked checker matte; cleaned source is true RGBA.
- QA report: `clean_alpha_extrema [0,255]`, `clean_edge_white_pixels_after 0`,
  `cell_edge_white_pixels_after 0`, `clean_floodable_neutral_after 0`,
  `cell_floodable_neutral_after 0`.
- Normalized source cell is `512x512`, pivot `[256,470]`, visible bbox
  `[136,94,375,470]`, visible height `376 px`, inside SCRUM-422 target
  `360..380 px`.
- Handoff sheet is `2560x1024`, 2 rows x 5 frames. It repeats the accepted source
  cell as pose placeholders only; final idle/move motion drawing remains
  Animator-owned.

Not done by Design scope:
- No SpriteFrames / AnimationPlayer / AnimationTree / runtime player wiring.
- No gameplay scale/collision or Back-end logic changes.
- No animation/runtime smoke; Animator/Back-end must run those after accepted
  source motion exists.
