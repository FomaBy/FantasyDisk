# SCRUM-1059 — Main Menu: шесть действий одной колонкой слева

Статус: done
Версия: 0.2.1
Jira: SCRUM-1059
Контур: Codex
Owner: Back-end/Codex `/root/scrum1059_mainmenu_column`
Thread: `/root/scrum1059_mainmenu_column`
Locked paths: MainMenu-only hunks in `scripts/ui_screens.gd`; MainMenu focused tests; `docs/design/mockups/scrum1059_main_menu_column/**`; MainMenu sections of `docs/design/current_game_state.md` and `docs/design/systems/menus_ui.md`.

## Цель

Перестроить шесть основных действий главного меню из сетки 2×3 в одну
адаптивную вертикальную колонку слева, сохранив текущий фон, логотип, золотую
раму, semantic button family и отдельную icon-only кнопку благодарностей.

## Обязательный Design-контракт

- UI Director mockup/spec создаётся до runtime-изменений.
- Новая графика не генерируется: действует уже принятое для SCRUM-1050
  исключение `existing source reuse` из-за низкого PixelLab-бюджета.
- Композиция использует только принятые PixelLab/runtime-источники:
  `main_menu_epic_battle_v3.png`, `main_menu_title_fantasy_disk.png`,
  `frame_border.png`, семейство `main_menu_380x104` и
  `ui_icon_gratitude.png`.
- Контент находится только в реальной authored inner-зоне золотой рамы;
  scrollbars запрещены.

## Acceptance criteria

- `MainMenuActions.columns == 1`, ровно шесть кнопок в каноническом порядке.
- Колонка, логотип, gratitude button и version label не пересекаются и остаются
  внутри authored inner-зоны при 1152×648, 1280×720, 1600×900, 1920×1080 и
  2560×1440, включая live resize.
- Сохраняются callbacks, UI SFX, unread badge, пять visual states и registered
  main-menu family.
- Up/Down образует детерминированное кольцо шести действий; gratitude доступна
  и возвращает фокус без trap.
- Focused geometry, gold shell/no-overlap, semantic family, gamepad, runtime и
  full smoke проходят; Metal capture matrix визуально принят.

## Результат

- `MainMenuActions` содержит ровно шесть канонических действий в одной левой
  колонке; responsive tiers: 320×54, 340×56, 360×64, 380×76 и 380×96.
- Aspect-correct логотип и version label занимают отдельные непересекающиеся
  зоны в верхней левой части authored inner rect. Gratitude остаётся отдельной
  icon-only 64/72/88px кнопкой в правой верхней inner-зоне с принятым PixelLab
  asset, tooltip/accessibility, SFX и Credits callback.
- Все шесть действий явно закреплены за registered
  `text/main_menu_380x104`; пять 9-slice состояний сохраняют геометрию, а
  compact texture/content margins масштабируются пропорционально.
- Up/Down образует кольцо шести действий; Right с каждой строки ведёт к
  gratitude, её Left/Down возвращает к Start, Up — к Exit. Focus trap нет.
- Mockup-first package: `docs/design/mockups/scrum1059_main_menu_column/`;
  accepted-source preview: `docs/design/previews/scrum1059_main_menu_column/`.
  Пять planning reports: `ready_for_image`, `ok:true`, 0 errors/warnings.
- PixelLab provenance: reused SCRUM-981 gold-shell lineage
  `7d9c5262-5448-40c0-beaf-2b7d4b6b1f58` and SCRUM-1050 gratitude object
  `c1c1c353-e56e-405b-9adf-f1e6bd993152`; no new/fallback art.
- Green gates: focused five-view + live resize, SCRUM-981 gold shell,
  SCRUM-1051 semantic family, global no-overlap, title no-overlap, gamepad menu
  focus/full-flow, runtime UI and full `runtime_smoke_test.gd` all PASS.
- Windowed Metal matrix: Apple M4 Pro, 1152×648 / 1280×720 / 1600×900 /
  1920×1080 / 2560×1440 PASS; all labels fully readable, no scrollbar, frame
  ornament unobstructed. Transient captures are not committed.
- Independent read-only review: PASS, no actionable findings.
- Disk cleanup: transient `.godot`, `build/qa/scrum1059`, temporary HOME/XDG
  directories and unrelated generated `.gd.uid` sidecars removed before handoff.

## QA routing

Implementation complete; Jira must move to `Контроль качества` only after the
green commit is pushed to `origin/dev`. `Готово` requires independent QA PASS.
