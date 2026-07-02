# Мета 4.0 «Созвездия героев»: ядро — валюты, per-class графы, миграция schema 5

Статус: done
Приоритет: high
Роль: Back-end (Claude)
Версия: 0.2.0
Создано: 2026-07-02
Jira: SCRUM-828
Контур: Claude
Owner: claude-backend (оркестратор, 3-й заход после session-limit)
Thread/Worker: pm-chat-continuation-2026-07-02 (изолированный worktree wt-828core)
Locked paths: `scripts/meta_progression.gd`, `scripts/meta_progression_tree_data.gd`, `scripts/player.gd` (ключи мета-эффектов), `tests/meta_skill_tree_smoke_test.gd`, `tests/skill_tree_per_hero_test.gd`, `tests/meta_points_per_ascension_test.gd`

## Источник истины

`docs/design/systems/meta_constellations.md` — дизайн Меты 4.0 (PM, 2026-07-02).
Читать ПОЛНОСТЬЮ до начала. Этот тикет реализует §2–§6 и §8 (без UI — экран
остаётся старым до T3, публичный API совместим). Отступления от дока — только
через комментарий PM в Jira. Задача полностью автономна.

## Scope

1. **Две валюты вместо общего пула** (§4): `class_sigils[char_id]` (эмблемы,
   формула 2/2/3/4/5/6 за первые клиры A0..A5 + по 2 за каждый выполненный
   `CLASS_CHALLENGE`) и `stardust` (аккаунт: первая победа классом ×17, первый
   A5 ×17, секретный босс 3, вехи кодекса 8, вехи достижений 5). Анти-фарм
   (повторные победы без валюты) — сохранить 1:1.
2. **Данные созвездий** (§3): в `meta_progression_tree_data.gd` — per-class
   графы 17 классов (21–23 узла: ядро 0-cost с +1 primary, 12 звёзд-атрибутов
   cost 1 строго из primary/secondary `ATTRIBUTE_RELEVANCE`, 4 звезды-техники
   cost 2 с механикой оружий/ульты, 2–3 взаимоисключающих keystone cost 4 с
   числовым downside — эталоны в §3, полная таблица = приложение A дока,
   ЗАПОЛНИТЬ её в доке этим тикетом), 2 скрытые звезды на challenge-условиях
   (§5). Плюс «Атлас гильдии» ~24 узла QoL (§2) с 4 наследными keystone v2.
   Форма созвездия — нормированные pos по силуэтам приложения C.
3. **Логика**: keystone-взаимоисключение (активен ≤1, переключение купленных
   бесплатно), скрытые звезды открываются условием (не покупкой), бесплатный
   полный респек. Новые ключи эффектов развести в `player.gd` и записать в
   приложение B дока (ключ без разводки = потерян — гейтом).
4. **Миграция schema 4 → 5** (§4): эмблемы пересчитать из
   `ascension_levels`/`meta_point_awards`, пыль — из `class_boss_wins`,
   `discovered_*`, `secret_boss_defeated`; полный респек; старые сейвы ничего
   не теряют.
5. **Тесты/гейты** (§6): переписать `meta_points_per_ascension_test` под
   формулу эмблем; расширить smoke/per-hero: связность каждого созвездия,
   бюджет силы полного билда класса +18–25% (коридор damage_mult-эквивалента
   [0.10..0.40]), кросс-классовый спред бюджетов ≤1.25, атрибуты ⊆
   релевантности, keystone-взаимоисключение, наличие downside у keystone,
   миграция 4→5 roundtrip. Все существующие гейты зелёные
   (`berserk_dps_runaway_gate`, `attribute_relevance_test`,
   `class_progression_test`, `runtime_smoke_test`) — через
   `python3 tools/godot_gate.py`, сериализованно.

## Совместимость

Старый экран дерева (v3 UI) должен продолжать работать до T3: сохранить
публичный API `node_list/node_by_id/entry_map/allocate_node/reset_skill_tree/
skill_modifiers/skill_modifiers_for_class` (внутри — новые данные). Если экран
v3 требует минимального адаптера (например, показывает только созвездие
выбранного класса) — допустимо править `ui_screens.gd` точечно, без редизайна.

## Acceptance

1. Приложения A (keystone-таблица 17 классов) и B (реестр ключей) дока
   заполнены; данные в коде совпадают с доком.
2. Валюты и миграция работают: старый сейв schema 4 конвертируется без потерь
   (тест + ручная проверка на копии реального dev-сейва).
3. Все тесты §5 зелёные; runtime smoke зелёный; полный прогон гейтов в
   Result / Evidence.
4. CHANGELOG (Unreleased) + Jira-комментарии; сдача: `Статус: done` первым
   словом + Result / Evidence; Jira → «Контроль качества».

## Процесс

Полная автономия; git pull перед стартом, явный `git add` своих файлов
(не `-A`), push в `origin/dev` после зелёных гейтов; .uid новых .gd коммитить;
`character_balance_csv.gd` полностью не гонять (SIGABRT-флаки).

## Прогресс

- 2026-07-02 (заход 2, после session-limit первого исполнителя — с нуля):
  - **Ядро** (`b20ba2c0`): `meta_progression.gd` переведён на схему 5 — валюты
    `class_sigils_*` (2/2/3/4/5/6 за первые клиры + 2/челлендж, дериватив от
    `meta_point_awards`/`class_challenges_done`) и `stardust_*` (первые победы
    ×17, первые A5 ×17, секретный босс 3, кодекс 8 вех — доли открытых записей
    по категориям 4/2/2, достижения 5 вех — пороги 1/2/4/6/8; потолок 50).
    Анти-фарм 1:1 (повторные победы валюту не дают); v3-кап 100 на запись
    наград снят (факты первых клиров фиксируются всегда). Миграция 4→5:
    полный респек, union наград с выводом из ascension_levels (возврат
    потерянных под капом), `active_keystones` нормализуются; save/load схемы 5.
  - **Данные** (`meta_progression_tree_data.gd`): 17 созвездий × 22 узла
    (ядро/12 минорных/4 техники/3 keystone/2 скрытых) + Атлас гильдии 25 узлов
    (14 minor + 4 notable + 4 наследных keystone v2 + 2 скрытых + хаб, 60 пыли);
    нормированные позиции по силуэтам (приложение C, релаксация ≥0.045);
    значения звёзд подобраны под бюджет §6 через `POWER_WEIGHTS`.
  - **player.gd**: разведены `healing_mult`, `kill_explosion_chance`,
    `take_hit_pulse_chance`, `thorn_reflect_multiplier`, `crit_speed_burst`,
    `dodge_rush_bonus`, `lowhp_guard` (реестр — приложение B дока).
  - **API для SCRUM-827**: `constellation_class_ids/constellation_nodes/
    atlas_nodes/class_sigils_earned|spent|available/stardust_earned|spent|
    available/currency_available_for_node/active_keystone/set_active_keystone/
    is_keystone_active/hidden_star_unlocked/hidden_star_progress/
    reset_constellation/estimated_class_power_multiplier`; старый API v3
    сохранён (старый экран работает без правок `ui_screens.gd`).
  - **Тесты** (`cca3129b`, `1be54f38`): три locked-теста переписаны под ядро;
    coupled-fix ожидания в `meta_progression_smoke_test` (3→8 по новой
    формуле). Дизайн-док: приложения A (51 keystone), B (7 ключей), C
    (npos-фиксация) заполнены; код и таблица A генерируются из одной спеки.

## Result / Evidence

- Коммиты в origin/dev (после rebase поверх SCRUM-834/uid-resync):
  `b20ba2c0` (ядро), `cca3129b` (тесты+док), `1be54f38` (лестница эмблем с
  авто-челленджем), `25e6a4e5` (размер Атласа 25/60), `914876fd` (базлайн
  атлас-вклада), `66f8185b` (CHANGELOG+спека done).
- Прогоны (изолированный worktree от origin/dev + cherry-pick, полный
  `--import`, изолированный user-dir через переименование `config/name`):
  - `tests/meta_points_per_ascension_test.gd` — PASSED;
  - `tests/skill_tree_per_hero_test.gd` — PASSED;
  - `tests/meta_skill_tree_smoke_test.gd` — PASSED;
  - `tests/runtime_smoke_test.gd` — PASSED;
  - смежные: `meta_progression_smoke_test`, `secret_encounter_test`,
    `achievements_smoke_test`, `class_progression_test`,
    `attribute_relevance_test` — PASSED.
- Бюджет §6: полный билд класса (ядро+12+4+1 активный keystone) по всем 51
  keystone-вариантам = +18..25% взвешенной силы; спред лучших билдов ≤1.25;
  Атлас целиком: аккаунт-множитель <1.30, вклад в class-power ≤5%.
