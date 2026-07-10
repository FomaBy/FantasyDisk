# BUG: Hero Select level-3 ascension delta is clipped at 1920×1080

Статус: new
Версия: 0.2.1
Jira: SCRUM-1026
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Приоритет: high
Роль: Back-end
Найдено QA при тестировании: SCRUM-980

## Scope And Locks

- responsive height/content allocation of `HS4AscensionFrame` and
  `HS4AscensionDescriptionScroll` in `scripts/ui_screens.gd`;
- all-selectable-level coverage in
  `tests/hero_select_scrum980_ascension_layout_test.gd`;
- this mirror and the current Hero Select UI contract/evidence.

Existing HS4/Atlas art, portraits, animations, progression/balance data and
unrelated screens remain read-only. Claim this issue in Jira before editing and
record worker/worktree/locked paths.

## Reproduction

1. Run fresh `origin/dev` `bb726a00` with a unique scratch `user://` root.
2. At 1920×1080, set a hero's completed ascension progress to `2`; run level
   `3` is then a valid selectable level through `selectable_max()`.
3. Open Hero Select and select level 3.
4. Inspect the complete selected-level delta inside
   `HS4AscensionDescriptionScroll`.

## Expected

The SCRUM-980 Jira contract says the selected-level delta is fully visible at
1920×1080 and 2560×1440. Only 1280×720 requires vertical scrolling. The full
text remains inside the frame content zone without overlapping the stepper,
dossier, counter, carousel, Choose button, or frame ornament.

## Actual

At 1920×1080 the valid level-3 `AscensionModsLabel` is `84.0 px` high while
`HS4AscensionDescriptionScroll` is only `71.33 px` high. The third line is
clipped and the vertical scrollbar remains active. The landed focused test
seeds level 2 (`55 px`) only, so its headless/windowed PASS misses the longer
supported level.

## Acceptance Criteria

- Exercise every selectable ascension level at 1280×720, 1920×1080 and
  2560×1440 using viewport-bounded targets.
- At 1920×1080 and 2560×1440 every selected-level delta is fully visible with
  no active vertical overflow; 1280×720 remains mouse/keyboard/gamepad
  scroll-safe.
- Real pointer `−`/`+` and hero switching reset the description to the first
  line; the cumulative tooltip remains accurate.
- Real keyboard and D-pad Down reach the bottom and transfer focus at the
  boundary; default focus and the full gamepad flow remain green.
- Stepper, description, dossier, counter, carousel, Choose and all decorative
  frame zones remain disjoint at the full responsive matrix.
- Focused Hero Select, no-overlap, dark-theme, runtime UI and full runtime gates
  pass with scratch `user://` roots.

## QA Evidence

- Independent viewport/input oracle: level-3 description `84.0 px` versus
  `71.33 px` scroll viewport at 1920×1080.
- Transient windowed render:
  `build/qa/scrum980-independent-qa/hero_select_independent_1920x1080.png`.
- Official focused test passes because it exercises only the shorter level-2
  delta; independent real input routes otherwise pass.
