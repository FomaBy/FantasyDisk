# Back-end: Integrate SCRUM-478 Bright Minimalist Full UI Runtime Kit And QA

Статус: new
Приоритет: high
Роль: Back-end (UI/runtime/tests)
Исполнитель: Back-end
Версия: 0.1.6
Создано: 2026-06-19
Автор: Design main / Codex handoff from SCRUM-478
Jira: SCRUM-480
Связано: SCRUM-478

## Context

Design delivered the SCRUM-478 bright minimalist full-game UI source package:

- Spec: `docs/design/mockups/scrum478_minimalist_full_ui_redesign/spec.md`
- Exact-size matrix:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_minimalist_full_ui_metadata.json`
- Button source:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_bright_minimal_button_anchor_sheet_transparent.png`
- Frame source:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_exact_size_frame_source_sheet_transparent.png`
- Mockup board:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_full_screen_mockup_board.png`
- Self-QA evidence:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_self_qa_evidence.md`

## Scope

Back-end owns runtime integration only after Design/PM accepts the source
package:

1. Slice or otherwise prepare final runtime PNGs from the SCRUM-478 source
   sheets into `assets/sprites/ui/frames/minimalist_full_ui/` or another
   reviewed path.
2. Preserve exact asset dimensions from the matrix for `1280x720`, `1600x900`
   and `1920x1080`; do not stretch ornamental borders/caps.
3. Wire the new paths/constants/theme helpers in runtime UI code.
4. Update all covered screens: main menu, hero select, weapon select, combat
   HUD, level-up, rewards, shop, attribute shop, event, codex, settings, patch
   notes, feedback, pause, results, tooltips and badges.
5. Add render/no-overlap/text-overflow verification for all covered screens at
   the three target resolutions.

## Hard Requirements

- Runtime content must stay inside each `content_rect_xywh`.
- Labels, icons, portraits, meters, focus rings and hit areas must never sit on
  frame rails, accent diamonds, gold corner ticks or glow caps.
- If StyleBoxTexture/NinePatchRect is used, `texture_margins_ltrb` and
  `content_margins_ltrb` from the matrix are mandatory; only flat centers may
  stretch.
- Keep old UI kits available until no-live-ref and screenshot QA pass.

## Acceptance

- [ ] Final runtime PNGs are transparent where they are UI assets.
- [ ] All target screens render at `1280x720`, `1600x900`, `1920x1080`.
- [ ] Text overflow verifier is green.
- [ ] Interactive overlap verifier is green.
- [ ] Frame content-zone verifier is green.
- [ ] Asset 1:1 / no ornamental stretch verifier is green.
- [ ] Runtime smoke and focused UI smoke are green.
- [ ] QA evidence is saved under `build/qa/scrum478_minimalist_full_ui/`.

## Out Of Scope

Design-source regeneration and Animator/motion work are out of this Back-end
handoff unless PM creates a separate follow-up.
