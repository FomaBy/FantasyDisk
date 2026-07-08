# Menus And UI

Обновлено: 2026-07-03

Этот файл собирает UI-направление FantasyDisk после domain split. Полное фактическое состояние остается в `docs/design/current_game_state.md`, а канонические IDs и assets - в `docs/design/content_registry.md`.

## SCRUM-692 Runtime Readability Pass

SCRUM-692 increases runtime UI readability without changing gameplay, economy,
progression, save data, or generated art. `scripts/ui_screens.gd` now routes
player-facing font overrides through a viewport-aware scale: about `1.32x` on
short `648p` layouts and `1.45x` at `864p+`, with per-screen caps where a larger
font would leave a frame content zone. Tight safe-zone exceptions include Codex
tabs, rebind conflict actions, combat title banner, Level Up later button,
economy-card action labels, reward cards, and compact combat HUD labels.

`scripts/ui_icon_registry.gd` scales common icon requests up by `1.45x` through
`72px` and `1.20x` through `100px`; larger authored icons stay at source size.
Screens with narrow card safe-zones request smaller fit icons instead of
allowing content to cover frame ornament. Menu HUD is shifted slightly upward on
720p screens so the enlarged HUD strip does not overlap shop headers.

Acceptance coverage: `tests/ui_no_overlap_matrix_test.gd` includes `1536x864`,
`1920x1080`, and `2560x1440`; required smoke tests are
`runtime_smoke_ui_test.gd`, `runtime_smoke_test.gd`, and
`ui_icon_registry_smoke_test.gd`. Screenshot evidence is written by
`tests/design_review_screenshot_capture_test.gd` to
`build/qa/design_review/` for Hero Select, Level Up, Shop, Codex, Settings, and
Combat HUD at `1280x720`, `1920x1080`, and `2560x1440`.

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
SCRUM-639 fixes the follow-up visual regression from the release gate: Event no
longer creates the disabled `UpgradeFabButton` inside `MenuPanel_event`. That
extra child made the `PanelContainer` lay out a lone upgrade arrow over an empty
gray interior in screenshots, hiding title/story/choices/back even though basic
rect checks still passed. The matrix now explicitly forbids `UpgradeFabButton`
on Event and requires `EventContent`, title, story, choices and back to remain
inside the scaled `evt_panel` content safe rect.
SCRUM-672 applies the same release-gate lesson to Rest: `_show_rest_screen()`
must keep `UpgradeFabButton` on the screen root, never inside
`MenuPanel_campfire`, so the campfire panel continues to show `RestContent`,
`RestTitle`, `RestSubtitle`, the two rest choice cards and `RestBackButton`.
The UI matrix now fails if Rest regresses to a blank panel/up-arrow-only shell or
if the Rest content disappears from the campfire panel.

SCRUM-996 adds conditional/hidden outcomes to the Event screen without visual
redesign (the visual layer is SCRUM-997):

- **Hidden choices.** A choice with `hidden: true` never reveals its outcome on
  the card: the description shows `unknown_hint` (fallback «Исход неизвестен…»)
  and the action text is «Рискнуть». `cost_money` price is not printed on a
  hidden card's action button, so hidden paid choices must mention the price in
  `unknown_hint` (data contract, `scripts/event_data.gd`).
- **Reveal state.** If the applied outcome has `outcome_text`, or the choice was
  `hidden`, or a stat `check` ran, the screen switches to a reveal state after
  the outcome is applied: `EventStory` text is replaced by `outcome_text` plus a
  check-result line («Проверка <Стат> <N> — пройдена/провалена»), the
  `EventChoiceRow` cards and `EventBackButton` hide, and a single
  `EventContinueButton` («В путь», the standard 260-wide action plate) appears
  and grabs focus (the SCRUM-477 focus chain collapses to this one button, its
  neighbors loop to itself). Only pressing it clears `current_event_definition`
  and advances the route (`_advance_route_after_noncombat`). Outcomes without
  these markers keep the old instant transition; combat outcomes start combat
  immediately as before (the fight itself is the reveal).
- **Event shop.** An outcome with `shop_after: true` (also honored inside
  `post_combat` of an event fight) opens the regular `_show_shop_screen()` after
  the reveal confirmation, with a freshly generated stock and an optional
  `shop_discount` (0..0.9) applied to stock prices once. Leaving that shop
  continues the event path — route advance with autosave after an event outcome,
  or the standard combat-node return after an event-fight victory — instead of
  the normal shop-node «return to map without advance» exit
  (`Main.event_shop_exit_action`, consumed by one exit).

SCRUM-674 rebuilds the live Settings apply flow inside the existing dark-fantasy
frame contract. The screen still has exactly three custom tabs: `Экран`, `Звук`
and `Управление`, with built-in `TabContainer` headers hidden and
`SettingsTabButton_0..2` inside the switcher safe rects. Screen settings
(`SettingsScreenOption`, `SettingsResolutionOption`, `SettingsWindowModeOption`)
now stage values in a pending buffer and do not call `_apply_video_settings()`
until `SettingsApplyButton` is pressed; `SettingsRevertButton` discards the
pending buffer. `ScreenShakeToggle`, sound controls and controls/rebind settings
remain immediate-apply. Sound sliders are compact `420x42` rows with the same
dark track/gold fill/focus behavior, so they no longer stretch across the whole
content panel. Mockup/spec: `docs/design/mockups/scrum674_settings_ui/spec.md`;
OpenAI reference: `docs/design/references/scrum674_settings_ui/settings_apply_flow_mockup.png`.

SCRUM-694 delivers the Settings **v3** full redraw design package: a from-scratch
premium dark-fantasy frame family (PixelLab) replacing the shared minimal-metal
styleboxes for every Settings surface. Pipeline: live inventory →
`docs/design/references/settings_v3_full_redraw/layout.json` (responsive geometry,
fit gate `ready_for_image`, validated against the live 2K constants) → three
textless OpenAI mockups (`docs/design/mockups/settings_v3_full_redraw/`, reference
only) → five PixelLab final 9-slice frames in
`assets/sprites/ui/frames/settings_v3/`: main modal (dragon-wing crest + red-gem
corners), tab switcher (3 slots), content panel, inset field (dropdowns/rebind),
action button. Native-size sources, transparent, textless, alpha-clean; modal
native 2048×1232 (covers 2K+4K), proportional 1536×924 at 1080p (no one-axis
stretch — only tiled 9-slice centers adapt). Runtime swap is a Back-end follow-up
per `docs/design/references/settings_v3_full_redraw/backend_handoff.md` (exact
paths, texture margins, node IDs, tests); v2/minimal-metal stays live until then.

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

Main menu uses `assets/backgrounds/main_menu_epic_battle_v3.png` through `MAIN_MENU_BACKGROUND`. The 2026-07-02 0.2.0 release pass replaces the earlier dragon-battle image with a 2560x1440 OpenAI-generated cosmic character-atlas background: pixel-art heroes, constellation/star-chart rings, atlas silhouettes and distant bosses, while preserving the calm left button-safe column and readable title-safe area. The asset is prepared for proportional cover-crop, not one-axis stretching, and contains no baked UI text/buttons/frames. Source, backup, preview and the Telegram/Discord announcement derivative are tracked in `docs/design/mockups/main_menu_020_cosmic_release/spec.md`. SCRUM-680 release refresh replaces the title with `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` (`960x360`, transparent, PixelLab crest source in `docs/design/references/main_menu_logo_release_fix/`) and positions the action column below the title with a computed `80px` minimum source-space gap for 1920x1080, 2560x1440 and 1080x1920.

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

- SCRUM-798 keeps the 2026-06-30 user-requested minimal black Hero Select direction, not the older ornate/Pixellab frame layout, but rebuilds the live sizing and information hierarchy. `_show_character_select()` / `_build_character_select_v4()` builds `HeroSelectScreen` over `HS4BlackBackground`; no title frame, no PixelLab backdrop, no compass rose, and no `HeroStatRadar` are active. The selected `HS4Portrait` is now the dominant left-column object (`320x320` at 1280x720, about `510x510` at 1920x1080, capped near `660x660` on tall screens) and keeps SCRUM-416/SCRUM-687 directional SpriteFrame rotation when available. `HS4AscensionFrame` is directly below the preview with `-`/`+`, max clamping, modifier text/tooltip and `HS4ChooseButton`. The right `HS4DossierFrame` is scroll-safe and contains class title, description, strengths, weaknesses, weapon names, class identity, eight base characteristics as hoverable Line Bars with rich `StatFormulas.STAT_DEFINITIONS` + class interpretation tooltips, and data-driven build guidance sections `Основные атрибуты`, `Второстепенные атрибуты`, `Дополнительные атрибуты` from `ProgressionData.attribute_relevance`. The bottom `HS4Carousel` uses enlarged responsive `HS4CarouselSlot_*` buttons (`~203px` at 720p, `~305px` at 1080p, capped near `320px`), larger arrows, cyclic paging and default focus on the selected visible slot. Since SCRUM-421 follow-up, carousel portraits are also alpha-bottom aligned inside clipped slots so PixelLab classes with different transparent canvas padding share one visible baseline. SCRUM-822 now positions both the large preview and carousel portraits by cached alpha bounding boxes, so transparent side padding is ignored, visible bodies are centered/bottom-aligned, and each carousel slot reserves a bottom `HS4CarouselLabel_*` name strip from the character title. Evidence: `build/qa/scrum-798/`, `build/qa/scrum421/`, `docs/design/mockups/hero_select_black_minimal/scrum822_preview_crop_labels_spec.md`.
- SCRUM-870 supersedes the SCRUM-868 full-screen Weapon Select runtime layer.
  `_show_weapon_select()` no longer creates `WeaponSelectPixelLabRuntimeLayer`;
  the old PixelLab layer remains only as historical SCRUM-867/868 evidence.
  Runtime now uses native, opaque Godot surfaces: `MenuPanel_weapon_select` is a
  dark readable shell, each `WeaponOption_*` is a framed `1674x260` card with no
  baked text/art behind labels, and `WeaponSelectBackButton` uses the normal
  fantasy button theme. The active source-space geometry is `WS_PANEL_2K`
  `Rect2(360,120,1840,1200)`, `WS_SAFE_2K` `Rect2(443,229,1674,1016)`,
  title/subtitle at `443,218,1674,62` and `443,288,1674,34`, first card at
  `443,350,1674,260` with `274px` vertical step, and Back at
  `1140,1238,280,60`. Every card has a `204x204`
  `WeaponSelectIconWell_*`, a larger `176x176` `WeaponSelectSprite_*`, center
  title/`Отличие:`/concise mechanic/role text, and a right `310x204`
  `WeaponSelectStatsPanel_*` with range/radius, cooldown, damage/control/limit
  context. The start-boon screen continues to use the generic `weapon_select`
  menu box, and Route Map/SCRUM-563 geometry remains untouched. Mockup/spec:
  `docs/design/mockups/weapon_select_redraw_from_scratch/`.
- Live HS4 Hero Select keeps the same runtime selection contract: carousel arrow
  buttons select previous/next character cyclically in
  `ProgressionData.character_ids()` order and use the same refresh path as
  slot clicks for portrait, dossier, ascension label and selected carousel state.
  The arrows remain inside the bottom carousel band.
- 2026-06-29: `HS4Portrait` can render an animated class preview when the
  selected character exposes directional SpriteFrames. PixelLab classes use
  one-frame `idle_<direction>` rotation rows and cycle `south -> south_west ->
  west -> north_west -> north -> north_east -> east -> south_east`, so Berserk,
  Dark Mage and Guitarist turn clockwise with the same static-pose cadence while
  staying inside the existing portrait content zone. Other characters keep the
  static `sprite_path` portrait fallback.
- SCRUM-664 fixes HS4 keyboard/gamepad focus for the same screen: the visible
  carousel hero slots are focusable, the selected visible slot receives default
  focus, carousel arrows/slots/Ascension/Choose/Back have explicit directional
  focus neighbors, and Escape/Back still returns to the main menu. This is a
  runtime input fix only; no frame art or safe-zone geometry changed.
- Historical: SCRUM-561 updated the older HS4 Hero Select v4 2K frame pass. Slot-exact assets
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
- SCRUM-436 and SCRUM-447 runtime integrations are historical Hero Select work for Sprint 0.1.6. The 2026-06-30 black minimal Hero Select contract above is the active runtime basis; future ornate/frame-based Hero Select work must first replace that active contract intentionally.
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

- SCRUM-657 adds a Design-ready text-button size audit and unified dark fantasy
  dragon button package under
  `docs/design/references/ui_text_buttons_unique_size_redraw/` and
  `assets/sprites/ui/frames/text_buttons_unique/`. Each final size group has its
  own OpenAI source PNG; the runtime set is not one stretched master. SCRUM-669
  promotes this package for normal text/action buttons through
  `UIThemePaths.TEXT_BUTTON_UNIQUE_*` and the runtime button resolver, including
  main menu, standard/back/quit/continue/later/settings/feedback/pause/event/
  rebind text actions and the pause dossier's local button helper. Runtime labels
  must stay inside the declared `content_rect_xywh`, between the decorative end
  shutters/caps. If a label does not fit, increase the button width or use the
  expanded long-label variants; text may not overlap claws, bevels, ruby pins or
  scale caps. Left/right caps are fixed-size ornaments and must not be scaled
  horizontally; only the center rail may stretch. Icon-only controls, cards,
  slots, portraits, plus/minus steppers, route nodes, weapon/reward cards and
  non-text decorative frames remain excluded.

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

- SCRUM-585 historically refreshed the `GlossaryTooltipPanel` as an isolated 2K
  tooltip frame (`assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png`,
  content margins `Vector4(66, 44, 66, 40)`). Generated mockup/spec and
  safe-zone evidence live under `docs/design/mockups/scrum585_glossary_tooltip/`
  and `docs/design/previews/scrum585_glossary_tooltip_*`. SCRUM-889 removes the
  live glossary section from the in-game Codex, so this panel is no longer
  created by `scripts/ui_screens.gd`.

- SCRUM-588 refreshes the transient `LevelUpToast` as an isolated generated @2K
  frame asset. Runtime uses
  `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png` through
  `UIThemePaths.OVERHAUL_2K_FRAME_*["lut_toast"]` at source size `480x300`,
  texture margins `58/48/58/48`, and strict content margins `70/112/70/112`.
  The toast now owns the single visible `Level Up` label inside that safe rect;
  the world-space `LevelUpEffect` is only a flash/ring/spark burst with no
  separate badge plaque. The frame is centered `190px` above the player screen
  position and fades in only to `0.70` opacity so it remains about 30%
  transparent. Sparkle/ring content starts inside the frame safe rect only.
  Mockup/spec and audit evidence live in
  `docs/design/mockups/scrum588_levelup_toast/`,
  `docs/design/references/scrum588_levelup_toast/`, and
  `docs/design/previews/scrum588_levelup_toast_safe_zone.png`.

- SCRUM-654 keeps the overhead level-up callout compact and singular. Runtime
  keeps `_spawn_level_up_effect()` as a textless player-following burst; when
  multiple level-ups arrive quickly, it removes older live `LevelUpEffect` nodes
  from the `level_up_effects` group before spawning the replacement. The only
  visible `Level Up` text is `LevelUpToastLabel` inside `LevelUpToastFrame`.

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

SCRUM-671 makes the SCRUM-666 clean essential-only HUD live in runtime. Combat
now shows only HP, XP, money, ULT charge, timer, ascension/elevation and the
bottom-right level-up plus/count control. The previous artifact row and compact
character stat chip strip are not created in combat HUD anymore. Runtime uses
the existing generated frame assets (`chud_resource_panel`, `chud_timer`,
minimal-metal metric cards, ascension badge and combat plus button), but places
them from the accepted SCRUM-666 `ui_plan.json`/`layout.json` rectangles because
SCRUM-666 shipped as a full-screen OpenAI mockup/source package rather than
transparent per-slot runtime slices. Text, icons, bars, count badges,
focus/click zones and the plus glyph stay inside the accepted dark interiors;
decorative rails, gems, rims and bevels stay unobstructed. UI smoke/no-overlap
coverage now fails if `CharacterStatsHud` or `ArtifactHudRow` appears in combat,
or if HUD content escapes the SCRUM-666 safe-zone metadata.

SCRUM-521 adds `LowHpVignetteOverlay` as a procedural combat HUD warning:
when player HP drops below 30%, a shader vignette fades in with a transparent
center and light red edges; it fades out only after HP recovers to 34%+ to avoid
threshold flicker. The overlay is drawn behind HUD cards, ignores mouse input,
uses the shared `combat_feedback` setting, and is covered by the HUD smoke
matrix.

SCRUM-666 is the Design-source package behind this pass. It keeps only HP, XP,
money, ULT charge, timer, ascension/elevation and the bottom-right level-up plus
button. Source and geometry live under
`docs/design/mockups/scrum666_combat_hud_2k/`, OpenAI reference art under
`docs/design/references/scrum666_combat_hud_2k/`, and safe-zone previews under
`docs/design/previews/scrum666_combat_hud_2k_*`. The QA-red revision moved
accepted content zones into generated dark interiors and out of rail/ornament
positions; level-up plus and pending-count zones are separate and
non-overlapping at 2560x1440.

SCRUM-778 compacts the same accepted SCRUM-666/SCRUM-671 runtime HUD geometry
without generating new art or changing the essential-only content set. At
1920x1080 the resource strip is now `938x111`, the timer panel `233x108`, the
ascension badge `123x123`, and the pending level-up button `66x78`; the top HUD
band bottoms at `162 px` (`15.0%` of viewport height) instead of the SCRUM-700
reported `26.2%`. The 1080p no-overlap matrix now gates combat HUD footprint:
top band must stay at or below `18%` of viewport height, and pending-level frame
footprint at or below `3.5%` of viewport area. Runtime content still uses the
same frame-safe metadata zones and may not overlap decorative rails, bevels,
rims, or badges.
- Weapon select uses lightweight clickable cards, not parchment/wax button frames. Each card shows `assets/sprites/weapons/<weapon_id>.png` (with legacy Berserk aliases `sword/axe/hammer -> two_handed_*`), title/description, and Russian stat labels: `Дальность`, `Радиус`, `Перезарядка`.
- Level-up reward options remain full-card clickable Buttons for input/focus and
  now use the larger SCRUM-682 runtime frame family from
  `assets/sprites/ui/frames/level_up_scrum682/`: `ui_frame_lu682_panel.png`
  (`1720x1040`), `ui_frame_lu682_card.png` (`470x560`), hover/selected card
  states, portrait frame, effect-preview field, and dedicated `Позже` button
  states. The screen still presents exactly 3 variants and preserves deferred
  choice through `level_up_offer`.
- SCRUM-871 (Level Up 3.0 Advisor) rebuilds the card information architecture on
  top of the SCRUM-682 kit: each card shows a top recommendation ribbon slot
  (`LU_CARD_BADGE_RECT`), a 120px icon, title, short description, and a large
  «до -> после» delta field (`LU_CARD_EFFECT_RECT` 354x132) that replaces the
  old single-line effect preview with up to 3 recalculated derived-stat lines
  (`LevelUpRewardEffectText`, `...Text2/3`) inside the same 9-slice
  `ui_frame_lu682_effect_preview` frame. `scripts/level_up_advisor.gd` dry-runs
  every offered reward against live player stats/run_modifiers/weapon_config via
  `ProgressionData.derived_parameters` and scores a DPS proxy
  (class damage_parameter × attack_speed × crit expectation + DoT track) and an
  EHP survivability model mirroring combat `take_damage` (absorb → defense →
  dodge + regen/vampiric window). The best positive DPS gain card gets the red
  «ЛУЧШИЙ УРОН» ribbon (`ui_badge_lu_best_dps.png`), the best survivability gain
  the green «ВЫЖИВАНИЕ» ribbon (`ui_badge_lu_best_surv.png`), one card winning
  both axes gets the gold «ЛУЧШИЙ ВЫБОР» ribbon (`ui_badge_lu_best_both.png`);
  zero/negative gains award no badge. Ribbons are PixelLab textless assets with
  runtime labels constrained to each ribbon's empty field
  (`LU_BADGE_META.label_zone` — фактические поля риббонов, замеренные по
  пикселям низкодисперсным раном в средней полосе PNG; поле у всех риббонов в
  ВЕРХНЕЙ части с эмблемой слева, подпись центрируется в поле по вертикали с
  учётом кламппа минимальной высоты Label); card tooltips list the full delta
  set and explain the badge with the computed gain percent. Damage-type
  isolation (SCRUM-524) keeps foreign damage types out of card deltas.
  Mockup/spec: `docs/design/mockups/level_up_advisor/`;
  gate: `tests/level_up_advisor_test.gd`.
- SCRUM-876 unifies the run resource HUD: `_create_menu_run_hud()` now builds
  the SAME SCRUM-806 combat slim cluster (HP/XP/ULT pixel-icon bars + gold,
  `ui_hud_v2_cluster_bg`) on every run menu screen — route map, level-up,
  rewards, shops, events, upgrade — via the shared `_create_resource_hud_panel`
  (combat-only layout param removed) + `_layout_combat_hud` responsive pass.
  The route map keeps its custom anchor below `RouteMapHeader` through
  `_layout_menu_resource_hud(root, origin)` (inner zones are laid out against
  the combat rect because `_hud_v2_place_in_panel` subtracts the panel
  position). The legacy card-style menu HUD (`_hud_panel_style`,
  `_add_hud_resource_card`, `_add_hud_money_card`, `_hud_bar_fill_style`) is
  deleted; `RouteMapHeader` uses the same `chud_resource_panel` @2K frame
  directly. Combat-only elements (timer, boss bar, ascension pips) stay
  combat-exclusive. Evidence: `build/qa/scrum876/route_map_hud_1920x1080.png`.
- SCRUM-683 is the live runtime wiring for the SCRUM-682 Level Up package.
  Source geometry lives under `docs/design/mockups/level_up_scrum682/spec.md`,
  and runtime scales it from 2560x1440 while keeping hero header, portrait,
  title, subtitle, three cards, card content, and `Позже` inside frame content
  zones. The runtime raises the `Позже` button slightly inside the panel safe
  area because the source handoff button y-position exceeded the declared
  content bottom. Card interiors show a large icon, readable title, short
  description, and framed visible effect preview; tooltip text is overflow only,
  not the primary explanation. The UI no-overlap matrix covers
  `LevelUpPanel`, `LevelUpHeroHeader`, all three reward cards,
  `LevelUpRewardEffectPreview`, and `LevelUpLaterButton`; focused SCRUM-683 QA
  evidence writes `build/qa/scrum683/level_up_no_overlap_matrix.md`.
- SCRUM-571 adds the Design-source 2K ordinary reward mockup/spec package for the post-battle reward selection screen. Source geometry and safe-zone files live under `docs/design/mockups/scrum571_reward_2k/`, the OpenAI base layer under `docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png`, and previews under `docs/design/previews/scrum571_reward_2k_*.png`. As of SCRUM-670 this package has no isolated alpha runtime frames, so runtime intentionally keeps the SCRUM-338 reward-card kit instead of slicing the full-screen mockup.
- SCRUM-572 adds the Design-source 2K elite artifact reward mockup/spec package for the elite victory artifact-choice screen. Source geometry and safe-zone files live under `docs/design/mockups/scrum572_elite_artifact_reward_2k/`, the OpenAI base layer under `docs/design/references/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_base.png`, and previews under `docs/design/previews/scrum572_elite_artifact_reward_2k_*.png`. As of SCRUM-670 this package has no isolated alpha runtime frames, so runtime intentionally keeps the SCRUM-338 elite reward-card kit instead of slicing the full-screen mockup.
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
tabs and click/focus hitboxes must not sit on decorative dragon/metal/gem
borders. SCRUM-403 historically wired the kit into `_show_codex_screen`, Codex
tabs, entry cards, portrait/icon slots and `GlossaryTooltipPanel`; SCRUM-889
removes the live glossary section and tooltip panel from the in-game Codex.
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
and cache, Escape/back returns to main menu, and character detail portraits keep
SCRUM-416 full-frame `sprite_path` plus SCRUM-417 covered scaling. QA dumps:
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

SCRUM-725 supersedes the SCRUM-574 frame material and old geometry for the live
Codex screen. Runtime now follows
`docs/design/mockups/codex_redesign_2026_06/layout_map.md`: full-screen
`codex_pl_backdrop` cover-crop, lighter readable shade, 24px base outer inset,
left nav / center list / right detail columns at the accepted proportions, and
textless 9-slice assets under `assets/sprites/ui/frames/codex_pl/` plus matching
`fit/` paths. Entry/list/detail text uses cream/gold on dark frames; dark ink is
confined to the `CodexDetailParchmentInset`. Active sections rebuild on viewport
resize so entry-card heights, portrait slots and detail text zones recompute
instead of keeping stale rects from the previous resolution. Source/provenance:
`docs/design/references/codex_redesign_2026_06/`; previews:
`docs/design/previews/codex_redesign_2026_06_pixellab_contact.png` and
`docs/design/previews/codex_redesign_2026_06_runtime_contact.png`.
SCRUM-725 verification retry on 2026-07-02 tightened the live list-panel
content margins to `Vector4(64, 72, 64, 64)`, keeping list content outside the
48px `codex_pl_grid_panel` ornament band with horizontal reserve. The follow-up
2026-07-02c verification retry keeps entry cards at a 150px source height with
`Vector4(28, 36, 28, 28)` card content margins, and renders each list card as a
single clamped title-summary block so text stays readable inside the empty card
zone without touching the red diamond ornament or 9-slice rails. Full description
text remains in `CodexDetailParchmentInset`.

SCRUM-849 prepared the object-first Codex design package, and SCRUM-850 makes it
live in runtime. The current screen shifts away from text-first list density
toward a large right-side object stage, a concise center selected/list area, and
a quiet left category rail. Source/spec:
`docs/design/mockups/codex_object_first_redesign/spec.md` and
`layout_zones.json`; PixelLab preview:
`docs/design/previews/codex_object_first_redesign_contact_v1.png`. Runtime base
rects are `CodexMainPanel` 72,54,1776,972; `CodexNavPanel` 96,210,300,700;
`CodexContent` 438,210,490,700; and `CodexDetailPanel` 960,210,840,700. The
center column contains `CodexCenterObjectStage`, contained
`CodexCenterObjectTexture`, short selected summary and cached compact section
lists; the right detail overlay contains the larger contained
`CodexDetailPortraitSlot`, chip row and `CodexDetailParchmentInset`. Data-driven
sections, mouse/keyboard/gamepad navigation and strict frame-safe content
placement are preserved. SCRUM-889 removes the live `Глоссарий` section from
the category rail, so the active Codex shows Персонажи, Монстры, Артефакты,
Характеристики and Возвышения only. Screenshot evidence:
`build/qa/codex_object_first/`.

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
runtime normal text/action button themes use the SCRUM-657 text-button `_hover`
/ `_focus` textures with neutral hover/focus font treatment; pressed and
disabled states keep their dedicated generated textures. SCRUM-450 minimal-metal
button textures remain available for compact/icon-like exceptions and historical
metadata tests.

## Main Menu Quit Confirmation

`MainMenuExitButton` and Escape on `MainMenuScreen` open `QuitConfirmationDialog`
instead of quitting immediately. The dialog is a custom game-styled full-screen
modal overlay, not a default Godot `ConfirmationDialog`: it blocks clicks below
the dim layer, focuses safe `Отмена` by default, cancels on Escape/outside click
and calls `Main.request_game_quit()` only from the explicit `Выйти` button.

SCRUM-344 locks the dialog action buttons to 220x72; SCRUM-669 routes
`QuitConfirmExitButton` / `QuitConfirmCancelButton` to the generated
`quit_220x72` SCRUM-657 text-button state kit. Do not let these buttons fall
back to compact/back/icon families: their text must remain inside the
`quit_220x72` content band. Runtime smoke records the actual rects and textures
in `build/qa/scrum319/quit_confirmation_dialog.md`.

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
overlay. Long pause/dossier stats content scrolls inside the modal safe-zone;
SCRUM-841 makes victory/death result screens no-scroll: `ResultContent_*` is a
direct panel child, `ResultBody_*` splits the middle safe-zone into a decorative
crest slot and compact `RunSummaryColumn_*`, and the primary action button stays
visible in the bottom safe-zone at 1152x648 through 4K. Result crests remain
decorative art, not text containers. QA dump:
`build/qa/scrum330/pause_end_ui_no_overlap_matrix.md`; current regression gate:
`tests/ui_no_overlap_matrix_test.gd` fails if `PauseEndModalScroll_victory` or
`PauseEndModalScroll_death` returns.

SCRUM-693 changes the active-combat Escape entry point: when no other run screen
is covering gameplay, Escape opens the pause dossier / character board directly
and uses its left run-control column as the available pause actions. The old
standalone `RunPauseMenuRoot` is still available for noncombat overlays such as
route/shop/event/level-up/reward contexts, but it must not appear over or instead
of the character board for clean active gameplay. Resume, Settings Back, and
repeated Escape preserve the same run state and pause-stack semantics.

SCRUM-839 is a runtime readability pass on the accepted SCRUM-580/SCRUM-486
pause dossier @2K layout. No new bitmap frames were generated: `pd_panel`,
`pause_280x60`, stat row/chip frames, and tooltip frames remain the source of
truth. `scripts/pause_stats_menu.gd` now uses viewport-aware readable minimums:
base stat rows are at least 44px high with 17/18px name/value text, derived stat
chips are at least 236x54px with 15/17px name/value text, and stat icons render
at 44px+ for base attributes and 46px+ for derived attributes. Long Russian stat
names are clipped with ellipsis or wrapped only inside their existing containers;
content remains inside the frame safe-zone. The update note lives in
`docs/design/mockups/scrum839_pause_dossier_readability/spec.md`.

SCRUM-840 unifies global hover tooltip behavior without generating new bitmap
assets. Generic `tooltip_text` controls inherit the existing minimal-metal
`tooltip` frame (`66/44/66/40` content margins), while pause dossier stat
details keep `stat_tooltip`. The shared
runtime helper in `scripts/ui/global_tooltip.gd` builds opaque framed panels
with word wrap, `MOUSE_FILTER_IGNORE`, 460px generic width / 430px stat width,
16px viewport clamp and 18px cursor/anchor gap. Generic tooltip panels carry a
small positioning script that re-places the Godot tooltip away from the cursor
after instantiation. Spec note: `docs/design/mockups/scrum840_global_tooltips/spec.md`.

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
in-run pause/dossier flow returns to the appropriate run pause surface and
preserves the active run state instead of rebuilding the start screen.

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

SCRUM-816 restructures the «Управление» tab into three labelled sections
(`_add_controls_section_header` → `SettingsSectionHeader_*`) inside the same
`ControlsScroll`:
- **Устройство ввода** — `SettingsInputModeOption` (Авто / Клавиатура и мышь /
  Геймпад → `input_mode`, applied live via `InputDeviceManager.set_input_mode`),
  a hint line, and the live `SettingsGamepadStatus` label (updates on hot-plug via
  `InputDeviceManager.device_changed` + `Input.joy_connection_changed`).
- **Клавиатура** — the existing per-action keyboard rebind rows
  (`BindingButton_*`) plus «Сбросить управление».
- **Геймпад** — per-action joypad rebind rows (`GamepadBindButton_*`, listening
  mode assigns the next joypad button / stick axis, conflicts reuse a menu-box
  dialog), `SettingsGamepadDeadzoneSlider` (`gamepad_deadzone`),
  `SettingsGamepadVibrationToggle` (`gamepad_vibration`), and «Сбросить геймпад»
  (`SettingsResetGamepadButton`). Full contract: `docs/design/systems/input_controls.md`.

### SCRUM-584. Key Rebind Conflict Dialog

SCRUM-584 completes the `_show_rebind_conflict` 2K pass. The dialog is now a
dedicated `RebindConflictDialog` / `RebindConflictPanel`, not the generic menu
box, with a textless OpenAI mockup reference and dedicated runtime
`rc_panel`/`rc_btn` frame assets. The generated mockup is visual direction only;
exact content geometry is enforced by the `RC_*_2K` constants and verifier.

| Slot | const | x | y | w | h |
| --- | --- | ---: | ---: | ---: | ---: |
| Panel frame | `RC_PANEL_2K` | 940 | 530 | 680 | 380 |
| Safe-area | `RC_SAFE_2K` | 998 | 602 | 564 | 242 |
| Title | `RC_TITLE_2K` | 998 | 614 | 564 | 44 |
| Message | `RC_MESSAGE_2K` | 998 | 674 | 564 | 66 |
| Button: choose another | `RC_BTN_RETRY_2K` | 1031 | 758 | 240 | 72 |
| Button: settings | `RC_BTN_BACK_2K` | 1289 | 758 | 240 | 72 |

Frame contract: content margins are `58/72/58/66` on the `680x380` source
`ui_frame_2k_rc_panel.png`, so title/message/buttons must stay inside local
`Rect2(58, 72, 564, 242)`. The ornament, rails and dividers of the frame are not
usable content space. Both actions use the dedicated `240x72`
`ui_frame_2k_rc_btn.png` button frame. OpenAI/source and safe-zone evidence live
under `docs/design/references/scrum584_rebind_conflict_2k/`,
`docs/design/mockups/scrum584_rebind_conflict_2k/`, and
`docs/design/previews/scrum584_rebind_conflict_2k_safe_zones.png`. Verifier
coverage: `tests/ui_no_overlap_matrix_test.gd`, screen id `rebind_conflict`,
across 1080p/2K/4K.

SCRUM-667 limits Settings to two windowed resolution choices: `2560x1440` first
when supported and `1920x1080` as fallback. SCRUM-441 remains integrated in the
same Settings pass: options use `scripts/display_resolution.gd` to compare
requested window sizes against physical monitor pixels (`screen_size *
screen_scale`) instead of only logical points, `_apply_video_settings()` clamps
with `DisplayResolution.clamp_to_physical(...)`, and `project.godot` enables
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

## SCRUM-827 — Атлас героев: no-overlap сокетов

`scripts/ui_screens.gd::_show_atlas_screen()` строит экран «Атлас героев»:
лента классов, холст созвездия, панель узла и вкладка гильдии. Сокеты
созвездий используют `ATLAS_SOCKET_SIZES` как 2560×1440-ориентир, но runtime
применяет compact scale для 720p/1080p, stagger для плотных колонок,
collision-relax и финальный nearest-open placement. Acceptance rule: круги
`AtlasNode_*` не наслаиваются друг на друга на 1280×720, 1920×1080 и
2560×1440; тестовое покрытие — `runtime_smoke_test.gd`,
`runtime_smoke_ui_test.gd` и `meta40_atlas_screen_smoke_test.gd`.

## SCRUM-812 — фокус-навигация внутризабеговых экранов (геймпад/стрелки)

Все окна выбора, открывающиеся ВНУТРИ забега, полностью управляются геймпадом
(крестовина/стик + A/B) и клавиатурой (стрелки + Enter/Esc), сохраняя мышь как
гибрид. Реализация в `scripts/ui_screens.gd`, `scripts/route_map_screen.gd`,
`scripts/pause_stats_menu.gd`; тест `tests/gamepad_inrun_ui_test.gd`.

Механика:
- Единый хелпер `UIScreens._wire_run_ui_focus(primary, axis_h, secondary, initial)`
  проставляет `FOCUS_ALL`, разводит круговые `focus_neighbor_*` (ряд — лево/право,
  столбец — верх/низ) и ставит стартовый фокус (`call_deferred("grab_focus")`).
  `secondary` (напр. «Позже»/«Назад») доступен с перпендикулярной оси и связан
  обратно в круг.
- Опора на встроенные `ui_*`-экшены Godot. В текущей сборке `ui_up/down/left/right`
  уже имеют joypad-события (крестовина 11–14 + стик), а `ui_accept`/`ui_cancel` —
  НЕТ. Поэтому `_ensure_run_ui_gamepad_bindings()` идемпотентно доводит
  `A→ui_accept` и `B→ui_cancel` в рантайме. Полную раскладку геймпада формализует
  ядро **SCRUM-811** (InputDeviceManager); гард исключает дубли при слиянии.

Карта стартового фокуса и cancel по экранам:
- Level-up (`_show_level_up_screen`): карточки апгрейда по кругу лево/право, «Позже»
  доступна ui_down; старт — первая карточка; Esc/`ui_escape_action` = отложить.
  Окно ставит дерево на паузу (`push_pause("level_up")`), поэтому move_* не дёргают
  игрока (требование #8).
- Награда/премиум-награда/событие (`_show_reward_screen`,
  `_show_elite_artifact_reward`, `_show_event_screen`): круговой фокус-граф карточек,
  старт — первая карточка (награды обязательны — cancel не выходит).
- Пауза (`_build_run_pause_menu`): вертикальное меню, старт — «Продолжить»;
  B/Esc = продолжить игру.
- Досье паузы (`PauseStatsMenu`): кнопки фокусируемы, старт — «Продолжить»; B/Esc
  обрабатывается централизованно в `main._input`.
- Смерть/победа (`_show_death_screen`, `_show_victory_screen`): старт — основная
  кнопка; B/Esc = основная кнопка (нет «пустого» закрытия).
- Магазин/отдых/улучшение (`_show_shop_screen`, `_show_rest_screen`,
  `_show_upgrade_screen`): товары/карточки фокусируемы, «Назад» доступна ui_down,
  покупка/выбор по A, выход по B.
- Карта маршрута (`route_map_screen.gd`): доступные ноды — `FOCUS_ALL`, недоступные
  `FOCUS_NONE` (пропускаются); крестовина/стик двигают выделение по доступным нодам,
  A подтверждает (`Button.pressed`), заметная золотая кайма (`focus`-стайлбокс),
  скролл следует за фокусом (`follow_focus`). Мышь идёт своим путём
  (`_handle_route_node_input`); двойную активацию гасит реэнтранси-латч
  `_route_node_activating` в `_activate_route_node`.

`main._input` (SCRUM-812): геймпад B (`ui_cancel`) закрывает/отменяет ТОЛЬКО открытый
внутризабеговый экран или паузу-оверлей (паритет с Esc); вне открытых экранов B не
трогается — остаётся под геймплей (dodge и т.п., раскладка — SCRUM-811/814).
Клавиатурный путь `pause` (Esc) не изменён.

## SCRUM-813 — навигация мета-меню с геймпада/клавиатуры

Мета-экраны вне забега управляются крестовиной/стиком + A/B (и стрелками+Enter/Esc),
мышь — гибрид. Опора на ядро **SCRUM-811** (InputDeviceManager биндит A→ui_accept,
B→ui_cancel, крестовину/стик к ui_*) и общий хелпер `_wire_run_ui_focus` (SCRUM-812).

Карта стартового фокуса и cancel по мета-экранам:
- Главное меню (`_show_main_menu`): вертикальный круг кнопок, старт — «Начать новую
  игру»; B/Esc = подтверждение выхода.
- Диалоги выхода/продолжения (`_show_quit_confirmation_dialog`,
  `_show_continue_run_dialog`): пара кнопок, круговой фокус, старт на «Отмена»/
  «Продолжить»; B/Esc = отмена (фокус ограничен попапом).
- Выбор героя (`_build_character_select_v4`): 2D-граф фокуса (карусель + возвышение
  +/- + Выбрать + Назад) — уже был (SCRUM-664), сохранён.
- Выбор оружия/боона (`_show_weapon_select`, `_show_start_boon_select`): карточки
  вертикально по кругу, «Назад»/«Без боона» ниже; старт — первая карточка.
- Магазин атрибутов (`_show_attribute_shop`): докач-опции + Reroll/Skip, старт — первая
  доступная опция; `follow_focus` прокручивает список.
- Дерево умений (`_show_skill_tree_screen`): старт — селектор класса; кнопки хедера
  (зум/сброс/назад) достижимы направлением; узлы графа — мышь/зум (гео-навигация графа
  геймпадом — отдельная доработка).
- Патч-ноуты (`_show_patch_notes_screen`): старт — «Назад в меню»; контент read-only
  (колесо/перетаскивание).
- Кодекс (`_show_codex_screen`): старт — первая вкладка; карточки записей фокусируемы,
  секция-скролл `follow_focus`; live-раздела `Глоссарий` нет. **LB/RB листают
  секции** (`_cycle_codex_section`).
- Настройки (`_show_settings_menu`): старт — первая вкладка; слайдеры/OptionButton/
  CheckBox фокусируемы (ui_left/right меняют значение из коробки). **LB/RB листают
  вкладки** (`_cycle_settings_tab`).

Механика LB/RB: `main._input` ловит raw `JOY_BUTTON_LEFT_SHOULDER(9)`/
`RIGHT_SHOULDER(10)` и роутит в `UIScreens._handle_menu_shoulder_nav(dir)`, который
локально по открытому экрану (SettingsV2Root / CodexScreen под `game.ui_layer`) листает
вкладку/секцию. Обрабатывается, только если экран открыт — иначе не трогается.
ui_cancel/B закрывает попапы через `ui_escape_action` (SCRUM-812 путь в `main._input`).
Focus-стиль — существующие не-жёлтые focus-текстуры темы (курс «без жёлтых рамок»).
