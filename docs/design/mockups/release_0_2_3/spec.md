# Release 0.2.3 Announcement Image

Status: planned for FAN-1128.

## User-facing focus

- Secure updates through public GitHub Releases.
- Reliable movement rearm for all 17 playable heroes.
- Direct hero-select start, refreshed main-menu and Codex backgrounds.
- Round Berserk hammer impact and larger Engineer orbital drones.

## Art direction

Create a premium 1350×1350 FantasyDisk release-notes poster. Keep the title,
intro, two release-note columns, and footer as calm empty interiors for later
compositing. Surround those zones with restrained blackened iron, dark stone,
worn gold, tiny crimson gems, subtle violet disk-rift light, and dragon-forged
ornaments. Decorative art must stay outside the declared rectangles.

No text, numbers, letters, pseudo-text, logos, watermarks, characters, weapons,
bright seams, or opaque patches inside content zones. The generated base is the
final visual layer; only the declared logo and text may be composited afterward.

PixelLab source target: 632×424 (`create_ui_asset`). Crop the accepted integrated
frame to its real alpha bounds and resize it to 1350×1350 before compositing.

Strict empty content interiors:

- release badge: `x=80 y=55 w=145 h=80`
- brand logo: `x=240 y=50 w=300 h=90`
- subtitle: `x=790 y=55 w=460 h=80`
- intro: `x=86 y=190 w=1180 h=150`
- left notes: `x=82 y=410 w=580 h=704`
- right notes: `x=692 y=410 w=576 h=704`
- footer: `x=88 y=1188 w=1174 h=112`

Planning gate: `ready_for_image` (0 errors, 0 warnings).
PixelLab source: `5451d4ee-226f-4501-869f-f88446079fb9` (completed and visually accepted).
Final compositor report: `ok` (0 errors, 0 warnings); final and zone-debug images reviewed.
