# SCRUM-1046 — Hero Select 720p dossier keyboard/gamepad scrolling

Статус: done
Версия: 0.2.1
Jira: SCRUM-1046
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-next4`
Branch: `codex/scrum1046-dossier-scroll`
Blocks: SCRUM-952

## Scope And Locks

Only the local `HS4DossierScroll.gui_input` contract in
`scripts/ui_screens.gd`, physical input assertions in
`tests/hero_select_scrum952_trait_copy_test.gd`, this evidence mirror, the
SCRUM-952 mirror and matching Hero Select input paragraphs are writable.

Trait/Codex data, copy, frame/portrait/ascension/carousel/stat geometry and all
art remain unchanged. The accepted SCRUM-952 PixelLab source
`c72b6dba-895e-4f6a-93a1-1a5a36934a54` and its frame-safe zones are reused;
this blocker changes input only.

## Root Cause

`HS4DossierScroll` had `FOCUS_ALL` and a bottom focus neighbour but no local
`gui_input` handler. A focusable `ScrollContainer` does not guarantee the menu's
scroll-first behavior: `ui_down` immediately followed the focus graph to
`HS4ChooseButton`, while PageDown did nothing. At 1280×720 Druid has 104 px of
real overflow, leaving lower copy inaccessible without a mouse.

## Decision

Mirror the proven local contracts already used by
`HS4AscensionDescriptionScroll` and `AtlasNodeScroll`:

- consume `ui_down` / `ui_page_down` and `ui_up` / `ui_page_up` while scroll
  content remains;
- move by 65% of the visible lane, with a 12 px minimum;
- retain dossier focus while scrolling;
- only at top/bottom hand focus to the explicit Back/Choose neighbour;
- preserve hero-change reset to zero.

No global `_input`/`_unhandled_input` hook is added. Right stick is not
special-cased because the canonical configurable UI bindings are D-pad and
left stick; stealing raw motion would bypass rebind policy and other screens.

## Focused Verification

`hero_select_scrum952_trait_copy_test.gd` now sends physical press/release
events into the 1280×720 `SubViewport` for keyboard Up/Down/PageUp/PageDown and
gamepad D-pad Down. It asserts scroll-first focus retention, top/bottom boundary
handoff, real overflow and carousel hero-change reset, while retaining all 17
class/copy/frame checks at 720p/1080p/2K.

PASS before land:

- focused SCRUM-952/1046 test headless and actual windowed Metal;
- `hero_select_pixellab_layout_test.gd` and SCRUM-1026 all-level ascension
  layout/input test;
- `gamepad_menu_focus_test.gd`, `gamepad_full_flow_smoke_test.gd`;
- `ui_no_overlap_matrix_test.gd`;
- `runtime_smoke_ui_test.gd` and isolated full `runtime_smoke_test.gd`.

The runtime suites emit the known dummy-renderer screenshot diagnostic but exit
0 and report PASS. No visual capture changed because production geometry/art is
unchanged; the focused Metal lifecycle is clean.

## QA-Вердикт (2026-07-11)

Статус: PASSED

QA owner: QA/Codex `/root/qa_scrum1046_952` on fresh `origin/dev`
`48af1122a`. Exact implementation/evidence/routing commits `9070a85a9`,
`50c5c5277` and `48af1122a` were verified as ancestors of production `dev`.

The blocker is independently fixed:

- at 1280×720 the real Druid dossier overflow is exercised by physical
  keyboard Down/Up/PageDown/PageUp and physical D-pad Down press/release;
- the dossier scrolls before navigation and retains focus while content
  remains, then hands focus only at the top/bottom boundary to Back/Choose;
- changing the selected hero resets `scroll_vertical` to zero;
- all 17 class copies preserve `Особенность → Плюсы → Минусы`, exact
  shared/Codex projections and frame-safe layout at 720p/1080p/2K;
- focused test passes headless and actual Metal. The Metal lifecycle log is
  clean: no `SCRIPT ERROR`, `ObjectDB` leak, resources-still-in-use, Ogg or
  `ERROR:` diagnostics;
- visual review of all three renderer captures confirms that content stays in
  the frame's empty inner zone. At 1080p/2K all three decision sections are
  visible; at 720p the remaining copy is reachable through the verified lane;
- `hero_select_pixellab_layout_test.gd`, SCRUM-1026 ascension layout/input,
  `gamepad_menu_focus_test.gd`, two consecutive
  `gamepad_full_flow_smoke_test.gd` runs, `ui_no_overlap_matrix_test.gd`,
  `runtime_smoke_ui_test.gd` and isolated `runtime_smoke_test.gd` all pass.

Production audit: the change is confined to the dossier's local `gui_input`
handler and focused assertions. It adds no global input hook, raw right-stick
path, trait/data/art mutation or visual geometry change. The accepted SCRUM-952
PixelLab source `c72b6dba-895e-4f6a-93a1-1a5a36934a54` and validated
content-zone package are reused unchanged.

Verdict: **PASSED**. SCRUM-1046 may move to `Готово`; its lock is released
before sequential parent re-QA of SCRUM-952.

Implementation commit: `9070a85a9`, rebased without conflict on accepted
SCRUM-971 QA evidence `069d47a4f` and pushed directly to `origin/dev`.
Post-rebase focused, gamepad full-flow and isolated full runtime gates PASS.

Disk cleanup: removed the 446 MiB task `.godot` cache, 7.7 MiB SCRUM-952 Metal
captures and all owned isolated HOME/XDG scratch roots. The clean task worktree
is retained only until independent QA dispatch is recorded.

Thread cleanup: not a disposable worker thread.
