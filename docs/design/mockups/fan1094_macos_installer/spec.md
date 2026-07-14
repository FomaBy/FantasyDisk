# UI Mockup Spec — macOS Drag-To-Applications Installer

- Status: implemented in build tooling; notarized artifact blocked until Apple credentials are installed
- Role owner: Back-end / release integration
- Task: Multica `FAN-1094`
- Base resolution: `720×480` Finder logical points
- Responsive targets: macOS Finder 1× and HiDPI 2×; fixed logical geometry
- Mockup art layer: `docs/design/references/fan1094_macos_installer/pixellab_arrow.png`
- Art-layer preview: `docs/design/previews/fan1094_macos_installer_arrow.png`
- Runtime DMG smoke: `docs/design/previews/fan1094_macos_installer_runtime.png`
- Generated with: PixelLab MCP `create_map_object`; object `eefc2d99-8fb4-407f-8a84-13f043c4f017`

## Source Request

Replace the cluttered macOS DMG with a minimal drag-to-Applications flow. The
user must only drag the FantasyDisk icon onto Applications. No added decoration
or baked copy is allowed; one arrow is the only permitted drawn element.

## Screen Elements

| ID | Type | Runtime content | Rect / position @ 720×480 | Anchors | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `fantasydisk_app` | native Finder item | signed `FantasyDisk.app` icon + native label | center `{190,235}`, icon size `128` | fixed | Finder | drag/open | Finder canvas |
| `drag_arrow` | bitmap background element | PixelLab arrow only | `275,208,170,64` | centered | background | static | empty gap between icons |
| `applications_alias` | native Finder alias | `/Applications` icon + native label | center `{530,235}`, icon size `128` | fixed | Finder | drop target | Finder canvas |

## Frames And Safe Zones

There is no frame, border, panel, ornament, title, instruction, baked label or
decorative background. The Finder canvas is solid neutral gray. The arrow is
confined to `x=275..445`, leaving at least 21 px between its bounds and the
approximate native icon bounds. Finder owns both labels below the icons, so no
duplicate text is baked into the bitmap.

The `720×480` background PNG is stored inside
`FantasyDisk.app/Contents/Resources/FantasyDiskDmgBackground.png`, not in a
visible `.background` folder at the DMG root. The root allowlist is exactly:

- `FantasyDisk.app`;
- `Applications` symlink to `/Applications`;
- Finder's internal `.DS_Store` only.

`.background`, `.fseventsd`, `.Spotlight-V100`, `.Trashes`,
`.TemporaryItems` and `.metadata_never_index` are forbidden in the sealed DMG.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Notes |
| --- | --- | --- | --- | --- | --- |
| `drag_arrow_source` | `docs/design/references/fan1094_macos_installer/pixellab_arrow.png` | PixelLab provenance/source | 256×96 | RGBA | accepted third pass; no text or decoration |
| `drag_arrow_runtime` | `FantasyDisk.app/Contents/Resources/FantasyDiskDmgBackground.png` | signed Finder background | 720×480 | RGBA | source resized to 170×64 and centered by `build_release.sh` before signing |

## Responsive Rules

- Finder window geometry remains `720×480` logical points.
- Retina/HiDPI scales the window and native icons without changing layout.
- No custom hover, pressed, focus or disabled artwork exists; Finder supplies
  native selection, drag and drop feedback.

## Acceptance Checks

- [x] PixelLab MCP created the only new drawable element.
- [x] Preview shown in the working chat.
- [x] Native app and Applications icons are the only foreground items.
- [x] No baked labels, instructions, frames, scenery or ornament.
- [x] DMG helper rejects any unexpected root item.
- [x] Mounted Retina screenshot matches the fixed `720×480` logical layout.
- [x] Release build rejects ad-hoc or unnotarized macOS output.
- [ ] Build an Apple-accepted artifact and validate it with `stapler` and
  `spctl`; blocked because this Mac has no Developer ID Application identity or
  notary keychain profile.

## Deviations

The first two PixelLab UI-panel attempts ignored the negative prompt and added
fantasy menu art. Both were rejected. The accepted third pass generates only
the arrow art layer; native Finder renders the rest of the final interface.
