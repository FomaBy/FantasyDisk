# SCRUM-730 Biologist Sample Injector Attack VFX Prompt Notes

Issue: SCRUM-730
Weapon ID: `biologist_sample_injector`
Runtime asset: `assets/sprites/effects/vfx_weapon_biologist_sample_injector.png`
Source path: `docs/design/references/weapon_attack_animations/biologist_sample_injector/`
Preview: `docs/design/previews/weapon_attack_animations/biologist_sample_injector_contact.png`

## User Override

The active task explicitly overrides the default PixelLab-only asset rule. This VFX source was generated with the repository OpenAI Images helper:

```bash
python3 skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py --no-task --quality high --size 1024x1024 --output docs/design/references/weapon_attack_animations/biologist_sample_injector/biologist_sample_injector_openai_source.png --prompt "<prompt below>"
```

Model: `gpt-image-2`
Quality: `high`
Requested size: `1024x1024`
Duplicate task creation: skipped with `--no-task`

## Prompt

```text
FantasyDisk dark fantasy D&D top-down 2D action RPG attack VFX source plate for the Biologist weapon 'Sample Injector'. Transparent background PNG, no text, no watermark. A precise alchemical sample dart / injection line travels diagonally left-to-right toward target tissue, with a faint ghost silhouette of a slim syringe-like injector behind the effect. Near the target impact are exactly two subtle biochemical analysis echoes: translucent teal-green circular tissue scan pulses with tiny organic motes and violet reagent sparks. Calm semi-transparent painterly VFX, readable center, not a solid explosion, not covering HUD or characters, clear direction and area of effect, elegant dark fantasy laboratory magic, cyan green violet accents, soft alpha edges.
```

## Postprocess Notes

- The OpenAI source returned as RGB with a baked checkerboard despite the transparent-background prompt; it was retained as source evidence.
- `biologist_sample_injector_openai_source_alpha_clean.png` removes low-chroma mid-gray checkerboard pixels and preserves saturated teal/violet reagent marks and dark target tissue.
- The runtime PNG composites the cleaned OpenAI source with a semi-transparent silhouette derived from `assets/sprites/weapons/biologist_sample_injector.png`, rotated to point the injector needle along the attack vector.
- A precise cyan sample dart/injection line and exactly two biochemical analysis echo rings were reinforced deterministically for gameplay readability.
- No gameplay code, damage values, cooldowns, targeting, attack shape, or shared runtime API changed.

## Runtime Visual Contract

- Canvas: `256x256` RGBA, same path/name as the existing weapon signature VFX.
- Visual direction: bottom-left injector ghost and sample dart line toward upper-right target tissue.
- Area read: two scan/analysis echoes around the target impact tissue.
- Readability: transparent corners, sparse alpha footprint, no fully opaque pixels, no text or watermark.
