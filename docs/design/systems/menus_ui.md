# Menus And UI

Обновлено: 2026-06-14

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
| `ui_game_cursor` | `assets/sprites/ui/cursor/game_cursor.png` | `(2, 2)` |
| `ui_game_cursor_hover` | `assets/sprites/ui/cursor/game_cursor_hover.png` | `(2, 2)` |
| `ui_game_cursor_attack` | `assets/sprites/ui/cursor/game_cursor_attack.png` | `(2, 2)` |

Back-end owns runtime cursor setup and optional state switching.

## Screen Backdrops

Central-window screens use role-specific dark fantasy backdrops from `assets/backgrounds/ui/` through `SCREEN_BACKGROUND_PATHS` and `_add_screen_background()`:

| Screen role IDs | Backdrop |
| --- | --- |
| `system`, `settings`, `codex`, `hero_select`, `weapon_select`, `pause_stats`, `meta_tree`, `campfire` | `assets/backgrounds/ui/ui_backdrop_system_cathedral.png` |
| `shop` | `assets/backgrounds/ui/ui_backdrop_merchant_archive.png` |
| `event`, `upgrade`, `level_up`, `meta_progression` | `assets/backgrounds/ui/ui_backdrop_arcane_lab.png` |
| `elite_reward`, `victory`, `artifact_reward` | `assets/backgrounds/ui/ui_backdrop_reward_hall.png` |
| `death`, `defeat`, `end_run_confirm` | `assets/backgrounds/ui/ui_backdrop_defeat_crypt.png` |

Backdrops are full-rect `TextureRect` nodes with cover scaling and a readable shade layer. Route map and combat arena backgrounds remain separate systems.

## Hero / Weapon / Level-Up Layout Rules

- Hero select uses a fullscreen v3 layout: large portrait left, bottom hero thumbnail strip, and one right-side info panel. Inside that panel `HeroSelectDossier` stays left of `HeroSelectRadarPanel`; runtime smoke asserts the description/right dossier edge is left of the radar panel with a real gap at 1280x720, 1600x900 and 2560x1440.
- Weapon select uses lightweight clickable cards, not parchment/wax button frames. Each card shows `assets/sprites/weapons/<weapon_id>.png` (with legacy Berserk aliases `sword/axe/hammer -> two_handed_*`), title/description, and Russian stat labels: `Дальность`, `Радиус`, `Перезарядка`.
- Level-up reward options remain full-card clickable Buttons for input/focus, but visually use flat text-field/panel styling with rare gold accent instead of the heavy reward button texture. The screen still presents exactly 3 variants and the `Позже` deferral button.

## Button Height / Wax Seal Rule

Controls that use `ui_df_button_*` Parchment & Wax Seal textures must keep enough height for the seal to remain readable. Standard `_make_button()` buttons use 68px minimum height and left content padding for the seal. Compact utility controls (`+/-`, FAB, keybinding fields, dropdowns) use flat no-seal styling instead of squeezing the seal texture. Runtime smoke writes `build/qa/parchment_button_seal_sizes.md`.
