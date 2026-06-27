# SCRUM-510: Smoke: регресс-гард на нулевой рендер-спам (det==0 / bone-length warnings)

Jira: SCRUM-510 · Роль: qa · Контур: claude · Приоритет: P2 · foma · Эпик: —
Статус: К выполнению

## Что и зачем

После фикса рендер-спама скелетного рига (SCRUM-509, коммит `205fe13e "Fix skeletal rig bone rest setup"`) рантайм перестал заваливать консоль 360×`ERROR det==0` + ~20×`WARNING` на риг. Но **гарда нет**: до фикса `runtime_smoke` печатал этот шум и всё равно проходил зелёным — ошибки рендера не отлавливались ассертами, поэтому регрессия (кто-то снова заведёт вырожденный bone-rest) вернётся незаметно и накопится обратно.

Цель — дешёвый, детерминированный, headless-гонимый гард, который **падает (red) на состоянии до фикса рига и проходит (green) после фикса**. С точки зрения продукта: это не геймплейная фича, а tech-debt/QA-страховка — играбельные скелетные персонажи (dark_mage, knight) должны рендериться без вырожденных трансформов костей, иначе спрайты схлопываются/исчезают и засирают лог, маскируя реальные ошибки.

Ожидаемый результат: новый smoke-тест строит скелетный риг для dark_mage и knight, обходит все `Bone2D` и ассертит, что rest/global-трансформ каждой кости имеет **ненулевой детерминант** (т.е. кость не вырождена в точку/линию). Тест включён в общий smoke-набор (`tools/run_focused_tests.sh`) и задокументирован.

## Текущее состояние в коде

**Что генерит/чинит риг:**
- `scripts/skeleton_player_rig_2d.gd` — `Node2D`, экспортит `entity_id`, `manifest_path`, `base_scale`. В `configure()` → `_build_rig()` создаёт `Skeleton2D` ("Skeleton2D") и дерево `Bone2D` (`Root → Pelvis → Torso → Head/UpperArm*/Thigh*…`).
- `_spawn_bone()` (строки 162–175): каждой кости ставит `set_autocalculate_length_and_angle(false)`, `set_length(MIN_BONE_LENGTH)` (=8.0), `set_bone_angle(0.0)`, `set_rest(Transform2D(bone.rotation, bone.position))`.
- `_finalize_bone_setup()` (строки 178–196) — **это и есть фикс SCRUM-509**: после полной сборки для каждой кости пересчитывает length по смещению первого child-Bone2D (`_first_child_bone_offset`) либо по экстенту спрайта (`_leaf_bone_length`, clamp `[8.0, 72.0]`), затем `set_length(maxf(length, MIN_BONE_LENGTH))`, `set_bone_angle(angle)`, `set_rest(...)`, и помечает кость метой `bone.set_meta("rest_det_safe", true)` + `bone.set_meta("bone_length_source", ...)`.
- Константы: `MIN_BONE_LENGTH := 8.0`, `MAX_LEAF_BONE_LENGTH := 72.0` (строки 5–6).
- Источник вырождения, который чинит фикс: до SCRUM-509 кости имели нулевую length/угол → `Skeleton2D` строил вырожденный bone-rest (det==0) при ригинге спрайтов, отсюда 360 `det==0`.

**Где риг инстанцируется (источник рантайм-спама):**
- `scenes/characters/DarkMageSkeletonRig.tscn` — `script = skeleton_player_rig_2d.gd`, `entity_id="dark_mage"`, `manifest_path="res://assets/sprites/characters/skeleton_parts/dark_mage/skeleton_source_manifest.json"`, `base_scale=(0.5,0.5)`.
- `scenes/characters/KnightSkeletonRig.tscn` — то же для `knight` / `.../knight/skeleton_source_manifest.json`.
- Оба манифеста существуют на диске (`assets/sprites/characters/skeleton_parts/{dark_mage,knight}/skeleton_source_manifest.json`).
- `scripts/player.gd` строки 17–18 preload'ит обе сцены; `_character_skeleton_rig_scene(class_id)` (стр. 1786–1791) маппит `dark_mage`→DarkMage, `knight`→Knight (других скелетных персонажей нет — остальные классы на cutout-риге/full-frame). `_configure_skeletal_player_rig()` (стр. 1760) добавляет инстанс как `VisualRoot/SkeletalRigRoot`.

**Как риг уже косвенно покрыт тестами (но БЕЗ det-гарда):**
- `tests/animation_smoke_test.gd` → `_assert_skeletal_player_rig(player, character_id)` (стр. 792–849): проверяет существование костей `Root/Pelvis/Torso/...`, наличие клипов idle/walk/move, движение root при ходьбе, противофазу бёдер, mirror по фейсингу. **Детерминант rest/global НЕ проверяется** — это и есть дырка.
- `tests/sliced_rig_manifest_smoke_test.gd` — эталон **изолированного** теста: `extends SceneTree`, preload скрипта, обход данных, накопление `errors[]`, в конце `push_error` по каждой + `quit(1)`, иначе `print(...); quit(0)`. **Не грузит Main.tscn, не трогает мета-сейв** — ровно тот паттерн, что нужен здесь.

**Как гоняются smoke-тесты:**
- `tools/run_focused_tests.sh` автоматически подхватывает любой `tests/*.gd`, начинающийся с `^extends SceneTree`, и гоняет headless через Godot, exit-код = вердикт. Новый файл попадёт в набор **автоматически** по факту `extends SceneTree`.
- Ручной запуск одиночного: `Godot --headless --path . --script res://tests/<name>.gd`.

## Что сделать — по шагам

1. **Создать отдельный изолированный тест-файл** `tests/skeletal_rig_rest_det_smoke_test.gd` (НЕ дописывать в зонтичный `runtime_smoke_test.gd` — тот грузит `Main.tscn` и читает реальный dev мета-сейв `unlocks/death_save`, что даёт ложные red'ы; держим гард независимым и детерминированным по образцу `sliced_rig_manifest_smoke_test.gd`). Файл `extends SceneTree` → автоматически попадёт в `run_focused_tests.sh`.
2. **Для каждого рига из набора `["dark_mage", "knight"]`** (можно через preload сцен `DarkMageSkeletonRig.tscn`/`KnightSkeletonRig.tscn`, либо инстанцируя `skeleton_player_rig_2d.gd` напрямую и вызывая `configure(manifest_path, entity_id, base_scale)`):
   - инстанцировать сцену, добавить в `root` (риг строится в `_ready()`/`configure()`), `await process_frame` чтобы дерево собралось;
   - получить `Skeleton2D` (нода "Skeleton2D" под ригом);
   - рекурсивно обойти все потомки типа `Bone2D` (через `find_children("*", "Bone2D", true, false)` или ручной обход дерева).
3. **Для каждой `Bone2D` ассертить ненулевой детерминант** rest- и/или global-трансформа:
   - `bone.get_rest().determinant()` — детерминант rest-трансформа (то, что `set_rest()` записал в `_finalize_bone_setup`);
   - `bone.get_global_transform().determinant()` — фактический рендер-трансформ;
   - условие падения: `absf(det) < EPS` (взять `EPS := 0.0001`). Накапливать имя кости + значение det в `errors[]`.
   - (Дополнительно, дёшево и по делу) ассертить `bone.get_length() >= MIN_BONE_LENGTH` (8.0) — именно нулевая length рождала вырожденный rest; и/или что кость несёт мету `rest_det_safe == true`, проставляемую фиксом. Это «привязывает» гард к источнику регрессии.
4. **Гард на не-вакуумность**: убедиться, что обошли > N костей (например `bone_count >= 8` на риг — у скелета их заведомо больше, см. `_assert_skeletal_player_rig`), иначе тест прошёл бы «вхолостую» при пустом ригинге (паттерн из `sliced_rig_manifest_smoke_test.gd`, где гейтят `data.size() < 10`).
5. **Финал по образцу изолированных тестов**: если `errors` непусто — `push_error` по каждой ошибке + сводный `push_error(... "%d ошибок")` + `quit(1)`; иначе `print("Skeletal rig rest-det smoke passed (N bones, 2 rigs)."); quit(0)`. Освобождать инстансы (`queue_free()`), не оставлять висящих нод.
6. **Проверить red→green вручную и приложить оба прогона в отчёте Jira**: временно откатить `_finalize_bone_setup` (или закомментить вызов на стр. 124 и пересборку length/angle) → тест должен стать **red** (det==0 / length==0); вернуть фикс → **green**. Откат — только локально для демонстрации, в коммит НЕ кладём.
7. **Документировать запуск**: добавить строку запуска в шапку нового файла (как в `sliced_rig_manifest_smoke_test.gd`) и, если уместно, упомянуть в `AGENTS.md` рядом со списком smoke-тестов (раздел ~стр. 160). Файл уже попадёт в `run_focused_tests.sh` без правок скрипта — но проверить это фактическим прогоном `tools/run_focused_tests.sh skeletal_rig_rest_det`.

## Acceptance Criteria

- [ ] Тест строит скелетный риг для **dark_mage и knight** и обходит все `Bone2D`, ассертя, что `get_rest().determinant()` (и/или `get_global_transform().determinant()`) каждой кости имеет **ненулевой детерминант** (`absf(det) >= 0.0001`).
- [ ] Тест **падает (red)** на состоянии до фикса рига (откат `_finalize_bone_setup`) и **проходит (green)** после фикса — оба прогона приложены в отчёте Jira.
- [ ] Тест **headless-запускаемый и детерминированный**, НЕ зависит от реального dev мета-сейва (`unlocks`/`death_save`) и НЕ грузит `Main.tscn` (изолированный `extends SceneTree`, как `sliced_rig_manifest_smoke_test.gd`).
- [ ] Тест **включён в общий smoke-набор** (`tools/run_focused_tests.sh` подхватывает по `^extends SceneTree`) и способ запуска **задокументирован** (шапка файла + при желании AGENTS.md).
- [ ] Не-вакуумный гард: тест ассертит обход ≥8 костей на риг (иначе fail), чтобы пустой/сломанный ригинг не давал ложный green.
- [ ] Тест зелёный в текущем (после-фикс) состоянии репо; прочие smoke-тесты не сломаны.

## Files / точки входа

- `tests/skeletal_rig_rest_det_smoke_test.gd` — **НОВЫЙ** файл, `extends SceneTree`, `_initialize()`: инстанцирование ригов, обход `Bone2D`, det-ассерты, накопление `errors`, `quit(0/1)`. Образец структуры — `tests/sliced_rig_manifest_smoke_test.gd`.
- `scenes/characters/DarkMageSkeletonRig.tscn`, `scenes/characters/KnightSkeletonRig.tscn` — preload-источники ригов для теста (читать, НЕ менять).
- `scripts/skeleton_player_rig_2d.gd` — система под тестом (читать для понимания `_finalize_bone_setup`/`MIN_BONE_LENGTH`/`rest_det_safe`; **в рамках этой задачи НЕ менять**). Временный откат фикса — только локально для red-демонстрации.
- `tools/run_focused_tests.sh` — раннер; правок НЕ требует (авто-подхват), но прогнать для верификации.
- `AGENTS.md` (~стр. 160, список smoke-тестов) — опционально дописать строку запуска нового теста.

## Замечания / подводные камни

- **Anti-collision / locked paths**: `scripts/ui_screens.gd` и `scripts/progression_data.gd` — НЕ трогать (и не нужны здесь). Задача чисто QA: создаём один новый тест-файл, продукт-код не меняем.
- **Связь с SCRUM-509**: эта задача — регресс-гард на уже сделанный фикс (коммит `205fe13e`). Хук для привязки к фиксу — мета `rest_det_safe`/`bone_length_source` и константа `MIN_BONE_LENGTH=8.0`, проставляемые в `_finalize_bone_setup()`.
- **Почему det==0, а не «length-only»**: 360 `ERROR det==0` рождались внутренним ригингом `Skeleton2D`, когда bone-rest вырожден (нулевая length/совпадающие точки). Проверка детерминанта rest/global — прямой и устойчивый сигнал; проверка `get_length() >= MIN_BONE_LENGTH` — дешёвый вторичный сигнал ближе к корню.
- **`Transform2D(rotation, position)` сам по себе det=1** — поэтому проверять надо именно `get_rest()`/`get_global_transform()` уже собранной кости (после `_finalize_bone_setup` и `Skeleton2D`-ригинга), а не «руками» пересобранный трансформ; иначе тест станет вакуумным и не поймает регрессию.
- **Изоляция от мета-сейва (память проекта)**: умышленно НЕ включаем в зонтичный `runtime_smoke_test.gd` — он грузит `Main.tscn` и читает реальный dev мета-сейв, что историческя давало ложные red'ы по unlocks/death_save. Отдельный `SceneTree`-файл этого избегает.
- **`await process_frame`**: риг строится в `_ready()`/`configure()`; перед обходом костей дать кадр на сборку дерева (как делает `runtime_smoke_test._initialize` после `root.add_child(main)`).
- **Набор персонажей**: скелетный риг сейчас только у `dark_mage` и `knight` (`player._character_skeleton_rig_scene`). Если появятся новые скелетные классы — список ригов в тесте стоит держать рядом с этим маппингом; для текущей задачи достаточно двух из тикета.
- **Только один новый .md и один новый .gd-тест** в этой задаче — никаких правок продукт-кода в коммите.
