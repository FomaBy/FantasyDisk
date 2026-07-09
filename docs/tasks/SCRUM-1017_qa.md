# SCRUM-1017 — independent Design QA: Codex navigation and enlarged icons

Статус: done
Дата: 2026-07-10
Final QA owner: Codex `/root/audit_repo`
Implementation owner: Designer2/Codex `/root/audit_qa`
Implementation commit: `63562574` (Jira sync `9ce035b6`)

## QA-Вердикт

Статус: PASSED

Independent Design QA on fresh `origin/dev` accepts the shared PixelLab-first
source package for the Backend integration tickets SCRUM-954 and SCRUM-958.
QA made no Design or runtime changes.

The accepted direct source is PixelLab UI asset
`27b4e50d-3d97-470d-bb7a-e11eecfb0c5f`,
`scrum1017_codex_navigation_icons_v1`, generated through
`create_ui_asset`. Its committed request/fetch records and manifest identify a
`672x378 RGBA` textless source with SHA-256
`5b89865361d0aed6fc2d2edf457959f42d0ecf0bc3d10875e5ddcde450b535a7`.
Independent pixel inspection confirmed 72,393 fully transparent pixels,
181,623 fully opaque pixels, zero partial-alpha pixels and alpha bbox
`20,15,645,354`. The 1920 base is a pixel-exact nearest-neighbour scale of the
source and matches manifest SHA-256
`203038984b5f497d8a5bd5bb5783143527c9d046fcfc348abd05a08fe999f230`.
No OpenAI/manual/legacy fallback, baked pseudotext or watermark is present.

The recorded planning chronology shows the initial `revise_task` result was
resolved before the PixelLab request; the final independently rerun gate is
`ready_for_image`, `ok=true`, 51/51 elements, with zero errors and warnings.
The bundled compositor was rerun from the immutable base into `/tmp`: character,
monster and artifact states each passed 22/22 zones and reproduced their
committed final PNG hashes exactly (`c30f18cc…`, `c5869326…`, `d6f2552e…`). A
separate 25-check image/provenance probe verified every source/sample/mockup
hash, exact scaling, identical state geometry and that no final-state pixel
change occurs outside a declared content zone.

Visual inspection of final and debug overlays at 1280x720, 1920x1080 and
2560x1440 confirms the hard frame rule: labels, icons, portraits and text stay
inside the real dark interiors; claws, gems, rails, bevels and corners remain
visible. All six Russian tabs fit, including `Характеристики`; there are only
the two declared scrollbar lanes and no bar below the detail preview. The
source's far-right vertical rail is outer frame ornament outside every content
zone. Character, monster and artifact rows use canonical actual images and
Russian names (`Берсерк`, `Темный маг`, `Гитарист`, `Друид`; the four canonical
monster samples; `Точильный камень`, `Полевой бинт`, `Магнитный талисман`,
`Линза охоты`). No category emblem, raw ID, English duplicate or secondary
micro-icon is present in a row.

## Verification

All commands ran from the clean QA worktree at `6dc5169f` through the repository
Godot semaphore where applicable:

- bundled `validate_ui_layout_plan.py`: PASS, 51/51, `ready_for_image`;
- bundled `render_content_zones.py`: PASS, 22/22 for all three states and
  byte-identical final hashes;
- `validate_scrum1017_geometry.py`: PASS for 1280/1920/2560 geometry, safe
  panel gaps, image/preview sizes, scrollbar lanes and identical state zones;
- independent manifest/alpha/hash/zone-containment probe: 25/25 PASS;
- `tests/codex_data_smoke_test.gd`: PASS — 31 monsters, 17 characters,
  161 artifacts, 5 ascensions and 34 stats;
- `tests/asset_reference_integrity_test.gd`: PASS — 195 files and 2424 unique
  `res://` references;
- `tests/dark_fantasy_ui_theme_test.gd`: PASS;
- `tests/runtime_smoke_ui_test.gd`: PASS;
- `tests/ui_no_overlap_matrix_test.gd`: PASS, including Codex at the full
  1152/1280/1536/1600/1920/2560/3840 matrix;
- `tests/runtime_smoke_test.gd`: PASS; duplicate-artifact guard scanned 13,932
  files. The existing dummy-render screenshot-helper backtrace is non-failing.

`fantasydisk-ui-director` made the PixelLab mockup, responsive Control contract
and frame-safe visual review mandatory. `content-zone-image-compositor` made
the pre-generation planning decision, exact content zones and reproducible
zone-only compositing acceptance gates. Both skill contracts are satisfied.

SCRUM-1017 may move to `Готово`. Its completed design contract removes the
`blocked` gate from SCRUM-954 and SCRUM-958; those tickets remain separately
owned Backend work and must implement and test the contract without baking the
mockup into runtime UI.

Disk cleanup: disposable `.godot/`, generated `build/`, `/tmp` validators/logs
and the QA worktree are removed after Jira/GitHub synchronization.
