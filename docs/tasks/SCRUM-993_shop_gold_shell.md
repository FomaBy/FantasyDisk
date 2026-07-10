# SCRUM-993 — Shop gold shell while preserving merchant art

Статус: in_progress (Stage 1 Design committed locally; runtime blocked by SCRUM-981 lock)
Контур: Codex
Owner: combined Design+Back-end `/root/scrum993_shop_design`
Thread/Worker: `/root/scrum993_shop_design`
Jira: SCRUM-993
Ветка: `codex/scrum-993-shop-gold-shell`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-993-shop-gold-shell`

Locked paths for Stage 1:

- `docs/design/mockups/scrum993_shop_gold_shell/**`
- `docs/design/references/scrum993_shop_gold_shell/**`
- `docs/design/previews/scrum993_shop_gold_shell/**`
- `docs/tasks/SCRUM-993_shop_gold_shell.md`

Explicitly excluded until SCRUM-981 is landed and its locks are released:

- `scripts/ui_screens.gd`, route/shop runtime and shared UI helpers;
- `tests/runtime_smoke_test.gd`, `tests/ui_no_overlap_matrix_test.gd`;
- shared `menus_ui.md`, `current_game_state.md`, `content_registry.md`;
- SCRUM-981/1032/985/983/1030 and all Claude-owned dirty paths.

## Goal

Bring `ShopScreen` into the accepted SCRUM-981 gold-edge family without losing
the canonical merchant archive backdrop. The screen remains an illustrated shop,
not an opaque modal: four products, prices, purchased/unaffordable states,
tooltip, run HUD, upgrade FAB and Back stay in exact content zones.

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
