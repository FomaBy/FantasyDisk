# SCRUM-1061 Semantic Typography — UI Director Spec

Status: implemented / awaiting independent QA
Role owner: Back-end UI integration under accepted Design sources
Jira: SCRUM-1061
Base resolution: 1920×1080
Responsive targets: 1152×648, 1280×720, 1600×900, 1920×1080,
2560×1440, 3840×2160
Contact sheet:
`docs/design/mockups/scrum1061_semantic_typography/accepted_frames_contact_sheet.png`
Generated with: no new art. The contact sheet is a deterministic composition of
accepted PixelLab/runtime previews made by
`tools/build_scrum1061_typography_contact.py`.

## Source Request

Unify player-facing typography behind a semantic, responsive API without
flattening the D&D + Dark Fantasy Dragon hierarchy, reducing text below readable
floors, or moving content onto ornamental frame zones.

## Accepted PixelLab Anchors

| Screen | Accepted source used | Typography surfaces | Safe-zone rule |
| --- | --- | --- | --- |
| Settings | `docs/design/previews/scrum975_settings_game_tab/settings_game_1920x1080.png` | title, tab, section, field, value, description, action | Text remains inside the seamless inner panel and the flat middle of standalone tab/action plates. |
| Codex | `docs/design/previews/scrum954_codex_runtime/codex_1920x1080.png` | title, tab, field, body, description, caption | The 1920×1080 design stage may transform; resolved visual px stays within token bounds. Text stays inside each leather/card content inset. |
| Pause dossier | `docs/design/previews/atlas_style_pause_menu_2560x1440.png` | title, section, field, value, tooltip, action | Existing atlas frame/content margins are immutable; dense cards use authored compatibility sizes. |
| Route map | `docs/design/previews/scrum981_gold_menu_shell/pixellab_route_map_gold_shell_reference_688x384.png` | title, caption, HUD, action | Header/node copy stays inside the meta40 inner safe rectangle; no text enters the gold rail. |

No frame, ornament, plate, image well, anchor, size, or content margin changes in
SCRUM-1061. Existing screen specs remain the geometry source of truth.

## Semantic Roles

The canonical contract is
`scripts/ui/semantic_typography.gd`; the detailed table and overflow rules are in
`token_contract.md`.

| Role | Typical content | Min / target / max effective px |
| --- | --- | --- |
| display | victory/defeat, level-up toast | 32 / 44 / 72 |
| title | screen/modal title | 24 / 34 / 54 |
| section | panel heading | 20 / 24 / 34 |
| body | ordinary readable copy | 16 / 18 / 24 |
| description | explanatory copy | 14 / 17 / 22 |
| action | button label | 16 / 23 / 34 |
| tab | tab/navigation plate | 16 / 23 / 28 |
| field | row/stat label | 16 / 20 / 28 |
| value | numeric/status value | 16 / 20 / 28 |
| tooltip | tooltip title/body | 18 / 20 / 24 |
| caption | supporting hint | 12 / 14 / 18 |
| HUD | timer, feedback, compact combat signal | 14 / 22 / 34 |

## Responsive Rules

- Semantic-native `resolve()` interpolates min→target from 648p to 1080p and
  target→max from 1080p to 2160p; results are monotonic and clamped.
- `resolve_authored_compat()` preserves the accepted SCRUM-883 1.32→1.45
  readability curve for existing `ui_screens` and route-map authored values.
- `resolve_scaled_compat()` preserves Settings/pause/HUD authored layout scales.
- `resolve_transform_aware()` compensates Codex design-space font size so the
  rendered size after stage transform stays inside the selected visual band.
- 1152×648 and 1280×720 may wrap/scroll only as allowed by the role; no generic
  shrink-to-fit below a role minimum is introduced.
- 1600×900, 1920×1080, 2560×1440 and 3840×2160 preserve hierarchy; large windows
  may grow type only up to role max.
- Continue Run title is inventoried as `title`; its SCRUM-1062 slot, effective
  tier, default font family and geometry are intentionally untouched.

## Inventory And Allowlist

`typography_inventory.json` fingerprints every player-facing GDScript theme
override, full multiline font expression, `draw_string` dependency and
`FONT_SIZE` constant, plus `.tscn`/`.tres`/`.theme` font overrides. The schema-2
fingerprint uses path, function, normalized full expression and same-source
ordinal. Role/status comes only from the explicit reviewed manifest: a new or
changed fingerprint becomes `unreviewed`, and
`tools/typography_inventory.py --check` refuses to pass or rewrite it.

The manifest separates future `semantic_native` consumers from the 245 accepted
`legacy_compat` assignments. Native sites must stay inside the canonical token
band. Every compatibility site carries a named range contract and numeric
reviewed site-effective bounds; 141 cross-band accepted-geometry assignments are
explicit allowlist entries rather than silently weakening the native scale.

The inventory currently contains 104 in-band mappings and 141 authored
cross-band compatibility contracts. Every entry records owner, reason and a
truthful next issue:

- SCRUM-1068 owns only two Atlas-canvas/topology fingerprints;
- SCRUM-1073 owns the exact 139-fingerprint manifest for all remaining legacy
  cross-band component geometry and stays unassigned until SCRUM-1061 lands;
- SCRUM-1070 remains limited to its Atlas reset-footer button scope and owns no
  current typography-inventory fingerprint.

The developer console is explicitly outside player-facing scope.

## Acceptance Checks

- [x] Accepted PixelLab anchors reused; no unapproved art fallback.
- [x] Token contract has all required roles, min/target/max and overflow policy.
- [x] Route-map duplicate readability formula removed.
- [x] Existing readable/Settings/Codex/pause helpers delegate to one API without
  changing established effective values.
- [x] Tooltip, toast, threat indicator, world combat feedback and raw combat HUD
  typography route through the semantic source.
- [x] Machine inventory/fingerprint and Russian glyph matrix tests added.
- [x] Continue Run SCRUM-1062 geometry unchanged.
- [x] Frame ornaments and safe zones unchanged.

## Deviations

No new PixelLab generation was performed because this task changes typography
semantics, not art/layout, and accepted PixelLab packages already cover every
touched screen family. The contact sheet makes that reuse explicit. Compact
Atlas/card fit exceptions remain visually unchanged and are routed to their
own follow-up issues rather than being mass-rewritten here.
