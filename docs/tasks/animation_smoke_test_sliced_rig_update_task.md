# Animator Task: Обновить animation_smoke_test Под Sliced Rig

Статус: закрыта 2026-06-10 — Animator-агент обновил tests/animation_smoke_test.gd под sliced rig параллельно; тест проходит без ERROR-строк. Остается актуальным только примечание №4: API `set_status_tint(color)` в риге используется enemy/boss-кодом (щит, аура, windup, ярость) и должен сохраняться при будущих переработках рига.
Роль: Animator
Создано: 2026-06-10

## Проблема

`scripts/cutout_rig_2d.gd` переведен на sliced rig (manifest `scripts/sliced_rig_manifest.gd`, иерархия `Pelvis/Figure/<части по манифесту>`), но `tests/animation_smoke_test.gd` все еще проверяет старую структуру `Pelvis/Body`, `Pelvis/Head`, `Pelvis/ArmL/Sprite` и т.д. Тест печатает "passed", но при этом сыпет `push_error` на каждом отсутствующем узле — ошибки маскируют реальные регрессии, а часть error-веток не делает `return` после `quit(1)`.

## Что Нужно

1. Переписать проверки `_assert_player_rig` / `_assert_rig_part_texture` / `_assert_hero_overlay` / enemy-проверки под фактическую структуру sliced rig (включая legacy fallback, если профиль отсутствует в манифесте).
2. Убедиться, что каждая error-ветка завершает тест (`quit(1)` + `return`), чтобы тест не мог печатать "passed" после ошибок.
3. Сохранить покрытие: rig игрока, rig врага, hero overlay, walk/idle/action позы, death ghost (`spawn_death_ghost`).
4. Backend-совместимость: API `set_status_tint(color)` в риге используется enemy/boss-кодом для щита/ауры/windup/ярости — не удалять.

## Проверка

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

Тест должен проходить без ERROR-строк в выводе.

## QA-Вердикт
Статус: PASSED
Легаси-задача, работа выполнена и в игре (подтверждено архивным ревью QA-кладбища 2026-06-28). Повторный дрейф в QA = board-sync revert из-за отсутствия PASSED-блока. Релевантные smoke (animation_smoke_test / runtime_smoke_test) зелёные на origin/dev 2026-06-30. Блок дописан, чтобы остановить дрейф.
