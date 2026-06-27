# SCRUM-531: Berserk visual redesign — новый animation-ready source sprite pack

Jira: SCRUM-531 · Роль: Design (Codex) · Контур: design-main · Приоритет: P1 · foma · Эпик: Character art / Berserk visual identity
Статус: К выполнению (To Do)

> Метки Jira: `animation-source, berserk, character-art, codex, design, design-main, fantasydisk, foma, p1`

## Что и зачем

Пользователь хочет **более сильный, новый облик Берсерка** и просит сперва изучить
PixelLab-подобный пайплайн анимации персонажей. Предпочитаемый визуал — **НЕ pixel
art**: dark fantasy / D&D / «драконья» эстетика, брутально и читаемо на игровом
масштабе. Pixel-стиль допустим **только как fallback**, если непиксельный источник
не получается чисто заанимировать.

Цель этой задачи — собрать **animation-ready Berserker v2 source pack** (исходники +
референсы + handoff-спека), **а НЕ рантайм-интеграцию**. По PixelLab-подобному
процессу: сначала стабильный source-персонаж/референс с чётким силуэтом и пивотами,
заметки по позам/направлению, затем **передача Animator'у** на скелет/text/action-frame
анимацию. Прозрачный фон обязателен; без шумной переусложнённой детализации, которая
«не читается» на боевом масштабе.

Почему важно: Берсерк — стартовый/якорный класс игры (`character_id := "berserk"` по
умолчанию в `scripts/player.gd:117`), и его визуал задаёт планку для всего ростера.
Это **уже 4-я итерация** облика Берсерка — предыдущие приняты, но пользователь хочет
новое сильное направление, отличное от текущего cartoon-anchor.

Ожидаемый результат: принятый Design-source пакет (source/cell/sheet-handoff +
handoff.md + dark-bg превью + alpha/pivot QA-отчёт), по которому Animator в отдельном
тикете сделает idle/move анимацию без переделки арт-направления.

### История (заземление, НЕ повторять — это уже сделано в других тикетах)

- **SCRUM-420** `art_char_redraw_v2_berserk_task.md` — v2 «ярко/эпично», огненный
  варвар. Source: `docs/design/references/characters_v2/berserk/`. Статус `done`.
- **SCRUM-442** `design_berserk_sprite_v3_cartoonish_transparent_task.md` — v3 «чуть
  мультяшнее», один кадр без анимаций. Source: `docs/design/references/characters_v3/berserk/`,
  игровой кандидат `assets/sprites/characters/berserk_v3_sprite.png`. Статус `done`.
- **SCRUM-456 / SCRUM-461** cartoon/anime anchor — **текущий живой облик**. Source:
  `docs/design/references/chars_cartoon/berserk_cartoon_anchor_*`. Рантайм: 10 кадров
  `assets/sprites/characters/full_frame/berserk/berserk_{idle,walk}_0X.png` +
  `assets/sprites/characters/berserk_spriteframes.tres`. Статус `done`.

SCRUM-531 — **новое направление поверх этого**: dark fantasy / D&D / dragon, брутально,
непиксельно. Новый облик должен быть визуально **отличим от текущего cartoon-anchor**.

## Текущее состояние в коде

Это **Design/source** задача — рантайм-код менять НЕЛЬЗЯ, но вот как Берсерк
устроен сейчас (чтобы source-контракт точно лёг в существующий пайплайн):

- **Дефолтный класс**: `scripts/player.gd:117` — `var character_id := "berserk"`.
  Конфиг класса: `scripts/player.gd:80` (`CHARACTER_CONFIGS["berserk"]`,
  `display_name "Берсерк"`, `max_health 88.0`, `speed 235.0`).
- **Загрузка спрайтов (рантайм, НЕ трогать)**:
  - `scripts/player.gd:1795 _character_sprite_frames()` → сначала пытается
    `_character_full_frame_sprite_frames(character_id)`.
  - `scripts/player.gd:1804 _character_full_frame_sprite_frames()` → приоритет у
    `_character_resource_sprite_frames()`, иначе sheet.
  - `scripts/player.gd:1811 _character_resource_sprite_frames()` → грузит
    `res://assets/sprites/characters/%s_spriteframes.tres`. Для берсерка это
    **`assets/sprites/characters/berserk_spriteframes.tres`** — и он существует, значит
    Берсерк сейчас рендерится из ресурс-SpriteFrames, НЕ из `_sheet.png`.
  - `scripts/player.gd:1818 _character_sheet_sprite_frames()` — fallback на
    `<class>_sheet.png` (берсерк-шита нет, путь не используется).
  - `scripts/player.gd:31-33` — `BERSERK_ANIMATION_FRAME_SIZE/CHARACTER_SHEET_FRAME_SIZE
    = Vector2i(384, 384)`, `CHARACTER_SHEET_COLUMNS = 5` (формат старого style-sheet,
    cartoon-anchor использует 512-cell).
- **Текущий живой SpriteFrames**: `assets/sprites/characters/berserk_spriteframes.tres`
  — анимации `idle` (5 кадров, loop, 7 fps), `move`/`walk` (5 кадров, loop, 9 fps),
  ссылается на `full_frame/berserk/berserk_idle_00..04.png` и `berserk_walk_00..04.png`
  (512×512, pivot (256,470)). **Строки `attack`/`attack_primary` нет** (атака отключена:
  `scripts/player.gd:37 USE_ATTACK_ANIMATION := false`).
- **Source-контракт (из принятых SCRUM-456/461 и style-sheet)** — новый source ДОЛЖЕН
  ему соответствовать, чтобы Animator переиспользовал пайплайн без сюрпризов:
  - cell `512x512`, pivot `(256, 470)`, transparent RGBA;
  - видимая высота персонажа ~`360..432 px` внутри cell (cartoon-anchor 432px, v2 376px);
  - руки **пустые** — НЕ запекать оружие/щит/инструмент (оружие — отдельные ассеты);
  - ноги разведены (мид-стэнс, НЕ «по стойке смирно»), ракурс пригоден для
    горизонтального flip (3/4-right);
  - без белого фона / белой каймы по контуру / замкнутых «карманов» между рук-ног;
  - sheet-handoff: gutters/outer padding `48 px`, ряды row0 `idle` / row1 `walk`,
    по `5` кадров; attack-ряд НЕ включать.
- **Style-канон**: `docs/design/references/character_animation_style_sheet_0_1_5.md` —
  «polished painterly D&D dark fantasy hero», читаемый силуэт, чистый контур, без
  noisy texture mush. Identity Берсерка: `broad shoulders, forward aggression, empty
  clenched hands, fur/leather/red cloth`.
- **Целевые директории задачи НЕ существуют** (их создаёт исполнитель):
  `docs/design/references/berserk_v2/` — НЕТ; `assets/sprites/characters/berserk_v2/` — НЕТ.
  (Внимание на коллизию имён: уже есть `docs/design/references/characters_v2/berserk/`
  от SCRUM-420 — это ДРУГАЯ папка; новый путь именно `references/berserk_v2/`.)

## Что сделать — по шагам

1. **Изучить PixelLab-пайплайн** (по ссылкам из тикета) перед рисованием и кратко
   зафиксировать в handoff.md, какие принципы взяты:
   - https://www.pixellab.ai/
   - https://www.pixellab.ai/docs/tools/animate-with-skeleton
   Суть для нас: стабильный source-персонаж → чистый силуэт + пивоты/joints →
   pose/direction-заметки → skeleton/action-frame анимация. Мы делаем **первый этап**
   (source), Animator — второй (skeleton/animate).

2. **Сгенерировать новый source Берсерка** скиллом `fantasydisk-asset-generator`
   (OpenAI Images `gpt-image-2`, PNG). Команда-шаблон (см. SKILL.md
   `skills/codex/fantasydisk-asset-generator/SKILL.md`):
   ```bash
   python3 ~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py \
     --prompt "<dark-fantasy D&D dragon berserker prompt>" \
     --output "berserk_v2/berserk_v2_source_raw.png" \
     --size 1024x1024 --quality high
   ```
   - Если нужен offline/без Jira-sync: префикс `FANTASYDISK_SKIP_JIRA_SYNC=1`.
   - Если в env есть локальный `tools/artgen/generate_asset.py` — скилл предпочитает его.
   - Арт-направление: **dark fantasy / D&D / dragon-themed брутальный варвар** — массивные
     плечи, агрессивная передняя стойка, пустые сжатые кулаки, мех/кожа/кость, акценты
     «драконьей» темы (например: чешуя/драконий череп-наплечник/рога/драконья кость/тёмно-багровый),
     читаемый героический силуэт. НЕ pixel art. **Визуально отличаться** от текущего
     cartoon-anchor (другой материал/палитра/настроение — мрачнее и брутальнее, не cel-shaded мультяшный).
   - `gpt-image-2` НЕ даёт прозрачность напрямую → постпроцесс альфы обязателен.

3. **Постпроцесс / чистка альфы** до чистого RGBA:
   - снять запечённый checker/белый matte;
   - вычистить белые / нейтрально-светлые / pale-low-saturation пиксели по краю;
   - проверить отсутствие белой каймы по контуру и замкнутых «карманов»;
   - инструмент-помощник: `tools/strip_white_background.py` (если присутствует в репо;
     если нет — чистить вручную/скриптом и зафиксировать в QA-отчёте extrema альфы).
   - Сохранить: `berserk_v2_source_raw.png` (исходник), `berserk_v2_source_clean.png`
     (чистый RGBA), нормализованный `berserk_v2_idle_cell_512.png` (`512x512`, pivot
     `(256,470)`).

4. **Собрать source-sheet handoff** (placeholder-раскладка поз, НЕ финальная анимация):
   `berserk_v2_sheet_source_handoff.png` — ряды row0 `idle` / row1 `walk`, по 5 ячеек
   `512x512`, gutters/outer padding `48 px`. Кадры могут повторять принятый source-cell
   как pose-плейсхолдеры (реальное motion-рисование — за Animator).

5. **Сложить файлы по путям из acceptance тикета**:
   - source/референсы → `docs/design/references/berserk_v2/`;
   - финальные кандидат-экспорты → `assets/sprites/characters/berserk_v2/` (или ближайший
     существующий character-path; рекомендую именно `berserk_v2/`, т.к. так требует тикет
     и это изолированная новая папка);
   - dark-bg / contact превью → `docs/design/previews/` (имя с префиксом `scrum531_`);
   - QA-отчёт (alpha/size/pivot) → `build/qa/scrum531_berserk_v2/`.

6. **Написать handoff.md для Animator** (по образцу
   `docs/design/references/chars_cartoon/berserk_cartoon_anchor_design_handoff.md`):
   `docs/design/references/berserk_v2/berserk_v2_design_handoff.md`. Содержимое:
   - таблица «Purpose → Path» со ВСЕМИ артефактами (raw/clean/cell/sheet/previews/QA);
   - Visual Direction (что нарисовано, чем отличается от текущего, dragon/dark-fantasy);
   - Source Format (cell `512x512`, pivot `(256,470)`, visible bbox/height, sheet-size,
     gutters `48px`, ряды idle/walk×5, attack НЕ включён, suggested fps: idle 7 / walk 9);
   - **direction-facing choice** (3/4-right, пригоден для flip), **pivot notes**,
     **palette/silhouette notes**;
   - Animator Boundary: что делает Animator дальше (idle/move keyframes, SpriteFrames,
     GIF/contact, manifest-валидация, Godot smoke — НЕ в этом тикете);
   - явная пометка: **pixel fallback** не использован (или, если использован — почему
     непиксельный источник не анимировался чисто, со ссылкой на проверку).

7. **Зеркальный mirror-таск (опционально, по suggested scope тикета)**:
   `docs/tasks/design_berserk_v2_visual_redesign_task.md` — короткая копия для борда
   (можно сослаться на этот SCRUM-файл).

8. **Документация / синк**: упомянуть berserk_v2 source в `docs/design/content_registry.md`
   (если ведётся для подобных), обновить `CHANGELOG.md` строкой Design-source, прогнать
   `python3 tools/jira_board_sync.py` после смены статуса и синхронизировать Jira/борд
   (по mandate live-sync).

## Acceptance Criteria

Из тикета:
- [ ] Новый облик Берсерка **визуально отличим** от текущего и **читаем на игровом
      масштабе**.
- [ ] Предпочитаемый source — **непиксельный** painterly/hand-drawn; pixel-fallback
      задокументирован **только** если этого требует анимационная пригодность.
- [ ] Source/референс-файлы лежат под `docs/design/references/berserk_v2/`, а финальные
      кандидат-экспорты — под `assets/sprites/characters/berserk_v2/` (или ближайший
      существующий character sprite path).
- [ ] Handoff включает: idle/move/attack-ready pose-референсы, выбор direction-facing,
      pivot-заметки, palette/silhouette-заметки и **точные пути файлов** для Animator.
- [ ] В этой Design-задаче **НЕ меняется** gameplay / balance / runtime-логика /
      реализация анимации.

Дополнено по коду (проверяемые):
- [ ] Целевые папки `docs/design/references/berserk_v2/` и
      `assets/sprites/characters/berserk_v2/` созданы и содержат артефакты.
- [ ] `*_source_clean.png` и `*_idle_cell_512.png` — **истинный RGBA** (alpha extrema
      включают `0` и `255`), edge-white по контуру = `0`, нет замкнутых neutral-карманов
      (зафиксировано в `build/qa/scrum531_berserk_v2/*_report.json`).
- [ ] Нормализованный cell — `512x512`, pivot `(256, 470)`, visible height в диапазоне
      ~`360..432 px`.
- [ ] Source-sheet handoff: cell `512x512`, gutters `48 px`, ряды idle/walk×5, attack-ряд
      отсутствует.
- [ ] Руки персонажа **пустые** — оружие/щит/инструмент НЕ запечены.
- [ ] `berserk_v2_design_handoff.md` присутствует и перечисляет все артефакты + пути.
- [ ] dark-bg превью в `docs/design/previews/scrum531_*` подтверждает прозрачность и
      читаемость на тёмной арене.
- [ ] **Рантайм НЕ тронут**: `assets/sprites/characters/berserk_spriteframes.tres`,
      `assets/sprites/characters/full_frame/berserk/*`, `scripts/player.gd` и тесты
      без изменений (git diff пуст по этим путям).

## Files / точки входа

Создаёт (НОВОЕ):
- `docs/design/references/berserk_v2/berserk_v2_source_raw.png` — сырой OpenAI-источник.
- `docs/design/references/berserk_v2/berserk_v2_source_clean.png` — чистый RGBA.
- `docs/design/references/berserk_v2/berserk_v2_idle_cell_512.png` — нормализованный
  512-cell, pivot (256,470).
- `docs/design/references/berserk_v2/berserk_v2_sheet_source_handoff.png` — placeholder
  source-sheet (idle/walk × 5, gutters 48px).
- `docs/design/references/berserk_v2/berserk_v2_design_handoff.md` — handoff-спека для
  Animator (paths/format/pivot/palette/direction).
- `assets/sprites/characters/berserk_v2/…` — финальные кандидат-экспорты source/cell.
- `docs/design/previews/scrum531_berserk_v2_dark_bg.png` (+ contact) — превью.
- `build/qa/scrum531_berserk_v2/…_alpha_size_report.json` — QA-отчёт альфа/размер/пивот.
- (опц.) `docs/tasks/design_berserk_v2_visual_redesign_task.md` — mirror для борда.

Инструменты / скиллы (читать, НЕ менять):
- `skills/codex/fantasydisk-asset-generator/SKILL.md` (`~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py`) — генерация source.
- `tools/strip_white_background.py` — дочистка альфы (если присутствует).
- `docs/design/references/character_animation_style_sheet_0_1_5.md` — style-канон.
- `docs/design/references/chars_cartoon/berserk_cartoon_anchor_design_handoff.md` — образец handoff.md.

Заземление для контракта (читать, НЕ менять):
- `assets/sprites/characters/berserk_spriteframes.tres` — текущий рантайм-SpriteFrames (512-cell, pivot 256/470, idle 7fps / walk-move 9fps).
- `scripts/player.gd:1795/1804/1811` — как рантайм грузит берсерк-SpriteFrames.

## Замечания / подводные камни

- **Это чисто Design/source.** НЕ делать SpriteFrames/AnimationPlayer/AnimationTree,
  НЕ трогать `assets/sprites/characters/berserk_spriteframes.tres`, НЕ перерисовывать
  живые `full_frame/berserk/*`, НЕ менять `scripts/player.gd`, НЕ менять gameplay/balance,
  НЕ гонять animation/runtime smoke как часть фикса (это Animator/Back-end follow-up).
- **Anti-collision / locked paths**: задача НЕ касается `scripts/ui_screens.gd` и
  `scripts/progression_data.gd` (locked) — не трогать их вовсе. Файлы изолированы в новых
  `berserk_v2/`-папках, конфликтов с параллельными lane'ами быть не должно.
- **Не перепутать папки**: `docs/design/references/characters_v2/berserk/` уже существует
  (SCRUM-420). Новый путь — `docs/design/references/berserk_v2/` (без `characters_`). Это
  РАЗНЫЕ директории; писать строго в новую.
- **gpt-image-2 без альфы**: прозрачность обязателен постпроцесс. Сырой raw часто opaque/
  с checker-matte — это нормально, но в QA-отчёт класть extrema именно для `*_clean` и
  `*_idle_cell_512` (они должны быть истинно прозрачными).
- **Пустые руки**: канон — базовый character-sheet unarmed; оружие Берсерка (hammer/axe)
  — отдельные ассеты/сокеты (`scripts/berserk_weapon.gd`). НЕ запекать оружие в source.
- **Attack-ready поза**: тикет просит «idle/move/attack-ready pose references». Это
  pose-референс (поза готовности к удару) в handoff — НЕ анимация атаки и НЕ строка
  `attack_primary` в sheet (атака в игре отключена `USE_ATTACK_ANIMATION := false`).
- **Pixel fallback**: разрешён только если непиксельный source не анимируется чисто. Если
  пришлось — задокументировать причину в handoff.md (какая проверка показала непригодность).
- **Связанные тикеты**: SCRUM-420 (v2 bright/epic, done), SCRUM-442 (v3 cartoonish, done),
  SCRUM-456/461 (cartoon anchor — текущий живой, done), SCRUM-503 (берсерк DPS-кап —
  баланс, не визуал). Новый облик должен читаться отличимо от cartoon-anchor.
- **Live-sync mandate**: держать Jira/борд синхронными на каждом шаге; после смены статуса
  прогнать `tools/jira_board_sync.py` (watch out за stale flock — при зависании ps/lsof+kill PID).
- **Edge-case читаемости**: проверить силуэт на ~game-scale (персонаж ≈ 2× среднего монстра)
  — детализация не должна «слипаться»; dark-bg превью именно для этого.
