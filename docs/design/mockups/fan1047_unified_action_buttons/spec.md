# UI Mockup Spec — FAN-1047 Unified Codex And Dossier Actions

Status: implemented_and_verified
Role owner: Design source reuse → Back-end integration
Task: `docs/tasks/FAN-1047.md`
Multica: FAN-1047
Base resolution: 1920×1080
Responsive targets: 1152×648, 1280×720, 1600×900, 1920×1080, 2560×1440
PixelLab UI-kit preview: `docs/design/previews/scrum1050_ui_unification_reference_sheet_688x384.png`
PixelLab dossier preview: `docs/design/references/scrum983_escape_dossier/pixellab_escape_dossier_v1_688x384.png`
Generated with: accepted PixelLab MCP source reuse; dossier asset ID `ccc0e262-f062-4eb3-90d5-71c68c7db203`; no new art generation.

## Source Request

Use the same buttons as the Main Menu for the six Codex navigation actions and
the four Escape hero-dossier actions. Remove the old yellow Codex exception and
stop squeezing the 380×104 Main Menu source into clipped arbitrary rectangles.

## Runtime Asset Contract

All ten controls reuse `text/main_menu_380x104`:

- normal: `ui_btn_text_unique_main_menu_380x104_normal.png`;
- hover: `..._hover.png`;
- pressed: `..._pressed.png`;
- focus: `..._focus.png`;
- disabled: `..._disabled.png`.

Source aspect is `380/104 = 3.653846`. Runtime rectangles must stay within 2%
of that ratio. Source texture margins are `L54/T21/R54/B21`; content margins
are `L69/T21/R69/B21`. Margins scale by the same uniform factor as the target
button. Ornament and label zones may not be cropped independently.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920×1080 | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- |
| `CodexTab_characters` | Button | Персонажи | `0,24,260,72` in `CodexTabs` | five states + selected modulation | `CodexNavPanel` |
| `CodexTab_monsters` | Button | Монстры | `0,142,260,72` | five states | `CodexNavPanel` |
| `CodexTab_artifacts` | Button | Артефакты | `0,260,260,72` | five states | `CodexNavPanel` |
| `CodexTab_characteristics` | Button | Параметры | `0,378,260,72` | five states | `CodexNavPanel` |
| `CodexTab_attributes` | Button | Атрибуты | `0,496,260,72` | five states | `CodexNavPanel` |
| `CodexTab_ascension` | Button | Возвыш. | `0,614,260,72` | five states | `CodexNavPanel` |
| `PauseResumeButton` | Button | Продолжить | `296,787,320,88` | five states | dossier inner rect |
| `PauseSettingsButton` | Button | Настройки | `632,787,320,88` | five states | dossier inner rect |
| `PauseEndRunButton` | Button | Завершить забег | `968,787,320,88` | five states | dossier inner rect |
| `PauseMainMenuButton` | Button | Главное меню | `1304,787,320,88` | five states | dossier inner rect |

Codex rectangles above are local to `CodexTabs` in the 1920×1080
`CodexStage`: `0,24 + index×118,260,72`. The complete control
stays inside the nav-panel empty interior. Runtime labels remain outside baked
art and use the existing semantic tab font.

## Escape Dossier Responsive Rules

- 1152×648: right action rail, target `219×60`, gap `6`; four actions stack
  vertically inside the dossier body. Hero and derived columns retain their
  documented minimum content heights and the rail stays inside the inner rect.
- 1280×720: right action rail, target `263×72`, gap `8`.
- 1600×900: right action rail, target `263×72`, gap `10`.
- 1920×1080: horizontal footer, target `320×88`, gap `16`.
- 2560×1440: horizontal footer, exact target `380×104`, gap `20`; first button
  starts at x=490 and the remaining buttons at x=890/1290/1690.

For compact targets the body topology is `hero | derived | action rail`; there
is no separate bottom footer consuming dossier height. At 1080p/2K the topology
remains `hero | derived` plus a horizontal footer. Resize recomputes topology
without recreating the screen.

## Frames And Safe Zones

| Frame | Texture margins | Content reserve | Forbidden zones |
| --- | --- | --- | --- |
| CodexNavPanel | existing panel geometry | existing 32/38/32/50 plus tab local gap | panel border and corners |
| Escape gold shell | 160 source px scaled per viewport | 24px compact/1080p; 32px 2K | all gold rails, dragons, gems and corner ornament |
| Main Menu action plate | scaled `54/21/54/21` | scaled `69/21/69/21` | button caps and bevel ornaments |

## Interaction States

- Hover/focus use their dedicated generated texture; no yellow procedural ring.
- Pressed/disabled use their dedicated generated texture.
- Selection in Codex may modulate the full button but may not change its rect,
  margins or font allocation.
- Initial and directional focus behavior remains unchanged.

## Acceptance Checks

- [x] PixelLab source/reference paths and asset ID recorded.
- [x] Exact element rectangles and responsive topology documented before runtime edits.
- [x] Existing production assets only; no new art or baked labels.
- [x] Codex old `minimal/codex_tab` path removed.
- [x] Dossier buttons preserve main-menu aspect and ornament.
- [x] Screenshot comparison at 720p/1080p/2K.
- [x] Focused and full UI/runtime gates pass.

## Deviations

This amendment intentionally supersedes the SCRUM-983 one-row compact footer.
That earlier geometry squeezed the same 380×104 source to 220×72/260×72 and is
the visual clipping reported by the user. The content hierarchy and outer frame
remain unchanged.
