# Таймеры боя: обычный 1 минута, Элитка/Босс — 5 минут «убей или проиграл»

Версия: 0.2.0 · Роль: backend · Контур: Claude · Приоритет: P1 · foma · Эпик: Бой, враги, боссы, события
Статус: done · Спринт: 0.2.0
Jira: SCRUM-785
Owner: Backend / Claude
Locked paths: scripts/main.gd (_process win/lose + round-duration консты); scripts/combat_director.gd (_start_combat/_end_combat/elite/boss)

## Что и зачем
Перебалансировать длительность боёв и условия победы/поражения:
- **Обычный бой** — длится **1 минуту** (первый бой = ровно 60с). Победа по
  истечении таймера (выжил = прошёл), как сейчас, но базовая длительность = 60с.
- **Бой с Элиткой** — таймер **5 минут (300с)**. Победа = **убить элитку** до
  истечения таймера. Если 5 минут прошли, а элитка жива → **поражение** (death screen).
- **Бой с Боссом** — таймер **5 минут (300с)**. Победа = убить босса. Если 5 минут
  прошли, а босс жив → **поражение**.

Зачем: сейчас босс без таймера (бесконечно до убийства), а элитка по таймауту даёт
«выживание = победа». Нужно напряжение: элитку/босса надо именно убить за 5 минут,
иначе ран проигран.

## Текущее состояние в коде
`scripts/main.gd`:
- Консты длительности раунда (≈23–25): `BASE_ROUND_DURATION = 30.0`,
  `ROUND_DURATION_STEP = 3.0` (на стадию), `ROUND_DURATION_MAX = 60.0`.
- `_process` (≈1090–1116): для НЕ-boss декрементит `round_time_left -= delta`.
  Условия завершения:
  - `if boss_combat_active and bosses.is_empty(): combat._end_combat(true)` — босс убит.
  - `elif not boss_combat_active and round_time_left <= 0.0: combat._end_combat(true)` —
    таймер вышел → победа (для обычного И для элитки, т.к. элитка идёт как не-boss).

`scripts/combat_director.gd`:
- `_current_round_duration()` (≈использует консты выше) — `min(30 + stage*3, 60) *
  round_duration_mult`.
- `_start_combat(is_boss_fight, combat_type)` (≈22–42): ставит
  `round_time_left = _current_round_duration()`, `boss_combat_active = is_boss_fight`,
  `current_combat_type` ∈ {"battle","elite","boss"}, `_elite_defeated = false`.
- Элитка идёт с `boss_combat_active = false`, `current_combat_type = "elite"`;
  `_elite_defeated` ставится в `_on_enemy_died()` (≈731) когда элитка умирает.
- `_end_combat(victory)` (≈117–190): при victory выдаёт награды; для элитки экран
  выбора артефакта только если `_elite_defeated`. Поражение (victory=false) →
  capture metrics + death screen.
- Босс спавнится `_spawn_boss()` (≈516), у boss-боя НЕТ декремента таймера.

## Что сделать — по шагам
1. **Обычный бой = 60с.** Сделать так, чтобы базовая/первая длительность обычного
   боя была 60с. Простейший путь: `BASE_ROUND_DURATION = 60.0` (и `ROUND_DURATION_MAX`
   ≥ 60). Проверить, что первый бой ран'а (act1, route_stage 0) даёт ровно ~60с.
   Решить, оставлять ли рост +3/стадию (можно оставить, но первый = 60с минимум).
2. **Ввести таймер 300с для элитки и босса.** Добавить отдельную длительность
   `ELITE_BOSS_ROUND_DURATION = 300.0` (5 минут). В `_start_combat` для
   `combat_type in {"elite","boss"}` ставить `round_time_left = 300.0` (с учётом
   ascension `round_duration_mult`, если применимо — но базово 300с).
3. **Таймер должен ТИКать и в боссе.** Сейчас босс-бой не декрементит таймер. Нужно
   декрементить `round_time_left` для elite И boss тоже (чтобы 5-минутный лимит
   работал). Аккуратно: оставить win-by-kill моментальной.
4. **Условия победы/поражения переписать в `_process`:**
   - Обычный бой (battle, не elite/boss): `round_time_left <= 0` → `_end_combat(true)`
     (выжил = победа) — как сейчас.
   - Элитка: убил элитку (`_elite_defeated`/нет живой элитки) → `_end_combat(true)`.
     Если `round_time_left <= 0` и элитка ещё жива → **`_end_combat(false)`** (поражение).
   - Босс: нет живых боссов → `_end_combat(true)`. Если `round_time_left <= 0` и босс
     жив → **`_end_combat(false)`** (поражение).
5. **Поражение по таймауту = корректный death screen.** Убедиться, что `_end_combat(false)`
   по таймауту проходит ту же ветку смерти (capture run metrics, outcome reason вроде
   «Не успел убить босса/элитку за 5 минут», death screen).
6. **Спавн в элитке/боссе на 5 минут.** Проверить, что за 300с спавн-логика не
   создаёт runaway: для босса спавн волнами обычно отключён (только босс+минионы),
   для элитки — поток врагов идёт 5 минут; убедиться что cap держит и нет утечки.
7. **HUD таймера.** Если на экране есть индикатор времени боя — он должен корректно
   показывать 60с / 5:00 и обратный отсчёт для elite/boss. (Если индикатора нет —
   отметить как возможный follow-up, не блокер.)
8. Прогнать smoke + combat/boss/elite гейты (один инстанс Godot, без runaway).

## Acceptance Criteria
- [ ] Первый (и обычный) бой длится ~60с; победа по истечении таймера (выжил = прошёл).
- [ ] Бой с элиткой: таймер 300с; убил элитку → победа с наградой-артефактом;
      таймер вышел и элитка жива → поражение (death screen).
- [ ] Бой с боссом: таймер 300с тикает; убил босса → победа; таймер вышел и босс
      жив → поражение (death screen) с понятным reason.
- [ ] Смерть по таймауту проходит штатную ветку (run metrics + death screen), не
      крашит и не зависает.
- [ ] Spawn за 5 минут не уходит в runaway (cap держит), гейты зелёные.

## Files / точки входа
- scripts/main.gd — консты round-duration (≈23–25); `_process` win/lose (≈1090–1116).
- scripts/combat_director.gd — `_current_round_duration`, `_start_combat` (выбор
  длительности по combat_type), `_end_combat` (ветка поражения), elite/boss setup.

## Замечания / подводные камни
- В одной волне с [[backend_combat_density_spawn_dynamic_task]] — общий main.gd/
  combat_director.gd; делать последовательно одним контуром, не параллелить.
- НЕ трогать route_map_screen.gd / route-консты — это контур route-задач
  ([[backend_route_8nodes_act_progression_secret_boss_task]]).
- Элитка идёт как `boss_combat_active=false` — следить, чтобы новое условие
  поражения по таймеру срабатывало именно для combat_type=="elite", а обычный
  battle по таймауту по-прежнему = победа.
- Ascension `round_duration_mult`: решить, применять ли к 300с (рекомендуется не
  уменьшать ниже разумного; зафиксировать решение в отчёте).
- main.gd на старте dirty — точечные правки, не затирать чужие хунки.

## QA-Вердикт
Статус: PASSED
Дата: 2026-06-30 · QA: claude-qa

Проверено на HEAD origin/dev (commit 36b05c66):
- Консты (main.gd): BASE_ROUND_DURATION 30→60, ROUND_DURATION_MAX 60→90,
  ELITE_BOSS_ROUND_DURATION=300 — обычный бой 60с база (+3/стадию до 90).
- `_current_round_duration` (combat_director.gd): elite/boss → фикс 300с БЕЗ round_duration_mult
  (стабильное окно убийства); обычный — base*mult.
- `_process` (main.gd): таймер тикает во ВСЕХ боях; босс — убит→победа / таймаут→поражение;
  элитка — is_elite_defeated()→победа / таймаут→поражение; обычный — таймаут→победа.
- `_end_combat`: ветка поражения по таймауту даёт outcome_reason («Не успел убить босса/элиту
  за 5 минут») + штатный death screen + capture_run_metrics_finals.
- Награда-артефакт элитки гейтится `_elite_defeated` (двойная защита).
- TTK-баланс: boss_elite_ttk_gate показывает elite TTK ~2.5-4.2с, boss ~4.6-9.7с (ускоренная
  модель) — глубоко внутри 300с-окна, ложных поражений по таймеру в нормальной игре нет.
- Гейты зелёные (один инстанс Godot): runtime_smoke_test PASS, runtime_smoke_combat_test PASS,
  runtime_smoke_boss_elite_test PASS, boss_elite_ttk_gate PASS.
