# Release 0.2.2 Announcement Image

Status: accepted for FAN-1090.

## User-facing focus

- Concise release notes cover every one of the 17 playable heroes.
- All 51 starting weapons have a viable role; crowd scaling is bounded.
- The new Codex/lore pass and main-menu background are summarized without internal implementation details.

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
- subtitle: `x=870 y=55 w=370 h=80`
- intro: `x=86 y=190 w=1180 h=150`
- left notes: `x=82 y=410 w=580 h=704`
- right notes: `x=692 y=410 w=576 h=704`
- footer: `x=88 y=1188 w=1174 h=112`

Planning gate: `ready_for_image` (`ok=true`, zero errors, zero warnings).

Accepted PixelLab source: `e074fae7-42ce-4627-858f-1e12ac26baa7`
(`release_0_2_2_character_notes`). PixelLab MCP config smoke and direct JSON-RPC
bridge both passed without printing secrets. The 632×424 source was cropped to
the integrated frame, resized to 1350×1350, and the baked editor checker outside
the frame was flood-cleaned to near-black without touching frame/content pixels.

Final compositor report: `release_0_2_2_render_report.json`, `ok=true`; all 17
hero notes fit inside the two body zones. The debug overlay confirms the logo,
text, and footer stay clear of dragon ornaments and frame borders.
