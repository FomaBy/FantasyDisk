# Backend: Увеличить боевой размер игровых персонажей

Статус: done
Приоритет: medium
Роль: Back-end
Контур: Codex
Owner: Back-end/Codex
Thread/Worker: current Codex thread
Locked paths: `scripts/player.gd`, `scenes/Player.tscn`, `tests/runtime_smoke_test.gd`, `tests/animation_smoke_test.gd`, `docs/design/systems/combat.md`, `docs/design/current_game_state.md`
Версия: 0.1.8
Создано: 2026-07-02
Автор: прямой запрос пользователя
Jira: SCRUM-823

## Контекст
Пользователь просит во время боя слегка увеличить playable characters, потому что
они иногда выглядят меньше монстров. Целевой визуальный множитель — примерно x1.5
от текущего combat scale.

## Требования
- Увеличить только визуальный combat scale игровых персонажей.
- Не менять collision radius, скорость, дальности, урон, enemy scale или UI portraits.
- Сохранить full-frame `AnimatedSprite2D`, skeletal/cutout fallback и weapon socket
  в одном масштабе через общий `BASE_SPRITE_SCALE`.
- Обновить smoke expectations и документацию по текущему боевому состоянию.

## Acceptance Criteria
- [x] `Player/VisualRoot/Body` и fallback rigs используют новый combat visual scale.
- [x] `CollisionShape2D` игрока остается прежним.
- [x] Focused/runtime smoke не находят регрессий в player scale/weapon socket.
- [x] Документация фиксирует, что изменение visual-only и не меняет баланс.

## План проверки
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`

## Результат
- `PLAYER_COMBAT_VISUAL_SCALE` поднят `0.425 -> 0.64`, примерно x1.5, через общий
  `BASE_SPRITE_SCALE` для full-frame `Body`, skeletal и cutout fallback paths.
- `scenes/Player.tscn` приведён к тому же стартовому `Body.scale = Vector2(0.64, 0.64)`.
- `CollisionShape2D` / `CircleShape2D radius = 8.9` не менялся; скорость, дальности,
  урон, enemy scale, pivot, flip и `WeaponSocket` не менялись.
- Обновлены smoke expectations и документация: `docs/design/systems/combat.md`,
  `docs/design/current_game_state.md`.

Проверки:
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
  в чистом QA worktree `/tmp/fantasydisk-scrum823-qa`.
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
  в чистом QA worktree `/tmp/fantasydisk-scrum823-qa`.

Примечание по основному checkout: полный runtime smoke в основном дереве был
заблокирован не этой задачей, а чужим dirty WIP в `scripts/ui_screens.gd`
(SCRUM-816 settings/gamepad changes) с compile errors. Чтобы не трогать чужой WIP,
проверка `SCRUM-823` выполнена в чистом detached QA worktree с применённым только
patch этой задачи.

Disk cleanup: removed `/tmp/fantasydisk-scrum823-qa` and `/tmp/scrum823_player_scale.patch`.
Thread cleanup: not a disposable worker thread.
