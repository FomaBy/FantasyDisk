# BUG (CRITICAL): Смерть игрока НЕ завершает бой — game-breaking

Статус: new
Приоритет: critical
Роль: Back-end (бой/death-flow)
Версия: 0.1.6
Создано: 2026-06-15
Автор: QA (находка при regression-прогоне)

## Симптом
`runtime_smoke_test.gd` стабильно (3/3) падает: **«Expected player death to end
combat.»** (строка ~7457). QA-проверка отдельным скриптом: после `player.take_damage(99999)`
**бой НЕ завершается даже через 120 кадров** (`game.combat_active` остаётся `true`).
В игре это значит: игрок умирает → нет экрана смерти, забег не заканчивается. **Game-breaking.**

## Диагностика (QA)
Цепочка смерти КОД-корректна, но не срабатывает:
1. `player.gd:496 take_damage` → при `health <= 0` (518/536) →
   `player.gd:540 died.emit()` → `541 queue_free()`.
2. `combat_director.gd:42-45`: `current_player.died.connect(func(): _end_combat(false))`.
3. `combat_director.gd:107 _end_combat(false)` → `113 game.combat_active = false`.

**Факты:**
- `died.emit()` НЕ кидает script-error (spawn_death_ghost guarded `has_method`,
  `_cutout_rig()` возвращает RigRoot — он существует даже скрытым при full-frame Body SCRUM-411).
- Тем не менее `combat_active` не сбрасывается → бой висит.

**Гипотезы корня (проверить по порядку):**
- **(A) Игрок не умирает**: `take_damage:497` early-return при
  `_damage_invulnerability_left > 0.0` ИЛИ `505` dodge — если у игрока spawn-инвул/
  невозможность урона в момент вызова, `99999` не применяется, `died` не эмитится.
  (Тест обнуляет dodge, но НЕ invuln.) Проверить, есть ли invuln на старте боя / после
  недавних правок.
- **(B) Сигнал `died` не доходит**: connect (combat_director:42) мог не выполниться для
  текущего `current_player` (переинстанс игрока / порядок setup), или хэндлер
  отключился. Проверить, что соединение живо именно на убиваемом инстансе.
- **(C) Регресс от SCRUM-442** (отмена v2 / новый спрайт Берсерка «без анимаций»):
  изменение спрайта/рига могло поломать death-путь (rig-состояние, visual). 442 не менял
  .gd, но сменил берсерк-ассеты — проверить, не зависит ли death-flow от анимаций спрайта.
- НЕ регресс одного коммита: `088e852b` (ранее) тоже падает на 1-frame death-ассерте —
  баг присутствовал/латентен и стал стабильно воспроизводиться.

## Требования
1. Найти точку разрыва (died.emit не эмитится / сигнал не доходит / combat_active не
   сбрасывается) и починить так, чтобы **смерть игрока всегда завершала бой** и показывала
   экран смерти.
2. Сделать ассерт детерминированным: ждать сигнала/завершения боя (bounded frames), а не
   ровно 1 frame (если окажется timing-составляющая).
3. Не сломать death_save (capstone «Вторая жизнь»), victory-flow, boss/elite end.

## Acceptance Criteria
- [ ] `take_damage` до 0 HP → `combat_active` становится `false` (бой завершается), показан death-экран.
- [ ] `runtime_smoke_test` «player death to end combat» зелёный 3/3; полный runtime_smoke зелёный.
- [ ] death_save/victory/boss-end не сломаны.

## Files
- `scripts/player.gd:496-542` (take_damage / death / died.emit)
- `scripts/combat_director.gd:42-45` (died.connect), `:107-128` (_end_combat)
- `tests/runtime_smoke_test.gd:~7445-7458` (death assertion)

## Verification
```bash
# до фикса: COMBAT STILL ACTIVE; после: COMBAT ENDED after N frames
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --user-data-dir /tmp/dc --path "$PWD" --script res://tests/runtime_smoke_test.gd 2>&1 | grep -c "Runtime smoke test passed"  # → 1, 3/3
```

## ОКОНЧАТЕЛЬНЫЙ ДИАГНОЗ (Back-end, 2026-06-15 — подтверждён эмпирически)

**Корень найден — это НЕ game-breaking и НЕ гипотезы A/B/C.** Изолированный прогон
(berserk/sword) печатает фактическое состояние:
- `death_save: 1.0`, после `take_damage(99999)` → `health: 1.0`, **игрок ЖИВ** (не умирает),
  `combat_active: true`. То есть **игрок НЕ умирает** — его спасает `death_save`
  (player.gd:528-534), а не «умирает, но бой не кончается».
- (A) invuln — НЕ причина: `_damage_invulnerability_left = 0` на старте.
- (B) сигнал — НЕ причина: при нейтрализации death_save игрок умирает И бой кончается
  (`combat_active: false`, player freed) → connect/`_end_combat` работают.
- (C) SCRUM-442 — НЕ причина: 442 не менял .gd.

**Почему death_save активен:** `meta_state.skill_nodes` содержит ВСЕ 38 узлов (включая
`endure_capstone`). Источник — **реальный dev-сейв** `~/Library/Application Support/Godot/
app_userdata/FantasyDisk/fantasydisk_meta.cfg` (дерево полностью разблокировано).
**ВАЖНО: `--headless --user-data-dir <X>` НЕ изолирует** — Godot игнорирует флаг,
`user://` всегда резолвится в реальный app_userdata. Поэтому тест читает общий сейв.

**Severity на самом деле — НЕ critical/game-breaking:** новый игрок (пустое дерево,
`default_state().skill_nodes == []`) `death_save=0` → `take_damage(99999)` убивает →
бой кончается → death-экран. Подтверждено: при пустом/нейтрализованном death_save
`combat_active → false`. Затронуты ТОЛЬКО окружения с купленным `endure_capstone`.

**Настоящая проблема двойная:**
1. **Хрупкость теста** `_test_death_flow`: нейтрализует dodge, но не death_save. Фикс
   (подтверждён) — перед `take_damage` добавить:
   ```gdscript
   var run_mods: Dictionary = player.get("run_modifiers")
   run_mods["death_save"] = 0.0
   run_mods["death_save_used"] = 1.0
   player.set("run_modifiers", run_mods)
   ```
   (Детали — `docs/tasks/bug_runtime_smoke_death_flow_death_save_fragility_task.md`.)
2. **Дыра тест-изоляции:** тесты гоняют по общему реальному сейву (`--user-data-dir`
   не работает). Тест должен грузить чистый `default_state()` или временный конфиг,
   а не реальный мета-сейв. Иначе ЛЮБОЙ капстон в личном сейве ломает тесты.

**Не game-breaking → можно снизить с critical.** Геймплейный death-flow корректен.
Правка нужна только в тесте/тест-изоляции, НЕ в `player.gd`/`combat_director.gd`.

**Кто применяет:** правку `_test_death_flow` беру я, как только `runtime_smoke_test.gd`
освободится (сейчас M у другого воркера). Геймплейный код не трогать.
