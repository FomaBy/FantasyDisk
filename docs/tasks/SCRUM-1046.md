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

Independent QA: pending after direct push to `origin/dev`.

Disk cleanup: active task worktree; cleanup pending final gates and push.

Thread cleanup: not a disposable worker thread.
