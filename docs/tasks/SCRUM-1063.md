# SCRUM-1063 — Hero Select wide carousel / Ascension buttons and cyclic wrap

Статус: done
Версия: 0.2.1
Jira: SCRUM-1063
Контур: Codex
Owner: Backend/UI Codex `/root/scrum1063_hero_carousel`
Branch: `codex/scrum1063-hero-carousel`

## Scope And Locks

Only Hero Select hunks in `scripts/ui_screens.gd`; SCRUM-1063 focused tests and
the necessary Hero Select assertions in existing responsive/gamepad/runtime
tests; PixelLab source/mockup/spec under
`docs/design/{mockups,references,previews}/scrum1063_hero_carousel_wide_buttons/`;
the promoted wide-button runtime asset; Hero Select paragraphs in
`docs/design/current_game_state.md` and `docs/design/systems/menus_ui.md`.
Route Map and every unrelated screen remain read-only.

## Planned Contract

- carousel Previous/Next buttons keep their current responsive height and use
  exactly twice the former width;
- one textless PixelLab wide-button source and one geometry/state helper serve
  carousel arrows and Ascension `−`/`+`, with runtime glyphs inside the empty
  content zone;
- Ascension shows only centered `Возвышение N`; cumulative modifier copy moves
  to tooltips and no long delta remains visible;
- Previous from the first hero/window selects the last hero in the final window;
  Next from the last hero/window selects the first hero in the first window;
- direct visible-slot choice, roster counter, portrait, dossier, stat bars,
  selected-level bounds and input focus remain synchronized;
- responsive acceptance covers 1152×648, 1280×720, 1920×1080 and 2560×1440,
  preserving at least three visible hero slots and strict frame content zones;
  compact slots scale uniformly to 116/132 px where the fixed gold shell cannot
  fit three former 180 px cards beside the doubled arrows.

## Result

Implemented the Hero Select contract and prepared it for independent QA:

- the shared accepted PixelLab plate
  `assets/sprites/ui/frames/hero_select_pixellab/button_asc_minus.png`
  (SHA-256
  `de06e39e0af1ebe2ca32be37c3b670d91709e2230b774d2edfd58ecb46451d5d`)
  now drives carousel and Ascension controls through the same five-state
  9-slice helper; no replacement bitmap was generated because the live PixelLab
  request returned `no generations or credits remaining`, and the task-approved
  existing-source variant passed the frame/content-zone audit;
- responsive wide-control sizes are 142×94 at 1152×648 and 1280×720,
  150×100 at 1920×1080, and 202×134 at 2560×1440; every width is exactly twice
  the recorded former responsive width and every viewport keeps three slots;
- `Возвышение N` is centered exactly, cumulative modifiers are tooltip-only,
  bounds remain disabled correctly, and Previous/Next wrap first↔last through
  pointer, keyboard and gamepad while keeping hero data synchronized;
- UI Director plan, PixelLab provenance, rendered mockups, fit report and four
  full-page previews are committed with the implementation.

Verification: focused SCRUM-1063 matrix PASS; Ascension regression PASS;
PixelLab layout PASS; UI no-overlap matrix PASS; gamepad menu focus PASS;
gamepad full-flow PASS; runtime UI smoke PASS; full runtime smoke PASS.
Independent post-review: PASS with no blocking findings. The dummy renderer's
known null screenshot-texture diagnostic remains non-fatal in the two runtime
smokes.

Disk cleanup: disposable Godot user-data, captures and import cache removed
after the final gate. Jira destination: `Контроль качества` (not `Готово`) for
independent QA.
