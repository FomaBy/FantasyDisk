# SCRUM-675 Visual Frame-Zone Audit

Date: 2026-06-29
Worker: claude-design-scrum675

Purpose: confirm every accepted content zone of the redesigned «Древо умений»
screen sits inside an empty frame interior, clear of the generated gold-brass
ornament (corner studs, rails, crests, accent hairlines). Per
frame-content-safe-area-rule.

Evidence: `docs/design/mockups/scrum675_skill_tree_2k/debug_overlay.png`
(mirror in `docs/design/previews/scrum675_skill_tree_2k_debug_overlay.png`).

## Zone Review

| Zone | Rect @ 2560x1440 | Visual placement | Clear of ornament |
| --- | --- | --- | --- |
| `title_zone` | `980,88,600,70` | Inside the dark title plaque on the main top rail; clear of crest diamond and corner studs. | YES |
| `points_button_zone` | `196,96,280,92` | Inside the «Очки умений» button dark field, right of the coin medallion; clear of bevel. | YES |
| `points_badge_zone` | `540,100,132,96` | Centre of the heraldic shield badge; clear of brass rim and gold edge. | YES |
| `class_select_zone` | `2120,100,300,78` | Left text field of the class dropdown; clear of the chevron plate (reserved by the 72px right texture margin). | YES |
| `class_popup_zone` | `196,320,460,900` | Inside the class-popup interior below the header plaque; clear of corner studs, crest and side rails. | YES |
| `path_wealth_zone` | `760,300,420,900` | Inside the wealth path interior below its icon header band; clear of studs and rails. | YES |
| `path_lore_zone` | `1208,300,420,900` | Inside the lore path interior below its icon header band; clear of studs and rails. | YES |
| `path_might_zone` | `1656,300,420,900` | Inside the might path interior below its icon header band; clear of studs and rails. | YES |
| `path_endure_zone` | `2104,300,420,900` | Inside the endure path interior below its icon header band; clear of studs and rails. | YES |

## Safe-Area Notes

- Main panel texture margin `(74,86,74,82)` covers the ornate border; the
  layout VBox runs inside content margin `(120,118,120,108)` so no content
  lands on the rail or the heraldic crests.
- Each path frame reserves the top `0..150px` band for its medallion icon +
  title; content/node columns start at y>=300 (>=18px below the band).
- Class dropdown reserves the right `72px` (texture margin) for the chevron
  plate, so the class-name text zone never collides with it.
- Node-state icons render inside path interiors only; their octagon socket
  sits within the branch content column, never over the frame border.

## Verdict

GREEN — all 9 content zones are clear of generated ornament; ready for runtime
integration by SCRUM-676.
