# Menus And UI

Обновлено: 2026-06-14

Этот файл собирает UI-направление FantasyDisk после domain split. Полное фактическое состояние остается в `docs/design/current_game_state.md`, а канонические IDs и assets - в `docs/design/content_registry.md`.

## Shop UI

Магазин должен ощущаться частью shop background, а не отдельным default modal window. Предметы располагаются в центральной свободной зоне canonical backdrop `assets/backgrounds/ui/ui_backdrop_merchant_archive.png`.

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

SCRUM-629 keeps the random event panel from rendering as an empty shell: the
screen root is `EventScreen`, the actual frame stays named `MenuPanel_event`,
and the content column is fixed to the `evt_panel` safe zone as `EventContent`
with visible `EventTitle`, `EventStory`, event choice cards and the back action.
Event scroll no longer follows focus on open, so focusing the first choice
cannot auto-scroll title/story/options out of the initial viewport. The UI
no-overlap matrix now fails if the event panel, title/story, or at least two
choices are missing, empty, clipped, or outside the event frame.

SCRUM-471 adds the 1152x648 short-height guard for Attribute Shop and Settings:
Attribute Shop uses compact `320x240` offer cards plus shorter bottom action
buttons only below 660px viewport height, while Settings permits a compressed
content panel only when the v2 modal is height-constrained. This preserves the
720p+ layout targets and keeps bottom actions reachable in the no-overlap matrix.

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

SCRUM-464 confirms the Rest/Event opaque-matte defect is resolved by the active
minimal-metal cleanup from SCRUM-466. Current Rest/Event economy constants route
panel/card/price/tooltip through `assets/sprites/ui/frames/minimal_metal/`
(`panel`, `card`, `field`, `tooltip`), and the task-specific audit reports `0`
pale/white opaque pixels in both content rects and stretch cores. Evidence:
`build/qa/scrum464/economy_live_frame_matte_audit.md`,
`docs/design/previews/scrum464_economy_matte_free_live_frames.png`; final
renderer-capable screenshot recapture remains QA-only.

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

Main menu uses `assets/backgrounds/main_menu_epic_battle_v3.png` through `MAIN_MENU_BACKGROUND`. SCRUM-560 refreshed the 2560x1440 runtime background with a calm left button-safe column, readable title area, and center-right/lower-right battle focus. The asset is prepared for proportional cover-crop, not one-axis stretching, and contains no baked UI text/buttons/frames.

## Route Map 2K Source

Route Map has a SCRUM-563 2K UI Director source package for the global UI
overhaul. The package is design-source, not a broad runtime rewrite: geometry is
defined in `docs/design/mockups/scrum563_route_map_2k/ui_plan.json` and
`spec.md`, the OpenAI source mockup is
`docs/design/references/scrum563_route_map_2k/route_map_2k_mockup.png`, and the
safe-zone evidence is under `docs/design/previews/scrum563_route_map_2k_*`.
The visual direction is a full-screen scroll field with a thin framed header,
compact run HUD, clamped tooltip panel, centered vertical node lane and small
bottom-right FAB. Runtime text/icons must stay inside the declared interiors.

## Hero / Weapon / Level-Up Layout Rules

- Hero select now uses the SCRUM-447 v3 fullscreen runtime contract. `_show_character_select()` builds a centered proportional `1536x864` `HeroSelectCanvas` from the accepted SCRUM-446 source package in `docs/design/references/hero_select_v3/`: `mockup.png`, corrected `zones.json` / `zones_normalized.json`, `frames_spec.json`, and `hero_select_v3_mockup_spec.md`. The live runtime uses `assets/sprites/ui/frames/hero_select_v3/background.png`, `frame_preview.png`, `frame_dossier.png`, square `frame_radar.png`, and `frame_carousel.png`; Godot import sidecars are required for these runtime assets. Title, Back, preview, dossier, radar and carousel are placed from the v3 source rects, while all labels, portraits, controls, hover highlights and thumbnails stay inside each frame's documented content rect. The live SCRUM-322/SCRUM-347 `HeroSelectRadarPanel` / `HeroStatRadar` compass-rose contract is preserved and rendered inside the square v3 radar content zone without non-uniform stretch. SCRUM-389 ascension selection, SCRUM-416 full-frame portrait routing and SCRUM-417 portrait scaling remain live. Runtime smoke asserts v3 texture loading, proportional canvas aspect, safe-zone containment, preserved radar placement, carousel containment, portrait texture paths/scaling and no-overlap at responsive sizes; QA evidence lives in `build/qa/scrum446_hero_select_v3/`.
- SCRUM-562 updates the live Weapon Select 2K pass. `_show_weapon_select()` now uses a dedicated `WS_PANEL_2K` frame at `420,190,1720,1060` with `WS_SAFE_2K` `498,286,1564,898`; the start-boon screen continues to use the generic `weapon_select` economy panel. Runtime frames are `ws_panel`, `ws_card`, and `ws_btn_back` in `assets/sprites/ui/frames/overhaul_2k/`, registered through `UIThemePaths.OVERHAUL_2K_FRAME_*`. OpenAI/source and safe-zone evidence live under `docs/design/references/scrum562_weapon_select_2k/`, `docs/design/mockups/scrum562_weapon_select_2k/`, and `docs/design/previews/scrum562_weapon_select_2k_*`. Route Map/SCRUM-563 geometry is intentionally untouched.
- Live HS4 Hero Select keeps the same runtime selection contract: carousel arrow
  buttons select previous/next character cyclically in
  `ProgressionData.character_ids()` order and use the same refresh path as
  thumbnail/slot clicks for portrait, dossier, radar, ascension label and
  selected thumbnail state. The arrows remain inside the existing carousel
  content zone; no frame art or safe-zone geometry changes are part of this
  behavior.
- SCRUM-561 updates the live HS4 Hero Select v4 2K pass. Slot-exact assets now
  live under `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_hs4_*.png` and are
  registered in `UIThemePaths.OVERHAUL_2K_FRAME_*`. Runtime content uses scaled
  frame content margins via `_overhaul_2k_content_margins()`: portrait/dossier/radar
  panels use `58/72/58/66`, the carousel uses the horizontal `hud_strip` safe band
  `104/62/104/56`, and choose/ascension buttons use their own 2K button slots.
  No portrait, radar, dossier text/stat row, carousel arrow or thumbnail may be
  positioned against the outer frame bounds.
- The older SCRUM-436 v2 Hero Select contract is superseded by SCRUM-447. Its corrected v2 frame slices and `build/qa/scrum436/` evidence remain historical references only; do not base new runtime Hero Select layout work on `assets/sprites/ui/frames/hero_select_v2/`.
- Historical SCRUM-436 720p safe-area notes: the v2 `HeroSelectBackButton`, portrait/dossier/radar separation and bottom thumbnail strip were fixed with corrected slices in `assets/sprites/ui/frames/hero_select_v2/`. Those files and QA dumps in `build/qa/scrum436/` remain reference evidence only; the active runtime frame kit is SCRUM-447 v3.
- SCRUM-355 supersedes the earlier dossier/carousel content-zone guidance for Design-safe ornament avoidance: the live `ui_frame_hero_select_dossier.png` and `ui_frame_hero_select_thumbnail_strip.png` were recomposed thinner/lighter by `tools/build_hero_select_thin_frames.py`; strict source margins are dossier `Vector4(126, 160, 126, 172)` and thumbnail strip `Vector4(132, 62, 132, 62)`. SCRUM-354 wires those exact source-space margins into runtime, scaling the carousel from its actual `1536x255` source image rather than the `1024x170` 720p display size. Labels, description text, ascension controls, the start button, thumbnails, hover states and selection states stay inside the computed safe rects; the 720p runtime dump shows dossier content `[P: (489, 191), S: (299, 280)]` within the 2px test tolerance of safe `[P: (488.5, 191.3), S: (299.9, 279.3)]`, carousel content `[P: (216, 587), S: (848, 88)]` within the same tolerance of safe `[P: (216, 587.3), S: (848, 87.3)]`, and a 22px gap between dossier and carousel frames. QA rects live in `build/qa/hero_select_radar_rects.md`.
- SCRUM-356 runtime integration: `ui_frame_hero_select_unified_panel.png` is drawn as one proportional `TextureRect`, not 9-sliced or stretched on one axis. Runtime content may only use these source-space safe zones: portrait `Rect2(130,145,420,560)`, description `Rect2(610,145,786,500)`, bottom controls `Rect2(570,705,660,178)`. `ui_frame_hero_select_asc_button_small.png` is the compact `256x256` stepper frame for both `-` and `+`; on compact 720p layouts the ascension delta line is hidden so the row and choose button stay inside `bottom_controls`, while larger layouts show the delta line inside the same safe-zone. QA rects live in `build/qa/hero_select_radar_rects.md`.
- SCRUM-436 runtime integration is complete historical work for Sprint 0.1.6, but SCRUM-447 is the current live Hero Select basis. Do not place future Hero Select labels, portraits, icons, buttons, hover highlights or tooltips outside the SCRUM-446/SCRUM-447 source-space content zones or on frame ornament.
- SCRUM-446 is the Design-source package behind the live SCRUM-447 runtime. Source artifacts live in `docs/design/references/hero_select_v3/` and the UI-director mirror package in `docs/design/mockups/hero_select_v3/`: `mockup.png`, `mockup_zones_annotated.png`, raw `zones_vision_raw.json`, corrected non-overlapping `zones.json` / `zones_normalized.json`, `frames_spec.json`, and `hero_select_v3_mockup_spec.md`. Production frame assets are `assets/sprites/ui/frames/hero_select_v3/frame_preview.png`, `frame_dossier.png`, `frame_radar.png`, `frame_carousel.png`, plus `background.png`. The four transparent frame assets are RGBA with `white_opaque_pixels=0` after cleanup and declare texture/content margins in `frames_spec.json`.
- SCRUM-373/SCRUM-382 add and integrate the unified master frame kit in `assets/sprites/ui/frames/unified/`. SCRUM-384 revises the same preserved runtime paths into a thinner metallic frame with small red corner gems and separate optional dragon overlays. Generic panels/cards/tooltips/HUD/timer frames use a shared StyleBoxTexture builder with tile stretch on both axes and texture margins `72/72/72/72`; filled runtime surfaces use `ui_frame_unified_master_fill.png` for readability, while `ui_frame_unified_master.png` remains the border-only variant. Strict content margins are `88/88/88/88` from the `1024x1024` source (`Rect2(88, 88, 848, 848)` safe rect). Screen-specific whole-image frames with authored source safe zones, including Hero Select SCRUM-356, the radar, carousel and settings tab switcher, stay proportional and are not forced into the generic 9-slice builder. Optional top/bottom unified ornaments remain large-window-only; no runtime content may overlap them.
- SCRUM-448 adds the Design-source package for the 0.1.6 minimalist UI restyle
  while preserving SCRUM-273 Red & Gold buttons. The accepted direction is:
  non-button frames/panels/tooltips/HUD surfaces move toward calm graphite /
  obsidian fills, thin aged-brass rails and tiny ruby pins, with no heavy dragon
  curls or gem overload. OpenAI style-board, transparent frame kit, exact
  `content_rect_xywh` metadata and responsive rules live in
  `docs/design/mockups/scrum448_ui_minimalist/spec.md` and
  `docs/design/references/ui_minimal/scrum448_minimal_ui_frame_metadata.json`.
  Runtime assets live in `assets/sprites/ui/frames/minimal/` and all audit at
  `white_opaque_pixels=0`. SCRUM-449 makes this kit live for non-button generic
  panels/cards/tooltips, Settings shell/switcher/content panel, Codex
  shell/list/detail/tooltip, economy choice cards/price badges, reward cards,
  pause/result shells and compact combat HUD wrappers. SCRUM-273 Red & Gold
  buttons stay unchanged, and screen-specific authored frames such as Hero Select
  v3, progression circular nodes and combat bar fills remain exceptions. QA
  evidence lives in `build/qa/scrum448_ui_minimalist/`.

- SCRUM-452 adds the Design-source anchor for the next strict minimal-metal UI
  series. Source boards, style guide and metadata live under
  `docs/design/references/ui_minimal_metal/`, the UI-director spec mirror is
  `docs/design/mockups/scrum452_ui_minimal_metal/spec.md`, previews are
  `docs/design/previews/scrum452_minimal_metal_anchor_contact.png` and
  `docs/design/previews/scrum452_minimal_metal_safe_zones.png`, and runtime
  candidates live in `assets/sprites/ui/frames/minimal_metal/`. The six frames
  are RGBA with `white_opaque_pixels=0` and exact `content_rect_xywh` metadata.
  SCRUM-459 wires them as first-class runtime theme paths/constants plus a shared
  tiled StyleBoxTexture helper and metadata guard, but does not promote them over
  SCRUM-448 live generic frames yet. SCRUM-462 separately promotes SCRUM-450
  minimal-metal buttons as the active action-button contract.

- SCRUM-450 adds the Design-ready minimal-metal button kit. Source/spec assets
  live under `docs/design/references/ui_minimal_metal_buttons/` and
  `docs/design/mockups/scrum450_ui_minimal_metal_buttons/spec.md`; runtime
  assets live in `assets/sprites/ui/frames/minimal_metal_buttons/` as 15
  button types x 5 states. All candidates are transparent RGBA and audit at
  `white_opaque_pixels=0`. SCRUM-462 promotes the kit for live action-button
  families while preserving card/hit-area exceptions. Hover/focus preserve
  SCRUM-318 no-yellow semantics on dedicated `_hover`/`_focus` PNGs, and runtime
  labels/icons stay inside the metadata `content_rect_xywh` rather than on caps,
  bevels or ruby pins. QA evidence lives in
  `build/qa/scrum450_minimal_metal_buttons/`.

- SCRUM-451 adds the Design-source rollout contract for applying SCRUM-452
  minimal-metal frames across all UI screens. The screen-family mapping lives in
  `docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_matrix.json`
  with the UI-director spec at
  `docs/design/mockups/scrum451_ui_minimal_frames_rollout/spec.md`. It maps
  main menu, Settings, Hero Select, Codex, Shop, Rewards, Level-up, Events,
  Pause, Results, Combat HUD, tooltips and dialogs onto the six frame families
  `modal`, `panel`, `card`, `tooltip`, `hud_strip` and `field`. SCRUM-463 makes
  this rollout live for generic runtime surfaces by promoting the SCRUM-452
  minimal-metal frame paths/margins/content metadata in `scripts/ui/ui_theme_paths.gd`
  and `scripts/ui_screens.gd`; `scripts/pause_stats_menu.gd` also uses the
  minimal-metal modal/panel/field/tooltip family. Hero Select v3 authored frames,
  progression node rings and combat bar fills/icons remain screen-specific
  exceptions. Runtime content must use only each frame's `content_rect_xywh`;
  QA evidence is in `build/qa/scrum451_minimal_metal_rollout/`.

- SCRUM-585 refreshes the `GlossaryTooltipPanel` as an isolated 2K tooltip
  frame. Runtime keeps the existing dynamic placement contract (`460` fixed
  width, content-driven height, `8px` anchor gap, `16px` viewport clamp) and now
  uses the regenerated `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png`
  with strict content margins `Vector4(66, 44, 66, 40)`. Generated mockup/spec
  and safe-zone evidence live under
  `docs/design/mockups/scrum585_glossary_tooltip/` and
  `docs/design/previews/scrum585_glossary_tooltip_*`. Runtime text stays inside
  the empty center and never covers the metal rails, ruby pins, or corner claws.

- SCRUM-588 refreshes the transient `LevelUpToast` as an isolated generated @2K
  frame asset. Runtime uses
  `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png` through
  `UIThemePaths.OVERHAUL_2K_FRAME_*["lut_toast"]` at source size `480x300`,
  texture margins `58/48/58/48`, and strict content margins `70/112/70/112`.
  The toast remains textless; the existing world-space level-up badge is still
  the single `Level Up` text/icon callout. Sparkle/ring content starts inside
  the frame safe rect only. Mockup/spec and audit evidence live in
  `docs/design/mockups/scrum588_levelup_toast/`,
  `docs/design/references/scrum588_levelup_toast/`, and
  `docs/design/previews/scrum588_levelup_toast_safe_zone.png`.

- SCRUM-654 keeps the overhead level-up callout compact and singular. Runtime
  uses the accepted `LevelUpPopupBadge` at `160x80`; when multiple level-ups
  arrive quickly, `_spawn_level_up_effect()` removes older live `LevelUpEffect`
  nodes from the `level_up_effects` group before spawning the replacement.
  `LevelUpToast` stays outside that cleanup group and remains a textless
  sparkle/ring cue, so there is only one visible `Level Up` text badge.

- SCRUM-396 makes the SCRUM-391 Settings tab switcher live:
`assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`
(`1280x256` RGBA). It has exactly three slots in the red-gold/dark-steel style,
with safe rects `Rect2(160,88,270,82)`, `Rect2(506,88,270,82)` and
`Rect2(852,88,270,82)`. Runtime `SETTINGS_TAB_SWITCHER_FRAME_PATH` points to
this 3-slot asset, `SETTINGS_TAB_SWITCHER_SAFE_RECTS` contains exactly those
three rects, and `SettingsTabButton_3` must not exist.
- SCRUM-439 integrates the Settings v2 rebuild runtime for Sprint 0.1.6:
`docs/design/mockups/scrum439_settings_v2/spec.md`,
`scrum439_settings_v2_mockup.png`, `docs/design/previews/scrum439_settings_v2_safe_zones.png`
and transparent candidate frames in `assets/sprites/ui/frames/settings_v2/`.
The mockup covers all three tabs (`Экран`, `Звук`, `Управление`) and records a
new three-slot tab switcher, modal frame, section panel and control-row safe
zones. Runtime now uses the v2 main modal and v2 proportional 3-slot switcher,
preserves the existing settings/rebind semantics, keeps exactly three tab
buttons, and places labels, icons, sliders, dropdowns, checkboxes, focus rings
and scroll bars only inside modal safe areas. The dense live body uses a flat
inner safe panel rather than the optional section/control-row frames, because
those candidates' source margins would clip controls or collide with the Back
button at 720p.

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
compact character stat chips below the resource panel, and opaque level-up plus button bottom-right. Text, icons, bars, count badges,
focus/click zones and the plus glyph stay inside the safe rects documented in
`docs/design/references/combat_hud_redraw/combat_hud_redraw_metadata.json`.
Runtime uses compact content margins only to fit the live 720p HUD band; source
safe rects remain the authority and decorative dragon heads, red gems, claw
tips and bevels must stay unobstructed. Design mocks and Back-end runtime rect
dumps at `1152x648`, `1280x720` and `2560x1440` live in `build/qa/scrum390/`.
SCRUM-556 moves the in-run Escape pause panel to the upper-left gameplay area and
adds `CharacterStatsHud`, a compact four-chip base-stat strip under
`RunResourceHud`, using existing minimal-metal frames and runtime stat data.
SCRUM-521 adds `LowHpVignetteOverlay` as a procedural combat HUD warning:
when player HP drops below 30%, a shader vignette fades in with a transparent
center and light red edges; it fades out only after HP recovers to 34%+ to avoid
threshold flicker. The overlay is drawn behind HUD cards, ignores mouse input,
uses the shared `combat_feedback` setting, and is covered by the HUD smoke
matrix.
- Weapon select uses lightweight clickable cards, not parchment/wax button frames. Each card shows `assets/sprites/weapons/<weapon_id>.png` (with legacy Berserk aliases `sword/axe/hammer -> two_handed_*`), title/description, and Russian stat labels: `Дальность`, `Радиус`, `Перезарядка`.
- Level-up reward options remain full-card clickable Buttons for input/focus, but visually use flat text-field/panel styling with rare gold accent instead of the heavy reward button texture. The screen still presents exactly 3 variants and the `Позже` deferral button. SCRUM-465 makes the overlay viewport-aware: short 720p layouts use compact panel/card/header metrics and a shorter medium back-frame deferral button, while larger viewports keep the same safe-zone contract without bottom cropping. The UI no-overlap matrix covers `LevelUpPanel`, `LevelUpHeroHeader`, all three reward cards and `LevelUpLaterButton`; QA evidence lives under `build/qa/scrum465/`.
- SCRUM-571 adds the Design-source 2K ordinary reward mockup/spec package for the post-battle reward selection screen. Source geometry and safe-zone files live under `docs/design/mockups/scrum571_reward_2k/`, the OpenAI base layer under `docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png`, and previews under `docs/design/previews/scrum571_reward_2k_*.png`. This is not runtime-integrated yet; future Back-end wiring must keep title, subtitle, three reward icons, titles, bodies, choice labels and footer text inside the declared empty content zones and off metal rails, gems, corners and dragon ornaments.
- SCRUM-572 adds the Design-source 2K elite artifact reward mockup/spec package for the elite victory artifact-choice screen. Source geometry and safe-zone files live under `docs/design/mockups/scrum572_elite_artifact_reward_2k/`, the OpenAI base layer under `docs/design/references/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_base.png`, and previews under `docs/design/previews/scrum572_elite_artifact_reward_2k_*.png`. This is not runtime-integrated yet; future Back-end wiring must keep artifact icons, names, tier badges, descriptions, receive buttons and footer hint inside declared empty content zones and off metal rails, card crests, ruby sockets, dragon claws and bottom ornaments.
- SCRUM-404 wires the dedicated SCRUM-338 reward-card frame kit for battle rewards and elite artifact rewards: `assets/sprites/ui/frames/rewards/ui_frame_reward_card.png`, `_hover.png`, `ui_frame_reward_elite_artifact_card.png` and `_hover.png`. Runtime uses the metadata in `docs/design/references/rewards/reward_frames_scrum338_metadata.json`, keeps title, icon, description, artifact tier labels and `Получить`/choice content inside the safe content fields, and preserves whole-card click/focus without placing UI content on red gems, top crests, side metal or bottom ornaments. Runtime smoke writes SCRUM-338 card rect dumps to `build/qa/scrum338/`.

## Button Height / Minimal Metal Rule

Controls that use `ui_btn_minimal_metal_*` textures must keep the authored caps,
bevels, ruby pins and back-arrow ornaments readable. Standard `_make_button()`
buttons use the 104px action height from SCRUM-263/264, main menu uses 380x104,
pause uses 280x60,
rebind/dropdown-style controls use 420x62, compact utility uses 54x42 and FAB
uses 50x50. Route nodes, shop item hit areas, hero thumbnails and
weapon/reward cards stay as cards/hit areas instead of receiving heavy action
button frames. Runtime smoke writes
`build/qa/scrum450_minimal_metal_buttons/minimal_metal_button_sizes.md`.

Back buttons use the minimal-metal `back_*` family and must not be squeezed into
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

SCRUM-574 refreshes the live Codex v2 frame material to a dedicated 2K kit while
preserving the SCRUM-438 three-column geometry. The accepted mockup/spec lives
at `docs/design/mockups/scrum574_codex_2k/spec.md`, with the OpenAI API source
mockup at `docs/design/references/scrum574_codex_2k/codex_2k_mockup.png`.
Runtime assets are generated by `tools/build_ui_2k_frame_kit.py --all` into
`assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_*.png` for main, nav,
list, detail, entry card, tab button and back button slots. `CodexMainPanel`,
`CodexNavPanel`, `CodexContent`, `CodexDetailPanel`, `CodexEntryCard`,
`CodexTab_*` and `CodexBackButton` must use those slot-exact frames; portraits
and text still stay inside the recorded content margins and never overlap the
ornamental rails.

SCRUM-331 adds a Design-ready progression/skill-tree frame kit while preserving
the SCRUM-345/SCRUM-403 Codex kit as the historical Codex component package.
SCRUM-574 is the live Codex 2K frame baseline. Mockup/spec:
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
runtime button themes use the SCRUM-450 minimal-metal `_hover` / `_focus`
textures with neutral tint (`1.16` hover / `1.20` focus) and near-white
hover/focus text. Pressed and disabled states keep their dedicated textures and
semantics.

## Main Menu Quit Confirmation

`MainMenuExitButton` and Escape on `MainMenuScreen` open `QuitConfirmationDialog`
instead of quitting immediately. The dialog is a custom game-styled full-screen
modal overlay, not a default Godot `ConfirmationDialog`: it blocks clicks below
the dim layer, focuses safe `Отмена` by default, cancels on Escape/outside click
and calls `Main.request_game_quit()` only from the explicit `Выйти` button.

SCRUM-344 locks the dialog action buttons to 220x72 and SCRUM-462 routes
`QuitConfirmExitButton` / `QuitConfirmCancelButton` to the minimal-metal `pause`
button frame, whose vertical content band is safe at 72px. Do not let these buttons
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

SCRUM-439 supersedes the older SCRUM-396 switcher-only runtime with the full
Settings v2 modal. The live settings screen now draws
`assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_main_modal.png` and
the design-ready 3-slot switcher
`assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_tab_switcher_3slot.png`
(`1280x256`, RGBA transparent, no baked text). The switcher is displayed as a
whole-image proportional 5:1 strip so it is never stretched on one axis. The
built-in `TabContainer` headers are hidden; `SettingsTabs` still owns the three
settings pages, while `SettingsTabButton_0..2` switch `current_tab`.

Runtime labels/click/focus zones must stay inside these base safe rects and
scale proportionally with the whole image. Runtime smoke validates the actual
button rects against the scaled safe rects:

SCRUM-626 fixes Settings return-origin tracking. Settings opened from the main
menu returns to the main menu on Back/Escape, while Settings opened from the
in-run pause/dossier flow returns to the run pause menu and preserves the active
run state instead of rebuilding the start screen.

| Slot | Safe Rect |
| --- | --- |
| `tab_0_screen_safe` | `Rect2(150, 78, 275, 92)` |
| `tab_1_audio_safe` | `Rect2(502, 78, 275, 92)` |
| `tab_2_controls_safe` | `Rect2(854, 78, 275, 92)` |

There is no fourth runtime slot and no fourth hit area. If the settings screen
ever needs another page, Design must provide a new asset and safe-zone metadata
instead of Back-end placing a tab on the existing ornament.

Do not place text, icons, click zones or focus rings on the tab strip's metal
bevels, dragon heads, red gems, dividers or lower rail. Preview:
`docs/design/previews/scrum439_settings_v2_safe_zones.png`; runtime QA dumps:
`build/qa/scrum439/settings_v2_runtime_rects.md` and
`build/qa/scrum439/settings_v2_no_overlap_matrix.md`.

The «Управление» tab also contains the `DebugModeToggle` (SCRUM-375). It is a
normal settings checkbox inside `ControlsScroll`, not a fourth tab. The toggle is
OFF by default and persists through `scripts/game_settings.gd`; its tooltip
documents the combat-only debug controls (right-click / Shift+left-click move
target, middle-click teleport).

SCRUM-497 adds `CombatFeedbackToggle` to the same «Управление» tab. It is a
normal checkbox row inside `ControlsScroll`, persists as `combat_feedback` in
`user://settings.cfg`, defaults ON, and controls floating damage/heal numbers,
critical markers and hit flash/outline visuals without changing gameplay.

SCRUM-441 is integrated in the same Settings pass. Resolution options use
`scripts/display_resolution.gd` to compare requested window sizes against the
physical usable monitor size (`usable_logical * screen_scale`) instead of only
logical points; `_apply_video_settings()` clamps with
`DisplayResolution.clamp_to_physical(...)`, macOS adds a detected logical native
`(Mac)` option when needed, and `project.godot` enables
`window/dpi/allow_hidpi=true`. QA evidence:
`build/qa/scrum441/hidpi_resolution_evidence.md`.

## SCRUM-478 Bright Minimalist Full UI Anchor

SCRUM-478 is the Design-source anchor for the next full-game minimalist UI
redesign. The source package is not wired into runtime yet. Back-end must use
`docs/design/mockups/scrum478_minimalist_full_ui_redesign/spec.md` and
`docs/design/references/minimalist_full_ui_redesign/scrum478_minimalist_full_ui_metadata.json`
before changing live menus.

Covered screen families: main menu, hero select, weapon select, combat HUD,
level-up, rewards, shop, attribute shop, event, codex, settings, patch notes,
feedback, pause, results, global tooltips and badges.

The anchor keeps the global hard frame rule:

- every frame/button/chip has an exact `content_rect_xywh` for `1280x720`,
  `1600x900` and `1920x1080`;
- runtime labels, icons, portraits, meters, focus rings and hit areas must stay
  inside that content rect;
- border rails, accent diamonds, gold ticks and glow caps are decoration only;
- exact-size PNGs are preferred; if Back-end uses 9-slice, only the flat center
  may stretch and the metadata margins are mandatory.

Runtime integration and render/no-overlap/text-overflow QA are tracked in
`docs/tasks/backend_minimalist_full_ui_redesign_runtime_handoff_task.md`.

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
