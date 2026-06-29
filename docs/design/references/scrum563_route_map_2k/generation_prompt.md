# SCRUM-563 Route Map 2K Generation Prompt

Create a 2560x1440 full-screen FantasyDisk route-map UI mockup and frame/source concept.

No baked runtime text, numbers, letters, pseudo-text, logo, watermark, or readable runes. The mockup may use abstract icon silhouettes for route node types, but labels and values are inserted by runtime.

Strict empty content interiors:
- header_frame: x=28 y=18 w=2504 h=110. Keep a thin dark fantasy metal/parchment header frame. Content must remain empty inside x=88 y=34 w=2372 h=72.
- route_scroll_viewport: x=28 y=140 w=2504 h=1272. This is the full-screen scroll-map field. It must stay dark, calm, and readable, with a vertical route lane and no ornaments entering the node/line area.
- route_scroll_content_safe: x=188 y=202 w=2168 h=1148. Route nodes and connecting lines live here; keep it calm and low-contrast.
- resource_hud_strip: x=64 y=164 w=820 h=84. Small run HUD strip, inside the map field, not a large modal.
- tooltip_panel: x=1838 y=200 w=560 h=170. Empty tooltip frame; no text inside.
- upgrade_fab: x=2426 y=1308 w=68 h=68. Small square action button; keep the icon zone centered and off the border.
- visible_node_grid: x=246 y=296 w=2020 h=956. Route nodes are 88x88, spaced vertically, with thin connecting lines.

Decorative metal rails, corner brackets, ruby pins, dragon-scale accents, parchment tacks, ropes, compass marks, fog, smoke, bright highlights, and frame ornament must stay outside the declared content interiors. Do not cover the route node interiors, connecting paths, tooltip interior, header title/stats zones, HUD strip interior, or FAB icon zone.

Style: D&D + Dark Fantasy Dragon, strict and premium, blackened iron, dark parchment, worn gold, muted crimson/ruby pins, faint ember light, eerie route-map wilderness background, central fogged map column, readable silhouettes. Beautiful and brutal, but restrained; no loud neon, no clutter, no random decorative junk.

Responsive intent:
- 1920x1080 and 1280x720 use proportional scaling from the 2560x1440 contract.
- 4K doubles the base geometry.
- Header and full-screen scroll viewport preserve their content margins.
- Route map remains vertical with horizontal scrolling disabled.
