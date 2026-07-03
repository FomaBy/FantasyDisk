# SCRUM-571: UI-redesign Reward Ordinary 2K Mockup

Статус: done
Lane: Codex
Owner: Design/Codex UI worker scrum571-648
Thread: 019f2386-22ee-7d62-a7ce-68706354cfbb
Locked paths: docs/design/mockups/scrum571_reward_2k/, docs/design/previews/scrum571_reward_2k_*, docs/tasks/design_scrum571_reward_ui_2k_mockup_task.md
Jira: SCRUM-571

## Autonomy / Approval

User pre-approved in-scope Design work. Work is limited to source mockup/spec/evidence assets for the ordinary reward screen. Runtime scripts and shared integration files are out of scope.

## Context

The task requests a 2K OpenAI-API-generated UI mockup/spec/source package for the ordinary reward screen. `fantasydisk-ui-director` and `content-zone-image-compositor` were used because the screen has fixed reward cards, choice buttons, and strict safe content zones.

## Result

Completed the Design-only SCRUM-571 2K ordinary reward mockup package. The OpenAI Images API base layer was generated after loading `OPENAI_API_KEY` from the Windows User environment, then runtime sample content was composited strictly inside declared content zones. No manual/non-API substitute was used.

## Completed Evidence

- `docs/design/mockups/scrum571_reward_2k/ui_plan.json`
- `docs/design/mockups/scrum571_reward_2k/ui_plan_report.json` (`ok=true`, `decision=ready_for_image`)
- `docs/design/mockups/scrum571_reward_2k/ui_plan_guide.png`
- `docs/design/mockups/scrum571_reward_2k/layout.json`
- `docs/design/mockups/scrum571_reward_2k/layout_guide.png`
- `docs/design/mockups/scrum571_reward_2k/layout_guide_report.json` (`ok=true`)
- `docs/design/mockups/scrum571_reward_2k/spec.md`
- `docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_debug.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_report.json` (`ok=true`, 15 zones)
- `docs/design/previews/scrum571_reward_2k_ui_plan_guide.png`
- `docs/design/previews/scrum571_reward_2k_layout_guide.png`
- `docs/design/previews/scrum571_reward_2k_base.png`
- `docs/design/previews/scrum571_reward_2k_mockup.png`
- `docs/design/previews/scrum571_reward_2k_mockup_debug.png`

## Validation

- `validate_ui_layout_plan.py --plan docs/design/mockups/scrum571_reward_2k/ui_plan.json --guide-output ... --report ...` passed.
- `render_content_zones.py --layout docs/design/mockups/scrum571_reward_2k/layout.json --guide-output ... --report ...` passed.
- OpenAI asset generator passed: `reward_ordinary_2k_base.png` saved under `docs/design/references/scrum571_reward_2k/`.
- Final compositor passed: `reward_ordinary_2k_mockup_report.json` has `ok=true` for all 15 zones.
- PNG audit passed: base/mockup/debug/preview images are `2560x1440`.

## Pending Deliverables

- Runtime Godot integration is intentionally out of scope for this Design stage and should be handled by a separate Back-end/UI integration task if needed.

## Rationale / Notes

The base image is a full-screen UI mockup/reference layer, so RGB is acceptable for this Design package. Future isolated runtime frame assets must be exported separately as alpha-ready PNGs with freshly measured texture/content margins before Godot wiring.

## SCRUM-648 QA Defect Fix (2026-06-28)

Fixed the QA defect from SCRUM-648 against this evidence package. The OpenAI-generated base image was reused; no new base generation and no runtime/backend integration were needed. The content-zone JSON/spec/composition were revised so text no longer sits on decorative frame bars:

- `subtitle_zone` now uses the lower empty interior of the subtitle frame instead of the upper ornamental rail.
- Card icon zones were compacted and card title/body zones were moved into dark empty interiors, away from divider bars and gem rails.
- `footer_zone` moved into the lower modal interior field, away from card bottoms and bottom ornaments.

Updated evidence:

- `docs/design/mockups/scrum571_reward_2k/ui_plan.json`
- `docs/design/mockups/scrum571_reward_2k/ui_plan_report.json` (`ok=true`, `decision=ready_for_image`)
- `docs/design/mockups/scrum571_reward_2k/ui_plan_guide.png`
- `docs/design/mockups/scrum571_reward_2k/layout.json`
- `docs/design/mockups/scrum571_reward_2k/layout_guide.png`
- `docs/design/mockups/scrum571_reward_2k/layout_guide_report.json` (`ok=true`)
- `docs/design/mockups/scrum571_reward_2k/spec.md`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_debug.png`
- `docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_report.json` (`ok=true`, 15 zones)
- `docs/design/previews/scrum571_reward_2k_ui_plan_guide.png`
- `docs/design/previews/scrum571_reward_2k_layout_guide.png`
- `docs/design/previews/scrum571_reward_2k_mockup.png`
- `docs/design/previews/scrum571_reward_2k_mockup_debug.png`

Validation:

- `validate_ui_layout_plan.py --plan docs/design/mockups/scrum571_reward_2k/ui_plan.json --guide-output docs/design/mockups/scrum571_reward_2k/ui_plan_guide.png --report docs/design/mockups/scrum571_reward_2k/ui_plan_report.json` passed.
- `render_content_zones.py --layout docs/design/mockups/scrum571_reward_2k/layout.json --guide-output docs/design/mockups/scrum571_reward_2k/layout_guide.png --report docs/design/mockups/scrum571_reward_2k/layout_guide_report.json` passed.
- `render_content_zones.py --input docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png --layout docs/design/mockups/scrum571_reward_2k/layout.json --output docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png --debug-output docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_debug.png --report docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_report.json` passed.
- PNG dimension audit confirmed base/mockup/debug/preview images are `2560x1440`.
- Visual/debug check: subtitle, body text, button labels and footer sit inside dark empty interiors or intentional button interiors; decorative rails, gems, dividers and frame bars remain unobstructed.

## SCRUM-648 Dev Integration Re-Apply (2026-07-02)

Re-applied the stranded SCRUM-648 fix to current `origin/dev` without merging the
old `origin/codex/scrum648-reward-zones-fix` branch. The task branch is
`codex/scrum571-648-reward-zones`; the original fix commit
`3825dda2d4b34bea8bba5a01fc7b798842efc671` was cherry-picked cleanly as the
first task commit and then revalidated on top of `origin/dev`.

Scope remained Design evidence only:

- `docs/design/mockups/scrum571_reward_2k/`
- `docs/design/previews/scrum571_reward_2k_*`
- `docs/tasks/design_scrum571_reward_ui_2k_mockup_task.md`

Validation on 2026-07-02:

- `python3 skills/codex/content-zone-image-compositor/scripts/validate_ui_layout_plan.py --plan docs/design/mockups/scrum571_reward_2k/ui_plan.json --guide-output docs/design/mockups/scrum571_reward_2k/ui_plan_guide.png --report docs/design/mockups/scrum571_reward_2k/ui_plan_report.json`
  passed with `ok=true`, `decision=ready_for_image`.
- `python3 skills/codex/content-zone-image-compositor/scripts/render_content_zones.py --layout docs/design/mockups/scrum571_reward_2k/layout.json --guide-output docs/design/mockups/scrum571_reward_2k/layout_guide.png --report docs/design/mockups/scrum571_reward_2k/layout_guide_report.json`
  passed with `ok=true`.
- `python3 skills/codex/content-zone-image-compositor/scripts/render_content_zones.py --input docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png --layout docs/design/mockups/scrum571_reward_2k/layout.json --output docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png --debug-output docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_debug.png --report docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_report.json`
  passed with `ok=true` for all 15 zones.
- PNG dimension audit confirmed base, guide, final, debug and preview PNGs are
  `2560x1440`.
- Visual/debug inspection confirmed subtitle/body/footer/title/button content
  stays inside dark interiors or button interiors; decorative frame bars, rails,
  gems, dividers and bottom ornaments remain unobstructed.

Runtime scripts, unrelated assets and the stale branch's unrelated history were
not touched. Disk cleanup: no `.godot`, `__pycache__`, import cache or temp
render cache was created in the task worktree; the disposable worktree cleanup is
reported in the final Jira comment after push.

## QA-Вердикт (2026-07-03)

Статус: PASSED

Проверено:
- Current `origin/dev` HEAD after pre-commit fast-forward is `d636814e`; tests
  were run at `03d9657e`, and the fast-forward to `d636814e` changed only
  docs/process/task metadata outside SCRUM-571 mockup/runtime paths. This is not
  the stranded feature branch: commits `7f999ed5` and `7a093b3d` are ancestors
  of HEAD.
- `python3 skills/codex/content-zone-image-compositor/scripts/validate_ui_layout_plan.py --plan docs/design/mockups/scrum571_reward_2k/ui_plan.json --guide-output build/qa/scrum571_reqacheck_20260703/ui_plan_guide.png --report build/qa/scrum571_reqacheck_20260703/ui_plan_report.json` passed with `ok=true`, `decision=ready_for_image`.
- `python3 skills/codex/content-zone-image-compositor/scripts/render_content_zones.py --layout docs/design/mockups/scrum571_reward_2k/layout.json --guide-output build/qa/scrum571_reqacheck_20260703/layout_guide.png --report build/qa/scrum571_reqacheck_20260703/layout_guide_report.json` passed with `ok=true`.
- `python3 skills/codex/content-zone-image-compositor/scripts/render_content_zones.py --input docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png --layout docs/design/mockups/scrum571_reward_2k/layout.json --output build/qa/scrum571_reqacheck_20260703/reward_ordinary_2k_mockup.png --debug-output build/qa/scrum571_reqacheck_20260703/reward_ordinary_2k_mockup_debug.png --report build/qa/scrum571_reqacheck_20260703/reward_ordinary_2k_mockup_report.json` passed with `ok=true` for all 15 zones.
- Regenerated final/debug PNGs are byte-identical to committed evidence (`cmp=0`);
  PNG audit confirms base, final, debug and preview files are `2560x1440`.
- Manual final/debug inspection confirms subtitle, card body, footer and button
  labels stay inside dark interiors or intentional button interiors; decorative
  rails, gems, separators, frame bars and bottom ornaments remain unobstructed.
- Independent read-only subagent audit also returned PASS for the SCRUM-648
  frame-rule defect. Non-blocking note: the declared title zone is wide, but the
  actual title glyphs are centered away from side ornaments.
- `git diff --check -- docs/design/mockups/scrum571_reward_2k docs/design/previews docs/tasks/design_scrum571_reward_ui_2k_mockup_task.md` passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_progression_smoke_test.gd` passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd` passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` passed.

Краевые случаи:
- Re-QA проверяет именно current dev after integration, not the previously
  stranded `origin/codex/scrum648-reward-zones-fix` branch.
- Content-zone regeneration is deterministic/idempotent against committed
  evidence.
- Frame-rule acceptance checked visually against both final and debug overlays,
  including the previously failing subtitle/body/footer areas.

Баги: нет.
