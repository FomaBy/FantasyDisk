# SCRUM-728 Axe Attack VFX Prompt Notes

User override: generate via OpenAI Images / `gpt-image-2`, not PixelLab.

Command:

```bash
python3 skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py --prompt "<prompt below>" --output docs/design/references/weapon_attack_animations/axe/openai_axe_arc_source.png --size 1024x1024 --quality high --no-task
```

Prompt:

```text
FantasyDisk Godot game asset, transparent PNG, top-down Dungeons and Dragons dark fantasy painterly weapon attack VFX for a Berserk two-handed battle axe. Create one broad 140-degree crescent sweep arc facing right, shaped like a heavy axe cleave, with smoky iron, muted crimson, ember-orange and tarnished steel energy. The effect must be semi-transparent and readable in combat: transparent background, transparent center, soft fading edges, no opaque square, no scene background. Include a subtle ghost silhouette of a two-handed axe embedded inside the arc: long haft and large crescent axe head visible as spectral charcoal/steel shape following the swing path. The VFX should show attack direction and approximate radius, with an outer rim and inner motion trails, but remain calm and not cluttered. No character, no UI, no text, no letters, no numbers, no logo, no watermark.
```

Postprocess:

- The OpenAI source returned as RGB with a baked checkerboard background.
- The accepted runtime PNG was rebuilt as real RGBA by removing high-neutral checker pixels, preserving smoky dark strokes and red/ember energy, clamping alpha for combat readability, and downsampling to the existing 256x256 runtime contract.
- The canonical `assets/sprites/weapons/two_handed_axe.png` was composited as a calm translucent ghost silhouette inside the generated cleave, without changing gameplay/runtime APIs.
