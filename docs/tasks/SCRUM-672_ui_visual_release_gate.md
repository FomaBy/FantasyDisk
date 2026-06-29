# SCRUM-672 - UI visual release gate: full screenshot QA

Статус: done
Контур: Codex
Owner: Codex visual QA recheck worker
Thread/Worker: codex-worker-visualqa-final-scrum672
Locked paths: docs/tasks/SCRUM-672_ui_visual_release_gate.md; read-only UI surface screenshots under build/qa/
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

## QA-Red Fix (2026-06-29)

Статус: fixed, ready for QA visual gate rerun.

Root cause:

- Rest used `_create_upgrade_fab(box.get_parent().get_parent()...)`, which passed
  `MenuPanel_campfire` instead of the screen root. `PanelContainer` then laid out
  `UpgradeFabButton` as panel content, reproducing the same blank-panel /
  up-arrow-only symptom class that SCRUM-639 fixed for Event.

Fix:

- `scripts/ui_screens.gd::_show_rest_screen()` now names the Rest content/title/
  subtitle for QA assertions, keeps the Rest scroll at top, moves the
  `UpgradeFabButton` to the screen root outside `MenuPanel_campfire`, and adds a
  visible `RestBackButton`.
- `tests/ui_no_overlap_matrix_test.gd` now requires Rest title/subtitle, two
  economy choice cards, Back, visible `RestContent`, and explicitly fails if
  `UpgradeFabButton` appears inside the Rest panel.
- `docs/design/systems/menus_ui.md` records the SCRUM-672 Rest fix contract.

Verification:

- `python3 tools/build_ui_2k_frame_kit.py --verify` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd` - PASS
- `python3 tools/godot_gate.py --path . --script res://tests/design_review_screenshot_capture_test.gd` - PASS screenshots written, with Godot exit leak/resource warnings only

Screenshot evidence:

- `/Users/sergeyfomin/Documents/FantasyDisk-SCRUM-672-rest-fix/build/qa/design_review/rest_1280x720.png`
- `/Users/sergeyfomin/Documents/FantasyDisk-SCRUM-672-rest-fix/build/qa/design_review/rest_1920x1080.png`
- `/Users/sergeyfomin/Documents/FantasyDisk-SCRUM-672-rest-fix/build/qa/design_review/rest_2560x1440.png`

Result:

- Rest now shows title/body, two visible action cards, Back, and the attribute
  upgrade FAB outside the panel at bottom-right. Event screenshots remain
  unaffected by this scoped fix. Broad SCRUM-672 release-gate rerun remains QA
  owned.

## Final Visual Gate Recheck (2026-06-29)

Статус: PASSED

Tested checkout:

- Worktree: `/tmp/FantasyDisk-QA-SCRUM-672`
- Branch: `codex/scrum-672-visualqa-final`
- HEAD: `d06455be fix(SCRUM-672): restore rest screen content`
- Confirmed history includes `893afba6 fix(SCRUM-639): restore event screen content`
  and visible SCRUM-666/668/669/670/671 completion/fix commits.

Commands:

- `python3 tools/build_ui_2k_frame_kit.py --verify` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` - PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd` - PASS
- `python3 tools/godot_gate.py --path . --script res://tests/design_review_screenshot_capture_test.gd` - PASS screenshots written

Screenshot evidence:

- Manifest: `build/qa/design_review/manifest.md`
- Event triptych: `build/qa/scrum672_visual_final_recheck/scrum672_event_triptych.jpg`
- Rest triptych: `build/qa/scrum672_visual_final_recheck/scrum672_rest_triptych.jpg`
- Full contact sheets:
  `build/qa/scrum672_visual_final_recheck/scrum672_1280x720_contact_sheet.jpg`,
  `build/qa/scrum672_visual_final_recheck/scrum672_1920x1080_contact_sheet.jpg`,
  `build/qa/scrum672_visual_final_recheck/scrum672_2560x1440_contact_sheet.jpg`

Visual gate matrix:

| Surface | Viewports | Evidence | Verdict | Notes |
| --- | --- | --- | --- | --- |
| Event | 1280x720, 1920x1080, 2560x1440 | `build/qa/design_review/event_*.png`; event triptych | PASS | SCRUM-639 regression remains fixed: Event title, story, three choices, and Back button are visible; no blank-panel/up-arrow-only regression. |
| Rest | 1280x720, 1920x1080, 2560x1440 | `build/qa/design_review/rest_*.png`; rest triptych | PASS | SCRUM-672 Rest fix is verified: Rest title/body, two action cards, Back button, and bottom-right upgrade FAB are visible; no blank-panel/up-arrow-only regression. |
| Main menu, quit, settings display/audio/controls | 1280x720, 1920x1080, 2560x1440 | full contact sheets | PASS | Menus are populated and readable; controls stay inside panel interiors. |
| Hero select, weapon select, codex, codex tooltip | 1280x720, 1920x1080, 2560x1440 | full contact sheets | PASS | Dense UI remains populated; no release-blocking overlap or frame ornament coverage observed. |
| Battle reward, elite reward | 1280x720, 1920x1080, 2560x1440 | `build/qa/design_review/*reward_*.png` | PASS / exception | Intentional SCRUM-668/SCRUM-670 exception preserved: runtime keeps SCRUM-338 reward-card kit. |
| Level-up, shop, attribute shop, upgrade | 1280x720, 1920x1080, 2560x1440 | full contact sheets | PASS | Titles/actions/cards render; content remains in dark/empty interior zones. |
| Pause, pause stats, victory, death, combat HUD, feedback | 1280x720, 1920x1080, 2560x1440 | full contact sheets | PASS | Representative gameplay and modal surfaces render without a new release-gate blocker. |
| Normal text/action buttons | Representative screenshots and theme gate | `build/qa/design_review/*.png`; `dark_fantasy_ui_theme_test.log` | PASS / exception | Text-button rollout holds for normal actions; icon-only/card/slot/portrait/stepper/route-node/weapon/reward controls remain documented exceptions. |
| Global frame/content-zone rule | All captured representative UI surfaces | screenshots + no-overlap/theme gates | PASS | No content/text/icons observed over decorative frame ornament/borders outside preserved SCRUM-668 exceptions. |

QA verdict:

- SCRUM-639 Event regression: visually verified fixed.
- SCRUM-672 Rest regression: visually verified fixed.
- Final SCRUM-672 visual release gate: PASSED.
- Production/runtime changes by QA worker: none.
