# SCRUM-1080 QA: нижний правый gratitude + version responsive matrix

Статус: done
Версия: 0.2.1
Jira: SCRUM-1083
Контур: Codex
Owner: QA
Thread: /root/main_menu_corner_qa
Locked paths: read-only verification; QA evidence in this mirror

## Scope

Independently verify the lower-right gratitude + dynamic-version cluster:
gratitude immediately left of the version, enlarged hitbox, bounded glow,
neutral focus, original action-column placement, frame-safe zones, the full
responsive matrix and live resize. QA does not fix implementation.

## QA-Вердикт (2026-07-12)

Статус: **QA PASSED**

- Точная runtime-геометрия совпадает с
  `docs/design/mockups/scrum1081_main_menu_bottom_corners/spec.md` во всех
  пяти точках: 1152×648, 1280×720, 1600×900, 1920×1080 и
  2560×1440, а также при live resize 2K→648p.
- `MainMenuActions` сохраняет исходную SCRUM-1059 левую
  колонку. `MainMenuCreditsButton` стоит слева от
  `MainMenuVersionLabel`; между bounded glow и версией сохранён
  специфицированный 12/16/20 px gap.
- Размеры icon-only hitbox равны 72/80/96 px; procedural glow
  ограничен 84/96/116 px, игнорирует mouse input и ни в
  одном состоянии не выходит из authored inner safe-zone.
- Версия разрешается динамически из
  `application/config/version`; на проверенном checkout это
  `v0.2.0`. Литерал релиза в UI не зашит.
- Сохранены accepted gratitude asset, пустой face text,
  tooltip/accessibility `Благодарности`, `credits_icon`, callback и
  UI SFX. Focus style остался нейтральным/нежёлтым;
  навигация замкнута и детерминирована.
- Проверка Metal captures подтвердила читаемость,
  сдержанное свечение, отсутствие пересечений и
  наложения контента на золотой орнамент. Runtime визуально
  совпадает с accepted preview.

### Фактические прогоны

- `tests/scrum1059_main_menu_single_column_test.gd` — PASS.
- `tests/scrum981_gold_menu_shell_test.gd` — PASS.
- `tests/scrum1051_ui_button_family_test.gd` — PASS.
- `tests/ui_no_overlap_matrix_test.gd` — PASS.
- `tests/gamepad_menu_focus_test.gd` — PASS.
- `tests/gamepad_full_flow_smoke_test.gd` — PASS, 3/3 consecutive runs.
- `tests/runtime_smoke_ui_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS.
- Windowed Metal `tools/capture_scrum1059_main_menu.gd` — PASS на всех
  пяти целевых разрешениях; репрезентативный временный
  screenshot до cleanup:
  `build/qa/scrum1059/main_menu_1920x1080.png`.

Runtime UI/full smoke вывели только известную dummy-renderer
diagnostic `texture_2d_get: Parameter "t" is null` в test-only weapon-select
screenshot helper; оба прогона завершились exit 0 с явным PASS.

Краевые случаи: compact 1152×648, tier boundary 1280×720,
2K 2560×1440, live 2K→648p shrink, три последовательных
gamepad full-flow прогона.

Баги: нет.

Production implementation/design/tests не изменялись independent QA.

Disk cleanup: removed QA `.godot` import cache (~446 MiB), transient Metal
captures (~14 MiB), isolated HOME/XDG scratch roots and 50 generated untracked
`.uid`/`.import` sidecars.
