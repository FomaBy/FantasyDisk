# Character/Weapon Mechanics Review Table
Статус: done
Версия: 0.2.1
Контур: Codex
Owner: backend/codex-character-weapon-mechanics-review-table
Thread/Worker: current Codex thread
Locked paths: `docs/design/reports/character_weapon_mechanics_review_table.md`, `docs/design/reports/character_weapon_mechanics_review_table.xlsx`, `docs/tasks/codex_backend_character_weapon_mechanics_review_table_task.md`, `docs/process/jira_sync_map.json`, `docs/process/task_board.md`
Jira: SCRUM-878
Исполнитель: Codex

## Context / problem
User request 2026-07-08: prepare a compact review table of every playable character and all of their weapons, with the main distinctive weapon mechanics described clearly enough for product review and future mechanic-change planning.

Existing SCRUM-856 produced a broad class rebalance identity audit. This task is a narrower current-state review artifact: it should be easy to scan, cite current implementation/config sources, and avoid proposing runtime changes unless they are explicitly marked as review notes.

## Required change
- Create `docs/design/reports/character_weapon_mechanics_review_table.md`.
- Follow-up 2026-07-08: export the review table to
  `docs/design/reports/character_weapon_mechanics_review_table.xlsx`.
- Inventory all playable characters/classes and their three weapons from current repository data.
- For each weapon, describe the main distinguishing mechanics: target pattern, range/geometry, cadence/setup/payoff, projectile/zone/summon/deploy behavior, defensive/control/sustain utility, and scaling/stat hook when identifiable.
- Include source references to the implementation/config files used for the table.
- Do not change gameplay, balance numbers, visuals, or runtime behavior in this task.

## Acceptance criteria
- [x] The report includes all current playable characters/classes and all class weapons.
- [x] Each weapon row has a concise, reviewable mechanics description rather than only numeric stats.
- [x] The table distinguishes similar-looking weapons by actual implementation behavior where possible.
- [x] Unclear or clone-like mechanics are marked as review notes, not silently guessed.
- [x] Follow-up Excel workbook contains the same reviewable table data as the markdown report, split into scan-friendly sheets.
- [x] Jira status/comment, local mirror, and task board row reflect the active owner and final result.

## Verification plan
- Inspect `ProgressionData.WEAPONS_BY_CLASS`, weapon config data, current class/weapon docs, and relevant weapon scripts.
- Cross-check against `docs/design/reports/full_class_rebalance_identity_audit.md` without treating the older report as the only source of truth.
- Run documentation/table sanity checks; no runtime smoke is required unless code changes accidentally occur.

## Результат

Done 2026-07-08: created
`docs/design/reports/character_weapon_mechanics_review_table.md` as a
review-friendly table for all 17 playable classes and all 51 current weapon
configs. The report contains a class-kit summary, per-weapon mechanics table,
utility/scaling hooks and cross-kit review hotspots.

Verification:
- `python3` completeness check against `scripts/progression_data_weapons.gd`:
  `weapon_config_ids=51`, `unique_weapon_config_ids=51`, `missing=none`.
- `git diff --check` — PASS.
- Runtime smoke not run: this task changed documentation/task mirrors only and
  did not edit gameplay/runtime files.

Docs/mirrors: report added; task mirror and local task board updated. Jira final
comment/status and commit hashes are recorded after push in the Jira comments.
Disk cleanup: none created.

Follow-up done 2026-07-08: exported the markdown review artifact to
`docs/design/reports/character_weapon_mechanics_review_table.xlsx`.
Workbook sheets:
- `Class Kits`: 17 playable classes and their three-weapon role summaries.
- `Weapons`: 51 current weapon rows with attack mode, mechanics, utility/scaling
  hook and review note.
- `Review Hotspots`: 6 cross-kit mechanic families for product review.
- `Sources`: source/evidence notes from the markdown report.

Follow-up verification:
- Spreadsheet runtime generated and exported the `.xlsx` workbook.
- Rendered and visually checked all workbook sheets as PNG previews.
- Workbook formula/error scan found 0 `#REF!`, `#DIV/0!`, `#VALUE!`,
  `#NAME?` or `#N/A` matches.
- Runtime smoke not run: this follow-up added a spreadsheet artifact and task
  mirror text only; no gameplay/runtime files were changed.

## QA

QA PASSED 2026-07-08:
- Jira moved to `Готово`.
- Verified report coverage against `scripts/progression_data_weapons.gd`: 17/17
  playable classes, 51/51 weapon configs, no extra or missing class/weapon rows.
- `git diff --check` — PASS after whitespace cleanup.
- QA fix commit: `0d2eee12` removed trailing spaces from report metadata lines.
- Runtime smoke not rerun for the whitespace-only QA fix; the earlier sync gate
  passed `tests/runtime_smoke_test.gd` before push.
Disk cleanup: none created.
