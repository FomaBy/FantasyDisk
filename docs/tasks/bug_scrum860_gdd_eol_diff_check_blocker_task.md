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
- [x] Normalize the tracked GDD source so a fresh clone is clean under the
  repository `.gitattributes` contract.
- [x] Keep the change mechanical: no content rewrite, gameplay, balance, UI, or
  asset changes.
- [ ] Re-run `git diff --check` and SCRUM-860 focused QA gates from a clean
  checkout after the fix.
- [ ] Sync Jira and close the blocker only after commit and push.

## Acceptance Criteria
- [x] `git ls-files --eol -- source_docs/FantasyDisk_GDD.txt` reports LF in the
  index and working tree, matching `*.txt text eol=lf`.
- [ ] A fresh clone/worktree of `origin/dev` has no dirty
  `source_docs/FantasyDisk_GDD.txt` diff.
- [ ] SCRUM-860 can receive a truthful independent QA verdict.

## Результат
Normalized `source_docs/FantasyDisk_GDD.txt` into the repository LF contract with
`git add --renormalize`, preserving content and changing only line-ending storage.

Verification:
- `git ls-files --eol -- source_docs/FantasyDisk_GDD.txt` reports
  `i/lf w/lf attr/text eol=lf`.
- `git diff --check` PASS.
- Fresh-clone QA is pending after commit/push.

Disk cleanup: no implementation temp clone/cache created.
