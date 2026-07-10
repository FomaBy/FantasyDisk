# BUG: Atlas class dossier and Buy are off-screen at 1280×720

Статус: new
Версия: 0.2.1
Jira: SCRUM-1024
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
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

1. Run on fresh `origin/dev` `bcf966b9` with a unique scratch `user://` root.
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

