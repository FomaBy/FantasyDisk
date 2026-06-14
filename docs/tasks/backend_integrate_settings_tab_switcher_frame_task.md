# Задача Для Back-end-Агента: Подключить Settings Tab Switcher Frame

Статус: done
Приоритет: medium
Роль: Back-end
Версия: 0.1.5
Jira: SCRUM-334
Создано: 2026-06-14
Источник: SCRUM-325 / `design_integrate_generated_settings_tab_switcher_frame_task.md`

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках задачи. Подтверждение не
спрашивать; если integration невозможна без дополнительных state assets, вернуть
конкретный handoff в Design.

## Контекст

Design подготовил production PNG для нового settings tab switcher в стиле
D&D + Dark Fantasy. Это visual asset only; Design не меняет `TabContainer`
runtime/theme mapping.

## Что Уже Сделано

- Production asset:
  `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png`
  (`1280x256`, RGBA, transparent, no baked text).
- Source/reference:
  `docs/design/references/settings_tab_switcher_frame/settings_tab_switcher_frame_reference.png`
  and
  `docs/design/references/settings_tab_switcher_frame/settings_tab_switcher_frame_transparent.png`.
- Preview:
  `docs/design/previews/settings_tab_switcher_frame_preview.png`.
- Content-zone overlay:
  `docs/design/previews/settings_tab_switcher_frame_content_zone.png`.

## Что Нужно От Back-end

1. Подключить новый visual tab switcher к экрану настроек
   `scripts/ui_screens.gd::_show_settings_menu()` / `SettingsTabs`, не меняя
   gameplay/settings persistence.
2. Не класть runtime labels, icons, click zones или focus rings на декоративный
   металл, самоцветы, углы, стрелки или нижний кант.
3. Сохранить функциональность вкладок `Экран`, `Звук`, `Управление`, keyboard
   focus, hover/click, Escape/back.
4. Если текущий full-strip PNG недостаточен для корректного динамического
   active-tab state, создать Design handoff на дополнительные sliced state
   assets (`active`, `inactive`, `hover`, `pressed`, `disabled`) вместо
   технической имитации поверх орнамента.
5. Прогнать UI/no-overlap/settings smoke на 1152x648, 1280x720, 1600x900,
   2560x1440.

## Files / Assets / IDs

Asset ID:
- `ui_frame_settings_tab_switcher`

Production PNG:
- `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png`

Recommended whole-image scale:
- Use proportional scaling only. Do not stretch the strip along one axis.
- Base size: `1280x256`.

Safe label/click zones in base asset coordinates:

| Slot | Rect2(x, y, w, h) | Notes |
| --- | --- | --- |
| `tab_0_active_safe` | `Rect2(146, 78, 178, 82)` | Inside red active tab, avoids left lightning, top gem and borders |
| `tab_1_safe` | `Rect2(414, 91, 178, 74)` | Inside inactive tab, avoids top gem and bevels |
| `tab_2_safe` | `Rect2(693, 91, 178, 74)` | Inside inactive tab, avoids top gem and bevels |
| `tab_3_safe` | `Rect2(969, 91, 162, 74)` | Inside inactive tab, avoids right arrow ornament |

Only these safe rects should receive text/click hit areas unless Back-end
derives stricter scaled rects. Decorative borders/corners/jewels/spikes remain
unobstructed.

Relevant code:
- `scripts/ui_screens.gd` (`_show_settings_menu`, `SettingsTabs`)
- `scripts/ui/ui_theme_paths.gd` if theme mappings are added
- `tests/runtime_smoke_ui_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`

## Acceptance Criteria

- [ ] Settings screen uses the new tab switcher visual or records a precise
  Design blocker for missing per-state assets.
- [ ] Labels/click/focus zones sit only inside the recorded safe rects and do
  not cover metal/gems/arrows/borders.
- [ ] Tab switching still works for `Экран`, `Звук`, `Управление`.
- [ ] No overlap/regression on 1152x648 / 1280x720 / 1600x900 / 2560x1440.
- [ ] UI smoke and no-overlap tests pass.
- [ ] Docs updated if runtime integration changes settings layout/theme.

## Документация

Update `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`
and `CHANGELOG.md` after runtime integration.

## Result / Summary
- Подключен production `ui_frame_settings_tab_switcher.png` к экрану настроек как `SettingsTabSwitcher` с proportional 5:1 scaling (`640x128`) без one-axis stretch.
- Built-in headers у `SettingsTabs` скрыты; `SettingsTabButton_0..2` переключают страницы «Экран», «Звук», «Управление» и лежат строго в scaled safe rects `tab_0_active_safe`, `tab_1_safe`, `tab_2_safe`.
- Hover/focus/click состояния реализованы только внутри safe rects; декоративный металл, самоцветы, стрелки и кант не используются под runtime labels или hit zones. Четвертый safe slot остается пустым/decorative до появления четвертой вкладки.
- Дополнительно восстановлен `HeroSelectPortraitPanel` expand/stretch ratio 1.0, чтобы SCRUM-333 master layout снова реально давал 1/3 portrait + 2/3 right region на целевых разрешениях.
- Verification: `runtime_smoke_ui_test.gd` PASS, `ui_no_overlap_matrix_test.gd` PASS, `runtime_smoke_test.gd` PASS; Hero Select QA rect dump refreshed.
