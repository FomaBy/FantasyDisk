# UI Element Workflow

Use this reference when creating game UI elements, HUD panels, menus, cards,
popups, inventory frames, stats panels, tooltips, or report/poster interfaces
that will receive text or live content after image generation.

## 1. Content Inventory

Before drawing anything, extract the content contract from the user request:

- fixed text: titles, labels, button captions, captions, footer notes;
- dynamic text: numbers, names, item descriptions, tooltips, stat values;
- controls: buttons, toggles, tabs, sliders, selectors, close/back controls;
- media: portraits, icons, item thumbnails, charts, radar graphs;
- repeatable content: list rows, cards, inventory slots, rewards, logs;
- states: normal, hover, selected, disabled, locked, error, warning;
- viewport sizes: final bitmap size and any responsive/runtime target.

If the request has too much content for one surface, split it before art:
tabs, paging, collapsible details, scroll area, or separate screens.

## 2. Geometry First

Create `ui_plan.json` or `layout.json` before image generation. Every visible
content surface must have an exact rectangle:

- outer component rect: decorative frame, panel, button, slot, scroll viewport;
- content rect: where text/icons may live;
- safe gap between neighboring components;
- reserved scrollbar lane when scrolling may be needed.

For FantasyDisk-like UI, content rects must sit inside the empty dark interior,
not on metal, gems, spikes, dragon heads, or decorative corners.

## 3. Fit And Scroll Rules

Use a scrollbar only when content naturally exceeds its viewport and the user
expects a scrollable surface: long codex entries, item lists, logs, settings,
inventory grids, quest text, or multi-row rewards.

Prefer no scrollbar for:

- main action buttons;
- single metric cards;
- compact tooltips;
- modal titles;
- hero/header areas;
- small reward cards with fixed content.

If a list needs scrolling:

- declare the scroll area as `scroll: "auto"` or `scroll: "required"`;
- reserve `scrollbar_w` pixels inside the component or outside the content rect;
- keep the scrollbar quiet: dark rail, worn gold thumb, no neon;
- never let the scrollbar overlap text or ornament.

If content cannot fit even with reasonable scroll/paging, report `revise_task`
and propose the smallest product change: shorten copy, split to tabs, add paging,
increase canvas, or remove secondary content.

## 4. Style Direction

Default style for FantasyDisk UI assets:

- dark fantasy / dragon specific / D&D;
- brutal, strict, beautiful, premium, epic;
- blackened iron, dark stone, worn gold, deep crimson accents, subtle ember glow;
- strong silhouettes, crisp frame edges, readable dark interiors;
- restrained detail density: rich borders but calm content interiors;
- no loud neon, no clutter, no overdecorated noise, no text-like runes.

The image model should create the frame/component art, not the final content.
Prompt for empty interiors and explicit coordinate obedience.

## 5. Prompt Pattern

```text
Create a <WxH> dark fantasy / dragon specific / D&D game UI frame layer.
No text, no numbers, no letters, no pseudo-text, no logo, no watermark.

Strict content interiors:
- <id>: x=<x> y=<y> w=<w> h=<h>, purpose=<purpose>

All listed rectangles must stay empty, dark, calm, and readable. Decorative
metal, dragon ornaments, gems, spikes, seams, smoke, highlights, and characters
must stay outside these rectangles. Draw frames around the rectangles, not over
them.

Style: brutal but restrained, blackened iron, dark stone, worn gold, subtle
ember glow, premium D&D dark fantasy. Epic, strict, not loud, not cluttered.
```

## 6. QA Checklist

- Planning report says `decision: ready_for_image`.
- Guide overlay shows all content zones before generation.
- Generated base image has no text or pseudo-text.
- Generated base image leaves every content rectangle calm and readable.
- Final content is inserted only by renderer/compositor.
- No new frames, panels, cards, or opaque patches are added after generation.
- Final debug overlay confirms text/icons sit inside the declared zones.
