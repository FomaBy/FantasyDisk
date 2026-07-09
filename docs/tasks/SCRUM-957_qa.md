# SCRUM-957 — independent Design QA

Статус: done
Дата: 2026-07-10
QA owner: Codex `/root/audit_repo`
Lane: Codex
Implementation commits: `b61fa280`, `a973041e`, `c10b1941`, `dcde96b0`
Jira: SCRUM-957

## Precondition And Scope

Live Jira was `Контроль качества` with the implementation owner released and
no competing QA claim or locked QA-evidence path. QA claimed the issue before
creating a fresh worktree from `origin/dev` `79cbcac1`.
Before verdict, the worktree fast-forwarded to latest `origin/dev` `2f91805e`
and all focused gates plus runtime smoke were rerun on that head.

QA writes are limited to this evidence mirror and the scoped SCRUM-957 entry in
`docs/process/jira_sync_map.json`. All production icons, source references,
previews, scripts, scenes and tests were inspected read-only. No production or
asset correction was made.

## QA-Вердикт

Статус: PASSED

The five requested canonical artifact icons pass provenance, source/runtime,
alpha, padding, readability, style and repository integration acceptance.
No follow-up defect was found.

## Canonical And Provenance Audit

The exact IDs exist in `scripts/progression_data_content.gd` and
`docs/design/content_registry.md`:

- `red_whetstone`, `field_kit`, `magnetic_buckle`, `fast_boots`, `hawk_lens`.
- Runtime paths are exactly
  `assets/sprites/ui/icons/artifacts/artifact_<id>.png`.
- Each `docs/design/references/icons/artifacts/<id>/prompt.md` records one
  independent `gpt-image-2`, quality `high`, `1024x1024` call and the explicit
  SCRUM-957 OpenAI Images override. This ticket-specific override takes
  precedence over the default PixelLab icon route; no unrecorded generator or
  PixelLab fallback is claimed.
- Every source folder contains the prompt, RGB chroma source, RGBA source and
  exact pre-SCRUM-957 runtime snapshot. The five snapshots match the parent
  Git blobs byte-for-byte.

The related SCRUM-956 mapping is also canonical: «Масло темпа» remains
`shop_weapon_cooldown` and «Пыльный артефакт» remains `shop_artifact` in
`scripts/progression_data_shop.gd`; no `dusty_artifact` path was introduced and
`quickstring` was not remapped.

## Independent Image Audit

All runtime files are unique `256x256` RGBA PNGs with alpha extrema `0..255`,
fully transparent corners, non-empty visible content and zero detected
green-dominant chroma-fringe pixels at alpha `>16`. Padding order is
left/top/right/bottom.

| ID | SHA-256 | Alpha bbox | Padding | Visible px at 64/40/32 |
| --- | --- | --- | --- | --- |
| `red_whetstone` | `71e5407889aaf33cdc8858d25d6a5218bfd5ab83e8584eef5bc27a4b96d5473f` | `(36,45)-(220,211)` | `14.06/17.58/14.06/17.58%` | `1219/494/327` |
| `field_kit` | `faf835b98a155b3c0cd15ba5b502faff494d26b85b480ea62e3b041e8a26c672` | `(37,36)-(219,220)` | `14.45/14.06/14.45/14.06%` | `1714/691/450` |
| `magnetic_buckle` | `c1eddb6733b11ad173d3e1d9c11310318d9d7cadb1aa925cf798c342543bf769` | `(36,39)-(220,216)` | `14.06/15.23/14.06/15.62%` | `1304/542/350` |
| `fast_boots` | `f728c23d82587485b31cbae6faec2053afe2670eab903e14431ca19fcd844c48` | `(40,36)-(216,220)` | `15.62/14.06/15.62/14.06%` | `1179/482/319` |
| `hawk_lens` | `efb8a7da96a31157013d1f20c6c642e99a1d437911f323985d7918c1106f91c5` | `(36,41)-(220,215)` | `14.06/16.02/14.06/16.02%` | `1109/451/294` |

Every margin is at least 10%. Visual inspection of the committed contact sheet,
the before/after comparison and all five full-size RGBA sources confirms five
distinct, readable silhouettes: whetstone, bandage kit, magnetic buckle,
lightweight boots and hunting lens. They share the intended restrained
D&D/dark-fantasy material language without baked text, letters, numbers,
watermarks, frame, panel, opaque matte or unrelated scene.

Evidence files exist and agree with the independently recalculated values:

- `docs/design/previews/artifact_icons_scrum957_contact.png` at
  `256/64/40/32` scales;
- `docs/design/previews/artifact_icons_scrum957_existing_comparison.png`;
- `docs/design/previews/artifact_icons_scrum957_report.md`;
- five prompt/source/runtime-reference folders under
  `docs/design/references/icons/artifacts/`.

## Sidecars And Change Boundaries

- All five existing runtime `.import` sidecars are present, have the recorded
  hashes and have no diff in implementation commit `b61fa280`.
- `artifact_quickstring.png`, `shop_shop_weapon_cooldown.png` and
  `shop_shop_artifact.png` match the exclusion hashes recorded by the
  implementation report.
- `artifact_dusty_artifact.png` is absent as required.
- The implementation content diff contains only the five runtime PNGs, five
  source/evidence folders, two previews, report, task mirror and scoped Jira
  map entry; it contains no gameplay/UI code or unrelated production asset.

## Verification

All commands ran from the fresh QA worktree through `tools/godot_gate.py` and
exited 0:

- `tests/ui_icon_registry_smoke_test.gd` — PASS, 49 registry icons.
- `tests/asset_reference_integrity_test.gd` — PASS, 195 files and 2424 unique
  `res://` references.
- `tests/no_duplicate_artifact_files_test.gd` — PASS, 13,857 files scanned.
- `tests/artifacts_606_609_test.gd` — PASS, 10 artifact data/icon records.
- `tests/runtime_smoke_test.gd` — PASS. The dummy-renderer
  `texture_2d_get` screenshot diagnostic is known and non-fatal.

Independent static validation also passed for source/runtime existence, prompt
contract, full SHA-256 values, source modes/sizes, alpha bbox, four-side padding,
transparent corners, zero green-fringe pixels, small-size visible content,
unique hashes, preserved sidecars, pre-change snapshots and exclusion guards.

Git/Jira: QA evidence commit `e85e0015` was pushed to `origin/dev`; live Jira
was moved from `Контроль качества` to `Готово` after the PASS verdict.

Disk cleanup: removed the generated `.godot` cache (`444 MB`) and Python
caches. The now-clean disposable QA worktree and local branch are removed after
the scoped Jira-map sync commit is pushed.
