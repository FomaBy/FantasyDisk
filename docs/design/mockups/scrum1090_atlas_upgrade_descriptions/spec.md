# SCRUM-1090 — Atlas detailed upgrade dossier UI Director spec

Status: `ready_for_independent_re_qa`
Role owner: Design
Jira: SCRUM-1090
Base reference: 688×384 PixelLab source; runtime geometry remains the accepted
1920×1080 SCRUM-1075 Atlas contract.
Responsive targets: 1280×720, 1920×1080, 2560×1440 and same-instance resize.
PixelLab source ID: `cccfc9a1-e067-4507-a178-9dd6d54bfce4` (SCRUM-1092
glyph-free replacement).

Source PNG:
`../../references/scrum1090_atlas_upgrade_descriptions/pixellab_atlas_detailed_dossier_688x384.png`.
Preview/debug:
`../../previews/scrum1090_atlas_upgrade_descriptions/atlas_detailed_dossier_preview_688x384.png`
and adjacent debug overlay.
Responsive contact/report:
`../../previews/scrum1090_atlas_upgrade_descriptions/responsive_contact_sheet.png`
and `responsive_fit_report.json`.

## Scope decision

This Design task changes no production asset, runtime UI, constellation data or
balance. It defines how the existing scrollable Atlas dossier must explain a
selected point. The accepted Meta40 art and schema-6 three-ray topology remain
unchanged.

## Content hierarchy

Every selected purchasable node uses this order:

1. node role and affected axis;
2. upgrade title;
3. owning weapon and explicit `только это оружие` scope;
4. exact trigger/affected parameter with numeric value;
5. current path progress and `before → after` result;
6. price/status and purchase action.

Weapon finals replace the ordinary effect block with a blue-gold
`УНИКАЛЬНЫЙ ФИНАЛ` callout. The callout must state trigger, unique mechanic,
boss/elite behavior where different, numeric caps and the minimum gain over the
preceding node. Flavor text never substitutes for numbers.

## Dossier content zones @ 688×384 reference

| Zone | Rect | Purpose |
| --- | --- | --- |
| exact final callout | `510,69,143,12` | compositor-only `УНИКАЛЬНЫЙ ФИНАЛ` |
| title | `510,84,143,16` | selected node title |
| owning weapon | `510,104,143,14` | weapon title + scope |
| effect | `510,136,143,48` | exact trigger in the second empty compartment |
| result | `510,198,143,48` | boss/final floor in the third empty compartment |
| path progress | `510,260,65,16` | `5/6 → 6/6` or selected rank |
| price | `585,260,67,16` | exact currency and cost |
| state | `510,281,143,14` | availability/purchased/locked state |
| action | `510,300,143,16` | purchase action; stable rect in all states |

The dossier frame is `497,56,169,269`; all content has at least 12 px lateral
reserve from its ornament. The scroll lane exists by design, so long final
mechanics never force smaller-than-minimum typography or overflow onto borders.

## Runtime mapping @ 1920×1080

The Back-end handoff must apply the same hierarchy inside the accepted
SCRUM-1075 dossier `1280,232,400,400`. Its calm text interior is
`1310,252,340,372`; content margins remain at least 30 px left/right and 20 px
top/bottom. Existing `AtlasNodeScroll` owns long copy. Price and Buy stay pinned
outside the scroll viewport, preserving pointer/gamepad reachability.

## Responsive rules

- 1280×720: preserve the dossier width from SCRUM-970/1075; use semantic minima
  and scrolling, never clip or cover ornament.
- 1920×1080: show trigger and result blocks without scrolling for ordinary
  one-effect nodes; complex finals may scroll.
- 2560×1440: scale typography/content gaps, not the outer ornament thickness;
  keep the same information order.
- Same-instance resize recomputes the viewport and scrollbar page; text content
  must not rebuild the constellation or move the purchase controls.

## States

- available: exact `После вложения` result and enabled action;
- locked: same exact result plus the missing prerequisite/currency reason;
- purchased: `Активно` and the exact live effect remain readable;
- hidden: reveal condition/progress precedes effect details until revealed;
- weapon final: blue-gold callout, distinct final socket halo, no activation
  toggle, applies only to its owning weapon.

## Acceptance

- planning validator reports `decision: ready_for_image`;
- PixelLab MCP source/export is recorded and no fallback generator is used;
- compositor reports every text zone fits;
- debug overlay confirms no content crosses dossier/frame ornament;
- mockup preview demonstrates exact numeric final text;
- linked Back-end Jira handoff owns runtime descriptions, data/balance review and
  tests; SCRUM-1090 owns no runtime/data files.

## Design result

- PixelLab MCP config smoke passed and `create_ui_asset` completed source
  `b6693906-f259-4b43-a1b5-4283ff88bec3` at 688×384; no fallback generator was
  used and no asset was promoted to runtime.
- Planning gate: `ready_for_image`, 0 errors, 0 warnings.
- Content compositor: 13/13 zones fit; final copy states the 3-hit trigger,
  35% execute threshold, +24% boss cap and +20% final-strength floor.
- Debug review: every text block sits inside a generated calm compartment; the
  split progress/price row avoids the centre ornament and the action remains in
  its own lower plate.
- Responsive source-reference matrix: 3/3 PASS at 1280×720, 1920×1080 and
  2560×1440. Runtime remains governed by the accepted SCRUM-1075 geometry.
- Back-end handoff: SCRUM-1091, intentionally blocked until this Design result
  passes independent QA and SCRUM-1088/SCRUM-1089 release overlapping locks.

## SCRUM-1092 rework result

- Rejected source `b6693906-f259-4b43-a1b5-4283ff88bec3` / SHA
  `a8d05d4bbc33bb078239b4722ded71fac5640bde869ed62240ba6190e82b9f6f`
  is superseded because it baked a `$` glyph into the header.
- Replacement PixelLab MCP source
  `cccfc9a1-e067-4507-a178-9dd6d54bfce4` / SHA
  `3c2583453bd3d03612df9345676b9a91d465c3ca889481a93473f4a299d429be`
  contains no text, numbers, currency marks, semantic icons, runes or
  pseudo-writing. The original-size audit is recorded beside the source in
  `glyph_audit.json`.
- The required visible callout is compositor-owned and exactly
  `УНИКАЛЬНЫЙ ФИНАЛ`; the base contains no baked replacement or abbreviation.
- Updated planning gate: `ready_for_image`, 20 elements, 0 errors, 0 warnings.
- Updated compositor: 13/13 zones PASS; the exact callout fits at 9 px in
  `Rect2(510,69,143,12)` without touching ornament.
- Updated responsive evidence: 3/3 PASS at 1280×720, 1920×1080 and
  2560×1440; exact callout sizes are 17/25/33 px respectively.
- Runtime/data/assets remain unchanged; SCRUM-1091 stays blocked pending re-QA
  and release of SCRUM-1088/SCRUM-1089 locks.
