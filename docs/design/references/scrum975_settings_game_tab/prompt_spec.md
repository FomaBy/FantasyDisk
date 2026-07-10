# SCRUM-975 PixelLab prompt/spec

Target: a textless 688×387 (16:9) Settings page frame/layout layer that scales
proportionally to 2560×1440. It must match FantasyDisk Settings v6 / Atlas:
strict dark fantasy D&D, blackened iron, dark stone, restrained worn gold,
small blue-steel accents and one subtle amber active-tab glow.

Required structure on the 512×288 PixelLab virtual canvas:

- title chip: `x=45 y=25 w=124 h=18`;
- back plate: `x=415 y=25 w=52 h=21`;
- four separate equal tab plates, never a three-slot strip:
  `x=145/202/258/315 y=50 w=52 h=21`;
- content frame: `x=102 y=76 w=309 h=172`;
- five quiet row separators inside the content frame at y≈131/149/167/185/203;
- reset action plate in the lower-right content interior.

Strict empty content interiors:

- header title/back and every tab's inner label field;
- content safe rectangle equivalent to 2560-space `[556,426,1448,770]`;
- each modifier row label/slider/value rectangle;
- reset label field.

Decorative metal, dragon ornaments, claws, gems, seams, highlights and smoke
must stay outside those interiors. No text, letters, numbers, pseudo-text,
logos, watermarks, characters or weapons. Draw frames around content zones,
never over them. Keep the content center calm and almost black. The composition
must be orthographic, flat UI, no perspective and no one-axis-stretched
ornament. The fourth tab is subtly active in amber; the other three remain
quiet graphite/brass.
