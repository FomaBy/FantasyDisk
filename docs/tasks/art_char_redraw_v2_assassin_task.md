# ART/ANIM: Перерисовать «Ассасин» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: done
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-419
QA: pending (Animator done 2026-06-15)
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatcher Design Dispatch (2026-06-15)

Передано Design main (`019eabf1-6d54-7561-8af9-ce25cdf483a9`) как свободная
per-class v2 Design-source строка после SCRUM-422 source anchor. Designer 2
сейчас активен на SCRUM-429 Guitarist, Animator получает SCRUM-424 Dark Mage, так
что этот ряд не конфликтует с активными владельцами.

Scope for this pass: prepare the accepted bright+epic Assassin v2 Design-source
pack only: transparent source PNG, normalized `512x512` cell/source handoff,
alpha/halo/pocket validation, visible body height/pivot report, contact/dark-bg
preview and handoff notes. Use `fantasydisk-asset-generator` and the accepted
SCRUM-422 style/format anchor. Do not build SpriteFrames, AnimationPlayer,
runtime player wiring, animation smoke, combat scale/collision, or Back-end
logic in this Design pass. Animator starts only after source acceptance. Keep
reasoning High/no low.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Ассасин** (`assassin`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Ассасин: ловкий убийца в стильном тёмно-бирюзовом, острые силуэты, лёгкое свечение клинков; ярко-контрастно. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Ассасин» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Ассасин» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [x] «Ассасин» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [x] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [x] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.
- [x] Design-source handoff prepared: 512-cell source, pivot/height report, placeholder source-sheet layout, dark-bg preview.

## Документация
docs/design/content_registry.md (assassin), current_game_state.

## Design Source Result (2026-06-15)

Статус: `review` — Assassin v2 Design-source handoff готов для PM/Animator
review. Runtime-код, SpriteFrames, AnimationPlayer/AnimationTree,
scale/collision и smoke tests не выполнялись в этом pass.

Artifacts:
- Raw OpenAI source: `docs/design/references/characters_v2/assassin/assassin_v2_source_raw.png`
- Alpha-clean source: `docs/design/references/characters_v2/assassin/assassin_v2_source_clean.png`
- Normalized 512-cell source: `docs/design/references/characters_v2/assassin/assassin_v2_idle_cell_512.png`
- Design-source sheet handoff: `docs/design/references/characters_v2/assassin/assassin_v2_sheet_source_handoff.png`
- Asset-side idle source copy: `assets/sprites/characters/v2/assassin/assassin_v2_idle_source.png`
- Asset-side sheet handoff copy: `assets/sprites/characters/v2/assassin/assassin_v2_sheet_source_handoff.png`
- Handoff spec: `docs/design/references/characters_v2/assassin/assassin_v2_design_handoff.md`
- Contact/dark-bg preview: `docs/design/previews/scrum419_assassin_v2_contact.png`
- QA report: `build/qa/scrum419_assassin_v2/scrum419_assassin_v2_alpha_size_report.json`

Visual acceptance:
- Bright epic Assassin: agile hooded rogue with sharp silhouette, dark teal/cyan
  contrast, black leather/silver accents and subtle cyan shadow glow.
- No held weapon, dagger, blade, sword, chakram, claw, orb, focus or gameplay prop.
- Visible feet and grounded stance for bottom-center pivot.

Technical acceptance:
- Raw source was opaque with baked checker matte; cleaned source is true RGBA.
- QA report: `clean_alpha_extrema [0,255]`, `clean_edge_white_pixels_after 0`,
  `cell_edge_white_pixels_after 0`, `clean_floodable_neutral_after 0`,
  `cell_floodable_neutral_after 0`.
- Normalized source cell is `512x512`, pivot `[256,470]`, visible bbox
  `[144,94,368,470]`, visible height `376 px`, inside SCRUM-422 target
  `360..380 px`.
- Handoff sheet is `2560x1024`, 2 rows x 5 frames. It repeats the accepted source
  cell as pose placeholders only; final idle/move motion drawing remains
  Animator-owned.

Not done by Design scope:
- No SpriteFrames / AnimationPlayer / AnimationTree / runtime player wiring.
- No gameplay scale/collision or Back-end logic changes.
- No animation/runtime smoke; Animator/Back-end must run those after accepted
  source motion exists.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-source: assassin v2 ярко/эпично + 512-cell + source-sheet handoff); Animator-фаза (idle/move) — pending

Проверено (фактически):
- **assassin v2 source прозрачный**: `assassin_v2_source_clean` (1024²), `_idle_cell_512`
  (512²), `_sheet_source_handoff` (2560×1024) — все RGBA, corner_alpha=0, прозрачные
  (raw 1024² opaque — сырьё). Alpha/size report.
- **Визуал** `scrum419_assassin_v2_contact.png`: тёмный ассасин с cyan/teal свечением
  (энергия/клинки), капюшон, агильная поза, насыщенные акценты (консистентно с анкором
  SCRUM-422, ярче 0.1.5 dark), прозрачность на тёмном ✓.
- **Source-sheet handoff**: 5 idle placeholder + 5 move placeholder слотов (motion —
  Animator-owned).

⚠️ **Реальная idle/move анимация + SpriteFrames + runtime ещё НЕ сделаны** — Animator-фаза
(pending). НЕ промоутил в Готово.

Acceptance (Design-source scope):
- [x] assassin v2 перерисован ярко/эпично, прозрачный (нет белого/каймы/карманов).
- [x] Design-source handoff: 512-cell, pivot/report, source-sheet layout, dark-bg preview.
- [~] idle+move анимация, 2× монстра, виден/анимирован в игре — Animator follow-up (pending).

Статус: Design-source PASS, ждёт Animator-фазу. Баги: нет (Design-scope).

## Animator Takeover (2026-06-15)

Статус: `in_progress` — беру Animator-фазу после accepted Design-source PASS.
Scope: собрать реальные idle + move/walk v2 loop-кадры из accepted
`assassin_v2_idle_cell_512.png`, обновить live SpriteFrames/runtime путь
`assets/sprites/characters/assassin_spriteframes.tres`, положить старые live
ассеты в docs backup, создать manifest/contact/GIF QA artifacts, прогнать
animation smoke и runtime smoke. Attack остаётся отсутствующим по требованиям
этой v2 строки.

## Animator Result (2026-06-15)

Статус: done.

Animator-фаза SCRUM-419 завершена:

- live `assets/sprites/characters/assassin_spriteframes.tres` заменён на v2
  full-frame SpriteFrames с `idle`, `walk` и `move` по 5 loop-кадров; `move`
  использует тот же walk-loop, attack/attack_primary намеренно отсутствуют;
- runtime PNG кадры обновлены в
  `assets/sprites/characters/full_frame/assassin/assassin_{idle,walk}_00..04.png`;
- derived safe source sheet сохранён как
  `assets/sprites/characters/v2/assassin/assassin_v2_anim_sheet.png`
  (`512x512` cells, 48px gutter/outer padding, pivot `[256,470]`);
- старые live SpriteFrames/runtime PNG сохранены вне Godot import scope:
  `docs/design/backups/scrum419_assassin_v2_pre_anim/` без `.import` sidecars;
- QA artifacts:
  `build/qa/scrum419_assassin_v2_anim/animation_manifest.json`,
  `manifest_validator_output.txt`,
  `alpha_size_report.json`,
  `scrum419_assassin_v2_anim_contact.png`,
  `assassin_v2_idle.gif`,
  `assassin_v2_walk.gif`.

Validation:

- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/scrum419_assassin_v2_anim/animation_manifest.json`
  records expected `missing attack_primary animation`, because this task
  explicitly excludes attack.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd`
  PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
  PASS.
