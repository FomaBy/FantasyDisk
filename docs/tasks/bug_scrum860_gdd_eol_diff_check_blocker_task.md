# Bug: Fresh Clone Diff Check Fails On GDD Line Endings
Статус: done
Версия: 0.2.1
Контур: Codex
Owner: Codex control thread
Thread/Worker: current Codex thread
Locked paths: `source_docs/FantasyDisk_GDD.txt`, `.gitattributes` only if required, this task mirror, `docs/process/jira_sync_map.json`
Jira: SCRUM-866
Исполнитель: Codex
Branch: `dev`
Worktree: `/Users/sergeyfomin/Documents/AI Agent`

## Контекст
Independent SCRUM-860 QA on fresh `origin/dev` failed before functional checks
because `git diff --check` sees `source_docs/FantasyDisk_GDD.txt` as a dirty
CRLF/trailing-whitespace normalization diff. The main checkout hid this through
a local `.git/info/attributes` override, but fresh clones do not have that
override.

## Требования
- [x] Confirm the tracked GDD source is clean in a fresh worktree under the
  repository `.gitattributes` contract.
- [x] Keep the change mechanical: no content rewrite, gameplay, balance, UI, or
  asset changes.
- [x] Re-run `git diff --check` and SCRUM-860 focused QA gates from a clean
  checkout after the fix.
- [x] Sync Jira and close the blocker only after commit and push.

## Acceptance Criteria
- [x] `git ls-files --eol -- source_docs/FantasyDisk_GDD.txt` reports LF in the
  index and working tree, matching `*.txt text eol=lf`.
- [x] A fresh clone/worktree of `origin/dev` has no dirty
  `source_docs/FantasyDisk_GDD.txt` diff.
- [x] SCRUM-860 can receive a truthful independent QA verdict.

## Результат
Removed the stale local `.git/info/attributes` override that masked
`source_docs/FantasyDisk_GDD.txt` as `-text` in this checkout. No tracked GDD
content or index change was required: `origin/dev` already stores the file as LF
once the repository `.gitattributes` contract is allowed to apply.

Verification:
- `git ls-files --eol -- source_docs/FantasyDisk_GDD.txt` reports
  `i/lf w/lf attr/text eol=lf`.
- `git diff --check` PASS.
- Fresh detached worktree `/private/tmp/fantasydisk-scrum866-origincheck` from
  `origin/dev @ 27b57308` has no dirty `source_docs/FantasyDisk_GDD.txt` diff.
- `tests/kill_scaling_identity_test.gd` PASS.
- `tests/doctor_drain_softcap_test.gd` PASS.
- `tests/priest_sustain_softcap_test.gd` PASS.
- `tests/global_survivability_balance_smoke_test.gd` PASS.
- `tests/survivability_scenario_test.gd` PASS.
- `tests/global_damage_balance_smoke_test.gd` PASS.
- `tests/runtime_smoke_test.gd` PASS.

Disk cleanup: removed `/private/tmp/fantasydisk-scrum866-origincheck` and
`/private/tmp/fantasydisk-scrum866-logs`; ran `git worktree prune`.

## QA-Вердикт 2026-07-04
Статус: PASSED

Independent blocker QA passed. `origin/dev @ 27b57308` has a clean
`source_docs/FantasyDisk_GDD.txt` in a fresh detached worktree, the tracked LF
contract is visible via `git ls-files --eol`, whitespace gate passed, and the
SCRUM-860/SCRUM-861 focused balance gates plus runtime smoke passed.
