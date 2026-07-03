# BUG: SCRUM-855 weapon overlays are far below requested 60% opacity

Статус: new
Приоритет: high
Роль: Back-end
Версия: 0.2.1
Контур: Codex
Исполнитель: Codex
Jira: SCRUM-864
Найдено QA при тестировании: SCRUM-855
Связано: SCRUM-855

## Воспроизведение

1. Check SCRUM-855 acceptance: weapon overlays in combat should read at roughly
   `60% opacity` and should not look nearly invisible.
2. Inspect the committed Berserk exact-zone overlay path on `origin/dev`.
3. Compare configured weapon `visual_color.a` values with the exact-zone overlay
   alpha applied in `scripts/berserk_weapon.gd`.

## Ожидание / Реальность

Expected:
- Exact damage-zone overlays for weapon attacks are readable at about 60%
  opacity, or the backend evidence explains a different accepted opacity.

Actual:
- `scripts/berserk_weapon.gd` clamps the exact-zone polygon alpha to
  `minf(visual_color.a * 0.55, 0.22)`.
- Current Berserk weapon colors are `0.32..0.34` alpha, so the exact-zone overlay
  becomes about `0.176..0.187`, capped at `0.22`; this is far below the requested
  60% readability target.
- The general `attack_vfx_smoke_test.gd` path can pass while this specific
  exact-zone overlay remains too faint, so SCRUM-855 needs a focused assertion or
  visual evidence for the exact overlay layer.

## Окружение

- QA source: Jira SCRUM-855 acceptance criteria.
- Verified on `origin/dev` after fast-forward to `7a74c850`
  (`chore(SCRUM-856): intake full class rebalance wave`); SCRUM-855 runtime code
  still comes from earlier dev commits.
- Relevant paths:
  - `scripts/berserk_weapon.gd`
  - `scripts/progression_data_weapons.gd`
  - `tests/attack_vfx_smoke_test.gd`

## Suggested Fix

- Raise exact-zone overlay alpha to the SCRUM-855 readability target, or add a
  documented calibrated value with screenshot evidence if 60% is visually too
  strong.
- Add a focused test/evidence dump for `_show_exact_zone_overlay` so the generic
  VFX smoke cannot miss this acceptance point.
