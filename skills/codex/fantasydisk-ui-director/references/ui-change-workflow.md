# FantasyDisk UI Change Workflow

Use this workflow for every FantasyDisk interface request: new screen, screen redesign, layout fix, HUD change, menu popup, carousel, frame/button/icon work, or style unification.

## 1. Discovery

Read the relevant project docs and the active task. Identify:

- screen name and gameplay state;
- target devices/aspect ratios;
- all required visible elements;
- all interactive states: default, hover, pressed, focus, disabled, selected, locked, empty, loading, error;
- runtime data that must fit inside the UI;
- existing UI assets that should be reused.

If the request concerns a visual-only mockup or asset, keep the task in Design ownership. If it requires Godot scene/script wiring, create or use a Back-end handoff for integration.

## 2. Mockup First

Before changing runtime UI, create a mockup package under:

```text
docs/design/mockups/<task_or_screen_slug>/
```

The package must contain:

- PixelLab MCP generated full-page mockup PNG or frame/layout layer;
- markdown spec using `references/mockup-spec.md`;
- optional annotated PNG with safe zones and element IDs;
- generated reference assets, if the mockup uses new frames/buttons/icons.

Use `$fantasydisk-asset-generator` to generate the mockup/art layer through PixelLab MCP. If the task needs exact geometry, use a prompt/spec that asks for clean orthographic UI layout, no perspective, no baked labels unless explicitly required, transparent/empty content areas where runtime text will go, and clear internal safe zones.

After generation, show the mockup in chat:

```markdown
![mockup](/absolute/path/to/mockup.png)
```

Do this whenever the file exists. If PixelLab MCP generation/export is unavailable, block the task rather than substituting a manual, OpenAI Images, built-in, or other image pipeline.

## 3. Spec The Geometry

For the base resolution, usually `1920x1080` unless the task says otherwise, document:

- element IDs and rectangles: `x, y, width, height`;
- anchor rules for each element;
- minimum and maximum sizes;
- z-order;
- frame texture margins;
- safe content margins;
- forbidden border/ornament zones;
- responsive behavior for `1280x720`, `1920x1080`, and `2560x1440`.

The spec is the contract. Implementation follows it. If an implementer discovers the spec is impossible, update the spec first and record why.

## 4. Asset Generation

Generate new UI assets through `$fantasydisk-asset-generator`, which must use PixelLab MCP for new production art.

Required asset notes:

- source prompt;
- PixelLab source ID/tag/name;
- output path;
- size;
- transparent background or postprocessing plan;
- 9-slice texture margins when applicable;
- content margins;
- intended Godot node type: `TextureRect`, `NinePatchRect`, `StyleBoxTexture`, `Button`, `PanelContainer`, etc.

Do not bake runtime text into assets unless the task explicitly asks for a static title image.

## 5. Godot Implementation

Recreate the mockup using Godot 4 `Control` layouts:

- use anchors and containers for responsive placement;
- use fixed/custom minimum sizes for buttons, slots, hero cards, and icon cells;
- use `StyleBoxTexture` or `NinePatchRect` only when the frame supports 9-slice;
- use non-stretch `TextureRect` or sliced composition for frames with irregular ornaments;
- keep text, icons, and portraits inside the safe content zone.

Keep decorative art and runtime content separate. Runtime content should be replaceable without editing the source image.

## 6. Verification

Verify at the documented resolution matrix:

- no overlap between content and frame decoration;
- no text clipping;
- no content outside safe zones;
- no UI elements covering each other;
- clickable controls keep stable size in every state;
- hover/focus/pressed/disabled states do not shift layout;
- screenshots visually match the mockup.

Run existing project tests when available:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/sergeyfomin/Documents/AI\ Agent \
  --script res://tests/runtime_smoke_test.gd
```

Also run UI-specific smoke or no-overlap tests if they exist in the repository.

## 7. Multica And Task-Mirror Bookkeeping

For task-tracked work, update:

- task status and result summary;
- mockup/spec/preview paths;
- changed runtime files;
- generated asset paths;
- test results;
- Multica status/comment with implementation and QA evidence.

If another role must continue, create a handoff task with the mockup/spec links and safe-zone requirements.
