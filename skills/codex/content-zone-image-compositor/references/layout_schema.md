# Layout Schema

Use one JSON file per output image. Coordinates are absolute pixels in the final
canvas.

## Fields

Top-level fields:

- `canvas.width`, `canvas.height`: required output dimensions.
- `content`: optional object mapping content keys to strings.
- `zones`: required array of content zones.
- `defaults`: optional style defaults inherited by all zones.

Zone fields:

- `id`: required unique zone id.
- `content_key`: key into top-level `content`; optional if `text` is present.
- `text`: literal text for this zone; overrides `content_key`.
- `x`, `y`, `w`, `h`: required pixel rectangle.
- `role`: optional label such as `title`, `metric`, `caption`, `body`, `badge`.
- `align`: `left`, `center`, or `right`; default `center`.
- `valign`: `top`, `middle`, or `bottom`; default `middle`.
- `font`: optional font path.
- `max_font`: largest font size to try.
- `min_font`: smallest acceptable font size. Render fails if text cannot fit.
- `color`: text color as hex, e.g. `#F7E7BD`.
- `stroke_fill`: optional outline color.
- `stroke_width`: outline width in pixels.
- `line_spacing`: multiplier; default `1.08`.
- `uppercase`: boolean.
- `required`: boolean; default `true`.
- `debug_color`: optional overlay color for debug guide.

`defaults` can provide: `font`, `max_font`, `min_font`, `color`,
`stroke_fill`, `stroke_width`, `line_spacing`, `align`, and `valign`.

## Example

```json
{
  "canvas": {"width": 1920, "height": 1080},
  "defaults": {
    "font": "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "color": "#F7E7BD",
    "stroke_fill": "#1B0D12",
    "stroke_width": 3,
    "line_spacing": 1.08
  },
  "content": {
    "title": "FantasyDisk",
    "subtitle": "17-й день разработки",
    "commits": "553",
    "commits_label": "коммита"
  },
  "zones": [
    {
      "id": "title",
      "content_key": "title",
      "x": 120,
      "y": 70,
      "w": 1000,
      "h": 110,
      "align": "left",
      "valign": "middle",
      "max_font": 78,
      "min_font": 42
    },
    {
      "id": "subtitle",
      "content_key": "subtitle",
      "x": 125,
      "y": 165,
      "w": 950,
      "h": 56,
      "align": "left",
      "max_font": 34,
      "min_font": 22
    },
    {
      "id": "commits_number",
      "content_key": "commits",
      "x": 1220,
      "y": 230,
      "w": 260,
      "h": 95,
      "max_font": 76,
      "min_font": 44,
      "align": "center"
    },
    {
      "id": "commits_label",
      "content_key": "commits_label",
      "x": 1220,
      "y": 328,
      "w": 260,
      "h": 48,
      "max_font": 30,
      "min_font": 18,
      "align": "center"
    }
  ]
}
```

## Prompt Handoff

After writing the layout, summarize the zones in the image-generation prompt.
The model should be asked to draw decorative borders around these rectangles and
leave their interiors empty. Use phrasing like:

```text
The rectangles listed below are strict empty content interiors. Do not place
ornaments, highlights, characters, texture seams, symbols, text, or pseudo-text
inside them. Decorative frames may surround them but must stay outside.
```
