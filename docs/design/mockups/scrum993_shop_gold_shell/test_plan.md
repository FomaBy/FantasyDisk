# SCRUM-993 Stage 2 verification plan

This contract is implemented by `tests/scrum993_shop_gold_shell_test.gd` plus
the shared gates listed below. SCRUM-981 locks were released before Stage 2.

## Geometry oracle

For 1280×720, 1920×1080 and 2560×1440:

1. Build `ShopScreen` from a deterministic four-item fixture.
2. Assert `ShopGoldFrame` uses
   `res://assets/sprites/ui/meta40/frame_border.png`, source 1536×1024,
   texture/content margins scaled from 160px, `draw_center=false`, final child,
   z=100, mouse-ignore.
3. Assert frame safe and inner content rects exactly match `spec.md` (1px
   tolerance only for rounded independent X/Y scaling).
4. Assert the background path is the canonical merchant archive, clipped to
   frame safe rect, `STRETCH_KEEP_ASPECT_CENTERED`, and the visible image rect
   matches the non-cropped table. Alpha/source edges all remain represented.
5. Assert HUD, title, subtitle, four slot hitboxes, tooltip and Back stay
   inside inner content and outside the ornament reserve.
   Assert `UpgradeFabButton` is absent from Shop and the former FAB reserve has
   no hitbox/focus target (SCRUM-982 reconciliation).
6. Assert all sibling hitboxes are pairwise non-overlapping. Caption, icon,
   affinity badge and price stay inside their parent slot.
7. Assert no horizontal/vertical Shop scrollbar exists: exactly four items fit.
8. Reuse an existing screen instance and test live resize 2560×1440→1280×720;
   geometry and content margins must update without rebuilding stock.

## Visual/state oracle

- Default: all four icons/captions/prices visible, no tooltip until focus/hover.
- Focus/hover: fixed tooltip becomes visible in its dedicated band and contains
  full title, effect, price and state reason; no cursor-following ornament escape.
- Unaffordable: slot remains focusable, icon desaturated, price red, press does
  not spend, tooltip says insufficient money.
- Purchased: one spend only, slot disabled, purchased/`снято` state visible,
  icon/price do not overlap, focus skips it.
- Long caption: single-line ellipsis inside the caption plate; tooltip keeps full
  text.
- Four-digit price and foreign-class affinity badge stay inside the slot.

## Behavior oracle

- Re-enter the same normal Shop node: item IDs and purchased vector unchanged.
- Leave normal Shop: route return callable runs once, stock remains available
  for the same node.
- Event shop with discount: price transform applies once, exit action consumed
  once, event/combat route continuation preserved.
- A/Enter buys; B/Escape and Back call the same leave action.
- Focus starts at first not-purchased item, cycles left/right, reaches Back via
  down, and returns to a product via up. Mouse remains hybrid.

## Required gates after implementation

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/scrum993_shop_gold_shell_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_inrun_ui_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/gamepad_full_flow_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd
```

Windowed capture: default, hover/focus, unaffordable, purchased and live-resize
screens at all three resolutions. Store persistent accepted captures under
`docs/design/previews/scrum993_shop_gold_shell/runtime/` and transient rect logs
under `build/qa/scrum993/` only when Stage 2 is authorized.
