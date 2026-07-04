# Награда за акт-босса: выбор 1 из 3 суперредких артефактов + отхил 60–80% HP при переходе в акт

Статус: done
Приоритет: P1
Роль: Back-end
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Locked paths: `scripts/combat_director.gd` (`_grant_boss_completion_rewards`, `_end_combat` boss-victory ветка), `scripts/progression_data.gd` (`boss_completion_artifact_rewards`), `scripts/progression_data_content.gd` (пул суперредких артефактов, если вводится новый тир), `scripts/ui_screens.gd` (экран выбора награды на 3 варианта), `scripts/main.gd` (`advance_to_next_act` — отхил снапшота), `tests/runtime_smoke_test.gd`, `tests/runtime_smoke_ui_test.gd`
Jira: SCRUM-873
Версия: 0.2.1
Создано: 2026-07-04
Автор: PM (прямой запрос пользователя)
Labels: backend, claude, fantasydisk, foma, p1

## Autonomy / Approval
Пользователь заранее одобрил. Проценты отхила и состав пула решить самому (в рамках 60–80%).
Вести полностью автономно.

## Source Request

> «За победу над боссом в конце акта требуется, чтобы давалась награда в виде одного из трёх
> суперредких артефактов, и при переходе в следующий акт чтобы восстанавливалось 60–80% (реши
> сам) процентов жизней. То есть был отхил.»

## Контекст (Что и Зачем)

Акт заканчивается боссовым боем; при победе `_end_combat(true)` с `was_boss_fight=true`
(`scripts/combat_director.gd:273-274`) вызывает `_grant_boss_completion_rewards()` и затем
`advance_to_next_act()` (`scripts/combat_director.gd:287`, `scripts/main.gd:863`). ACT_COUNT=3
(`scripts/main.gd:33`).

Текущая награда за босса (`scripts/combat_director.gd:878-888`):
```gdscript
var artifact_rewards := PROGRESSION_DATA.boss_completion_artifact_rewards(selected_character_id)
if not artifact_rewards.is_empty():
    var reward = artifact_rewards[rng.randi_range(0, size-1)].duplicate(true)
    current_player.apply_reward(reward)          # авто-выдача ОДНОГО случайного
    ...
```
`boss_completion_artifact_rewards()` (`scripts/progression_data.gd:1398`) возвращает артефакты
`tier >= 3` (эпические). То есть сейчас: 1 случайный эпик выдаётся молча, без выбора игрока.
Игрок НЕ выбирает и HP при переходе в акт НЕ восстанавливается.

Между узлами/актами игрок пересоздаётся и восстанавливается из `run_player_snapshot`
(`scripts/combat_director.gd:1173/1188`, поле `health`). Снапшот снимается в `_end_combat` ДО
`advance_to_next_act` (`scripts/combat_director.gd:280`), поэтому отхил надо применять к самому
снапшоту (или к живому игроку до снятия снапшота), чтобы он «переехал» в следующий акт.

## Требования

### A. Выбор 1 из 3 суперредких артефактов
1. Вместо молчаливой авто-выдачи одного артефакта — показать игроку экран выбора награды с
   ТРЕМЯ вариантами суперредких артефактов; игрок берёт один.
2. «Суперредкие» = высший тир артефактов. Решение реализатора (задокументировать выбор):
   - либо использовать текущий top-tier пул (`tier >= 3`, `boss_completion_artifact_rewards`),
   - либо ввести новый тир «суперредкие» (напр. `tier 4`) с отдельным небольшим пулом в
     `scripts/progression_data_content.gd` (`ARTIFACTS`), учтя веса `TIER_WEIGHTS`
     (`scripts/progression_data_balance.gd:376`). Предпочтительно — отдельный узнаваемый
     «boss-only» суперредкий пул, чтобы награда за акт-босса ощущалась особенной.
3. Выборка 3 вариантов — без дублей, с учётом релевантности классу
   (`is_reward_relevant`/`class_affinity`), как в существующем артефакт-оффере
   (`scripts/ui_screens.gd:8378`). Если релевантных суперредких < 3 — добить нейтральными
   (`class_affinity: []`) того же тира; гарантировать ровно 3 варианта.
4. Экран выбора переиспользует существующий паттерн reward/artifact-choice UI в
   `scripts/ui_screens.gd` (тот же визуальный язык, safe-area, геймпад/мышь/клава). Выбранный
   артефакт применяется через `current_player.apply_reward(...)` + учёт кодекса
   (`record_codex_artifact_discovery`). XP/деньги за босса (`drop_class_rewards("boss", ...)`)
   выдаются как раньше.
5. Финальный босс акта 3 (ветка `else` → `_show_victory_screen`,
   `scripts/combat_director.gd:293-299`): награда-выбор допустима и там (по решению
   реализатора), но экран выбора не должен ломать переход на экран победы/финальные метрики.

### B. Отхил 60–80% HP при переходе в следующий акт
6. При успешном переходе в следующий акт восстанавливать HP игрока на выбранный процент в
   диапазоне 60–80% от max_health (реализатор фиксирует конкретное значение, напр. 70%, и
   документирует). Хил — это лечение (clamp по max_health), а не установка HP в фиксированное
   значение; т.е. `health = min(max_health, health + pct*max_health)`.
7. Точка применения: в `advance_to_next_act()` (`scripts/main.gd:863`, возвращает `true` только
   если есть следующий акт) домешивать хил к `run_player_snapshot["health"]` (снапшот уже снят к
   этому моменту). Так HP «переезжает» в первый бой нового акта. НЕ хилить, когда акт финальный
   (`current_act >= ACT_COUNT`, ранний `return false`) — там забег завершается победой.
8. Использовать существующую семантику лечения (`player.heal_percent`,
   `scripts/player.gd:2287`) как ориентир для формулы; для снапшота — арифметика по
   `health`/`max_health` полей снапшота.

## Acceptance Criteria

- [ ] После победы над боссом акта игроку показывается экран выбора из РОВНО 3 суперредких
      артефактов; выбранный применяется к игроку и учитывается в кодексе.
- [ ] Варианты без дублей, релевантны классу (с добивкой нейтральными при нехватке); тир —
      высший/«суперредкий», задокументирован (существующий tier≥3 или новый tier4).
- [ ] Экран выбора работает мышью, клавиатурой и геймпадом, контент в safe-area, без наезда на
      рамку; не ломает переход на карту следующего акта и экран победы после финального босса.
- [ ] При переходе в следующий акт HP восстанавливается на 60–80% max_health (значение
      зафиксировано и записано в docs); отхил виден в первом бою нового акта.
- [ ] После финального босса (акт 3) отхил не применяется, забег корректно завершается победой.
- [ ] XP/деньги за босса выдаются как раньше; обычные бои и их награды не затронуты.
- [ ] `runtime_smoke_test.gd` и `runtime_smoke_ui_test.gd` зелёные из чистого worktree.

## Заметки для исполнителя

- `ui_screens.gd` за Claude-контуром. Пересекается по `combat_director.gd` с задачей
  «ultimate_charge persist» — брать/вести в одном контуре, не параллелить правку одного файла
  двумя воркерами.
- Не превращать акт-награду в обязательный «power creep» без баланса: если вводится tier4 —
  держать пул небольшим и осмысленным, отметить в balance-доке.
- Если для суперредких нужен новый арт-икон — вынести арт в отдельную design/animation-задачу,
  функциональную часть не блокировать (временно переиспользовать иконку тира 3).

## Файлы

- Изменить: `scripts/combat_director.gd` (`_grant_boss_completion_rewards` → выбор 3),
  `scripts/progression_data.gd` (`boss_completion_artifact_rewards` / новая выборка суперредких),
  `scripts/progression_data_content.gd` (пул, если новый тир), `scripts/ui_screens.gd` (экран
  выбора награды), `scripts/main.gd` (`advance_to_next_act` — отхил снапшота).
- Тесты: `tests/runtime_smoke_test.gd`, `tests/runtime_smoke_ui_test.gd`.
- Docs: `docs/design/systems/` (артефакты/прогрессия), `docs/design/current_game_state.md` —
  записать: пул суперредких, механику выбора 3, процент отхила при переходе в акт.

## Валидация

- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- Живой прогон (dev-консоль `~`): дойти до акт-босса (`win`/`fight`), убить, проверить экран
  выбора 3 суперредких и восстановление HP в первом бою нового акта.

## Result

2026-07-04, Claude (pm-chat, worktree dreamy-bun-6a51c0):

**A. Выбор 1 из 3 суперредких:**
- `scripts/progression_data.gd`: новая `boss_completion_artifact_choices(count, character_id)` —
  равновероятная выборка БЕЗ дублей из существующего top-tier пула
  `boss_completion_artifact_rewards` (tier >= 3, 8 артефактов, 7 нейтральных — на любой класс
  хватает 3 уникальных). Решение: «суперредкие» = верхний тир как boss-only оффер; новый tier 4
  контент НЕ вводился (при желании — отдельная design/balance задача).
- `scripts/combat_director.gd` `_grant_boss_completion_rewards()`: артефакт больше не выдаётся
  молча — остались XP/деньги (`drop_class_rewards("boss", ...)`).
- `scripts/combat_director.gd` `_end_combat()` boss-victory: флоу обёрнут в
  `proceed_after_boss`; экран выбора показывается когда забег продолжается (следующий акт или
  секретный босс); после финального босса — сразу экран победы (выбор бессмыслен, забег
  завершён).
- `scripts/ui_screens.gd`: новый `_show_boss_artifact_reward(on_done)` по паттерну
  `_show_elite_artifact_reward` (панель 1140×640, карточки `_make_elite_artifact_card`,
  титул «Трофей босса» в TIER_COLORS[3], фокус-навигация стрелками/геймпадом по кругу,
  Escape не закрывает, guard на пустой пул). Применение через `_apply_reward_to_run`
  (снапшот) + кодекс.

**B. Отхил при переходе акта:**
- `scripts/main.gd`: `ACT_TRANSITION_HEAL_PERCENT := 0.7` (зафиксировано 70%, середина
  запрошенного диапазона 60–80). В `advance_to_next_act()` лечится
  `run_player_snapshot["health"]` (+70% max, clamp по max) — HP переезжает в первый бой
  нового акта. После финального акта функция возвращает false до отхила — не хилим.

**Тесты:**
- Новый `tests/boss_act_reward_heal_test.gd`: пул choices (3, уникальные, tier>=3, для 5
  классов включая doctor), отхил 20→90, clamp 60→100, финальный акт без отхила, UI-флоу
  (3 карточки, клик → артефакт в снапшоте из суперредкого пула, on_done, экран закрыт).
- `tests/runtime_smoke_test.gd` `_test_boss_act_transition`: контракт обновлён — после
  победы над акт-боссом ждём 3-карточный экран, кликаем, затем акт 2 + артефакт в снапшоте.
- `tests/doctor_drain_softcap_test.gd`: source-scan перенацелен на
  `_show_boss_artifact_reward` (character-filtered choices) + прямой фильтр-чек
  `boss_completion_artifact_choices(3, "doctor")`.

Validation:
- `boss_act_reward_heal_test.gd` — PASS; `doctor_drain_softcap_test.gd` — PASS;
  `runtime_smoke_test.gd` — PASS; `runtime_smoke_ui_test.gd` — PASS;
  `monster_xp_pressure_pacing_test.gd` — PASS (все через godot_gate).

Docs updated: `docs/design/current_game_state.md` (основной поток п.11 — экран трофея босса +
отхил 70%).

Disk cleanup: none created.
