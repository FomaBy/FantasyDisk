---
name: fantasydisk-asset-generator
description: Use this skill when creating or editing game assets, sprites, UI frames, icons, buttons, sprite sheets, 9-slice frames, or Godot-ready PNG assets for a dark fantasy game.
---

# Game Asset Art Director

You are helping build a Godot dark fantasy D&D-style game.

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

When asked to generate assets, use `tools/artgen/generate_asset.py` when that project-local script exists.

If the project-local script is absent, use the bundled generator:

```bash
python3 ~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py \
  --prompt "dark fantasy ornate frame, no text, transparent background if possible" \
  --output "reference_pack/asset_reference.png" \
  --size 1536x1024 \
  --quality high
```

The bundled script:

1. Calls the OpenAI Images API with `model="gpt-image-2"` and `output_format="png"`.
2. Saves relative outputs under `docs/design/references/`.
3. Creates a new `docs/tasks/design_integrate_generated_<slug>_task.md` task for implementation.
4. Runs `python3 tools/jira_board_sync.py` when available, then patches the generated task with the Jira key.

After generation, postprocess the result before presenting it as game-ready:

- remove or mask backgrounds when possible;
- crop/pad to the intended canvas;
- verify PNG dimensions and alpha mode;
- create preview/contact sheets when useful;
- write safe content padding notes for UI assets;
- create or update the implementation task when the asset must be integrated.

## UI Frames

For UI frames:

- preserve a stretchable center;
- avoid details in 9-slice stretch zones;
- keep corners readable;
- keep text/icon/clickable content inside the safe content zone;
- do not place labels, icons, or runtime content on decorative borders, gems, spikes, seals, metal, or ornaments;
- export safe content padding notes.

For 9-slice frames, include texture margins and content margins in the task or result notes. If margins are not known, mark them as estimates and ask the implementer to verify in Godot.

## Sprites

For sprites:

- generate frame lists;
- create sprite sheets;
- include `frame_width`, `frame_height`, and `frame_count`;
- avoid changing character proportions between frames;
- keep pivots and silhouette consistent across animation frames;
- document intended animation names, FPS, loop settings, and direction count when relevant.

## Output Paths

- Save references under `docs/design/references/<task_or_pack>/`.
- Save preview/contact sheets under `docs/design/previews/`.
- Save accepted runtime assets under the correct `assets/sprites/...` folder only after the visual is accepted.
- Keep generated source/reference files separate from final runtime assets.

Use descriptive folder names matching the task or reference pack, for example `settings_tab_switcher_frame`, `hero_select_dossier`, `artifact_icons_realistic_dnd`, `main_menu_background_bosses`, or `elite_boss_vfx`.

## Quality And Size

Pass `--quality low`, `medium`, `high`, or `auto`.

Pass `--size auto` or `WIDTHxHEIGHT`. For `gpt-image-2`, keep dimensions divisible by 16, aspect ratio between `1:3` and `3:1`, and stay at or below the documented maximum of `3840x2160` pixels unless the project explicitly needs an experimental size.

`gpt-image-2` currently does not support transparent backgrounds directly. If FantasyDisk needs alpha-ready final art, generate the reference first, then postprocess alpha or create a cleanup/integration task.

## Environment

Require `OPENAI_API_KEY` in the environment and the Python `openai` package available to the interpreter for API-backed generation.

To create only the PNG/task without Jira sync in an offline or credentialless environment:

```bash
FANTASYDISK_SKIP_JIRA_SYNC=1 python3 ~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py ...
```
