# BUG: SCRUM-975 wide Settings title overlaps dragon ornament

Статус: new
Приоритет: high
Роль: Design
Контур: Codex
Owner: unassigned
Thread: n/a
Locked paths when claimed:
`docs/design/references/scrum975_settings_game_tab/**`,
`docs/design/previews/scrum975_settings_game_tab/**`, and this mirror only
Jira: SCRUM-1033
Sprint / fixVersion: `Спринт 0.2.1` / `0.2.1`
Blocked issue: SCRUM-975
Найдено QA при повторной приёмке:
`docs/tasks/SCRUM-975_settings_four_tab_game_design.md`

## Autonomy / Approval

The user pre-approved all in-scope repository work. A Design/Codex worker must
claim SCRUM-1033 in Jira before editing, use FantasyDisk UI Director and the
content-zone workflow, preserve the accepted SCRUM-1030 compact contract, push
the correction to `origin/dev`, and return SCRUM-975 to independent QA.

## Проблема

The canonical wide `settings_title` content zone starts at the left edge of an
ornate PixelLab title plate instead of inside its actual empty interior. At
2560×1440 the zone is `[224,124,620,88]` and the rendered text bounding box is
`[224,140,277,55]`. The left dragon ornament occupies the same area, so the
first title glyphs cover decorative pixels. The exact 1920×1080 derivative
`[168,93,465,66]` preserves the collision.

Independent pixel comparison between the textless 2K base and the final render
found 2,603 rendered title pixels at `x < 330` inside the brown/gold ornament
area. The overlap is also visible in the committed 1920/2560 debug previews.
This violates the global hard rule that content may occupy only an empty frame
interior and fails SCRUM-975 acceptance even though SCRUM-1030 itself passed.

## Acceptance Criteria

- [ ] Correct the 2560 title content zone to the measured empty plate interior
      with explicit ornament thickness plus reserve; regenerate an exact 0.75
      1920 derivative.
- [ ] No title glyph or debug content rectangle overlaps the left/right dragon
      ornaments, gold border, bevel or corner decoration at 1920×1080 and
      2560×1440.
- [ ] Regenerate the canonical guide/report and 1920/2560 final/debug
      previews/reports from committed sources; an exact rerun matches them
      byte-for-byte.
- [ ] Preserve SCRUM-1030 unchanged: complete compact `878×520` canvas,
      `892×306` viewport, `14px` lane, scroll `0/214`, both compact states and
      PixelLab provenance.
- [ ] Planning, focused geometry, all compositor reports, secret/Design-only
      scope/diff checks and full runtime smoke remain green.
- [ ] No runtime GDScript, settings persistence, SCRUM-981/1032 or Claude-owned
      paths are edited.
- [ ] SCRUM-975 passes a fresh independent re-QA after the correction lands.

## QA Evidence

- Source: fresh `origin/dev` `be136ca87`.
- SCRUM-1030 exact correction: PASSED; Jira moved to `Готово`.
- SCRUM-975 re-QA: FAILED only on this separate frame-safety defect.
- PixelLab/compositor sources and runtime code were not modified by QA.
