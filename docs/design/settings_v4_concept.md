# Settings v4 — концепт-решение (A vs B) + целевая геометрия

SCRUM-805, фаза 4. Опирается на [аудит](settings_v4_audit.md),
[референс-принципы](settings_v4_reference_principles.md) и мокапы в
`docs/design/references/settings_v4/`. Дата: 2026-07-02.

## Решение: гибрид с упором на B (перерисовка элементов)

| Вариант | Суть | Вердикт |
|---|---|---|
| A | Цельный сгенерённый арт как background + нативные контролы в safe-зонах | Отклонён как основа: цельная картинка при любом ресайзе либо растягивается (мыло), либо контролы «плывут» относительно нарисованных полей; трудно гарантировать «ноль пересечений» и точную ширину |
| **B (выбран, гибрид)** | **Панель/рамка — 9-slice с валидными margins; КАЖДЫЙ интерактивный элемент — отдельный ассет в ТОЧНОМ финальном размере с 3 состояниями** | Соответствует направлению PM. Даёт фикс. ширины (P3), выровненную сетку (P2), нерастянутые ассеты (P9), явные состояния (P8) |

Гибрид = рамки и панели допускаются фоном (9-slice, углы/орнамент не искажаются),
но все кнопки/дропдауны/слайдеры/чекбоксы — отдельные спрайты в нативном размере.
Никакой контент НЕ ложится на орнамент рамки (safe-area rule, AGENTS.md/qa_protocol).

## Мокапы-референсы (утверждённая раскладка)

- `references/settings_v4/mockup_tab_screen.png` — вкладка «Экран».
- `references/settings_v4/mockup_tab_sound.png` — вкладка «Звук».
- `references/settings_v4/mockup_tab_controls.png` — вкладка «Управление».
- `references/settings_v4/mockup_button_states.png` — лист состояний
  (Tab / Dropdown / Action / Keybind / Checkbox / Slider × normal/hover/pressed).

Мокапы подтверждают: ~55–60% ширины экрана, две колонки `label | control`,
дропдауны/слайдеры фикс. ширины (не на весь ряд), Apply/Revert/Back внизу.

## Целевой габарит модалки (замена 80%-й)

- **Ширина** = `clamp(round(viewport.x * 0.56), 960, 1536)`.
- **Высота** = `round(width / 1.6)` (пропорция мокапов), cap 88% высоты вьюпорта.
- @1920×1080 → **1075×672** (56% ширины, 62% высоты).
- @2560×1440 → **1434×896** (56% ширины, 62% высоты).
- Арт рамки v4 рисуется в нативе ~**1536×960** и НИКОГДА не апскейлится
  (на 2К даунскейл, на 1080p ещё сильнее — резко); либо честный 9-slice
  с margins, углы/орнамент без искажения (P9).

## Целевая геометрия элементов (точный финальный размер @2560×1440)

Все размеры — «native px» ассета (на 1080p — пропорциональный даунскейл ×0.75).

| Элемент | Размер @2560 (px) | Состояния | Прим. |
|---|---|---|---|
| Свитчер: tab-кнопка ×3 | 300×72 (gap 24) | normal/hover/pressed × (active/idle) | активная — золотая |
| Метка (колонка label) | ширина 320, высота ряда 64 | — | правый край выровнен |
| Dropdown-поле (OptionButton) | **460×64** | normal/hover/pressed | стрелка справа; **без EXPAND_FILL** |
| Слайдер-трек | **380×36** | normal/hover/pressed | грабер 44×44 |
| Value-label (%) | 72×64 | — | золотой |
| On/Off тоггл | 132×56 | normal/hover/pressed | — |
| Checkbox | 44×44 | unchecked/checked × normal/hover/pressed | — |
| Keybind-кнопка | **300×60** | normal/hover/pressed/awaiting | «W»/«Space» |
| Action-кнопка (Apply/Revert) | **260×72** | normal/hover/pressed/disabled/focus | — |
| Кнопка «Назад» | 300×72 | те же | — |
| Reset-кнопка (звук/управление) | 360×64 | те же | НЕ на всю ширину |

Инвариант: **ширина любого контрола ≤ 55% ширины контент-зоны**; единая
двухколоночная сетка (label 320 | control ≤460), шаг ряда 64, вертикальный
интервал 18–20 px. Эфф. кегль метки ≥ 16 px @1080p (P5).

## Список ассетов для фазы 5 (`assets/sprites/ui/frames/settings_v4/`)

1. `settings_v4_main_modal` — 9-slice рамка модалки (валидные margins).
2. `settings_v4_tab_button` — состояния таб-кнопки (active/idle × n/h/p).
3. `settings_v4_dropdown_field` (+ arrow) — n/h/p.
4. `settings_v4_action_button` — n/h/p/disabled/focus.
5. `settings_v4_keybind_button` — n/h/p/awaiting.
6. `settings_v4_checkbox` — unchecked/checked × n/h/p.
7. `settings_v4_slider_track` + `settings_v4_slider_grabber` — n/h/p.
8. `settings_v4_toggle_onoff` — n/h/p.

Прозрачный фон; при запечённом checkerboard/сером фоне — border-connected
flood-fill alpha-cleanup (numpy+PIL), НЕ регенерация. PNG + .import в git.

## Внедрение (фаза 6, `scripts/ui_screens.gd` settings-блок)

- Новый габарит модалки (формула выше) вместо 0.80.
- Убрать `SIZE_EXPAND_FILL` у всех OptionButton'ов → фикс. 460.
- Единая сетка `label|control` (заменить `_add_settings_control_row` на
  двухколоночную с фикс. шириной контрола; убрать FILL-растяжение reset-кнопок).
- Пути-константы v4, стили состояний из ассетов v4.
- Другие блоки `ui_screens.gd` НЕ трогать.

## Верификация (фаза 7)

`ui_no_overlap_matrix` (1920/2560/3840) + game_settings/video_settings_apply/
aim_mode_settings/runtime_smoke_ui через `tools/godot_gate.py`; оконные
скриншоты 3 вкладок @1920 и @2560; `settings_v4_verification.md` — пункт×вердикт.
