# Menus And UI

Обновлено: 2026-07-15

Этот файл собирает UI-направление FantasyDisk после domain split. Полное фактическое состояние остается в `docs/design/current_game_state.md`, а канонические IDs и assets - в `docs/design/content_registry.md`.

## FAN-1112 Game Updater

Settings tabs 0–2 now keep `SettingsUpdateButton` («Обновить игру») at the left
edge of the existing frame-safe footer, separated by an expanding spacer from
Screen-only Revert/Apply. The Game tab still collapses the complete footer.
Manual checks always report current/error/available state; the exported startup
check prompts only when a newer public GitHub Release exists and stays silent
offline. The modal uses the accepted Atlas chip and global action-button families,
traps keyboard/gamepad focus, restores the previous Escape action, and scales
inside 1280×720, 1920×1080 and 2560×1440 viewports.

FAN-1124 makes the updater action routing explicit after final button sizing:
the 420×72 primary uses `text/continue_run_long_420x72`, while the 240×72 close
action uses `text/continue_240x72`. Their dedicated neutral-bright focus PNGs
replace the accidental bright-yellow `minimal/standard` fallback without
changing action-row geometry, copy, initial focus, cyclic navigation or Escape
restoration. Geometry and safe-zone contract:
`docs/design/mockups/fan1124_update_focus/spec.md`.

The accepted no-new-art mockup/spec package is
`docs/design/mockups/fan1112_game_updater/`. Runtime and responsive checks are
`tests/update_settings_ui_test.gd` and `tests/settings_footer_scrum1053_test.gd`.
The network, trust and installer contract is documented in
`docs/process/game_updates.md`.

## FAN-1098 Codex Background

The live Codex now uses a cohesive 2560x1440 RGB draconic-archive background at
the existing `assets/sprites/ui/atlas_style/codex/bg_codex_sanctum.png` path.
It was created only with the built-in OpenAI Image Generator in Codex, then
center-cropped and proportionally normalized; PixelLab and the OpenAI Images API
were not used. All panels, title, crest, buttons, text, content geometry, focus,
and navigation remain separate unchanged runtime Controls.

The dark low-frequency field preserves the exact accepted 1920x1080 safe zones
for title, crest, Back, navigation, list, and dossier. Real renderer captures at
1280x720, 1920x1080, and 2560x1440 plus source provenance, hashes, prompt,
safe-zone luminance, backup, and implementation contract live under
`docs/design/{references,mockups,previews,backups}/fan1098_codex_openai_background/`.

## FAN-1080 Лор: Интро Истории, «Летопись» Кодекса, Лорные Баннеры И Исходы

Канон текстов: `docs/design/lore.md`; рантайм-данные: `scripts/lore_data.gd`.

- **Интро истории (FAN-1099: убрано из запуска игры).** «Начать новую игру» и
  «Новая игра» из continue-диалога больше НЕ показывают вступление — оба ведут
  сразу в выбор героя (`_show_character_select`). Рассказ о мире остался только в
  Кодексе: запись «Вступление» на вкладке «Летопись» (те же 4 слайда). Экран
  `LoreIntroScreen` и хелперы `_maybe_show_lore_intro`/`_show_lore_intro`
  (`LoreScreens.show_intro`) сохранены для пересмотра/тестов и на случай возврата
  интро в поток запуска: 4 слайда (Диск → Разлом → Хранитель → Печать) на
  codex-sanctum фоне, центральная панель кодекс-кита 920×560 с content margins
  56/44 (контент только в пустой зоне рамы), кнопки «Пропустить»/«Далее» (на
  последнем слайде «В путь»), Esc/B — пропуск, фокус-ринг горизонтальный. Флаг
  «показ один раз» `settings.cfg: lore_intro_seen` (`game_settings.DEFAULTS`) и
  тест-байпас `main.force_skip_lore_intro = true` остаются в коде, но в потоке
  запуска сейчас не задействованы.
- **«Летопись» — 7-я вкладка Кодекса** (`CODEX_SECTIONS`, шаг nav-плит 104 вместо
  118, последняя плита y=648+72=720 в 752px content-зоне). Записи из
  `LORE_DATA.CHRONICLE`: Вступление (те же 4 слайда), Диск, Разлом, Владыки
  Разлома (по строке «что убило его мир» на каждого босса; строка Истока
  добавляется только при `META_PROGRESSION.secret_boss_defeated`), Хранители,
  Печать и Возвышение. Досье классов получило секцию «Происхождение»
  (осколок-мир), боссов — «Владыка Разлома», элиток — «Офицер прибоя».
- **Боевые баннеры.** `_show_combat_title_banner(title, color, big, lore_line)`:
  необязательная лор-строка без рамки (outline-текст) под баннером, живёт чуть
  дольше титула. Боссы передают `LORE_DATA.boss_intro_line(boss_id)`, элитки —
  `elite_lore(id)` и русский титул из Кодекса вместо англ. `enemy_type_name`.
  Сцены Стража Разлома и Пожирателя Диска получили русские `boss_display_name`,
  секретный босс — «Исток».
- **Исходы.** Победа: первая строка subtitle — «Печать наложена…» (вариант «…
  Разлом уйдёт глубже», пока `run_level < MAX_ASCENSION_LEVEL`); смерть —
  добавленная строка «Диск вписал павшего в Летопись…». Число строк victory
  subtitle не выросло (лор-строка заменила «Финальный босс повержен»).
- Тесты: `tests/lore_screens_test.gd` (данные + интро + Летопись + спойлер-гард),
  обновлены `codex_scrum954_layout_test` (7 вкладок), `runtime_smoke_test`
  (строка победы, байпас интро), `gamepad_full_flow_smoke_test` (байпас интро).

## FAN-1077 Codex Unread And Victory Unlock Journal

New Codex discoveries persist canonical discovery lists plus a separate
`codex_unread` map for characters, weapons, monsters, bosses and artifacts.
The discovery lists remain the source
for locked artifact/enemy knowledge; unread is presentation state. Old saves
load with an empty unread map, so migration never marks the whole historical
Codex as new. Opening an entry explicitly clears and immediately saves all of
its unread references. Merely landing on the default dossier does not clear it.

Unread rows are stable-partitioned before read rows. Character rows aggregate
their own ID and all nested `character_id/weapon_id` references, so a newly
presented weapon raises its owning dossier. The 36×36 PixelLab exclamation
badge stays inside the 516×154 card at `x=446,y=22`; unread rows reserve 86px
on the right rather than covering the name. Category badges aggregate
characters+weapons, monsters+bosses and artifacts. `MainMenuCodexUnreadBadge`
shows while any category remains unread.

`codex_unlock_state.gd`, `codex_run_unlocks.gd` and
`codex_unlock_presenter.gd` own the focused persistence, journal and view
contracts while `MetaProgression`, Main and `UIScreens` keep compatibility
facades. `run_metrics.new_unlocks` keeps acquisition order and deduplicates by
category+ID. A successful result with entries adds `VictoryUnlockPanel` and a
nested `VictoryUnlockScroll` before a four-row compact stat summary, showing
every artifact, hero and weapon rather than truncating the run journal. Hero
and weapon unlock conditions are deliberately future work: FAN-1077 provides
validated presentation APIs without locking the currently accessible roster.
Design evidence and safe-zone reports live under
`docs/design/mockups/fan1077_codex_unread_unlocks/`; responsive coverage is
`tests/codex_unread_victory_test.gd`.

## FAN-1065 / FAN-1066 / FAN-1069 Codex Atlas/Settings Runtime Skin

The active Codex component canon is the FAN-1065 PixelLab package
`docs/design/mockups/fan1065_codex_atlas_settings_redesign/`, promoted into
`assets/sprites/ui/atlas_style/codex/`, except for the FAN-1098 full-canvas
background described above. The accepted SCRUM-954/FAN-1047
1920×1080 stage and all runtime rects remain unchanged: nav
`72,172,324,840`, list `420,172,620,840`, dossier `1064,172,784,840`, 516×154
entry rows, 300×300 dossier well with a contained 236×248 image, and a 684×356
lower scroll whose live text lane remains 610×304. Uniform stage scaling and
letterboxing remain the only responsive transform.

Runtime uses the FAN-1098 built-in OpenAI archive scene, PixelLab panel 9-slice, entry cards,
dossier portrait frame, chip bar and crest. Text, icons and portraits remain
separate Controls inside the documented empty zones. The square dossier frame
is used only on the 300×300 portrait well: visual QA proved that stretching its
broad dragon corners over the 684×356 lower scroll would cover the locked text
lane, so that scroll uses the thinner parchment-warm Codex panel 9-slice.

The six left tabs and `CodexBackButton` stay on the canonical Main Menu action
family (`text/main_menu_380x104` / Back plate). The retired yellow
`minimal_metal_codex_tab` family must never return. Button states, lazy section
cache, focus neighbors, LB/RB section cycling, B/Esc Back behavior and exactly
two active vertical scrollbar lanes remain unchanged. Regression coverage:
`codex_scrum954_layout_test.gd`, `runtime_smoke_test.gd`,
`ui_no_overlap_matrix_test.gd` and `dark_fantasy_ui_theme_test.gd`; real Codex
screenshots are written under `build/qa/scrum954/`.

## FAN-1047 / SCRUM-1049/1051 Unified Semantic Button Families

Runtime buttons now expose an explicit `ui_button_family` contract through
`scripts/ui/ui_button_family.gd`. The registry resolves the accepted
text-button/minimal-metal production assets only after final name and size are
known, so semantic intent no longer depends on construction order. Main actions,
Back/navigation, Codex tabs and Pause actions share the resolver; selectable
content rows/cards, Settings fields/toggles, Route nodes, Atlas sockets,
Hero-carousel arrows and @2K conflict controls remain
documented shape-specific siblings of the same FantasyDisk family.

Codex keeps the accepted frameless SCRUM-954 three-column layout. FAN-1047
removes the old yellow `minimal/codex_tab` exception: all six left tabs now use
the exact five-state `text/main_menu_380x104` family at a ratio-preserving
260×72 target. The longest tab caption uses the compact synonym «Параметры»
so it remains inside the plate content lane at 720p. Entry cards stay
`content_row`; hover/focus/pressed/disabled do
not alter content margins or geometry. Compact Shop/Attribute actions are now named
`slim_action` instead of borrowing rebind-field semantics. Pause dossier actions
consume the same shared resolver instead of a copied path/threshold table.
At 648p/720p/900p they form a right vertical rail at 219×60 or 263×72;
1080p/2K retain a centered horizontal footer at 320×88 or native 380×104.
Texture and content margins always scale by one uniform factor, so the Main
Menu ornament is never cropped independently from the label lane.

`MainMenuCreditsButton` is an icon-only gratitude action using the transparent
PixelLab asset `assets/sprites/ui/icons/credits/ui_icon_gratitude.png`; its face
text is empty, while tooltip/accessibility metadata remains «Благодарности».
SCRUM-1081/1082 moves it into the lower-right utility cluster immediately left
of the version. SCRUM-1093 removes the wide invisible version placeholder;
SCRUM-1095 additionally removes the accepted PNG's transparent-source-padding
error at draw time. Runtime scans the unchanged PixelLab source alpha bbox and
uses a right-facing square `AtlasTexture` crop (`(41,48)-(201,208)` for the
accepted `256x256` source) without editing the bitmap. The 72/80/96 px hitbox is
biased 3 px toward the version but remains inside its bounded 84/96/116 px
procedural aura; the aura-to-label rect gap is 2 px. Independent actual-alpha
measurements are `15/17/17/19 px` at 1280/1920/2048/2560, within the required
`0..20 px` band. The existing neutral keyboard focus, Credits callback,
accessibility, tooltip and UI SFX remain intact.

`MainMenuVersionLabel` is the single runtime version control; it reads
`application/config/version`, never a hardcoded release number. SCRUM-1082
introduced the lower-right placement; SCRUM-1093 sizes the rect from the actual
rendered string plus 6 px effect reserve and anchors its right/bottom edge to
`frame_safe.end - Vector2(8,8)`. The 14/16/18 px caption tiers, right/bottom
alignment and restrained dark outline remain unchanged. Logo/actions still use
the more conservative page-wide authored inner rect.

Acceptance coverage: `tests/scrum1051_ui_button_family_test.gd`,
`tests/codex_scrum954_layout_test.gd`,
`tests/scrum1093_main_menu_version_corner_test.gd`,
`tests/scrum1093_independent_visible_gap_test.gd`,
`tests/scrum981_gold_menu_shell_test.gd`,
`tests/ui_no_overlap_matrix_test.gd` and the general runtime UI/full smokes.

## SCRUM-1062 Continue Run Live Title Typography

`ContinueRunTitle` is now an accessible live Godot `Label` with the exact
Russian text `Продолжить забег?`; the former 760×170 Luminari bitmap wordmark
and its platform-font generator were removed after confirming that the dialog
was their only runtime consumer. The label inherits the same theme/default
`Font` resource as standard game title labels. SCRUM-1061 inventories it as the
semantic `title` role while this screen keeps its documented fit-safe title tier
`_readable_font_size(29)` (`38/40/42/42px` at 1152×648 / 1280×720 / 1080p /
2K), with warm-gold text, 2px dark outline and 2px shadow offset.

The accepted PixelLab SCRUM-842 composition and all frame/button art are
unchanged. The centered fixed `840×380` panel publishes an authored content
rect of exactly `696×242` after integer layout; the title occupies a `696×70`
single-line slot at source-space `Rect2(932,602,696,70)` at 2K. Measured
glyph/effect bounds stay inside that slot and the empty content zone without
touching rails, subtitle or buttons at 1152×648, 1280×720, 1920×1080,
2560×1440 and live resize. Continue/New Game callbacks, autosave, Escape and
mouse/keyboard/gamepad focus behavior are unchanged. Contract and evidence:
`docs/design/mockups/scrum582_continue_run/spec.md` and
`tests/scrum1062_continue_run_title_test.gd`.

## SCRUM-926/1088 Priest Battle Prayer Choice

Every Priest combat now begins behind a mandatory, non-cancellable three-card
prayer choice. `CombatDirector` creates/configures the player and HUD first, but
does not call `Player.on_battle_start()` or spawn an elite/boss until a valid
`Player.select_battle_prayer()` succeeds. The modal owns pause reason
`battle_prayer`; the global `Main._input` guard consumes physical Escape,
keyboard `ui_cancel` and gamepad B before pause/hotkey routing, so no second
overlay can cover the mandatory decision. The first card receives initial
focus, left/right navigation is circular and up/down stays on the same card.
Other classes retain the synchronous, screen-free combat-start path.

SCRUM-1088 removes the bespoke 688×384 prayer modal from runtime. The choice
now literally uses the same `LevelUpOverlay`, `LevelUpPanel`, title/divider,
`LevelUpRewardsRow`, `_level_up_card_plan()` and three
`LevelUpRewardButton0..2` builders as an ordinary level-up attribute/reward
choice. Only the title/subtitle, prayer dictionaries and selection callback
differ; the mandatory screen intentionally has no `Позже` button. The existing
Level Up background, card/socket art, responsive metrics and hover/focus/pressed
states are therefore the single visual/layout source of truth. No
prayer-specific frame, card rects or focus style are rendered.

The cards keep canonical order `prayer_wrath`, `prayer_mending`,
`prayer_aegis`, use their damage/regeneration/defense icon IDs and show the
round effect in the standard Level Up effect-summary field. All runtime content
stays within the existing card content margins and socket inner zones at
1280×720, 1920×1080 and 2560×1440. PixelLab reuse-spec evidence is under
`docs/design/mockups/scrum1088_priest_prayer_attribute_picker/`; the generated
layout layer is reference-only and is not promoted to runtime assets.

Acceptance: `tests/scrum926_priest_prayer_choice_test.gd`,
`tests/priest_kit_test.gd`, `tests/ui_no_overlap_matrix_test.gd` and real runtime
captures under
`docs/design/previews/scrum1088_priest_prayer_attribute_picker/runtime/`.

## SCRUM-951 Hero Select Stat Identity Palette

The eight `HS4Stat_*` rows now use one shared semantic map in
`scripts/ui/hero_select_constants.gd`, independent of the selected class:
Strength `#D84A3A`, Agility `#4CC66A`, Intelligence `#4C8DFF`, Perception
`#F4C542`, Energy `#38D6E8`, Knowledge `#A675FF`, Endurance `#D98236`, and
Leadership `#D8B24A`. Bars keep the canonical accents. Name/value text uses the
same color except Strength, whose accessible text companion is `#E05B4C`
(4.97:1 on the reference `#171613` row; canonical red remains on the bar).

Color is redundant information: localized name, numeric value, bar length and
the existing concise tooltip remain. At 1280×720 the stat zone reflows to 2×4
cells so all semantics stay visible; 1920×1080 and 2560×1440 keep the vertical
1×8 column. Both layouts remain inside `HS4DossierFrame` and the hollow global
frame rails. PixelLab styling references/spec:
`docs/design/mockups/scrum951_hero_stat_colors/`; Metal captures:
`docs/design/previews/scrum951_hero_stat_colors/runtime/`. Acceptance:
`tests/scrum951_hero_stat_colors_test.gd`,
`tests/hero_select_pixellab_layout_test.gd` and the general UI gates.

## SCRUM-981 Unified Gold Menu Shell

SCRUM-981 promotes `assets/sprites/ui/meta40/frame_border.png` to the shared
hollow outer shell for appropriate non-combat pages. The runtime
`StyleBoxTexture` uses the 1536×1024 source with 160 px texture/content rails
and `draw_center=false`; the frame is always the final, mouse-ignoring child.
Its exact empty interiors are `Rect2(133,113,1014,494)` at 1280×720,
`Rect2(200,169,1520,742)` at 1920×1080 and
`Rect2(267,225,2026,990)` at 2560×1440. Every label, icon, hitbox, scroll lane
and local panel must remain inside those rectangles.

Live application inventory:

- SCRUM-1059 Main Menu preserves the accepted logo/background/shell and places
  six semantic `main_menu_380x104` actions in one responsive left column:
  320×54 @1152×648, 340×56 @1280×720, 360×64 @1600×900, 380×76 @1080p and
  380×96 @2K. SCRUM-1081/1082 keeps the accepted action column X at the authored
  inner left edge. The 72/80/96px gratitude icon and bounded 84/96/116px
  procedural glow form a lower-right cluster immediately left of the dynamic
  version. SCRUM-1093 removes the oversized hidden label gap; SCRUM-1095 makes
  the measurement alpha-aware through the runtime crop described above. The
  glow-to-label separation is 2px, the label width is live glyph width + 6px,
  and the compact cluster uses an 8px reserve from the frame-safe opening.
  Logo/actions keep the
  stricter shell interior (texture-safe rect minus another 24px, or 32px at 2K).
  The screen never scrolls and relayouts on live resize. Up/Down wraps the six
  actions; Right reaches gratitude, whose Left/Up returns to Exit and Down
  returns to Start.
- Route Map insets header/title, shared resource HUD, vertical scroll/canvas,
  scrollbar lane and upgrade FAB into authored inner zones. Horizontal scroll
  remains disabled and map nodes are rebuilt safely when available width changes.
- Rest, Upgrade and Battle Reward keep their local Atlas chips/cards below a
  reserved in-frame HUD/FAB strip; 720–900p uses explicit compact card tiers.
- Victory and Defeat keep their local result modal, summary and action inside
  the shell; the smallest legacy matrix uses compact summary typography and a
  content-width action plate. SCRUM-986 also centers the transient 960x224
  Victory banner on both axes at every target viewport; the old absolute 2K
  top offset is forbidden because it clipped the banner at 720p.
- Every listed shell has a live `resized` relayout path. Shrinking an existing
  2560×1440 screen to 1280×720 recomputes panel/card/result/FAB geometry and
  Route Map canvas width; it is not valid to rely only on screen reconstruction.
- Existing Hero/Weapon Select, Settings, Patch Notes, Atlas and Pause dossier
  shells remain unchanged. Codex intentionally keeps the SCRUM-954 frameless
  three-column contract. Level Up remains frameless under SCRUM-985. Combat,
  Combat HUD and transient combat/result overlays never receive the large shell.
- Shop, Attribute Shop, Event and elite/boss reward variants remain owned by
  their more specific child-task contracts and are not broadened by SCRUM-981.

UI Director source, exact inventory and PixelLab provenance:
`docs/design/mockups/scrum981_gold_menu_shell/`; accepted PixelLab references:
`docs/design/references/scrum981_gold_menu_shell/`; runtime QA:
`tests/scrum981_gold_menu_shell_test.gd`,
`tests/scrum981_route_map_gold_shell_test.gd`,
`tests/ui_no_overlap_matrix_test.gd` and `build/qa/scrum981/`.

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

## SCRUM-1061 Semantic Typography

Player-facing font sizing now has one canonical runtime source:
`scripts/ui/semantic_typography.gd`. It defines the semantic roles `display`,
`title`, `section`, `body`, `description`, `action`, `tab`, `field`, `value`,
`tooltip`, `caption` and `HUD`; every role owns min/target/max effective px and
an overflow policy. New UI uses the semantic resolver directly. Existing
accepted layouts use centralized authored-compatibility, scale-compatibility or
Codex transform-aware resolution so the SCRUM-692/883 effective values and
frame geometry do not move during migration.

The duplicated route-map readability formula is removed. `ui_screens` readable,
Settings and Codex helpers plus the pause dossier helper now delegate to the
same API. Global tooltips, level-up toast, threat indicators, player/enemy world
feedback and raw combat HUD sizes are routed through it as well. Continue Run is
inventoried as `title`, but its accepted SCRUM-1062 slot and effective tier are
unchanged.

The machine inventory
`docs/design/mockups/scrum1061_semantic_typography/typography_inventory.json`
uses stable source fingerprints. SCRUM-1073 migrated the exact 139-site
non-Atlas legacy-geometry manifest into semantic bands without lowering token
floors. Schema 3 records each original/replacement fingerprint, effective
before/after range and final disposition; `139/139` replacements are live and
SCRUM-1073 routing is zero. Two Atlas-canvas/topology fingerprints still route
to SCRUM-1068. SCRUM-1070 remains scoped only to the Atlas reset-footer button
and owns no current inventory fingerprint. The responsive matrix explicitly
covers 2048×1152. Contract, PixelLab anchors and rules:
`docs/design/mockups/scrum1061_semantic_typography/`.

The additional SCRUM-1073 PixelLab/content-zone package is under
`docs/design/mockups/scrum1073_semantic_band_migration/`. It covers the 35
sites without an accepted family-specific mockup through eight clean empty
zones (economy, combat HUD, event, confirmation, feedback, patch notes, start
boon, victory); the remaining 104 migrations reuse their accepted mockups.
The generated contact sheet is evidence only and is not a runtime texture.

## Shop UI

Магазин должен ощущаться частью shop background, а не отдельным default modal window. Предметы располагаются в центральной свободной зоне canonical backdrop `assets/backgrounds/ui/ui_backdrop_merchant_archive.png`.

SCRUM-993 makes that contract the live responsive gold-shell implementation.
`ShopScreen` clips the complete 2560×1440 merchant archive with
`STRETCH_KEEP_ASPECT_CENTERED` inside the SCRUM-981 safe rect, keeps the dark
side gutters, and draws the shared hollow `meta40/frame_border.png` last at
z=100. Authored geometry and ready/fit reports for 1280×720, 1920×1080 and
2560×1440 live under `docs/design/mockups/scrum993_shop_gold_shell/`; renderer
captures for default/focus/unaffordable/purchased states live under
`docs/design/previews/scrum993_shop_gold_shell/runtime/`.

The four product hitboxes remain one horizontal, scroll-free focus ring. Their
caption plates use scaled source 9-slice margins and one-line ellipsis, price
badges fit four digits, unavailable products keep the icon/caption visible with
desaturated art and red price, and purchased products become a disabled
`снято` hook. Descriptions no longer use the cursor-following global tooltip:
hover/focus populates one fixed `ShopTooltipPanel` below the row. Its rails
scale with the displayed panel and text begins beyond rail + reserve. SCRUM-1073
uses a `700×148` compact panel with a `650×114` empty inner zone, containing all
wrapped semantic tooltip lines before the Back action at 720p. Leaving focus
hides the panel. Shop does
not create `UpgradeFabButton`; the manual Attribute Shop entry was removed by
SCRUM-982, while the mandatory post-combat shop remains SCRUM-987-owned.

Design-ready assets:

| Asset ID | File |
| --- | --- |
| `ui_shop_artifact_slot_frame` | `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png` |
| `ui_shop_artifact_slot_hover` | `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png` |
| `ui_shop_price_badge` | `assets/sprites/ui/shop/ui_shop_price_badge.png` |
| `ui_shop_purchased_overlay` | `assets/sprites/ui/shop/ui_shop_purchased_overlay.png` |
| `ui_shop_tooltip_frame` | `assets/sprites/ui/shop/ui_shop_tooltip_frame.png` |

## Attribute Shop UI

SCRUM-982/987/988 supersede the repeatable/manual Attribute Shop flow and its
old tall inner-panel layout. Route Map, Rest, Shop, Event and Escape/pause do not
offer a paid attribute-upgrade entry. Normal victories still open Attribute
Shop before returning to the map; elite victories still open it after the
artifact reward. Pending Level Up rewards remain reachable through the separate
`LevelUpPlusButton` on combat and non-combat screens and are not coupled to the
removed gold-spend FAB.

The live Attribute Shop reuses the shared hollow gold shell
`assets/sprites/ui/meta40/frame_border.png`; it has no second central
panel/frame. The shell is drawn last and all interactive content stays inside
its true empty safe zone. The offer area is one horizontal, scroll-free row:
two cards by default, or three when Atlas grants `attr_extra_options`. Every
card visibly includes the class interpretation, attribute influence and derived
before/after preview. SCRUM-1073 permits a compact two-line visible summary but
stores the exact unabridged influence/preview payload in label metadata and the
focus tooltip. Reroll and Skip are a horizontal action pair below the cards. Authored
metrics and live `resized` relayout cover 1280x720, 1920x1080 and 2560x1440,
including switching among those sizes while the screen remains open.

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

SCRUM-413/SCRUM-415 are the historical 720p hardening baseline. Their
scrollable, grid-based Attribute Shop layout is superseded by SCRUM-987/988's
single scroll-free offer row and horizontal actions; the unaffordable-card
state remains disabled/greyed and still explains insufficient gold. Random
event choices keep long descriptions inside the accepted choice-card safe zone
and normalize risk text so player copy shows a single `Риск:` prefix, never
`Риск: Риск:`.

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
SCRUM-672 historically moved `UpgradeFabButton` to the Rest screen root to
protect the campfire panel layout. SCRUM-982 now removes that manual paid
Attribute Shop entry from Rest entirely. The surviving invariant is that
`MenuPanel_campfire` continues to show `RestContent`, `RestTitle`,
`RestSubtitle`, the two rest choice cards and `RestBackButton`; the UI matrix
still fails on a blank panel/up-arrow-only shell or missing Rest content.

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

SCRUM-997 turns the Event screen into an illustrated encounter (spec:
`docs/design/mockups/scrum997_event_dialog/spec.md`, geometry single-sourced by
`_event_dialog_metrics()`):

- **Per-event background.** `ScreenBackground_event` swaps its texture to
  `assets/backgrounds/events/event_bg_<event.id>.png` when the SCRUM-998 art
  exists (`Main.event_background_path()`, file-convention manifest — no id
  dictionary in code); unmapped ids keep the shared `ui_backdrop_arcane_lab`
  fallback. Over native art the `ScreenBackgroundReadableShade` lightens to
  a=0.14 (the art reserves dark UI zones per the pack manifest); the fallback
  keeps the usual a=0.44.
- **Right-side dialog panel.** `MenuPanel_event` is a manually-rected atlas
  chip (`_atlas_chip_style(0.90, pad)`) pinned to the right safe edge, width
  `clamp(0.36·W, 330, 980)`, spanning from the top safe margin down to the
  bottom strip. Inside, the scroll keeps `EventContent` with left-aligned
  golden `EventTitle`, a brass `EventTitleRule` divider and light `EventStory`;
  long stories scroll instead of inflating the panel. The illustration on the
  left is never covered by text.
- **Bottom choice strip.** `EventBottomZone` (full-rect, mouse-ignore) hosts
  `EventChoiceRow` — exactly three `_make_economy_choice_card` chips sized
  `card_w × clamp(0.22·H, 142, 320)` — plus the unified 260-wide
  `EventBackButton` plate at the right end, vertically centered. Every card
  carries a SCRUM-997 hint line (`EventChoiceButtonNHint`): «Проверка: <Стат>
  <N>» for checks, a compact visible-reward summary, or «Исход скрыт» for
  hidden choices (price stays in `unknown_hint` per the SCRUM-996 contract).
- **Reveal.** The SCRUM-996 reveal keeps its node contract; visually the
  outcome text lands in the right dialog panel while `EventContinueButton`
  («В путь», 260-wide plate) is centered in the bottom strip and grabs focus.
- The UI no-overlap matrix enforces the new geometry: right-side panel
  (left edge ≥ 0.55·W, width ≈ 30–42%·W or the 980 clamp), title/story inside
  the chip content rect, the choice row inside the bottom strip and clear of
  the panel, hint lines inside their cards, back plate in the strip and clear
  of both, and a `ScreenBackground_event` (or fallback) node present.

SCRUM-674 historically rebuilt the Settings apply flow inside the existing
dark-fantasy frame contract. Its three pages `Экран`, `Звук`, `Управление` remain,
but SCRUM-1025 adds live `Игра` and `SettingsTabButton_3`; built-in
`TabContainer` headers remain hidden. Screen settings
(`SettingsScreenOption`, `SettingsResolutionOption`, `SettingsWindowModeOption`)
now stage values in a pending buffer and do not call `_apply_video_settings()`
until `SettingsApplyButton` is pressed; `SettingsRevertButton` discards the
pending buffer. `ScreenShakeToggle`, sound controls and controls/rebind settings
remain immediate-apply. Sound sliders are compact `420x42` rows with the same
dark track/gold fill/focus behavior, so they no longer stretch across the whole
content panel. Mockup/spec: `docs/design/mockups/scrum674_settings_ui/spec.md`;
OpenAI reference: `docs/design/references/scrum674_settings_ui/settings_apply_flow_mockup.png`.

SCRUM-974 expands the immediate-apply Sound page with three backed settings,
without adding a placeholder control: `ui_volume` («Звуки интерфейса»),
`mute_when_unfocused` («Без звука вне окна») and
`low_hp_warning_enabled` («Предупреждение о здоровье»). Four compact volume
rows are followed by two short toggle rows and the existing Reset action inside
`AudioScroll`. At 1920×1080/2560×1440 all content fits with the scrollbar hidden;
at 1280×720 the styled vertical scrollbar and `follow_focus` keep Reset and both
toggles reachable without shrinking labels or touching the footer/frame.
`SettingsResetAudioButton` restores all eight audio keys. PixelLab plan/source,
rejected candidates, compositor fit/debug evidence and exact responsive contract:
`docs/design/mockups/scrum974_settings_audio/`.

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

SCRUM-975 defines the Design handoff for a fourth Settings tab, `Игра`, over the
current fullscreen Atlas-family shell. It uses four independent global-kit tab
plates instead of stretching the obsolete three-slot switcher: one centered row
at 1920x1080 and 2560x1440, and a centered 2×2 grid at 1280x720. The Game page
contains five SCRUM-976 sandbox multipliers, a neutral/custom status, next-run
application and progression-restriction notices, and an atomic reset to `1.0×`.
The header, Back action and tab plates remain fixed; only Game-page content
scrolls at 720p. Every label, slider, value and hit area stays inside the real
empty frame interior, clear of dragon heads, gems, bevels and the dedicated
scroll lane. Exact rectangles, responsive rules, PixelLab provenance, generated
sources and debug-overlay evidence live in
`docs/design/references/scrum975_settings_game_tab/`; rendered previews live in
`docs/design/previews/scrum975_settings_game_tab/`. SCRUM-1025 now integrates
that accepted package:
four independent plates (one row wide / 2×2 compact), PixelLab Game icon,
five authoritative SCRUM-976 sliders, status/warning, atomic reset and
next-run-only semantics. `SettingsBottomActions` is hidden only on Game because
Apply/Revert belongs to staged Screen settings; Game content remains inside
the transparent clip owner and scrolls vertically with a dedicated 14px lane.

SCRUM-1053 hardens the remaining compact footer against the live Atlas bottom
ornament. Screen/Sound/Controls now budget an `88px`
`SettingsBottomActionsSafe` slot: the unchanged native `280x64` Apply/Revert
plates occupy its top and the last `24px` stay empty. At 1280x720 this produces
a 12px gap after `SettingsContentPanel`, a footer bottom exactly at the authored
inner boundary `y=583`, and 24px before the texture-safe edge `y=607`. Compact
Screen is now vertically scrollable (`SettingsScreenScroll`, `follow_focus`)
so its legacy rows cannot expand the VBox through that reserve. Game hides the
entire wrapper, so SCRUM-1025's `892x242` scroll viewport, `878x520` canvas and
exclusive 14px lane remain exact. Focused headless/Metal coverage also checks
the `<=760px` breakpoint at 1280x760.

SCRUM-1060 aligns the four Settings tab labels with the header Back action.
`SettingsTabButton_0..3` remain exact `260x72` plates in the compact 2x2 grid,
`260x88` at 1080p and `260x104` at 1440p, but are now consistently text-only.
Their effective font uses the same `_readable_font_size(16)` contract as
`SettingsBackButton`: `21/22/23/23 px` at 1152x648, 1280x720, 1920x1080 and
2560x1440. `_settings_fit_kit_row()` receives this as a fixed typography
contract and may calculate equal state margins but may not downscale it. Every
complete Russian label stays centered inside the plate's flat `x=48..212`
field; wrap, clipping, ellipsis and icon fallback are forbidden. The accepted
SCRUM-975 PixelLab Settings art is reused unchanged; adaptive spec and source
provenance live in `docs/design/mockups/scrum1060_settings_tab_font/`.

SCRUM-471 is the historical 1152x648 short-height guard for the former Attribute
Shop inner panel and Settings. Its Attribute Shop card/button metrics are
superseded by SCRUM-987/988's gold-shell relayout at 720p/1080p/1440p; the
Settings compression rule remains unchanged.

SCRUM-437 makes the wide 0.1.6 economy choice-card frame live in runtime for
rest, upgrade, event and Attribute Shop choices. Runtime now uses
`assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide.png` and
`ui_frame_economy_choice_card_wide_hover.png` (`960x640`, RGBA transparent) with
source size `Vector2(960, 640)`, texture margins `Vector4(96, 88, 96, 96)`,
content margins `Vector4(132, 118, 132, 128)`, hover content margins
`Vector4(140, 126, 140, 136)` and safe rect `Rect2(132, 118, 696, 394)`.
The historical display targets were `360x240` at 1280x720, `420x300` at
1920x1080 and `480x340` at 2560x1440, with a compact 1152px matrix fallback;
SCRUM-987/988 supersede those Attribute Shop geometry targets. The wide economy
card art remains reusable, but the live Attribute Shop cards reserve visible
space for icon/title, class interpretation, full stat influence, derived
before/after preview and price in one horizontal row. Runtime labels, icons and
focus/click content stay inside the scaled safe rect;
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

Main menu uses `assets/backgrounds/main_menu_epic_battle_v3.png` through
`MAIN_MENU_BACKGROUND`. FAN-1097 replaces the composited FAN-1088 art with one
cohesive 2560x1440 scene generated and corrected through the built-in OpenAI
Image Generator in Codex: one unarmed barbarian stands on a basalt cliff above a
large violet disk-shaped rift, backed by ruined spires and storm mountains. The
focal art stays center-right/right, while the calm left button column and
title-safe area remain free of key silhouettes; a targeted second pass also
quieted the lower-right utility zone. The proportional cover-crop contains no
baked UI text, buttons, frames, labels, logo, cursor or watermark. Built-in
sources, both prompts, backup, mockup, responsive matrix and safe-zone evidence
are tracked in
`docs/design/mockups/fan1097_main_menu_openai_background/spec.md` and
`docs/design/references/fan1097_main_menu_openai_background/manifest.json`.
The former FAN-1088 runtime image is backed up under
`docs/design/backups/fan1097_main_menu_openai_background/`; the FAN-1088 package
remains historical provenance.
SCRUM-680 release refresh keeps the title as
`assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` (`960x360`,
transparent, PixelLab crest source in
`docs/design/references/main_menu_logo_release_fix/`). The historical
SCRUM-484 single column and SCRUM-981 2×3 grid are superseded by the SCRUM-1059
authored-inner single-column contract described above.

## Route Map Horizontal Gold Shell

SCRUM-1057/1079 replaces the previous vertical geometry with an accepted
PixelLab-authored horizontal contract: start at left, boss at right, route steps
increase strictly on X and branches within a step separate on Y. Runtime uses
horizontal auto-scroll only; the vertical scrollbar is disabled and
`scroll_vertical=0`. The raised header/title/resource wells, node viewport,
bottom scrollbar lane and pending-level FAB keep-out follow exact matrices for
1152×648, 1280×720, 1600×900, 1920×1080 and 2560×1440. Spec/provenance:
`docs/design/mockups/scrum1057_route_map_horizontal/spec.md`; runtime matrix:
`docs/design/previews/scrum1079_route_map_horizontal_runtime/`.
SCRUM-1086 добавляет width-measured responsive status copy: 1152/1280
используют полную компактную фразу без ellipsis, а 1600/1920/2560
сохраняют прежний полный текст. Live resize меняет copy без изменения
authored title-zone geometry.

The production outer shell remains the hollow SCRUM-981
`assets/sprites/ui/meta40/frame_border.png`; all controls stay inside its real
empty content zone. The older SCRUM-563 vertical 2K source package remains
historical design evidence only.

SCRUM-1089 supersedes the scrollable portion of that contract with the live
full-fit layout requested from the 2026-07-12 route-map screenshot. All nine
columns (eight activity steps plus boss) are now visible simultaneously;
`RouteMapScroll` remains as a clipping/input compatibility node but both scroll
axes and both scrollbar lanes are disabled and pinned to zero. The node canvas
equals the authored node viewport, columns use the complete safe width, and
multi-branch columns expand 55% toward the maximum safe vertical spread instead
of clustering around the centre. The raised header uses the outer shell's real
irregular empty zone: side/corner rails keep the 160px source boundary while
the clear central top/bottom opening uses the measured 128px boundary plus
24px reserve (32px at 2560×1440). HP/XP/ULT/gold is exactly 2× the former
visible SCRUM-1079 Route Map cluster; compact 1152/1280/1600 tiers stack the
title above it, while 1920/2560 keep title and resources side by side. The
PixelLab textless layout source, exact matrix, user-before reference and runtime
captures are under `docs/design/{mockups,references,previews}/scrum1089_route_map_full_fit_hud2x/`.

## Hero / Weapon / Level-Up Layout Rules

- Historical SCRUM-980 (superseded by SCRUM-1063 below) replaced the old left-column ascension geometry while preserving
  the active HS4/Atlas art and selected-level semantics. `HS4AscensionFrame` is
  now a wide right-hand band between `HS4DossierFrame` and `HS4Carousel`;
  `HS4AscensionActionRow` occupies its left safe segment and the untrimmed
  `AscensionModsLabel` occupies `HS4AscensionDescriptionScroll` in the right
  segment. At 1280×720 the text scrolls vertically; at 1920×1080 and
  2560×1440 the current-level delta fits in full. `HS4CarouselCounter` reserves
  a separate segment beside the frame, while `HS4ChooseButton` remains at the
  bottom of the left portrait column. Stepper, description, counter, carousel,
  dossier and CTA must never overlap or cover frame ornament. Focused geometry
  coverage: `tests/hero_select_scrum980_ascension_layout_test.gd`; transient
  rect/screenshot evidence: `build/qa/scrum980/`.
- Historical SCRUM-1026 (superseded by SCRUM-1063 below) made the full-size portion of that contract exhaustive instead of
  relying on the shorter level-2 sample. At viewport heights `>=1000`,
  `HS4AscensionFrame` has a 132 px minimum and stays bottom-anchored above the
  carousel, so it expands upward into the scroll-safe dossier budget only.
  Every selectable delta 0..5 has zero vertical overflow at 1920×1080 and
  2560×1440; 1280×720 uses a 69 px band so its real 59 px utility row stays
  inside 5 px top/bottom frame content margins, while the copy keeps its
  intentional internal scroll. The focused gate uses physical viewport-bounded `−`/`+` and hero-slot
  pointer input, validates exact cumulative tooltips, scroll reset and D-pad
  boundary transfer, and records every level's label/viewport/overflow metrics.
  No art, frame texture/content margin, carousel, counter, portrait or CTA
  geometry changes. Spec:
  `docs/design/mockups/hero_select_black_minimal/scrum1026_ascension_level3_responsive_spec.md`.
- SCRUM-1063 supersedes the visible SCRUM-980/1026 modifier-scroll lane and
  SCRUM-979's clamped carousel edges. The live Ascension strip contains only
  symmetric wide `−` / centered exact `Возвышение N` / wide `+`; complete
  cumulative modifiers remain on the frame/value/button tooltips. All four
  controls reuse accepted PixelLab `button_asc_minus.png` through the same
  9-slice/content rect and the same normal/hover/pressed/focus/disabled states.
  Width is exactly twice the former rounded carousel width while height is
  preserved: `142×94`, `142×94`, `150×100`, `202×134` at 1152×648, 720p,
  1080p and 2K. Label/button midpoint error is `0 px` at all targets. Carousel
  Previous wraps first→last/final-window and Next wraps last→first/first-window;
  pointer, physical Enter, gamepad A and cyclic D-pad focus share the same
  selection/window/dossier/portrait/counter/Ascension refresh. Compact cards
  scale uniformly to 116/132 px so every target retains three disjoint slots.
  Spec/provenance: `docs/design/mockups/scrum1063_hero_carousel_wide_buttons/`
  and `docs/design/references/scrum1063_hero_carousel_wide_buttons/`.

Historical SCRUM-952 made the Hero Select dossier's class identity readable via
`Особенность`, `Плюсы`, `Минусы`. SCRUM-1064 supersedes that visible hierarchy:
the scroll lane now renders optional canonical trait first in exact format
`Особенность: <title> — <short_description>`, then name, all three canonical
weapons, deterministic top-3 `BASE_STATS` with values, and complete primary /
secondary attribute lists. FAN-1887 removes the «Слабые атрибуты» rail: the
dossier lists only what the hero can actually receive, exclusions are never
displayed as choices. Free description and prose strengths/weaknesses are
absent from the live tree; no `+N`, ellipsis or line cap hides available
registry entries. The right eight colored stat bars remain fixed.

`HS4DossierScroll` owns overflow at every tier, reserves a separate scrollbar
lane (16 px at 1080p plan, 14 px compact), is keyboard/gamepad focusable, and
resets to the first line whenever the selected hero changes.
SCRUM-1046 makes that input contract explicit: keyboard/D-pad/left-stick
`ui_up/down` and PageUp/PageDown scroll the text lane first, retaining dossier
focus while content remains; at the actual top/bottom only, the same action
hands focus to Back/Choose. The handler is local to `HS4DossierScroll`, so it
does not steal global gameplay input or bypass configurable controller binds.
`ProgressionData.CLASS_TRAITS` remains the only trait source; Codex projects the
same title, short copy and detailed copy. Frame, portrait, stats, ascension and
carousel geometry are unchanged. SCRUM-1064 also rebuilds only the Hero Select
screen after a live viewport resize, without resetting route/run state.
Accepted PixelLab reuse + content-zone evidence:
`docs/design/mockups/scrum1064_hero_dossier/`.
- Historical SCRUM-798 baseline (its ascension placement is superseded by
  SCRUM-980 above) keeps the 2026-06-30 user-requested minimal Hero Select
  sizing/information hierarchy. The selected `HS4Portrait` is the dominant
  left-column object and keeps SCRUM-416/SCRUM-687 directional SpriteFrame
  rotation when available. The right `HS4DossierFrame` is scroll-safe and
  contained class title, description, strengths, weaknesses, weapon names,
  class identity, eight base characteristics as hoverable Line Bars and
  data-driven build guidance; SCRUM-1064 supersedes that text content while
  retaining the same frame/stat geometry. The bottom `HS4Carousel` uses enlarged responsive
  slots and default focus on the selected visible slot. Historical SCRUM-979
  introduced the moving window; SCRUM-1063 restores cyclic first↔last edges
  while preserving the one-step window/selected-anchor behavior. Since
  SCRUM-421/SCRUM-822, large and carousel portraits use cached alpha bounds for
  consistent centering/bottom alignment and reserve a name strip. Historical
  evidence: `build/qa/scrum-798/`, `build/qa/scrum421/`,
  `docs/design/mockups/hero_select_black_minimal/scrum822_preview_crop_labels_spec.md`.
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
- Historical SCRUM-979 made the live HS4 carousel window the primary navigation state.
  `HS4CarouselPrevButton` / `HS4CarouselNextButton` shift its clamped offset by
  exactly one in `ProgressionData.character_ids()` order and preserve the
  selected visible-slot anchor; the hero newly occupying that slot becomes the
  selection. Its clamped edge no-ops are superseded by SCRUM-1063 cyclic wrap.
  Direct slot clicks keep
  the current window and select the exact clicked hero through the same portrait,
  dossier and ascension refresh path. The visibly larger arrows reuse the
  accepted PixelLab vertical plates and their authored empty content margins;
  SCRUM-1063 replaces them at runtime with the shared horizontal PixelLab plate.
  Mockup/spec: `docs/design/mockups/scrum979_hero_carousel_window/`.
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

- SCRUM-396 is the historical SCRUM-391 Settings tab-switcher integration:
`assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`
(`1280x256` RGBA). It has exactly three slots in the red-gold/dark-steel style,
with safe rects `Rect2(160,88,270,82)`, `Rect2(506,88,270,82)` and
`Rect2(852,88,270,82)`. Runtime `SETTINGS_TAB_SWITCHER_FRAME_PATH` points to
this 3-slot asset, `SETTINGS_TAB_SWITCHER_SAFE_RECTS` contains exactly those
three rects. SCRUM-1025 supersedes that runtime geometry with four independent
plates; the old 3-slot bitmap remains reference/backup only.
- SCRUM-439 historically integrated the Settings v2 rebuild for Sprint 0.1.6:
`docs/design/mockups/scrum439_settings_v2/spec.md`,
`scrum439_settings_v2_mockup.png`, `docs/design/previews/scrum439_settings_v2_safe_zones.png`
and transparent candidate frames in `assets/sprites/ui/frames/settings_v2/`.
That mockup covers the former three tabs (`Экран`, `Звук`, `Управление`) and records a
new three-slot tab switcher, modal frame, section panel and control-row safe
zones. That runtime used the v2 main modal and proportional 3-slot switcher,
preserved the settings/rebind semantics, kept exactly three tab
buttons, and places labels, icons, sliders, dropdowns, checkboxes, focus rings
and scroll bars only inside modal safe areas. The dense v2 body used a flat
inner safe panel rather than the optional section/control-row frames, because
those candidates' source margins would clip controls or collide with the Back
button at 720p. SCRUM-879/972/1025 supersede this shell and tab count.

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
- SCRUM-985 removes the largest Level Up shell without changing the three-card
  reward flow. Runtime no longer creates `LevelUpFrame`; `LevelUpPanel` remains
  only as a responsive safe-margin/layout host with `0.20` alpha and no visible
  border. The arcane-lab backdrop uses a brighter color modulation, a `0.12`
  readable shade, and a `0.24` intro dim instead of the SCRUM-892 `0.82` dim.
  Local card/socket ornament stays visible. Level Up explicitly opts out of the
  registry's small-icon readability enlargement, so each reward icon keeps the
  exact calculated inner socket rect and never crosses the ring. SCRUM-1032
  makes the advisor badge a separate stack row even in the compact 720p tier;
  it never overlays the socket ornament or reward icon, and every card reserves
  the same row so sockets/titles remain aligned. The responsive matrix also
  verifies that the full Russian badge label fits and focus does not move the
  badge/socket/icon geometry. PixelLab-first
  provenance and the accepted no-shell mockup live under
  `docs/design/mockups/scrum985_level_up_cleanup/` and
  `docs/design/references/scrum985_level_up_cleanup/`; runtime captures for
  1280x720, 1920x1080 and 2560x1440 live under
  `docs/design/previews/scrum985_level_up_cleanup/`.
- SCRUM-571 adds the Design-source 2K ordinary reward mockup/spec package for the post-battle reward selection screen. Source geometry and safe-zone files live under `docs/design/mockups/scrum571_reward_2k/`, the OpenAI base layer under `docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png`, and previews under `docs/design/previews/scrum571_reward_2k_*.png`. As of SCRUM-670 this package has no isolated alpha runtime frames, so runtime intentionally keeps the SCRUM-338 reward-card kit instead of slicing the full-screen mockup.
- SCRUM-572 adds the Design-source 2K elite artifact reward mockup/spec package for the elite victory artifact-choice screen. Source geometry and safe-zone files live under `docs/design/mockups/scrum572_elite_artifact_reward_2k/`, the OpenAI base layer under `docs/design/references/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_base.png`, and previews under `docs/design/previews/scrum572_elite_artifact_reward_2k_*.png`. As of SCRUM-670 this package has no isolated alpha runtime frames, so runtime intentionally keeps the SCRUM-338 elite reward-card kit instead of slicing the full-screen mockup.
- SCRUM-404 wires the dedicated SCRUM-338 reward-card frame kit for battle rewards and elite artifact rewards: `assets/sprites/ui/frames/rewards/ui_frame_reward_card.png`, `_hover.png`, `ui_frame_reward_elite_artifact_card.png` and `_hover.png`. Runtime uses the metadata in `docs/design/references/rewards/reward_frames_scrum338_metadata.json`, keeps title, icon, description, artifact tier labels and `Получить`/choice content inside the safe content fields, and preserves whole-card click/focus without placing UI content on red gems, top crests, side metal or bottom ornaments. Runtime smoke writes SCRUM-338 card rect dumps to `build/qa/scrum338/`.
- SCRUM-990/991 supersede the elite/boss full-screen portion of that historical
  package. Elite/chest and boss artifact choices now share one responsive
  reward-hall builder: canonical `ui_backdrop_reward_hall.png` below, one hollow
  `meta40/frame_border.png` shell above, and no visible central modal or second
  ornamental screen frame. The outer frame is the final mouse-ignore child.
  Exact inner content rects are `157,137 966×446` at 1280×720,
  `224,193 1472×694` at 1920×1080 and `299,257 1962×926` at 2560×1440.
  Title, subtitle and all three Atlas-chip cards remain in that empty zone on
  live resize. The PixelLab-first component mockup, validated UI plans and
  compositor proof live under
  `docs/design/{mockups,references,previews}/scrum990_991_artifact_reward/`;
  production intentionally reuses the ticket-required shared frame/background.
- Artifact reward cards no longer expose a separate generic `Interpretation`
  line. `ArtifactRewardPresenter` dry-runs each reward with the same stats/mods
  semantics and `ProgressionData.derived_parameters()` formulas as runtime,
  names the current class and shows concise concrete before/after deltas or the
  artifact's concrete conditional description. Across the three offers only a
  unique positive, safely modelled top gain receives `Лучший урон` or
  `Лучшая выживаемость`; a unique hybrid may receive both. Ties, zero/negative
  gains and mechanics outside the derived model receive no badge rather than a
  guessed recommendation. Full detail remains in the card tooltip.

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

SCRUM-955 supersedes that five-section data/navigation statement using the
independently accepted PixelLab and content-zone package from SCRUM-1013. The
active rail has six fixed Russian tabs: `Персонажи`, `Монстры`, `Артефакты`,
`Характеристики`, `Атрибуты`, `Возвышение`. The rail width and button content
margins scale so the longest label plus icon fits without ellipsis at
1280x720, 1920x1080 and 2560x1440. `Характеристики` is the exact ordered
`BASE_STAT_ORDER` projection (8 rows); `Атрибуты` (FAN-1887/FAN-1927) is the
exact ordered `ProgressionData.ATTRIBUTE_REGISTRY` projection via
`AttributeContract.canonical_axes()` — the canonical 16 player-facing axes with
registry ids/names/units (`damage_flat` «Добавление урона» + `damage`
«Увеличение урона» instead of the removed derived aliases `Урон`/`Магический
урон`; removed internal parameters such as attack range, projectile speed, DoT
tick rate, aura radius, buff power, absorb and the split vampiric chance are no
longer separate Codex attribute rows; vampiric is a single row whose text
covers the 20% proc-chance condition). Each derived row additionally carries a
live «Этот герой» section from `AttributeContract.axis_snapshot` (current
effective value, damage channel of the CURRENT weapon, cap state, run history);
a class/weapon-ineligible axis is explicitly marked as not issued to this hero.
Both lists remain lazy/cached.

The dossier follows the accepted split content zones: `CodexDetailLeftRail`
contains the centered, aspect-preserving icon and
`CodexDetailRelatedScroll`; `CodexDetailRightRail` contains title, semantic
Russian chip, and `CodexDetailParchmentInset`. SCRUM-1021 makes the related list
an exact projection of `StatFormulas.DERIVED_BASE_DEPENDENCIES`, a canonical
26-row matrix mirroring `ProgressionData.derived_parameters`; localized
formula/influence prose is never parsed as data. Derived rows preserve
`BASE_STAT_ORDER`, base rows are the exact inverse filtered to the canonical
registry axes (FAN-1887/FAN-1927: `AttributeContract.canonical_axes()` unions
the dependencies of each axis's runtime parameters; removed axes are not
presented as available attributes), and
Russian display titles remain presentation-only. `ultimate_multiplier` lists
all eight base characteristics; derived attributes with no direct base input
(range/vampiric run modifiers) correctly expose an empty relation set.
SCRUM-1023 keeps the selected dossier title on a mockup-native resolution
scale rather than the global readability boost: 15px at 1280x720, 22px at
1920x1080, 29px at 2560x1440 and a 30px cap at 4K. This preserves the accepted
title rect while guaranteeing at least one rendered line; the responsive
Codex gate checks `Label.get_visible_line_count()`, not only rect height.
The two rails, all six tabs, center rows and scrollbars remain inside the dark
panel interiors; the hollow frame ornament stays unobstructed. No row or chip
shows raw character, monster, artifact or stat ids. Focused coverage lives in
`codex_data_smoke_test.gd`, `runtime_smoke_test.gd` and the 720p/1080p/1440p
Codex branch of `ui_no_overlap_matrix_test.gd`.

SCRUM-954 supersedes the previous container geometry with the independently
accepted SCRUM-1017 PixelLab/content-zone contract. Runtime uses a real
1920x1080 `CodexStage`, uniformly scaled by
`min(viewport_width/1920, viewport_height/1080)` and letterboxed for other
aspect ratios. Base panel rects are `CodexNavPanel 72,172,324,840`,
`CodexContent 420,172,620,840` and `CodexDetailPanel 1064,172,784,840`.
The old full-screen `CodexFrame` is removed because its 160px rails covered the
new header/nav zones at 720p and 1080p; the title, Back control and each panel
now own explicit safe margins. The six navigation controls contain only
centered Russian labels on the shared back/main button family, with no category
emblems. Center rows are 516x154 design pixels and expose exactly one canonical
image plus one centered Russian display-name; summary prose, raw ids and English
duplicates live outside the list. The right dossier uses a contained 236x248
image zone and a single 610x304 lower text scroll. Stat relations are projected
inside that lower scroll, so only the center list and dossier have visible
scrollbar lanes. The stage-aware font clamp keeps nav/names/title within
15–30 visual px and dossier text within 17–32 visual px. Ascension rows reuse
the canonical combat-HUD ascension icon; shop-derived artifact rows resolve the
existing `shop/shop_<id>.png` family before the fail-safe icon. Exact
720p/1080p/1440p coverage and windowed screenshots are
produced by `codex_scrum954_layout_test.gd`; the Codex branch of
`ui_no_overlap_matrix_test.gd` checks the same transformed rects and content
zones. Font metadata is refreshed on live window resize without rebuilding the
six cached sections. Persistent windowed previews live under
`docs/design/previews/scrum954_codex_runtime/`.

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
and anchored bottom-right, and keeps its pending-count badge readable. On Route
Map and other non-combat screens it remains the dedicated entry for saved
pending level-up offers after SCRUM-982 removes the unrelated paid Attribute
Shop FAB. Runtime smoke writes `build/qa/combat_level_up_button.md` and
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

The in-run `EndRunConfirmationDialog` deliberately has a separate width
contract. SCRUM-1055 gives both `Завершить` and `Отмена` equal 240x72 slots on
the native `text/continue_240x72` five-state family. This leaves at least a 4px
text-fit reserve after the style content margins at supported font scales, so
the final soft sign in `Завершить` cannot be clipped. The 600px atlas-chip panel,
18px inter-button gap, safe default focus on Cancel, and Escape/B behavior stay
unchanged.

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
is covering gameplay, Escape opens the pause dossier / character board directly.
SCRUM-983 originally moved the four run actions into a fixed footer, with
Continue focused first. SCRUM-1056 removed the pause-only/danger styling, and
FAN-1047 fixes the remaining source cropping: Continue, Settings, End Run and
Main Menu all use the exact `main_menu_380x104` five-state family. Compact
targets use the right vertical rail described above; 1080p/2K keep the bottom
footer. The old
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

SCRUM-983 supersedes the old pause-dossier placement while preserving those
readability minima. SCRUM-1056 removes the dossier scrollbars and replaces the
old overflow layout with a no-scroll responsive contract. The live screen reuses the SCRUM-981 hollow gold shell and
adds a real inner reserve beyond the scaled 160px rails: exact inner rects are
`157,137,966,446` at 1280×720, `224,193,1472,694` at 1920×1080 and
`299,257,1962,926` at 2560×1440. Header, hero/derived body and the fixed footer
remain inside those rects; `HeroCardScroll` and `DerivedStatsScroll` have both
scroll modes disabled and must report `content minimum <= viewport`. Base stats are
eight semantic rows in `BaseStatsGrid` (2 columns at every tier);
the 1080p two-column name lane must fit at least the rendered short localized
label `Сила`. Four opaque reserve masks cover everything outside the inner rect
below the content/final frame, preventing any combat HUD from showing through
gold ornament. Derived stat groups remain 2×2 and show deterministic readable
compact aliases without clipping either aliases or localized numeric values;
canonical names remain in tooltips. Every stat target is keyboard/gamepad focusable,
uses geometric D-pad neighbors, and exposes the same complete
description/formula/source/influences through one shared hover/focus tooltip.
The former long Arsenal/Equipment blocks are condensed into the always-visible
`RunBuildSummaryPanel`; full weapon, ultimate and artifact details remain in its
tooltip. The header preserves the complete class + weapon identity with an
explicit rendered-text lane and a 24px local reserve before the irregular
top-right ornament; clipping, wrapping and ellipsis are forbidden across the
1152×648/720p/900p/1080p/2K matrix and live resize. Stat rows disable the generic 460/620px engine popup; the dossier tooltip is a
clipped vertical viewport that never exceeds 430×288 and scrolls by wheel,
Page Up/Down or gamepad shoulders. Wheel is captured only during an actual stat
hover; after the pointer leaves stat rows it does not move the no-scroll dossier
or the focus-only tooltip. Footer Up neighbors resolve from visible stat rows.
The acceptance matrix covers 1152×648, 1280×720, 1600×900, 1920×1080 and
2560×1440. Runtime oracle:
`tests/scrum983_escape_dossier_test.gd`; visual evidence:
`build/qa/scrum983/`.

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
`FeedbackScreenshotPreview`, default-on `FeedbackScreenshotToggle`, complete
privacy/operator/retention/local-fallback disclosure, `FeedbackSendButton` and
`FeedbackCancelButton`. Escape closes only this overlay, while normal text
input remains inside the text field.

The screenshot is captured before the overlay is created. Sending is handled by
`scripts/feedback_reporter.gd`: schema-v2 relay reports use a bounded JPEG or
explicit JSON `null`; opted-out reports never retain/encode/send/save image
bytes. Missing/failed delivery falls back to `user://feedback/<timestamp>/`,
and the opt-out path creates only `report.txt`.

FAN-1057/FAN-1059 replaces the old narrow vertical form with a PixelLab-first
responsive contract. At 1920×1080 the centered 1400×990 panel uses a two-column
description/screenshot row plus a full-width privacy field; 2560×1440 scales
the geometry uniformly to 1866×1320. At 1280×720 the 1200×672 panel keeps
title/status/actions pinned and changes the middle to a one-column 824px scroll
body. Live resize switches the same Controls without losing player text.
Intermediate panel geometry is continuous at 1400/1401 and 1599/1600; a
constrained middle body remains scrollable. Focus is TextEdit →
ScreenshotToggle → Send → Cancel, while the right stick scrolls disclosure from
any focus stop. PixelLab source,
provenance, exact zones and fit evidence:
`docs/design/mockups/FAN-1057_feedback_privacy/` and
`docs/design/references/FAN-1057_feedback_privacy/`; runtime/protocol details:
`docs/design/systems/feedback_reporting.md`.

## Settings Tabs

SCRUM-439 superseded the older SCRUM-396 switcher-only runtime with the full
Settings v2 modal. That historical settings screen drew
`assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_main_modal.png` and
the design-ready 3-slot switcher
`assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_tab_switcher_3slot.png`
(`1280x256`, RGBA transparent, no baked text). The switcher is displayed as a
whole-image proportional 5:1 strip so it is never stretched on one axis. The
built-in `TabContainer` headers remain hidden. Current `SettingsTabs` owns four
pages, while `SettingsTabButton_0..3` switch `current_tab`.

SCRUM-879 later promoted Settings into the shared fullscreen Atlas shell while
preserving the native pages and controls. SCRUM-972 defines the current
content-surface contract: `SettingsContentPanel` remains the centered responsive
width/clip owner and retains positive content margins, but both its style and
the hidden `SettingsTabs.panel` style are fully transparent with zero borders.
Rows therefore sit directly on the single dark sanctum background; there must
be no gray inset, inner outline, bevel, shadow or second frame between the tab
plates and footer. The outer `SettingsFrame` stays hollow/on top, and every
control remains inside `SettingsSafeArea`. PixelLab direction, exact zones and
fit/debug evidence: `docs/design/mockups/scrum972_settings_seamless_content/`;
runtime matrix: `build/qa/scrum972/`. SCRUM-1025 extends this same transparent
surface to `Игра`: panel widths `960/1158/1544`, Game scroll widths
`892/1068/1424`, compact logical content `878×520`, and four standalone
tab plates. The source compact mockup's `306px` viewport omitted the live Atlas
border; runtime uses a frame-safe `242px` viewport at 720p (max scroll `278`)
so the bottom state exposes rows 3–5 and Reset entirely above the ornament.
All five rows remain inside the empty frame interior.

The SCRUM-1060 live switcher is text-only even though the accepted SCRUM-975
icon PNGs remain in the repository as source/history. Removing the icons from
all four tabs frees the complete 164px flat label lane and lets `Управление`
retain the same effective font as Back without touching the dragon end caps.

The following safe-rect table is historical SCRUM-439/v2 evidence, not the live
SCRUM-1025 switcher contract. In that former whole-strip asset, runtime labels,
click and focus zones had to stay inside these three source rects:

SCRUM-626 fixes Settings return-origin tracking. Settings opened from the main
menu returns to the main menu on Back/Escape, while Settings opened from the
in-run pause/dossier flow returns to the appropriate run pause surface and
preserves the active run state instead of rebuilding the start screen.

| Slot | Safe Rect |
| --- | --- |
| `tab_0_screen_safe` | `Rect2(150, 78, 275, 92)` |
| `tab_1_audio_safe` | `Rect2(502, 78, 275, 92)` |
| `tab_2_controls_safe` | `Rect2(854, 78, 275, 92)` |

That v2 asset had no fourth runtime slot or hit area. SCRUM-1025 supersedes this
limitation with four independent global-kit plates, including live
`SettingsTabButton_3`; it does not place a fourth hit area on the old ornament.

For the archived v2 strip, text, icons, click zones and focus rings must not be
placed on its metal bevels, dragon heads, red gems, dividers or lower rail. Preview:
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

SCRUM-1002 makes Godot editor previews ignore saved fullscreen at launch and use
a bordered, resizable, screen-fitting window. The override is non-persistent:
exported/runtime builds still use the saved video mode and resolution.

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

SCRUM-1024 fixes the 1280×720 responsive minimum-size contract without changing
Atlas art, graph or purchase semantics. The authored content rectangle remains
the frame's scaled `160/1536` horizontal and `0.86 × 160/1024` vertical inset.
When that safe width is below 1420 px, the two header currency chips keep their
icons and exact numeric counts while the full localized currency/class phrase
moves to the tooltip; the three standard 260 px action plates remain unchanged.
All variable dossier copy — description, condition/lore, constellation progress
and hidden-star hint — lives in `AtlasNodeScroll`; price and explicit Buy remain
pinned below it. The dossier scroll is focusable, supports mouse/`ui_up/down`,
resets to the first line on every node/class/tab refresh and hands focus to
Back/Buy at its boundaries. Currency chip children are mouse-ignore so hovering
either icon or number resolves the parent's full tooltip. `AtlasClassStrip.follow_focus` keeps the ninth
row of the 17-hero grid reachable on 720p. The focused bounded oracle refuses
synthetic off-viewport pointer coordinates and verifies every live hitbox,
every socket/circle, class/Guild preview-only state and exact explicit spend on
1280×720, 1920×1080, 2048×1152 and 2560×1440.

SCRUM-1091 реализует accepted SCRUM-1090 hierarchy внутри того же
`AtlasNodeScroll`. Schema-6 dossier показывает scope/weapon, axis, exact
`before → after`, результат и путь; финал предваряется native-label
`УНИКАЛЬНЫЙ ФИНАЛ` и раскрывает trigger/caps/boss/floor. Цена и Buy остаются
соседями scroll в `AtlasNodePanelBox`, то есть всегда pinned; weapon final не
показывает legacy `AtlasKeystoneToggle`. `AtlasNodePanel` держит 30px content
reserve от орнамента, а длинный текст прокручивается на 720p без уменьшения
семантического шрифта. Focused matrix:
`tests/scrum1091_atlas_dossier_ui_test.gd`.
The class-hidden state follows schema 6 end to end: a recorded reveal fact and
the attached order-3 path expose a cost-1 Buy action; only that explicit
purchase lights the star and applies its weapon-scoped effect.

SCRUM-1094 hardens the same fail-closed panel path: an invalid class dossier has
higher precedence than ordinary locked/currency/purchased hints. Available and
locked malformed nodes both retain the exact explicit schema failure, keep Buy
visible but disabled and never show a plausible generic fallback. Regression:
`tests/scrum1094_atlas_failure_precedence_test.gd`.

SCRUM-971 adds `AtlasCenterColumn`, a responsive vertical owner for the native
`AtlasSelectedClassLabel` row and the existing expanding `AtlasCanvas`. The
localized label is refreshed from `ProgressionData.character_config(class_id)`
on initial open, class-medallion selection and both tab paths. It remains
pointer-pass-through and unframed; the reserved row keeps it disjoint from the
header, class grid, socket canvas, dossier and footer at 1280×720, 1920×1080,
2048×1152 and 2560×1440. PixelLab/content-zone evidence is stored under
`docs/design/mockups/scrum971_atlas_class_label/`; runtime reuses the existing
Atlas art rather than adding the mockup as a production texture.

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
- Досье паузы (`PauseStatsMenu`): старт — «Продолжить» в fixed footer;
  left/right cycles the four actions, up/down enters the closest semantic stat
  row, stat navigation preserves geometric rows/columns and focus-follow scroll;
  B/Esc обрабатывается централизованно в `main._input`.
- Смерть/победа (`_show_death_screen`, `_show_victory_screen`): старт — основная
  кнопка; B/Esc = основная кнопка (нет «пустого» закрытия).
- Магазин/отдых/улучшение (`_show_shop_screen`, `_show_rest_screen`,
  `_show_upgrade_screen`): товары/карточки фокусируемы, «Назад» доступна ui_down,
  покупка/выбор по A, выход по B.
- Карта маршрута (`route_map_screen.gd`): доступные ноды — `FOCUS_ALL`, недоступные
  `FOCUS_NONE` (пропускаются); крестовина/стик двигают выделение по доступным нодам,
  A подтверждает (`Button.pressed`), заметная золотая кайма (`focus`-стайлбокс),
  Left/Right ищут ближайшую доступную колонку, Up/Down двигаются по веткам
  текущей колонки, а horizontal scroll следует за фокусом. Мышь идёт своим путём
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
- Магазин атрибутов (`_show_attribute_shop`, FAN-1887: пул после consumability-фильтра — Лидерство только summon-способным классам): 2 докач-опции по умолчанию или 3 с
  Atlas-бонусом находятся в одном горизонтальном focus ring, старт — первая
  доступная опция; Down ведёт к горизонтальной паре Reroll/Skip, scroll отсутствует.
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

## SCRUM-963 — Артефактный UI: редкость, классовая пометка, иконки (0.2.1)

Единый канон отображения артефактов на всех поверхностях (данные — SCRUM-960/961,
иконки — SCRUM-962, контракт — `artifact_system_matrix.md` §1.1/§7.4).

**Редкость.** `tier` и есть редкость; player-facing подписи — `TIER_LABELS`
(`ui_screens.gd`): 1 «Обычный» / 2 «Редкий» / 3 «Эпический», цвета `TIER_COLORS`
прежние (светлый/голубой/оранжевый). Номера тиров игроку не показываются нигде:
хинт сундука маршрута (`route_map_screen._elite_artifact_tier_hint`) — «шанс
эпического / ориентир — редкий / ориентир — обычный или редкий», сабтайтл трофея
босса — «Выбери 1 из 3 эпических артефактов», капстоун Атласа «Связи в гильдии» —
«гарантированно есть эпический товар». Для ПОЛУЧЕННЫХ артефактов показывается
роллнутый тир записи забега `player.artifacts[].tier` (HUD-тултип, чипы
«Экипировки» паузы — имя цветом редкости + тултип), фоллбек — корневой тир
определения (старые сейвы без поля живы, редкость без тира не рисуется).

**Иконки.** Все карточки наград с артефактами используют уникальную
`artifact_<id>.png` через `_make_reward_card_icon` (элитка/босс/сундук —
`_make_elite_artifact_card`; пост-боевой выбор — `_make_battle_reward_card`);
стат/атрибут-награды остаются на реестровых иконках `UIIconRegistry`. Магазин
(`_shop_item_icon_path`), HUD-ряд (`_refresh_artifact_hud_row`), кодекс и
экипировка паузы (`pause_stats_menu._equipment_artifact_icon`) грузят тот же
файл. Fallback (`buff_power`) — только dev-страховка: гейты
`tools/validate_artifact_icons.py` (данные 154 = иконки 154) и
`codex_data_smoke_test` (ResourceLoader.exists на каждый id + запрет латиницы
в титулах).

**Классовая пометка.** Формат `_artifact_affinity_note`: «Класс: <RU> ·
Возвышение 5» (цвет 0.55/0.92/1.0). Показывается у ЛЮБОГО классового артефакта:
на своих — знак эксклюзива класса, на cross-class выпадениях «Украденного герба»
— честное имя чужого класса. Поверхности: карточки наград (нижняя строка вместо
генерик-«Интерпретации», которая осталась только у универсалов со stats/mods),
тултипы карточек/HUD (суффикс `[Класс: …]`), магазин (строка тултипа; бейдж «!»
— ТОЛЬКО на чужеклассовом товаре), кодекс. Старая формулировка «Тематика»
упразднена (глоссарий `affinity` переписан под гейт: «Классовый артефакт»).
CLASS_RU покрывает 17/17 классов (дословно titles CHARACTER_CONFIGS).

**Кодекс.** Чипы записи — редкость + класс-владелец (+«Заперто»), сырой id из
чипов убран; товары магазина помечаются чипом «Магазин» вместо фиктивной
редкости. Классовый артефакт ЗАПЕРТ, пока мета-Возвышение его класса <
`requires_ascension` (`_codex_artifact_locked`, порог = гейт выдачи): ряд
затемнён китовым locked-тинтом (0.70/0.72/0.78/0.82), иконка — тёмный силуэт
(`CODEX_LOCKED_SILHOUETTE_TINT`, тот же приём, что «скрытая звезда» Атласа),
эффект скрыт — вместо описания условие «Откроется на Возвышении 5 — <Класс>»,
досье показывает секцию «Как открыть» и силуэт (тинт через
`detail_data.texture_tint`). Разблокированные — обычные записи с новой иконкой
и классовой пометкой; смоук-анкер формата пометки — `runtime_smoke_test`
(stolen_crest/void_hunger/warrior_charm).

**Run summary.** Имена артефактов остаются компактным списком без тиров
(решение по лаконичности; редкость доступна в тултипах HUD/паузы).

## SCRUM-958 — Canonical Codex image fit

Codex character, monster and artifact rows keep the accepted SCRUM-954 geometry
but no longer display full transparent source canvases as micro-previews.
`scripts/ui/codex_image_fit.gd` supplies cached, non-destructive `AtlasTexture`
views for both the 88×96 row image and 236×248 dossier preview. Character views
use an 8% alpha reserve with bottom-center anchoring; monsters use 4% centered
contain; artifact and shop icons use 10% centered contain. Visible alpha is
never cropped, and each view keeps its canonical source path/policy metadata.

The player-facing contract is unchanged: one actual canonical image and one
centered Russian name per row, no category emblem, English duplicate or raw id.
All 17 characters, 31 monster projections and 161 artifact/shop projections
resolve their canonical runtime source. Missing entity/artifact art is rejected
by `codex_scrum958_image_fit_test.gd`; the old generic registry fallback is not
an accepted Codex result.
