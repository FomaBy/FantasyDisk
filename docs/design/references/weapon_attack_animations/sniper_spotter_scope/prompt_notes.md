# SCRUM-765 Sniper Spotter Scope Attack VFX Prompt Notes

Production path: PixelLab MCP through `fantasydisk-asset-generator`.

Stale task wording mentioned an OpenAI-only override, but the direct user
directive on 2026-07-01 superseded that blocker and required PixelLab MCP for
attack-VFX work. This run did not use OpenAI Images, `image_gen`, manual drawing,
or shared-pack regeneration.

## PixelLab Prompts

Primary beam candidate, object `dce7e36f-bea9-4aee-b8f1-0cffd1c828f4`:

```text
FantasyDisk 256px transparent attack VFX, sniper spotter scope kill-zone, high
top-down dark fantasy. Show a thin cyan-silver targeting reticle circle on the
ground with crosshair ticks and range marks, plus four narrow vertical moonlight
sky-beam impact columns piercing down inside the zone, tiny star sparks and
smoky blue dust. Include a faint brass tripod spyglass scope ghost silhouette
behind the magic, very low opacity. Calm readable transparent center, no
icon-only lens, no magenta, no text, no UI frame, no watermark, no opaque
background, restrained D&D tabletop magic, combat-readable at small scale.
```

Supporting reticle candidate, object `ce0de7cf-9a50-47ec-b19b-e46e63d3add2`:

```text
FantasyDisk attack VFX plate for sniper spotter scope weapon, top-down dark
fantasy Dungeons and Dragons style, transparent background, no text, no UI
frame, no watermark. A precise sniper kill-zone marker: thin silver-blue arcane
targeting reticle circle with crosshair ticks, several narrow pale moonlight
sky-beam strike columns landing inside the zone, faint brass spyglass scope
ghost silhouette behind the effect, subtle raven-blue smoke and tiny star
sparks, calm semi-transparent center so enemies and player remain readable,
crisp readable silhouette at 256px combat scale, restrained painterly magic, not
neon, not overexposed.
```

## Postprocess Notes

- PixelLab metadata reported transparent backgrounds, but both downloaded PNGs
  contained opaque preview fields. The accepted source removes those fields and
  keeps only luminous cyan/white VFX pixels.
- The primary beam candidate supplied the sky-beam kill-zone language; the
  supporting reticle candidate supplied the clean circular targeting read.
- `assets/sprites/weapons/sniper_spotter_scope.png` was composited as a
  low-opacity ghost silhouette under the PixelLab VFX so the attack still reads
  as the canonical Sniper Spotter Scope weapon.
- Runtime PNG remains `256x256` RGBA with transparent corners. Gameplay,
  targeting, cooldowns, damage, scenes, and shared scripts were not changed.
