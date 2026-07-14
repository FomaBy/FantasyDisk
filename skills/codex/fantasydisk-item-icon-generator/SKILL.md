---
name: fantasydisk-item-icon-generator
description: Use this skill when generating, revising, or specifying FantasyDisk artifact icons, stat or attribute icons, weapon icons, or item-icon source packs that need canonical IDs, PixelLab MCP source generation, transparent PNG output, D&D + Dark Fantasy Dragon style, small-size readability, and QA evidence.
---

# FantasyDisk Item Icon Generator

Use this skill for focused item-icon work after the repository instructions in `AGENTS.md` and the current Multica issue have been checked. This skill narrows `$fantasydisk-asset-generator` for four icon routes: artifacts, basic stat icons, derived attribute icons, and weapon icons.

## Scope

- In scope: icon art direction, PixelLab MCP prompt/spec design, transparent source PNGs, exact naming, source/reference storage, contact sheets, alpha/readability QA, and Multica handoff notes.
- Out of scope: gameplay, balance, runtime integration, UI layout code, animation rigs, and mass production packs unless the Multica issue explicitly asks for them.
- Do not use OpenAI Images, built-in image generation, old manual generation, or non-PixelLab flows for new icons. Reuse the current PixelLab MCP asset workflow from `$fantasydisk-asset-generator`.

## Required Inputs

Before generating or specifying icons, record these inputs in the task notes:

- `asset_category`: one of `artifact`, `stat_basic`, `stat_derived`, or `weapon`.
- `canonical_id`: snake_case runtime ID from `docs/design/content_registry.md` or the relevant `ProgressionData` table.
- `display_name`: player-facing name, only for prompt intent; do not bake text into the icon.
- `target_size`: final PNG size, normally `256x256` unless the issue names another size.
- `final_path`: exact runtime path from the asset matrix below.
- `source_dir`: exact source/reference folder under `docs/design/references/icons/`.
- `style_notes`: material, silhouette, class/stat association, palette constraints, and any must-avoid motifs.
- `pixellab_source`: PixelLab asset/project ID or planned tag/name once generated.
- `qa_evidence`: preview/contact-sheet path and alpha/readability report path.

## Asset Matrix

Use these default paths unless the Multica issue names a newer canonical route:

| Category | Runtime PNG | Source/reference folder | Preview/evidence |
| --- | --- | --- | --- |
| Artifact | `assets/sprites/ui/icons/artifacts/artifact_<canonical_id>.png` | `docs/design/references/icons/artifacts/<canonical_id>/` | `docs/design/previews/artifact_icons_<batch>.png` |
| Basic stat | `assets/sprites/ui/icons/stats/stat_<canonical_id>.png` | `docs/design/references/icons/stats/<canonical_id>/` | `docs/design/previews/stat_icons_<batch>.png` |
| Derived attribute | `assets/sprites/ui/icons/derived/attr_<canonical_id>.png` | `docs/design/references/icons/attributes/<canonical_id>/` | `docs/design/previews/attribute_icons_<batch>.png` |
| Weapon | `assets/sprites/weapons/<canonical_id>.png` | `docs/design/references/icons/weapons/<canonical_id>/` | `docs/design/previews/weapon_icons_<batch>.png` |

For weapon attack signatures or VFX plates, use the dedicated VFX route only when the Multica issue explicitly asks for it: `assets/sprites/effects/vfx_weapon_<canonical_id>.png`.

The stat routes intentionally match `scripts/ui_icon_registry.gd`: base stats load from `assets/sprites/ui/icons/stats/stat_<id>.png`, while derived parameters load from `assets/sprites/ui/icons/derived/attr_<id>.png`. Do not collapse these into one folder or prefix.

## Generation Workflow

1. Confirm ownership in Multica and locked paths before creating files.
2. Validate canonical IDs against `docs/design/content_registry.md` and any live data table used by the issue. For stats, verify basic IDs against `scripts/stat_formulas.gd::BASE_STAT_ORDER` and derived IDs against `scripts/stat_formulas.gd::DERIVED_STAT_ORDER` / `scripts/ui_icon_registry.gd`.
3. Build one PixelLab prompt/spec per icon using the template below, preserving the category and ID in local notes.
4. Generate, revise, or fetch icons through PixelLab MCP from `$fantasydisk-asset-generator`, saving source PNGs under the source/reference folder first.
5. Crop/resize only to the requested square size, keeping transparent padding and the full subject visible.
6. Export final PNGs to the runtime path with the exact matrix naming.
7. Produce a contact sheet at runtime scale and a QA report covering alpha, cropping, readability, and naming.
8. Update the Multica issue and local mirror with generated paths, evidence paths, and any handoff needed for integration.

If PixelLab MCP cannot be reached, read `../pixellab_mcp_auth.md` and run the
config-based smoke before blocking or handing off the task. Do not use
`generate_asset.py`, `image_gen`, or any OpenAI Images fallback for new icon
creation unless the user explicitly overrides the rule in the active task.

## Prompt Template

Use one concise PixelLab prompt/spec per icon:

```text
D&D + Dark Fantasy Dragon game icon, transparent background, isolated <asset_category> for FantasyDisk.
Canonical id: <canonical_id>. Player-facing concept: <display_name>.
Visual motif: <style_notes>. Centered full subject, readable silhouette at 32px and 64px, strong material contrast, subtle painterly highlights, no frame, no text, no letters, no numbers, no UI panel, no background, no cropping.
Final icon must work as a 256x256 RGBA PNG with clean alpha edges and 10-18% transparent padding.
```

For stat and attribute icons, favor symbolic silhouettes over literal labels: strength as a clenched gauntlet or cracked anvil, damage as a blade impact, defense as a shield plate, move speed as a boot trail, pickup radius as a magnet/rune ring, and so on.

## Self-Serve Examples

Use these examples as patterns for task notes. Do not generate production packs unless the active Multica issue explicitly asks for image output.

```text
asset_category: stat_basic
canonical_id: strength
display_name: Strength
target_size: 64x64
final_path: assets/sprites/ui/icons/stats/stat_strength.png
source_dir: docs/design/references/icons/stats/strength/
style_notes: heavy iron gauntlet crushing cracked black stone, warm red-gold edge light, simple silhouette.
qa_evidence: docs/design/previews/stat_icons_strength_contact.png plus alpha/readability report.
```

```text
asset_category: weapon
canonical_id: long_spear
display_name: Long Spear
target_size: 256x256
final_path: assets/sprites/weapons/long_spear.png
source_dir: docs/design/references/icons/weapons/long_spear/
style_notes: noble dark-steel spear with aged brass socket and restrained ruby cloth wrap, full weapon visible diagonally.
qa_evidence: docs/design/previews/weapon_icons_knight_contact.png plus alpha/readability report.
```

## QA Checklist

The icon set is not ready until all checks pass:

- PNG is RGBA with transparent background and no opaque square matte.
- Subject is not cropped and keeps 10-18% transparent padding inside the square.
- Silhouette is readable at `32x32`, `40x40`, and `64x64`.
- No baked text, letters, numbers, watermark, frame, panel, or background scene unless the Multica issue explicitly requests it.
- Palette/materials match D&D + Dark Fantasy Dragon and are consistent across the batch.
- Runtime filename matches the canonical ID exactly, including `artifact_`, `stat_`, or `attr_` prefixes where required.
- Source PNG, final PNG, prompt notes, contact sheet, and QA report are all recorded in the local task mirror and Multica result comment.

When any check fails, regenerate or revise the icon before handoff. Do not patch failed images by drawing over them with unrelated UI panels or frames.

## Reporting Requirements

Every icon task must finish with a local mirror/Multica note that lists:

- the claimed FAN key, role/lane, owner, and locked paths;
- every canonical ID and category validated, including the source used for validation;
- PixelLab source IDs/tags/names and prompt/spec notes;
- final runtime paths, source/reference paths, prompt notes, contact sheets, and alpha/readability reports;
- any IDs skipped or blocked, with a precise reason and follow-up Multica issue if needed;
- confirmation that PixelLab MCP was used and that no legacy/OpenAI/built-in generator was used unless Multica explicitly recorded the exception.
