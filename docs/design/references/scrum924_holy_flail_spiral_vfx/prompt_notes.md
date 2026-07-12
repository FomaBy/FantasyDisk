# SCRUM-924 Holy Flail expanding-spiral VFX

PixelLab MCP was the only source-generation path. Config-based `get_balance`
smoke passed; no token or header was printed or stored.

- Object: `b1089fd9-a4c7-49ce-aec2-af62fb0317b6`.
- v3 animation group: `50cb9b87-58b3-411e-af3e-caabce8b4cb4`.
- Animation: `0ff0ce1e-e95c-409a-b542-e50b606fd928`.
- Display name: `holy_flail_center_out_spiral`.
- Source: one-direction, `256x256`, high top-down, eight frames.

The object prompt requested one consecrated dark-steel spiked flail, articulated
chain, restrained sacred-gold light, transparent empty centre, no character,
text, UI or background. The animation prompt requested a clockwise one-turn
uncoil from a tight centre to the outer radius, with the head leading and links
trailing.

PixelLab supplied the moving holy-flail/chain silhouette and changing sacred
head highlights. Runtime geometry does not infer hit mechanics from the bitmap:
the isolated visual node receives each accepted SCRUM-923 step and grows its
chain trail to that exact angle/radius. This makes the seven `0.085s` damage
windows readable even when the generated source motion is subtle.

Postprocessing is mechanical only: remove edge-connected flat preview pixels,
cap alpha at 190, inset the complete PixelLab canvas by 16px with nearest
resampling, and export separate alpha-clean/runtime frames. No frame was
repainted, generated manually or sourced from OpenAI Images.
