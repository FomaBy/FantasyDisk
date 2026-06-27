# Задача Для Design-Агента: Level Up Popup Badge

Статус: done
Создано: 2026-06-27
Jira: SCRUM-519
Версия: 0.1.7
Спринт: Спринт 0.1.7
Роль: Designer 2 (Codex)
Исполнитель: Codex / Designer 2
Контур: Codex
Owner/Worker: 019ec7a6-55a5-7bc3-a397-606ce046308d
Locked paths:
- `docs/design/references/level_up_popup/`
- `docs/design/previews/level_up_popup_badge_contact_sheet.png`
- `assets/sprites/effects/level_up_popup_badge.png`

## Контекст
Нужен production-ready transparent PNG badge/icon с текстом `Level Up` для
короткого popup возле персонажа. Runtime-показ делает отдельный Back-end тикет
SCRUM-520; эта задача отвечает только за Design-source, финальный PNG, QA
evidence и handoff.

## Acceptance Criteria
- [x] Создан transparent PNG icon/badge с текстом `Level Up`, читаемый на
  игровых фонах и при небольшом размере возле персонажа.
- [x] Asset имеет чистую alpha, не содержит белого/матового фона и не обрезан
  по краям.
- [x] Размер и safe padding подходят для runtime popup; source/варианты
  сохранены рядом с финальным asset.
- [x] Source/reference файлы и preview/contact sheet сохранены под
  `docs/design/references/level_up_popup/`.
- [x] Добавлен краткий handoff для Back-end: финальный asset path,
  recommended display size, pivot/anchor and animation notes.

## Результат 2026-06-27 (Designer 2 / Codex)
Design-source pass complete. Created an accepted D&D + Dark Fantasy Dragon
`Level Up` popup badge with a generated empty badge base and composited real
text inside the declared content zone.

Final runtime asset:
- `assets/sprites/effects/level_up_popup_badge.png`

Source/evidence:
- `docs/design/references/level_up_popup/level_up_popup_badge_base.png`
- `docs/design/references/level_up_popup/level_up_popup_badge_base_alpha.png`
- `docs/design/references/level_up_popup/level_up_popup_badge_final.png`
- `docs/design/references/level_up_popup/level_up_popup_badge_final_debug.png`
- `docs/design/references/level_up_popup/level_up_popup_layout_plan.json`
- `docs/design/references/level_up_popup/level_up_popup_layout_plan.report.json`
- `docs/design/references/level_up_popup/level_up_popup_layout.json`
- `docs/design/references/level_up_popup/level_up_popup_badge_alpha_report.json`
- `docs/design/previews/level_up_popup_badge_contact_sheet.png`

QA summary:
- PNG: 512x256 RGBA.
- Alpha: extrema `[0, 255]`, `edge_alpha_max=0`.
- Matte/spill: `white_matte_pixels_alpha_gt_8=0`,
  `green_spill_pixels_alpha_gt_8=0`.
- Safe padding: left 66 px, top 12 px, right 65 px, bottom 10 px.
- Recommended display size: 224x112 px.
- Minimum readable display size: 160x80 px.

Back-end handoff:
- Jira SCRUM-520 commented and unblocked.
- Use final asset `assets/sprites/effects/level_up_popup_badge.png`.
- Pivot/anchor: center-bottom, offset 10-18 px above player head.
- Suggested animation: scale 0.92 -> 1.04 -> 1.0, float upward 24-36 px,
  fade out over about 0.85 seconds.

No runtime UI/code/gameplay changes were made.

## QA-Вердикт 2026-06-27
Статус: PASSED

Проверено:
- Final asset exists: `assets/sprites/effects/level_up_popup_badge.png`.
- Runtime asset is byte-identical to `docs/design/references/level_up_popup/level_up_popup_badge_final.png`.
- Independent PIL audit: 512x256 RGBA, alpha extrema `[0, 255]`, nontransparent bbox `[66, 12, 447, 246]`, edge alpha max `0`, safe padding left/top/right/bottom `66/12/65/10`, green spill `0`.
- Broad white-like scan found one fully opaque highlight/text pixel at `(404, 133)` and zero low/partial-alpha white pixels, so no matte/halo background issue.
- Layout plan/report valid: `decision=ready_for_image`, `label_zone x=92 y=83 w=328 h=88`, `fit_font_size=72`.
- Visual QA: final badge has clean transparent edges and remains readable at 224x112 and 160x80 on dark, light, and busy gameplay-like backgrounds.
- SCRUM-520 handoff is present with asset path, display size, pivot/anchor, offset and animation notes.

Product call: lower empty badge area accepted as intentional reserve for future level-number/subtext; not a blocker for this source asset.
