# Боевая динамика: плотность, число и места спавна монстров с первых секунд

Версия: 0.2.0 · Роль: backend · Контур: Claude · Приоритет: P1 · foma · Эпик: Бой, враги, боссы, события
Статус: done · Спринт: 0.2.0
Jira: SCRUM-784
Owner: Backend / Claude
Locked paths: scripts/combat_director.gd; scripts/main.gd (WAVE_SETTINGS блок)

## Что и зачем
Сейчас бой раскачивается слишком медленно: первые волны мелкие (база 2 врага),
паузы между волнами длинные, спавнит с одного края арены. Игрок первые секунды
скучает. Цель — **сделать бой динамичным с первой секунды**: больше монстров на
экране, быстрее первые волны, спавн сразу с нескольких краёв, чтобы давление было
ощутимым немедленно, но без читерского спавна врага «в лицо» игроку.

Ожидаемый результат для игрока: запустил бой — экран сразу наполняется врагами с
разных сторон, движение и стрельба начинаются мгновенно, ощущается «движ».

## Текущее состояние в коде
`scripts/main.gd` — словарь `WAVE_SETTINGS` (≈строки 213–231) задаёт параметры волн:
- `base_spawn_count` = 2 — базовое число врагов в волне.
- `spawn_count_per_stage` = 1, `spawn_count_per_wave_step` = 1, `wave_step_size` = 3.
- `normal_spawn_limit` = 5 (лимит врагов за волну в обычном бою), elite/boss limit = 3.
- `base_active_cap` = 14, `active_cap_per_stage` = 5, `active_cap_per_wave_step` = 2,
  `max_active_cap` = 30 — потолок одновременных врагов.
- `spawn_pause_min/max` = 1.35 / 2.15 c — пауза между волнами (обычный бой).
- `boss_spawn_pause_min/max` = 2.0 / 3.2 c.
- `first_wave_boost` — множитель плотности первой волны (×1.5 при wave_index ≤ 1).

`scripts/combat_director.gd`:
- `_spawn_enemy_wave()` (≈344–390) — оркестратор волны: считает raw_count из
  WAVE_SETTINGS, применяет ascension density mult и first_wave_boost, режет по лимиту.
- `_active_enemy_cap()` (≈392–401) — потолок одновременных врагов.
- `_next_spawn_cooldown()` (≈404–410) — интервал до следующей волны (с wave_pressure).
- `_choose_wave_spawn_edges()` (≈413–426) — выбор краёв арены (0 top..3 left). Обычно
  1 край; 2 края при stage≥2 / boss / elite / wave_index≥4.
- `_random_spawn_position()` (≈867–872) — координаты спавна; есть `SPAWN_EDGE_PADDING`
  (72px) и player safe radius 420px.
- `_start_combat()` (≈22–42) сбрасывает `spawn_wave_index=0`, `spawn_cooldown=0`.

## Что сделать — по шагам
1. **Мгновенный старт боя.** Первая волна должна выходить почти сразу: в
   `_start_combat()` (или при первой итерации) сделать стартовый `spawn_cooldown`
   очень коротким (≈0.1–0.2с), а не полноценную паузу — чтобы экран наполнялся в
   первую секунду. Убедиться, что `_spawn_enemy_wave()` срабатывает на первом тике.
2. **Больше врагов с первых волн.** Поднять `base_spawn_count` (2 → ~4) и/или
   усилить `first_wave_boost`, чтобы первые 1–2 волны были крупнее. Поднять
   `normal_spawn_limit` (5 → ~8), чтобы плотность реально росла. Значения подбирать
   так, чтобы на экране держалось заметно больше врагов, но играбельно.
3. **Выше потолок одновременных врагов на ранней стадии.** Поднять `base_active_cap`
   (14 → ~20) с сохранением разумного `max_active_cap` (можно 30 → 36), чтобы ранние
   бои не упирались в низкий cap.
4. **Короче паузы между волнами.** Снизить `spawn_pause_min/max` (1.35/2.15 →
   ~0.8/1.4), чтобы волны шли плотнее, особенно в начале.
5. **Спавн с нескольких краёв сразу.** В `_choose_wave_spawn_edges()` сделать так,
   чтобы уже с первой волны спавнило минимум с 2 краёв (а на поздних — до 3–4),
   создавая ощущение окружения. Сохранить избегание спавна вплотную к игроку
   (player safe radius) и за краем экрана.
6. **Не ломать боссов/элиток.** Менять плотность только для обычного боя; для boss
   оставить отдельные boss-параметры (минимум изменений), для elite — лёгкое
   усиление допустимо, но эта задача про обычные бои. Логику победы/таймера НЕ
   трогать (это отдельная задача [[backend_combat_timer_elite_boss_killtimer_task]]).
7. Прогнать smoke-тесты (`tests/runtime_smoke_test.gd` и связанные combat/pool-гейты),
   убедиться что нет runaway-спавна и просадок (см. pool_dot_gate — гонять headless
   по одному инстансу Godot).

## Acceptance Criteria
- [ ] В первую ~1 секунду боя на арене уже несколько врагов (визуально динамично).
- [ ] Базовое число врагов в волне и потолок одновременных врагов увеличены; на
      экране ощутимо плотнее, чем сейчас, но без зависаний/runaway.
- [ ] Паузы между волнами короче; волны идут чаще, особенно ранние.
- [ ] Спавн идёт минимум с 2 краёв арены уже с первой волны; враги не появляются
      вплотную к игроку и не за пределами арены.
- [ ] Боссовый бой по плотности/спавну существенно не изменился (отдельный контур).
- [ ] Smoke/combat/pool гейты зелёные (один инстанс Godot, без runaway).

## Files / точки входа
- scripts/main.gd — `WAVE_SETTINGS` (≈213–231): base_spawn_count, normal_spawn_limit,
  active_cap, spawn_pause_*, first_wave_boost.
- scripts/combat_director.gd — `_start_combat` (стартовый cooldown), `_spawn_enemy_wave`,
  `_active_enemy_cap`, `_next_spawn_cooldown`, `_choose_wave_spawn_edges`,
  `_random_spawn_position`.

## Замечания / подводные камни
- `scripts/main.gd` — общий hot-файл; правит ТОЛЬКО эта/смежная combat-задача в данной
  волне, НЕ редактировать одновременно с route-задачами. Менять только блок WAVE_SETTINGS.
- Эта задача в одной волне с [[backend_combat_timer_elite_boss_killtimer_task]] —
  делать последовательно одним контуром (общие файлы main.gd/combat_director.gd).
- Pool/DoT гейты дают ложный runaway при параллельных Godot — гонять по одному
  (pkill сначала). См. правило о godot single-instance.
- Не спавнить врагов в player safe radius (420px) — сохранить проверку.
- Файл main.gd на старте уже dirty (рабочее состояние dev) — делать точечные правки,
  не затирать чужие хунки.

## QA-Вердикт
Статус: PASSED
Дата: 2026-06-30 · QA: claude-qa

Проверено на HEAD origin/dev (commit 36b05c66):
- `WAVE_SETTINGS` (scripts/main.gd): base_spawn_count 2→4, normal_spawn_limit 5→8,
  base_active_cap 14→20, max_active_cap 30→36, spawn_pause 1.35/2.15→0.8/1.4 — соответствует спеке.
- `_start_combat` (combat_director.gd): стартовый spawn_cooldown=0.1 → первая волна почти мгновенно.
- `_choose_wave_spawn_edges`: минимум 2 края всегда, элитка 2-3, обычный бой до 3-4 на поздних
  стадиях/волнах; player safe radius (420px) и edge padding сохранены — нет спавна в лицо/за краем.
- Боссовый контур плотности существенно не изменён (edge_count=2, отдельные boss-параметры).
- Caps жёстко ограничены (max 36) → runaway невозможен.
- Гейты зелёные (один инстанс Godot): runtime_smoke_test PASS, runtime_smoke_combat_test PASS,
  runtime_smoke_boss_elite_test PASS, boss_elite_ttk_gate PASS.
