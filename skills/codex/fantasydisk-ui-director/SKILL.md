---
name: fantasydisk-ui-director
description: Use this skill when planning, generating, redesigning, integrating, validating, or fixing FantasyDisk UI screens, HUD, menus, popups, buttons, frames, icons, mockups, Control layouts, StyleBox/TextureRect frames, or Godot UI safe-zone issues. Requires an OpenAI-API-generated mockup before implementation, unified D&D + Dark Fantasy Dragon direction, and strict frame content-zone rules.
---

# FantasyDisk UI Director

Use this skill for every FantasyDisk interface change. The workflow is mockup first, implementation second: create a complete OpenAI-API-generated page mockup with all required elements, document exact bounds and safe zones, then recreate the layout in Godot.

## Required Reading

In a FantasyDisk repo checkout, read these before UI work:

- `AGENTS.md`
- `docs/process/agent_role_boundaries_and_handoffs.md`
- `docs/design/current_game_state.md`
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/visual_style_assets.md`
- the active task file, task board row, and linked Jira context when present

Then read only the references needed for the current step:

- `references/ui-change-workflow.md` for the end-to-end process.
- `references/mockup-spec.md` before producing a mockup or task spec.
- `references/fantasydisk-ui-style.md` before art/style decisions.
- `references/godot-implementation-checklist.md` before runtime implementation.
- `references/common-pitfalls.md` before generating art or integrating frames — gpt-image-2 size/aspect/key limits, STRETCH_SCALE distortion, verifying the rendered asset, and content-inset margins.

## Non-Negotiable Rules

1. Create or update the mockup before touching runtime UI implementation. Tiny emergency bug fixes may skip only when the user explicitly says no mockup is needed.
2. Generate the mockup and new UI art through the OpenAI Images API. Prefer `$fantasydisk-asset-generator` and its project/bundled scripts. Do not use the old/random/manual image pipeline as a fallback.
3. Show the generated mockup or preview in chat whenever a preview file exists, using Markdown image syntax with an absolute filesystem path.
4. If OpenAI API credentials, billing, model access, or generation fail, mark the task blocked or create the correct handoff. Do not silently replace the API-generated mockup with a hand-drawn substitute.
5. Keep all FantasyDisk pages in one visual family: D&D + Dark Fantasy Dragon, using the current button style as the main reference family.
6. Never place UI content on frame texture, borders, ornaments, gems, spikes, metal, seals, or decorative corners. Buttons, text, icons, portraits, carousels, slots, previews, and selection controls belong only in the empty internal content zone or on a background underlay.
7. Content margins must be at least `texture margins + reserve`. For irregular frames, the content zone is the real internal empty area, not the rectangular bounding box.
8. Implement the Godot layout from the mockup/spec. If implementation needs different bounds, update the mockup/spec first and record the reason.
9. Respect role boundaries: Design owns visual mockups and art assets, Back-end owns runtime UI wiring/tests, Animator owns motion/animated UI only when animation behavior is the task. Create a handoff instead of doing another role's specialist work.
10. Avoid the known traps in `references/common-pitfalls.md`: use gpt-image-2-valid sizes (>=~1MP, aspect 1:3..3:1, /16 — `generate_asset.py` auto-corrects); generate frames at the panel's real aspect or 9-slice them so `STRETCH_SCALE` does not distort ornament; confirm the swapped asset is the one actually rendered (watch for a combined "unified" frame); and inset content to each frame's real inner transparent zone so nothing overlaps the border.

## Workflow

1. Inventory the screen:
   - screen purpose, target resolution, target aspect ratios;
   - every visible element, state, tooltip, popup, disabled state, and input state;
   - data-driven content such as hero names, class stats, inventory counts, upgrade cards, or selected ascension.
2. Produce a mockup package:
   - OpenAI-API-generated page mockup PNG;
   - annotated spec with element rectangles, anchors, z-order, safe zones, and responsive behavior;
   - asset list with frame margins, content margins, and 9-slice notes when applicable.
3. Present the preview:
   - show the generated PNG in chat with `![preview](/absolute/path.png)`;
   - include only concise notes about dimensions, safe zones, and unresolved risks.
4. Generate or update assets:
   - use `$fantasydisk-asset-generator` for frames, buttons, icons, backgrounds, mockups, and UI reference sheets;
   - keep source references under `docs/design/references/<topic>/`;
   - keep previews under `docs/design/previews/`;
   - move accepted runtime assets to `assets/...` only when integration is part of the task.
5. Implement in Godot:
   - use stable Control anchors, containers, custom minimum sizes, StyleBoxTexture margins, TextureRect stretch settings, and responsive constraints;
   - keep runtime labels/text outside baked art unless the task explicitly asks for text in an image.
6. Validate:
   - compare implementation screenshots to the mockup;
   - run UI overlap/smoke tests when available;
   - inspect 1280x720, 1920x1080, and 2560x1440 or the task-specified matrix;
   - fail the work if content overlaps frame decoration, clips text, or moves outside the safe zone.
7. Document:
   - update the task file with mockup path, preview path, asset paths, margins, implementation paths, tests, and deviations;
   - sync Jira/board status when the work is task-tracked.

## Output Contract

Every UI change result should include:

- mockup PNG path and shown chat preview when generation succeeded;
- mockup/spec markdown path;
- target resolution and responsive matrix;
- element bounds, safe zones, frame margins, and content margins;
- generated asset paths and runtime asset paths;
- Godot scene/script/style paths changed;
- screenshot or QA preview paths;
- test commands and results.

Do not declare a UI task complete if it lacks a mockup/spec or if generated previews were not shown when available.
