# FantasyDisk UI Style

All FantasyDisk interface work should feel like one product family: D&D + Dark Fantasy Dragon. Use the current ornate buttons as the strongest style reference.

## Direction

Use:

- dark fantasy RPG materials: aged dark metal, worn leather, smoked glass, deep parchment, obsidian, ember, muted gold, ruby accents;
- dragon-language visual cues: claw-notched corners, scale texture, wing arcs, subtle horn silhouettes, forged metal bands, gem sockets, crest-like separators;
- thin readable frames where the screen needs density; heavier heroic frames only for main menu, boss/reward moments, or major modal focus;
- crisp silhouettes and high contrast around interactive controls;
- restrained ornament density so gameplay information remains readable.

Avoid:

- bright cartoon mobile UI;
- random medieval assets that do not match the button family;
- one-note red/gold on every surface;
- text baked into generated art unless specifically requested;
- decorative borders that consume so much space that runtime content has no safe zone.

## Unified But Distinct Screens

Keep a shared material language, but give each screen a recognizable accent:

- Main menu: heroic dragon crest, large frame, strong title zone.
- Character select: hero portrait frame, carousel rail, compass/rose navigation accent, dossier-like description panel.
- Combat HUD: compact, dark metal/leather, minimal ornament, fast readability.
- Inventory/rewards: treasure, rune, gem, and parchment accents.
- Settings: mechanical tabs, carved toggles, quiet readable panels.
- Codex/lore: parchment/book materials, library dividers, subdued ornament.
- Pause/game over: modal frame, strong readability, no clutter over gameplay.

## Buttons

Use the current FantasyDisk button style as baseline:

- ornate dark fantasy button body;
- readable internal label zone;
- separate visual states: default, hover, pressed, disabled, selected/focus;
- no runtime text on border ornaments;
- icon-only buttons still need a clear internal icon safe zone.

When asking OpenAI Images API for buttons, request a consistent button family and state sheet, not isolated unrelated buttons.

## Frames And Panels

Every frame asset must declare:

- source size;
- texture/ornament margins;
- content margins;
- minimum practical size;
- whether it is safe for 9-slice;
- forbidden border zones.

Thin frames are preferred for dense screens. If a decorative frame is visually thick, expand the asset or shrink the content area instead of letting content overlap the ornament.

## OpenAI Generation Notes

For mockups, ask for:

- full game UI screen mockup;
- exact aspect ratio and base resolution;
- all major layout regions visible;
- empty internal content zones where runtime text/icons/portraits will go;
- no baked labels unless required;
- UI style matching D&D + Dark Fantasy Dragon and current ornate red/gold buttons;
- clear separation between frame borders and content areas.

For final UI assets, ask for:

- isolated PNG asset;
- transparent background when possible, or clean removable background;
- no text;
- no watermark;
- game-ready silhouette;
- enough internal padding for runtime content.
