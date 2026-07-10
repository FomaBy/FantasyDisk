# BUG: SCRUM-975 wide Settings title overlaps dragon ornament

Статус: review
Приоритет: high
Роль: Design
Контур: Codex
Owner: Design/Codex `/root/scrum1033_design`
Thread: `/root/scrum1033_design`
Branch / worktree: `codex/scrum-1033-settings-title-safe` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1033-settings-title-safe`
Locked paths:
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

- [x] Correct the 2560 title content zone to the measured empty plate interior
      with explicit ornament thickness plus reserve; regenerate an exact 0.75
      1920 derivative.
- [x] No title glyph or debug content rectangle overlaps the left/right dragon
      ornaments, gold border, bevel or corner decoration at 1920×1080 and
      2560×1440.
- [x] Regenerate the canonical guide/report and 1920/2560 final/debug
      previews/reports from committed sources; an exact rerun matches them
      byte-for-byte.
- [x] Preserve SCRUM-1030 unchanged: complete compact `878×520` canvas,
      `892×306` viewport, `14px` lane, scroll `0/214`, both compact states and
      PixelLab provenance.
- [x] Planning, focused geometry, all compositor reports, secret/Design-only
      scope/diff checks and full runtime smoke remain green.
- [x] No runtime GDScript, settings persistence, SCRUM-981/1032 or Claude-owned
      paths are edited.
- [ ] SCRUM-975 passes a fresh independent re-QA after the correction lands.

## QA Evidence

- Source: fresh `origin/dev` `be136ca87`.
- SCRUM-1030 exact correction: PASSED; Jira moved to `Готово`.
- SCRUM-975 re-QA: FAILED only on this separate frame-safety defect.
- PixelLab/compositor sources and runtime code were not modified by QA.

## Design correction result (2026-07-10)

- Design commit `40e968c3d` is pushed directly to `origin/dev`; Jira SCRUM-1033
  is routed to `Контроль качества`, and SCRUM-975 has a fresh re-QA-ready note.
- The 2560 title content rect is now `352,132,392,72`, font 48; the generated
  1920 contract is its exact 0.75 derivative `264,99,294,54`, font 36.
- Conservative ornament/frame bounds and minimum reserve are explicit in
  `spec.md`, `manifest.json` and
  `scrum1033_title_safe.report.json`. The measured reserves are
  2K `13/29/7/8px` and 1080p `10/22/5/6px` (L/R/T/B).
- `validate_scrum1033_title_safe.py` compares the textless PixelLab base with
  each final composite at pixel level. It detects 5,759 changed title pixels at
  2K and 3,770 at 1080p, with `forbidden_overlap_pixels: 0` at both targets.
- Accepted PixelLab source `105dd091-3096-41c5-a1e5-bc3277cfaef0` is reused
  byte-identically: the ornament art is correct, so regenerating it would add
  visual drift without addressing the content-contract defect.
- All affected planning/guide/final/debug/report artifacts were regenerated
  twice from the committed sources and remained byte-identical. The full
  SCRUM-1030 compact plan, top/bottom composites and reports are unchanged from
  `origin/dev`.
- Gates: both planning validators `ready_for_image`; all four compositor
  reports `ok: true`; SCRUM-1030 focused geometry `ok: true`; SCRUM-1033 pixel
  oracle `ok: true`; Python AST/JSON/image checks, secret/scope/diff checks and
  Godot 4.7 `tests/runtime_smoke_test.gd` through the semaphore PASS.
- Runtime/shared UI code, runtime tests, menus/current-state docs, SCRUM-981/
  1032 and all Claude-owned paths were not changed.
- Next owner/status: independent QA must recheck SCRUM-1033 and SCRUM-975 from
  fresh `origin/dev`; Design does not mark either issue `Готово`.
