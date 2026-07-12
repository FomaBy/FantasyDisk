# SCRUM-895 Berserk Axe/Hammer PixelLab VFX

PixelLab MCP is the only generated-source path. The config-based `get_balance`
smoke passed; no secret was printed or committed.

## Axe

- Object `d5452069-7d6e-4646-8b9d-379f0c332f17`.
- v3 group `7e9c7287-d8f0-4461-844e-c1e0bfc5e817`.
- Animation `b318ca47-840b-49d4-ab74-32be1d0c9c5a`.

Prompt direction: one heavy two-handed crescent battle axe, dark steel/wood,
restrained ember rune light; animation winds back and performs a clear broad
left-to-right cleave with the actual blade/haft silhouette always present. No
character, hand, baked wedge, text, UI or background.

## Hammer

- Object `b1fed1f3-71b6-47d5-a1eb-e3e4b8db65b5`.
- v3 group `4515832c-5217-444d-a1a4-b25f1090d435`.
- Animation `11ced058-204f-48dc-bfcb-c0aee7665917`.

Prompt direction: one massive two-handed rune-cracked warhammer, charcoal iron
and restrained violet-gold impact light; overhead windup, clear downward slam,
impact on frame 5, rebound and settle. No character, hand, baked circle, text,
UI or background.

Postprocessing is mechanical: remove only edge-connected near-flat preview
background, cap alpha at 205, inset the complete source canvas by 16px and retain
the PixelLab RGB/motion. Runtime procedural arc/ring layers receive current
weapon radius/angle/center and do not own gameplay membership.
