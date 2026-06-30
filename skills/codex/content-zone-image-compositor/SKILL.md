---
name: content-zone-image-compositor
description: Plan, generate, and finish PixelLab MCP-created UI elements, game interface panels, HUD/menu frames, posters, infographics, cards, banners, and report images using content zones defined before image generation. Use when text, numbers, labels, icons, portraits, lists, buttons, scroll areas, charts, or other content must fit into exact coordinates without covering decorative frames, ornaments, borders, or artwork. This skill first estimates layout/fit/scrollbar needs from the source request, requires a ready/revise decision, then prompts PixelLab generation to preserve strict content zones, composites content only inside those zones, and verifies the result with debug overlays and fit reports.
---

# Content Zone Image Compositor

## Core Rule

Define content zones before generating the image. Treat the generated image as the final layout/frame layer. After generation, do not draw new cards, frames, panels, borders, or opaque backing boxes unless the user explicitly asks for a second design pass.

For UI elements, first make a sizing plan from the user's request: what content exists, where it goes, how large it is, whether scrolling is needed, and whether everything can fit. If the plan does not fit, revise the task/layout before image generation.

Post-processing may add only:

- text inside declared zones;
- icons/images clipped inside declared zones;
- text shadow/stroke needed for readability;
- optional debug overlays saved as separate QA artifacts.

If content does not fit, shorten content, reduce font size, or regenerate the image with larger zones. Do not solve fit problems by adding new frames over the artwork.

## Workflow

1. **Parse the request into content inventory.** List every text block, button, icon, portrait, stat row, list item, tab, scrollbar, and dynamic state that must exist.
2. **Plan geometry before art.** Create a `ui_plan.json` or `layout.json` with exact rectangles, minimum sizes, gaps, scroll behavior, and content zones.
3. **Run the planning gate.** Use `scripts/validate_ui_layout_plan.py` for UI plans. Continue only if the report says `decision: ready_for_image`. If it says `revise_task`, adjust content, zone sizes, scroll rules, or task scope before generation.
4. **Generate frame/layout layer.** Use PixelLab MCP to create empty brutal dark fantasy / dragon specific / D&D interface art around the approved coordinates. Explicitly forbid text, numbers, pseudo text, watermarks, and filled content in those areas.
5. **Inspect the image.** Check that the generated artwork left the planned zones visually usable. If important zones are blocked by ornament/art, regenerate or revise the plan.
6. **Composite content.** Run `scripts/render_content_zones.py` with the generated image and `layout.json`.
7. **Verify.** Review the final image and the debug overlay. The render report must show `ok: true`; every text block must fit inside its zone.
8. **Iterate within zones only.** If the result looks wrong, edit text styles/zones or regenerate the base image. Never add ad hoc frames over the base image.

For detailed UI planning rules, read `references/ui_element_workflow.md`.

## Image Generation Prompt Pattern

Use the planned zones directly in the PixelLab prompt/spec. Example:

```text
Create a 1920x1080 dark fantasy / dragon specific / D&D UI frame layer with no text.
The following rectangles must remain empty, calm, readable interiors for later text insertion:
- title zone: x=120 y=70 w=1000 h=110
- hero number zone: x=130 y=220 w=500 h=360
- metric card 1: x=700 y=230 w=330 h=170
Decorative borders may surround these rectangles but must not enter them.
No letters, numbers, placeholder text, runes shaped like text, logos, or watermarks.
Do not place characters, weapons, bright highlights, seams, or ornaments inside the empty rectangles.
Style: strict, brutal and epic dark fantasy; dragon-forged metal, black stone, worn gold, restrained red embers; beautiful and premium but not loud, not busy, not over-detailed.
```

For FantasyDisk UI/report work, also apply the global frame rule: content belongs only in the empty inner area of a frame, never on the ornament.

If PixelLab MCP is unavailable, read `../pixellab_mcp_auth.md` and run the
config-based smoke before blocking or handing off the task. Do not use OpenAI
Images, built-in image generation, old manual art, or legacy asset scripts as a
fallback for FantasyDisk UI/HUD/frame generation.

## Planning Gate

For interface elements, use the layout validator before image generation:

```bash
python3 /Users/sergeyfomin/.codex/skills/content-zone-image-compositor/scripts/validate_ui_layout_plan.py \
  --plan ui_plan.json \
  --guide-output ui_plan.guide.png \
  --report ui_plan.report.json
```

Continue to image generation only when the report contains:

```json
{"decision": "ready_for_image", "ok": true}
```

If the report says `revise_task`, do not force the image. Change the layout,
reduce content, add/resize a scroll area, split the UI into tabs/pages, or
return a concise note that the request must be decomposed.

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

- UI plan/report exists before image generation for interface elements.
- Scrollbars are declared when content exceeds viewport height.
- `layout.json` existed before image generation.
- The base image is used as the visual layer; no new frames/cards/panels were drawn afterward.
- All final text/icons are inside declared zones.
- Debug overlay matches the intended content areas.
- Report JSON has `ok: true`.
- No content overlaps decorative frame art or important illustration details.
- Style is dark fantasy / dragon specific / D&D: strict, beautiful, brutal, epic, restrained, and not visually noisy.
