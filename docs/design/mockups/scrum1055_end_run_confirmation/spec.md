# SCRUM-1055 End Run confirmation text-fit corrective spec

Status: accepted corrective pass

## Reused visual contract

- Reuse the existing opaque atlas-chip `EndRunConfirmationPanel`; no new art or
  frame redraw is required.
- Preserve the accepted 600x340 centered modal, title/subtitle stack, 18px
  inter-button gap, outside-click cancellation, and safe default focus on
  `Отмена`.
- Keep all labels and hitboxes inside the panel's empty content zone; nothing may
  overlap its ornament or border.

## Button content zones

| Control | Slot | Shared family | Text-fit rule |
|---|---:|---|---|
| `EndRunConfirmAcceptButton` | 240x72 | `text/continue_240x72` | full `Завершить`, including final `ь`, plus 4px reserve |
| `EndRunConfirmCancelButton` | 240x72 | `text/continue_240x72` | full `Отмена` plus 4px reserve |

The two slots occupy 498px including their 18px gap, which remains inside the
panel's authored inner content width. Font size stays shared and readable; the
corrective pass widens the native button family instead of shrinking only one
label.

## Acceptance

- Both buttons have equal rects and use all five states from the same registered
  family.
- `rendered_text_width + 4 <= style_content_width` at 1152x648, 1280x720,
  1920x1080, and 2560x1440.
- Buttons are disjoint and enclosed by `EndRunConfirmationPanel`.
- Cancel remains the initial focus; Escape/B closes only the confirmation.
