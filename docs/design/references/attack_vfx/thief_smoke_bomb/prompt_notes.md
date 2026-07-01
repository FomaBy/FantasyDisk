# SCRUM-775 PixelLab Prompt Notes

Production path: PixelLab MCP via `fantasydisk-asset-generator`, following the 2026-07-01 dispatcher/user unblock. The older OpenAI Images helper path remains superseded by `billing_hard_limit_reached`; no OpenAI Images, `image_gen`, or legacy generator was used.

Selected PixelLab object ID/job: `08edb666-7ad1-4675-a39a-d2190b042900`  
Unused first candidate: `5a68f6da-9a6a-46db-bb9e-e89de4ae4e4a`  
Tool: `create_map_object`  
Canvas: `256x256`, low top-down, lineless, medium detail/shading.

Selected prompt:

```text
Transparent 256x256 top-down FantasyDisk attack VFX for thief_smoke_bomb, D&D dark fantasy rogue smoke bomb. BROKEN smoke cloud ring, open readable transparent center, smoky grey blue curling wisps, small black iron smoke-bomb canister ghost silhouette behind the ring, a few violet shadow motes. Must NOT be a solid disk, NOT a shield, NOT ice, NOT water, NOT a perfect circle, no square background, no text, no UI, no scenery. Semi-transparent combat effect plate for delayed AoE and dodge cloud.
```

Rejected first prompt/candidate:

```text
FantasyDisk thief_smoke_bomb attack VFX plate, dark fantasy Dungeons and Dragons rogue smoke bomb effect, top-down circular delayed area cloud, soft grey blue smoke ring with wispy curling edges, readable transparent center, faint ghost silhouette of a small round smoke bomb canister behind the smoke, subtle violet shadow motes and ember sparks, semi-transparent game VFX on transparent background, calm combat readability, no text, no UI, no frame, no character, no scenery
```

Postprocess:

- Raw selected PixelLab source saved as `thief_smoke_bomb_pixellab_source_raw.png`.
- Unused first candidate saved as `thief_smoke_bomb_pixellab_source_raw_candidate1.png` for audit/evidence.
- Alpha-clean accepted source saved as `thief_smoke_bomb_pixellab_source.png`; PixelLab metadata reported transparent background but the PNG download contained an opaque flat preview background, so corners were used for alpha cleanup.
- Runtime exported to `assets/sprites/effects/vfx_weapon_thief_smoke_bomb.png` as `256x256` transparent RGBA.
- Existing canonical weapon art `assets/sprites/weapons/thief_smoke_bomb.png` was composited at low opacity as a ghost silhouette under the PixelLab-generated smoke ring.
- Center alpha was softened and final alpha capped for combat readability; no gameplay, balance, targeting, cooldown, scene, or shared runtime logic changed.

Key runtime metrics:

- `bbox`: `[19, 19, 237, 238]`
- `visible_pixel_ratio_alpha_gt_8`: `0.4918`
- `max_alpha`: `172`
- `center_64_mean_alpha`: `81.5`
- `dark_arena_avg_luma_delta`: `37.73`
- `light_arena_avg_luma_delta`: `22.55`
