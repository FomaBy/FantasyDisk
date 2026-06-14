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

- Hero select uses a fullscreen v4 layout: large portrait left, central dossier, floating top-right radar, and a bottom image-only hero thumbnail strip. SCRUM-281 replaces its screen-specific frames with `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_*` from `docs/design/references/herouiframe/`; SCRUM-320 specifically replaces the bottom `thumbnail_strip` asset with the Carusel reference frame from `docs/design/references/carusel/`. Runtime smoke asserts the description/right dossier edge is left of the radar panel with a real gap at 1280x720, 1600x900 and 2560x1440.
- Hero Select must preserve 720p safe areas: `HeroSelectBackButton` stays inside the top-right viewport, portrait/dossier/radar remain separated, and the bottom thumbnail strip stays fully visible with adaptive image-only previews. The SCRUM-320 Carusel strip is not 9-sliced: it is drawn as one `TextureRect` and scales proportionally (`1024x170` at 720p, `1536x255` at 1080p, `2048x340` at 1440p) so the metal/jewel ornament never stretches on only one axis. Thumbnails are centered in a separate content layer with base margins `Vector4(112, 46, 112, 46)` and adapt `42-124px`; they must never overlap side stones, crests, spikes, or metal borders. QA capture lives at `build/qa/scrum281/hero_select_*.png`; SCRUM-320 copies its acceptance screenshots to `build/qa/scrum320/`.
- Weapon select uses lightweight clickable cards, not parchment/wax button frames. Each card shows `assets/sprites/weapons/<weapon_id>.png` (with legacy Berserk aliases `sword/axe/hammer -> two_handed_*`), title/description, and Russian stat labels: `Дальность`, `Радиус`, `Перезарядка`.
- Level-up reward options remain full-card clickable Buttons for input/focus, but visually use flat text-field/panel styling with rare gold accent instead of the heavy reward button texture. The screen still presents exactly 3 variants and the `Позже` deferral button.

## Button Height / Red & Gold Dragon Rule

Controls that use `ui_btn_red_gold_*` textures must keep the authored dragon
caps and bevel readable. Standard `_make_button()` buttons use the 104px action
height from SCRUM-263/264, main menu uses 380x104, pause uses 280x60,
rebind/dropdown-style controls use 420x62, compact utility uses 54x42 and FAB
uses 50x50. Route nodes, shop item hit areas, hero thumbnails and
weapon/reward cards stay as cards/hit areas instead of receiving heavy action
button frames. Runtime smoke writes `build/qa/red_gold_button_sizes.md`.

Hover/focus states after SCRUM-318 are neutral-bright, not golden glow states:
runtime button themes reuse the normal Red & Gold texture with a neutral tint
(`1.16` hover / `1.20` focus) and near-white hover/focus text. Baked
`*_hover.png` textures remain in the asset kit for compatibility but are not
used by active button themes. Pressed and disabled states keep their dedicated
textures and semantics.

## Main Menu Quit Confirmation

`MainMenuExitButton` and Escape on `MainMenuScreen` open `QuitConfirmationDialog`
instead of quitting immediately. The dialog is a custom game-styled full-screen
modal overlay, not a default Godot `ConfirmationDialog`: it blocks clicks below
the dim layer, focuses safe `Отмена` by default, cancels on Escape/outside click
and calls `Main.request_game_quit()` only from the explicit `Выйти` button.

## Ornate Frame Safe-Area Rule

Controls that use `ui_frame_ornate_*` textures must use the signed
texture/content margins from `UIThemePaths.ORNATE_FRAME_MARGINS` and
`UIThemePaths.ORNATE_FRAME_CONTENT`. Text and icons should sit inside the dark
center field, not on the red metal ornament. If an existing screen needs more
safe-area than the frame provides, treat it as a layout bug for the owning UI
task instead of stretching or cropping the source frame art.

Hero Select is the exception to generic ornate frames: it uses its own
`HERO_SELECT_FRAME_TEXTURES`, `HERO_SELECT_FRAME_MARGINS` and
`HERO_SELECT_FRAME_CONTENT` in `scripts/ui_screens.gd`. The bottom Carusel
thumbnail strip is an additional exception inside Hero Select: it uses
`HERO_SELECT_CAROUSEL_FRAME_BASE_SIZE` and `HERO_SELECT_CAROUSEL_CONTENT_BASE`
with whole-image scaling instead of StyleBoxTexture slicing.
