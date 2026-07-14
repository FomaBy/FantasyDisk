# UI Mockup Spec — FAN-1077 Codex Unread And Victory Unlocks

Status: implemented

Role owner: Back-end / UI integration

Task: Multica FAN-1077

Base resolution: 1920×1080

Responsive targets: 1280×720, 1920×1080, 2560×1440

Reference-board canvas: 688×384

Mockup PNG: `docs/design/references/fan1077_codex_unread_unlocks/reference_board_base.png`

Preview PNG: `docs/design/previews/fan1077_codex_unread_unlocks_mockup.png`
Generated with: PixelLab MCP via `create_ui_asset`; source IDs are recorded in `manifest.json`

## Source Request

After a successful run, show every newly unlocked artifact, hero, and weapon. In the Codex, mark unread entries with a drawn exclamation badge, sort unread entries first, and show the same unread signal on the Main Menu Codex action. Hero and weapon unlock rules remain future work; the presentation contract accepts those categories now.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920×1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| main_codex_badge | TextureRect | unread badge | inside `MainMenuCodexButton`, top-right interior, 40×40 | right/center | 28×28 | 20 | visible/hidden | main-menu button content zone |
| codex_tab_badge | TextureRect | unread category badge | tab interior right inset, 28×28 | right/center | 20×20 | 20 | visible/hidden | `CodexTab_*` content zone |
| codex_entry_badge | TextureRect | unread entry badge | row x=446, y=22, 36×36 | right/top | 28×28 | 20 | unread/read | `CodexEntryCard` inner rect x=20..486, y=20..134 |
| victory_unlocks | ScrollContainer | all run-local unlock records | right summary column, above run stats | fill width | 220×96 | 10 | hidden when empty; auto-scroll | `RunSummaryColumn_victory` |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| main menu action | shared Main Menu button family | existing | existing shared family | badge stays 52 px inside the right edge | bevel, corners, seal/ornament | existing contract |
| codex entry card | `assets/sprites/ui/atlas_style/codex/entry_card_516x154.png` | 516×154 | authored non-stretch card | L20/T20/R30/B20; unread layout reserves R86 | full leather/metal border and corners | no |
| codex panel | `assets/sprites/ui/atlas_style/codex/panel_9slice.png` | existing | existing Codex constants | existing panel margins | all panel ornament | yes |
| victory modal | existing pause/end result frame | responsive | existing result margins | existing result content rect | crest/frame rails/corners | existing contract |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ui_badge_codex_unread | `assets/sprites/ui/icons/codex/ui_badge_codex_unread.png` | unread signal | 256×256 source, runtime 18–40 px | transparent | n/a | centered exclamation silhouette | PixelLab object source `661aefb3-25e0-4054-9dfe-cd21a7ebe9ad`; no runtime text |

## Responsive Rules

- 1280×720: existing uniform Codex stage scale applies; badge scales with its parent and remains at least 20 visual px. Victory unlock list uses a 96 px maximum height and scrolls.
- 1920×1080: authored Codex card is 516×154; entry badge is 36×36 at x=446/y=22. Main-menu badge is 40×40 inside the action plate.
- 2560×1440: existing uniform Codex stage scale applies. Badge does not grow beyond the authored stage scale. Victory unlock list may use up to 140 px height.

## Interaction States

- Unread: badge visible; entry sorts before read siblings.
- Read: badge hidden after the entry is explicitly opened; persistent unread state is saved immediately.
- Category tab: badge remains while any entry in that section is unread.
- Main Menu: badge remains while any Codex entry is unread.
- Victory: run-local artifact/hero/weapon unlocks are listed in canonical acquisition order; the block is absent when the run unlocked nothing.

## Implementation Notes

- Runtime scenes stay code-built in `scripts/ui_screens.gd`, with FAN-1077 presentation extracted to `scripts/codex_unlock_presenter.gd`. Persistent compatibility APIs remain on `scripts/meta_progression.gd` and delegate to `scripts/codex_unlock_state.gd`; run-local acquisition order lives in `scripts/main.gd::run_metrics` through `scripts/codex_run_unlocks.gd`.
- Weapons remain nested in character dossiers. A future unread weapon record raises the owning character row and uses its badge.
- This task does not define hero or weapon unlock conditions and does not lock the current roster. It only provides future-ready record/display APIs, avoiding inaccessible content before the follow-up progression design lands.

## Acceptance Checks

- [x] Planning report says `ready_for_image`.
- [x] Mockup and badge generated through PixelLab MCP.
- [x] Preview prepared for the final task handoff.
- [x] All visible elements are listed above.
- [x] No content overlaps frame borders or ornaments.
- [x] Runtime content fits at all responsive targets.
- [x] Unread sorting, read persistence, victory journal, and main-menu signal have focused tests.
- [x] Screenshot matrix is produced by `tests/codex_unread_victory_test.gd` when a non-headless display is available; the headless geometry matrix covers all three targets in CI.

## Deviations

The 688×384 generated image is a multi-surface UX reference board, not a replacement runtime background. Existing accepted FAN-1065/FAN-1069 Codex art remains the live frame family; only the generated badge is promoted as a runtime asset.
