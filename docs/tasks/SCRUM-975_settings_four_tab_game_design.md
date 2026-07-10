# SCRUM-975 — Design: four-tab Settings / Game sandbox page

Статус: in_progress
Контур: Codex
Owner: Design/Codex
Thread: `/root/design_scrum975`
Locked paths: `docs/design/references/scrum975_settings_game_tab/**`, `docs/design/previews/scrum975_settings_game_tab/**`, this task mirror, and the backend handoff mirror created after its Jira issue
Jira: SCRUM-975
Sprint / fixVersion: `Спринт 0.2.1` / `0.2.1`
Branch / worktree: `codex/scrum-975-settings-game-design` / `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-975-design`

## Autonomy / Approval

The user pre-approved all in-scope repository work. This task is Design-only:
PixelLab mockup/art, exact safe zones, responsive behavior and a Back-end
handoff. Runtime GDScript, settings persistence, combat/balance and gameplay are
out of scope.

## Контекст

Live Settings v6 uses a fullscreen Atlas-family shell and three independent
global-kit tab plates (`Экран`, `Звук`, `Управление`). SCRUM-975 adds a fourth
tab, `Игра`, for the persisted run-sandbox modifiers specified by SCRUM-976.
The obsolete three-slot strip must not be stretched or receive an extra hit
area. The current shell, field, slider, checkbox, value-chip and action-button
families remain the accepted visual baseline.

## Design scope

- inventory the live Settings screen and SCRUM-976 requirements read-only;
- define a four-plate tab row and a Game-page content contract;
- create `ui_plan.json` and pass the content-zone planning gate before art;
- generate the textless page/frame layer with PixelLab MCP;
- composite Russian preview copy only inside declared content zones;
- verify fit/debug evidence for 1280x720, 1920x1080 and 2560x1440;
- create a separate Jira Back-end handoff issue, then its local mirror.

## Game page content contract

The page exposes five persisted sliders, each with a label, range/value chip,
keyboard/gamepad focus and a neutral value of `1.0×`:

1. HP monsters: `0.5×..3.0×`, step `0.1×`.
2. Damage of monsters: `0.5×..3.0×`, step `0.1×`.
3. Player damage: `0.5×..2.0×`, step `0.1×`.
4. Player attack speed: `0.5×..2.0×`, step `0.1×`.
5. Monster attack speed: `0.5×..3.0×`, step `0.1×`.

The page also shows a neutral/custom status chip, explains that changes apply
from the next run, warns that non-neutral sandbox runs do not grant normal
progression/achievements/balance evidence, and provides a single reset-to-
neutral action. Back-end remains authoritative for clamping and propagation.

## Acceptance

- [x] PixelLab MCP source ID/export and prompt are recorded without secrets.
- [x] Planning report is `ready_for_image` before generation.
- [x] Four tabs fit without using any old three-slot ornament/hit areas.
- [x] All text, values, sliders, controls and hit areas stay inside empty frame
      interiors; ornament is never covered.
- [x] 1920x1080 and 2560x1440 show all five controls and reset without scroll.
- [x] 1280x720 uses an internal vertical scroll lane and keeps tab/header/back
      controls fixed and unobstructed.
- [x] No runtime GDScript/settings/gameplay file changes.
- [x] Separate Back-end Jira handoff and local mirror exist.

## Work log

- 2026-07-10: claimed in Jira by Design/Codex; stale `backlog` label removed,
  fixVersion set to `0.2.1`; design-only locks and next verification recorded.
- 2026-07-10: current Settings v6, historical v3/three-slot packages and
  SCRUM-976 acceptance contract audited read-only.
- 2026-07-10: PixelLab sources generated for wide and 720p layouts; deterministic
  composites, exact content-zone plans and responsive debug overlays completed
  at 1280x720, 1920x1080 and 2560x1440.
- 2026-07-10: Design validation passed (`ready_for_image`, fit `ok: true`,
  runtime smoke PASS); SCRUM-1025 created as the blocked Back-end integration
  handoff depending on SCRUM-975 and SCRUM-976.
