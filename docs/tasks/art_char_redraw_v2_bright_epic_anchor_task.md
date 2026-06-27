# ART/ТЕХ: Перерисовка персонажей v2 — ЯРКО и ЭПИЧНО, move+idle, 2× монстра — ОПОРНАЯ

Статус: done
Приоритет: high
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-422
QA: in_progress (2026-06-15)

## Dispatcher Dispatch (2026-06-15)

Sent to Design main thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` as the first
0.1.6 character-redraw anchor. Keep reasoning High/no low. Scope starts with
Design/source work only: create the bright+epic class style-sheet, transparent
source art/spec, size/pivot format, and one accepted exemplar/handoff. Do not
route Animator work until Design source assets and handoff are accepted.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Перерисовать ВСЕХ персонажей. Все должны быть ЯРКИЕ и ЭПИЧНЫЕ в соответствии с
их классом (можно не так мрачно, как игра в целом). Обязательно модельку на
ПРОЗРАЧНОМ фоне. Потом — анимация ДВИЖЕНИЯ и ПРОСТОЯ (анимация атаки НЕ нужна).
Движение — плавное и логичное. Размер персонажей — в 2 раза больше среднего
размера монстра».

Это ОПОРНАЯ задача инициативы «Перерисовка персонажей v2» (0.1.6). Задаёт единый
яркий-эпичный стиль, формат, размер и тех.требования ПЕРЕД 16 пер-персонажными
задачами (каждая блокируется этой). 16 классов: berserk, dark_mage, guitarist,
assassin, thief, elementalist, sniper, priest, biologist, robot, engineer, doctor,
chemist, knight, druid, soldier.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования — стиль и формат
1. **Яркий, эпичный стиль по классу**: каждый герой выразительный, насыщенные
   класс-уместные цвета и свечение, героическая поза — НЕ грим-дарк (светлее, чем
   общий тон игры), но в каноне фэнтези. Зафиксировать style-sheet в
   docs/design/references/ + menus_ui/visual_style_assets.
2. **ПРОЗРАЧНЫЙ фон обязателен**: RGBA, без белого фона/каймы/замкнутых карманов
   (между рук/ног). Проверять `tools/strip_white_background.py` + визуально на тёмном.
3. **Единый формат листа**: ячейка (напр. 512×512 — крупнее, т.к. персонаж большой),
   pivot «ступни по центру низа». Только **idle** и **move/walk** ряды (attack НЕ
   делать). Зафиксировать спеку (размер ячейки/кадры/fps/пути).

## Требования — размер (2× монстра)
4. **Размер персонажа на экране = 2× средний размер монстра.** Обычные монстры —
   спрайты 192×192. Замерить среднюю экранную высоту монстра (sprite×scale) и
   подобрать масштаб персонажа (PLAYER_COMBAT_VISUAL_SCALE / размер ячейки) так,
   чтобы герой был ВДВОЕ крупнее. Согласовать коллайдер/прицел, не ломая баланс.

## Требования — анимация
5. **move/walk** (loop, 5+ кадров) — плавный, ЛОГИЧНЫЙ цикл (контакт-проход-подъём-
   возврат для ногастых; левитация для парящих), без проскальзывания/рывков.
6. **idle** (loop, 2-5 кадров) — лёгкое дыхание/покачивание.
7. **attack НЕ создавать** (USE_ATTACK_ANIMATION уже false — attack-кадры не нужны).
8. Эталон: один класс (напр. berserk) полностью довести как образец для 16 задач;
   система проигрывания move/idle уже есть (player.gd), full-frame видим (SCRUM-411).

## Тест/верификация
- animation_smoke + runtime_smoke зелёные; на экране герой ЯРКИЙ, прозрачный (нет
  белого), вдвое крупнее монстра, move/idle плавные. Превью-гиф/контакт в build/qa/.
- CHANGELOG; systems/animation.md + visual_style_assets; content_registry.

## Acceptance Criteria
- [x] Style-sheet «ярко+эпично по классу» + формат (idle/move, ячейка, pivot, пути) + правило размера 2× монстра зафиксированы.
- [x] Прозрачность гарантирована (нет белого фона/каймы/карманов); эталон-класс доведён как Design source exemplar.
- [ ] animation+runtime smoke зелёные; runtime smoke отложен до Animator/Back-end integration, потому что SCRUM-422 выполнен как Design-source anchor без SpriteFrames/runtime wiring.

## Документация
docs/design/systems/visual_style_assets.md, animation.md, content_registry, current_game_state.

## Результат Design Source Anchor (2026-06-15)

Статус: `review` — Design/source anchor готов для PM/Animator review. Runtime
SpriteFrames/AnimationPlayer/AnimationTree и gameplay integration не выполнялись,
так как это Animator/Back-end scope после принятия source assets.

Принятый exemplar:
- raw generated source:
  `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_source_raw.png`;
- alpha-clean Design source:
  `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_source_clean.png`;
- normalized 512-cell exemplar:
  `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_idle_cell_512.png`;
- asset-side accepted source copy:
  `assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png`;
- dark-background/contact preview:
  `docs/design/references/characters_v2/bright_epic_anchor/character_v2_anchor_dark_bg_preview.png`;
- canonical v2 style/spec:
  `docs/design/references/characters_v2/bright_epic_anchor/character_v2_bright_epic_style_sheet.md`;
- pixel QA report:
  `build/qa/scrum422_character_v2_anchor/scrum422_character_v2_anchor_alpha_report.json`.

Style/spec contract for the 16 per-class v2 rows:
- bright, epic, class-readable D&D fantasy direction; more colorful/readable than
  the 0.1.5 full-frame sheets while staying compatible with FantasyDisk;
- transparent RGBA only, no baked background, no edge-connected white/checker
  matte, no white halo;
- base hero source must remain unarmed/no held weapon/focus/orb in hands unless
  a class task explicitly defines a non-combat prop that Animator/Back-end can
  safely ignore;
- source cell `512x512`, pivot guide `(256, 470)`, target visible body height
  `360-380 px`;
- animation handoff rows: `idle` 4-5 frame loop at about `5 fps`; `move`/`walk`
  5+ frame loop at about `10 fps`; attack rows are intentionally out of scope
  for this v2 initiative;
- runtime visual-scale target for later Back-end/Animator review:
  `0.39-0.40`, which maps the `360-380 px` source body to about `140-152 px` on
  screen, roughly 2x the measured average standard monster screen height.

Verification:
- Generated through `fantasydisk-asset-generator` (`gpt-image-2`, `1024x1024`,
  high quality), then alpha-cleaned through the approved local edge flood-fill /
  de-halo pipeline used by SCRUM-412.
- QA report confirms raw source was opaque, cleaned source is RGBA with
  `clean_alpha_extrema: [0, 255]`, `clean_edge_white_pixels_after: 0`, and
  `clean_floodable_background_after: 0`.
- Normalized exemplar has visible bbox `[118, 94, 394, 470]` in `512x512`,
  visible height `376 px`, matching the 2x-monster source-size target.

Docs updated:
- `docs/design/references/characters_v2/bright_epic_anchor/character_v2_bright_epic_style_sheet.md`;
- `docs/design/systems/visual_style_assets.md`;
- `docs/design/systems/animation.md`;
- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `CHANGELOG.md`;
- `docs/process/task_board.md`.

Not run:
- Godot runtime/animation smoke tests were not run in this Design-source pass:
  no SpriteFrames, runtime player scale, collision, animation tree, or gameplay
  code was changed.

Handoff:
- Animator may use this anchor to build idle/move source sheets, contact sheets,
  GIF previews and SpriteFrames for the per-class v2 rows after PM accepts this
  visual direction.
- Back-end should only review runtime scale/target rects after accepted v2 sheets
  exist; no Back-end change is required for this anchor itself.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-source anchor: яркий-эпичный v2 style-sheet + спека + эталон)

Проверено (фактически):
- **Эталон berserk_v2**: source_clean (1024²), idle_cell_512 (512²), asset-side
  idle_source (512²) — все RGBA, corner_alpha=0, opaque+transp (прозрачный фон, без
  белого/каймы). Alpha-report: clean_bbox/visible-height, cell 512, pivot [256,470].
- **Визуал** `character_v2_anchor_dark_bg_preview.png`: огненный эпичный варвар —
  ярко-оранж/красное пламя, светящиеся эффекты, насыщенные класс-цвета (заметно ярче
  0.1.5 dark full-frame), руки пустые (без оружия), прозрачность на тёмном фоне ✓.
- **Спека/контракт** `character_v2_bright_epic_style_sheet.md`: 512-ячейка, pivot
  [256,470], visible body 360-380px, idle 4-5f @5fps + move 5+f @10fps (attack вне
  scope), runtime visual-scale 0.39-0.40 (≈2× средней высоты монстра). Зафиксировано
  в visual_style_assets/animation.md.

Acceptance (Design-source scope):
- [x] Style-sheet «ярко+эпично по классу» + формат (idle/move, ячейка, pivot, пути) + правило 2× монстра.
- [x] Прозрачность гарантирована (нет белого/каймы/карманов); эталон-класс доведён как source exemplar.
- [~] animation+runtime smoke — отложены до Animator/Back-end integration (SCRUM-422 = Design-source anchor без SpriteFrames/runtime).

Статус review→done (Design-source). Баги: нет. Опорная для 16 пер-классовых v2-задач (0.1.6).
⚠️ Это 0.1.6-инициатива (после фриза 0.1.5): v2-перерисовка ярче/эпичнее, заменит 0.1.5
full-frame; runtime/анимация — следующим этапом (Animator после приёмки PM).
