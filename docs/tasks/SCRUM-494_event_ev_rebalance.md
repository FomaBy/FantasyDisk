# SCRUM-494: EV-ребаланс наград событий: таблица risk/cost -> reward

Jira: SCRUM-494 · Роль: backend (balance) · Контур: claude · Приоритет: P1 · foma · Эпик: SCRUM-476 (carry-over)
Статус: Готово (QA PASSED 2026-06-27)

> QA-Вердикт: **PASSED** (2026-06-27). Прогнаны headless (Godot 4.6.3):
> runtime_smoke / event_data_smoke (12 событий) / progression_economy /
> live_balance_simulation / global_damage_balance / global_survivability —
> все зелёные. Сверены все acceptance: таблица EV покрывает 12 событий / 27
> опций и совпадает с полями `event_data.gd`; `full_rest` без бесплатной
> Выносливости (штраф 1.25); множители elite-боя честно применяются в
> `combat_director`; `post_combat` прокидывается и для choice-level, и для
> nested `random_outcomes` (dig); тултипы синхронизированы. Расхождений нет.
> Переведено в Jira «Готово».

> ВАЖНО ДЛЯ ИСПОЛНИТЕЛЯ. Дев-часть этой задачи **уже выполнена и закоммичена** —
> коммит `1e131f8a feat(SCRUM-494): EV-ребаланс наград событий + честные множители
> elite-боёв`. Изменены `scripts/event_data.gd`, доку `docs/design/systems/progression_balance.md`
> (раздел «Random Events EV (SCRUM-494)») и `CHANGELOG.md`. Тикет сейчас в колонке
> «Контроль качества». Поэтому актуальная работа по тикету — **QA-верификация уже
> залитого изменения**, а НЕ новая реализация с нуля. Раздел «Что сделать — по шагам»
> ниже описан как QA-чек-лист. Не переделывай реализацию заново; если QA найдёт
> расхождение — точечный фикс + переоткрытие статуса (см. «Замечания»).

## Что и зачем

Случайные события (`?`-ноды на карте маршрута) — это микро-решения «риск/цена →
награда» между боями. До ребаланса EV опций был перекошен: безопасные/бесплатные
опции давали слишком много, а рискованные/платные — слишком мало, из-за чего у
игрока не было причины рисковать. Конкретные перекосы из тикета:

- `cursed_altar/defile` — гарантированный элитный бой (самый дорогой по риску
  исход в наборе) давал лишь +50% золота / +25% XP, и при этом денежный
  множитель elite-ветки **молча игнорировался** в коде (тултип врал).
- `hot_spring/full_rest` — полный хил + бесплатно +1 Выносливость за смешной штраф
  (+20% живучести врага в одном бою): безопасная опция доминировала риск-опции.
- `goblin_lottery` / `heroes_graveyard` — рандомные исходы: либо артефакт, либо
  «хлам»/мимик, разброс EV непрозрачен, вход дорогой.

Цель: свести EV каждой опции каждого события к явной формуле
`EV = P(успех) × награда − стоимость/штраф` (в gold-value, GV), выровнять так,
чтобы **рискованные/платные опции имели заметно более высокий апсайд**, а
**безопасные — скромную гарантию**, при этом не разбалансировать экономику забега
и сохранить разнообразие наград (статы / артефакты / run-long моды / хил / золото
/ бои — не всё сведено к золоту). Ожидаемый игровой результат: осмысленный выбор
на `?`-нодах, честные тултипы, прозрачная для дизайнера таблица EV в доке.

## Текущее состояние в коде (что уже залито)

Данные событий: `scripts/event_data.gd` — `const RANDOM_EVENTS` (12 событий,
строки 3–115). Каждое событие: `id`, `title`, `story`, `choices[]`. Опция несёт
плоские поля-эффекты: `cost_money`, `money`, `stats`, `mods`, `heal_percent`,
`random_artifact`, `health_percent_cost`, `random_outcomes[]`, `risk`, `check`
(+ `success`/`failure`-ветви), `combat` (+ `post_combat`).

Применение опций (UI-слой) — `scripts/ui_screens.gd`:
- `_apply_event_choice` (стр. 5261) — инстансит temp-player, восстанавливает
  снапшот забега, резолвит исход, применяет к игроку, при `combat`-исходе кладёт
  payload в `game.pending_event_combat` (с `post_combat`) и стартует бой.
- `_resolve_event_choice_outcome` (стр. 5289) — раскрывает `random_outcomes`
  (равновероятный выбор) и `check` (passed = `stat >= difficulty`, merge
  `success`/`failure`).
- `_apply_event_outcome_to_player` (стр. 5308) — honored поля: `cost_money`
  (через `stage_scaled_cost`), `money`, `reward`, `stats`/`mods`/`heal_percent`
  (через `apply_reward`), `random_artifact` (weighted sample из `reward_pool`),
  `health_percent_cost`.
- `_event_choice_scaled_cost` (стр. 5241) — `cost_money` масштабируется
  `PROGRESSION_DATA.stage_scaled_cost`.

Награды боя-исхода — `scripts/combat_director.gd::_grant_combat_completion_rewards`
(стр. 866–886). База: `elite` → `xp=7+stage×2`, `money=10+stage×4`; `battle` →
`xp=3+stage`, `money=4+stage×2`. **Ключевая правка коммита**: `xp_multiplier` и
`money_multiplier` из event-боя теперь применяются к ОБЕИМ веткам (раньше elite
их игнорировал — стр. 880–882), а `post_combat` применяется после боя
(стр. 885–886). `enemy_health_multiplier` — в `_run_enemy_health_multiplier`
(стр. 938–946).

Экономика для сверки EV — `scripts/progression_data.gd` / `progression_data_balance.gd`:
- `stage_scaled_cost(base, stage)` = `ceil(base × stage_scale(stage) × 1.10)`,
  `ECONOMY_PRICE_MULTIPLIER=1.10`, `stage_scale` = `1.18^stage + 0.075×stage`.
- `COST_BY_TIER = {1:30, 2:55, 3:95}`, `TIER_WEIGHTS = {1:1.0, 2:0.45, 3:0.12}` →
  взвешенная цена артефакта ≈ 45 зол (база GV для `random_artifact`).
- `reward_pool(character_id)` — артефакты взвешены по тиру; `random_artifact`
  тянет 1 через `_weighted_sample`.
- Атрибут в лавке атрибутов: `ATTRIBUTE_BUY_BASE_COST=18` → stage0 ≈ `ceil(18×1.10)`
  ≈ 20 зол → 1 стат ≈ 20 GV.

Доку с целевой таблицей EV: `docs/design/systems/progression_balance.md`, раздел
**«Random Events EV (SCRUM-494)»** (стр. 99–155) — шкала GV + полная таблица по
всем 25 опциям. `CHANGELOG.md` (стр. 129–143, секция Unreleased/0.1.7) — запись.

Смоук-тест: `tests/event_data_smoke_test.gd` — структурная валидация (валидные
статы, ветви check, типы боя, диапазоны `heal_percent`/`health_percent_cost` ∈
(0,1], неотрицательные деньги, валидность `post_combat.stats`). Балансовую EV как
таковую он НЕ считает — это намеренно (числа сверяются глазами по таблице доки).

## Что сделать — по шагам (QA-верификация залитого изменения)

1. **Сверить event_data.gd ↔ таблицу доки.** Пройти все 12 событий /
   25 опций в `scripts/event_data.gd` и сверить фактические поля с таблицей
   «Random Events EV» в `progression_balance.md` (стр. 122–150). Точечно
   убедиться в ключевых правках из CHANGELOG:
   - `full_rest` (стр. 66): только `heal_percent: 1.0` + `mods.enemy_health_multiplier: 1.25`
     — БЕЗ `stats.endurance` (бесплатная Выносливость убрана), штраф 1.20→1.25.
   - `defile` (стр. 20) и `mirror/duel` (стр. 75): elite-`combat` с
     `money_multiplier` (1.5 / 1.3) и `post_combat` со статами — теперь честные.
   - `goblin_lottery/buy_bag` (стр. 57): `cost_money: 12`, «хлам» = `money: 8`
     (был 3), исходы `random_artifact`/`money:8`/`combat`.
   - `well/throw_coin`, проверочные опции (`*/failure` дают консолацию).
2. **Прогнать смоуки headless** (Godot 4.6.3 в `~/Downloads/Godot.app`):
   - `tests/event_data_smoke_test.gd` — структура событий (должен напечатать
     `Event data smoke test passed (12 событий).`).
   - `tests/runtime_smoke_progression_economy_test.gd` — экономика забега не
     разъехалась.
   - `tests/live_balance_simulation_test.gd`,
     `tests/global_damage_balance_smoke_test.gd`,
     `tests/global_survivability_balance_smoke_test.gd` — общий баланс зелёный.
   Команда-образец:
   `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/event_data_smoke_test.gd`
3. **Проверить честность множителей elite-боя в коде** —
   `combat_director._grant_combat_completion_rewards` (стр. 880–882): множители
   применяются и к `elite`, и к `battle`; `post_combat` (стр. 885–886) применяется.
4. **Проверить синхронность тултипов** — `description` каждой опции в
   `event_data.gd` соответствует фактическим числовым эффектам (ни один тултип не
   обещает то, чего код не делает).
5. **Свести вердикт.** Если всё сходится — PASSED: прогнать
   `tools/jira_board_sync.py` (PASSED → «Готово»). Если расхождение — точечный
   фикс соответствующего поля в `event_data.gd` (и/или строки таблицы в доке),
   переоткрыть статус (.md + Jira, не только метки), повторить смоуки.

## Acceptance Criteria

- [ ] Для каждой опции каждого из 12 событий есть явная таблица risk/cost → reward
      с EV (раздел «Random Events EV» в `progression_balance.md`, стр. 122–150) —
      и она соответствует фактическим полям `event_data.gd`.
- [ ] Рискованные/платные исходы (`defile`, `duel`, `blood_price`, `take_shard`,
      `dig`, `buy_bag`, combat-ветки) дают заметно более ценную награду; безопасные
      (`walk_away`, `quick_dip`, `pay_respects`, `loot`) — скромную гарантию.
- [ ] Экономика забега не разбалансирована: значения сверены против
      `stage_scaled_cost` / `COST_BY_TIER` / `TIER_WEIGHTS` /
      `DROP_CLASS_MULTIPLIERS`; крупного плоского `money` на риск-опциях нет
      (плоское золото не масштабируется со стадией, в отличие от `cost_money`).
- [ ] Сохранено разнообразие исходов: в наборе остаются статы, артефакты, моды,
      хил, золото и бои — не всё сведено к золоту.
- [ ] `full_rest` больше НЕ даёт бесплатно полный хил + Выносливость; штраф
      следующему бою 1.25 (было 1.20), Выносливость убрана.
- [ ] Денежный/XP-множитель event-боя честно применяется и к elite-ветке в
      `combat_director._grant_combat_completion_rewards` (тултипы `defile`/`duel`
      больше не врут); `post_combat` применяется после боя.
- [ ] Тултипы (`description`) в `event_data.gd` синхронизированы с фактическими
      эффектами всех полей.
- [ ] `event_data_smoke_test.gd` + economy/runtime + балансные смоуки зелёные
      (headless).
- [ ] `docs/design/systems/progression_balance.md` и `CHANGELOG.md` обновлены
      (уже сделано — проверить актуальность и точность чисел).
- [ ] Статус в Jira синхронизирован с вердиктом (`jira_board_sync.py`).

## Files / точки входа

- `scripts/event_data.gd:3` — `RANDOM_EVENTS` (12 событий / 25 опций); источник
  правды по числам. Менять только при найденном расхождении (точечно).
- `scripts/ui_screens.gd:5261` — `_apply_event_choice`; `:5289`
  `_resolve_event_choice_outcome`; `:5308` `_apply_event_outcome_to_player`;
  `:5241` `_event_choice_scaled_cost`. ЧИТАТЬ для верификации honored-полей;
  файл в locked-paths (см. ниже) — не трогать без явной нужды.
- `scripts/combat_director.gd:866` — `_grant_combat_completion_rewards`
  (множители elite-ветки + `post_combat`). Проверить логику.
- `scripts/progression_data.gd:364` — `stage_scaled_cost`; `:896` `reward_pool`.
  ЧИТАТЬ для сверки экономики; файл в locked-paths — не трогать.
- `scripts/progression_data_balance.gd:178-199` — `STAGE_SCALE_*`,
  `ECONOMY_PRICE_MULTIPLIER`, `COST_BY_TIER`, `TIER_WEIGHTS`,
  `DROP_CLASS_MULTIPLIERS`. ЧИТАТЬ для GV-шкалы.
- `docs/design/systems/progression_balance.md:99` — раздел «Random Events EV
  (SCRUM-494)» с таблицей. Обновлять при правках чисел.
- `CHANGELOG.md:129` — запись Unreleased/0.1.7. Обновлять при правках.
- `tests/event_data_smoke_test.gd` — структурный смоук; при добавлении/правке
  опций гонять.

## Замечания / подводные камни

- **Дев-часть уже сделана (коммит `1e131f8a`).** Не реализуй заново. Текущий
  актуальный объём — QA-верификация + точечные фиксы при расхождении.
- **Anti-collision / locked paths:** `scripts/ui_screens.gd` и
  `scripts/progression_data.gd` — заблокированные пути (закреплены за Claude-lane,
  параллельный churn). Для этой задачи их трогать НЕ требуется (только читать).
  Если правка реально нужна — координировать, не делать `git add -A`, коммитить
  явным `git add` своих файлов после green-gate.
- **GV-шкала — приближение раннего забега.** `money` плоское (не масштабируется
  стадией), `cost_money`/артефакты/статы масштабируются. Поэтому крупные плоские
  награды `money` на риск-опциях намеренно не используются — на поздних стадиях
  они обесцениваются. При сверке EV держать это в голове.
- **`random_artifact` зависит от пула персонажа** (`reward_pool(character_id)`):
  фильтр релевантности статов может менять состав, но артефакты в пуле общие;
  GV ≈ 45 — усреднение по `TIER_WEIGHTS`, не гарантия конкретного тира.
- **Edge-case checks:** `check` passed = `stat >= difficulty` по сырому базовому
  стату temp-player (восстановленному из снапшота забега). P(success) в доке
  (≈0.55 при diff7, ≈0.45 при diff8) — оценка раннего забега; на поздних стадиях
  с прокачанными статами растёт. Это ок: риск проверок снижается по ходу забега.
- **Godot meta-сейв:** при headless-смоуках помнить про известный нюанс —
  `--user-data-dir` не изолирует реальный dev мета-сейв (death_save/unlocks),
  что иногда даёт ложные red'ы в runtime-тестах. При подозрительном red — не
  эскалировать в critical, перепроверить с нейтрализованным мета.
- **Связанные тикеты:** carry-over из эпика `SCRUM-476` (закрыт административно
  без выполнения EV-ребаланса). Смежная балансовая правка — `SCRUM-503` (cap
  berserk hammer DPS), отдельный коммит; конфликтов по файлам событий нет.

## QA Reverify - 2026-06-28

anim-loop-1 reverified SCRUM-494 read-only on fresh `origin/dev`.

- `tests/event_data_smoke_test.gd` PASS.
- `tests/runtime_smoke_progression_economy_test.gd` PASS.
- `tests/live_balance_simulation_test.gd` PASS.
- `tests/global_damage_balance_smoke_test.gd` PASS.
- `tests/global_survivability_balance_smoke_test.gd` PASS.
- `tests/runtime_smoke_test.gd` PASS (`Runtime smoke test passed.`).

Evidence: `build/qa/scrum494_anim_loop_qa/`.
