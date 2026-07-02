# Godot UI Implementation Checklist

Use this checklist before and after changing FantasyDisk Godot UI scenes, scripts, themes, or runtime asset placement.

## Before Editing

- Confirm the current branch is the active project branch.
- Read the mockup spec and preview.
- Confirm every runtime element has bounds, anchors, and a safe-zone parent.
- Confirm new art was generated through PixelLab MCP or is an accepted existing asset.
- Identify role ownership: Design for art/mockup, Back-end for runtime UI, Animator only for animated UI/motion.

## Node And Layout Rules

- Prefer `Control` anchors and containers for scalable placement.
- Use `custom_minimum_size` for buttons, icon cells, carousel cards, portrait slots, and fixed-format controls.
- Use `PanelContainer`/`MarginContainer` to enforce content margins.
- Use `StyleBoxTexture` only when 9-slice is safe and margins are documented.
- Use `TextureRect` or composed frame pieces for irregular non-9-slice frames.
- Keep runtime labels, icons, portraits, and clickable children inside `MarginContainer` content zones.
- Do not let hover, focus, pressed, or disabled styles resize the control.
- Keep text readable at 1280x720 and 1920x1080.

## Frame Safety

For every frame:

- texture margin = visual border/ornament thickness;
- content margin = texture margin + reserve;
- reserve should be at least `8 px` for small controls, `16 px` for medium panels, and `24 px` for large panels unless the mockup specifies more;
- runtime content must not overlap decorative corners, gems, spikes, seals, metal plates, dragon ornaments, or bevel highlights.

Fail QA if content touches a decorative border even by a few pixels.

## Buttons

- Keep button labels/icons in the internal safe zone.
- Provide default, hover, pressed, disabled, and focus/selected states when the screen uses those interactions.
- Preserve current FantasyDisk ornate button language unless the task explicitly introduces a new button family.
- Do not bake translatable/runtime text into generated button art.

## Screenshot Matrix

Capture or inspect at:

- `1280x720`
- `1920x1080`
- `2560x1440`

If the task targets a special aspect ratio, add it to the matrix.

Check:

- no overlap;
- no text clipping;
- no content on frame border;
- no element hidden behind another;
- no layout shift between states;
- mockup and implementation match materially.

## Test Commands

Run runtime smoke after UI implementation when available:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/sergeyfomin/Documents/AI\ Agent \
  --script res://tests/runtime_smoke_test.gd
```

Run UI-specific tests if present, for example:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/sergeyfomin/Documents/AI\ Agent \
  --script res://tests/runtime_smoke_ui_test.gd
```

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/sergeyfomin/Documents/AI\ Agent \
  --script res://tests/ui_no_overlap_matrix_test.gd
```

If a listed UI test does not exist, note that explicitly in the task result instead of pretending it ran.
