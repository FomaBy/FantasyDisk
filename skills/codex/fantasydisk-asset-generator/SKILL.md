---
name: fantasydisk-asset-generator
description: Use this skill when creating or editing FantasyDisk characters, objects, props, sprites, icons, UI frames, HUD elements, buttons, sprite sheets, 9-slice frames, or Godot-ready PNG assets. All new visual asset creation must use the PixelLab MCP workflow, with D&D + Dark Fantasy Dragon art direction, transparent/source PNG exports, reference/runtime path discipline, and QA evidence.
---

# Game Asset Art Director

You are helping build a Godot dark fantasy D&D-style game.

## Mandatory PixelLab Rule

For every new FantasyDisk character, object, prop, sprite, UI frame, HUD element, icon, button, mockup art layer, or production-ready PNG, use PixelLab through MCP as the source generation/editing tool.

- First try exposed PixelLab MCP tools in the chat. If tools are not visible, use tool discovery for `pixellab`.
- If the PixelLab MCP server is configured locally but not exposed as direct tools, call it through the configured MCP bridge without printing tokens, headers, or secrets.
- If PixelLab MCP cannot be reached, mark the task blocked or create the correct handoff. Do not silently fall back to OpenAI Images, `image_gen`, hand drawing, old random generators, or the legacy `generate_asset.py` pipeline.
- Record the PixelLab source asset/project ID, tag/name, export IDs when available, prompt/spec, exported source paths, runtime paths, and QA evidence in the task/Jira result.

Always produce assets with:

- no text unless explicitly requested;
- no baked UI labels;
- clean silhouette;
- game-ready structure;
- consistent dark fantasy visual style;
- correct file names;
- correct target folders;
- PNG output;
- transparent background or postprocessed alpha when possible.

## Generation Workflow

1. Confirm the task owner/Jira state and locked paths before creating files.
2. Build a concise PixelLab prompt/spec from the task: asset type, canonical ID, target use, size/aspect, style, forbidden text, safe zones, alpha needs, and animation/state needs.
3. Use PixelLab MCP to create, revise, or fetch the source asset. Prefer stable tags matching the canonical ID, for example `berserk`, `artifact_blood_sigil`, `ui_frame_combat_hud_health`.
4. Export source PNGs from PixelLab into `docs/design/references/<task_or_pack>/`.
5. Save a `manifest.json` beside the source files with PixelLab IDs/tags, prompt/spec, export dimensions, frame/state names, and source filenames. Never store API tokens or Authorization headers.
6. Postprocess the result before presenting it as game-ready.
7. Create preview/contact sheets when useful, especially for batches, state sheets, frames, or animations.
8. Promote accepted runtime assets to `assets/...` only when integration is part of the task.

After generation, postprocess the result before presenting it as game-ready:

- remove or mask backgrounds when possible;
- crop/pad to the intended canvas;
- verify PNG dimensions and alpha mode;
- create preview/contact sheets when useful;
- write safe content padding notes for UI assets;
- create or update the implementation task when the asset must be integrated.

Legacy note: `tools/artgen/generate_asset.py` and `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py` are historical OpenAI Images helpers. Do not use them for new production asset creation unless the user explicitly overrides the PixelLab rule in the active task and the Jira/task evidence records that exception.

## UI Frames

For UI frames:

- preserve a stretchable center;
- avoid details in 9-slice stretch zones;
- keep corners readable;
- keep text/icon/clickable content inside the safe content zone;
- do not place labels, icons, or runtime content on decorative borders, gems, spikes, seals, metal, or ornaments;
- export safe content padding notes.

For 9-slice frames, include texture margins and content margins in the task or result notes. If margins are not known, mark them as estimates and ask the implementer to verify in Godot.

For HUD or full UI frame layers, generate empty, calm content interiors in PixelLab from the approved geometry plan. Decorative art may surround content zones but must not enter them.

## Sprites

For sprites:

- use PixelLab frame/state exports, not manually imagined frame lists;
- create sprite sheets or full-frame PNG rows only from exported PixelLab frames;
- include `frame_width`, `frame_height`, and `frame_count`;
- avoid changing character proportions between frames;
- keep pivots and silhouette consistent across animation frames;
- document intended animation names, FPS, loop settings, and direction count when relevant.

For animated characters, also follow `$fantasydisk-pixellab-animation-integrator`.

## Output Paths

- Save references under `docs/design/references/<task_or_pack>/`.
- Save preview/contact sheets under `docs/design/previews/`.
- Save accepted runtime assets under the correct `assets/sprites/...` folder only after the visual is accepted.
- Keep generated source/reference files separate from final runtime assets.

Use descriptive folder names matching the task or reference pack, for example `settings_tab_switcher_frame`, `hero_select_dossier`, `artifact_icons_realistic_dnd`, `main_menu_background_bosses`, or `elite_boss_vfx`.

## QA And Reporting

Every asset task should finish with:

- PixelLab source ID/tag/name and exported source paths;
- final runtime paths when promoted;
- size, alpha, crop/padding, state/frame count, and safe content margins;
- preview/contact sheet path when useful;
- tests or visual QA performed;
- explicit note that PixelLab MCP was used, or a blocker/handoff explaining why it could not be used.
