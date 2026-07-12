# SCRUM-1089 — Route Map Full Fit + HUD 2×

Статус: done
Контур: Codex
Owner: Design + Back-end / Codex root
Thread: current user task (source `019f4879-aabb-7113-b8e4-3e3e2e898fc5`)
Locked paths: `scripts/route_map_screen.gd`, focused route-map tests/capture, `docs/design/mockups/scrum1089_route_map_full_fit_hud2x/`, matching references/previews and Route Map documentation
Jira: SCRUM-1089
Ветка: `codex/scrum-1089-route-map-full-fit`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/SCRUM-1089`

## Контекст

Пользователь показал live Route Map, где маршрут занимает слишком мало высоты и ширины, девятая колонка уходит в горизонтальный scroll, а верхний HP/XP/ULT/gold HUD слишком мелкий. Требуется сразу видеть весь маршрут, поднять верхний информационный блок, заполнить пустую внутреннюю область до безопасных отступов золотого shell и увеличить ресурсный HUD ровно вдвое относительно прежнего видимого размера.

Combined scope Design + Back-end подтверждён Jira-комментарием: PixelLab mockup/spec и runtime integration используют один экран и одни locked paths.

## Решение

- сохранить production backdrop, реальные route-node icons и hollow `meta40/frame_border.png`;
- использовать PixelLab только как textless layout reference, не как runtime bitmap;
- уточнить irregular safe zone внешнего frame: боковые rails сохраняют 160 px source margin, а пустой верх/низ начинается после 128 px source ornament; поверх этого применяется 24 px reserve (32 px на 2560×1440);
- на 1152/1280/1600 поставить title/progress над HUD, на 1920/2560 — рядом;
- удвоить фактический видимый `RunResourceHud` относительно SCRUM-1079;
- отключить обе полосы прокрутки и подогнать canvas под node viewport, чтобы все 9 колонок всегда были видны;
- сохранить drag suppression, focus/navigation, tooltip, route data и pending level-up FAB без пересечений.

## Acceptance Criteria

- [ ] PixelLab MCP mockup/spec сохранены, preview показан в чате.
- [ ] На 1280×720, 1920×1080 и 2560×1440 одновременно видны все 9 колонок route data.
- [ ] Horizontal и vertical scrolling отключены; scrollbar не занимает место.
- [ ] Карта выше и шире прежней node viewport, насколько позволяет компактный tier.
- [ ] Шапка поднята, не касается frame ornament.
- [ ] HP/XP/ULT/gold HUD имеет 2× прежний видимый размер и остаётся внутри header safe zone.
- [ ] Title/progress, HUD, nodes, lines, FAB и tooltip не перекрывают рамки или друг друга.
- [ ] Focused geometry/capture tests и `runtime_smoke_test.gd` проходят через `tools/godot_gate.py`.
- [ ] Документация обновлена, изменения закоммичены и запушены в `origin/dev` после свежей интеграции.
- [ ] Jira переведена в «Контроль качества» с точным commit/tests/disk cleanup и locks освобождены.

## Evidence

- User reference: `docs/design/references/scrum1089_route_map_full_fit_hud2x/user_reference_before.png`
- PixelLab source ID: `a32def07-33e5-464d-a046-4967feefa4b1`
- PixelLab reference: `docs/design/references/scrum1089_route_map_full_fit_hud2x/pixellab_route_map_full_fit_hud2x_688x384.png`
- Mockup/spec: `docs/design/mockups/scrum1089_route_map_full_fit_hud2x/spec.md`
- Responsive matrix: `docs/design/mockups/scrum1089_route_map_full_fit_hud2x/responsive_matrix.json`

## Результат

Runtime implementation готова к финальному green gate:

- все 9 route columns помещаются без horizontal/vertical scroll;
- шапка поднята по measured irregular shell safe-zone;
- HP/XP/ULT/gold HUD масштабирован ровно в 2× от SCRUM-1079 visible baseline;
- compact tiers используют stacked header, desktop tiers side-by-side;
- multi-branch columns используют 55% дополнительной безопасной высоты;
- `HudULTLabel` route-only clamp сохраняет текст внутри собственного HUD rect;
- PixelLab provenance/spec и пятиразмерная runtime capture matrix сохранены.

Промежуточные проверки: `scrum1089_route_map_full_fit_hud_test.gd` PASS,
`scrum1079_route_map_horizontal_test.gd` PASS,
`scrum981_route_map_gold_shell_test.gd` PASS,
`scrum1086_route_map_header_text_fit_test.gd` PASS,
`ui_no_overlap_matrix_test.gd` PASS,
`runtime_smoke_ui_test.gd` PASS,
`dark_fantasy_ui_theme_test.gd` PASS,
`runtime_smoke_test.gd` PASS.

Final Metal capture matrix:
`docs/design/previews/scrum1089_route_map_full_fit_hud2x/runtime/`.

Implementation commit landed in `origin/dev`: `1c9cf28f1`.

Final post-rebase gates on `1c9cf28f1`:

- `tests/scrum1089_route_map_full_fit_hud_test.gd` — PASS (exact steps 0..8, no `-1`, title↔HUD no-overlap, HUD children in safe-zone, 2.00× baseline, 1280/1920/2560);
- `tests/ui_no_overlap_matrix_test.gd` — PASS;
- `tests/runtime_smoke_test.gd` — PASS (`Duplicate-artifact guard passed`, known optional dummy-renderer screenshot warning only).

Disk cleanup: removed `.godot` cache (446M) and 55 transient `.import`/`.uid` sidecars; isolated worktree and task branch are removed after this review-status sync lands.

Locks: released for independent QA after `origin/dev` landing.
