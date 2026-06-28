# SCRUM-657 UI Text Button Size Audit

Status: design package ready for QA.

Accepted action text buttons: **40**.
Accepted unique display sizes: **13** plus **2** optional expanded long-label variants.
Scenes scan: no additional `.tscn` Button/TextureButton text nodes found in `scenes/**/*.tscn` for this checkout.
Runtime integration files were audited but not edited. Active SCRUM-562 weapon-select runtime scope was left untouched.

## Accepted Unique Sizes

| Group | Size | Count | Examples | Decision |
| --- | ---: | ---: | --- | --- |
| `main_menu_380x104` | 380x104 | 6 | MainMenuStartButton, MainMenuSettingsButton, MainMenuPatchNotesButton | accepted exact-size family |
| `standard_420x104` | 420x104 | 5 | AttributeRerollButton, AttributeSkipButton, VictoryNewRunButton | accepted exact-size family |
| `wide_440x104` | 440x104 | 1 | SettingsResetBindingsButton | accepted exact-size family |
| `back_260x104` | 260x104 | 2 | SkillTreeBackButton, PatchNotesBackButton | accepted exact-size family |
| `quit_220x72` | 220x72 | 2 | QuitConfirmExitButton, QuitConfirmCancelButton | accepted exact-size family |
| `continue_240x72` | 240x72 | 2 | ContinueRunButton, ContinueRunNewGameButton | accepted exact-size family |
| `later_260x72` | 260x72 | 1 | LevelUpLaterButton | accepted exact-size family |
| `settings_back_280x64` | 280x64 | 1 | SettingsBackButton | accepted exact-size family |
| `feedback_260x64` | 260x64 | 1 | FeedbackSendButton | accepted exact-size family |
| `feedback_cancel_220x64` | 220x64 | 1 | FeedbackCancelButton | accepted exact-size family |
| `pause_280x60` | 280x60 | 5 | RunPauseContinueButton, RunPauseDossierButton, RunPauseSettingsButton | accepted exact-size family |
| `event_back_380x54` | 380x54 | 1 | EventBackButton | accepted exact-size family |
| `rebind_420x62` | 420x62 | 12 | Settings control rebind buttons, OptionButton-like controls, key binding rows | accepted exact-size family |

## Exclusions

| Group | Reason |
| --- | --- |
| Hero carousel thumbnails / TextureButton slots | icon/portrait card hit areas; not text buttons; child labels are adjacent/inside carousel content and use authored HS4 frame contract |
| Weapon select cards | active SCRUM-562 overlap; cards intentionally use card/text-field styling, not action button kit |
| Shop item buttons | icon/product hit areas on shop backdrop; no text label on button body |
| Reward, elite artifact, level-up reward, event, attribute offer cards | full-card information choices with child labels; excluded from text-button kit to avoid squeezing paragraphs into button frames |
| Progression nodes / skill tree circular buttons | circular node frames; text belongs outside/tooltip, not a rectangular action button |
| Combat LevelUpPlusButton / UpgradeFabButton / ascension +/- / carousel arrows | icon/symbol-only controls; need icon/square/FAB family, not text-button family |
| Glossary term underline buttons | inline text affordances; visual state is underline/tooltip, not framed text button |

## Generated Package

- OpenAI sources: original family reference `docs/design/references/ui_text_buttons_unique_size_redraw/scrum657_text_button_family_reference.png` plus 15 per-size source PNGs in `docs/design/references/ui_text_buttons_unique_size_redraw/per_size_sources/`.
- Runtime exact-size PNGs: `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_<group>_<state>.png`.
- States: `normal`, `hover`, `pressed`, `focus`, `disabled`.
- Metadata/safe zones: `docs/design/references/ui_text_buttons_unique_size_redraw/button_family_metadata.json`.
- Alpha audit: `docs/design/references/ui_text_buttons_unique_size_redraw/alpha_audit.json` passes 75/75 transparent-corner checks.
- Text fit report: `docs/design/references/ui_text_buttons_unique_size_redraw/button_text_fit_report.json`.
- Contact sheets: `docs/design/previews/scrum_text_buttons_unique_size_dark_contact.png`, `docs/design/previews/scrum_text_buttons_unique_size_light_contact.png`.

## Safe Zone Contract

Runtime text is external and must use the `content_rect_xywh` in `button_family_metadata.json`. The decorative scale caps, claws, bevel rails, ruby pins and focus glow are ornament. Content margins are intentionally larger than texture margins on narrow buttons; if Back-end later converts any exact PNG to StyleBoxTexture, only the dark center may stretch.

Each of the 15 size groups has its own OpenAI-generated source button. Final runtime PNGs are not a single stretched master; they are exact-size exports rebuilt from the matching per-size source so each proportion has its own authored ornament rhythm.

Side-cap rule: the left/right decorative shutters are fixed-size ornaments per button height and must never be horizontally squeezed or stretched. The package composes each button as fixed left cap + stretchable center rail + fixed right cap; only the center rail may change width. If a label needs more room, increase the whole button width by extending the center, not by scaling the caps.

## Text Fit Rule

Before runtime implementation assigns a texture, measure the localized label. The label must fit inside the central content field between the decorative end shutters/caps. Use:

`button_width = max(audited_width, measured_text_width + left_content_margin + right_content_margin + 24px reserve)`

If a label does not fit, increase the button width or use an expanded variant. Do not shrink text onto claws, ruby pins, bevels or scale caps. The package includes optional `reset_bindings_long_560x104` and `continue_run_long_420x72` variants for long Russian labels.
