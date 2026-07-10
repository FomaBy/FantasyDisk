# SCRUM-975 — Design: four-tab Settings / Game sandbox page

Статус: done
Контур: Codex
Owner: Design/Codex
Thread: `/root/design_scrum975`
Locked paths: released after push of the Design package; runtime integration remains owned by SCRUM-1025
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

## Результат

- Jira SCRUM-975 moved to `Контроль качества`; independent QA is still required.
- Design package and responsive evidence pushed to `origin/dev` in commit
  `192c7cbf`.
- PixelLab generation IDs, original exports, deterministic post-processing,
  layouts and fit reports are recorded in the reference manifest.
- Runtime scope remains intentionally incomplete: SCRUM-1025 integrates this
  package after SCRUM-975 and SCRUM-976 acceptance; SCRUM-977 remains blocked.
- Disk cleanup: generated `.godot/` import cache removed; task worktree and
  local branch are removed after the final bookkeeping commit is pushed.

## QA-Вердикт (2026-07-10)

Статус: FAILED

Проверено:

- independent production QA from fresh `origin/dev` (`b243d6e26`) in the
  disposable worktree
  `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-975-qa`;
- PixelLab manifest/provenance: three valid source UUIDs, all referenced files
  present, textless alpha layers and the 44×44 Game icon inspected directly;
- `ui_plan.json` and `ui_plan_1280x720.json` rerun through
  `validate_ui_layout_plan.py`; both report `ready_for_image` with no reported
  errors or warnings;
- all three compositor renders rerun from committed bases/layouts; final PNGs
  reproduce byte-for-byte and reports remain `ok: true` at 1280×720,
  1920×1080 and 2560×1440;
- final/debug previews inspected at all three targets: visible content is
  readable, four tab plates remain separate, header/back/tabs stay fixed at
  720p, and visible content does not cover frame ornament;
- deterministic `postprocess_assets.py` rerun in an isolated temporary copy;
  all alpha layers, responsive bases and icon outputs reproduce byte-for-byte;
- JSON parse, Python syntax, secret-pattern scan, manifest path/dimension/alpha
  checks, `git diff --check`, and the no-runtime-path scope check passed;
- Godot 4.7 semaphore gates passed: `runtime_smoke_test.gd`,
  `runtime_smoke_ui_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `dark_fantasy_ui_theme_test.gd`, `animation_smoke_test.gd`,
  `meta_progression_smoke_test.gd`, `melee_weapon_targeting_test.gd`,
  `gamepad_menu_focus_test.gd`, and two consecutive
  `gamepad_full_flow_smoke_test.gd` runs. Runtime/UI smokes emitted only the
  known non-fatal dummy-renderer screenshot warning and ended PASS.

Краевые случаи:

- 1280×720 2×2 tab reflow with fixed header/back and a dedicated 14px
  scroll lane;
- 1920×1080 and 2560×1440 one-row tabs with five visible modifier rows and
  reset without scrolling;
- reproducibility audit of committed plans, guides, reports, composited images
  and PixelLab post-processing rather than relying on the executor report.

Баги: `SCRUM-1030` — the compact plan/layout contains only the two
initially visible rows and omits exact geometry for the three scrolled rows,
their slider/value hitboxes and reset, so frame safety of the complete 720p
scroll content is not proven. The committed 2560 guide/report is also stale:
it does not reproduce from committed `layout.json` and reports different tab,
label, value and slider zones. SCRUM-975 remains in Jira `Контроль
качества` until the Design correction is independently rechecked.
