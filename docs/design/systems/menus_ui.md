# Menus And UI

Обновлено: 2026-06-11

Этот файл собирает UI-направление FantasyDisk после domain split. Полное фактическое состояние остается в `docs/design/current_game_state.md`, а канонические IDs и assets - в `docs/design/content_registry.md`.

## Shop UI

Магазин должен ощущаться частью shop background, а не отдельным default modal window. Предметы располагаются в центральной свободной зоне `assets/sprites/ui/screens/screen_shop_background.png`.

Design-ready assets:

| Asset ID | File |
| --- | --- |
| `ui_shop_artifact_slot_frame` | `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png` |
| `ui_shop_artifact_slot_hover` | `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png` |
| `ui_shop_price_badge` | `assets/sprites/ui/shop/ui_shop_price_badge.png` |
| `ui_shop_purchased_overlay` | `assets/sprites/ui/shop/ui_shop_purchased_overlay.png` |
| `ui_shop_tooltip_frame` | `assets/sprites/ui/shop/ui_shop_tooltip_frame.png` |

Rules:

- show artifact/shop item icon and price directly on the shop background;
- show description/effects only in hover tooltip;
- keep purchased/unavailable state visible through `ui_shop_purchased_overlay`;
- avoid large default windows that cover the merchant/background art;
- preserve HP/XP/money HUD visibility where current UI requires it.

Full mapping and layout metrics: `docs/design/artifact_shop_cursor_visual_kit.md`.

## Cursor

FantasyDisk uses a custom visible cursor:

| Asset ID | File | Hotspot |
| --- | --- | --- |
| `ui_game_cursor` | `assets/sprites/ui/cursor/game_cursor.png` | `(5, 4)` |
| `ui_game_cursor_hover` | `assets/sprites/ui/cursor/game_cursor_hover.png` | `(5, 4)` |
| `ui_game_cursor_attack` | `assets/sprites/ui/cursor/game_cursor_attack.png` | `(5, 4)` |

Back-end owns runtime cursor setup and optional state switching.
