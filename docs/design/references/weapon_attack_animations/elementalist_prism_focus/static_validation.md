# SCRUM-743 Static VFX Validation

- Weapon: `elementalist_prism_focus` / `Призматический Фокус`
- PixelLab object/job: `d5ef1e3e-12d7-4f67-9ac0-7ba6a2b4c579`
- PixelLab source: `docs/design/references/weapon_attack_animations/elementalist_prism_focus/pixellab_d5ef1e3e_prism_rift_source.png`
- Alpha-clean source: `docs/design/references/weapon_attack_animations/elementalist_prism_focus/pixellab_d5ef1e3e_prism_rift_alpha_clean.png`
- Runtime PNG: `assets/sprites/effects/vfx_weapon_elementalist_prism_focus.png`
- Preview/contact: `docs/design/previews/weapon_attack_animations/elementalist_prism_focus_contact.png`
- Readability preview: `docs/design/previews/weapon_attack_animations/elementalist_prism_focus_readability.png`
- Postprocess rationale: PixelLab returned the right crossed-prism VFX but with an opaque floor plate, so the runtime export alpha-cleans the luminous magic strokes, removes the generated lower-right mark, caps opacity, and composites a subtle ghost silhouette from `assets/sprites/weapons/elementalist_prism_focus.png` behind/through the PixelLab rift.
- Gameplay/runtime logic changed: no.

## Runtime Metrics

- Mode/size: `RGBA` `256x256`
- Alpha extrema: `(0, 209)`
- Max alpha: `209`
- Average visible alpha: `171.84`
- Visible pixels: `14233` (`21.72%`)
- Visible bbox (alpha > 8): `(34, 35, 223, 221)`
- Corner alphas: `[0, 0, 0, 0]`

## Alpha-Clean Source Metrics

- Mode/size: `RGBA` `256x256`
- Alpha extrema: `(0, 214)`
- Max alpha: `214`
- Average visible alpha: `188.74`
- Visible bbox (alpha > 8): `(34, 35, 223, 221)`

## Visual QA Notes

- Shape reads as two crossing prism-rift beams with a central crystalline focus, matching `prism_rift`.
- Runtime export removes the opaque PixelLab tile plate; the accepted file is a transparent VFX plate, not a square floor decal.
- The final alpha is capped for the existing `AttackVfx.weapon_signature()` additive/modulate layer.
- Corners are transparent and the source watermark/background plate is absent from the runtime PNG.
