# UI Plan Schema

Use this JSON format before generating interface art. It is intentionally simple
and deterministic so an agent can decide whether the UI is ready for image
generation or must be revised.

## Top-level fields

- `canvas.width`, `canvas.height`: required final bitmap dimensions.
- `policy.min_gap`: recommended minimum gap between collision-checked elements.
- `policy.allow_overlap`: default `false`; if false, sibling overlaps fail.
- `content`: optional string map used by `text_key`.
- `elements`: required list of planned UI rectangles.

## Element fields

- `id`: required unique id.
- `kind`: `panel`, `zone`, `text`, `button`, `icon`, `portrait`, `slot`,
  `list`, `scroll_area`, `scrollbar`, `decor`, or similar.
- `x`, `y`, `w`, `h`: required pixel rectangle.
- `parent`: optional parent element id. Child rectangles are allowed to overlap
  their parent and must fit inside it unless `allow_outside_parent` is true.
- `content_zone`: boolean; true when live content may be inserted there.
- `collision`: boolean; default true for top-level elements, false for children.
- `min_w`, `min_h`: optional minimum acceptable dimensions.
- `text` or `text_key`: optional text to fit-check.
- `max_font`, `min_font`: text fit range.
- `scroll`: `never`, `auto`, or `required`.
- `content_h`: explicit scrollable content height.
- `item_count`, `item_h`, `item_gap`: alternate way to estimate scroll content.
- `scrollbar_w`: width reserved for scrollbar when scrolling is needed.
- `required`: default true.

## Decision

The validator emits one of:

- `ready_for_image`: geometry fits; image generation may start.
- `revise_task`: layout/content cannot fit or policy is violated.

Warnings do not block generation; errors do.

## Example

```json
{
  "canvas": {"width": 1280, "height": 720},
  "policy": {"min_gap": 12, "allow_overlap": false},
  "content": {
    "title": "Codex",
    "body": "Long lore text..."
  },
  "elements": [
    {"id": "modal", "kind": "panel", "x": 120, "y": 70, "w": 1040, "h": 580, "min_w": 720, "min_h": 420},
    {"id": "title_zone", "kind": "text", "parent": "modal", "content_zone": true, "x": 180, "y": 110, "w": 720, "h": 64, "text_key": "title", "max_font": 44, "min_font": 28},
    {"id": "body_scroll", "kind": "scroll_area", "parent": "modal", "content_zone": true, "x": 180, "y": 200, "w": 860, "h": 330, "scroll": "auto", "content_h": 560, "scrollbar_w": 18},
    {"id": "close_button", "kind": "button", "parent": "modal", "content_zone": true, "x": 920, "y": 560, "w": 160, "h": 54, "text": "Close", "max_font": 26, "min_font": 18}
  ]
}
```
