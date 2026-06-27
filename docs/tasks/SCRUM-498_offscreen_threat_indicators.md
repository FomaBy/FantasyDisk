# SCRUM-498: Индикатор внеэкранных угроз (стрелки к боссу/элиткам/шутерам)

Jira: SCRUM-498 · Роль: backend · Контур: claude · Приоритет: P1 · foma · Эпик: —
Статус: К выполнению (Feature)

## Что и зачем

Боевая камера привязана к игроку с зумом `COMBAT_CAMERA_ZOOM = (1.12, 1.12)` и кэпами по краям арены, поэтому на 1600x900 и даже на 2560x1440 в кадр попадает лишь часть арены `ARENA_SIZE = (2560, 1440)`. Опасные дальнобойные враги (босс, элитки, shooter/mage/spitter) часто стоят и стреляют из-за края экрана. Игрок получает урон «из ниоткуда», не понимает, куда двигаться/смотреть, и это ощущается как нечестная смерть.

Цель — добавить компактные **edge-индикаторы** (стрелка + иконка ранга) на границе вьюпорта, указывающие направление к значимым внеэкранным угрозам. Маркеры только для опасных архетипов (босс / элитка / активно стреляющий ranged), чтобы не превращать экран в «ёлку» из стрелок на каждый melee-мусор.

Ожидаемый результат для игрока: когда опасная цель за кадром — на ближайшем к ней краю экрана появляется указатель её направления с иконкой ранга; как только цель входит в кадр или умирает — указатель исчезает. Индикаторы не кликабельны и не мешают route-map/combat-кликам.

## Текущее состояние в коде

**Камера и арена.**
- `scripts/main.gd:34-36` — `ARENA_SIZE = (2560,1440)`, `ARENA_CENTER`, `COMBAT_CAMERA_ZOOM = (1.12,1.12)`.
- `scripts/combat_director.gd:59-71` `_configure_player_camera()` — берёт `Camera2D` у игрока (`game.current_player.get_node("Camera2D")`), ставит zoom, `limit_left/top/right/bottom = 0..ARENA_SIZE`, `position_smoothing_enabled = true`. Кэмера-клэмп важен: на краях арены центр кадра не равен позиции игрока — нельзя считать игрока центром экрана, нужно брать реальный canvas transform.
- Проекция world→screen в проекте делается через canvas transform: `scripts/main.gd:730-733` `_screen_position_to_arena_world()` использует `get_viewport().get_canvas_transform()` (инверсно для screen→world). Для нашего обратного направления: `screen_pos = get_viewport().get_canvas_transform() * world_pos`. Видимый прямоугольник экрана — `get_viewport_rect().size` (или `get_viewport().get_visible_rect().size`, как уже делается в `ui_screens.gd`).

**Враги и архетипы.**
- Базовый `scripts/enemy.gd`. В `_ready()` (`enemy.gd:106-126`) каждый враг делает `add_to_group("enemies")`; элитки — в группе `elite_enemies`; боссы (`scripts/boss.gd:40-42`, `super()` + `add_to_group("bosses")`).
- Ранг/тир уже классифицируется: `enemy.gd:148-156` `_epic_scale_profile_id()` возвращает `"boss"` / `"elite"` / `"ordinary"` по группам и `enemy_type_name`. Это естественная основа для «ранга угрозы» (boss/elite).
- Ranged-архетип — это флаг `@export var can_shoot` (`enemy.gd:11`). Его выставляют сцены `EnemyShooter.tscn`, `EnemyMage.tscn`, `EnemySpitter.tscn`, `ElitePoisoned.tscn`, а также все боссы (`can_shoot = true`). Дистанция кайтинга — `desired_shooting_distance` (`enemy.gd:23`, дефолт 280).
- Стрельба: `enemy.gd:1080-1099` `_update_shooting()`. Кулдаун `_shoot_cooldown` (`enemy.gd:35`) тикает вниз; после выстрела сбрасывается в `fire_interval` (`enemy.gd:15`, дефолт 1.5). «Активно ведёт огонь» => враг недавно стрелял или вот-вот выстрелит по игроку: можно опираться на `can_shoot && projectile_scene != null && _shoot_cooldown <= fire_interval` (т.е. цикл стрельбы активен — игрок в зоне досягаемости), либо ввести таймстамп последнего выстрела. Сейчас прямого «недавно выстрелил» флага нет — его надо добавить (см. шаги).
- Удаление из групп при смерти: `enemy.gd:397-399` снимает `enemies/bosses/elite_enemies/summoned_enemies`. Значит, мёртвый враг автоматически выпадает из итерации по группам — маркер исчезнет сам, если перебирать живые группы каждый кадр.

**HUD.**
- `scripts/ui_screens.gd:7553-7575` `_create_hud()` создаёт `game.hud_layer` (`CanvasLayer`, `process_mode = PROCESS_MODE_ALWAYS`) и внутри — `Control` `CombatHudRoot` с `set_anchors_preset(PRESET_FULL_RECT)` и `mouse_filter = MOUSE_FILTER_IGNORE`. Это правильный родитель для индикаторов: full-rect Control поверх боя, не перехватывающий клики.
- `game._clear_hud()` уничтожает слой; повторный `_create_hud()` пересоздаёт. Никакого per-frame combat-update внутри HUD сейчас нет, кроме `_update_hud()`.
- Per-frame драйвер боя — `scripts/main.gd:743-766` `_process(delta)`: при `combat_active` тикает таймер, спавнит волны, вызывает `ui._update_hud()`. Это единственная точка, откуда удобно дёргать обновление индикаторов каждый кадр.
- В HUD уже есть прецедент per-frame накладок (damage flash overlay, toasts) — стиль и `find_child` по имени узла используются повсеместно.

**Тесты.**
- `tests/ui_no_overlap_matrix_test.gd` — матрица не-перекрытия по `VIEWPORT_SIZES` (1152..3840, включая 1280x720 / 1600x900 / 2560x1440). Проверяет именованные узлы экранов на fit/overlap/overflow. Боевой HUD-оверлей индикаторов не должен ломать существующие проверки (он не должен перехватывать мышь и не должен «торчать» за вьюпорт сам по себе).

## Что сделать — по шагам

1. **Маркер «активной стрельбы» на враге (`scripts/enemy.gd`).**
   - Добавить поле `var _last_shot_time := -1000.0` (или таймер `var _active_fire_left := 0.0`).
   - В `_update_shooting()` после успешного выстрела (`enemy.gd:1099`, рядом с `_shoot_cooldown = fire_interval`) проставлять метку «недавно стрелял», например `_active_fire_left = fire_interval + 1.0` или `_last_shot_time = Time.get_ticks_msec() / 1000.0`.
   - Добавить публичный хелпер `func is_active_ranged_threat() -> bool`, возвращающий `true`, если `can_shoot and projectile_scene != null` и враг недавно стрелял (метка свежая, окно ~1.5–2.5 с). Боссы и элитки этот флаг не используют (для них достаточно ранга).
   - Добавить публичный хелпер `func threat_rank() -> String`, переиспользующий логику `_epic_scale_profile_id()`: вернуть `"boss"` / `"elite"` / `"ranged"` / `"" (none)`. Порядок приоритета: bosses → elite_enemies → активный ranged → none. melee без `can_shoot` → `""`.
   - Не дублировать классификацию: либо вынести общий приватный helper, который зовут и `_epic_scale_profile_id()`, и `threat_rank()`, либо `threat_rank()` строит ранг поверх `_epic_scale_profile_id()` + проверки `is_active_ranged_threat()`.

2. **Сервис индикаторов в HUD (`scripts/ui_screens.gd`).**
   - В `_create_hud()` (после `_create_damage_flash_overlay(root)`, ~`ui_screens.gd:7568`) создать контейнер `Control` с именем `OffscreenThreatIndicatorLayer`, `set_anchors_preset(PRESET_FULL_RECT)`, `mouse_filter = MOUSE_FILTER_IGNORE`, добавить в `root`. Пул маркеров (например `TextureRect`/`Control` со стрелкой + иконкой ранга) создавать лениво и переиспользовать (object pool), а не пересоздавать каждый кадр.
   - Реализовать `func _update_offscreen_threat_indicators() -> void`:
     - Если `not game.combat_active` или нет `game.current_player` — скрыть/обнулить пул и выйти.
     - Получить `viewport_size = game.get_viewport().get_visible_rect().size` и `canvas_xf = game.get_viewport().get_canvas_transform()`.
     - Собрать кандидатов: перебрать `get_tree().get_nodes_in_group("bosses")` и `"elite_enemies"` (всегда), плюс `"enemies"` с фильтром `is_active_ranged_threat()`. Дедуп по instance (босс/элитка могут быть и в `enemies`). Использовать `is_instance_valid()`.
     - Для каждого кандидата: `screen_pos = canvas_xf * enemy.global_position`. Если `screen_pos` внутри вьюпорта (с небольшим инсетом, например 24 px) — цель в кадре, маркер не нужен.
     - Если за кадром: посчитать точку пересечения луча `центр_экрана → screen_pos` с прямоугольником вьюпорта (с отступом ~`margin` от края, чтобы маркер не уезжал под рамку/за экран). Поставить маркер в эту точку, повернуть стрелку `rotation = (screen_pos - center).angle()`, выставить иконку ранга (boss/elite/ranged — три разных тинта/текстуры), сделать видимым.
     - Лишние маркеры пула — `visible = false`.
   - Ограничить число одновременных маркеров (например cap 6–8, сортировка по приоритету ранга и близости), чтобы не засорять экран при большом числе ranged.
   - Учесть `safe-area` рамки HUD: отступ `margin` от края экрана должен держать маркер в пустой зоне, а не на орнаменте рамки (правило frame-content safe-area из AGENTS.md).

3. **Per-frame драйвер (`scripts/main.gd`).**
   - В `_process(delta)` (`main.gd:760-761`, рядом с `ui._update_hud()`) добавить вызов `ui._update_offscreen_threat_indicators()` под условием `combat_active`. Дёргать каждый кадр — индикаторы должны плавно следовать за движущимися врагами и камерой.
   - Альтернатива (если важна производительность): троттлить до ~20–30 Гц, но для гладкости стрелок лучше каждый кадр; число кандидатов мало (боссы/элитки единичны, ranged — десятки максимум).

4. **Иконки/арт ранга.**
   - Нужны 3 визуала: стрелка-указатель + бейдж ранга (boss / elite / ranged). Если готовых ассетов нет — собрать из примитивов (Polygon2D/треугольник + тинт) или через `fantasydisk-asset-generator` (см. memory: вся графика — через этот скилл, прозрачный фон). Цветовая кодировка: boss — красный/багровый, elite — золотой/оранжевый, ranged — голубой/бирюзовый. Не блокировать задачу на арте: допустим программный плейсхолдер с TODO на полировку.

5. **Жизненный цикл.**
   - Маркер исчезает автоматически, когда цель в кадре (шаг 2) или мертва (выпадает из групп при `_die`, `enemy.gd:397-399`) или `combat_active = false`. Убедиться, что при `_clear_hud()` / `_end_combat()` пул не оставляет висящих узлов (он живёт внутри `hud_layer`, уничтожается вместе с ним — проверить, что нет внешних ссылок, удерживающих узлы).

6. **Тесты / smoke.**
   - `tests/ui_no_overlap_matrix_test.gd`: добавить (при необходимости) проверку, что `OffscreenThreatIndicatorLayer` и его маркеры имеют `mouse_filter = MOUSE_FILTER_IGNORE` и не считаются перекрывающими интерактив. Минимально — убедиться, что добавление слоя не ломает существующие no-overlap-проверки (слой full-rect, ignore-mouse).
   - Прогнать runtime smoke (Godot 4.6.3 headless, см. memory QA-runner) — старт боя с ranged-врагами и босс-файт, индикаторы появляются/исчезают, кликов по карте/бою не ломают.

## Acceptance Criteria

- [ ] Когда босс или элитка вне видимой области камеры — на краю экрана в их направлении рисуется стрелка/маркер с иконкой ранга (boss/elite различимы).
- [ ] Внеэкранные shooter/mage/spitter, **активно ведущие огонь** по игроку, получают временный маркер угрозы (ranged-иконка).
- [ ] Маркер исчезает, как только цель попадает в кадр **или** умирает; обычные melee-мобы маркерами экран не засоряют.
- [ ] Индикаторы живут в HUD `CanvasLayer` (`game.hud_layer` → `CombatHudRoot` → `OffscreenThreatIndicatorLayer`), `mouse_filter = MOUSE_FILTER_IGNORE`, не перехватывают клики, не ломают route-map / combat-клики.
- [ ] Корректно работает на 1280x720, 1600x900 и 2560x1440 с учётом camera-clamp (проекция через `get_canvas_transform()`, а не «игрок = центр экрана»).
- [ ] Маркеры держатся в пределах вьюпорта с отступом от края (safe-area рамки), не уезжают за экран и не наезжают на орнамент HUD-рамки.
- [ ] Число одновременных маркеров ограничено (cap), при толпе ranged экран не «ёлка».
- [ ] `ui_no_overlap_matrix_test.gd` зелёный; runtime smoke (старт боя + босс-файт) зелёный.
- [ ] При завершении боя / `_clear_hud()` маркеры и пул не оставляют висящих узлов и не пишут ошибок в лог.

## Files / точки входа

- `scripts/enemy.gd:11,15,23,35` (`can_shoot`, `fire_interval`, `desired_shooting_distance`, `_shoot_cooldown`) — основа архетип/ranged-классификации.
- `scripts/enemy.gd:148-156` `_epic_scale_profile_id()` — переиспользовать как источник ранга для нового `threat_rank()`.
- `scripts/enemy.gd:1080-1099` `_update_shooting()` — проставлять метку «недавно стрелял» после выстрела; добавить `is_active_ranged_threat()` и `threat_rank()`.
- `scripts/enemy.gd:397-399` `_die`/cleanup — подтверждает авто-снятие из групп (маркер гаснет сам).
- `scripts/boss.gd:40-42` — боссы в группе `bosses` (через `super()` уже в `enemies`); ранг `"boss"`.
- `scripts/ui_screens.gd:7553-7575` `_create_hud()` — создать `OffscreenThreatIndicatorLayer` в `CombatHudRoot`; реализовать `_update_offscreen_threat_indicators()` + пул маркеров рядом с HUD-кодом.
- `scripts/main.gd:743-766` `_process()` — вызвать `ui._update_offscreen_threat_indicators()` рядом с `ui._update_hud()` под `combat_active`.
- `scripts/main.gd:34-36` — `ARENA_SIZE`, `COMBAT_CAMERA_ZOOM` (контекст clamp).
- `tests/ui_no_overlap_matrix_test.gd:4-11` `VIEWPORT_SIZES` — матрица разрешений для гейта.

## Замечания / подводные камни

- **ANTI-COLLISION (locked paths):** `scripts/ui_screens.gd` — за Claude-контуром (см. memory: ui_screens.gd за Claude; lane задачи = `claude`, всё ОК). `scripts/progression_data.gd` тоже locked — **в этой задаче он не нужен**, не трогать. Не редактировать `EnemyShooter.tscn`/`EnemyMage.tscn`/`EnemySpitter.tscn` без необходимости (классификация — рантайм по `can_shoot`/группам, новых @export-полей в сцены добавлять не требуется).
- **Camera-clamp — главный подводный камень:** на краю арены центр кадра != позиция игрока. Нельзя считать игрока серединой экрана. Брать `screen_pos = get_viewport().get_canvas_transform() * enemy.global_position` и центр как `viewport_size * 0.5`. Это устойчиво к зуму и клэмпу одновременно.
- **«Активный огонь»** — у `can_shoot`-врага есть кайтинг (`enemy.gd:209-212`): он останавливается на `desired_shooting_distance` и стреляет. Если завязать маркер только на `can_shoot`, замаркируются и далёкие пассивные ranged. Поэтому критично окно «недавно выстрелил» (метка в `_update_shooting`), а не просто `can_shoot`.
- **`process_mode`:** `hud_layer.process_mode = PROCESS_MODE_ALWAYS` — слой обновляется даже на паузе; драйвер в `main._process` уже выходит при `get_tree().paused` (`main.gd:744-745`), так что на паузе индикаторы не дёргаются. Проверить, что замороженный кадр не оставляет неактуальных стрелок (опционально — скрывать на паузе).
- **Производительность:** перебор групп каждый кадр дёшев (боссы/элитки единичны), но при больших волнах ranged стоит ограничить cap и не создавать узлы в цикле — только переиспользовать пул.
- **Дедуп:** босс/элитка состоят и в `bosses`/`elite_enemies`, и в `enemies` — собирать в `Dictionary`/`Array` по instance, чтобы не рисовать двойной маркер.
- **Связанные тикеты / эпик:** Jira `epic` у тикета не проставлен (вернулся пустым) — если родительский эпик «боевой UX/HUD» существует, привязать при синке. Тематически рядом с боевыми HUD-задачами SCRUM-487 (combat block 2K coords) и общими HUD-доработками — координаты/safe-area рамки боевого HUD не нарушать.
- **Safe-area:** маркеры держать в пустой зоне фрейма боевого HUD (правило frame-content safe-area, AGENTS.md+qa_protocol). Отступ `margin` подобрать так, чтобы стрелка не наезжала на углы/орнамент рамки на всех трёх целевых разрешениях.
- **Не менять баланс/спавн:** задача чисто презентационная (read-only по геймплею врага, кроме добавления метки времени выстрела). Урон, кайтинг, спавн не трогать.
