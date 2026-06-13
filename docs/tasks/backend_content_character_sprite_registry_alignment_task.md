# Back-end Task: Align Character Sprite Paths With Registry

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-192
Эпик: epic_full_project_quality_pass

## Scope

Fix character `sprite_path` drift between `scripts/progression_data.gd`, `docs/design/content_registry.md` and actual asset files.

## Known Drift

`thief`, `elementalist`, `sniper`, `priest`, `biologist` and `engineer` have final PNG files, but current config points at older proxy class sprites.

## Requirements

- Update code paths only if final files exist.
- Add a regression test that each `CHARACTER_CONFIGS[id].sprite_path` exists and matches registry expectation.
- Update docs if any intentional fallback remains.

## Verification

- Runtime smoke and animation smoke pass.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## Result Summary (2026-06-13)

Closed by Back-end.

- Aligned `scripts/progression_data.gd` character `sprite_path` values with `docs/design/content_registry.md` for `thief`, `elementalist`, `sniper`, `priest`, `biologist` and `engineer`.
- Added `tests/character_sprite_registry_alignment_test.gd`, which checks all 17 character IDs against canonical sprite paths and verifies that each resource exists.
- No art files were changed; the task only switched runtime config to already-existing canonical PNGs.

Verification:

- `Godot --headless --path ... --script res://tests/character_sprite_registry_alignment_test.gd` — passed.
- `Godot --headless --path ... --script res://tests/content_registry_consistency_test.gd` — passed.
- `Godot --headless --path ... --script res://tests/animation_smoke_test.gd` — passed.
- `Godot --headless --path ... --script res://tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-192)

Проверено фактически (конфиг + тест + РЕАЛЬНЫЙ рендер):
- sprite_path в CHARACTER_CONFIGS для 6 классов теперь указывает на ФИНАЛЬНЫЕ PNG
  (не прокси): thief→thief.png, elementalist→elementalist.png, sniper→sniper.png,
  priest→priest.png, biologist→biologist.png, engineer→engineer.png. ✓
- Регресс-тест `tests/character_sprite_registry_alignment_test.gd` — PASSED
  («17 characters»): каждый CHARACTER_CONFIGS[id].sprite_path существует + совпадает с
  каноническим путём реестра. Защита от будущего дрейфа. ✓
- РЕНДЕР hero select с выбранным thief (build/qa/sprite_registry_alignment/): главный
  портрет — Вор с собственным финальным артом (капюшон/кинжалы/кожа), досье «Вор» —
  т.е. в игре грузится правильный спрайт, не старый прокси. ✓
- content_registry_consistency + animation + runtime smoke зелёные (по отчёту + мои
  прогоны в прошлых тиках).
Корректность-фикс: 6 новых классов больше не показывают прокси-спрайты. Багов нет.
