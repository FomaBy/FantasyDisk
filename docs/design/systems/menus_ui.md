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

SCRUM-332 adds a Design-ready economy node frame kit for the broader shop/rest/
upgrade/event/attribute cluster. Mockup and spec live in
`docs/design/mockups/scrum332_shop_economy/`; generated source/reference art
lives in `docs/design/references/ui_overhaul_shop_economy/`; contact preview is
`docs/design/previews/scrum332_shop_economy_frame_kit_contact.png`.
Runtime-ready assets:

| Asset ID | File |
| --- | --- |
| `ui_frame_economy_panel` | `assets/sprites/ui/frames/economy/ui_frame_economy_panel.png` |
| `ui_frame_economy_choice_card` | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card.png` |
| `ui_frame_economy_choice_card_hover` | `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_hover.png` |
| `ui_frame_economy_dragon_panel` | `assets/sprites/ui/frames/economy/ui_frame_economy_dragon_panel.png` |
| `ui_frame_economy_price_badge` | `assets/sprites/ui/frames/economy/ui_frame_economy_price_badge.png` |
| `ui_frame_economy_tooltip` | `assets/sprites/ui/frames/economy/ui_frame_economy_tooltip.png` |

SCRUM-406 makes the SCRUM-332 kit live in runtime. Attribute shop, campfire/rest,
upgrade and random event choices use `ui_frame_economy_panel` plus
`ui_frame_economy_choice_card`/hover variants with their safe-zone content
margins. Shop itself keeps compact square wall item hit areas instead of
squashing the tall choice-card art into slots; only the price tag uses
`ui_frame_economy_price_badge`. Use the safe zones from
`docs/design/mockups/scrum332_shop_economy/spec.md`. `ui_frame_economy_dragon_panel`
is irregular: its content may only use the real inner rect to the right of the
dragon head/wing, not the full bounding box. Runtime QA dump:
`build/qa/scrum332/economy_ui_no_overlap_matrix.md`.

SCRUM-413/SCRUM-415 harden the live economy screens for 720p and narrow
viewports: Attribute Shop uses responsive panel width/height, scrollable
content, grid-based attribute offers and compact reachable reroll/skip buttons;
unaffordable attribute cards are disabled, greyed and explain insufficient gold
in tooltip. Random event choices keep long descriptions inside the accepted
choice-card safe zone and normalize risk text so player copy shows a single
`Риск:` prefix, never `Риск: Риск:`.

SCRUM-437 makes the wide 0.1.6 economy choice-card frame live in runtime for
rest, upgrade, event and Attribute Shop choices. Runtime now uses
`assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide.png` and
`ui_frame_economy_choice_card_wide_hover.png` (`960x640`, RGBA transparent) with
source size `Vector2(960, 640)`, texture margins `Vector4(96, 88, 96, 96)`,
content margins `Vector4(132, 118, 132, 128)`, hover content margins
`Vector4(140, 126, 140, 136)` and safe rect `Rect2(132, 118, 696, 394)`.
Display targets are `360x240` at 1280x720, `420x300` at 1920x1080 and
`480x340` at 2560x1440, with a compact 1152px matrix fallback. Attribute Shop
uses extra vertical card space for stat icon/title/interpretation/price text.
Runtime labels, icons and focus/click content stay inside the scaled safe rect;
QA dumps live in `build/qa/scrum437/`. Spec:
`docs/design/mockups/scrum437_wide_economy_choice_card/spec.md`.

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

- Hero select uses a fullscreen master layout where SCRUM-356 supersedes the old separate portrait+dossier frames: `HeroSelectUnifiedFrame` draws `ui_frame_hero_select_unified_panel.png` as one proportional `1536x1024` image and contains the runtime portrait, dossier text and bottom controls only inside the authored safe zones. `HeroSelectRightRegion` remains as a radar reserve, while the actual `HeroSelectRadarPanel` stays a separate floating top-right widget. SCRUM-320/SCRUM-355 keep the bottom `HeroThumbnailStripFrame` as a separate proportional carousel frame. SCRUM-389 makes character selection default the ascension selector to `ascension_selectable_max(character_id)` for that class; the player can still lower or restore the chosen run level with the existing minus/plus controls before selecting a weapon. SCRUM-416 binds every static character portrait surface to the accepted cleaned full-frame idle frame via `ProgressionData.character_config(...).sprite_path`, so Hero Select large portrait, carousel thumbnails, Codex and level-up portraits no longer show legacy static PNGs. SCRUM-417 keeps those portrait paths but switches `HeroSelectLargePortrait` to covered aspect scaling inside the portrait content-zone so the full-frame hero fills the authored safe area more tightly without touching ornament. Runtime smoke asserts unified-frame aspect, safe-zone containment, that the description edge is left of the radar panel with a real gap, ascension max-default/manual-decrease behavior, SCRUM-416 portrait texture paths, SCRUM-417 covered portrait scaling, and no-overlap at 1280x720, 1600x900 and 2560x1440.
- Hero Select must preserve 720p safe areas: `HeroSelectBackButton` stays inside the top-right viewport, portrait/dossier/radar remain separated, and the bottom thumbnail strip stays fully visible with adaptive image-only previews. The SCRUM-320 Carusel strip is not 9-sliced: it is drawn as one `TextureRect` and scales proportionally (`1024x170` at 720p, `1536x255` at 1080p, `2048x340` at 1440p) so the metal/jewel ornament never stretches on only one axis. SCRUM-342 keeps that proportional frame but uses a tighter runtime content-zone `Vector4(72, 36, 72, 36)` plus 2px thumbnail separation, so portraits grow vertically without touching side stones, crests, spikes, or metal borders; QA rects show sample thumbnails `49x66` at 1280x720, `75x101` at 1920x1080 and `101x136` at 2560x1440. SCRUM-321 applies the same no-one-axis-stretch rule to the left portrait: `HeroSelectPortraitPanel` remains the 1/3 layout column, while inner `HeroSelectPortraitFrame` draws `ui_frame_hero_select_portrait.png` as one proportional image (`249x394`, `423x669`, `596x944` at 720p/1080p/1440p). `HeroSelectLargePortrait` is constrained by `HERO_SELECT_PORTRAIT_CONTENT_BASE = Vector4(128, 230, 128, 330)`, keeping the hero off the top crest, side metal and bottom jewel. SCRUM-323 applies the same rule to center dossier: `HeroSelectDossierPanel` centers `HeroSelectDossierFrame`, which draws DescriptionHS `ui_frame_hero_select_dossier.png` as a whole image (`387x394`, `581x591`, `774x788` at 720p/1080p/1440p), while `HeroSelectDossierContent` uses base margins `Vector4(96, 66, 96, 54)` so title, description, ascension controls and choose button stay on the dark field instead of the decorative frame. SCRUM-322 applies the rule to the top-right radar: `HeroSelectRadarPanel` draws the windrose frame as a square whole-image `TextureRect` (`390x390`, `585x585`, `780x780` at 720p/1080p/1440p). After SCRUM-347 the old `HeroStatRadarTitle` is removed; `HeroStatRadar` is the only content in the compass field, centered in the frame, with polygon radius factor `0.36` (+20% from the old 0.30) and tighter label offsets so graph labels remain inside the frame. Do not put labels or graph lines on red gems/spikes/metal tips. QA capture lives at `build/qa/scrum281/hero_select_*.png`; SCRUM-320 copies its acceptance screenshots to `build/qa/scrum320/`; SCRUM-321 rect dump lives at `build/qa/scrum321/hero_select_portrait_rects.md`; SCRUM-323 rect dump lives at `build/qa/scrum323/hero_select_dossier_rects.md`; SCRUM-322/SCRUM-347/SCRUM-342 rect dump lives at `build/qa/hero_select_radar_rects.md`.
- SCRUM-355 supersedes the earlier dossier/carousel content-zone guidance for Design-safe ornament avoidance: the live `ui_frame_hero_select_dossier.png` and `ui_frame_hero_select_thumbnail_strip.png` were recomposed thinner/lighter by `tools/build_hero_select_thin_frames.py`; strict source margins are dossier `Vector4(126, 160, 126, 172)` and thumbnail strip `Vector4(132, 62, 132, 62)`. SCRUM-354 wires those exact source-space margins into runtime, scaling the carousel from its actual `1536x255` source image rather than the `1024x170` 720p display size. Labels, description text, ascension controls, the start button, thumbnails, hover states and selection states stay inside the computed safe rects; the 720p runtime dump shows dossier content `[P: (489, 191), S: (299, 280)]` within the 2px test tolerance of safe `[P: (488.5, 191.3), S: (299.9, 279.3)]`, carousel content `[P: (216, 587), S: (848, 88)]` within the same tolerance of safe `[P: (216, 587.3), S: (848, 87.3)]`, and a 22px gap between dossier and carousel frames. QA rects live in `build/qa/hero_select_radar_rects.md`.
- SCRUM-356 runtime integration: `ui_frame_hero_select_unified_panel.png` is drawn as one proportional `TextureRect`, not 9-sliced or stretched on one axis. Runtime content may only use these source-space safe zones: portrait `Rect2(130,145,420,560)`, description `Rect2(610,145,786,500)`, bottom controls `Rect2(570,705,660,178)`. `ui_frame_hero_select_asc_button_small.png` is the compact `256x256` stepper frame for both `-` and `+`; on compact 720p layouts the ascension delta line is hidden so the row and choose button stay inside `bottom_controls`, while larger layouts show the delta line inside the same safe-zone. QA rects live in `build/qa/hero_select_radar_rects.md`.
- SCRUM-436 prepares the Hero Select v2 rebuild package for Sprint 0.1.6: `docs/design/mockups/scrum436_hero_select_v2/spec.md`, `hero_select_v2_mockup_1920x1080.png`, `hero_select_v2_safe_zones_annotated_1920x1080.png` and `hero_select_v2_layout_metadata.json`. The new design keeps the live SCRUM-322/SCRUM-347 `HeroSelectRadarPanel` / `HeroStatRadar` exactly, then redraws the rest of the screen from scratch: large left hero preview, central dossier/traits/weapons, bottom ascension selector, Select/Back buttons, wide image-only carousel and tooltip safe area. Back-end runtime integration must rebuild `_show_character_select()` from those rects, use one proportional scale factor for 1280x720 / 1920x1080 / 2560x1440, and keep every label, portrait, icon, button, hover highlight and tooltip inside recorded safe zones rather than on frame ornament.
- SCRUM-373/SCRUM-382 add and integrate the unified master frame kit in `assets/sprites/ui/frames/unified/`. SCRUM-384 revises the same preserved runtime paths into a thinner metallic frame with small red corner gems and separate optional dragon overlays. Generic panels/cards/tooltips/HUD/timer frames use a shared StyleBoxTexture builder with tile stretch on both axes and texture margins `72/72/72/72`; filled runtime surfaces use `ui_frame_unified_master_fill.png` for readability, while `ui_frame_unified_master.png` remains the border-only variant. Strict content margins are `88/88/88/88` from the `1024x1024` source (`Rect2(88, 88, 848, 848)` safe rect). Screen-specific whole-image frames with authored source safe zones, including Hero Select SCRUM-356, the radar, carousel and settings tab switcher, stay proportional and are not forced into the generic 9-slice builder. Optional top/bottom unified ornaments remain large-window-only; no runtime content may overlap them.

- SCRUM-396 makes the SCRUM-391 Settings tab switcher live:
`assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`
(`1280x256` RGBA). It has exactly three slots in the red-gold/dark-steel style,
with safe rects `Rect2(160,88,270,82)`, `Rect2(506,88,270,82)` and
`Rect2(852,88,270,82)`. Runtime `SETTINGS_TAB_SWITCHER_FRAME_PATH` points to
this 3-slot asset, `SETTINGS_TAB_SWITCHER_SAFE_RECTS` contains exactly those
three rects, and `SettingsTabButton_3` must not exist.
- SCRUM-439 prepares the Settings v2 rebuild Design package for Sprint 0.1.6:
`docs/design/mockups/scrum439_settings_v2/spec.md`,
`scrum439_settings_v2_mockup.png`, `docs/design/previews/scrum439_settings_v2_safe_zones.png`
and transparent candidate frames in `assets/sprites/ui/frames/settings_v2/`.
The mockup covers all three tabs (`Экран`, `Звук`, `Управление`) and records a
new three-slot tab switcher, modal frame, section panel and control-row safe
zones. Back-end integration must preserve the existing settings/rebind
semantics, keep exactly three tab buttons, and place every label, icon, slider,
dropdown, checkbox, focus ring and scroll bar only inside documented empty safe
zones.

## Combat HUD Redraw

SCRUM-390 prepared the Design-ready combat HUD kit and SCRUM-400 wires it into
the live runtime because `scripts/ui_screens.gd` owns the HUD tree and value
updates. Active assets:

- `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_resource_panel.png`;
- `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_card_hp.png`,
  `_xp.png`, `_gold.png`, `_ult.png`;
- `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_timer.png`;
- `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_ascension_badge.png`;
- `assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus.png` plus
  hover/pressed/disabled states;
- `assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_hp.png`, `_xp.png`,
  `_ult.png`, `_gold.png` and `ui_hud_gold_medallion.png`.

Runtime keeps the combat HUD compact and readable: resource panel top-left,
timer near top center, artifact row top-right with adaptive vertical fallback,
and opaque level-up plus button bottom-right. Text, icons, bars, count badges,
focus/click zones and the plus glyph stay inside the safe rects documented in
`docs/design/references/combat_hud_redraw/combat_hud_redraw_metadata.json`.
Runtime uses compact content margins only to fit the live 720p HUD band; source
safe rects remain the authority and decorative dragon heads, red gems, claw
tips and bevels must stay unobstructed. Design mocks and Back-end runtime rect
dumps at `1152x648`, `1280x720` and `2560x1440` live in `build/qa/scrum390/`.
- Weapon select uses lightweight clickable cards, not parchment/wax button frames. Each card shows `assets/sprites/weapons/<weapon_id>.png` (with legacy Berserk aliases `sword/axe/hammer -> two_handed_*`), title/description, and Russian stat labels: `Дальность`, `Радиус`, `Перезарядка`.
- Level-up reward options remain full-card clickable Buttons for input/focus, but visually use flat text-field/panel styling with rare gold accent instead of the heavy reward button texture. The screen still presents exactly 3 variants and the `Позже` deferral button. SCRUM-348 sets `LevelUpLaterButton` to a non-cropped 260x104 medium back frame.
- SCRUM-404 wires the dedicated SCRUM-338 reward-card frame kit for battle rewards and elite artifact rewards: `assets/sprites/ui/frames/rewards/ui_frame_reward_card.png`, `_hover.png`, `ui_frame_reward_elite_artifact_card.png` and `_hover.png`. Runtime uses the metadata in `docs/design/references/rewards/reward_frames_scrum338_metadata.json`, keeps title, icon, description, artifact tier labels and `Получить`/choice content inside the safe content fields, and preserves whole-card click/focus without placing UI content on red gems, top crests, side metal or bottom ornaments. Runtime smoke writes SCRUM-338 card rect dumps to `build/qa/scrum338/`.

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
the medium back frame; longer `Назад в меню` buttons in Skill Tree and Patch
Notes use 260x104. Codex v2 is the screen-specific exception: SCRUM-438 uses a
compact arrow back button inside the authored `back_button_safe` rect so the
library frame ornament stays unobstructed. Runtime smoke validates their
viewport bounds and content zone sizes and writes
`build/qa/scrum343/back_button_frames.md`.

SCRUM-345 adds a Design-ready Codex-specific texture kit under
`assets/sprites/ui/frames/codex/`:
`ui_frame_codex_main_panel`, `section_panel`, `entry_card`,
`entry_card_hover`, `portrait_slot`, `tooltip`, and `tab` states. Safe content
rects live in `docs/design/references/codex/codex_ui_texture_kit_metadata.json`.
Runtime Codex content must stay inside those rects; portraits, descriptions,
tabs, glossary tooltips and click/focus hitboxes must not sit on decorative
dragon/metal/gem borders. SCRUM-403 wires the kit into `_show_codex_screen`,
Codex tabs, entry cards, portrait/icon slots and `GlossaryTooltipPanel`.
Runtime smoke asserts the actual StyleBoxTexture paths and writes
`build/qa/scrum345/codex_texture_runtime_dump.md`.
SCRUM-417 increases character portrait density by rendering character
`CodexPortraitSlot` textures at `216x216` with covered aspect scaling while
leaving non-character icon slots centered; runtime smoke writes the rect dump to
`build/qa/scrum417/codex_character_portrait_runtime_dump.md`.
SCRUM-438 makes the Codex v2 rebuild live in runtime. `_show_codex_screen` now
builds a real Control hierarchy from the accepted OpenAI mockup/spec:
`CodexMainPanel`, `CodexNavPanel`, vertical `CodexTabs`, `CodexContent` as the
scrollable list page, and `CodexDetailPanel` for selected-entry portrait/chips/
body text. Uniform-scale rects come from
`docs/design/mockups/scrum438_codex_v2/codex_v2_layout_metadata.json` for
1280x720 / 1920x1080 / 2560x1440. The full mockup PNG is not wired as a runtime
atlas; the existing SCRUM-345/SCRUM-403 Codex frame kit remains the component
frame material. Entry cards are focusable buttons, sections still lazy-build
and cache, Escape/back returns to main menu, glossary tooltips keep the Codex
tooltip frame, and character detail portraits keep SCRUM-416 full-frame
`sprite_path` plus SCRUM-417 covered scaling. QA dumps:
`build/qa/scrum438/codex_v2_runtime_dump.md` and
`build/qa/scrum438/codex_v2_no_overlap_matrix.md`.

SCRUM-331 adds a Design-ready progression/skill-tree frame kit while preserving
the SCRUM-345/SCRUM-403 Codex kit as the accepted Codex baseline. Mockup/spec:
`docs/design/mockups/scrum331_progression_codex/`; generated references:
`docs/design/references/ui_overhaul_progression_codex/`; preview:
`docs/design/previews/scrum331_progression_frame_kit_contact.png`. Runtime-ready
assets:

| Asset ID | File |
| --- | --- |
| `ui_frame_progression_main_panel` | `assets/sprites/ui/frames/progression/ui_frame_progression_main_panel.png` |
| `ui_frame_progression_branch_panel` | `assets/sprites/ui/frames/progression/ui_frame_progression_branch_panel.png` |
| `ui_frame_progression_node_available` | `assets/sprites/ui/frames/progression/ui_frame_progression_node_available.png` |
| `ui_frame_progression_node_locked` | `assets/sprites/ui/frames/progression/ui_frame_progression_node_locked.png` |
| `ui_frame_progression_node_purchased` | `assets/sprites/ui/frames/progression/ui_frame_progression_node_purchased.png` |
| `ui_frame_progression_node_focus` | `assets/sprites/ui/frames/progression/ui_frame_progression_node_focus.png` |
| `ui_frame_progression_class_panel` | `assets/sprites/ui/frames/progression/ui_frame_progression_class_panel.png` |
| `ui_frame_progression_points_badge` | `assets/sprites/ui/frames/progression/ui_frame_progression_points_badge.png` |
| `ui_frame_progression_tooltip` | `assets/sprites/ui/frames/progression/ui_frame_progression_tooltip.png` |

Use the safe zones from `docs/design/mockups/scrum331_progression_codex/spec.md`.
Circular skill-node frames must remain square/proportional; long node text should
move to tooltip/adjacent labels instead of sitting on the ornate ring. SCRUM-408
wires the progression kit into `_show_skill_tree_screen`: the main panel, class
progress panel, point badge, branch columns and circular node states use
`assets/sprites/ui/frames/progression/*.png`; Codex stays on the accepted
SCRUM-345/SCRUM-403 kit. Runtime smoke asserts texture paths and ring-safe node
text, while UI matrix dumps live under `build/qa/scrum331/`.

The combat/route `LevelUpPlusButton` is an exception to the flat FAB look: in
combat it uses the SCRUM-390 square plus texture states, remains fully opaque
and anchored bottom-right, and keeps its pending-count badge readable. Runtime
smoke writes `build/qa/combat_level_up_button.md` and
`build/qa/scrum390/combat_level_up_button.md`.

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

## Pause And Result Screens

SCRUM-330 prepared the Design package for pause, pause dossier/stats, victory
and death screens. The generated mockup/spec lives at
`docs/design/mockups/ui_overhaul_pause_end/scrum330_pause_end_mockup_spec.md`;
contact/safe-zone previews are
`docs/design/previews/ui_overhaul_pause_end_contact.png` and
`docs/design/previews/ui_overhaul_pause_end_safe_zones.png`.

Design-ready runtime assets:

| Asset ID | File | Safe-zone |
| --- | --- | --- |
| `ui_frame_pause_end_modal` | `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png` | Source `1280x1024`, safe rect `Rect2(170,180,940,670)`, content margins `Vector4(170,180,170,174)` |
| `ui_crest_victory` | `assets/sprites/ui/result_crests/ui_crest_victory.png` | Decorative header only |
| `ui_crest_defeat` | `assets/sprites/ui/result_crests/ui_crest_defeat.png` | Decorative header only |

Rules:

- draw the modal frame proportionally as a whole image, or integrate it as a
  verified 9-slice only if ornament distortion is checked;
- never stretch the whole frame along one axis;
- keep title/body/buttons/focus/click zones inside the scaled modal safe rect;
- do not place runtime content on dragon heads, wings, side columns, ruby gems,
  bottom crest or outer metal;
- result crests are decorative in this pass and should not become runtime text
  containers.

Runtime connection is implemented in SCRUM-407: `scripts/ui_screens.gd` uses the
modal frame for pause, victory and death menu boxes, while
`scripts/pause_stats_menu.gd` uses the same frame for the pause dossier/stats
overlay. Long stats content scrolls inside the modal safe-zone; result crests
remain decorative header art and 720p result actions use smaller crest/button
sizes so labels and click/focus zones stay off the border ornaments. QA dump:
`build/qa/scrum330/pause_end_ui_no_overlap_matrix.md`.

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

SCRUM-396 uses the design-ready 3-slot Settings tab switcher frame at
`assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`
(`1280x256`, RGBA transparent, no baked text). It is wired into the runtime
settings screen as the `SettingsTabSwitcher` control, displayed at a fixed 5:1
proportional size (`640x128`) so the strip is never stretched on one axis. The
built-in `TabContainer` headers are hidden; `SettingsTabs` still owns the three
settings pages, while `SettingsTabButton_0..2` switch `current_tab`.

Runtime labels/click/focus zones must stay inside these base safe rects and
scale proportionally with the whole image. Runtime smoke validates the actual
button rects against the scaled safe rects:

| Slot | Safe Rect |
| --- | --- |
| `tab_0_screen_safe` | `Rect2(160, 88, 270, 82)` |
| `tab_1_audio_safe` | `Rect2(506, 88, 270, 82)` |
| `tab_2_controls_safe` | `Rect2(852, 88, 270, 82)` |

There is no fourth runtime slot and no fourth hit area. If the settings screen
ever needs another page, Design must provide a new asset and safe-zone metadata
instead of Back-end placing a tab on the existing ornament.

Do not place text, icons, click zones or focus rings on the tab strip's metal
bevels, dragon heads, red gems, dividers or lower rail. Preview:
`docs/design/previews/settings_menu_3slot_switcher_safe_zone.png`; runtime QA
dump: `build/qa/scrum396/settings_tab_switcher_3slot_rects.md`.

The «Управление» tab also contains the `DebugModeToggle` (SCRUM-375). It is a
normal settings checkbox inside `ControlsScroll`, not a fourth tab. The toggle is
OFF by default and persists through `scripts/game_settings.gd`; its tooltip
documents the combat-only debug controls (right-click / Shift+left-click move
target, middle-click teleport).

SCRUM-439 Settings v2 Design handoff is ready but not live. It introduces
candidate assets under `assets/sprites/ui/frames/settings_v2/`:
`ui_frame_settings_v2_main_modal.png`,
`ui_frame_settings_v2_tab_switcher_3slot.png`,
`ui_frame_settings_v2_section_panel.png` and
`ui_frame_settings_v2_control_row.png`. The Back-end rebuild should use
`docs/design/mockups/scrum439_settings_v2/spec.md` as the contract, not infer
usable space from image bounds. The Settings v2 main modal reserves source
content margins `L144 T192 R144 B128`; the v2 switcher safe rects are
`Rect2(150,78,275,92)`, `Rect2(502,78,275,92)` and
`Rect2(854,78,275,92)` from its `1280x256` source. Runtime remains on the
SCRUM-396 switcher until this follow-up lands.

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
