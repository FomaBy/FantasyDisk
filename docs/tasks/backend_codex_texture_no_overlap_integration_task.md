# BACK-END: Integrate Codex Texture Kit And No-Overlap Layout

Статус: in_progress
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Design handoff from SCRUM-345
Jira: SCRUM-403
Связано: SCRUM-345, SCRUM-331, SCRUM-327

## Context

Design SCRUM-345 produced a new Codex UI texture kit through
`fantasydisk-asset-generator` and postprocessed it into production PNG assets.
Runtime integration remains Back-end scope because it touches
`scripts/ui_screens.gd`, stylebox/theme mapping and no-overlap matrix checks.

## Assets

Reference and metadata:

- `docs/design/references/codex/codex_ui_texture_kit_reference.png`
- `docs/design/references/codex/codex_ui_texture_kit_metadata.json`
- `docs/design/previews/codex_ui_texture_kit_contact.png`
- `build/qa/scrum345/codex_texture_design_qa.json`
- `build/qa/scrum345/codex_texture_design_qa.md`
- `build/qa/scrum345/codex_texture_mock_1280x720.png`
- `build/qa/scrum345/codex_texture_mock_1920x1080.png`
- `build/qa/scrum345/codex_texture_mock_2560x1440.png`

Runtime candidate PNGs:

- `assets/sprites/ui/frames/codex/ui_frame_codex_main_panel.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_section_panel.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_entry_card.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_entry_card_hover.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_portrait_slot.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tooltip.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tab.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tab_hover.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tab_pressed.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tab_disabled.png`

## Required Integration

- Use the Codex kit only on `CodexScreen`, `CodexTabs`,
  `CodexContent`, Codex entry rows, `_codex_portrait` slots and
  `GlossaryTooltipPanel`.
- Keep old global/ornate frames as fallback for other screens.
- Preserve existing Codex data/navigation semantics.
- Do not change gameplay, progression, content data, artifact stats or
  glossary definitions.

## Mandatory Safe-Zone Rule

Runtime content must stay inside each asset's `content_rect` from
`docs/design/references/codex/codex_ui_texture_kit_metadata.json`.

Never place portraits, monster art, artifact icons, text labels, glossary
tooltips, tab labels, click/focus hitboxes, scrollbars or hover regions on
decorative metal, dragon ornaments, jewels, spikes or frame corners.

## Acceptance Criteria

- [ ] Codex root, section panel, tabs, entry cards, portraits and glossary
  tooltips use the SCRUM-345 Codex texture kit.
- [ ] Character/monster/artifact art and descriptions are inside content zones
  at 1280x720, 1920x1080 and 2560x1440.
- [ ] Long descriptions scroll or wrap inside their safe zone without touching
  ornament.
- [ ] Keyboard/gamepad focus and mouse hover remain intact.
- [ ] `tests/ui_no_overlap_matrix_test.gd` PASS.
- [ ] `tests/runtime_smoke_ui_test.gd` PASS.
- [ ] Full runtime smoke PASS or unrelated blocker documented.
- [ ] QA screenshots/dumps saved under `build/qa/scrum345/`.

## Design Verification Already Done

- PNG validation PASS: all 10 runtime candidates are RGBA and have transparent
  outer backgrounds.
- Godot import PASS for all new PNGs.
- Current UI no-overlap matrix PASS before runtime integration.
- Current runtime UI smoke PASS before runtime integration.
