# UI Mockup Spec - Settings v2

Status: ready_for_integration
Role owner: Design
Task: docs/tasks/design_settings_rebuild_from_scratch_mockup_task.md
Jira: SCRUM-439
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: docs/design/mockups/scrum439_settings_v2/scrum439_settings_v2_mockup.png
Preview PNG: docs/design/previews/scrum439_settings_v2_safe_zones.png
Generated with: OpenAI Images API via fantasydisk-asset-generator

## Source Request

Completely redraw and re-spec the FantasyDisk settings window from scratch for
the three existing tabs: `Экран`, `Звук`, `Управление`. This Design pass
produces the visual mockup, transparent frame candidates and exact safe-zone
contract only; Back-end owns runtime rebuilding in `scripts/ui_screens.gd`.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| settings_dim | ColorRect | dimmed gameplay/menu backdrop | `Rect2(0,0,1920,1080)` | full rect | `1280x720` | 0 | default | viewport |
| settings_main_modal | NinePatchRect or proportional TextureRect | decorative Settings v2 frame | `Rect2(192,78,1536,924)` | center | `1024x616` | 5 | default | viewport |
| settings_main_content_safe | MarginContainer | all tab switcher + tab body content | `Rect2(336,250,1248,632)` | center scale with modal | `832x420` | 10 | default | settings_main_modal |
| settings_title_zone | Label container | live title/subtitle if retained | `Rect2(336,174,1248,48)` | top inside modal | `832x32` | 12 | default | settings_main_modal |
| SettingsTabSwitcher | TextureRect + Button hit zones | three-tab switcher art | `Rect2(520,126,880,176)` | top center inside modal | `640x128` | 20 | default/selected/focus | settings_main_modal |
| SettingsTabButton_0 | Button | `Экран` tab label/click | `Rect2(623,180,189,63)` | source-scaled slot | `126x42` | 25 | normal/hover/pressed/focus/selected | SettingsTabSwitcher |
| SettingsTabButton_1 | Button | `Звук` tab label/click | `Rect2(865,180,189,63)` | source-scaled slot | `126x42` | 25 | normal/hover/pressed/focus/selected | SettingsTabSwitcher |
| SettingsTabButton_2 | Button | `Управление` tab label/click | `Rect2(1107,180,189,63)` | source-scaled slot | `126x42` | 25 | normal/hover/pressed/focus/selected | SettingsTabSwitcher |
| SettingsTabs | TabContainer | hidden built-in headers; 3 pages | `Rect2(360,320,1200,520)` | fill content safe width | `840x300` | 15 | screen/audio/controls | settings_main_content_safe |
| screen_tab_grid | VBox/Grid | monitor, resolution, window mode, camera shake | `Rect2(420,350,1080,430)` | fill tab body | `760x260` | 20 | enabled/disabled | SettingsTabs |
| SettingsScreenOption | OptionButton | monitor selector when multiple screens | `Rect2(780,350,620,58)` | row right | `420x54` | 25 | normal/hover/focus/disabled | screen_tab_grid |
| SettingsResolutionOption | OptionButton | resolution list with disabled too-large values | `Rect2(780,426,620,58)` | row right | `420x54` | 25 | normal/hover/focus/disabled | screen_tab_grid |
| SettingsWindowModeOption | OptionButton | window mode selector | `Rect2(780,502,620,58)` | row right | `420x54` | 25 | normal/hover/focus/disabled | screen_tab_grid |
| ScreenShakeToggle | CheckBox | camera shake on/off | `Rect2(1180,594,160,50)` | row right | `128x42` | 25 | checked/unchecked/focus | screen_tab_grid |
| audio_tab_grid | VBox/Grid | three volume rows, toggles, reset | `Rect2(420,350,1080,430)` | fill tab body | `760x260` | 20 | enabled/disabled | SettingsTabs |
| VolumeSlider_master_volume | HSlider | master volume `0..100`, step 2 | `Rect2(660,362,560,48)` | row center expand | `420x42` | 25 | normal/focus/disabled | audio_tab_grid |
| VolumeSlider_music_volume | HSlider | music volume `0..100`, step 2 | `Rect2(660,438,560,48)` | row center expand | `420x42` | 25 | normal/focus/disabled | audio_tab_grid |
| VolumeSlider_sfx_volume | HSlider | SFX volume `0..100`, step 2 | `Rect2(660,514,560,48)` | row center expand | `420x42` | 25 | normal/focus/disabled | audio_tab_grid |
| VolumeToggle_music_enabled | CheckBox | music on/off | `Rect2(1290,438,132,48)` | row right | `108x42` | 25 | checked/unchecked/focus | audio_tab_grid |
| VolumeToggle_sfx_enabled | CheckBox | SFX on/off | `Rect2(1290,514,132,48)` | row right | `108x42` | 25 | checked/unchecked/focus | audio_tab_grid |
| SettingsResetAudioButton | Button | reset audio defaults | `Rect2(750,686,420,72)` | bottom center | `360x64` | 25 | normal/hover/pressed/focus/disabled | audio_tab_grid |
| controls_tab_grid | VBox | aim mode, debug, bindings scroll, reset | `Rect2(420,350,1080,430)` | fill tab body | `760x260` | 20 | enabled/disabled | SettingsTabs |
| SettingsAimModeOption | OptionButton | nearest/cursor aim mode | `Rect2(780,350,620,58)` | row right | `420x54` | 25 | normal/hover/focus | controls_tab_grid |
| DebugModeToggle | CheckBox | debug mode on/off with tooltip | `Rect2(780,426,360,50)` | row right | `300x42` | 25 | checked/unchecked/focus | controls_tab_grid |
| ControlsScroll | ScrollContainer | movement/pause/ultimate rebind rows | `Rect2(520,502,880,236)` | fill remaining body | `620x170` | 25 | scroll/focus | controls_tab_grid |
| BindingButton_* | Button | per-action binding value | `Rect2(835,0,420,58)` inside each scroll row | row right expand | `360x54` | 30 | normal/hover/pressed/focus/rebinding | ControlsScroll |
| SettingsResetBindingsButton | Button | reset bindings defaults | `Rect2(740,766,440,72)` | bottom center | `360x64` | 25 | normal/hover/pressed/focus/disabled | controls_tab_grid |
| SettingsBackButton | Button | back to pause/main menu | `Rect2(820,884,280,64)` | bottom center inside modal | `220x56` | 25 | normal/hover/pressed/focus | settings_main_modal |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| settings_main_modal | assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_main_modal.png | `1536x1024` | `L96 T118 R96 B96` | `L144 T192 R144 B128` | corner claws, ruby sockets, top dragon crest, side leather columns, bottom metal rail | yes, tile center only |
| settings_tab_switcher_3slot | assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_tab_switcher_3slot.png | `1280x256` | `L120 T56 R120 B56` | slot rects: `Rect2(150,78,275,92)`, `Rect2(502,78,275,92)`, `Rect2(854,78,275,92)` | outer gems, vertical dividers, top/bottom rails | no, draw proportional whole image |
| settings_section_panel | assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_section_panel.png | `1024x384` | `L76 T76 R76 B76` | `L104 T96 R104 B92` | corner gems, bevels, middle rail ornaments | yes |
| settings_control_row | assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_control_row.png | `1536x192` | `L72 T42 R72 B42` | `L96 T54 R96 B54` | side gems, upper/lower rails, center rivets | yes |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| settings_v2_mockup | docs/design/mockups/scrum439_settings_v2/scrum439_settings_v2_mockup.png | OpenAI design board covering all three tabs | `1920x1088` | opaque reference | n/a | see preview overlay | crop top `1920x1080` for base geometry |
| settings_v2_safe_zones | docs/design/previews/scrum439_settings_v2_safe_zones.png | annotated safe-zone preview | `1920x1080` | opaque preview | n/a | n/a | blue window safe, yellow tab slots, green panel safe zones |
| settings_v2_assets_contact | docs/design/previews/scrum439_settings_v2_assets_contact.png | transparent asset contact sheet | `1800x1200` | opaque preview | n/a | n/a | shows final candidates over dark checker |
| settings_v2_main_modal | assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_main_modal.png | modal/window frame | `1536x1024` | RGBA | `96/118/96/96` | `144/192/144/128` | source alpha-cleaned from OpenAI frame |
| settings_v2_tab_switcher | assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_tab_switcher_3slot.png | three-slot tab switcher candidate | `1280x256` | RGBA | `120/56/120/56` | per-slot safe rects | exactly 3 hit zones; no fourth slot |
| settings_v2_section_panel | assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_section_panel.png | nested tab content panel | `1024x384` | RGBA | `76/76/76/76` | `104/96/104/92` | optional if Back-end uses section panels |
| settings_v2_control_row | assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_control_row.png | dropdown/rebind/slider row background | `1536x192` | RGBA | `72/42/72/42` | `96/54/96/54` | optional for consistent rows |

Source references:

- docs/design/references/settings_v2/scrum439_settings_v2_mockup.png
- docs/design/references/settings_v2/scrum439_settings_v2_main_modal_frame_source.png
- docs/design/references/settings_v2/scrum439_settings_v2_frame_kit_source.png
- docs/design/references/settings_v2/scrum439_settings_v2_main_modal_frame_alpha_clean.png
- docs/design/references/settings_v2/scrum439_settings_v2_frame_kit_alpha_clean.png
- docs/design/references/settings_v2/scrum439_settings_v2_metadata.json

## Responsive Rules

- 1280x720: draw the main modal at `1024x616`, centered at
  `Rect2(128,52,1024,616)`. Content safe rect becomes
  `Rect2(224,167,832,424)`. Draw the tab switcher at `640x128`, centered near
  `Rect2(320,84,640,128)`. Minimum control row height is `54`; ControlsScroll
  must keep at least `170px` visible height and become the only scrollable area.
- 1920x1080: draw the main modal at `1536x924` or source-height clamped
  equivalent, centered at `Rect2(192,78,1536,924)`. Keep `144px` left/right
  modal content margins, `192px` top content margin, `128px` bottom reserve.
  Settings body width should be `1200px`; row label column `240..300px`;
  control column expands to `560..620px`.
- 2560x1440: draw the main modal at `2048x1232`, centered at
  `Rect2(256,104,2048,1232)`. Scale source-space margins by `1.333`. Keep row
  heights capped (`58..72px`) so the layout reads as a dense settings surface,
  not a hero menu. ControlsScroll may grow vertically but rebind rows keep stable
  fixed height.

Across all targets:

- `SettingsTabButton_0..2` must be computed from source safe rects. Do not add
  `SettingsTabButton_3`.
- Do not scale font size with viewport width; use existing project font sizes
  with responsive container sizes.
- Keep the `Управление` page scrollable. The outer settings modal must not
  scroll.
- The tab switcher is a proportional whole-image texture. Do not stretch it on
  one axis.
- Text, checkbox icons, slider handles, dropdown arrows, focus rings and button
  labels must stay inside their safe parent rectangles, never on frame ornament.

## Interaction States

- Tab slot default: transparent/neutral label over empty slot.
- Tab slot selected/focus: red-gold selected fill or StyleBox overlay inside the
  slot safe rect only; no glow on dividers or gems.
- OptionButton/rebind rows: default, hover/focus, pressed and disabled states use
  red/gold button styling inside `settings_control_row` content margins.
- Sliders: track stays inside the row content zone; handle may not cross the
  row's side gems or metal caps.
- Checkboxes/toggles: icon + label sit inside row content zone. Runtime Russian
  text `Вкл.`/`Выкл.` must not sit on row borders.
- ControlsScroll: scrollbar lives inside the controls panel safe rect and must
  not overlap the outer frame or tab switcher.
- Reset/back buttons: use existing Red & Gold Dragon button family unless Back-
  end intentionally swaps to a new matching state sheet later.

## Implementation Notes

- Godot scene: rebuild `_show_settings_menu()` layout in
  `scripts/ui_screens.gd` in the Back-end pass.
- Preserve existing runtime semantics:
  `SettingsTabs`, `SettingsTabSwitcher`, `SettingsTabButton_0..2`,
  `SettingsScreenOption`, `SettingsResolutionOption`,
  `SettingsWindowModeOption`, `ScreenShakeToggle`, `VolumeSlider_*`,
  `VolumeToggle_*`, `SettingsAimModeOption`, `DebugModeToggle`,
  `ControlsScroll`, `BindingButton_*`, `SettingsResetAudioButton`,
  `SettingsResetBindingsButton`.
- Keep `scripts/game_settings.gd` persistence behavior unchanged.
- Candidate frame assets live under `assets/sprites/ui/frames/settings_v2/`.
  They are not wired in this Design pass.
- Use `NinePatchRect`/`StyleBoxTexture` for `settings_main_modal`,
  `settings_section_panel` and `settings_control_row` only if texture margins
  above are honored. Otherwise draw proportional whole-image frames with content
  containers derived from source-space safe zones.
- The generated frame sources arrived with baked checkerboard and were alpha-
  cleaned into RGBA candidates. Back-end should use the `assets/` files, not the
  raw source PNGs.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every new frame has texture margins and content margins.
- [x] No UI content is allowed on frame border, ornament, gem, metal or dragon
  decoration.
- [x] Runtime content zones specified for 1280x720, 1920x1080 and 2560x1440.
- [x] Hover/focus/pressed/disabled states specified not to resize or shift
  layout.
- [ ] Screenshot comparison completed after implementation.
- [ ] Back-end no-overlap matrix completed after implementation.
- [ ] Task/Jira updated when applicable.

## Deviations

- This is a Design-only first pass. Runtime Settings rebuilding, screenshots
  from Godot, smoke tests and no-overlap matrix are intentionally left to the
  Back-end integration follow-up.
- The OpenAI mockup is a design board showing all three tabs at once so the PM
  and Back-end can review the full Settings v2 visual system in one PNG. Runtime
  remains a single active tab at a time.
