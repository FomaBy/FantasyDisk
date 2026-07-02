# SCRUM-532: Berserk v2 animation pack — move + primary attack из принятого source

Jira: SCRUM-532 · Роль: animator · Контур: codex · Приоритет: P1 · foma · Эпик: — (нет parent)
Статус: done

## Что и зачем

Берсерку делают новый визуал (SCRUM-531: «Berserk visual redesign — animation-ready source
sprite pack»). Эта задача — следующий, **анимационный** этап: из ПРИНЯТОГО дизайн-source
SCRUM-531 собрать игровой пак анимаций Берсерка v2 с двумя обязательными состояниями —
движение (move/walk) и основная атака (attack_primary).

Зачем продукту:
- Игрок должен видеть «брутального и читаемого» Берсерка в бою — стабильный силуэт, понятный
  замах оружия, плавная ходьба на геймплейном масштабе.
- Пользователь явно просил сначала изучить PixelLab-style пайплайн анимации и предпочитает
  **НЕ пиксель** (painterly/hand-drawn), если он анимируется чисто и стабильно; пиксель —
  только запасной вариант, если непиксельное качество хуже. Это требование тащится из
  SCRUM-531 и распространяется на анимацию.
- Исторический пробел: предыдущий v2-пак Берсерка (SCRUM-420) дал ТОЛЬКО idle+walk и **провалил
  валидацию манифеста** на отсутствии `attack_primary` (см. ниже). Эта задача закрывает дыру —
  добивает обязательную primary-атаку и приводит пак к Non-Negotiable Output Contract
  скилла `fantasydisk-animation-director`.

Ожидаемый результат: ассеты Berserk v2 (sheet/кадры + SpriteFrames при необходимости),
`move`/`walk` ≥5 кадров с реальным циклом шага и `attack_primary` ≥5 кадров с чётким таймингом
тела/оружия; стабильные pivots и направление лицом по дизайн-хэндоффу; QA-артефакты (contact/
GIF) и `animation_manifest.json`, проходящий валидатор анимации БЕЗ ошибки «missing
attack_primary». Геймплей/баланс/UI/классы НЕ трогаем.

ВАЖНО (gate): работа НЕ начинается, пока SCRUM-531 не отдал ПРИНЯТЫЕ source-файлы и handoff-
заметки (idle/move/attack-ready позы, выбор направления лицом, pivot/палитра/силуэт, точные
пути). Метка `blocked` на тикете — про это.

## Текущее состояние в коде

### Что уже есть от прошлой v2-итерации (SCRUM-420 / SCRUM-461)

- **Старый дизайн-source Berserk v2 (SCRUM-420)** — `docs/design/references/characters_v2/berserk/`:
  `berserk_v2_source_raw.png`, `berserk_v2_source_clean.png`, `berserk_v2_idle_cell_512.png`,
  `berserk_v2_sheet_source_handoff.png`, + хэндофф `berserk_v2_design_handoff.md`.
  Cell `512x512`, pivot `(256, 470)`, видимая высота ~376 px, безоружный source.
  ВНИМАНИЕ: это source ПРЕДЫДУЩЕГО редизайна. SCRUM-532 опирается на НОВЫЙ source из
  SCRUM-531 (по AC SCRUM-531 он ляжет в `docs/design/references/berserk_v2/` и финальные
  экспорты — в `assets/sprites/characters/berserk_v2/` ИЛИ в ближайший существующий путь, то
  есть `assets/sprites/characters/v2/berserk/`). Не перепутать старый и новый source.
- **Asset-side v2-копии (SCRUM-420)** — `assets/sprites/characters/v2/berserk/`:
  `berserk_v2_anim_sheet.png`, `berserk_v2_idle_source.png`, `berserk_v2_sheet_source_handoff.png`
  (всё закоммичено, `git status` чист). Это idle/move-материал; attack-ряда НЕТ.
- **Манифест прошлого пака** — `build/qa/scrum420_berserk_v2_anim/animation_manifest.json`:
  `kind: hero`, `production_pipeline: full_frame_spritesheet`, canvas 512, gutter/padding 48,
  `attack_required: false`, анимации `idle`/`walk`/`move` по 5 кадров (loop). Рядом
  `manifest_validator_output.txt` буквально содержит:
  `FantasyDisk animation manifest FAILED:` / `- berserk: missing attack_primary animation`.
  Это и есть дыра, которую закрывает SCRUM-532. Аналогичный «провал по attack_primary» есть у
  thief v2 (`build/qa/scrum435_thief_v2_anim/...`) — тот же сознательно урезанный паттерн.

### Как Берсерк сейчас живёт в рантайме

- **Активный SpriteFrames рантайма** — `assets/sprites/characters/berserk_spriteframes.tres`
  (SCRUM-461, cartoon/anime). Внутри ext_resource'ы на `assets/sprites/characters/full_frame/
  berserk/berserk_idle_0X.png` и `berserk_walk_0X.png` — по 5 кадров `idle` (speed 7, loop) и
  `walk`. Папка `assets/sprites/characters/full_frame/berserk/` СОДЕРЖИТ ещё и
  `berserk_attack_primary_0X.png` (5 кадров) и `berserk_idle_0X` — но `.tres` их НЕ
  подключает (attack по таску SCRUM-461 был исключён).
- **Резолв SpriteFrames игрока** — `scripts/player.gd`:
  - `_character_sprite_frames(config)` (строка 1795) → сначала `_character_full_frame_sprite_frames`
    → `_character_resource_sprite_frames` (строка 1811) грузит
    `res://assets/sprites/characters/<class>_spriteframes.tres` если есть. Для берсерка он есть,
    поэтому грузится именно `.tres`.
  - `_berserk_sprite_frames()` (строки 1870–1890) — РЕЗЕРВНЫЙ путь (используется только если
    `.tres` не нашёлся): строит кадры из `BERSERK_ANIMATED_SPRITE = berserk_walk_sheet_v2.png`
    (`BERSERK_ANIMATION_FRAME_SIZE = 384x384`, idle row 0 / walk row 1, и attack как алиас на
    walk-ряд по 5 кадров). По факту НЕ активен, пока `.tres` существует. Не опираться на него
    как на «текущую атаку Берсерка» — её визуально нет.
  - `BERSERK_SPRITE = berserk_unarmed.png`, `BERSERK_ANIMATED_SPRITE = berserk_walk_sheet_v2.png`
    (строки 12–13) — меню/легаси.
- **Legacy cutout-rig Берсерка** — `scripts/sliced_rig_manifest.gd`, ключ `"berserk"`
  (строки 102–117): source `berserk_unarmed.png`, parts `arm_l/arm_r/leg_l/leg_r/torso`
  (`assets/sprites/characters/cutout/berserk_*`), `attack_part: arm_r`, `foot_y: 492`,
  `socket: (388, 312)`. Это запасной анимационный слой движка (squash/socket/hit), который
  скрыт за full-frame Body, пока тот валиден. Менять его НЕ нужно.

### Контракт скилла и валидатор — что считается «готовым»

- **Скилл** `skills/codex/fantasydisk-animation-director/SKILL.md` — Non-Negotiable Output
  Contract: для каждого играбельного персонажа обязательны `move`/`walk` ≥5 кадров (loop) и
  `attack_primary` ≥5 кадров (non-loop, главным оружием/телесной атакой), КРОМЕ случая, когда
  активный таск явно ставит `attack_required=false`. Для SCRUM-532 attack ТРЕБУЕТСЯ (тикет это
  просит). Атака должна читаться как полное действие: anticipation → windup → active strike →
  follow-through → recovery. Слайсинг-сейфти обязателен: пустые gutters между кадрами и outer
  padding; для `512` ячейки — минимум `48 px`; runtime-прямоугольники НЕ включают gutter; нет
  bleed силуэта/оружия/VFX/тени в соседние кадры/край.
- **Валидатор** `skills/codex/fantasydisk-animation-director/scripts/validate_animation_manifest.py`
  (запуск из `~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py`).
  Для `kind: hero` без `attack_required:false`:
  - есть `move`/`walk`/`run`/`levitate`/`hover` (любое из) ≥5 кадров и `loop:true`;
  - есть `attack_primary` (имя начинается с `attack`) — иначе FAIL «missing attack_primary»;
  - все `attack*` ≥5 кадров и `loop` ∈ {false, none};
  - `transparent_background_checked:true`, `no_crop_checked:true`;
  - `canvas.width/height` заданы;
  - если есть `sprite_sheet`: `frame_gutter_px` и `outer_padding_px` ≥ `ceil(max_dim*0.08/8)*8`
    (для 512 → 48), и `safe_slicing_checked:true`.
  Прочие kind-проверки (elite/boss multiple attacks) к hero не применяются.

### Главный смоук-тест и его текущие ожидания (ОСТОРОЖНО — anti-regression)

`tests/animation_smoke_test.gd` (это «animation smoke», запуск:
`/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/
Documents/AI Agent" --script res://tests/animation_smoke_test.gd`). Сейчас он ЖЁСТКО фиксирует,
что РАНТАЙМ-SpriteFrames берсерка БЕЗ атаки:
- `_test_player_animation` (строки 178–187): `body.sprite_frames.resource_path ==
  berserk_spriteframes.tres`; есть `idle/walk/move` по 5 (loop); и ЯВНО запрещено
  `has_animation("attack") or has_animation("attack_primary")` (строки 182–183) — иначе тест
  падает «Expected Berserk … to omit attack animations by task scope».
- Цикл по классам (строки 302–325): для берсерка метка `SCRUM-461`, та же проверка «v2 без
  attack».

ВЫВОД ПО СКОУПУ: SCRUM-532 — задача ПРОДАКШЕНА АССЕТОВ + манифеста («Source/animation sheets and
manifests for Berserker v2 only»), а НЕ рантайм-интеграции. AC тикета прямо: «No unrelated
gameplay, balance, UI, or class changes». Значит:
- Делаем attack_primary кадры + sheet + манифест, который проходит ВАЛИДАТОР анимации (без
  «missing attack_primary»).
- НЕ подключаем attack в активный `berserk_spriteframes.tres` и НЕ правим `animation_smoke_test.gd`
  под наличие атаки — это была бы рантайм-интеграция и регрессия текущего зелёного смоука.
  Рантайм-вайринг новой атаки/визуала — отдельный backend/animator тикет (handoff), вне SCRUM-532.

## Что сделать — по шагам

0. **GATE.** Дождаться, что SCRUM-531 в статусе accepted и в репозитории есть его принятые
   source-файлы + handoff. Свериться с AC SCRUM-531: новый Берсерк визуально отличается от
   текущего, читается на геймплейном масштабе; предпочтительно non-pixel painterly; пути
   `docs/design/references/berserk_v2/` (source/reference) и `assets/sprites/characters/berserk_v2/`
   ИЛИ ближайший существующий (`assets/sprites/characters/v2/berserk/`); handoff содержит
   idle/move/attack-ready позы, выбор направления лицом, pivot/палитру/силуэт. Если source/
   handoff нет или он неполный — НЕ начинать, эскалировать как незавершённый upstream
   (handoff обратно в Design/SCRUM-531).

1. **Прочитать обязательное (по скиллу).** `AGENTS.md`,
   `docs/process/agent_role_boundaries_and_handoffs.md`, `docs/design/systems/animation.md`,
   `docs/design/current_game_state.md`, `docs/design/content_registry.md`, новый handoff из
   SCRUM-531 и этот файл. Изучить PixelLab-подход (skeleton/pose/action-frames →
   чистка кадров), как требует пользователь.

2. **Выбрать пайплайн.** По умолчанию (скилл, гуманоид) — rig-first `Skeleton2D`+`Bone2D`+
   `AnimationPlayer` как редактируемый источник, затем экспорт в sprite sheet/SpriteFrames, т.к.
   рантайм Берсерка ждёт `AnimatedSprite2D`. Допустим прямой `full_frame_spritesheet`, если так
   быстрее даёт стабильный силуэт (именно его использовал прошлый v2-пак SCRUM-420 и thief v2).
   Выбор зафиксировать в манифесте (`production_pipeline`) и в этом таск-файле.

3. **Канва, pivot, направление.** Держать единый cell/pivot из handoff SCRUM-531 (ориентир
   прошлой v2: `512x512`, pivot `(256, 470)`, нижне-центральная точка ног). Направление лицом —
   строго по handoff; зеркалирование делает рантайм (`flip_h`/scale.x), source — одна сторона.
   Безоружное тело по умолчанию (оружие — socket-owned), ЕСЛИ handoff не велит иначе. Сохранить
   принятый стиль/палитру/силуэт и читаемость на боевом масштабе.

4. **Анимация MOVE/WALK (обязательно, loop).** ≥5 читаемых кадров реального цикла шага:
   contact → passing → lift → recovery. Без статичного «боба». Назвать `move` и/или `walk`
   (валидатор принимает любое из `move/walk`; рантайм-смоук v2 ждёт idle+walk+move — если планируешь
   когда-то интегрировать, держи имена совместимыми, но в ЭТОЙ задаче рантайм не трогаем). Pivots
   стабильны (нога не «плавает» по Y).

5. **Анимация ATTACK_PRIMARY (обязательно, non-loop) — ГЛАВНАЯ ЦЕЛЬ задачи.** ≥5 кадров с
   чётким таймингом тела и оружия: anticipation → windup → active strike/impact → follow-through
   → recovery. Это primary-атака Берсерка (тяжёлый замах оружием/кулаком в его брутальном
   стиле). Силуэт и pivots стабильны; оружие/VFX/тень НЕ выходят за кадр и не залезают в gutter.
   Имя клипа/ряда — `attack_primary` (валидатор требует именно его; `attack` можно добавить
   алиасом, но это не обязательно для прохождения валидатора).

6. **(Опц., строго без расширения скоупа) idle/hit.** `idle`/`hit`-кадры можно добавить ТОЛЬКО
   если они не раздувают объём и не задерживают обязательный move/attack. По умолчанию — НЕ
   добавлять, чтобы не выйти за «locked scope» тикета.

7. **Слайсинг-сейфти.** Если собирается sprite sheet: пустые discard-only gutters между кадрами
   и outer padding ≥ `48 px` для 512-ячейки (или ≥8% размера ячейки, округлить вверх до 8 px).
   Runtime-прямоугольники исключают gutter. Проверить per-frame, что нет alpha-bleed/касания
   соседних кадров/края (как делал манифест SCRUM-420: `frame_stats` с `edge_alpha_pixels: 0`).

8. **QA-артефакты.** Сложить в `build/qa/scrum532_berserk_v2_anim/` (или
   `build/qa/<task>/`): contact-sheet с номерами кадров и именами анимаций; GIF/preview move и
   attack; `animation_manifest.json`; `manifest_validator_output.txt` с РЕЗУЛЬТАТОМ валидатора.
   Для rig/hybrid пайплайна манифест дополнительно несёт `animation_player_node`,
   `bone_hierarchy`, `animation_player_clips_checked:true`, `timeline_markers_checked:true` (для
   attack-клипов), `source_parts`, `rig_scene`.

9. **Манифест.** `build/qa/scrum532_berserk_v2_anim/animation_manifest.json`, по образцу
   SCRUM-420, но с обязательным attack-блоком. Минимум на сущность `berserk`:
   `id:"berserk"`, `kind:"hero"`, `production_pipeline` (выбранный),
   `sprite_sheet`/`spriteframes`/`rig_scene` (хотя бы один путь),
   `canvas:{width,height,pivot_x,pivot_y}`, `frame_gutter_px>=48`, `outer_padding_px>=48`,
   `safe_slicing_checked:true`, `transparent_background_checked:true`, `no_crop_checked:true`,
   `attack_required:true` (или просто не ставить false), и `animations`:
   `{name:"move",frames:>=5,loop:true,...}` (+ опц. `walk` алиас),
   `{name:"attack_primary",frames:>=5,loop:false,...}`. БЕЗ `attack_required:false` (иначе
   валидатор не потребует attack и дыра останется концептуально не закрыта).

10. **Валидация манифеста (главный gate готовности).**
    `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py
    build/qa/scrum532_berserk_v2_anim/animation_manifest.json`. Ожидать exit 0 и строку
    `FantasyDisk animation manifest OK: 1 entities`. НЕ должно быть «missing attack_primary» /
    «fewer than 5 frames» / «should not loop» / gutter/padding/checked-ошибок. Сохранить вывод в
    `manifest_validator_output.txt`.

11. **Рантайм-смоук — НЕ регрессировать.** Прогнать
    `res://tests/animation_smoke_test.gd` — он должен остаться ЗЕЛЁНЫМ. Так как мы НЕ трогаем
    `berserk_spriteframes.tres` и не подключаем attack в рантайм, тест продолжит видеть берсерка
    «idle/walk/move без attack» (строки 178–187, 302–325) и пройдёт. Если он покраснел — значит
    кто-то задел рантайм-вайринг; откатить, это вне скоупа SCRUM-532.

12. **Документация.** Обновить таск-файл (этот) фактами: entity id, имена анимаций и кол-во
    кадров, пути source/sheet/SpriteFrames/rig, canvas/pivot/fps/loop, gutter/padding и
    результат safe-slicing, marker-тайминги attack (если rig), QA-пути и команды. Дописать в
    `docs/design/systems/animation.md` строку про Berserk v2 attack-пак (как там фиксируют каждую
    анимационную веху). `docs/design/content_registry.md` / `current_game_state.md` /
    `CHANGELOG.md` — трогать ТОЛЬКО если меняются активные рантайм-пути (в этой задаче не
    меняются → правок там, скорее всего, не требуется). Опц. зеркальный лог
    `docs/tasks/anim_berserk_v2_animation_pack_task.md` (как разрешает тикет; в репо есть схожие
    `anim_*_task.md`/`art_char_redraw_anim_berserk_task.md`).

## Acceptance Criteria

Из тикета:
- [ ] Работа НЕ начата, пока SCRUM-531 не отдал ПРИНЯТЫЕ source-файлы и handoff-заметки.
- [ ] Анимация движения/ходьбы имеет 5+ читаемых кадров.
- [ ] Анимация primary-атаки имеет 5+ читаемых кадров с чётким таймингом тела/оружия.
- [ ] Опц. idle/hit кадры добавлены ТОЛЬКО если не расширяют скоуп и не задерживают
      обязательный move/attack набор.
- [ ] Pivots стабильны, направление лицом соответствует Design-handoff, и smoke/manifest-
      валидация анимации для этого ассета проходит.
- [ ] Не внесено посторонних изменений в gameplay, balance, UI или классы.

Дополнено по коду:
- [ ] `animation_manifest.json` Berserk v2 проходит
      `validate_animation_manifest.py` с exit 0 (`... OK: 1 entities`), БЕЗ «missing
      attack_primary» (та самая ошибка из `build/qa/scrum420_berserk_v2_anim/
      manifest_validator_output.txt` устранена).
- [ ] `move`/`walk` ≥5 кадров `loop:true`; `attack_primary` ≥5 кадров `loop:false`; все
      `attack*` ≥5 кадров и не лупятся (требования валидатора).
- [ ] Если собран sprite sheet (512-cell): `frame_gutter_px>=48`, `outer_padding_px>=48`,
      `safe_slicing_checked/transparent_background_checked/no_crop_checked = true`; нет alpha-
      bleed/касания краёв (по образцу `frame_stats … edge_alpha_pixels: 0` в манифесте SCRUM-420).
- [ ] `tests/animation_smoke_test.gd` остаётся ЗЕЛЁНЫМ (рантайм-SpriteFrames берсерка не
      изменён; attack в рантайм НЕ подключён → проверки «omit attack» строки 182–183/320–321 не
      нарушены).
- [ ] QA-артефакты на месте: contact, GIF move, GIF attack, манифест, вывод валидатора.
- [ ] Таск-файл и `docs/design/systems/animation.md` отражают финальные пути/кадры/тайминги.

## Files / точки входа

- `docs/design/references/berserk_v2/` ИЛИ `docs/design/references/characters_v2/berserk/` —
  ПРИНЯТЫЙ source/handoff из SCRUM-531 (ВХОД задачи; не редактировать дизайн-source, потреблять).
- `assets/sprites/characters/berserk_v2/` ИЛИ `assets/sprites/characters/v2/berserk/` —
  финальные анимационные ассеты Berserk v2 (sheet/кадры), которые создаёт/обновляет эта задача
  (locked scope тикета). Прошлый пак уже здесь: `berserk_v2_anim_sheet.png` (idle/move) — attack
  добавляется тут же или новым sheet.
- `build/qa/scrum532_berserk_v2_anim/` — QA-выход: `animation_manifest.json`,
  `manifest_validator_output.txt`, `*_contact.png`, `berserk_v2_move.gif`,
  `berserk_v2_attack.gif`. Образец структуры: `build/qa/scrum420_berserk_v2_anim/`.
- `skills/codex/fantasydisk-animation-director/scripts/validate_animation_manifest.py` —
  валидатор (gate); запуск из `~/.codex/skills/.../validate_animation_manifest.py`.
- `tests/animation_smoke_test.gd:178-187, 302-325` — рантайм-инвариант берсерка (idle/walk/move
  без attack). НЕ менять; держать зелёным.
- `docs/design/systems/animation.md` — добавить строку про Berserk v2 attack-пак.
- (Справочно, НЕ менять в этой задаче) `scripts/player.gd:1795-1890` —
  `_character_sprite_frames`/`_character_resource_sprite_frames`/`_berserk_sprite_frames`
  (рантайм-резолв); `scripts/sliced_rig_manifest.gd:102-117` — legacy cutout «berserk»;
  `assets/sprites/characters/berserk_spriteframes.tres` — активный рантайм-SpriteFrames.

## Замечания / подводные камни

- **GATE / зависимость SCRUM-531.** Это блокирующая зависимость, не «желательно». Без
  принятого source/handoff задача неактуальна. Метка `blocked` снимается только после accepted
  SCRUM-531. Если SCRUM-531 выбрал пиксель-fallback — анимация тоже идёт по нему; если non-pixel
  — держать его, как просит пользователь.
- **Скоуп = АССЕТЫ + МАНИФЕСТ, НЕ рантайм.** Тикет: «Source/animation sheets and manifests for
  Berserker v2 only». НЕ редактировать `berserk_spriteframes.tres`, `scripts/player.gd`,
  `animation_smoke_test.gd`, конфиги классов. Подключение нового визуала/атаки в живой рантайм —
  отдельный тикет (animator/backend handoff). Иначе ломается зелёный animation smoke и нарушается
  «No unrelated gameplay/UI/class changes».
- **Не перепутать source-итерации.** В репо лежит СТАРЫЙ v2 source (SCRUM-420) в
  `characters_v2/berserk/`. Брать НОВЫЙ из SCRUM-531 (вероятно `references/berserk_v2/`). Если
  путь нового source совпадёт со старым каталогом — свериться по handoff SCRUM-531, какие именно
  файлы приняты, чтобы не анимировать устаревший силуэт.
- **ANTI-COLLISION / locked paths.** Глобально горячие/конфликтные файлы Claude-контура —
  `scripts/ui_screens.gd` и `scripts/progression_data.gd`. Эта задача их НЕ касается вообще
  (чисто анимация/ассеты). Контур задачи — `codex`; параллельных правок берсерк-ассетов в
  `assets/sprites/characters/v2/berserk/` быть не должно, но проверить, что никто другой их не
  трогает, и коммитить СВОИ файлы явным `git add` (по памяти проекта про multi-worker churn — не
  `git add -A`).
- **`attack_required` в манифесте.** Прошлый пак ставил `attack_required:false` и валидатор не
  требовал attack (но всё равно печатал FAIL, т.к. кто-то прогонял с дефолтом). В ЭТОЙ задаче
  attack обязателен — НЕ ставить `attack_required:false`, иначе валидатор «пропустит» отсутствие
  attack и цель (закрыть дыру) не будет проверена.
- **Имена анимаций.** Валидатор хочет `attack_primary` (именно это имя для проверки наличия) и
  любое из `move/walk/run/levitate/hover`. Рантайм v2-контракт берсерка ждёт `idle/walk/move`.
  Чтобы будущая интеграция была безболезненной — называть ряды `move`(+`walk` алиас) и
  `attack_primary`(+опц. `attack` алиас), кадры 384 или 512 cell консистентно. На ПРОХОЖДЕНИЕ
  валидатора достаточно `move`+`attack_primary`.
- **Слайсинг 512.** Для 512-ячейки минимальный gutter/padding = 48 px (валидатор:
  `ceil(512*0.08/8)*8 = 48`). Если сменишь cell на 384 — порог станет 32 px (но рантайм берсерка
  исторически 384 в `_berserk_sprite_frames`, а v2-source — 512; держи один cell на весь пак и
  отрази в манифесте).
- **Крит/боевые цифры не относятся.** Не путать с эпиком SCRUM-522 (типы урона/цвета) — это
  отдельная ветка; SCRUM-532 чисто визуально-анимационная, без формул/урона.
- **Прогон тестов.** `animation_smoke_test.gd` обязателен (должен остаться зелёным). Если rig-
  пайплайн затронул общие рантайм-пути — прогнать и `tests/runtime_smoke_test.gd`. Godot:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot`.
- **Связанные артефакты-прецеденты.** SCRUM-420 (`build/qa/scrum420_berserk_v2_anim/`) —
  структура манифеста/`frame_stats`/`qa_artifacts` для копирования; thief v2
  (`build/qa/scrum435_thief_v2_anim/`) — тот же «idle/walk/move без attack» паттern, который
  SCRUM-532 как раз достраивает атакой.

## Animator Result - 2026-06-28

Status: ready for QA. Owner: Animator/Codex `anim-loop-1`.

Implemented Berserk v2 animation asset pack from accepted SCRUM-531 source,
without wiring it into live runtime:

- Entity: `berserk`, kind `hero`, full-frame spritesheet pipeline.
- Source: `docs/design/references/berserk_v2/berserk_v2_idle_cell_512.png`.
- Runtime-candidate sheet: `assets/sprites/characters/berserk_v2/berserk_v2_anim_sheet.png`.
- Frame folders:
  - `assets/sprites/characters/berserk_v2/frames/move/` - 5 frames.
  - `assets/sprites/characters/berserk_v2/frames/attack_primary/` - 6 frames.
- Canvas: `512x512`, pivot `(256, 470)`, 3/4-right flip-friendly direction.
- Safe source sheet: `48 px` outer padding and `48 px` discard-only gutters.
- `move`/`walk`: 5 frames, 9 fps, looping; contact/passing/opposite-contact/passing/settle cycle with secondary cloak and arm motion.
- `attack_primary`: 6 frames, 12 fps, non-looping; anticipation, windup, active empty-fist strike, impact/follow-through, recoil, recovery.
- No weapon is baked into the frames; the attack reads as an empty-fist/body strike to preserve SCRUM-531 handoff constraints.
- Live runtime intentionally untouched: no changes to `assets/sprites/characters/berserk_spriteframes.tres`, `assets/sprites/characters/full_frame/berserk/*`, `scripts/player.gd`, or `tests/animation_smoke_test.gd`.

QA evidence:

- Manifest: `build/qa/scrum532_berserk_v2_anim/animation_manifest.json`.
- Manifest validator output: `build/qa/scrum532_berserk_v2_anim/manifest_validator_output.txt`.
- Contact sheet: `build/qa/scrum532_berserk_v2_anim/berserk_v2_contact.png`.
- GIF previews: `build/qa/scrum532_berserk_v2_anim/berserk_v2_move.gif`, `build/qa/scrum532_berserk_v2_anim/berserk_v2_attack_primary.gif`.
- Alpha/slicing report: `build/qa/scrum532_berserk_v2_anim/frame_alpha_slicing_report.json`.

Validation:

- `python C:\Users\FomaE\.codex\skills\fantasydisk-animation-director\scripts\validate_animation_manifest.py build\qa\scrum532_berserk_v2_anim\animation_manifest.json` PASS: `FantasyDisk animation manifest OK: 1 entities`.
- Static alpha/slicing QA checked 12 PNG/sheet entries: `edge_alpha_pixels = 0` for all generated frame PNGs and sheet.
- `git diff -- assets/sprites/characters/berserk_spriteframes.tres scripts/player.gd tests/animation_smoke_test.gd` is empty.
- `animation_smoke_test.gd` was attempted with Godot 4.7 on Windows and is recorded in `build/qa/scrum532_berserk_v2_anim/animation_smoke_output.txt`; it failed before execution on pre-existing parse/class visibility issue: `Identifier "ProgressionData" not declared in the current scope` at `tests/animation_smoke_test.gd:29`.

## QA-Вердикт: PASSED
Статус: PASSED
Проверено claude-qa 2026-07-01 на HEAD origin/dev (delivery commit 7f588c52 = ancestor origin/dev).
- move: 5 кадров loop:true; walk: alias(move) 5 кадров loop:true; attack_primary: 6 кадров loop:false — все ≥5 (контракт валидатора выполнен).
- Все кадры PNG 512×512, alpha 0-255, edge_alpha_pixels=0 по 12 записям alpha-report (sheet 3408×1168 без alpha-bleed).
- animation_manifest.json validator: OK: 1 entities (committed manifest_validator_output.txt).
- Scope соблюдён (asset-pack-only): 7f588c52 НЕ трогает berserk_spriteframes.tres/player.gd/animation_smoke_test.gd/progression_data; runtime_integration в манифесте помечен «not connected by SCRUM-532 scope».
- animation_smoke_test.gd → PASS (exit 0) на HEAD; runtime_smoke → PASS.
- QA-артефакты на месте: contact, GIF move, GIF attack, манифест, вывод валидатора, alpha-report.
Прим.: в живом рантайме берсерк уже использует новый berserk_pixellab пак (SCRUM-703); v2 anim-пак поставлен по своему asset-only скоупу и не подключён в рантайм — это соответствует ТЗ, supersession — вопрос продукта, не QA-блокер.
Блок добавлен в .md, чтобы board_sync не реверт-ил PASSED-тикет.
