## FAN-3962 protected promotion report (2026-09-26, macOS)

**Promotion result: `main` advanced and `v0.3.1` created for the independently
accepted 0.3.1 source.** This report is immutable evidence from the promoter
(Claude dev_high `5c006dd4-45c3-4dd0-b1bb-d5e4a0d7e1f9`). It is not independent
verification, not a package build, and not a public release. Package build,
final native Windows verification and publication remain FAN-3963–FAN-3965.
The only repository change in this candidate is under `evidence/FAN-3962/`.

### Exact identities

| Item | Exact value |
| --- | --- |
| Source (`origin/dev`, unchanged before and after) | `448a0cc12f02eb05bc16becc69fde365021a9a17` |
| Source tree | `3e02df83290741b21d4de37c4fa03e356e20c591` |
| Base (`origin/main` before the write) | `02f358149d08b3cbe895ca87847452836d1e3c70` (tree `0c887fb3c3c6f551da149f923d2a21b649edea34`) |
| Result (`origin/main` after the write) | `1ec3d0dfb8b9a150fef742c088401c6a453e1a2b` |
| Result tree | `3e02df83290741b21d4de37c4fa03e356e20c591` (identical to the source tree) |
| Result parents | first `02f358149d08b3cbe895ca87847452836d1e3c70`, second `448a0cc12f02eb05bc16becc69fde365021a9a17` |
| Result message | `release: FantasyDisk v0.3.1 (merge dev)` |
| Result author/committer | `Claude (FantasyDisk agent) <fomamoney@gmail.com>`, 2026-09-26T01:31:53Z |
| Tag ref `refs/tags/v0.3.1` | annotated tag object `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` |
| Tag target (`v0.3.1^{}`) | `448a0cc12f02eb05bc16becc69fde365021a9a17` (tree `3e02df83290741b21d4de37c4fa03e356e20c591`) |
| Tag name / message / tagger | `v0.3.1` / `FantasyDisk v0.3.1` / `Claude (FantasyDisk agent) <fomamoney@gmail.com>`, 2026-09-26T01:31:53Z |
| Preflight report reviewed by QA | `e7cf845071c6619bbdec0b380f33a8aa75baeed2` (tree `ea0e3088138bb46eeba24fa5be0f1788bdc8ac07`), QA run `01a0db31-e25e-7430-85d8-7e1f8118dbcf`, verdict PASSED |

Precedent followed: `v0.3.0` is annotated tag `d7e516cd…` on `dev` commit
`fd9fd1a4…`, and its `main` merge `02f35814…` shares tree `0c887fb3…` with
that commit. `v0.3.1` uses the same shape: the tag on the `dev` source commit,
and one merge commit on `main` whose tree equals the source tree.

### Gates executed before the write

| Gate | Observed | Verdict |
| --- | --- | --- |
| Authorization and hold | Card description records `owner_release_scope` (Sergey Fomin, 2026-09-23T10:04Z) and the PM protected-promotion admission of 2026-09-26T01:26Z with `dispatch_target_agent_id=5c006dd4…`. FAN-2787 metadata has `workspace_manual_pause=false` and no `administrative-maintenance` key; the FAN-3971 failover record shows the cutover completed at 00:37:17Z. | PASS |
| Dependencies | FAN-3877, FAN-3961, FAN-3970 recorded `done`; `dependency_status=satisfied`; `waiting_on_issue_ids=[]`. | PASS |
| Independent QA of the preflight | `qa_verdict=PASSED` for report candidate `e7cf8450…` on source `448a0cc…`, reviewer `8ceb4992…` (not the author `0d1f7faf…`). | PASS |
| Fresh readback before write (01:32:14Z) | `git ls-remote`: `dev`=`448a0cc…`, `main`=`02f35814…`, `refs/tags/v0.3.1` absent. The push was gated on this exact comparison in the same shell command. | PASS |
| FAN-3905 crash-logger exclusion on `448a0cc` | `git merge-base --is-ancestor 8115041d… 448a0cc…` returned 1; `docs/process/crash_logger.md`, `scripts/crash_logger.gd`, `tests/crash_logger_test.gd`, `changelog.d/FAN-3905.md` absent from the tree; no path matching `crash_logger`; `project.godot` `[autoload]` lists only `AudioManager` and `InputDeviceManager`. AC7 stays INCONCLUSIVE on FAN-3905. | PASS (exclusion only) |
| Disposable merge probe | In a detached worktree at `02f35814…`, `git merge --no-commit --no-ff 448a0cc…` reported an automatic merge; `git write-tree` produced `3e02df83…`; merge aborted and worktree removed. No probe commit was pushed. | PASS |
| Local object construction | `git commit-tree 3e02df83… -p 02f35814… -p 448a0cc…` produced `1ec3d0df…`; `git tag -a v0.3.1 -m "FantasyDisk v0.3.1" 448a0cc…` produced `676c0f6f…`. Objects inspected with `git cat-file` before pushing. | PASS |
| Push | `git push --dry-run --atomic` accepted `02f358149..1ec3d0dfb main` and `[new tag] v0.3.1`. The real `git push --atomic origin 1ec3d0df…:refs/heads/main refs/tags/v0.3.1` exited 0 at 01:32:18Z. No `--force`, no `--force-with-lease`, no tag overwrite. | PASS |

### Readback after the write

`git ls-remote origin` at 01:32:18Z and the GitHub API afterwards agree:
`refs/heads/dev`=`448a0cc…` (unchanged), `refs/heads/main`=`1ec3d0df…`,
`refs/tags/v0.3.1`=`676c0f6f…` (type `tag`), `v0.3.1^{}`=`448a0cc…`.
The API commit object for `1ec3d0df…` reports tree `3e02df83…` and the two
parents above; the API tag object reports `tag=v0.3.1`, message
`FantasyDisk v0.3.1`, and target commit `448a0cc…`. Exact JSON is in
`promotion_readback.json`.

### Recorded open items (unchanged by this promotion)

- FAN-3866 original combat crash: owner-excluded from 0.3.1 delaying conditions; still INCONCLUSIVE on its own card.
- FAN-3905 AC7 overhead: not applicable to this source (logger not integrated); still INCONCLUSIVE on its own card.
- P1/P2 runtime contours were not remeasured after FAN-3877's `e33bded` certification; recorded as an open risk per the PM decision, not a PASS.
- Poster and CHANGELOG keep the 23 September date by PM decision.
- No `dev` push occurred, so the operator test mirror was not touched.

### Next gate

Independent verification by a Claude qa_high reviewer who is neither
`0d1f7faf…` nor `5c006dd4…` must compare the remote refs above to the approved
content before this card becomes terminal. FAN-3963 packages from tag `v0.3.1`.
