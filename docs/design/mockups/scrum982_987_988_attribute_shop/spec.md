# SCRUM-982/987/988 — Attribute Shop gold shell

Status: implemented reference contract, pending independent QA.

## Product flow

- Attribute Shop is mandatory after normal and elite victories.
- Route Map, Rest, Shop, Event and Escape/menu screens do not expose a repeatable paid-stat entry.
- Pending level rewards remain reachable through `LevelUpPlusButton`; this is independent from Attribute Shop.
- Default offer count is two. Atlas `atlas_n2` adds the third offer through `attr_extra_options = 1`.

## Visual contract

- Reuse the production `assets/sprites/ui/meta40/frame_border.png` as one hollow outer frame.
- No second central modal or ornamental frame.
- The frame is the final direct child, draws no center and ignores mouse input.
- Title, money, every offer card, actions and their hitboxes remain inside the exact gold-shell inner rect.
- Two offers center within the same row. Three offers occupy one left-to-right row; no wrap, scroll or height growth.
- Each card visibly shows the stat name and `+1`, a concise class interpretation, the complete `Влияет на` list, up to four live before/after derived-stat lines, and the price. The tooltip keeps the unabridged class text and insufficient-gold explanation.
- Reroll and Skip form one horizontal action row.

## Authored matrix

| Viewport | Inner rect | Three-card row | Card size | Action row |
|---|---:|---:|---:|---:|
| 1280×720 | `157,137 966×446` | `204,218 872×232` | `276×232`, gap `22` | `300,500 680×64` |
| 1920×1080 | `224,193 1472×694` | `350,330 1220×360` | `360×360`, gap `70` | `500,785 920×72` |
| 2560×1440 | `299,257 1962×926` | `470,430 1620×500` | `460×500`, gap `120` | `650,1060 1260×88` |

Intermediate sizes interpolate by viewport height and cap card width against the exact inner rect. Live resize is idempotent and does not regenerate the fixed offer.

## Design pipeline

- Content-zone planning reports: `ready_for_image`, zero errors/warnings at 720p, 1080p and 1440p.
- PixelLab MCP `create_ui_asset` source ID: `bf62b298-1df4-40d7-baeb-8fd30ac071d3`.
- PixelLab reference is textless and not promoted to runtime; it confirms one shell, three equal offer wells and two action wells.
- Deterministic compositor report: `ok=true`; all sample text fits only inside declared wells.
- Runtime uses the canonical shared frame and the existing `meta_progression` background.

## Runtime QA evidence

- `docs/design/previews/scrum982_987_988_attribute_shop/runtime/atlas_three_offers_1280x720.png`
- `docs/design/previews/scrum982_987_988_attribute_shop/runtime/atlas_three_offers_1920x1080.png`
- `docs/design/previews/scrum982_987_988_attribute_shop/runtime/atlas_three_offers_2560x1440.png`
- `docs/design/previews/scrum982_987_988_attribute_shop/runtime/runtime_matrix.md`

Visual review: all content and hit areas remain in the dark inner field, the gold ornament is unobstructed, every derived preview line is visible, and all three Atlas offers remain in one row.
