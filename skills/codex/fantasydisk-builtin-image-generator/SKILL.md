---
name: fantasydisk-builtin-image-generator
description: Generate or edit FantasyDisk full-canvas background imagery with the built-in OpenAI Image Generator. Use for menu and screen backgrounds, scenic backdrops, environment art, loading or splash art, illustrated underlays, and other repository-bound background images. Built-in OpenAI generation is mandatory by default for backgrounds; never use PixelLab for them. Use the OpenAI Images API only when the user explicitly requests it after preferring or reviewing the built-in result.
---

# FantasyDisk Built-in Image Generator

Use the built-in OpenAI Image Generator for every new or edited FantasyDisk background image, including production and repository-bound art.

## Core Rules

- Treat this as a permanent project rule: never use PixelLab to generate or edit background images.
- Use the built-in OpenAI Image Generator first. Do not require an API key and do not switch to the OpenAI Images API merely because it is available.
- Use the OpenAI Images API only after the user explicitly asks for the API route. A prior negative opinion about PixelLab is not permission to select the API over the built-in generator.
- If built-in generation is unavailable, report or record the blocker. Do not fall back to PixelLab.
- Keep PixelLab routing for non-background assets such as characters, isolated objects, props, sprites, icons, UI frames, HUD elements, buttons, and animation frames through the appropriate FantasyDisk skill.
- Do not confuse a transparent-background requirement for an isolated asset with a background image. This skill applies to the full-canvas scene or underlay itself.
- Preserve D&D + Dark Fantasy Dragon art direction, requested aspect ratio, UI-safe composition, and the prohibition on unwanted text, labels, logos, and watermarks.

## Workflow

1. Read the active Multica issue/request, confirm its owner and locked paths, and identify the asset type.
2. Classify it as a background when it is a full-canvas scenic image, environment, backdrop, loading/splash art, menu or screen background, or illustrated underlay behind runtime content.
3. For a background, prepare the source prompt, dimensions/aspect, focal areas, low-noise UI-safe zones, forbidden content, and intended runtime path before generation.
4. Call the built-in OpenAI Image Generator. Follow its output contract exactly and make the generation call the last conversational action of that turn when required by the tool.
5. If the user explicitly requests the OpenAI Images API, use the approved API workflow without exposing secrets and record that the API route was user-selected.
6. For a non-background asset, route to `$fantasydisk-asset-generator` or the more specific character, animation, item-icon, or UI skill.

## Prompt Patterns

Use the examples as starting points and adapt composition to the actual screen geometry.

Main menu background:

```text
FantasyDisk main menu background, dark fantasy D&D painting, epic ruined battlefield near a glowing cursed disk portal, two heroic silhouettes facing distant bosses, ornate gothic atmosphere, cinematic 16:9 composition, left and top UI-safe areas with lower visual noise, high detail, no text, no labels, no logo, no watermark
```

Gameplay backdrop:

```text
FantasyDisk gameplay background, D&D dark fantasy dragon world, <environment and narrative moment>, cinematic depth, readable gameplay plane, restrained contrast behind actors and HUD, low-noise UI-safe zones at <coordinates>, <aspect ratio>, no text, no labels, no logo, no watermark
```

Loading or splash background:

```text
FantasyDisk loading-screen background, dark fantasy D&D illustration, <subject and location>, dramatic but coherent lighting, strong focal composition away from the loading indicator and tip zones, <aspect ratio>, no text, no labels, no logo, no watermark
```

## Handoff Notes

For every accepted asset, capture:

- Multica issue ID and generator-routing decision;
- source prompt;
- generated output path or preview link;
- intended runtime path;
- Godot import status;
- screenshot or smoke/UI check result;
- whether the built-in OpenAI generator or the explicitly user-selected OpenAI Images API was used.
