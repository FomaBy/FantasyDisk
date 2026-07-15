# UI Mockup Spec — Settings Game Updater

Status: ready_for_integration

Role owner: Back-end integration using accepted existing UI art

Task: FAN-1112

Base resolution: 2560x1440

Responsive targets: 1280x720, 1920x1080, 2560x1440

Mockups: `settings_update_mockup.png`, `update_prompt_mockup.png`

Generators: background=existing; non-background UI=existing
Source paths: `build/qa/scrum1053/settings_tab0_2560x1440.png`, global FantasyDisk action/modal kit

## Source Request

Add a manual `Обновить игру` action to Settings and a startup update prompt without redesigning the accepted Atlas-family Settings shell.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `SettingsUpdateButton` | Button | manual update check | `508,1138,280,64` | footer left | `280x64` | content | normal/hover/pressed/focus/disabled | `SettingsBottomActionsSafe` |
| `UpdatePromptPanel` | PanelContainer | version, status, install guidance | `720,410,1120,620` | center | `680x420` | 501 | available/downloading/verified/error/current | viewport overlay |
| `UpdateInstallButton` | Button | download, verify, open installer | `866,842,420,88` | modal bottom | `420x72` | 502 | normal/busy/disabled | prompt panel |
| `UpdateLaterButton` | Button | dismiss | `1310,842,280,88` | modal bottom | `280x72` | 502 | normal/focus | prompt panel |

## Frames And Safe Zones

| Frame ID | Asset path | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- |
| Settings outer shell | existing unified `frame_border` | existing metadata | existing `SettingsSafeArea` | complete gold outer ornament | existing contract |
| footer action plate | existing global `280x64` Settings action | existing runtime metadata | label inside native flat field | dragon/corner/bevel ornament | yes |
| update modal | existing `_atlas_chip_style` | 20px visual border | 40px reserve | border and rounded brass edge | native scalable style |

No generated layer is introduced. This is an explicit existing-source reuse: the change adds behavior and one label-only control, so a new PixelLab button or OpenAI background would create an unnecessary visual fork from the accepted Settings family.

## Responsive Rules

- 1280x720: footer remains `960x64` plus the existing 24px bottom ornament reserve. Three `280x64` actions plus two 14px gaps fit in 868px; an expanding spacer separates Update from Revert/Apply.
- 1920x1080: footer is 1158px wide; update stays left and Revert/Apply stay right.
- 2560x1440: footer is 1544px wide; exact mockup rect is recorded in `layout.json`.
- The prompt uses a centered clamped panel. Text wraps inside a minimum 40px content reserve, and buttons reflow without touching the panel border.
- The Game tab keeps its existing hidden footer contract; Update is available from Screen, Sound, and Controls.

## Interaction States

- Manual check: the modal opens immediately in checking state with its primary
  action disabled; the overlay blocks repeated Settings interaction.
- Up to date: prompt shows the installed version and a single Close action.
- Update available: primary action is `Скачать и установить`; secondary action is `Позже`.
- Downloading/verifying: primary action remains disabled and status text changes without resizing the panel.
- Offline/error: startup check is silent; a manual check shows a retryable message and GitHub Releases fallback.
- Focus: modal focus is trapped between its visible actions; Escape/B closes without changing Settings state.

## Implementation Notes

- Runtime: `scripts/ui_screens.gd`, `scripts/main.gd`, `scripts/update_manager.gd`.
- Keep update networking outside `_process`; `HTTPRequest` completion signals own the lifecycle.
- Keep installer execution explicit and platform-gated. Verify the downloaded file SHA-256 before opening it.
- Do not replace the running executable in place: open the signed DMG on macOS or the signed setup executable on Windows.

## Acceptance Checks

- [x] Mockup/spec created before runtime UI edits.
- [x] Existing visual sources are declared; no generated layer is misrouted.
- [x] Footer and modal content zones include reserves beyond visual borders.
- [x] Metal runtime screenshots match the responsive geometry at 1280x720,
  1920x1080, and 2560x1440 (`build/qa/fan1112/update_prompt_*.png`).
- [x] All update states keep stable button/panel geometry.
- [x] Keyboard/gamepad focus and Escape dismissal pass.
- [x] No content overlaps the Settings outer frame or modal border.

## Deviations

The mockup uses a captured Settings Screen page as its base and overlays only the new action/prompt. Runtime reuses exact existing button and modal styles rather than promoting the vector overlay as a game asset.
