# BUG: Atlas class dossier and Buy are off-screen at 1280×720

Статус: done
Версия: 0.2.1
Jira: SCRUM-1024
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-1024`
Приоритет: high
Роль: Back-end
Найдено QA при тестировании: SCRUM-970

## Scope And Locks

- Atlas responsive class/Constellation layout only in `scripts/ui_screens.gd`;
- viewport-bound assertions in `tests/atlas_scrum970_clickability_test.gd`;
- this bug mirror and Atlas UI documentation/evidence.

Guild layout, Meta data/economy, Atlas art, preview-only semantics and unrelated
screens remain read-only. Claim in Jira before editing and record the actual
worker/worktree/locked paths.

## Reproduction

1. Run on fresh `origin/dev` `bb726a00` with a unique scratch `user://` root.
2. Open Atlas at 1280×720 on `Созвездие`.
3. Select `berserk_m0` with viewport mouse motion/down/up.
4. Wait 12 deferred responsive layout frames.
5. Attempt to use `Назад` or explicit `Вложить эмблему` with a physical pointer.

## Expected

`AtlasSafeArea`, all header controls, the node dossier and explicit Buy remain
fully inside the real 1280×720 viewport and empty frame content zone. Socket
selection remains preview-only; allocation occurs only through the visible Buy
button.

## Actual

In the class/Constellation state:

- `AtlasSafeArea` expands to 1601 px while the viewport is 1280 px;
- `AtlasBackButton`: `x=1208..1468`;
- `AtlasNodePanel`: `x=1196..1468`;
- `AtlasBuyButton` center: `x=1331.7`.

The right dossier and Back control are visually clipped outside the frame/window.
`SubViewport.push_input()` still accepts those synthetic off-viewport
coordinates, so the original focused helper can report a false-positive Buy.
The viewport-bounded independent pointer oracle rejects the unreachable target.

1280×720 Guild and class/Guild at 1920×1080, 2048×1152 and 2560×1440 pass.

## Acceptance Criteria

- At 1280×720 both tabs keep `AtlasSafeArea` at or inside the viewport.
- Back, dossier, Buy and every live hitbox are fully inside the viewport and
  empty frame content zone.
- Real pointer motion/down/up selects preview; 12 deferred frames do not cancel
  selection or mutate purchases/currency.
- Explicit visible Buy performs the exact allocation/spend.
- Focused test refuses any pointer target center outside `viewport.visible_rect`.
- 1280/1920/2048/2560 headless and windowed pointer matrices pass with scratch
  `user://`; no-overlap/theme/gamepad/meta/runtime gates remain green.

## QA Evidence

- `build/qa/scrum970-independent-qa/class_preview_1280x720.png` — transient
  screenshot showing the clipped class dossier/header.
- Independent bounded oracle error records the exact safe/header/dossier/Buy
  rectangles above.

## Implementation Result

Root cause was Container minimum propagation. At 1280×720 the authored frame
content zone is 1014×526, but the header required 1335 px (`3×260` action plates,
two verbose currency chips and gaps) and the dossier required 420 px height
because progress/hint labels sat outside its scroll. `MarginContainer` therefore
expanded `AtlasSafeArea` to 1601×768 and synthetic SubViewport coordinates hid
the real reachability failure.

The fix preserves the accepted art, margins, panel width, graph and explicit
Buy contract:

- at safe width below 1420 px currency chips show icon + exact numeric count;
  the full localized phrase/count is always retained in the tooltip;
- description, condition/lore, progress and hidden-star hint share the existing
  focusable `AtlasNodeScroll`; price and Buy remain pinned below it, and every
  node/class/tab refresh resets the scroll to its first line;
- focused `ui_up/down` scrolls dossier overflow and transfers to Back/Buy at
  boundaries; compact chip icon/label children route real hover to the full
  currency tooltip on their parent;
- `AtlasClassStrip.follow_focus` exposes the ninth row at 720p;
- `tests/atlas_scrum970_clickability_test.gd` now refuses any pointer target
  outside the real viewport, derives the frame content rect independently,
  checks all live buttons and all visible node circles/canvas bounds, verifies
  compact/full currency semantics and exercises the last medallion focus path.

Post-fix 1280×720 metrics: `AtlasSafeArea` 1280×720, `AtlasLayout` 1014×526,
header min 930, body 1014×372, panel min 280, canvas 629×372, Back
`887..1147`, dossier `875..1147`, Buy `886..1135`. Full currency labels,
wide-screen art/content zones and interaction semantics remain active at
1920/2048/2560; internal scroll allocation is intentionally responsive.

Focused headless + windowed class/Guild matrices PASS on 1280×720,
1920×1080, 2048×1152 and 2560×1440. `meta40_atlas_screen_smoke_test.gd`,
`ui_no_overlap_matrix_test.gd`, gamepad menu/full-flow, dark theme,
meta progression, per-hero skill tree and full runtime smoke PASS. The unrelated
legacy `meta_skill_tree_smoke_test.gd::_test_shop_discount` currently fails on
the unchanged baseline because the seeded discounted sample is replaced by a
higher-cost rare set; no Atlas UI code/data in this task touches that path.

Independent pre-land review found dossier gamepad/reset and real tooltip-hover
gaps; both were fixed and covered with physical `InputEventAction`/pointer
events. Final read-only re-review: PASS, no actionable findings remain;
`git diff --check` is clean.

Landed to `origin/dev` in commit `5f39a56ea`. Jira moved to
`Контроль качества`; independent production QA remains required before
`Готово`.

Disk cleanup: removed the 444 MB task `.godot/` import cache, 31 MB transient
`build/qa/scrum1024/` evidence and the three isolated `/tmp/fsd-scrum1024-*`
user roots; the clean task worktree/branch is removed after this routing commit.

Thread cleanup: not a disposable worker thread.
