# SCRUM-993 — Shop gold shell while preserving merchant art

Статус: review (Stage 2 implementation and local green-gate complete)
Контур: Codex
Owner: combined Design+Back-end `/root/scrum993_shop_design`
Thread/Worker: `/root/scrum993_shop_design`
Jira: SCRUM-993
Ветка: `codex/scrum-993-shop-gold-shell`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-993-shop-gold-shell`

Task-owned paths:

- `docs/design/mockups/scrum993_shop_gold_shell/**`
- `docs/design/references/scrum993_shop_gold_shell/**`
- `docs/design/previews/scrum993_shop_gold_shell/**`
- `docs/tasks/SCRUM-993_shop_gold_shell.md`
- `scripts/ui_screens.gd`
- `tests/scrum993_shop_gold_shell_test.gd`
- Shop-only oracles in `tests/runtime_smoke_test.gd` and
  `tests/ui_no_overlap_matrix_test.gd`
- `tools/capture_scrum993_shop_gold_shell.gd`
- `docs/design/systems/menus_ui.md`
- `docs/design/current_game_state.md`

## Goal

Bring `ShopScreen` into the accepted SCRUM-981 gold-edge family without losing
the canonical merchant archive backdrop. The screen remains an illustrated shop,
not an opaque modal: four products, prices, purchased/unaffordable states,
tooltip, run HUD and Back stay in exact content zones. The former manual
Attribute Shop FAB zone is deliberately empty per newer SCRUM-982/987 direction.

## Stage 1 acceptance

- [x] Jira claim records owner, lane, worktree and unique Design locks.
- [x] Live Shop runtime/assets inventoried read-only.
- [x] UI Director, PixelLab asset workflow and content-zone workflow applied.
- [x] Responsive `ui_plan` geometry exists for 1280×720, 1920×1080 and 2560×1440.
- [x] All three planning reports say `ready_for_image`.
- [x] PixelLab MCP textless shop/gold-shell source is generated and provenance recorded.
- [x] Accepted/rejected source decisions and alpha/crop audit are recorded.
- [x] Final and debug previews show the full merchant art and exact safe zones.
- [x] Design-only commit is created locally with `FSD_NO_AUTOLAND=1`; no push before runtime release.

## Runtime handoff gate

Runtime implementation starts only after `/root` confirms SCRUM-981 is landed
and releases the shared `ShopScreen`/`ui_screens.gd` locks. Stage 2 must rebase
onto fresh `origin/dev`, then preserve shop stock persistence, purchases,
event-shop exit, re-entry and route return semantics.

Stage 2 reconciliation: do not create `UpgradeFabButton` on Shop. Direct/manual
gold stat upgrade entry is removed by SCRUM-982; mandatory post-combat Attribute
Shop remains a separate SCRUM-987 flow.

## Stage 2 result

- [x] Complete merchant archive is contained without crop inside the responsive
  SCRUM-981 shell; hollow frame remains final/z=100/mouse-ignore.
- [x] Four products, fixed tooltip and Back use authored 1280/1920/2560 zones;
  no Shop scrollbar or manual `UpgradeFabButton` exists.
- [x] Caption plate source rails are scaled before 9-slice use; one-line
  ellipsis, four-digit price and foreign-affinity marker remain inside slots.
- [x] Unaffordable products remain readable/focusable without a covering
  overlay; purchased products render the disabled `снято` hook.
- [x] Tooltip rails/content margins satisfy rail + reserve and compact
  title/effect, price+class and tier+state without clipping at 720p.
- [x] Product/Back focus ring, tooltip show/reset, stock persistence and live
  resize are deterministic and covered by the focused test.
- [x] UI plans were revised after review and all three reports remain
  `ready_for_image`; all three compositor fit reports remain `ok: true`.
- [x] Twelve windowed Metal runtime captures cover
  default/focus/unaffordable/purchased at all three targets.

## Evidence log

- 2026-07-10: Jira moved to `В работе`; stale `backlog` label removed because
  the issue is in live Sprint 0.2.1 and directly dispatched by the autonomous
  sprint coordinator.
- 2026-07-10: PixelLab config-based MCP smoke `get_balance` PASS; tools list
  exposes `create_ui_asset`, `get_ui_asset`, `list_ui_assets`. No secret was
  printed or stored.
- 2026-07-10: source backdrop audited as RGBA 2560×1440, fully opaque, exact
  16:9. Accepted SCRUM-981 production shell is
  `assets/sprites/ui/meta40/frame_border.png`, 1536×1024, 160px 9-slice rails.
- 2026-07-10: PixelLab UI asset
  `9cd80493-fd42-437c-829c-a59f54d33ec7` accepted. It has exactly four item
  wells, one tooltip well, one Back well and complete shop shelving/chests on
  both sides with no baked text or extra controls. Source SHA-256
  `f0449af4c72e6bbf35d38cedaa138ae8e30d3c7a09648cc8ada6735aa731b453`.
- 2026-07-10: independent read-only review found unsafe tooltip rail insets,
  missing caption ellipsis and non-deterministic worst-case coverage. All three
  findings were fixed; the oracle now covers long caption, 9999g, foreign
  affinity, unavailable/purchased states, complete tooltip fit/reset and every
  explicit focus neighbor.
- 2026-07-10: final local gates PASS:
  `scrum993_shop_gold_shell_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `dark_fantasy_ui_theme_test.gd`, `runtime_smoke_ui_test.gd`,
  `gamepad_inrun_ui_test.gd`, `gamepad_full_flow_smoke_test.gd`, and full
  `runtime_smoke_test.gd`. Full/runtime-UI keep only the known non-fatal dummy
  renderer texture diagnostic; full smoke exits 0.
- 2026-07-10: windowed capture ran on OpenGL 4.1 Metal / Apple M4 Pro; visual
  review accepted complete art, frame clearance, readable states and fully
  visible fixed tooltip copy at 1280×720, 1920×1080 and 2560×1440.
