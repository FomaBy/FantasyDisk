# UI Mockup Spec - Codex Without Glossary

Status: implemented
Role owner: Back-end
Task: `docs/tasks/backend_remove_codex_glossary_task.md`
Jira: SCRUM-889
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: none
Preview PNG: none
Generated with: existing live Codex runtime/layout; no new PixelLab art

## Source Request

User request, 2026-07-08: remove glossary from the in-game Codex.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CodexNavPanel | PanelContainer | category tabs | existing SCRUM-879/884 responsive rect | full-screen frame relative | existing | 10 | default/focus/selected | CodexFrame safe rect |
| CodexTabs | VBoxContainer | category buttons except glossary | fills CodexNavPanel content zone | parent fill | existing | 20 | default/hover/focus/selected | CodexNavPanel |
| CodexContent | PanelContainer | selected section entry list | existing SCRUM-879/884 responsive rect | full-screen frame relative | existing | 10 | scroll/focus | CodexFrame safe rect |
| CodexCenterListHost | Control | selected section list | fills CodexContent inner zone | parent fill | existing | 20 | scroll/focus | CodexContent |
| CodexDetailPanel | PanelContainer | selected entry portrait/chips/body | existing SCRUM-879/884 responsive rect | full-screen frame relative | existing | 10 | selected entry updates | CodexFrame safe rect |
| CodexBackButton | Button | back to main menu | existing SCRUM-879/884 responsive rect | bottom/left safe rect | existing | 20 | default/hover/focus/pressed | CodexFrame safe rect |

Removed elements:

| ID | Previous type | Removal contract |
| --- | --- | --- |
| CodexTab_glossary | Button | Must not exist in live Codex. |
| CodexSection_glossary | ScrollContainer | Must not be created lazily. |
| CodexSectionList_glossary | VBoxContainer | Must not exist. |
| GlossaryTooltipPanel | Panel | Must remain absent. |

## Frames And Safe Zones

No new frames are generated. The live Codex keeps the existing atlas/meta40
frame stack from SCRUM-879/884:

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| CodexFrame | existing meta40 frame border | existing | existing | frame safe rect from runtime tests | ornament border/corners | yes |
| CodexNavPanel | runtime atlas chip StyleBoxFlat | n/a | n/a | style content margins | panel edge highlight | n/a |
| CodexContent | runtime atlas chip StyleBoxFlat | n/a | n/a | style content margins | panel edge highlight | n/a |
| CodexDetailPanel | runtime atlas chip StyleBoxFlat | n/a | n/a | style content margins | panel edge highlight | n/a |

## Generated Assets

None. This task removes UI content and does not add or replace bitmap art.

## Responsive Rules

- 1280x720: category rail keeps existing responsive width; five live category
  buttons fit without scroll or frame overlap.
- 1920x1080: five live category buttons use the existing Codex tab button kit and
  selected-state behavior.
- 2560x1440: column proportions and frame-safe margins remain unchanged; removed
  glossary slot must not leave an empty list/section placeholder.

## Interaction States

- Button/slot hover: existing Codex tab/card hover states.
- Button/slot pressed: existing tab selected/entry selected states.
- Disabled/locked: unchanged; no glossary disabled placeholder.
- Selected/focus: first live category (`characters`) receives initial focus;
  LB/RB section cycling skips glossary because it is not in `CODEX_SECTIONS`.
- Empty/loading: not applicable.

## Implementation Notes

- Godot scene: runtime-built `_show_codex_screen()` in `scripts/ui_screens.gd`.
- Control node structure: remove glossary from `CODEX_SECTIONS`, icon map and
  `_show_codex_section` builder match.
- Runtime text/icon containers: unchanged for characters, monsters, artifacts,
  stats and ascensions.
- `scripts/glossary.gd` remains as data/helper content; it is not a Codex UI
  section.

## Acceptance Checks

- [x] No new art needed; existing Codex frame/backdrop reused.
- [x] All live/removed elements are listed.
- [x] No runtime content overlaps frame border, ornament, gem, metal, or
  decorative corner.
- [x] Runtime content fits inside existing safe zones at every responsive target.
- [x] Hover/focus/pressed states do not resize or shift layout.
- [x] Automated Codex/UI smoke tests updated to assert glossary absence.

## Deviations

PixelLab mockup generation was intentionally skipped because the task removes an
existing category and does not introduce new layout art, frames, buttons, icons
or visual style. The live runtime layout is the accepted SCRUM-879/884 Codex
frame contract with one category removed.
