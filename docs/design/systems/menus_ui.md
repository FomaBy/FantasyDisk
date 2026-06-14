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

Main menu uses `assets/backgrounds/main_menu_epic_battle_v2.png` through `MAIN_MENU_BACKGROUND`. SCRUM-316 keeps the battle focus center-right/lower-right, leaving the left third for the vertical button stack and the top-center area for the title. The asset is native 2560x1440 and was prepared with proportional cover-crop, not one-axis stretching.

## Hero / Weapon / Level-Up Layout Rules

- Hero select uses a fullscreen master layout where SCRUM-356 supersedes the old separate portrait+dossier frames: `HeroSelectUnifiedFrame` draws `ui_frame_hero_select_unified_panel.png` as one proportional `1536x1024` image and contains the runtime portrait, dossier text and bottom controls only inside the authored safe zones. `HeroSelectRightRegion` remains as a radar reserve, while the actual `HeroSelectRadarPanel` stays a separate floating top-right widget. SCRUM-320/SCRUM-355 keep the bottom `HeroThumbnailStripFrame` as a separate proportional carousel frame. Runtime smoke asserts unified-frame aspect, safe-zone containment, that the description edge is left of the radar panel with a real gap, and no-overlap at 1280x720, 1600x900 and 2560x1440.
- Hero Select must preserve 720p safe areas: `HeroSelectBackButton` stays inside the top-right viewport, portrait/dossier/radar remain separated, and the bottom thumbnail strip stays fully visible with adaptive image-only previews. The SCRUM-320 Carusel strip is not 9-sliced: it is drawn as one `TextureRect` and scales proportionally (`1024x170` at 720p, `1536x255` at 1080p, `2048x340` at 1440p) so the metal/jewel ornament never stretches on only one axis. SCRUM-342 keeps that proportional frame but uses a tighter runtime content-zone `Vector4(72, 36, 72, 36)` plus 2px thumbnail separation, so portraits grow vertically without touching side stones, crests, spikes, or metal borders; QA rects show sample thumbnails `49x66` at 1280x720, `75x101` at 1920x1080 and `101x136` at 2560x1440. SCRUM-321 applies the same no-one-axis-stretch rule to the left portrait: `HeroSelectPortraitPanel` remains the 1/3 layout column, while inner `HeroSelectPortraitFrame` draws `ui_frame_hero_select_portrait.png` as one proportional image (`249x394`, `423x669`, `596x944` at 720p/1080p/1440p). `HeroSelectLargePortrait` is constrained by `HERO_SELECT_PORTRAIT_CONTENT_BASE = Vector4(128, 230, 128, 330)`, keeping the hero off the top crest, side metal and bottom jewel. SCRUM-323 applies the same rule to center dossier: `HeroSelectDossierPanel` centers `HeroSelectDossierFrame`, which draws DescriptionHS `ui_frame_hero_select_dossier.png` as a whole image (`387x394`, `581x591`, `774x788` at 720p/1080p/1440p), while `HeroSelectDossierContent` uses base margins `Vector4(96, 66, 96, 54)` so title, description, ascension controls and choose button stay on the dark field instead of the decorative frame. SCRUM-322 applies the rule to the top-right radar: `HeroSelectRadarPanel` draws the windrose frame as a square whole-image `TextureRect` (`390x390`, `585x585`, `780x780` at 720p/1080p/1440p). After SCRUM-347 the old `HeroStatRadarTitle` is removed; `HeroStatRadar` is the only content in the compass field, centered in the frame, with polygon radius factor `0.36` (+20% from the old 0.30) and tighter label offsets so graph labels remain inside the frame. Do not put labels or graph lines on red gems/spikes/metal tips. QA capture lives at `build/qa/scrum281/hero_select_*.png`; SCRUM-320 copies its acceptance screenshots to `build/qa/scrum320/`; SCRUM-321 rect dump lives at `build/qa/scrum321/hero_select_portrait_rects.md`; SCRUM-323 rect dump lives at `build/qa/scrum323/hero_select_dossier_rects.md`; SCRUM-322/SCRUM-347/SCRUM-342 rect dump lives at `build/qa/hero_select_radar_rects.md`.
- SCRUM-355 supersedes the earlier dossier/carousel content-zone guidance for Design-safe ornament avoidance: the live `ui_frame_hero_select_dossier.png` and `ui_frame_hero_select_thumbnail_strip.png` were recomposed thinner/lighter by `tools/build_hero_select_thin_frames.py`; strict source margins are dossier `Vector4(126, 160, 126, 172)` and thumbnail strip `Vector4(132, 62, 132, 62)`. SCRUM-354 wires those exact source-space margins into runtime, scaling the carousel from its actual `1536x255` source image rather than the `1024x170` 720p display size. Labels, description text, ascension controls, the start button, thumbnails, hover states and selection states stay inside the computed safe rects; the 720p runtime dump shows dossier content `[P: (489, 191), S: (299, 280)]` within the 2px test tolerance of safe `[P: (488.5, 191.3), S: (299.9, 279.3)]`, carousel content `[P: (216, 587), S: (848, 88)]` within the same tolerance of safe `[P: (216, 587.3), S: (848, 87.3)]`, and a 22px gap between dossier and carousel frames. QA rects live in `build/qa/hero_select_radar_rects.md`.
- SCRUM-356 runtime integration: `ui_frame_hero_select_unified_panel.png` is drawn as one proportional `TextureRect`, not 9-sliced or stretched on one axis. Runtime content may only use these source-space safe zones: portrait `Rect2(130,145,420,560)`, description `Rect2(610,145,786,500)`, bottom controls `Rect2(570,705,660,178)`. `ui_frame_hero_select_asc_button_small.png` is the compact `256x256` stepper frame for both `-` and `+`; on compact 720p layouts the ascension delta line is hidden so the row and choose button stay inside `bottom_controls`, while larger layouts show the delta line inside the same safe-zone. QA rects live in `build/qa/hero_select_radar_rects.md`.
- Weapon select uses lightweight clickable cards, not parchment/wax button frames. Each card shows `assets/sprites/weapons/<weapon_id>.png` (with legacy Berserk aliases `sword/axe/hammer -> two_handed_*`), title/description, and Russian stat labels: `Дальность`, `Радиус`, `Перезарядка`.
- Level-up reward options remain full-card clickable Buttons for input/focus, but visually use flat text-field/panel styling with rare gold accent instead of the heavy reward button texture. The screen still presents exactly 3 variants and the `Позже` deferral button. SCRUM-348 sets `LevelUpLaterButton` to a non-cropped 260x104 medium back frame.

## Button Height / Red & Gold Dragon Rule

Controls that use `ui_btn_red_gold_*` textures must keep the authored dragon
caps and bevel readable. Standard `_make_button()` buttons use the 104px action
height from SCRUM-263/264, main menu uses 380x104, pause uses 280x60,
rebind/dropdown-style controls use 420x62, compact utility uses 54x42 and FAB
uses 50x50. Route nodes, shop item hit areas, hero thumbnails and
weapon/reward cards stay as cards/hit areas instead of receiving heavy action
button frames. Runtime smoke writes `build/qa/red_gold_button_sizes.md`.

Back buttons use the Red&Gold `back_*` family and must not be squeezed into
ornament-cropping widths. `HeroSelectBackButton` uses 240x104 so it resolves to
the medium back frame; longer `Назад в меню` buttons in Skill Tree, Patch Notes
and Codex use 260x104. Runtime smoke validates their viewport bounds and content
zone sizes and writes `build/qa/scrum343/back_button_frames.md`.

The combat/route `LevelUpPlusButton` is an exception to the flat FAB look: it
uses the Red&Gold `main_menu` frame for visual weight, remains fully opaque and
anchored bottom-right, and keeps its pending-count badge readable. Runtime smoke
writes `build/qa/combat_level_up_button.md`.

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

SCRUM-344 locks the dialog action buttons to 220x72 and routes
`QuitConfirmExitButton` / `QuitConfirmCancelButton` to the Red&Gold `pause`
button frame, whose vertical margins are safe at 72px. Do not let these buttons
fall back to `back_s`: that frame is authored for taller action buttons and
visually squashes when used in this dialog. Runtime smoke records the actual
rects and textures in `build/qa/scrum319/quit_confirmation_dialog.md`.

## Feedback Overlay

`P` opens `FeedbackOverlayLayer`, a separate top-level overlay that does not call
`_clear_ui()` and therefore does not reset the underlying combat, route map,
shop, event, level-up or reward screen. The overlay contains `FeedbackTextEdit`,
`FeedbackScreenshotPreview`, `FeedbackSendButton` and `FeedbackCancelButton`.
Escape closes only this overlay, while normal text input remains inside the text
field.

The screenshot is captured before the overlay is created. Sending is handled by
`scripts/feedback_reporter.gd`: webhook reports use Discord-compatible
multipart payloads, while missing/failed webhook delivery falls back to
`user://feedback/<timestamp>/`. Details: `docs/design/systems/feedback_reporting.md`.

## Settings Tabs

SCRUM-325 adds a design-ready Settings tab switcher frame at
`assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png`
(`1280x256`, RGBA transparent, no baked text). SCRUM-334 wires it into the
runtime settings screen as the `SettingsTabSwitcher` control, displayed at a
fixed 5:1 proportional size so the strip is never stretched on one axis.
The built-in `TabContainer` headers are hidden; `SettingsTabs` still owns the
three settings pages, while `SettingsTabButton_0..2` switch `current_tab`.

Runtime labels/click/focus zones must stay inside these base safe rects and
scale proportionally with the whole image. Runtime smoke validates the actual
button rects against the scaled safe rects:

| Slot | Safe Rect |
| --- | --- |
| `tab_0_active_safe` | `Rect2(146, 78, 178, 82)` |
| `tab_1_safe` | `Rect2(414, 91, 178, 74)` |
| `tab_2_safe` | `Rect2(693, 91, 178, 74)` |
| `tab_3_safe` | `Rect2(969, 91, 162, 74)` |

Only the first three slots are interactive in 0.1.5. The fourth slot remains
ornamental/empty until a fourth settings page exists.

Do not place text, icons, click zones or focus rings on the tab strip's metal
bevels, red gems, side arrows, spikes or lower rail. Preview:
`docs/design/previews/settings_tab_switcher_frame_content_zone.png`.

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
The portrait frame is also image-only after SCRUM-321: use
`HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE` and
`HERO_SELECT_PORTRAIT_CONTENT_BASE`; do not turn it back into a 9-slice or
stretchable StyleBox.
The windrose radar frame is image-only after SCRUM-322: use
`HERO_SELECT_RADAR_FRAME_SOURCE_SIZE`, `HERO_SELECT_RADAR_FRAME_BASE_SIZE` and
`HERO_SELECT_RADAR_CONTENT_BASE`; do not turn it back into a rectangular
PanelContainer/StyleBox.
SCRUM-355 adds the strict Hero Select frame content zones documented in
`build/qa/scrum355/hero_select_thin_frames_qa.md`; use those margins when
integrating the thinner dossier and thumbnail strip assets.
