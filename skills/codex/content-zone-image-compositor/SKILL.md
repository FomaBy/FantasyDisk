---
name: content-zone-image-compositor
description: Generate or finish AI-created UI, poster, infographic, card, banner, report, or game-interface images using content zones that are defined before image generation. Use when text, numbers, labels, icons, portraits, charts, or other content must be inserted after generation without covering decorative frames, ornaments, borders, or artwork. This skill plans exact coordinates first, prompts image generation to leave those zones empty, composites content only inside those zones, and verifies the result with debug overlays and fit reports.
---

# Content Zone Image Compositor

## Core Rule

Define content zones before generating the image. Treat the generated image as the final layout/frame layer. After generation, do not draw new cards, frames, panels, borders, or opaque backing boxes unless the user explicitly asks for a second design pass.

Post-processing may add only:

- text inside declared zones;
- icons/images clipped inside declared zones;
- text shadow/stroke needed for readability;
- optional debug overlays saved as separate QA artifacts.

If content does not fit, shorten content, reduce font size, or regenerate the image with larger zones. Do not solve fit problems by adding new frames over the artwork.

## Workflow

1. **Plan zones first.** Create a `layout.json` before calling image generation. Include canvas size, zone ids, x/y/w/h, role, alignment, font limits, colors, and content keys.
2. **Generate frame/layout layer.** Prompt the image model to create an image with empty decorative frames/panels matching the planned zones. Explicitly forbid text, numbers, pseudo text, watermarks, and filled content in those areas.
3. **Inspect the image.** Check that the generated artwork left the planned zones visually usable. If important zones are blocked by ornament/art, regenerate or revise `layout.json`.
4. **Composite content.** Run `scripts/render_content_zones.py` with the generated image and `layout.json`.
5. **Verify.** Review the final image and the debug overlay. The render report must show `ok: true`; every text block must fit inside its zone.
6. **Iterate within zones only.** If the result looks wrong, edit text styles/zones or regenerate the base image. Never add ad hoc frames over the base image.

## Image Generation Prompt Pattern

Use the planned zones directly in the prompt. Example:

```text
Create a 1920x1080 dark fantasy infographic frame layer with no text.
The following rectangles must remain empty, calm, readable interiors for later text insertion:
- title zone: x=120 y=70 w=1000 h=110
- hero number zone: x=130 y=220 w=500 h=360
- metric card 1: x=700 y=230 w=330 h=170
Decorative borders may surround these rectangles but must not enter them.
No letters, numbers, placeholder text, runes shaped like text, logos, or watermarks.
Do not place characters, weapons, bright highlights, seams, or ornaments inside the empty rectangles.
Style: ...
```

For FantasyDisk UI/report work, also apply the global frame rule: content belongs only in the empty inner area of a frame, never on the ornament.

## Layout JSON

Read `references/layout_schema.md` when creating or editing a layout schema. Keep `SKILL.md` lean; the reference contains the schema and a complete example.

Minimal structure:

```json
{
  "canvas": {"width": 1920, "height": 1080},
  "content": {"title": "FantasyDisk", "days": "17 days"},
  "zones": [
    {
      "id": "title",
      "content_key": "title",
      "x": 120,
      "y": 70,
      "w": 1000,
      "h": 110,
      "align": "left",
      "valign": "middle",
      "max_font": 76,
      "min_font": 28,
      "color": "#F7E7BD"
    }
  ]
}
```

Coordinates are absolute pixels in the final output size. Use a separate zone for each logical content block.

## Renderer

Use the bundled renderer:

```bash
python3 /Users/sergeyfomin/.codex/skills/content-zone-image-compositor/scripts/render_content_zones.py \
  --input base.png \
  --layout layout.json \
  --output final.png \
  --debug-output final.debug.png \
  --report final.report.json
```

For a pre-generation zone guide without a base image:

```bash
python3 /Users/sergeyfomin/.codex/skills/content-zone-image-compositor/scripts/render_content_zones.py \
  --layout layout.json \
  --guide-output layout.guide.png \
  --report layout.guide.report.json
```

The renderer auto-wraps text, shrinks font size down to `min_font`, writes a JSON report, and exits non-zero if any required zone cannot fit.

## Acceptance Checklist

- `layout.json` existed before image generation.
- The base image is used as the visual layer; no new frames/cards/panels were drawn afterward.
- All final text/icons are inside declared zones.
- Debug overlay matches the intended content areas.
- Report JSON has `ok: true`.
- No content overlaps decorative frame art or important illustration details.
