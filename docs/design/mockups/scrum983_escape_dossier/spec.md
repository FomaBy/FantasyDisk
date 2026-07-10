# SCRUM-983 Escape Hero Dossier — UI Mockup Specification

Status: Design stage accepted; runtime integration waiting for SCRUM-981 lock release  
Role owner: combined Design+Back-end `/root/scrum983_dossier`  
Task: `docs/tasks/SCRUM-983_escape_hero_dossier.md`  
Jira: SCRUM-983  
Base resolution: 1920×1080  
Responsive targets: 1280×720, 1920×1080, 2560×1440  
Production outer frame: `assets/sprites/ui/meta40/frame_border.png`  
PixelLab source/preview: recorded in `docs/design/references/scrum983_escape_dossier/manifest.json`

## Source Request

Make the Escape hero dossier dense and immediately readable: stat names and
numeric values stay visible, while explanations live in hover/focus tooltips.
`Продолжить`, `Настройки` and `Главное меню` are neutral actions. Only
`Завершить забег` uses danger red. Keyboard/gamepad focus must reach every action
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

## Responsive Geometry

| Viewport | Header | Hero dossier | Derived stats | Action row |
| --- | --- | --- | --- | --- |
| 1280×720 | `157,137,966,60` | scroll `157,209,320,286`, content height 390, 14px scrollbar lane | required scroll `489,209,634,286`, content height 546, 14px lane | y=507 h=60: `168,220`; `396,220`; `624,260`; `892,220`, gaps 8 |
| 1920×1080 | `224,193,1472,72` | `224,281,420,470` | `664,281,1032,470`; four groups 2×2, no scroll for stats-only content | y=779 h=72: x=396/672/948/1244, widths 260/260/280/280, gaps 16 |
| 2560×1440 | `299,257,1962,104` | `299,385,520,650` | `843,385,1418,650`; four groups 2×2 | y=1075 h=72: x=660/960/1260/1600, widths 280/280/320/300, gaps 20 |

The 720p action row uses exactly 944px of the 966px inner width and therefore
leaves 11px on each side. Nothing is compressed under the frame rail. At 720p
the two content columns scroll independently and vertically; horizontal scroll
is disabled. At 1080p/2K the numeric stat groups fit without scrolling, while
equipment or arsenal overflow may remain below in the existing vertical scroll.

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
ellipsis inside their fixed label lane; the complete name is present in the
tooltip. The tooltip content comes from `scripts/stat_formulas.gd`, never from a
second manually maintained formula table.

## Local Component Geometry

At 1920×1080 the left dossier has 16px padding, a 120px identity row, then an
8-row base-stat grid arranged as two columns × four rows. Base rows are at least
44px tall with 44px icons. The right area has 16px padding and a 12px group gap;
each group gets a 30px title lane and compact chips at least 236×54px. The
physical/magic groups use up to three chip rows, support/control up to two and
periodic damage one. This preserves the SCRUM-839 readable minima while removing
the always-visible description paragraphs.

At 1280×720 the same logical order is preserved in scroll content. Stat-chip
width is derived from the 620px text lane after the 14px scrollbar reserve; no
chip, icon or pointer hitbox enters the scrollbar lane.

## Button And Focus Contract

- `PauseResumeButton`, `PauseSettingsButton` and `PauseMainMenuButton` use the
  neutral global text-button normal/hover/focus/pressed/disabled family. No red
  tint, red glow, red font or danger overlay is allowed on Continue or Main Menu.
- `PauseEndRunButton` alone uses the danger-red family in every state. Focus is
  brighter but does not change geometry.
- Initial focus is Continue. Left/right forms a non-destructive action ring:
  Continue → Settings → End Run → Main Menu → Continue.
- Up from an action moves to the nearest final visible stat chip; down from the
  final stat row returns to the nearest action. Stat chips are `FOCUS_ALL` even
  though activation is not required; focus opens the same explanation as hover.
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

## Planned Runtime Integration

Runtime integration starts only after `/root` confirms SCRUM-981 landed and
released shared UI locks. Expected runtime owner paths are
`scripts/pause_stats_menu.gd` plus new focused SCRUM-983 tests/capture helpers.
Shared `scripts/ui_screens.gd`, `tests/runtime_smoke_test.gd` and menu/current
state docs remain excluded until their active owners release them and a new Jira
heartbeat expands the lock.

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
- [x] Continue/Main Menu neutral; End Run alone danger-red in the spec.
- [x] Mouse/keyboard/gamepad tooltip and focus order specified.
- [ ] Runtime screenshots and focused/no-overlap/gamepad/full-smoke gates complete after lock release.

## Deviations

The action controls move to a dedicated footer at all target sizes. This gives
the compact numeric dossier a stable body height, avoids the current 720p header
crowding and preserves one predictable left/right focus ring. No gameplay,
pause-stack or action semantics change.

The first plan-constrained PixelLab generation passed all acceptance gates, so
there is no rejected-generation ID. The manifest records an explicit empty
rejected list and the decision not to spend a generation solely to manufacture
a failed candidate.
