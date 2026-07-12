# SCRUM-981 Live Screen Inventory

Audit source: fresh `origin/dev` `8d0f4be31`, `scripts/ui_screens.gd`,
`scripts/pause_stats_menu.gd`, `scripts/route_map_screen.gd`, accepted task and
design evidence through 2026-07-10.

Decision vocabulary:

- `applied`: the full-screen `meta40/frame_border` shell is already present;
- `add`: SCRUM-981 Back-end integration should add the shell and use the exact
  safe geometry in `spec.md`;
- `intentional exception`: an outer shell would cover active gameplay, an
  authored specialist layout, or critical illustration/content;
- `covered by child task`: preserve the more specific Jira contract and avoid
  parallel ownership.

## Main-menu family

| Screen / runtime root | Current evidence | Decision | Integration constraint |
| --- | --- | --- | --- |
| Main Menu / `MainMenuScreen` | Full-bleed `main_menu_epic_battle_v3.png`; logo begins at `(56,44)`, actions at `x=72`; no outer frame | **add** | A blanket overlay is unsafe. Move logo and all six actions into the authored safe area. Use the two-column/three-row responsive layout in `spec.md`; keep the scenic center/right readable. |
| Quit confirmation / `QuitConfirmationDialog` | Local `atlas_chip` modal above Main Menu | covered by parent shell | Keep the local modal. Do not add a second full-screen frame; the Main Menu shell remains visible behind the dim. |
| Continue Run / `ContinueRunDialog` | Local `cr_panel` specialist modal | covered by parent shell | Preserve its exact 9-slice/content margins; no duplicate outer shell. |
| Hero Select / `HeroSelectScreen` | `_unified_add_background`, `_unified_safe_margins`, `_unified_add_frame("HeroSelect")` | **applied** | Preserve SCRUM-879/SCRUM-980 geometry and all local portrait/dossier/ascension safe zones. |
| Weapon Select / `WeaponSelectScreen` | `_unified_add_frame("WeaponSelect")` | **applied** | Preserve card flow and shared safe area. |
| Start Boon / `StartBoonScreen` | `_unified_add_frame("StartBoon")` | **applied** | Preserve card flow and shared safe area. |
| Settings / `SettingsV2Root` | Fullscreen Atlas-family safe area plus `_unified_add_frame("Settings")` | **applied** | Do not touch the SCRUM-975/SCRUM-1030 Game-tab package. Existing three-tab runtime remains the source for this task. |
| Patch Notes / `PatchNotesScreen` | `_unified_add_frame("PatchNotes")` | **applied** | Preserve scroll lane inside the frame safe area. |
| Atlas / `AtlasScreen` | Direct `AtlasFrame` using `_atlas_frame_style` | **applied** | Canonical production shell/reference. |
| Codex / `CodexScreen` | SCRUM-954 deliberately removed `CodexFrame`; uniformly scaled 1920×1080 authored stage owns exact local margins | **intentional exception** | Do not restore the outer frame in SCRUM-981. At 720p/1080p its 160px rails covered title/nav zones. Codex still belongs to the material family through Atlas background/local panels/buttons. A future outer shell requires a new Codex layout task and revised safe geometry. |

## Run and route surfaces

| Screen / runtime root | Current evidence | Decision | Integration constraint |
| --- | --- | --- | --- |
| Route Map / `RouteMapScreen` | Header and scroll begin only 28px from viewport edges; no outer shell | **add** | Inset header, route scroll, resource HUD and upgrade action into the exact route safe zones in `spec.md`. Keep vertical scrolling/pan and map-critical content; no horizontal scroll. |
| Escape dossier / `PauseStatsMenuRoot` | Fullscreen `EscapeStatsPanelFrame` already uses `meta40/frame_border` | **applied** | Preserve readable gameplay dim and the local real-inner-zone margins. End-run dialog stays local. |
| End Run confirmation / `EndRunConfirmationDialog` | Local `atlas_chip` modal above paused dossier | covered by parent shell | No duplicate outer shell. |
| Shop / `ShopScreen` | Full shop art with wall items; no outer shell | **covered by child task** | SCRUM-993 owns the gold-frame shop pass and must preserve visible shop background art. SCRUM-981 only records the dependency. |
| Attribute Shop / `AttributeShopScreen` | Tall centered Atlas chip, no outer shell | **covered by child task** | SCRUM-987 owns the frame/content redesign; SCRUM-982 owns removal of paid stat upgrade. Do not pre-empt either. |
| Event / `EventScreen` | Accepted SCRUM-997 illustrated dialog: right story panel + bottom choice strip directly over unique event art | **covered by child task / intentional specialist layout** | Do not add a blanket outer frame: its current edge-aligned bottom strip and art composition are the accepted screen-specific contract. |
| Rest / `MenuPanel_campfire` | Background art plus centered local panel; no outer shell | **add** | Use shared outer shell and common body template. Keep campfire art visible; local choice panel remains inside body zone. |
| Upgrade / `MenuPanel_upgrade` | Centered Atlas chip/card flow; no outer shell | **add** | Use shared outer shell; compact mode scrolls only the cards, never the header/footer. |

## Rewards, results and gameplay overlays

| Screen / runtime root | Current evidence | Decision | Integration constraint |
| --- | --- | --- | --- |
| Battle Reward / `MenuPanel_artifact_reward` | Centered Atlas chip/card flow; no outer shell | **add** | Use common outer shell and keep all three cards in body zone. |
| Elite/Boss artifact reward | Centered reward panel over `elite_reward` art; no outer shell | **covered by child task** | SCRUM-990/991/992 own the artifact/chest gold-frame, exact text and QA contracts. |
| Level Up / `LevelUpOverlay` | SCRUM-985 removed `LevelUpFrame` and brightened gameplay backdrop | **intentional exception** | Never re-add the large outer frame. Keep local card/socket ornament only. |
| Final Victory / `PauseEndModalPanel_victory` | Centered result chip over victory art; no outer shell | **add** | Add only the shared outer shell behind the centered result modal. SCRUM-986 remains owner of small-resolution centering. |
| Defeat / `PauseEndModalPanel_death` | Centered result chip over death art; no outer shell | **add** | Same shell contract as Victory; keep result modal and run summary local. |
| Transient victory banner / `VictoryBannerLayer` | Compact Atlas chip over active combat | **intentional exception** | No large frame over active gameplay. |
| Combat HUD / active fight | Compact resource cluster, timer, feedback overlays | **intentional exception** | No large menu frame under any combat state. |
| Level-up toast / combat title / damage feedback | Small transient overlays over gameplay | **intentional exception** | Local ornament only; never wrap the viewport. |
| Rebind conflict dialogs | Local settings dialogs | covered by Settings shell | Keep local specialist modal; do not add a second viewport frame. |
| Feedback/dev-console overlays | Contextual utility overlays and screenshot review | **intentional exception** | Must preserve the underlying context and capture area; no large shell. |

## Net SCRUM-981 runtime handoff

The safe implementation batch is limited to Main Menu, Route Map, Rest,
Upgrade, Battle Reward, Victory and Defeat. Existing applied shells remain
unchanged unless Back-end finds a direct safe-zone regression. Codex, Level Up,
Combat and child-task screens are explicit non-targets.
