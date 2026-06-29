# SCRUM-672 - UI visual release gate: full screenshot QA

Статус: done
Контур: Codex
Owner: Codex visual QA recheck
Thread/Worker: codex-worker-visualqa-recheck-scrum672
Locked paths: read-only UI visual verification; QA evidence only
Jira: SCRUM-672

## Recheck Context

Rechecked latest `origin/dev` after SCRUM-639 pushed
`893afba6 fix(SCRUM-639): restore event screen content`.

Tested checkout:

- `/Users/sergeyfomin/Documents/FantasyDisk-QA-SCRUM-672-codex`
- `origin/dev` head `b376508b docs(SCRUM-639): sync event fix QA handoff`
- includes SCRUM-639 fix commit `893afba6`
- visible prerequisite history includes SCRUM-666, SCRUM-669, SCRUM-670, and
  SCRUM-671 completion/fix commits. SCRUM-668 exceptions are preserved from the
  documented SCRUM-338 reward-card and non-text-control exception rules.

## Commands

- `python3 tools/build_ui_2k_frame_kit.py --verify` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd` - PASS
- `python3 tools/godot_gate.py --path . --script res://tests/design_review_screenshot_capture_test.gd` - PASS screenshots written, with Godot exit leak/resource warnings only

## Visual Gate Matrix

Screenshot manifest:
`build/qa/design_review/manifest.md`.

Contact sheets:

- `build/qa/scrum672_visual_recheck/scrum672_event_triptych.png`
- `build/qa/scrum672_visual_recheck/scrum672_1920_contact_sheet.png`

| Surface | Viewports | Evidence | Verdict | Notes |
| --- | --- | --- | --- | --- |
| Event | 1280x720, 1920x1080, 2560x1440 | `build/qa/design_review/event_*.png` | PASS | SCRUM-639 regression is fixed: Event title, story, three choices, and Back button are visible; no blank gray panel/up-arrow-only regression. |
| Rest | 1280x720, 1920x1080, 2560x1440 | `build/qa/design_review/rest_*.png` | FAIL | Rest renders a large blank panel with only the up-arrow marker; no title, choice cards, or action buttons visible. Read-only code check shows `scripts/ui_screens.gd::_show_rest_screen()` still creates `UpgradeFabButton` in the Rest panel path before the choice content. |
| Upgrade | 1920x1080 spot-check plus manifest | `build/qa/design_review/upgrade_1920x1080.png` | PASS | Title, subtitle, three choice cards and action labels visible inside panel. |
| Attribute shop | 1920x1080 spot-check plus manifest | `build/qa/design_review/attribute_shop_1920x1080.png` | PASS | Title, two cards, reroll and skip buttons visible; text is dim but present. |
| Battle reward | 1280x720, 1920x1080, 2560x1440 | `build/qa/design_review/battle_reward_*.png` | PASS / exception | Intentional SCRUM-668/SCRUM-670 exception preserved: runtime keeps SCRUM-338 reward-card kit. |
| Elite reward | 1280x720, 1920x1080, 2560x1440 | `build/qa/design_review/elite_reward_*.png` | PASS / exception | Intentional SCRUM-668/SCRUM-670 exception preserved: runtime keeps SCRUM-338 elite reward-card kit. |
| Normal text/action buttons | Representative screenshots and theme gate | `build/qa/design_review/*.png`; `build/qa/scrum672_visual_recheck/dark_fantasy_ui_theme_test.log` | PASS / exception | Text-button rollout holds for normal actions; icon-only/card/slot/portrait/stepper/route-node/weapon/reward controls remain documented exceptions. |
| Representative UI surfaces | 23 surfaces x 3 viewports | `build/qa/design_review/*.png` | FAIL due Rest | Main menu, quit, settings, hero select, weapon select, codex, codex tooltip, level-up, shop, upgrade, event, pause, results, combat HUD, feedback captured successfully; Rest blocks release gate. |

## QA Verdict (2026-06-29)

Статус: FAILED

SCRUM-639 Event fix is visually verified, but SCRUM-672 remains failed because
the Rest screen now reproduces the same blank-panel/up-arrow-only class of
visual regression across all captured viewports.

Production/runtime fixes: none.
