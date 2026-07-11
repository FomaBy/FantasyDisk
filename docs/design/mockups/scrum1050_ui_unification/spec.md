# UI Mockup Spec — FantasyDisk unified interface language + gratitude button

Status: ready_for_integration
Role owner: Design main
Task: `docs/tasks/SCRUM-1050.md`
Jira: SCRUM-1050 (parent SCRUM-1049)
Reference board: 688x384
Runtime responsive targets: 1280x720, 1920x1080, 2560x1440
Reference PNG: `docs/design/references/scrum1050_ui_unification/scrum1050_unified_ui_reference_sheet_688x384.png`
Preview PNG: `docs/design/previews/scrum1050_ui_unification_reference_sheet_688x384.png`
Debug PNG: `docs/design/previews/scrum1050_ui_unification_reference_sheet_688x384_debug.png`
Generated with: accepted PixelLab MCP sources + deterministic source-reuse compositor; new gratitude icon via PixelLab MCP `create_map_object`, object `c1c1c353-e56e-405b-9adf-f1e6bd993152`.

## Source request

Make the whole game interface visually coherent without making every screen identical; include Codex and audit all buttons. Add a wordless gratitude/credits button in the upper-right corner, using an icon that clearly communicates appreciation.

## Direction

One material language: graphite/obsidian interiors, thin blackened-steel rails, aged-brass hairlines, restrained deep-crimson/ruby accents and subtle ember highlights. Screen identity comes from small edge accents (crest, compass, book divider, mechanical tab, treasure pin, socket), not from changing the base product family. Ornament density must decrease as information density rises.

Codex remains the accepted SCRUM-954 frameless three-column stage. “Unified” does not mean placing the SCRUM-981 large gold shell over Codex, Combat HUD, Level Up, Weapon Select, or other deliberate exceptions.

## Reference board elements

| ID | Type | Rect @ 688x384 | Safe content rect | States / accent |
| --- | --- | --- | --- | --- |
| button_normal | action sample | 24,24,120,52 | 40,36,88,28 | normal |
| button_hover | action sample | 154,24,120,52 | 170,36,88,28 | neutral-bright hover |
| button_pressed | action sample | 284,24,120,52 | 300,36,88,28 | dark pressed |
| button_focus | action sample | 414,24,120,52 | 430,36,88,28 | neutral focus |
| button_disabled | action sample | 544,24,120,52 | 560,36,88,28 | desaturated disabled |
| accent_main_menu | screen accent | 24,96,148,118 | 104,118,50,60 | heroic/gold shell crop |
| accent_selection | screen accent | 188,96,148,118 | 214,122,96,66 | dragon/portrait dossier |
| accent_settings | screen accent | 352,96,148,118 | 375,122,102,68 | mechanical panel |
| accent_codex | screen accent | 516,96,148,118 | 563,122,54,64 | quiet book/dragon divider |
| accent_combat_hud | screen accent | 24,230,148,130 | 38,276,120,36 | compact thin rail |
| accent_economy | screen accent | 188,230,148,130 | 210,280,104,28 | treasure/rune bar |
| accent_rewards_levelup | screen accent | 352,230,148,130 | 393,268,66,72 | gem/socket card |
| accent_pause_results | screen accent | 516,230,148,130 | 536,271,108,42 | restrained result/dossier plate |

The reference board contains no baked labels. The cyan rectangles exist only in the separate debug preview and prove that content zones stay off ornament.

## Gratitude / credits icon button

Runtime icon: `assets/sprites/ui/icons/credits/ui_icon_gratitude.png`
Source/reference: `docs/design/references/scrum1050_ui_unification/pixellab_gratitude_icon_alpha_256.png`
Source size: 256x256 RGBA
Strict source safe box: x=48, y=48, w=160, h=160
Measured alpha bbox: x=55, y=48, w=146, h=160
Source transparent margins: L55 / T48 / R55 / B48
Alpha: transparent 51,142 px; partial 3,195 px; opaque 11,199 px
9-slice: forbidden; icon must scale proportionally
Node intent: `TextureRect` inside an icon-only `Button`; no baked button background, no label.

Visual semantics: two articulated dark-steel gauntleted hands/palms support a small warm crimson-gold heart. It reads as appreciation/support rather than currency, combat, healing, trophy or prayer. PixelLab's raw output contained an opaque neutral background despite the endpoint reporting transparent; the recorded deterministic postprocess removes only the connected neutral backdrop, then fits the subject into the approved safe box. No new art was drawn during cleanup.

### Main Menu placement

Place the gratitude button inside the SCRUM-981 empty top-right shell interior, not on the gold rail. It opens the gratitude/credits surface; no visible text is baked into or placed beside the button. A tooltip/accessibility label `Благодарности` is allowed and recommended.

| Viewport | Shell safe rect | Button rect | Icon texture rect inside button | Content margins |
| --- | --- | --- | --- | --- |
| 1280x720 | 133,113,1014,494 | 1059,137,64,64 | 1059,137,64,64 | effective visible symbol remains ~36-40px because source is padded |
| 1920x1080 | 200,169,1520,742 | 1624,193,72,72 | 1624,193,72,72 | effective visible symbol remains ~41-45px |
| 2560x1440 | 267,225,2026,990 | 2173,257,88,88 | 2173,257,88,88 | effective visible symbol remains ~50-55px |

All three positions reserve at least 24px between the hitbox and the real shell ornament. Minimum hit target is 64x64. Hover/focus/pressed/disabled must keep the same rect. Use the compact utility/icon-button family; do not route this control through a text-action plate.

## Responsive rules

- 1280x720: retain screen-specific compact tiers; no label below/next to the gratitude icon; minimum action text size remains readable and does not enter caps.
- 1920x1080: base authored layout; preserve current screen exceptions and spacing hierarchy.
- 2560x1440: scale geometry or select the large tier, but keep ornament thickness visually stable; avoid one-axis whole-image stretching.
- On live resize, recompute screen-owned layouts and top-right gratitude placement from the current safe rect.
- For 9-slice assets, content margins must be at least texture margins plus 8px small / 16px medium / 24px large reserve. Irregular frames use measured real interior rectangles.

## Back-end handoff

- Audit the global resolver so ordinary text/actions use the current `text_buttons_unique` family and all five states.
- Keep compact icon buttons on the compact utility family; cards/slots/route nodes remain their own hit-area families.
- Preserve Codex SCRUM-954 geometry and make only material/state/margin changes that fit its explicit panel interiors.
- Add `CreditsButton` under `MainMenuScreen`, top-right inside the SCRUM-981 safe rect, with the runtime gratitude icon and no visible label.
- Create/open a gratitude/credits surface only within the Back-end task's content scope; this Design task provides the entry icon and placement contract, not runtime copy or wiring.

## Acceptance checks

- [x] Both UI plans validated `decision: ready_for_image`, `ok: true`, zero errors/warnings.
- [x] Layout guide reports are `ok: true`.
- [x] Reference board uses accepted PixelLab source families only; no alternate image model or hand-drawn fallback.
- [x] PixelLab gratitude icon exported before auto-delete and promoted as transparent runtime candidate.
- [x] Debug overlay confirms all declared content rectangles stay inside empty interiors.
- [x] Five common interaction states have stable geometry.
- [x] Codex is included without violating the SCRUM-954 frameless contract.
- [ ] Back-end runtime integration and screenshot matrix.

## Deviation / existing-source-reuse exception

The planned new PixelLab `create_ui_asset` reference-board job was rejected before generation with `no generations or credits remaining for creating a UI panel`; the tool requires 20-40 generations while the account had four. No quota was consumed. Under the approved `existing source reuse` exception, the board was composed only from previously accepted PixelLab source/runtime families with IDs recorded in `manifest.json`. The gratitude icon still originated from a successful PixelLab MCP generation. No OpenAI Images, built-in image generation, legacy asset generator, or hand drawing was used.
