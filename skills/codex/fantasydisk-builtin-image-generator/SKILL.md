---
name: fantasydisk-builtin-image-generator
description: Generate or revise FantasyDisk game art using Codex/ChatGPT built-in image generation instead of the project OpenAI API pipeline. Use when the user explicitly asks to create images without API keys, without OPENAI_API_KEY, through built-in Images, or wants quick concept/reference art for backgrounds, sprites, icons, UI frames, mockups, or dark fantasy assets before formal API-backed integration.
---

# FantasyDisk Built-in Image Generator

Use this skill when FantasyDisk art should be created with the built-in image generation tool rather than `tools/artgen/generate_asset.py` or the OpenAI API key based pipeline.

## Core Rules

- Use the `image_gen` tool directly for generation or image edits when it is available.
- Do not require or check `OPENAI_API_KEY` for this workflow.
- Keep the FantasyDisk style: dark fantasy, D&D-like, dragon/metal/stone motifs where relevant, readable silhouettes, game-ready composition.
- Do not bake text, UI labels, numbers, logos, or gameplay copy into generated art unless the user explicitly asks for text.
- Treat built-in generated images as quick concept/reference art unless the output is saved into the repo, reviewed, and wired into Godot.
- If a Jira/task requires "OpenAI API", `tools/artgen/generate_asset.py`, or reproducible API generation, say that this built-in workflow is a separate non-API fallback and update the task wording before using it.

## Workflow

1. Pull the project before starting if working inside `D:\FantasyDisk`.
2. Identify the asset type and target:
   - backgrounds: `assets/backgrounds/`
   - UI frames/buttons: `assets/sprites/ui/frames/`
   - icons: `assets/sprites/icons/` or the established project icon folder
   - character/source references: `docs/design/references/<pack>/`
   - previews/contact sheets: `docs/design/previews/`
3. Generate a prompt that includes:
   - FantasyDisk dark fantasy style
   - target aspect ratio and approximate size
   - "no text, no labels, no watermark"
   - safe zones for UI if the asset is a menu/background
   - transparent/background expectations when relevant
4. Call `image_gen` with the final prompt.
5. If the tool returns a local file or downloadable result, save/copy it into the appropriate reference path first. Promote to `assets/...` only after it is accepted for runtime.
6. For runtime integration, update the Godot path or script constant, run the relevant smoke/UI check, then commit and push.
7. Record the prompt, output path, and verification result in Jira or the local task file.

## Prompt Patterns

Main menu background:

```text
FantasyDisk main menu background, dark fantasy D&D painting, epic ruined battlefield near a glowing cursed disk portal, two heroic silhouettes facing distant bosses, ornate gothic atmosphere, cinematic 16:9 composition, left and top UI-safe areas with lower visual noise, high detail, no text, no labels, no logo, no watermark
```

Icon or item:

```text
FantasyDisk game item icon, dark fantasy D&D style, <object>, strong readable silhouette, centered object, transparent-friendly dark contrast, no text, no numbers, no watermark
```

UI frame:

```text
FantasyDisk ornate UI frame, dark metal and aged gold, red gem accents, stretchable clean center, detailed corners, content-safe inner area, transparent-friendly, no text, no icons, no watermark
```

## Handoff Notes

For every accepted asset, capture:

- source prompt;
- generated output path or preview link;
- intended runtime path;
- Godot import status;
- screenshot or smoke/UI check result;
- whether this is built-in non-API generation or the reproducible API pipeline.
