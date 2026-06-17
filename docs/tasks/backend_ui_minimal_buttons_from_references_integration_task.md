# UI: Интегрировать SCRUM-450 minimal-metal button kit

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-17
Автор: Designer 2 (Codex handoff)
Jira: SCRUM-462
QA: in_progress (2026-06-17)
Связано: SCRUM-450, SCRUM-452, SCRUM-273, SCRUM-318

## Контекст

Designer 2 подготовил новый Design-ready button kit по пользовательским
референсам: minimal-metal, obsidian/brass + warplate iron + редкие ruby accents.
Пакет сохраняет все 15 runtime button types и добавляет 5 visual states.

## Входные артефакты

- Style guide: `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_style_guide.md`
- Spec: `docs/design/mockups/scrum450_ui_minimal_metal_buttons/spec.md`
- Metadata: `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`
- Contact preview: `docs/design/previews/scrum450_minimal_metal_button_contact.png`
- Safe-zone preview: `docs/design/previews/scrum450_minimal_metal_button_safe_zones.png`
- Assets: `assets/sprites/ui/frames/minimal_metal_buttons/`

## Scope

Back-end owns runtime wiring, old-kit backup, screen rollout and smoke/no-overlap
validation. Do not apply action-button textures to controls that are intentionally
cards/hit areas: route nodes, shop item cards, hero thumbnails, weapon/reward
cards.

## Требования

1. Add path constants for the 15 minimal-metal button families and their
   `normal/hover/pressed/focus/disabled` states.
2. Preserve SCRUM-318 no-yellow hover/focus behavior. If active runtime uses
   neutral tint for hover/focus, keep that semantic and map `_hover`/`_focus`
   only where appropriate.
3. Use metadata texture margins for StyleBoxTexture/NinePatch setup.
4. Keep runtime labels/icons inside `content_rect_xywh`; do not overlap side
   caps, ruby pins, bevels or back-arrow ornaments.
5. Keep existing min sizes from SCRUM-263/SCRUM-264.
6. Back up the SCRUM-273 Red & Gold button kit outside runtime import scope
   before promotion, or leave both kits selectable until QA passes.
7. Update docs and run UI tests.

## Acceptance Criteria

- [x] Runtime loads the new minimal-metal button paths without missing texture errors.
- [x] All 15 button types render in the new style where action-button art is appropriate.
- [x] Hover/pressed/focus/disabled states work without layout shift.
- [x] Text/icons stay inside metadata content rects at 1280x720, 1920x1080 and 2560x1440.
- [x] QA evidence is written under `build/qa/scrum450_minimal_metal_buttons/`.
- [x] `runtime_smoke_ui`, `ui_no_overlap_matrix` and full runtime smoke pass or
      document an unrelated blocker.

## Результат

2026-06-17 Back-end UI done:
- `scripts/ui/ui_theme_paths.gd` exposes SCRUM-450 minimal-metal button dir plus texture/content margin maps for all 15 button types.
- `scripts/ui_screens.gd` promotes `_apply_fantasy_button_theme()` and compact/action button routing to SCRUM-450 normal/hover/focus/pressed/disabled textures while preserving SCRUM-390 combat plus and card/hit-area exceptions.
- `scripts/pause_stats_menu.gd` now uses the same minimal-metal `pause` state textures for the Escape/pause dossier local button helper.
- Codex tab spacing was tightened so the taller `codex_tab` safe margins stay inside the existing Codex nav safe zone.
- SCRUM-273 Red & Gold PNGs were backed up outside runtime import scope at `build/qa/scrum450_minimal_metal_buttons/red_gold_button_backup/` before promotion.
- Added metadata guards and QA dumps: `build/qa/scrum450_minimal_metal_buttons/minimal_metal_button_runtime_kit.md` and `minimal_metal_button_sizes.md`.

Verification PASS:
- Godot import pass (`--editor --quit`) generated imports for SCRUM-450 PNGs.
- `tests/dark_fantasy_ui_theme_test.gd`
- `tests/runtime_smoke_ui_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `tests/runtime_smoke_test.gd`

## QA-Вердикт (2026-06-17)
Статус: PASSED — интеграция 450 button kit
Проверено: `ui_theme_paths.gd` отдаёт button dir + margin-карты (15 типов); `_apply_fantasy_button_theme`
роутит на minimal-metal текстуры (norm/hover/focus/pressed/disabled), сохраняя SCRUM-390 combat-plus
и card/hit-area исключения; `pause_stats_menu.gd` на pause-state текстурах. dark_fantasy_ui_theme PASS;
старые Red&Gold в бэкап. done → Готово.
⚠️ QA: `ui_no_overlap_matrix` имеет 2 ПРЕД-существующих overflow при 1152×648 (settings + attribute_shop, оба и в HEAD до этой волны) — заведены отдельным багом `bug_settings_attribute_shop_overflow_overlap_1152x648_task.md`, НЕ регрессия этого тикета.
