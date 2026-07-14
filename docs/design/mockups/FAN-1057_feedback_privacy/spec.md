# FAN-1057 Feedback Privacy Overlay

Status: `ready_for_integration` after PixelLab visual QA

Design issue: FAN-1059

Parent: FAN-1057

Role owner: Design

Base canvas: 1920x1080

Responsive targets: 1280x720, 1920x1080, 2560x1440

Authoritative geometry: `ui_plan.json`

PixelLab source: `docs/design/references/FAN-1057_feedback_privacy/feedback_privacy_overlay_pixellab_source.png`

Review preview: `docs/design/previews/FAN-1057_feedback_privacy_overlay_1920x1080.png`

## Decision

Keep the proven centered overlay, pinned status/actions and scrollable middle
from SCRUM-460/SCRUM-583. Replace the single vertical content stream with a
desktop two-column report/screenshot composition and a full-width privacy block.
At 1280x720 the middle content becomes a one-column scroll body; title, send
status, local-fallback message and both actions remain pinned and reachable.

The PixelLab output is a textless full-page design reference. It is not a
runtime texture and must not replace `FeedbackOverlay` or its live children.
Godot recreates the geometry with Controls and reuses the accepted runtime
button/frame families.

## Existing Contracts Preserved

- top-level `FeedbackOverlayLayer` and `FeedbackOverlay` remain modal;
- gameplay is paused while the overlay is open;
- the screenshot is captured before the overlay appears;
- `FeedbackTextEdit`, `FeedbackScreenshotPreview`, `FeedbackStatusLabel`,
  `FeedbackSendButton` and `FeedbackCancelButton` keep their canonical names;
- Escape/gamepad cancel closes only this overlay;
- failed online delivery may save a local report and must show the resulting
  local path;
- middle content scrolls while status and actions stay pinned;
- send uses `text_buttons_unique/feedback_260x64` and cancel uses
  `text_buttons_unique/feedback_cancel_220x64`, including normal, hover, focus,
  pressed and disabled states.

## New Runtime Elements

| ID | Type | Purpose | Focus |
| --- | --- | --- | --- |
| `FeedbackPrivacyHeading` | Label | Introduces collected-data summary | none |
| `FeedbackPrivacyBody` | RichTextLabel/Label | Screenshot, metadata, installation ID and observed-IP disclosure | none |
| `FeedbackOperatorRetentionLabel` | Label | Deployment-owned operator and retention values | none |
| `FeedbackScreenshotToggle` | CheckBox | Explicit include/omit screenshot choice | 2 |
| `FeedbackLocalFallbackLabel` | Label | Explains local-only fallback before send | none |

`FeedbackScreenshotToggle` defaults to included because a preview is already
captured, but the choice must be explicit and reversible before submission. On
omit, the preview stays visible at reduced opacity with an omission state; the
reporter receives no image bytes. Toggling never recaptures the screen.

## Geometry At 1920x1080

All coordinates are `[x, y, width, height]` in viewport pixels.

| ID | Rect | Content/safety rule |
| --- | --- | --- |
| `feedback_dim` | `[0,0,1920,1080]` | uniform dim; no focus |
| `feedback_panel` | `[260,45,1400,990]` | content rect `[330,100,1260,855]`; outer 70px horizontal and 55-80px vertical rail reserve |
| `feedback_title` | `[375,100,1170,70]` | centered; no ornament inside |
| `feedback_scroll` | `[330,186,1260,595]` | reserve 18px on right for scrollbar even when hidden |
| `feedback_description` | `[350,205,690,330]` | report field; minimum body band, wrapped |
| `feedback_screenshot` | `[1074,205,496,279]` | exact 16:9 preview; aspect-preserving only |
| `feedback_screenshot_toggle` | `[1070,506,500,64]` | full hit/focus plate; no baked checkbox art |
| `feedback_privacy_disclosure` | `[350,586,1220,179]` | complete copy, word wrap, no ellipsis |
| `feedback_status_fallback` | `[350,800,1220,50]` | pinned; may wrap to two compact lines |
| `feedback_send` | `[1050,875,260,64]` | accepted exact-size button family |
| `feedback_cancel` | `[1330,875,220,64]` | accepted exact-size button family |

No content may use the full panel bounds. The PixelLab modal rail, corner
accents and separator lines are forbidden content zones. A runtime frame may
use its own stricter content margins; if so, the intersection of both safe
rects wins.

## Compact 1280x720

- panel: `[40,24,1200,672]`, safe content `[96,64,1088,612]`;
- title: `[96,64,1088,40]` and fixed;
- middle scroll viewport: `[96,120,1088,420]`;
- scroll body order: description 160px, screenshot toggle 48px, centered
  544x306 screenshot, privacy block 190px;
- scroll body is 824px high and therefore deliberately scrollable;
- status/local fallback: `[96,556,1088,40]`, fixed;
- send: `[686,612,260,64]`; cancel: `[964,612,220,64]`, fixed;
- scrollbar reserve: 18px; horizontal scrolling is disabled;
- runtime may lower description/body font only to the canonical semantic
  minimum. It must scroll before reducing below that band.

The compact form never hides actions below the fold. Screenshot omission does
not collapse the preview block, so focus and scroll positions do not jump. The
right stick scrolls the middle body from every focus stop; two 65%-viewport
steps reveal the complete privacy block before the player reaches Send.

## Intermediate Viewports

Panel size is continuous between the authored 1280×720 and 1920×1080 targets:
it interpolates from `1200×672` to `1400×990` using the limiting viewport scale.
The 1400→1401 px boundary therefore stays `1200×672`; 1599×899 and 1600×900
measure approximately `1299×830` and `1300×831`. Only the report columns switch
at the 1600×900 breakpoint. A constrained two-column viewport may still scroll
its middle body; pinned status/actions and controller access remain unchanged.

## 2560x1440

Scale the 1920x1080 geometry uniformly by 4/3. The panel is
`[347,60,1866,1320]`; the description minimum becomes 440px, screenshot frame
approximately 667×375, toggle/privacy/scroll minima 85/240/787px, and action
plates approximately 347×85 and 293×85. Nine-slice frame/button margins scale
with the resolved control sizes; no raster rail is stretched independently.
Text continues to use semantic typography tokens rather than raster scaling.

## Runtime Copy Contract

The following strings are live text; none are baked into the PNG:

- title: `Отправить фидбек`;
- field hint: `Что случилось, где вы были и что ожидали увидеть?`;
- toggle included: `Приложить скриншот`;
- toggle omitted: `Не прикладывать скриншот`;
- heading: `Что попадёт в отчёт`;
- disclosure: `Текст и выбранный скриншот; версия игры, экран, разрешение, ОС,
  персонаж, оружие, Возвышение, акт/этап и состояние боя; случайный ID
  установки. Сервер или edge видит IP соединения для защиты от спама.`;
- operator/retention: `Оператор: {operator}. Хранение: до
  {retention_days} дней.`;
- fallback: `Если онлайн-отправка недоступна, локальная копия сохранится только
  на этом устройстве; путь будет показан ниже.`;
- actions: `Отправить`, `Отмена`.

`operator` and `retention_days` are deployment-owned values, not Design
guesses. Online Send stays disabled when either is missing. This matches the
relay provisioning gate in `services/feedback_proxy/README.md` and prevents a
misleading disclosure from shipping.

## Focus And Input

Initial focus is `FeedbackTextEdit`.

1. `FeedbackTextEdit`
2. `FeedbackScreenshotToggle`
3. `FeedbackSendButton`
4. `FeedbackCancelButton`

The screenshot preview, disclosure labels, status and scroll container are not
Tab stops. Wheel/right-stick scrolling works while a descendant of the middle
body owns focus. Focus outlines are runtime state art and must not resize or
move a Control. Escape, gamepad B and the existing pause-back path close only
the overlay and restore focus to the control that opened it when available.

## States

| State | Required behavior |
| --- | --- |
| initial | TextEdit focused; screenshot included; online route available only when deployment privacy values are complete; otherwise the action is an explicitly disclosed local save |
| screenshot omitted | preview dimmed and marked by runtime copy; no screenshot bytes submitted |
| sending | Send disabled without changing its current responsive footprint, status=`Отправляем...`; Cancel remains reachable |
| success | status uses accessible success tint; no auto-close before the message is readable |
| online error/local saved | status shows the local path and fallback message; retry remains possible |
| missing operator/retention | online route disabled with truthful status; the existing local fallback action remains available |
| empty description | reporter validation message in pinned status; focus returns to TextEdit |
| long description/privacy | middle scrolls; pinned title/status/actions never move |

## PixelLab Art Contract

- source ID: recorded in adjacent `manifest.json`;
- source tag/name: `fan1057_feedback_privacy_overlay`;
- style: restrained aged blackened steel/obsidian, hairline antique gold,
  minimal dark-ruby dragon accents;
- exact source aspect: 672x378, proportional 16:9 review at 1920x1080;
- generated rectangles are empty content wells only;
- no text, numbers, runes, logos, watermark, checkbox mark, focus ring, icon or
  screenshot is baked into the source;
- the generated output remains Design evidence and is not promoted to runtime.

## Integration Checklist

- [x] Add `FeedbackScreenshotToggle` and make reporter image optional.
- [x] Render complete privacy/operator/retention/local-fallback copy as Controls.
- [x] Disable online routing unless deployment supplies operator/contact/retention/policy.
- [x] Preserve canonical existing node names and reporter lifecycle.
- [x] Keep lifecycle/facade compatibility in `ui_screens.gd` while extracting
  the focused builder to `scripts/ui/feedback_overlay.gd`.
- [x] Preserve pinned title/status/actions around the middle scroll body.
- [x] Reuse accepted exact-size feedback button families and their five states.
- [x] Verify 1280x720, 1920x1080 and 2560x1440 fresh-open and live-resize paths.
- [x] Verify keyboard/gamepad focus order, Escape/B close, retry and local fallback.
- [x] Run focused feedback, runtime smoke and responsive no-overlap validation.

## Design Acceptance

- [x] Existing overlay and accepted assets inventoried.
- [x] PixelLab MCP config smoke passed without exposing credentials.
- [x] Exact safe-zone geometry and compact scroll behavior documented.
- [x] Explicit screenshot include/omit choice specified.
- [x] Screenshot, allowlisted game/OS metadata, persistent anonymous install ID
  and observed IP are disclosed.
- [x] Operator/retention are required deployment values with a fail-closed send
  gate.
- [x] Local fallback is explained before Send.
- [x] Focus order and all action states are specified.
- [x] Runtime text is not baked into the art layer.
- [x] Runtime integration remains outside the Design locked paths.
