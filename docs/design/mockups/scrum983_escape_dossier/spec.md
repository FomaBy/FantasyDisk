# SCRUM-983 Escape Hero Dossier — UI Mockup Specification

Status: Accepted and implemented; FAN-1047 supersedes only the footer plate selection
Role owner: Back-end `/root`
Task: `docs/tasks/SCRUM-1056.md`
Jira: SCRUM-983, superseded for runtime geometry by SCRUM-1056
Base resolution: 1920×1080
Responsive targets: 1280×720, 1920×1080, 2560×1440
Production outer frame: `assets/sprites/ui/meta40/frame_border.png`
PixelLab source/preview: recorded in `docs/design/references/scrum983_escape_dossier/manifest.json`

## Source Request

Make the Escape hero dossier dense and immediately readable: stat names and
numeric values stay visible, while explanations live in hover/focus tooltips.
`Продолжить`, `Настройки`, `Завершить забег` and `Главное меню` use the same
main-menu button family. Keyboard/gamepad focus must reach every action
and every stat tooltip target. The page must remain inside the shared gold shell
at 720p, 1080p and 2K.

## Source Decision And Provenance

SCRUM-983 generates a PixelLab full-page component reference before runtime
work, but does not create another production outer frame. The runtime shell must
reuse the SCRUM-981 production contract: 1536×1024
`assets/sprites/ui/meta40/frame_border.png`, 160px 9-slice texture margins,
`draw_center=false`. Its actual production provenance is the accepted SCRUM-832
`gpt-image-2` product override; the earlier SCRUM-826 PixelLab family was
superseded. The new SCRUM-983 PixelLab reference establishes the page-specific
hero/stat/action composition, not a replacement runtime bitmap.

No runtime labels, numbers, portraits or icons are baked into generated art.
Runtime continues to use `UIIconRegistry`, `StatFormulas` and the global button
families.

## Content Inventory

| Region | Runtime content | States |
| --- | --- | --- |
| Header | Hero-dossier title, selected hero/class summary | static, localized |
| Hero dossier | portrait/crest, class, weapon, level/ascension, 8 base stat rows, compact survival/equipment summary | default, hover, keyboard/gamepad focus, vertical scroll only when required |
| Physical group | damage, attacks/sec, crit chance, crit multiplier, knockback | numeric chip, tooltip hover/focus |
| Magic group | magic damage, AoE radius, projectile speed, attack range, range multiplier | numeric chip, tooltip hover/focus |
| Support/control group | aura radius, buff power, knockback distance; summon amount when relevant | numeric chip, tooltip hover/focus |
| Periodic-damage group | DoT damage, DoT tick rate; sustain values remain in the hero/survival area | numeric chip, tooltip hover/focus |
| Actions | Continue, Settings, End Run, Main Menu | normal, hover, focus, pressed, disabled; End Run alone is danger |
| Tooltip | stat name, exact value, plain-language explanation, formula/source, influences | viewport-clamped, max 430×288 |
| Build summary | weapon, ultimate, artifact count; full descriptions/names in tooltip | static, localized, tooltip |

Always-visible prose descriptions are forbidden in stat cards. Group titles and
the short hint `Фокус или наведение — подробности` are the only explanatory copy
outside tooltips.

## Frames And Safe Zones

The frame safe rect uses the exact SCRUM-981 160px source-margin scaling. An
additional 24/32px reserve is content-free. The entire band outside the safe
rect plus the reserve is forbidden to labels, icons, portraits, buttons,
hitboxes, focus outlines, scrollbars and tooltip anchors.

| Viewport | Frame safe rect | Inner content rect | Forbidden reserve |
| --- | --- | --- | --- |
| 1280×720 | `Rect2(133,113,1014,494)` | `Rect2(157,137,966,446)` | 24px on every safe-rect edge |
| 1920×1080 | `Rect2(200,169,1520,742)` | `Rect2(224,193,1472,694)` | 24px on every safe-rect edge |
| 2560×1440 | `Rect2(267,225,2026,990)` | `Rect2(299,257,1962,926)` | 32px on every safe-rect edge |

The outer frame is visual-only, mouse-ignore and drawn last. Local hero/stat
surfaces stay inside the inner content rect and retain at least 12px local
content padding; focus/hover art may not grow their rectangles.

Four opaque mouse-ignore reserve masks cover `viewport − inner content rect`:
top, bottom, left and right. They render above the shared gameplay dim but below
dossier content and the final hollow frame. This prevents combat HUD text or
effects from showing through transparent ornament/reserve pixels while leaving
the inner gameplay backdrop dimly visible.

## Responsive Geometry

| Viewport | Header | Hero dossier | Derived stats | Action row |
| --- | --- | --- | --- | --- |
| 1152×648 | `144,125,864,46` | `144,175,348,270`, content min 268 | `504,175,504,270`, content min 178 | `149.5,447,853,72`; widths proportionally fit inner zone |
| 1280×720 | `157,137,966,46` | `157,187,348,318`, content min 268 | `517,187,606,318`, content min 314 | `168,507,944,72`; gaps 8 |
| 1600×900 | `191,165,1218,48` | `191,215,348,442`, content min 268 | `551,215,858,442`, content min 330 | `328,659,944,72` |
| 1920×1080 | `224,193,1472,72` | `224,277,420,482`, content min 368 | `664,277,1032,482`, content min 462 | `396,771,1128,104` |
| 2560×1440 | `299,257,1962,104` | `299,385,520,654`, content min 616 | `843,385,1418,654`, content min 480 | `660,1063,1240,104` |

Both dossier scroll owners have horizontal and vertical scrolling disabled.
Every target asserts `content minimum height <= viewport height`; disabled
scrollbars may never hide overflow. Compact tiers use two-column base stats,
tight Russian aliases and a visible build-summary row. The detailed portrait
returns at 2K; hero/weapon identity remains visible in the header at every tier.
The header identity lane reserves its measured rendered width explicitly and
uses no clipping, wrapping, abbreviation or ellipsis. If a future localized
identity exceeds all width left by the title chip, only its font scales down
within the documented readable tier; the complete class and weapon names remain.
The label also retains a 24px local reserve before the header's right safe edge,
keeping its final glyph outside the irregular top-right ornament intrusion.

## Numeric Stat Contract

| Kind | Visible format | Example | Tooltip retains |
| --- | --- | --- | --- |
| Base characteristic | localized name + plain numeric value | `Ловкость 5` | description, class relevance/influence |
| Damage/value | one decimal when useful | `Урон 14,6` | formula/source and influences |
| Attack/tick rate | localized per-second format | `Скорость атаки 1,94/с` | cooldown meaning and inputs |
| Chance/mitigation | percent | `Шанс крита 7%` | cap/diminishing-return explanation |
| Multiplier | multiplication sign + value | `Сила крита ×1,58` | exact effect and inputs |
| Radius/range/speed | compact integer | `Дальность 616` | unit meaning and influences |

Visible chips contain icon, one-line localized label and value only. Long names
use deterministic meaningful compact Russian aliases inside their fixed label
lane (`Скор. атаки`, `Маг. урон`, `Скор. снар.`, `Период. ур.` and equivalents);
the complete canonical name is present in the tooltip. Neither the alias nor the
compact numeric value may be clipped. The tooltip content comes from
`scripts/stat_formulas.gd`, never from a second manually maintained formula table.

## Local Component Geometry

At 1920×1080 the left dossier has 16px padding, a 120px identity row, then an
8-row base-stat grid arranged as two columns × four rows. Base rows are at least
44px tall with 44px icons. Row-side padding and numeric reserve must still leave
every localized name lane at least as wide as the rendered short label `Сила`;
longer names may ellipsize only after a meaningful visible prefix. The right
area has 16px padding and a 12px group gap;
each group gets a 30px title lane and compact chips at least 236×54px. The
physical/magic groups use up to three chip rows, support/control up to two and
periodic damage one. This preserves the SCRUM-839 readable minima while removing
the always-visible description paragraphs.

At 1280×720 the same logical order is preserved in scroll content. Stat-chip
width is derived from the 620px text lane after the 14px scrollbar reserve; no
chip, icon or pointer hitbox enters the scrollbar lane.

## Button And Focus Contract

- All four pause actions use one size-fit sibling from the Main Menu
  `text_buttons_unique` kit with `Color.WHITE` tint: `later_260x72` at compact
  tiers and `back_260x104` at 104px tiers. Normal/hover/focus/pressed/disabled
  retain identical bounds and logical content margins; no action receives a
  pause-specific or danger-red override.
- Initial focus is Continue. Left/right forms a non-destructive action ring:
  Continue → Settings → End Run → Main Menu → Continue.
- Up from an action moves to the nearest final visible stat chip; down from the
  final stat row returns to the nearest action. Stat chips are `FOCUS_ALL` even
  though activation is not required; focus opens the same explanation as hover.
- Visibility for footer/stat transfers is computed after intersection with the
  owning `ScrollContainer`; an off-screen row is never a footer neighbor.
- Focus tooltip content lives in a clipped vertical `ScrollContainer`. Its
  actual panel rectangle, including the longest priority/formula text, is capped
  at 430×288 and clamped to the inner content rect. Stat hover uses that same
  bounded panel instead of the generic engine/global tooltip; wheel, Page
  Up/Down and gamepad shoulders scroll long content while focus stays on the row.
  Wheel belongs to the tooltip only with an active stat hover; outside stat rows
  it continues to scroll the underlying Hero/Derived column.
- Scroll-value changes and footer focus trigger a deferred geometric-neighbor
  rebuild, so a footer action never retains an off-screen stat neighbor after
  focus-follow scrolling.
- Within stats, geometric left/right/up/down neighbors cover every base and
  derived chip. Both scroll containers use `follow_focus=true` and boundary
  neighbors transfer between columns/action row instead of trapping focus.
- B/Escape resumes the run through the existing centralized pause path.

## PixelLab Generation Contract

The 688×384 PixelLab source uses a 512×286 virtual canvas template:

- one hollow outer shell;
- one wide title well;
- one tall left hero-dossier well;
- exactly four right stat wells in a 2×2 grid;
- exactly four bottom action wells in one row;
- only the third action well may use crimson danger material;
- no text, pseudo-text, portrait, character, icon, circle, extra panel,
  checkerboard or filled background.

`pixellab_layout_688x384.json` is the deterministic content overlay contract.
The accepted PixelLab base remains immutable during compositing; the compositor
adds sample content only inside declared zones and writes a separate debug image
and fit report.

## Runtime Integration

The accepted contract is implemented in `scripts/pause_stats_menu.gd` with
focused coverage in `tests/scrum983_escape_dossier_test.gd` and real windowed
capture in `tools/capture_scrum983_escape_dossier.gd`. The implementation keeps
`scripts/ui_screens.gd` untouched, preserves the centralized pause/action
signals and uses the existing global icon/button/frame families.

The old umbrella no-overlap oracle now checks the semantic `DossierHeader`,
`DossierBody` and `PauseControlButtons` peers instead of treating the required
full-screen visual-only frame as a content peer. The shared runtime-smoke dossier
assertion remains read-only until the active Priest worker releases its test
lock, after which it will be aligned with the implemented semantic grid/footer.

The PixelLab image is a design reference, not a TextureRect screenshot to show
at runtime. Godot rebuilds the composition from responsive Controls, existing
icons, text-button states and the shared 9-slice frame.

## Acceptance Checks

- [x] Content inventory includes every visible region, dynamic value and state.
- [x] Exact shell safe/content rects recorded at 720p, 1080p and 2K.
- [x] UI planning gate is `ready_for_image`, `ok:true`, zero errors/warnings at all targets.
- [x] PixelLab MCP config smoke passed without printing secrets.
- [x] PixelLab base accepted after exact-zone, alpha and visual QA.
- [x] Preview shown in chat.
- [x] Compositor report `ok:true`; debug overlay proves content remains inside zones.
- [x] All four actions use the exact main-menu button family in all five states.
- [x] Mouse/keyboard/gamepad tooltip and focus order specified.
- [x] Runtime screenshots and focused/no-overlap/gamepad/UI-smoke gates complete.
- [x] Repository-wide runtime smoke complete after the Priest test-lock release.

## Deviations

The action controls move to a dedicated footer at all target sizes. This gives
the compact numeric dossier a stable body height, avoids the current 720p header
crowding and preserves one predictable left/right focus ring. No gameplay,
pause-stack or action semantics change.

The first plan-constrained PixelLab generation passed all acceptance gates, so
there is no rejected-generation ID. The manifest records an explicit empty
rejected list and the decision not to spend a generation solely to manufacture
a failed candidate.
