# SCRUM-952 — Hero Select trait, strengths and weaknesses copy

Статус: done (independent re-QA PASSED)
Версия: 0.2.1
Jira: SCRUM-952
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-next2`

## Scope

- shared player-facing class-trait data and Codex projection;
- Hero Select dossier hierarchy `Особенность` → `Плюсы` → `Минусы`;
- responsive 720p / 1080p / 2K fit and frame-safe QA;
- PixelLab-first mockup/spec and focused regression coverage.

No Hero Select frame, portrait, animation, stat, ascension or carousel art is
replaced. Canonical trait mechanics come from SCRUM-953 and
`docs/design/class_traits_registry.md`.

## Progress

- Jira claimed and exact locks recorded.
- SCRUM-953 is `Готово`; all 17 final traits are present in the canonical
  registry and current `CLASS_TRAITS` data.
- PixelLab mockup job `c72b6dba-895e-4f6a-93a1-1a5a36934a54` submitted.
- Pre-generation content-zone plan validated as `ready_for_image`.
- PixelLab source accepted after visual review. The first composite was rejected
  for crossing the center ornament; remeasured zones now pass `fit_report.json`
  and stay inside the three empty bands.
- Shared short trait copy, Codex projection and native Hero Select hierarchy are
  implemented. Canonical sections have no line cap/ellipsis; dossier scrolling
  is focusable and resets when the hero changes.
- Reviewer-found source drift is corrected: Sniper/Priest/Druid registry status
  is implemented, Priest no longer promises weapon sustain, and Druid mentions
  the implemented Wild Force Aura.

## Implementation result

- `CLASS_TRAITS` now carries concise `short_description` copy for all 17
  classes while preserving detailed mechanics in `description`.
- Canonical `CHARACTER_CONFIGS.strengths/weaknesses` were shortened into
  concrete selection copy; Codex keeps projecting those same fields.
- `CodexData.characters()` projects one shared `trait` record with id, title,
  short description and details.
- Hero Select renders `Особенность — <title>: <copy>` → `Плюсы:` → `Минусы:`
  before extended prose. These labels have no line cap or ellipsis, use full
  tooltips, and never leave `HS4DossierScroll`.
- The dossier scroll is keyboard/gamepad focusable, resets on every hero change,
  and stays inside the existing frame content area. No frame/art/portrait/stat/
  ascension/carousel geometry changed.

## Verification

- `hero_select_scrum952_trait_copy_test.gd`: PASS headless and actual Metal
  windowed, all 17 heroes at 1280×720 / 1920×1080 / 2560×1440; 1080p/2K show
  all three decision sections without scrolling, 720p proves scroll reachability;
  windowed teardown is clean with zero ObjectDB/resource/Ogg lifecycle errors.
- Visual inspection: final Metal captures at all three target viewports keep
  content inside the dossier and outer frame ornaments. An intermediate layout
  that hid plus/minus copy below generic prose was rejected and reordered.
- PASS: `hero_select_pixellab_layout_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `codex_data_smoke_test.gd`, `progression_data_character_contract_test.gd`,
  `gamepad_menu_focus_test.gd`, `gamepad_full_flow_smoke_test.gd`,
  `runtime_smoke_ui_test.gd`, and full `runtime_smoke_test.gd` (known dummy
  renderer screenshot diagnostic only).

Post-rebase green gate on fresh `origin/dev` `4b8b89f73`: focused SCRUM-952 and
no-overlap PASS; the first parallel full-runtime attempt was invalidated by a
shared `user://` autosave race, then the authoritative isolated HOME/XDG rerun
passed completely. Implementation commit: `6812188f5`.

Disk cleanup: pending post-land removal of the 446 MiB task `.godot/` cache,
transient `build/qa/scrum952` captures and task worktree.

Thread cleanup: not a disposable worker thread.

## Initial QA Verdict (2026-07-11)

Статус: **FAILED**

Проверено на `origin/dev` `50016c95e` независимым QA/Codex
`/root/qa_952_trait_copy`:

- PixelLab MCP provenance (`c72b6dba-895e-4f6a-93a1-1a5a36934a54`),
  `ready_for_image` plan, accepted source, remeasured zones and fit report;
- все 17 `CLASS_TRAITS`, изолированные `class_trait()` copies и точные Codex
  projections;
- точная иерархия `Особенность` → `Плюсы` → `Минусы` для всех 17 героев at
  1280×720 / 1920×1080 / 2560×1440;
- 1080p/2K показывают все три decision sections без прокрутки; Metal screenshots
  сохраняют текст внутри dossier/frame safe-zone и не перекрывают орнамент;
- verbose Metal lifecycle clean: без `SCRIPT ERROR`, `ObjectDB` leaks,
  `resources still in use`, Ogg или `ERROR` diagnostics;
- PASS: Hero Select layout, UI no-overlap, Codex data, character contract,
  gamepad core/in-run/menu, gamepad full-flow два раза подряд, runtime UI,
  animation, meta progression и полный runtime smoke. Известный dummy-renderer
  screenshot diagnostic полного runtime не является test failure.

Краевые случаи:

- при 1280×720 досье Друида имеет `max_scroll=104`, смена героя через настоящую
  carousel signal корректно сбрасывает `scroll_vertical` в `0`;
- physical PageDown, semantic `ui_page_down`, gamepad D-pad и right-stick input
  не меняют `scroll_vertical`; D-pad Down сразу уводит focus на
  `HS4ChooseButton`;
- следовательно, нижний dossier copy недоступен с клавиатуры/геймпада без мыши.

Баги:

- `SCRUM-1046` — **blocking** для SCRUM-952: 720p dossier cannot be scrolled by
  keyboard or gamepad;
- `SCRUM-1047` — unrelated regression found by the broad gate: legacy hammer
  targeting smoke still uses a circular boundary predating the accepted
  SCRUM-1043 offset/scaled hit ellipse (reproduced 3/3).

Production code, art and shared data QA не изменял. SCRUM-952 возвращён в Jira
`К выполнению` до исправления SCRUM-1046.

## Blocking fix SCRUM-1046 (implementation)

Backend diagnosis confirmed that focusability alone did not make
`HS4DossierScroll` scroll-first. The local fix consumes vertical and Page
actions while overflow remains, retains dossier focus, and transfers to
Back/Choose only at the real boundaries. Physical keyboard and D-pad assertions
now cover the 1280×720 Druid overflow plus carousel reset. Visual geometry,
trait/Codex data and the accepted PixelLab content zones are unchanged.

SCRUM-952 remains `К выполнению` until SCRUM-1046 independent QA and a parent
re-QA verdict; implementation success alone does not erase the prior QA FAIL.

## QA-Вердикт (2026-07-11 Re-QA)

Статус: PASSED

QA owner: QA/Codex `/root/qa_scrum1046_952`. Parent re-QA was claimed only
after SCRUM-1046 received its independent PASS, moved to `Готово`, and released
all locks. Production code/data/art remained read-only throughout re-QA.

Acceptance was independently reconfirmed on fresh production `origin/dev`:

- implementation `6812188f5`, handoff `c1720350a`, original routing
  `50016c95e`, prior RED evidence `6246ecb80`, blocker fix `9070a85a9` and
  SCRUM-1046 PASS `fe15cad63` are all ancestors of production `dev`;
- PixelLab MCP provenance is exact: source
  `c72b6dba-895e-4f6a-93a1-1a5a36934a54`, provider manifest, accepted source
  PNG, `ready_for_image` plan, remeasured layout and `fit_report.json` with
  `ok: true` for all three trait/strength/weakness content zones;
- all 17 `CLASS_TRAITS`, isolated copies and Codex projections are complete and
  exact. `codex_data_smoke_test.gd` reports 17 characters and
  `progression_data_character_contract_test.gd` reports 17 valid configs;
- focused SCRUM-952/1046 coverage passes all 17 heroes at 1280×720,
  1920×1080 and 2560×1440 with the exact native hierarchy
  `Особенность → Плюсы → Минусы` and no truncation;
- 1080p/2K renderer captures show all three decision sections in the empty
  dossier zone without touching the frame ornament. The 720p lane has real
  Druid overflow and is now keyboard/gamepad reachable;
- physical Down/Up/PageDown/PageUp and D-pad Down press/release scroll first,
  retain dossier focus while content remains, hand to Back/Choose only at the
  boundaries, and hero change resets scroll to zero;
- focused coverage passes headless and actual Metal. Metal teardown is clean:
  no `SCRIPT ERROR`, `ObjectDB` leak, resources-still-in-use, Ogg or `ERROR:`
  lifecycle diagnostics;
- regression PASS: Hero Select PixelLab layout, SCRUM-1026 ascension layout and
  input, gamepad menu focus, gamepad full-flow twice, UI no-overlap, runtime UI
  and isolated full runtime smoke.

Audit: SCRUM-1046 adds only a local dossier `gui_input` contract and focused
assertions. There is no global input hook, raw right-stick branch, visual
geometry change or mutation of the accepted trait/Codex/PixelLab package.

Verdict: **PASSED**. The previous blocker is closed and SCRUM-952 may move to
`Готово`.
