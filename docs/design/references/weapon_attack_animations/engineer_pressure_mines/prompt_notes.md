# SCRUM-744 Engineer Pressure Mines VFX Prompt Notes

## Pipeline

- Tool: PixelLab MCP via `fantasydisk-asset-generator`.
- Accepted PixelLab map object: `a6231ccd-f8ee-435a-a051-cd71da237633`.
- Alternate PixelLab map object saved as evidence: `db79ced0-ab90-4a95-9395-07df17114df7`.
- Alternate queued 1-direction object: `a32b0e98-8dcc-465e-8556-701be2f0909d`.
- Rationale: Jira dispatcher unblocked this stale OpenAI-only task on 2026-07-01 with the PixelLab path after the old OpenAI Images path hit `billing_hard_limit_reached`.

## Accepted Prompt

Transparent 256x256 FantasyDisk attack VFX, dark fantasy D&D top-down. EXACTLY THREE pressure mines only, no extra mines, no circular shield, no UI frame, no text. Arrange the three brass mines in a shallow forward fan / triangular grid matching a linked three-mine weapon: one mine near bottom center, two mines upper left and upper right. Each mine is partly ghosted/translucent with a turquoise trigger core. Show three separate activation halos and amber dust shock rings, plus thin teal trip-wire energy lines connecting the three mines. The middle of the sprite must stay readable and semi-transparent for gameplay. Soft alpha edges, restrained, painterly pixel-art VFX, no solid background, no watermark, not neon, not overexposed.

## Postprocess

- PixelLab returned an opaque gray matte; this was keyed out into real alpha.
- PixelLab overgenerated physical trigger nodes; generated node clusters were masked while preserving outer trip-wire/ring energy.
- The canonical `assets/sprites/weapons/engineer_pressure_mines.png` was composited as the readable translucent three-mine weapon ghost.
- Runtime PNG stays `256x256` RGBA at `assets/sprites/effects/vfx_weapon_engineer_pressure_mines.png`.
- No scene, damage, cooldown, targeting, radius, deploy-limit, balance, or shared runtime script changes.
