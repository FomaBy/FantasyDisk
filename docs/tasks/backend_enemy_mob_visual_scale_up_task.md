# Backend: Увеличить боевой размер мобов

Статус: done
Приоритет: medium
Роль: Back-end
Контур: Codex
Owner: Back-end/Codex
Thread/Worker: current Codex thread
Locked paths: `scripts/progression_data_enemies.gd`, `tests/enemy_content_integrity_test.gd`, `docs/design/systems/enemies_bosses.md`, `docs/design/mechanics_extract.md`, `docs/design/current_game_state.md`
Версия: 0.2.0
Создано: 2026-07-02
Автор: прямой запрос пользователя
Jira: SCRUM-829

## Контекст
Пользователь просит увеличить мобов на 20-30%, чтобы боевые враги читались
крупнее после увеличения playable characters.

## Требования
- Увеличить стандартных боевых мобов примерно на +25% через data-driven enemy
  size profiles.
- Сохранить иерархию размеров: обычный моб < мини-элита < карточная элитка < босс.
- Не менять boss scale, route elite scale, HP, урон, скорость, спавн или награды.
- Обновить тест данных и документацию по текущему состоянию enemy profiles.

## Acceptance Criteria
- [x] `ProgressionData.ENEMY_SIZE_PROFILES.ordinary.scale` поднят в диапазоне
  1.20-1.30.
- [x] `mini_elite` тоже увеличен так, чтобы оставаться крупнее обычного моба и
  меньше карточной элитки.
- [x] Босс-профиль остается крупнейшим.
- [x] Focused/runtime проверки не находят регрессий в enemy scale profiles.
- [x] Документация фиксирует новый масштаб мобов.

## План проверки
- `python3 tools/godot_gate.py --headless --path . --script res://tests/enemy_content_integrity_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`

## Результат
- `ProgressionData.ENEMY_SIZE_PROFILES.ordinary.scale` поднят `1.00 -> 1.25`
  (+25%) для стандартных боевых мобов.
- `mini_elite.scale` поднят `1.05 -> 1.31`, чтобы mini-elite свита оставалась
  крупнее обычного моба, но меньше карточной элитки.
- `elite.scale = 1.68` и `boss.scale = 1.90` не менялись; HP, урон, скорость,
  спавн и награды не менялись.
- `tests/enemy_content_integrity_test.gd` теперь закрепляет точные scale profiles
  и порядок `ordinary < mini_elite < elite < boss`.
- Документация обновлена в `docs/design/systems/enemies_bosses.md`,
  `docs/design/mechanics_extract.md`, `docs/design/current_game_state.md`.

Проверки:
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/enemy_content_integrity_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path /tmp/fantasydisk-scrum829-qa --script res://tests/enemy_content_integrity_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path /tmp/fantasydisk-scrum829-qa --script res://tests/runtime_smoke_test.gd`

Примечание: полный runtime smoke запускался в чистом detached QA worktree с
применённым только patch этой задачи, потому что основной checkout содержит
чужой dirty WIP в UI/settings/gamepad-файлах.

Disk cleanup: removed `/tmp/fantasydisk-scrum829-qa` and `/tmp/scrum829_enemy_mob_scale_code.patch`.
Thread cleanup: not a disposable worker thread.

## QA-Вердикт
Статус: PASSED
Дата: 2026-07-02 (claude-qa)
Проверено на origin/dev @ da38879e (ancestor origin/dev; код-диф — только scale).

- ENEMY_SIZE_PROFILES: ordinary 1.0→1.25 (+25%, в 1.20-1.30), mini_elite 1.05→1.31.
  elite 1.68 / boss 1.90 не изменены; HP/урон/скорость/спавн/награды — нет.
- Иерархия ordinary<mini_elite<elite<boss закреплена enemy_content_integrity_test.
- enemy_content_integrity_test — PASS (exit 0); runtime_smoke_test — PASS (exit 0,
  без регрессий enemy scale).
- Доки: enemies_bosses.md, mechanics_extract.md, current_game_state.md.
