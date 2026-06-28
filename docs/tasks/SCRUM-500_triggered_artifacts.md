# SCRUM-500: Триггерные (активируемые событием) артефакты как новый класс предметов

Jira: SCRUM-500 · Роль: backend · Контур: claude · Приоритет: P1 · foma · Эпик: —
Статус: done (QA PASSED 2026-06-28; stale QA gate closed by Codex replacement loop)

## Что и зачем

Сейчас все 85 артефактов — это пассивные стат/мод-«палки»: +5 силы, +50% урона, +25% скорости движения и т.п. Выбор лута после элиток и в level-up ощущается однообразно: карточки отличаются только цифрами, нет момента «о, эта штука делает что-то новое в бою».

Цель — ввести новый под-класс **триггерных артефактов**: предметы с понятным игровым событием срабатывания (`on_low_hp`, `on_kill`, `on_crit`, `on_room_clear`, `on_take_hit`) и активным боевым эффектом. Добавить 6-8 таких предметов в общий пул наград, level-up и в пул наград элиток. Игрок должен видеть на карточке визуальную пометку «активный», чтобы отличать их от пассивных.

ВАЖНО: это **новый контент-слой поверх существующей системы `run_modifiers`**, без изменения глобального баланса DPS/TTD-гейтов. Эффекты — «специи», а не новый множитель урона. Survivability/DPS smoke-гейты должны остаться зелёными.

Ожидаемый результат: после элитки/level-up игрок периодически встречает артефакт с явной активной механикой (рывок-щит на низком HP, шанс взрыва на убийстве, бафф скорости на крите, лечение на зачистке волны), эффект читается визуально (VFX) и честно снимается при смерти/смене персонажа/выходе из забега.

## Текущее состояние в коде

В проекте УЖЕ есть несколько «псевдо-триггерных» эффектов, зашитых ad-hoc через флаги в `run_modifiers`. Их надо использовать как референс паттерна (НЕ дублировать, но и не ломать), а новые триггеры построить по единому формату.

### Данные артефактов
- `scripts/progression_data_content.gd:58-112` — `const ARTIFACTS` (52 записи). Формат записи:
  `{"id", "title", "tier", "cost", "class_affinity":[], "description", "stats"?, "mods"?, "affinity_mods"?}`.
  Тиры: tier 1 (cost 30), tier 2 (cost 55), tier 3 (cost 95).
- Уже существующие «активные» tier-3 артефакты (референс по тону/тиру):
  - `echo_core` (line 105): `"mods": {"echo_blast_every": 5.0}` — каждый 5-й удар = взрыв эха.
  - `blood_pact` (line 107): `"mods": {"low_hp_damage_bonus": 0.5}` — <30% HP даёт +50% урона.
  - `leech_heart` (line 108): `"mods": {"kill_heal_percent": 0.02}` — убийство лечит 2% max HP.
  - `thorn_pact` (line 109): `"mods": {"thorn_reflect_multiplier": 2.0}` — урон в ответ при получении удара.
  - `phantom_step` (line 110): `"mods": {"dodge_rush_bonus": 0.4}` — уворот даёт +40% скорости на 2с.

### Применение мод-флагов
- `scripts/player.gd:693-717` — `apply_reward(reward)`: раскладывает `stats`/`mods`/`affinity_mods`, добавляет в `artifacts` массив `{id,title}` при `kind=="artifact"`.
- `scripts/player.gd:720-725` — `_apply_reward_mods(mods)`: ключи на `_multiplier` множатся, остальные суммируются в `run_modifiers`. **Триггерные эффекты должны идти как суммируемые скаляры/флаги** (НЕ `_multiplier`), как `echo_blast_every`, `kill_heal_percent` и т.п.
- `scripts/player.gd:202-223` — run-start сброс базовых `run_modifiers` в `configure_character()`. Триггерных флагов тут нет (они появляются только при подборе артефакта) — это и есть «снятие при смене персонажа»: при новом `configure_character()` словарь пересоздаётся, любые триггер-флаги исчезают.

### Существующие триггер-хуки (точки, куда подключать новые триггеры)
- **on_take_hit / on_low_hp**: `scripts/player.gd:560-608` — `take_damage()`.
  - `_trigger_thorn_reflect(final_damage)` вызывается на line 590 (паттерн on_take_hit).
  - low-HP проверка `_update_low_hp_state()` (`player.gd:682-690`) — переключает `low_hp_active` по порогу `health < max_health * 0.3`. Вызывается из апдейта (найти вызов через grep `_update_low_hp_state`).
- **on_kill**: `scripts/combat_director.gd:667-685` — `_on_enemy_died(enemy)`. Здесь уже читается `kill_heal_percent` (line 677). Это ЕДИНСТВЕННАЯ центральная точка «враг умер». Доступ к игроку: `game.current_player`, к его флагам: `(game.current_player.get("run_modifiers") as Dictionary)`.
- **on_crit / on_hit**: `scripts/player.gd:785-799` — `on_weapon_hit(enemy, dealt_damage)`. Центральный per-hit хук (вызывается из `class_weapon.gd:1958` и `berserk_weapon.gd:178`). ВНИМАНИЕ: сюда сейчас НЕ передаётся флаг крита — есть только `dealt_damage`. Для честного `on_crit` нужно прокинуть `was_crit` (см. «Подводные камни»). `_on_weapon_hit_echo(enemy)` (`player.gd:1396-1413`) — образец «каждый N-й удар → взрыв».
- **on_room_clear / on_wave_clear**: `scripts/main.gd:750-766` — конец боя по `round_time_left <= 0.0` → `combat._end_combat(true)`. Спавн волн: `spawn_wave_index += 1` (`main.gd:755`). «Зачистка волны» как событие в явном виде НЕ существует — нет момента «все враги текущей волны мертвы». Самый близкий честный анкер — конец боя в `combat_director.gd:_end_combat(true, ...)` (line 116-119, ветка victory до снапшота). См. «Подводные камни» про выбор семантики on_room_clear.

### Эффекты-«рывок/щит/бафф» (референс реализации временных баффов)
- `scripts/player.gd:667-679` — `_trigger_dodge_rush()`: ставит `dodge_rush_active=1.0`, пересчитывает скейл, через `create_tween()` на 2с снимает флаг. **Это эталон временного баффа** с корректным снятием через tween. Tween хранится в `_dodge_rush_tween` и `.kill()`-ается перед перезапуском.
- VFX-хелперы: `AttackVfx.ring_pulse(parent, pos, radius, color, filled)`, `AttackVfx.orb_burst(...)`, `_show_heal_vfx()`. Звук: `_play_sfx("...")`.

### Cleanup-контракт `player_weapon_effects`
- `scripts/player.gd:322-328` — `_clear_detached_weapon_effects()`: проходит по группе нод `"player_weapon_effects"` и `queue_free()`-ит их. Вызывается из `_clear_equipped_weapon()` (`player.gd:304-319`).
- Любые **спавнящиеся в сцену ноды** триггер-эффекта (союзник/орбита/постоянный визуал) ОБЯЗАНЫ добавляться в группу `"player_weapon_effects"` (как ally на `player.gd:1129`), чтобы автоматически чиститься при смене оружия/персонажа. Эффекты на tween внутри игрока (как dodge_rush) умирают вместе с нодой игрока при `_end_combat` → `_clear_world()`.

### Пулы наград
- `scripts/progression_data.gd:896-909` — `reward_pool(character_id)`: включает все `ARTIFACTS` с `kind="artifact"` и `weight = TIER_WEIGHTS[tier]`. Новые триггерные артефакты попадут СЮДА автоматически просто фактом добавления в `ARTIFACTS`.
- `scripts/progression_data.gd:979-991` — `shop_items()`: тоже итерирует `ARTIFACTS` (автоподхват).
- `scripts/progression_data.gd:994+` — `elite_artifact_choices(route_stage, count)`: пул трофеев элитки, итерирует `ARTIFACTS` с tier-weight (автоподхват). Элитная карточка: `combat_director.gd:140-143` → `ui._show_elite_artifact_reward(...)`.
- `scripts/progression_data.gd:912-918` — `level_up_rewards()` берёт из `LEVEL_UP_REWARDS`, НЕ из `ARTIFACTS`. Если триггерные нужны в level-up как отдельные карточки — добавить туда записи с `kind:"upgrade"` + `mods:{<trigger_flag>}` (опционально, см. шаги).

### Карточка / визуальная пометка «активный» (locked path — только чтение)
- `scripts/ui_screens.gd:4301-4369` — `_make_battle_reward_card(reward)`, `:4372+` — `_make_elite_artifact_card(reward)`. Карточка читает `reward.get("title"/"description"/"kind")`, иконку через `_reward_icon_id` (`:5601-5611`), тир-цвет `_artifact_tier_color` (`:7828`), тир-текст `_artifact_tier_text` (`:7824`), чипы (`:2901`).
- Существует паттерн бейджа `★ ХАРАКТЕРИСТИКА` для `rare`-наград (`ui_screens.gd:4256-4263`). Пометку «активный» делать аналогично — **через данные, читаемые из reward dict** (см. «Подводные камни»: ui_screens.gd ЗАЛОЧЕН).

## Что сделать — по шагам

1. **Определить единый формат триггерного артефакта** в `scripts/progression_data_content.gd`. Добавить в запись `ARTIFACTS` поле-маркер и поле триггера. Рекомендуемый формат (минимально инвазивный, совместимый с `_apply_reward_mods`):
   - `"active": true` — маркер под-класса (для UI-пометки и фильтров).
   - `"trigger": "on_low_hp" | "on_kill" | "on_crit" | "on_room_clear" | "on_take_hit"` — семантика события (для UI-подписи и runtime-диспетчера).
   - Сам эффект — как суммируемый флаг в `mods` (НЕ `_multiplier`), напр. `"mods": {"lowhp_guard_shield": 1.0}`. Тогда `apply_reward`/`_apply_reward_mods` уже разложат его в `run_modifiers` без правок.
   - tier: новые триггерные ставить tier 2-3 (cost 55/95), `class_affinity: []` (доступны всем), как `echo_core`/`leech_heart`.

2. **Добавить 6-8 новых триггерных записей** в `const ARTIFACTS`. Минимум 6 ОБЯЗАТЕЛЬНЫ (по AC), покрыть ≥4 разных триггера. Предлагаемый набор (id-нейминг в стиле существующих):
   - `on_low_hp` — «Рубеж Стража»: при первом падении HP ниже 30% — рывок-нокбэк + краткий щит/неуязвимость (кулдаун, раз в N сек). Флаг `lowhp_guard`.
   - `on_kill` — «Цепная Искра»: шанс (напр. 12%) на убийстве вызвать взрыв по области у трупа. Флаг `kill_explosion_chance`.
   - `on_crit` — «Импульс Крита»: крит даёт +X% скорости движения на 1.5-2с (короткий бафф через tween, как dodge_rush). Флаг `crit_speed_burst`.
   - `on_room_clear` — «Передышка»: при завершении боя/зачистке волны лечит фикс. % max HP. Флаг `room_clear_heal_percent`.
   - `on_take_hit` — «Контр-волна»: получив удар, шанс выпустить отталкивающую волну/мини-щит. Флаг `take_hit_pulse_chance`.
   - +1-2 на выбор (напр. on_kill «Сбор душ»: каждое N-е убийство = временный +урон-стак; on_low_hp «Второе дыхание»: при низком HP +reg/защита).
   Сбалансировать значения консервативно: эффекты ситуативны, НЕ должны ломать TTD/DPS-гейты. Кулдауны/шансы обязательны для on_kill/on_crit/on_take_hit, иначе runaway.

3. **Реализовать runtime минимум 6 триггеров** и подключить к точкам:
   - `on_take_hit` и `on_low_hp` → в `scripts/player.gd` рядом с `take_damage()` (`:560-608`) и `_update_low_hp_state()` (`:682-690`). Для low_hp-guard добавить латч `_lowhp_guard_used`/кулдаун (как death_save — раз за порог/раз в N сек), VFX `ring_pulse`, краткую неуязвимость (`_damage_invulnerability_left`).
   - `on_crit` → прокинуть `was_crit` в `on_weapon_hit` (см. шаг 4) и реализовать `_trigger_crit_speed_burst()` по образцу `_trigger_dodge_rush()` (`:667-679`): флаг `*_active`, tween на снятие, пересчёт `_apply_stat_scaling`. Хранить tween в новом поле `_crit_burst_tween` и `.kill()` перед рестартом.
   - `on_kill` → в `scripts/combat_director.gd:_on_enemy_died()` (`:667`), рядом с `kill_heal_percent` (`:675-679`): прочитать новые флаги из `run_modifiers`, реализовать шанс-взрыв (по образцу `player.gd:_on_weapon_hit_echo` — урон по `TARGET_QUERY.in_radius` + `AttackVfx.orb_burst`). Урон взрыва считать от `derived_parameters.damage`, как echo.
   - `on_room_clear` → в `scripts/combat_director.gd:_end_combat(victory)` ветка `victory and current_player` (`:116-119`), ДО `_store_player_snapshot`: если есть флаг `room_clear_heal_percent` — `game.current_player.heal_percent(...)`. (Семантика «зачистка волны» = победа в бою; см. подводные камни.)
   - Все новые поля-латчи (`_lowhp_guard_used`, `_crit_burst_tween`, счётчики) объявить рядом с `_echo_hit_counter`/`_dodge_rush_tween` (`player.gd:170-174`) и сбрасывать в `configure_character()`/`_ready()`.

4. **Прокинуть флаг крита в on_weapon_hit** (нужно для `on_crit`). Сейчас `on_weapon_hit(enemy, dealt_damage)` не знает про крит. Крит резолвится в оружии/`_deal_typed_damage`. Варианты (выбрать наименее инвазивный):
   - (a) Добавить опциональный параметр `on_weapon_hit(enemy, dealt_damage := 0.0, was_crit := false)` и прокинуть `true` из вызовов в `class_weapon.gd:1958-1959` и `berserk_weapon.gd:178-179`, где крит уже известен.
   - (b) Если крит-флаг недоступен в месте вызова — резолвить вероятностно от `crit_chance` в самом `on_weapon_hit` (менее точно, но без правок оружия). Предпочесть (a), если крит-инфо рядом в коде оружия.

5. **Гарантировать cleanup-контракт**:
   - Любые спавнящиеся ноды эффекта → группа `"player_weapon_effects"` (чистятся в `player.gd:322-328`).
   - Tween-баффы (crit_burst, lowhp_guard) живут на игроке → гибнут при `_end_combat`/`queue_free`. Убедиться, что флаги `*_active` не «залипают» в снапшоте: проверить `_store_player_snapshot`/`_restore_player_snapshot` (combat_director) — если снапшот сериализует `run_modifiers` целиком, исключить временные `*_active`/латчи (или сбрасывать их при ресторе).
   - При `configure_character()` (смена персонажа) `run_modifiers` пересоздаётся (`player.gd:202`) — триггер-флаги исчезают автоматически. Добавить сброс новых non-run_modifiers латчей (`_lowhp_guard_used` и т.п.) туда же.

6. **Регистрация контента**:
   - `docs/design/content_registry.md` — в секцию артефактов (рядом с описанием `ProgressionData.ARTIFACTS`, line ~428) добавить список новых id/имён/триггеров/эффектов. Отметить, что это под-класс `active`.
   - `docs/design/mechanics_extract.md` — задокументировать формат триггерного артефакта (поля `active`/`trigger`), список триггеров и их runtime-анкеры.

7. **Визуальная пометка «активный» в карточке** (`ui_screens.gd` ЗАЛОЧЕН — менять только если задача явно выделит окно; иначе сделать data-driven):
   - Предпочтительно: вложить признак в `description`/`title` reward dict так, чтобы существующий рендер показал пометку без правок layout (напр. префикс «⚡ Активный — <триггер>: » в `description`). Тогда `_make_battle_reward_card`/`_make_elite_artifact_card` отрисуют её как есть.
   - Если требуется отдельный бейдж (как `★ ХАРАКТЕРИСТИКА`, `ui_screens.gd:4256-4263`) — это правка locked-файла: согласовать через anti-collision (см. подводные камни), либо вынести в отдельный sub-тикет на UI.

8. **Тесты**:
   - В `tests/runtime_smoke_progression_economy_test.gd` (или новый focused `tests/runtime_smoke_triggered_artifacts_test.gd`, наследник `runtime_smoke_test.gd`) добавить focused-проверку на КАЖДЫЙ триггер: применить артефакт через `current_player.apply_reward(...)`, сэмулировать событие (нанести смертельный/несмертельный урон для low_hp/take_hit; вызвать `_on_enemy_died` для on_kill; `on_weapon_hit(enemy, dmg, true)` для on_crit; `_end_combat(true)` для room_clear) и проверить наблюдаемый эффект (HP вырос / появилась нода эффекта / `run_modifiers["*_active"]` выставлен / враг получил урон).
   - Smoke `reward_pool().size()` уже проверяет ≥28 (`runtime_smoke_progression_economy_test.gd:15`) — новые артефакты только увеличат пул, гейт не сломают.

## Acceptance Criteria

- [ ] В `progression_data_content.gd` определён формат триггерного артефакта с полями `active`/`trigger` и эффектом-флагом в `mods`; реестр `docs/design/content_registry.md` обновлён id/именами всех новых предметов.
- [ ] Реализованы и подключены к runtime минимум 6 триггеров, покрывающих ≥4 разных события из набора `on_low_hp / on_kill / on_crit / on_room_clear / on_take_hit` (пример: low_hp → рывок-нокбэк-щит; kill → шанс взрыва; crit → короткий бафф скорости; room_clear → лечение).
- [ ] Триггерные артефакты выпадают из общего пула (`reward_pool`), level-up и наград элиток (`elite_artifact_choices`) наравне с обычными; имеют визуальную пометку «активный» в карточке (через данные reward или согласованную правку UI).
- [ ] Эффекты соблюдают cleanup-контракт `player_weapon_effects`: спавнящиеся ноды в группе `"player_weapon_effects"`; временные баффы/латчи снимаются при смене персонажа (`configure_character`), смерти и выходе из забега; временные `*_active`-флаги не залипают в снапшоте.
- [ ] Шанс/кулдаун заданы для on_kill/on_crit/on_take_hit (нет runaway-цепочек); значения консервативны.
- [ ] Глобальные survivability/DPS smoke-гейты остаются зелёными; добавлен focused-тест на срабатывание каждого триггера; полный runtime smoke проходит.

## Files / точки входа

- `scripts/progression_data_content.gd:58-112` — `const ARTIFACTS`: добавить 6-8 триггерных записей с `active`/`trigger`/`mods`.
- `scripts/player.gd:560-608` — `take_damage()`: подключить `on_take_hit`/`on_low_hp`-эффекты.
- `scripts/player.gd:667-690` — `_trigger_dodge_rush()` / `_update_low_hp_state()`: эталон временного баффа + low-HP латч; рядом добавить `_trigger_crit_speed_burst()` и low-HP-guard.
- `scripts/player.gd:693-725` — `apply_reward()` / `_apply_reward_mods()`: убедиться, что новые флаги корректно ложатся (суммируемые, не `_multiplier`).
- `scripts/player.gd:785-799` — `on_weapon_hit()`: прокинуть `was_crit`, диспетчеризовать `on_crit`.
- `scripts/player.gd:170-174, 202-223` — поля-латчи + run-start сброс.
- `scripts/player.gd:322-328` — `_clear_detached_weapon_effects()`: контракт группы для спавнящихся нод.
- `scripts/combat_director.gd:667-685` — `_on_enemy_died()`: подключить `on_kill`-эффекты рядом с `kill_heal_percent`.
- `scripts/combat_director.gd:107-119` — `_end_combat(victory)`: подключить `on_room_clear`-эффект (ветка victory).
- `scripts/class_weapon.gd:1958-1959`, `scripts/berserk_weapon.gd:178-179` — вызовы `on_weapon_hit`: прокинуть крит-флаг.
- `scripts/progression_data.gd:896-909, 979-991, 994+` — `reward_pool`/`shop_items`/`elite_artifact_choices`: автоподхват (правки не требуются, проверить).
- `docs/design/content_registry.md` (~line 428) и `docs/design/mechanics_extract.md` — реестр + формат.
- `tests/runtime_smoke_progression_economy_test.gd` или новый `tests/runtime_smoke_triggered_artifacts_test.gd` — focused-тесты.

## Замечания / подводные камни

- **LOCKED PATHS — anti-collision**: `scripts/ui_screens.gd` и `scripts/progression_data.gd` — залоченные/высококонтактные файлы. По возможности НЕ трогать их:
  - Пометку «активный» делать **data-driven** через `description`/`title` в reward dict (`ui_screens.gd` читает их как есть) — тогда правка `ui_screens.gd` не нужна.
  - Пулы (`reward_pool`/`shop_items`/`elite_artifact_choices`) подхватывают `ARTIFACTS` автоматически — правки `progression_data.gd` НЕ требуются. Если потребуется новый хелпер — добавлять минимально и согласованно.
  - Основная работа изолирована в `progression_data_content.gd` (данные), `player.gd` и `combat_director.gd` (runtime) — это безопасные зоны для этой задачи.
- **`on_room_clear` семантики НЕТ в явном виде**: нет события «все враги текущей волны убиты» (волны спавнятся по таймеру `spawn_cooldown`, бой кончается по `round_time_left`). Честный анкер — победа в бою (`_end_combat(true)`). Если нужна именно «зачистка волны» (момент, когда `get_nodes_in_group("enemies").is_empty()` в середине боя) — это потребует нового детектора в `main.gd:_process` (line 750-766) с защитой от мульти-срабатывания между волнами. Согласовать семантику до реализации; для MVP достаточно «победа в бою».
- **on_crit требует крит-флага**: `on_weapon_hit` сейчас не получает `was_crit`. Прокинуть из оружия (`class_weapon.gd`/`berserk_weapon.gd`) — там крит уже резолвится. Не резолвить крит заново в player, чтобы не было рассинхрона с фактическим уроном.
- **Runaway-защита**: `on_kill`-взрыв БЕЗ кулдауна/шанса может зацепить цепную реакцию (взрыв убивает → новый on_kill). Обязателен шанс (<1.0) ИЛИ кулдаун, и взрыв НЕ должен рекурсивно слать `_on_enemy_died` без ограничения. Сравнить с echo-blast (там счётчик каждый N-й удар — безопасно).
- **Снапшот игрока между узлами**: `combat_director._store_player_snapshot`/`_restore_player_snapshot` сериализуют состояние игрока между боями. Временные `*_active`-флаги (crit_burst_active, dodge_rush_active, low_hp_active) НЕ должны «застывать» в снапшоте как постоянный бонус. Проверить, что снапшот либо не тащит их, либо рестор их обнуляет. Это прямой риск тихого баланс-дрейфа.
- **Связанные тикеты/референс**: tier-3 «активные» (`echo_core`, `blood_pact`, `leech_heart`, `thorn_pact`, `phantom_step`) — уже работающий прецедент; новый формат должен быть с ними согласован (по-хорошему — ретро-пометить их `active:true`/`trigger:...` тоже, но это опционально и не ломать их текущую работу). SCRUM-503 (cap berserk hammer DPS runaway, недавний коммит) — пример того, как runaway-эффекты ловят на гейтах; быть аккуратным с DPS-вкладом on_kill/on_crit.
- **Балансовая нейтральность**: триггерные эффекты — ситуативные «специи». Прямой постоянный +damage/+attack_speed запрещён (это сместит DPS-гейт). Лечение/щит/мув-бафф/ситуативный бурст-урон — ок. После реализации прогнать survivability+DPS smoke и сверить, что TTD/TTK-гейты зелёные.
- **Godot 4.6.3 headless smoke**: тесты гонять как в `qa-test-runner` памяти (Godot.app в ~/Downloads, headless). Focused-тест на триггеры держать детерминированным: для шанс-эффектов либо мокать rng/seed, либо ставить шанс=1.0 в тестовом артефакте.

## QA-Вердикт (2026-06-28)
Статус: PASSED
Проверено: live Jira already had QA PASSED on 2026-06-28 against `origin/dev` commit `49e51e3c`, plus later backend re-verification against `620d8402`; replacement loop confirmed no active owner conflict and closed the stale QA gate.
Команды из Jira evidence: `tests/runtime_smoke_triggered_artifacts_test.gd` - PASS, `tests/global_survivability_balance_smoke_test.gd` - PASS, `tests/global_damage_balance_smoke_test.gd` - PASS, `tests/runtime_smoke_test.gd` - PASS, `tests/runtime_smoke_ui_test.gd` - PASS.
Покрытие: active/trigger artifact data, on_low_hp/on_kill/on_crit/on_room_clear/on_take_hit hooks, reward pool pickup, cleanup/reset contract, snapshot transient flag cleanup, DPS/TTD balance gates.
Баги: нет.
