# BUG: Hero Select level-3 ascension delta is clipped at 1920×1080

Статус: done
Версия: 0.2.1
Jira: SCRUM-1026
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-1026`
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

## Implementation Plan / UI Director Decision

The accepted visual source remains
`docs/design/mockups/hero_select_black_minimal/spec.md`; this bug does not add,
redraw or replace any art/frame asset. Before runtime editing, SCRUM-1026 adds
the responsive geometry amendment
`docs/design/mockups/hero_select_black_minimal/scrum1026_ascension_level3_responsive_spec.md`.
The band keeps its bottom edge anchored above the carousel and may grow only
upward into the already scroll-safe dossier budget. Carousel, counter, portrait,
CTA and every authored frame/content margin remain unchanged.

## Implementation Result

Root cause: the SCRUM-980 band height was capped at 100 px but resolved to only
85.33 px at 1920×1080, leaving a 71.33 px description viewport. The focused
gate unlocked level 3 but initialized only the shorter level-2 delta, so it did
not exercise the maximum supported copy.

The accepted geometry now applies a 132 px minimum only when the physical
viewport height is at least 1000 px. The existing bottom anchor remains
`carousel_top - gap`; the top edge moves upward and consumes only the
scroll-safe dossier height. Compact 1280×720 uses 69 px so its real 59 px
utility row remains inside 5 px top/bottom frame content margins, and retains
its intentional internal scroll. No art, texture/content margin, portrait,
carousel/counter or Choose geometry changed. The manual row/description
positions now use the existing StyleBox's actual horizontal `pad × 1.4` inset,
so both content zones remain inside the authored empty frame interior. The two
compact external gaps are 1 px each (still positive/non-overlapping), reclaiming
the seven added frame pixels without shrinking the fixed eight-row dossier
stats column.

`tests/hero_select_scrum980_ascension_layout_test.gd` now unlocks and exercises
every selectable level 0..5 in both directions with viewport-bounded real
pointer motion/down/up, verifies the exact delta and cumulative tooltip, checks
physical viewport/major-zone bounds, sends a real mouse-wheel event, follows
the actual keyboard/D-pad scroll boundary to Choose, and switches heroes with a
real slot click to prove scroll reset.

Measured worst cases after the fix:

- 1280×720: level 3 is `89 px` label / `59 px` viewport / `30 px` overflow;
  the narrower content-safe inset makes level 5 the worst case at
  `112 / 59 / 53 px`; both are fully reachable through the intentional compact
  scroll path;
- 1920×1080: levels 3/5 `84 px` label / `118 px` viewport / zero overflow;
- 2560×1440: levels 3/5 `55 px` label / `114 px` viewport / zero overflow.

PASS: focused all-level test headless and actual windowed; inspected screenshots
at 1280×720, 1920×1080 and 2560×1440; `ui_no_overlap_matrix_test.gd`,
`dark_fantasy_ui_theme_test.gd`, `hero_select_pixellab_layout_test.gd`,
`gamepad_menu_focus_test.gd`, `gamepad_full_flow_smoke_test.gd`,
`meta_progression_smoke_test.gd`, `runtime_smoke_ui_test.gd` and full
`runtime_smoke_test.gd` (known dummy-renderer screenshot warning only).

Independent pre-land review found and then re-verified four concrete gaps:
the live ScrollContainer hover tooltip, real StyleBox vertical/horizontal
content insets, physical key/D-pad coverage and the compact dossier budget.
All were fixed. Final read-only verdict: PASS, no actionable findings remain;
the scoped Godot `.gd.uid` sidecar is included with the focused test.

Landed to `origin/dev` in implementation commit `7aa4850bb`. Jira moved to
`Контроль качества`; independent production QA remains required before
`Готово`.

Disk cleanup: removed the 444 MB task `.godot/` cache, 11 MB transient
`build/qa/scrum1026/` evidence and all `/tmp/fsd-scrum1026-*` scratch user
roots; the clean task worktree/branch is removed after the routing commit.

Thread cleanup: not a disposable worker thread.
