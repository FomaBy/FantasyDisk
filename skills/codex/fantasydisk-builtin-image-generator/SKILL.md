---
name: fantasydisk-builtin-image-generator
description: Deprecated FantasyDisk image-generation fallback. Use only to redirect old requests that mention Codex/ChatGPT built-in Images, no API key, image_gen, or the former non-PixelLab workflow. New FantasyDisk characters, objects, UI frames, HUD elements, icons, sprites, mockups, and production assets must be generated through PixelLab MCP via $fantasydisk-asset-generator instead.
---

# FantasyDisk Built-in Image Generator

Do not use this skill to create new FantasyDisk production art. It exists only to catch old prompts that ask for built-in image generation and redirect them to the current PixelLab MCP workflow.

## Core Rules

- For FantasyDisk characters, objects, UI frames, HUD, icons, sprites, mockups, and production assets, use `$fantasydisk-asset-generator` and PixelLab MCP.
- If PixelLab appears unavailable, read `../pixellab_mcp_auth.md` through the production skill path and run the config-based smoke before treating it as a blocker. Do not use this deprecated fallback because of stale MCP discovery in an already-open thread.
- Do not call `image_gen` for in-repository FantasyDisk asset creation unless the active user request explicitly says to bypass PixelLab for a one-off non-production concept.
- If a task requests the old built-in or OpenAI flow, update/record the task decision: PixelLab MCP is now mandatory. If PixelLab is unavailable, block or hand off instead of generating elsewhere.
- Never promote built-in generated art to `assets/...` for FantasyDisk runtime unless the user explicitly overrides the PixelLab rule in that task and the Multica issue records the exception.

## Workflow

1. Read the active request/task and identify the asset type.
2. If it is FantasyDisk production or repository-bound art, switch to `$fantasydisk-asset-generator` and use PixelLab MCP.
3. If the user explicitly asks for a non-production built-in concept despite the PixelLab rule, state in the task notes that it is not a production asset and must not be promoted to runtime without a PixelLab pass.

## Prompt Patterns

Legacy examples below are prompt references only. Convert them into PixelLab prompts/specs before production use.

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
- whether this is PixelLab MCP production output or an explicitly approved non-production built-in exception.
