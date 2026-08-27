---
name: fantasydisk-asset-generator
description: Use this skill when creating or editing FantasyDisk characters, objects, props, sprites, icons, UI frames, HUD elements, buttons, sprite sheets, 9-slice frames, or other non-background Godot-ready PNG assets. Use PixelLab MCP for these non-background assets with D&D + Dark Fantasy Dragon art direction, transparent/source PNG exports, reference/runtime path discipline, and QA evidence. Route every full-canvas background, scenic backdrop, environment image, splash/loading image, or illustrated UI underlay to $fantasydisk-builtin-image-generator and never use PixelLab for it.
---

# Game Asset Art Director

You are helping build a Godot dark fantasy D&D-style game.

## Generator Routing

For every new FantasyDisk character, object, prop, sprite, UI frame, HUD element, icon, button, non-background mockup art layer, or other isolated production-ready PNG, use PixelLab through MCP as the source generation/editing tool.

For every full-canvas background, scenic backdrop, environment image, menu or screen background, loading/splash image, or illustrated underlay, stop this workflow and use `$fantasydisk-builtin-image-generator`. The built-in OpenAI Image Generator is the mandatory default for backgrounds. Never generate or edit a background with PixelLab. Use the OpenAI Images API only when the user explicitly requests it.

Do not confuse an isolated asset that should have a transparent background with the background image itself. Transparent sprites, icons, frames, and props remain in the PixelLab workflow.

- First try exposed PixelLab MCP tools in the chat. If tools are not visible, use tool discovery for `pixellab`.
- If the PixelLab MCP server is configured locally but not exposed as direct tools, read `../pixellab_mcp_auth.md`, then call it through the configured MCP bridge without printing tokens, headers, or secrets.
- If PixelLab MCP appears unavailable, read `../pixellab_mcp_auth.md` and run the config-based smoke before marking the Multica issue blocked. Do not treat stale tool discovery or missing ambient `AUTH_HEADER` as proof of broken auth.
- If the post-fix MCP smoke truly fails, mark the task blocked or create the correct handoff. Do not silently fall back to OpenAI Images, `image_gen`, hand drawing, old random generators, or the legacy `generate_asset.py` pipeline.
- Record the PixelLab source asset/project ID, tag/name, export IDs when available, prompt/spec, exported source paths, runtime paths, and QA evidence in the Multica result.

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

1. Confirm the Multica issue owner/status and locked paths before creating files.
2. Classify the requested image before choosing a generator. Route background imagery to `$fantasydisk-builtin-image-generator` and continue here only for non-background assets.
3. Build a concise PixelLab prompt/spec from the task: asset type, canonical ID, target use, size/aspect, style, forbidden text, safe zones, alpha needs, and animation/state needs.
4. Use PixelLab MCP to create, revise, or fetch the source asset. Prefer stable tags matching the canonical ID, for example `berserk`, `artifact_blood_sigil`, `ui_frame_combat_hud_health`.
5. Export source PNGs from PixelLab into `docs/design/reference-assets-lfs/<task_or_pack>/` through Git LFS.
6. Save a `manifest.json` beside the source files with PixelLab IDs/tags, prompt/spec, export dimensions, frame/state names, and source filenames. Never store API tokens or Authorization headers.
7. Postprocess the result before presenting it as game-ready.
8. Create preview/contact sheets when useful, especially for batches, state sheets, frames, or animations.
9. Promote accepted runtime assets to `assets/...` only when integration is part of the task.

### Failed blocking CLI handoff

For pack generation, follow `docs/process/pixellab_pull_setup.md` and use the
blocking CLI. If it exits with any non-zero code, stop the current run: do not
sleep, manually poll, silently retry, promise a later report, or leave the
issue `in_progress`. Save the redacted CLI output, including the exact exit
code, object/job id (or `unavailable` if none is printed), and last status,
then immediately set the assigned issue to `blocked` and post that evidence with
`multica issue comment add --content-file`. A timeout retry with `--object-id`
belongs to a newly dispatched run, never to the failed run.

After generation, postprocess the result before presenting it as game-ready:

- remove or mask backgrounds when possible;
- crop/pad to the intended canvas;
- verify PNG dimensions and alpha mode;
- create preview/contact sheets when useful;
- write safe content padding notes for UI assets;
- create or update the implementation task when the asset must be integrated.

Legacy note: `tools/artgen/generate_asset.py` and `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py` are OpenAI Images API helpers. Do not use them by default. For backgrounds, prefer the built-in generator through `$fantasydisk-builtin-image-generator`; use the API helpers only when the user explicitly requests the API route. Do not use the helpers for non-background assets unless the user explicitly overrides their PixelLab route.

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

- Save new binary references and preview/contact sheets under `docs/design/reference-assets-lfs/<task_or_pack>/` through Git LFS.
- Treat `docs/design/references/` and `docs/design/previews/` as grandfathered legacy locations; do not add or modify binary assets there.
- Save accepted runtime assets under the correct `assets/sprites/...` folder only after the visual is accepted.
- Keep generated source/reference files separate from final runtime assets.

Use descriptive folder names matching the task or reference pack, for example `settings_tab_switcher_frame`, `hero_select_dossier`, `artifact_icons_realistic_dnd`, `main_menu_background_bosses`, or `elite_boss_vfx`.

## QA And Reporting

Every asset task should finish with:

- generator provenance: PixelLab source ID/tag/name for non-background assets, or built-in/API OpenAI provenance for backgrounds;
- final runtime paths when promoted;
- size, alpha, crop/padding, state/frame count, and safe content margins;
- preview/contact sheet path when useful;
- tests or visual QA performed;
- explicit note that the required generator route was used, or a blocker/handoff explaining why it could not be used.
