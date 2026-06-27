# ART: Берсерк — новый спрайт (прозрачный фон, чуть мультяшнее, без анимаций)

Статус: done
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-442
QA: in_progress (2026-06-15)
Связано: SCRUM-324 (asset-skill)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Designer 2 Takeover (2026-06-15)

Взято Designer 2 после heartbeat/board check как следующий свободный
Design-row. Scope этого pass: один новый Berserk v3 sprite/candidate на
прозрачном фоне, чуть более мультяшный и пригодный для будущего horizontal flip.
Анимации, SpriteFrames, runtime wiring и gameplay scale не выполняются.

## Контекст (запрос пользователя)
«Перерабатываем 1 класс — Берсерк. Сначала нарисовать его спрайт на ПРОЗРАЧНОМ
фоне (чтобы не было проблем с вырезанием в будущем). Сейчас рисует слишком
реалистично — сделать чуть более мультяшно. Просто спрайт БЕЗ анимаций. Учитывать,
что будут анимации движения вправо/влево (спрайт будет зеркалиться) и ноги чтобы
стояли НЕ на одном уровне».

Это первый шаг перехода на «по одному классу». Широкий редизайн v2 отменён.

## ОБЯЗАТЕЛЬНО — скилл
Рисовать скиллом `fantasydisk-asset-generator`
(`scripts/generate_asset.py --prompt "<...>" --output characters_v3/berserk
--size 1024x1024 --quality high`, gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон**
`background=transparent`). Проверить прозрачность (`tools/strip_white_background.py`),
чтобы НЕ было белого фона/каймы/карманов между рук/ног.

## Требования
1. **Только спрайт Берсерка, БЕЗ анимаций** (один кадр-модель). Свирепый варвар,
   мускулистый, меховые элементы, боевой раскрас, БЕЗ оружия в руках.
2. **Чуть более мультяшный** стиль (не фотореализм): читаемые формы, выразительный
   силуэт, чистые цвета — но в каноне игры. Меньше реалистичной детализации.
3. **ПРОЗРАЧНЫЙ фон гарантированно чистый** (главная цель шага) — без белого фона,
   без белой каймы по контуру, без замкнутых карманов; края чёткие, готовые к
   вырезанию/анимации.
4. **Подготовка к движению вправо/влево (зеркалирование)**: ракурс такой, чтобы
   горизонтальный flip выглядел естественно (3/4 или вид сбоку без асимметричных
   деталей, которые сломаются при отражении; либо отметить асимметрию). Поза
   нейтрально-боевая, лицом по направлению движения.
5. **Ноги НЕ на одном уровне**: поза с разведёнными/смещёнными ногами (мид-стэнс/
   мид-шаг), чтобы база читалась как готовая к ходьбе, а не «по стойке смирно».
6. Положить исходник в docs/design/references/characters_v3/berserk/ и игровой PNG
   в assets/sprites/characters/ (по согласованию пути; старый berserk — в бэкап).
   Анимации НЕ делать на этом шаге — отдельной задачей позже.
7. Превью на тёмном фоне арены в build/qa/ (показать, что прозрачно и читаемо).
8. CHANGELOG; content_registry (berserk).

## Acceptance Criteria
- [ ] Спрайт Берсерка нарисован скиллом, чуть мультяшнее, без оружия; БЕЗ анимаций (один кадр).
- [ ] Фон полностью прозрачный (нет белого/каймы/карманов); края готовы к вырезанию.
- [ ] Ракурс пригоден для flip влево/вправо; ноги не на одном уровне (мид-стэнс).
- [ ] Превью на тёмном фоне; старый berserk в бэкап; CHANGELOG.

## Документация
docs/design/content_registry.md (berserk), current_game_state.

## Design Result (Designer 2 / 2026-06-15)

Готов один новый Berserk v3 sprite/candidate без анимаций и runtime wiring.
Спрайт сгенерирован через `fantasydisk-asset-generator`, затем вручную
нормализован в чистый RGBA: удалён baked checker/white matte, вычищены белые,
нейтрально-светлые и pale low-saturation пиксели, а также disconnected fringe
после contact/dark-bg проверки.

Артефакты:
- transparent source: `docs/design/references/characters_v3/berserk/berserk_v3_source.png`
- transparent generator-source filename, corrected from opaque RGB to RGBA:
  `docs/design/references/characters_v3/berserk/berserk_v3_source_raw.png`
- clean source: `docs/design/references/characters_v3/berserk/berserk_v3_source_clean.png`
- normalized 512 sprite: `docs/design/references/characters_v3/berserk/berserk_v3_sprite_512.png`
- game candidate: `assets/sprites/characters/berserk_v3_sprite.png`
- old live sprite backup: `docs/design/backups/scrum442_berserk_v3_pre_sprite/berserk_unarmed_pre_scrum442.png`
- previews: `docs/design/previews/scrum442_berserk_v3_contact.png`,
  `docs/design/previews/scrum442_berserk_v3_dark_bg.png`
- QA report: `build/qa/scrum442_berserk_v3/scrum442_berserk_v3_alpha_pose_report.json`

Validation summary:
- `assets/sprites/characters/berserk_v3_sprite.png`: `512x512`, visible bbox
  `[102, 51, 409, 485]`, visible pixels `68375`, full-image alpha range
  includes transparent `0` and opaque `255`.
- `docs/design/references/characters_v3/berserk/berserk_v3_source_raw.png`,
  `berserk_v3_source.png` and `berserk_v3_source_clean.png` are all transparent
  RGBA `1024x1024`, full-image alpha range `0..255`, transparent pixels
  `808752`, visible bbox `[214, 73, 800, 905]`.
- `opaque_white_pixels_after = 0`, `neutral_light_pixels_after = 0`,
  `pale_low_saturation_pixels_after = 0`, `edge_visible_pixels_after = 0`.
- Additional strict pass recolored the remaining light matte-like pixels:
  `605` in clean source and `2` in the normalized/game candidate.
- Correction after review: the original generator output stored as
  `berserk_v3_source_raw.png` was RGB/opaque and looked like a non-transparent
  source; it has been replaced with the transparent RGBA clean source so no
  handoff/source-looking PNG remains opaque.
- Pose is unarmed, slightly cartoonish, 3/4-right and suitable for future
  horizontal flip; feet are offset and not on one horizontal line.
- Scope intentionally excludes animations, SpriteFrames, combat scale and
  runtime class wiring.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-source: один новый Berserk v3 спрайт, прозрачный, мультяшнее, без анимаций)

Проверено (фактически, на артефактах):
- **Чистая прозрачность** `assets/sprites/characters/berserk_v3_sprite.png`: `512×512`,
  **edge_alpha_max=0** (нет белой каймы/бордюра по контуру), opaque=63143 + transparent=193769
  (есть и `0`, и `255`). Отчёт: `opaque_white=0`, `neutral_light=0`, `pale_low_sat=0`,
  `edge_visible=0` — нет белого фона/каймы/карманов. Края готовы к вырезанию/анимации ✓.
- **Поза** (отчёт `pose` + превью `scrum442_berserk_v3_dark_bg.png`): **unarmed=True**
  (свирепый варвар, кулаки, БЕЗ оружия), **feet_offset=True** (ноги разведены, мид-стэнс,
  НЕ на одном уровне), **orientation «3/4 right, suitable for future horizontal flip»**
  (ракурс пригоден для зеркалирования) ✓.
- **Стиль**: чуть мультяшнее (читаемый силуэт, чистые формы), в каноне игры; прозрачность
  читается на тёмном фоне арены ✓.
- **Бэкап старого** `docs/design/backups/scrum442_berserk_v3_pre_sprite/berserk_unarmed_pre_scrum442.png`
  присутствует; превью contact+dark_bg; CHANGELOG + content_registry упоминают v3 ✓.

Acceptance (Design-source scope):
- [x] Спрайт нарисован скиллом, чуть мультяшнее, без оружия; БЕЗ анимаций (один кадр).
- [x] Фон полностью прозрачный (нет белого/каймы/карманов); края готовы к вырезанию.
- [x] Ракурс пригоден для flip; ноги не на одном уровне (мид-стэнс).
- [x] Превью на тёмном фоне; старый berserk в бэкап; CHANGELOG.

Статус done. Баги: нет. Первый шаг «по одному классу» (после отмены широкого v2).
⚠️ Scope намеренно БЕЗ анимаций/SpriteFrames/runtime-wiring/gameplay-scale — это отдельный
следующий шаг (Animator/Back-end). runtime_smoke не относится к этой art-задаче (442 не менял
.gd/тесты); текущий общий red — известный тест-изоляционный артефакт death-flow (SCRUM-443/444),
не регрессия от 442.
