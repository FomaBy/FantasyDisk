# SCRUM-970 — Atlas/Guild skill-node clickability at 1920×1080

Статус: done
Версия: 0.2.1
Jira: SCRUM-970
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-970`
Branch: `codex/scrum-970-atlas-click`

## Scope And Locks

Только Atlas/Guild input/focus responsive hunks в `scripts/ui_screens.gd`,
focused pointer regression, этот mirror и документация input-контракта.
Существующий Atlas art, progression data, баланс и unrelated UI read-only.

## Diagnosis And Decision

Канон SCRUM-838 новее исходной формулировки Jira: клик по сокету только
выбирает preview; покупка выполняется отдельной `AtlasBuyButton`. Прямую покупку
по сокету добавлять нельзя.

Реальный `SubViewport.push_input()` probe показал, что на 1280/1920/2048
курсор попадает точно в видимый `TextureButton`, а overlays и frame имеют
`MOUSE_FILTER_IGNORE`. После выбора Guild-узла появление action-кнопки с
legacy minimum width 360 px расширяло responsive dossier. Шесть deferred
layout-проходов повторно вызывали focus wiring, безусловный initial `grab_focus`
возвращал фокус на `atlas_hub`, а `focus_entered` перезаписывал selection и
отменял button cycle. На 2560 панель уже была достаточно широкой, поэтому
гонка не проявлялась.

Минимальное исправление сохраняет визуальный арт и content zones:

- Atlas socket — явная `MOUSE_FILTER_STOP`-цель с preview на button-down;
- focus-neighbour wiring отделён от однократного initial focus seed;
- deferred layout только обновляет направления и не крадёт текущий Atlas focus;
- отложенный initial seed сначала проверяет, не получил ли уже фокус элемент
  внутри Atlas;
- смена вкладки reseed-ит Guild core/медальон только если прежний focus скрыт,
  удаляется или исчез; живой header focus сохраняется;
- Buy/keystone actions заполняют доступную ширину dossier без 360 px minimum.

## Focused Verification

`tests/atlas_scrum970_clickability_test.gd` отправляет настоящие viewport-local
mouse motion/down/up, а не вызывает `pressed.emit()`. Матрица:
1280×720, 1920×1080, 2048×1152, 2560×1440.

Проверяемый путь: soldier/berserk selectors → class-node preview → explicit
Buy → Guild tab → Guild-node preview → explicit Buy → respec/cancel → Back.
Тест ждёт все responsive layout passes, проверяет visible hitboxes, STOP target,
overlay IGNORE, tooltip и сохранение selection после reflow. До каждой explicit
Buy отдельно проверяется, что preview не меняет `skill_nodes` и валюту; после
Buy проверяется точный расход эмблем/пыли. LB/RB/Tab проверяются в обе стороны,
после каждого rebuild должен оставаться видимый Atlas focus и достижимый d-pad
сосед.

Тест принципиально отказывается запускаться против default `user://`. Runner
передаёт test-only user argument `-- --user-data-dir=<unique scratch root>` и
направляет platform user-data environment в тот же временный root; тест сверяет
`OS.get_user_data_dir()` до создания Main. Поэтому production Buy никогда не
касается реального `fantasydisk_meta.cfg`, а scratch root удаляется runner после
process exit, включая аварийный.

Фактический macOS/Linux invocation pattern (внешний runner владеет cleanup):

```bash
scratch=$(mktemp -d /tmp/fsd-scrum970.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
HOME="$scratch" XDG_DATA_HOME="$scratch" \
  GODOT_BIN=/path/to/Godot \
  python3 tools/godot_gate.py --headless --path . \
  --script res://tests/atlas_scrum970_clickability_test.gd -- \
  --user-data-dir="$scratch"
```

PASS до pre-land review:

- focused real-pointer matrix — headless и windowed;
- `meta40_atlas_screen_smoke_test.gd`, `meta_skill_tree_smoke_test.gd`,
  `skill_tree_per_hero_test.gd`, `meta_progression_smoke_test.gd`;
- `gamepad_menu_focus_test.gd`, `gamepad_full_flow_smoke_test.gd`;
- `dark_fantasy_ui_theme_test.gd`, `ui_no_overlap_matrix_test.gd`;
- `runtime_smoke_ui_test.gd`, полный `runtime_smoke_test.gd` (exit 0; только
  известный dummy-renderer screenshot diagnostic).

Первый независимый read-only review нашёл gamepad reseed, save isolation и
preview-only assertion gaps; все три исправлены, focused/gamepad/no-overlap
повторно PASS. Финальный fresh-disk re-review: PASS, оставшихся actionable
findings нет; `git diff --check` чистый.

Disk cleanup: active task worktree; pending final gates and push.

Thread cleanup: not a disposable worker thread.

## QA-Вердикт (re-QA 2026-07-10)

Статус: PASSED

- QA worker: `qa_scrum1024` (`/root/qa_scrum1024`), Codex lane.
- Fresh production base: `origin/dev` `adf0682383f7`; blocking `SCRUM-1024`
  is QA PASSED / `Готово`, with its closure map landed in `0b79b5469`.
  Production code/assets remained read-only.
- The separate parent re-QA reran
  `atlas_scrum970_clickability_test.gd` headless and through the actual
  windowed Metal/OpenGL DisplayServer. Each process used a unique scratch
  `user://`; both covered class and Guild at `1280×720`, `1920×1080`,
  `2048×1152` and `2560×1440`.
- PASS: viewport-bounded real mouse motion/down/up; live STOP socket targets
  and mouse-ignore overlays; 12-frame preview-only state neutrality; exact
  explicit class/Guild Buy allocation and spend; reset/cancel and Back;
  compact currency/full real-hover tooltip; dossier scroll/reset/focus
  boundary; bottom medallion `follow_focus`; every viewport/frame/content/
  canvas/hitbox bound and node-circle no-overlap.
- The original 1920 clickability defect and the later 1280 off-screen blocker
  are both resolved. Windowed class/Guild screenshots were regenerated and
  inspected; no clipping, hidden action, overlap or frame-ornament intrusion.
- Same-path regression evidence remains green: Meta40/per-hero/progression,
  no-overlap/theme, gamepad menu/full-flow, runtime UI/full,
  animation/combat/targeting. Focused and full runtime gates were repeated
  after every intervening production batch that touched UI/runtime; since the
  last green run, diff audit shows only SCRUM-1028 test/docs/map changes.
- Separate baseline `SCRUM-1029` and non-blocking QA-lifecycle `SCRUM-1031`
  remain independently tracked and do not regress this Atlas acceptance.

Баги: нет открытых blocker-багов для SCRUM-970; `SCRUM-1024` исправлен и
принят.

Disk cleanup: removed the recreated 497 MB `.godot` QA import cache, 25 MB
transient `build/qa/scrum1024` + `scrum970-parent-reqa` screenshots/logs and all
owned scratch roots before the final routing commit. The clean worktree/local
branch removal is recorded in Jira after push.

Thread cleanup: collaboration QA subagent under the active parent task; not a
standalone disposable Codex app task.

## QA-Вердикт — 2026-07-10

Статус: FAILED

- QA worker: `codex-qa-scrum-970-20260710` (`/root/audit_qa`), Codex lane.
- Fresh base: `origin/dev` `bcf966b9f44a8af23db6d3c5dfccc1690dd532f6`.
- Official scratch-isolated focused test: PASS headless/windowed, but QA found
  that its pointer helper permits synthetic coordinates outside the real
  viewport.
- Independent viewport-bounded pointer oracle: FAILED at 1280×720
  class/Constellation. `AtlasSafeArea` is 1601 px wide; Back is
  `x=1208..1468`, dossier `x=1196..1468`, and Buy center `x=1331.7` outside the
  1280 px window. The explicit Buy is therefore not physically clickable.
- Windowed evidence confirms that the class dossier and Back are clipped beyond
  the right frame edge. This violates the real-pointer and frame content-zone
  acceptance rules.
- Passing scope: 1280×720 Guild and both tabs at 1920×1080, 2048×1152 and
  2560×1440. Preview-only state remains unchanged for 12 deferred frames;
  class/Guild overlay/STOP hitboxes, explicit Buy and real shoulder/d-pad
  traversal pass whenever the controls are inside the viewport.
- Production code/assets were not changed by QA.

Blocking bug: `SCRUM-1024` / `docs/tasks/bug_scrum970_atlas_class_dossier_offscreen_1280_task.md`.

Disk cleanup: transient `build/qa/scrum970*`, scratch `user://`, disposable QA
worktree and `.godot` cache are removed after this verdict mirror is committed
and pushed; final Jira comments record exact cleanup.

Thread cleanup: collaboration subagent QA is not a standalone Codex app worker
task; the active parent user task must not be archived.
