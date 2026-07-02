# SCRUM-694 — Settings v3 live inventory (source-of-truth from code)

Extracted from `scripts/ui_screens.gd::_show_settings_menu()` and helpers
(`_make_settings_tab_switcher`, `_add_settings_control_row`, `_add_volume_row`,
`_settings_v2_*_rect`). Every visible element, runtime node name, text and state
that the v3 redraw must support. Verified against code on 2026-06-30.

## Containers / structure

| Node | Type | Role |
|---|---|---|
| `SettingsV2Root` | Control (full rect) | root, holds screen background |
| `SettingsV2Modal` | Control | modal positioned at `_settings_v2_modal_rect()` |
| `SettingsV2MainModalFrame` | PanelContainer | **main frame art** (9-slice StyleBoxTexture) |
| `SettingsV2Title` | Label `"Настройки"` | font 34, color (0.96,0.90,0.68) |
| `SettingsTabSwitcher` / `SettingsTabSwitcherFrame` | Control + Panel | **tab bar frame art** |
| `SettingsTabButton_0..2` | Button | tab buttons `Экран` / `Звук` / `Управление` |
| `SettingsTabs` | TabContainer (tabs_visible=false) | page host |
| `SettingsContentPanel` | Panel | **content panel art** (clip_contents) |
| `SettingsContentSafe` | MarginContainer | inner safe zone (18/14/18/14) |
| `SettingsBottomActions` | HBoxContainer | bottom action row |

## Page 1 — `Экран` (Screen)

| Element | Node | Text / states |
|---|---|---|
| Monitor select (multi-display only) | `SettingsScreenOption` (OptionButton) | items `Экран N (WxH)` |
| Resolution | `SettingsResolutionOption` (OptionButton) | items `WxH`, disabled if not fitting |
| Window mode | `SettingsWindowModeOption` (OptionButton) | `game.WINDOW_MODE_OPTIONS` |
| Camera shake | `ScreenShakeToggle` (CheckBox) + label `Тряска камеры` | on/off |
| Pending status | `SettingsPendingLabel` | `Есть непримененные изменения.` / `Экранные настройки применены.` |

Control row template: `_add_settings_control_row(box, title, control)` — left
title Label (≈220 wide) + right control. OptionButton min size **520×62**.

## Page 2 — `Звук` (Sound)

| Element | Node | States |
|---|---|---|
| Master volume | `VolumeSlider_master_volume` (HSlider) + percent label | 0–100 % |
| Music volume | `VolumeSlider_music_volume` + `VolumeToggle_music_enabled` (CheckBox) | slider + mute toggle |
| SFX volume | `VolumeSlider_sfx_volume` + `VolumeToggle_sfx_enabled` (CheckBox) | slider + mute toggle |
| Reset audio | `SettingsResetAudioButton` (Button) | `Сбросить звук по умолчанию`, 420 wide |

## Page 3 — `Управление` (Controls) — scrollable

Wrapped in `ControlsScroll` (ScrollContainer, vertical AUTO, follow_focus) →
`ControlsContent` (VBox, separation 14).

| Element | Node | States |
|---|---|---|
| Aim mode | `SettingsAimModeOption` (OptionButton) | `Автонаводка на ближайшего` / `По курсору` |
| Debug mode | `DebugModeToggle` (CheckBox) | `Вкл. (ПКМ / Shift+ЛКМ)` / `Выкл.` |
| Combat feedback | `CombatFeedbackToggle` (CheckBox) | `Вкл.` / `Выкл.` |
| Key binds (per `game.INPUT_ACTIONS`) | `BindingRow_<action>` + `BindingButton_<action>` | label + rebind button (420×62) |
| Hint | Label | `Клик по биндингу, затем нажми клавишу. Esc отменяет.` |
| Reset binds | `SettingsResetBindingsButton` (Button) | `Сбросить управление по умолчанию`, 560 wide |

## Bottom actions (all pages)

| Button | Node | States |
|---|---|---|
| Apply | `SettingsApplyButton` | `Применить`, disabled unless video dirty (240×72) |
| Revert | `SettingsRevertButton` | `Отменить`, disabled unless video dirty (240×72) |
| Back | `SettingsBackButton` | `Назад` (280×64) |

## Behaviour to preserve (runtime, not art)

- Video changes (screen/resolution/window mode) are **pending** until `Применить`;
  `Отменить` reverts pending; `_settings_video_dirty()` gates Apply/Revert disabled.
- Sound sliders, mute toggles, shake/debug/feedback persist live via `save_game_settings()`.
- Key rebind flow (`_begin_rebind`) + conflict handling intact; Esc cancels.
- Return origin: main menu vs run-pause (`SETTINGS_RETURN_MAIN_MENU` / `_RUN_PAUSE`).

## Distinct visual elements requiring v3 art

1. Main modal frame (9-slice) · 2. Tab switcher frame (9-slice) · 3. Tab button
active/inactive · 4. Content panel (9-slice) · 5. Dropdown/OptionButton field
(9-slice) · 6. Action button (9-slice family) · 7. Rebind button (9-slice) ·
8. Checkbox/toggle on+off · 9. Slider track (9-slice) + handle · 10. Scrollbar grabber.
