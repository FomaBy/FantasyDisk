# BUG: Gold menu HUD tracks overlap after 2K-to-720 live resize

Статус: done
Приоритет: high
Роль: Back-end (UI runtime/tests)
Контур: Codex
Исполнитель: Codex
Owner: Back-end / Codex
Thread/Worker: root-scrum-1039-1040-ui-resize
Jira: SCRUM-1039
Версия: 0.2.1
Найдено QA при тестировании: SCRUM-1036 / SCRUM-981
Locked paths: `scripts/ui_screens.gd`;
`tests/scrum981_gold_menu_shell_test.gd`;
`tests/ui_no_overlap_matrix_test.gd`; this mirror/evidence

Branch/worktree: `codex/scrum-1039-1040-ui-resize` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1039-1040-ui-resize`

## Контекст

Fix `144371177` правильно переносит общий menu `RunResourceHud` и каждый его
видимый child в authored gold-shell inner rect, а generic FAB — в точный
равномерный `72x72` socket. Независимый QA обнаружил отдельный false-green при
live resize уже построенного экрана: внешний HUD пересчитывается, но дочерние
`PanelContainer`/`ProgressBar` не уменьшают фактический rect после снижения
minimum size с 2K tier на 720p.

## Воспроизведение

1. Взять `origin/dev` `5229e770f` или новее с fix `144371177`.
2. Открыть Rest gold-shell screen в `2560x1440`.
3. Не пересоздавая экран, изменить live viewport/window на `1280x720` и дать
   минимум семь кадров layout.
4. Измерить фактические `global_rect` `HudHPTrack`, `HudXPTrack` и
   `HudULTTrack` внутри `RunResourceHud`.

## Ожидание / Реальность

Свежий `1280x720` layout корректен и не имеет sibling intersections:

- `HudHPTrack=Rect2(187,143,258,16)`;
- `HudXPTrack=Rect2(187,165,210,13)`;
- `HudULTTrack=Rect2(187,182,210,13)`.

После live `2560x1440 -> 1280x720` позиции и внешний HUD верны, но высоты
остаются завышенными:

- `HudHPTrack=Rect2(187,143,258,32)`;
- `HudXPTrack=Rect2(187,165,210,26)`;
- `HudULTTrack=Rect2(187,182,210,26)`.

Итог: HP/XP пересекаются на `10px`, XP/ULT — на `9px`; дочерние progress bars
также физически пересекаются. Возврат к 2K восстанавливает исходную 2K
геометрию, поэтому текущий финальный idempotency assert зелёный и не ловит
сломанный промежуточный supported viewport.

Read-only root-cause inference: `_hud_v2_place_in_panel()` назначает меньший
размер `PanelContainer` до того, как меньший minimum дочернего `ProgressBar`
успевает примениться. Нужен корректный reset/order или второй deferred layout
pass; QA код не менял.

## Acceptance Criteria

- [x] Fresh 1280 и live 2560→1280 дают одинаковые rect всех видимых HUD
      children, кроме динамического текста/значений.
- [x] HP/XP/ULT sibling tracks и их ProgressBar children попарно не
      пересекаются после resize в обе стороны.
- [x] Каждый HUD child остаётся внутри authored `+24/+32` inner reserve;
      generic FAB остаётся exact visible `72x72` с uniform scale.
- [x] `2560 -> 1280 -> 2560` остаётся полностью idempotent.
- [x] Route Map specialized layout, Combat HUD и frameless Level Up не меняются.
- [x] Focused SCRUM-981 и no-overlap oracles проверяют fresh-vs-live child rect
      equality и sibling disjointness, а не только outer containment.
- [x] Focused shell/Route Map, no-overlap, theme, runtime UI, gamepad full-flow
      и full runtime проходят; результат запушен в `origin/dev` и передан QA.

## QA evidence (2026-07-10)

QA checkout: fresh `origin/dev` `5229e770f`, containing implementation
`144371177`. Windowed screenshot:
`build/qa/scrum1036_reqa_live_resize_1280.png`.

Зелёные проверки до блокера: SCRUM-981 focused, exact Route Map, fresh
no-overlap matrix, dark-fantasy theme, runtime UI, gamepad full-flow `2/2`,
animation/meta/targeting and full runtime `exit 0`. Full runtime printed only
the already tracked external SCRUM-1034 freed-lambda diagnostic and the known
dummy-renderer screenshot warning.

Product code/tests/art were read-only during QA.

## Implementation result (2026-07-10)

- `ProgressBar.custom_minimum_size` теперь уменьшается до назначения нового
  rect/style родительского `PanelContainer`; stale 2K minimum больше не
  удерживает завышенную физическую высоту после shrink.
- Gold-shell menu HUD получает immediate и deferred current-size layout pass,
  оба вычисляют inner rect из актуального viewport, а не из stale metadata.
- Focused oracle сравнивает actual rect трёх tracks и трёх bars у независимо
  созданного fresh 1280 layout с live `2560→1280`, проверяет sibling
  disjointness и полную `2560→1280→2560` idempotency.
- Независимый read-only subagent review: PASSED, blocking findings отсутствуют.

Green gate: SCRUM-981 focused; exact Route Map; UI no-overlap matrix;
dark-fantasy UI theme; runtime UI; gamepad full-flow 3/3; audio integration;
full runtime — PASSED. Full runtime содержит только известные non-fatal headless
lambda/dummy-renderer diagnostics.

Commit/push: `9f04dc59e` → `origin/dev`. Jira: `Контроль качества`.
Disk cleanup: removed task `.godot` cache (445 MB); generated UID sidecars
removed; clean disposable worktree is removed after final routing sync.

## QA-Вердикт — independent production acceptance (2026-07-10)

Статус: PASSED

Проверено read-only на свежем `origin/dev`: focused SCRUM-981 фактически
сравнивает шесть `Track`/`Bar` rect у fresh `1280x720` и live
`2560→1280`, sibling intersections отсутствуют, обратный
`1280→2560` совпадает с fresh 2K. Authored inner reserve, exact generic
`72x72` FAB, panel separation, Route Map specialized geometry, Combat и
frameless Level Up сохранились.

Green gate: exact Route Map; seven-viewport no-overlap; dark theme; runtime
UI; audio integration/manager; gamepad full-flow `2/2`; animation/meta/
targeting; full runtime `exit 0`. В полном runtime остались только внешние
известные SCRUM-1034 freed-lambda и dummy-renderer diagnostics. Jira:
`Готово`. Product code/tests/assets QA не менял.
