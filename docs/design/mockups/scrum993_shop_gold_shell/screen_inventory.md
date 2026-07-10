# SCRUM-993 live Shop inventory (read-only Stage 1)

Inventory base: `origin/dev` at `be136ca87667d0e9034da0773259ee44b1e7c567`.

## Runtime tree and behavior

| Area | Current node/API | Stage 1 observation |
| --- | --- | --- |
| Root | `ShopScreen` | Fullscreen Control, no outer shell. |
| Background | `_add_screen_background(root, "shop")` | Resolves canonical `ui_backdrop_merchant_archive.png` as full-viewport cover. New frame would cover important edge art unless the image is clipped/contained inside the shell. |
| Run resources | `_create_menu_run_hud()` | Current 1080p screenshot starts near `(20,12)`, outside the SCRUM-981 safe rect. Must move into the Shop header zone in Stage 2. |
| Upgrade action | `_create_upgrade_fab(root, _show_shop_screen)` | Must remain a separate 50×50 action inside the header safe zone. |
| Header | `ShopHeader` + title/subtitle | Centered at y≈104..190, above the future 1080p safe top y=169. Must use responsive spec rects. |
| Items | `ShopParchmentWall` → `ShopInlineItems` → four `ShopItemButton*` | Current layout is a 2×2 anchor grid in `0.20..0.80 × 0.38..0.75`. New spec uses one horizontal row so all four products and tooltip fit without scroll and more merchant art stays visible. |
| Item content | caption plate, icon, price badge, state overlay | Existing canonical paths are reusable; no new runtime art is required. |
| Tooltip | `tooltip_text` + global tooltip | Current cursor-following tooltip has no shell-safe clamp. New spec reserves a deterministic fixed tooltip band. |
| Back | `ShopLeaveButton` | Current bottom offsets are outside the shell inner content at some targets. New exact footer rects keep it inside. |
| Focus | `_wire_run_ui_focus(shop_focus_items, true, [skip_button], initial)` | Existing product/Back navigation semantics are preserved; one-row geometry makes left/right deterministic. |

## State and persistence APIs that Stage 2 must not change

- `_ensure_shop_stock_for_current_node()` and `_current_shop_node_key()`;
- `current_shop_items`, `current_shop_purchased`, `current_shop_node_key`;
- `_buy_shop_item_at()` / `_buy_shop_item()` one-spend behavior;
- purchased slot disabling and `_add_shop_empty_hook()`;
- insufficient-money no-op + tooltip explanation;
- event shop discount and one-shot `event_shop_exit_action`;
- normal `_return_to_map_after_shop_visit()` and event/combat continuation;
- `_random_shop_items(4)` and all canonical icon/tier/affinity routing.

## Existing production assets

| Purpose | Path | Size/status |
| --- | --- | --- |
| Merchant archive backdrop | `assets/backgrounds/ui/ui_backdrop_merchant_archive.png` | 2560×1440 RGBA, opaque, exact 16:9 |
| Shared gold shell | `assets/sprites/ui/meta40/frame_border.png` | 1536×1024 RGBA, 160px 9-slice margins, transparent center |
| Slot/frame states | `assets/sprites/ui/shop/ui_shop_artifact_slot_{frame,hover}.png` | 256×256 RGBA |
| Caption | `assets/sprites/ui/shop/ui_shop_caption_plate.png` | 1728×624 RGBA 9-slice |
| Price | `assets/sprites/ui/shop/ui_shop_price_badge.png` | 256×96 RGBA |
| Purchased/unavailable | `assets/sprites/ui/shop/ui_shop_purchased_overlay.png` | 256×256 RGBA |
| Tooltip | `assets/sprites/ui/shop/ui_shop_tooltip_frame.png` | 640×320 RGBA |

No runtime or shared documentation file was modified during this inventory.
