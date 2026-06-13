# Back-end Task: Refactor `ui_screens.gd` Into Domain UI Modules

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-174
Jira: SCRUM-199
Эпик: epic_full_project_quality_pass

## Scope

Split `scripts/ui_screens.gd` into focused UI modules without behavior changes.

## Required Boundaries

- Preserve public node names used by tests.
- Keep `ui_screens.gd` as compatibility facade until callers are migrated.
- Extract: main menu, hero select, settings, codex, level-up/rewards, shop, noncombat screens, run HUD, common styles.
- Do not change visual design or gameplay behavior.

## Verification

- Runtime smoke, animation smoke, meta progression, meta skill tree, melee targeting, attack VFX, hazard VFX all pass.
- Existing UI no-overlap checks remain green.

## Serialization

High conflict risk. Run only when no active task is editing `scripts/ui_screens.gd` or UI tests.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress. High-conflict task; only start when no active UI edits.

## Blocked / Serialized (2026-06-13)

Blocked by active UI dependency churn. SCRUM-222 is waiting on the accepted
SCRUM-147 UI frame kit, and current UI no-overlap/theme work still depends on
stable screen/style behavior. Splitting `scripts/ui_screens.gd` while UI assets
and tests are still settling would create high-conflict noise.

Next unblock: resume after SCRUM-147/SCRUM-222 is unblocked and active UI edits
are closed. No UI module split was started.

## Dispatcher Unblock / Dispatch (2026-06-13)

Unblocked for a serialized Back-end refactor window: SCRUM-222 is `Готово`,
SCRUM-147/SCRUM-229 are in QA rather than active code work, SCRUM-203 is
`Готово`, and `scripts/ui_screens.gd` was clean in git status. Dispatched to
Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as item 4 after
SCRUM-202, SCRUM-196 and SCRUM-198. Keep reasoning High/no low; do not change
visual design or absorb Design/Animator scope.

## Blocked / Release Freeze (2026-06-13)

Blocked for the v0.1.4 stabilization freeze. This is a high-conflict structural
refactor of `scripts/ui_screens.gd`, not a bug, QA defect, regression or release
blocker. It also conflicts with the just-landed SCRUM-231 hero-select bugfix in
the same file, so starting the module split now would add unnecessary release
risk.

Next unblock: resume after v0.1.4 release / feature-freeze lift, or if PM
explicitly reclassifies the UI module split as a release blocker. No UI module
split was started in this window.

## PM Override / Redispatch (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Release-freeze blocker снят именно для уже существующих board-задач. Redispatch
в существующий Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` как
последовательный queue item после SCRUM-230 и SCRUM-198. Keep reasoning High/no
low. Не начинать параллельно с работой, которая меняет `scripts/ui_screens.gd`
или UI smoke tests; сохранить визуал/поведение, закрыть task/board/Jira sync
перед переходом к следующей queued задаче. Если всплывает motion/animation
scope, создать/update Animator handoff вместо выполнения animation work.

## Result (2026-06-13)

Done with a conservative release-safe split. `scripts/ui_screens.gd` remains the
compatibility facade with all public methods and tested node names intact, while
the lowest-risk focused UI domains moved into `scripts/ui/` modules:

- `scripts/ui/hero_stat_radar.gd` — standalone `HeroStatRadar` `Control`.
- `scripts/ui/ui_theme_paths.gd` — dark-fantasy frame/button texture paths.
- `scripts/ui/shop_ui_constants.gd` — shop icon paths, slot sizes and cursor
  variant paths.
- `scripts/ui/hero_select_constants.gd` — hero radar stat IDs and class colors.

The facade aliases those constants/classes, so existing screen code, tests and
callers continue to use the same names. No visual design, gameplay behavior,
node names, button flow, shop behavior, HUD layout or animation behavior was
intentionally changed.

Verification passed:

- `tests/runtime_smoke_ui_test.gd`
- `tests/animation_smoke_test.gd`
- `tests/meta_progression_smoke_test.gd`
- `tests/meta_skill_tree_smoke_test.gd`
- `tests/melee_weapon_targeting_test.gd`
- `tests/attack_vfx_smoke_test.gd`
- `tests/hazard_vfx_smoke_test.gd`
- `tests/runtime_smoke_test.gd`

Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`,
`docs/design/systems/technical_architecture.md`.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 361e45c7 (ветка dev)

Проверено (фактически):
- **Facade цел**: `ui_screens.gd` сохранил публичную поверхность — 25 `_show_*`-
  методов на месте; вынесены 4 lowest-risk домена в `scripts/ui/`
  (hero_select_constants, hero_stat_radar, shop_ui_constants, ui_theme_paths).
- **Поведение/раскладка не изменены** (регрессия зелёная): `runtime_smoke_ui_test`,
  `ui_no_overlap_matrix_test` (1152/1280/1469/2560), `animation_smoke_test`,
  `meta_progression_smoke_test`, `melee_weapon_targeting_test`. Имена тестируемых
  узлов сохранены (no-overlap и UI-тесты находят их).
- **Дерево чистое/закоммичено** (`git status scripts/` пусто), зелёное.

Acceptance:
- [x] Сплит `ui_screens.gd` на focused UI-модули без изменения поведения.
- [x] `ui_screens.gd` остался compatibility facade (public-методы/узлы целы).
- [x] UI / animation / meta / melee / VFX / smoke зелёные.

Примечание: umbrella `runtime_smoke` прогоняется 32× в SCRUM-257-серии на этом коде.

Баги: нет.
