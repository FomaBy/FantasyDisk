# FantasyDisk Semantic Typography Token Contract

Jira: SCRUM-1061
Runtime source: `scripts/ui/semantic_typography.gd`

All sizes below are final effective pixels. The semantic role expresses purpose,
not a particular node type: for example, a `Label` inside a button still uses
`action`, while a compact timer uses `HUD`.

| Role | Min | Target | Max | Overflow policy |
| --- | ---: | ---: | ---: | --- |
| display | 32 | 44 | 72 | One line; expand the authored zone or use a documented fit tier. |
| title | 24 | 34 | 54 | Prefer one line; allow two-line wrap, then ellipsis only where the screen spec permits it. |
| section | 20 | 24 | 34 | Expand section rail first; single-line ellipsis is the final fallback. |
| body | 16 | 18 | 24 | Smart word wrap; grow or scroll the content zone. |
| description | 14 | 17 | 22 | Smart word wrap; grow or scroll, never overlap the frame. |
| action | 16 | 23 | 34 | Widen the flat plate or wrap to two lines; never shrink under min. |
| tab | 16 | 23 | 28 | Widen the standalone plate or allow a specified two-line label. |
| field | 16 | 20 | 28 | Reserve the label column; expand row before ellipsis. |
| value | 16 | 20 | 28 | Keep a stable numeric/status column; no wrap for scalar values. |
| tooltip | 18 | 20 | 24 | Widen 460→620px, then smart-wrap and grow vertically. |
| caption | 12 | 14 | 18 | Supporting single line may ellipsize; smaller sizes require a fingerprinted exception. |
| HUD | 14 | 22 | 34 | Fixed combat-feedback zone; preserve silhouette and use short text. |

## API Choice

- New responsive UI: `SemanticTypography.resolve(role, viewport_height)` or
  `apply(control, role, viewport_height)`.
- Accepted legacy authored grid: `resolve_authored_compat()`; the semantic role
  remains mandatory and the inventory records the owner.
- Existing scale-driven layout: `resolve_scaled_compat()`.
- Codex/design-space transform: `resolve_transform_aware()`.
- Fixed world/HUD feedback: `resolve_fixed()`.

Compatibility methods are not permission to introduce an unbounded local font
formula. A new call must be semantic-native unless an accepted screen spec and
inventory entry justify compatibility.

The committed schema-2 inventory is the authoritative role mapping for
compatibility sites. Roles are not inferred from function names at check time;
each full-expression fingerprint must have an explicit reviewed `mapped` or
`allowlist` decision.

`mapping_mode` is part of that decision. `semantic_native` must remain inside
the role's min/max. `legacy_compat` preserves accepted screen geometry and must
declare a named range contract plus numeric `effective_min`/`effective_max`;
cross-band deferred fits also require owner/reason/next issue.

## Russian And Long-Text Rules

- Measure Cyrillic glyphs with the effective runtime font, not Latin placeholders.
- Buttons/tabs keep at least 2px glyph-effect reserve inside their flat content
  field in every state.
- Tooltip and description overflow grows/wraps the inner content zone; it never
  spills onto frame rails.
- Numeric values keep an explicit stable column so commas, signs and `×1,25`
  remain visible.
- A compact caption below 12px is not accepted without an explicit allowlist
  owner, reason and follow-up issue.
