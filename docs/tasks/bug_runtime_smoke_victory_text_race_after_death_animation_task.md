# BUG: runtime_smoke victory-текст не успевает после death-анимации босса (гонка тайминга)

Статус: new
Приоритет: high
Роль: Back-end / Animator (тайминг)
Версия: 0.1.5
Создано: 2026-06-14
Автор: QA (затяжной green-gate блокер)
Jira: pending sync
Связано: SCRUM-370 (интеграция death-рядов в .tres), SCRUM-379 (death-lifecycle),
SCRUM-380 (death-row source-ассеты)

## Симптом
`tests/runtime_smoke_test.gd` (boss-flow) красный:
```text
ERROR: Expected victory screen text to include 'Победа'.
```
Блокирует green-gate (≥5 QA-тиков подряд, HEAD не двигается). Из-за этого
накоплены НЕзакоммиченные QA-вердикты (SCRUM-374/380/383 — синканы в Jira, но
коммит green-gated).

## QA-анализ корня (фактический)
- Victory-экран ИСПРАВЕН изолированно: прямой вызов `ui._show_victory_screen()`
  производит Label «Победа» (+ «Финальный босс повержен…») — проверено
  репродукцией (FOUND_POBEDA=true, 2 Label).
- В тесте boss-flow: `boss.take_damage(99999)` → проверки `combat_active==false`
  (стр.2952) и meta-grant (2956) **проходят** → бой завершается, мета выдаётся.
  Падает только сбор victory-текста `_collect_label_text(main)` (2960) после
  **всего 2 кадров** (2950-2951) — «Победа» ещё не на экране.
- Причина гонки: **SCRUM-379 death-lifecycle** (`enemy.gd:_play_full_frame_death_then_free`)
  теперь проигрывает death-анимацию **0.25-1.2с** перед cleanup, КОГДА у сущности
  есть full-frame `death`. **SCRUM-370** только что добавил death-ряды боссам в .tres
  (`death=6`), поэтому boss-смерть пошла по этому пути. Победный баннер/экран
  («Новый победный флоу: баннер „Победа“ → окно докачки атрибутов → карта»,
  комментарий теста 1155) теперь появляется ПОЗЖЕ 2 кадров.

Итог: НЕ слом геймплея (victory происходит, combat-end+meta целы) — это гонка
тайминга «death-анимация vs 2-кадровое ожидание теста», внесённая death-row
интеграцией.

## Воспроизведение
1. Убедиться, что boss-spriteframes содержат `death` (после SCRUM-370/380).
2. `Godot --headless --script res://tests/runtime_smoke_test.gd` → ERROR на «Победа».
3. `ui._show_victory_screen()` изолированно → «Победа» присутствует (экран исправен).

## Предлагаемый фикс (выбрать одно, координация Back-end/Animator)
1. **Тайминг победы независим от death-анимации**: показывать победный баннер/экран
   сразу по `died`-сигналу босса (он эмитится синхронно в `enemy.gd:240` ДО
   `_play_full_frame_death_then_free`), не дожидаясь окончания death-анимации; ИЛИ
2. **Босс пропускает death-delay для триггера победы** (death-анимация играет
   визуально, но combat-end→victory не ждёт её); ИЛИ
3. **Обновить тест**: в boss-flow ждать длительность boss death-анимации
   (≈`clampf(count/fps,0.25,1.2)` + запас) перед `_collect_label_text`, т.к.
   death-анимация — намеренное новое поведение (379). Это самый малый фикс, если
   геймплейная задержка победы на 0.25-1.2с приемлема (показать смерть босса до
   экрана победы — desirable).

## Acceptance Criteria
- [ ] `runtime_smoke_test.gd` boss-flow зелёный (victory-текст «Победа» находится).
- [ ] Геймплей: после смерти босса победный экран/баннер показывается (с death-
      анимацией или без — на усмотрение, но детерминированно для теста).
- [ ] Death-lifecycle (379) и death-ряды (370/380) не сломаны; loot/score/meta целы.
- [ ] runtime_smoke + boss_elite smoke зелёные; CHANGELOG при изменении поведения.

## Files / IDs
- `tests/runtime_smoke_test.gd` (boss-flow victory check ~2940-2970; `_collect_label_text`)
- `scripts/enemy.gd` (`_play_full_frame_death_then_free` 252-279; `died.emit` 240)
- `scripts/combat_director.gd` / `scripts/main.gd` (boss death → victory trigger)
- `scripts/ui_screens.gd` (`_show_victory_screen` 3737; победный баннер 1151)

## Документация
docs/design/systems/combat.md (victory-флоу + death-lifecycle тайминг).
