# SCRUM-1050 PixelLab Prompt Contract

## Reference sheet

Create a 688x384 textless dark-fantasy D&D game UI reference board. Transparent background. Orthographic front view, no perspective, no mock device, no letters, numbers, pseudo-text, logos, watermarks, checkerboard, portraits, weapons or characters.

Use one coherent material family across every component: graphite/obsidian interiors, thin blackened-steel rails, aged-brass hairlines, restrained deep-crimson enamel or ruby pins, subtle ember highlights. Premium, brutal, crisp and readable; no beige parchment wash, no neon, no bulky ornament.

Top row: exactly five equal button specimens in stable geometry for normal, hover, pressed, keyboard-focus and disabled. They must remain recognizably the same button. Hover/focus use neutral bright metal and restrained inner light, not yellow glow. Pressed darkens the center without resizing. Disabled is desaturated. Each button must keep x+16/y+12/w-32/h-24 as a calm empty label/icon interior.

Below: exactly eight accent panels in a 4x2 grid, all siblings from the same family but distinct through small edge cues only:
- heroic crest notch for Main Menu;
- portrait/compass corners for Hero + Weapon Select;
- mechanical tab ticks for Settings;
- quiet book-divider edge for Codex, while its interior remains a frameless three-column-safe material reference;
- compact minimal rail for Combat HUD;
- treasure/rune pin for economy screens;
- gem/socket notch for Rewards + Level Up;
- restrained crest edge for Pause + Results.

The strict empty interiors from ui_plan.json must contain no ornament, seam, highlight, smoke, symbol or texture interruption. Draw decoration around each zone, never through it. No large shared outer gold shell: this is a component/reference board, not a replacement full-screen frame.

## Gratitude icon

Create one isolated transparent 256x256 game UI icon, no button background and no text. Two symmetrical articulated dark-steel gauntleted hands/palms rise from the lower sides and gently support a small warm glowing crimson-gold heart or benevolent spark. The gesture must read instantly as thanks, support and appreciation, not combat, prayer, healing, donation, romance or a trophy. D&D dark-fantasy dragon-forged metal, aged brass edge highlights, restrained ruby accents, clean centered silhouette, strong readability at 32-48 px. Keep all visible pixels inside x=48 y=48 w=160 h=160 with soft glow contained inside that safe box. No letters, coins, currency, banner, frame, border, weapon, character, watermark or checkerboard.
