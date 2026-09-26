## FAN-3975 protected promotion report — FantasyDisk v0.3.2 (2026-09-26, macOS)

**Promotion result: `main` advanced and `v0.3.2` created for the independently
accepted 0.3.2 source.** This is the promoter's immutable evidence (Claude Dev
Fable `1cba3f6b-908a-4ba0-9baa-a849880b5682`). It is not independent
verification, not a package build and not a public release; those remain
FAN-3976, FAN-3964 and FAN-3965. The only repository change in this candidate
is under `evidence/FAN-3975/`. No `dev` push happened, so the operator test
mirror was not touched.

### Exact identities

| Item | Exact value |
| --- | --- |
| Source S (`origin/dev`, unchanged before and after) | `36340c473772781edafffb61ff1d8cc7caa42024` |
| Source tree | `1a361d628d8a4160a6f44993f2ed954c50593341` |
| Base (`origin/main` before the write) | `1ec3d0dfb8b9a150fef742c088401c6a453e1a2b` (tree `3e02df83290741b21d4de37c4fa03e356e20c591`) |
| Result (`origin/main` after the write) | `67b24d499082c7f15943253c5e857cd4b2e6892d` |
| Result tree | `1a361d628d8a4160a6f44993f2ed954c50593341` (identical to the source tree) |
| Result parents | first `1ec3d0dfb8b9a150fef742c088401c6a453e1a2b`, second `36340c473772781edafffb61ff1d8cc7caa42024` |
| Result message | `release: FantasyDisk v0.3.2 (merge dev)` |
| Result author/committer | `Sergey Fomin <fomamoney@gmail.com>` (the checkout's configured Git identity), 2026-09-26T18:42:50Z |
| Tag ref `refs/tags/v0.3.2` | annotated tag object `90279733311632aec88a70317e18afc67518e6d2` |
| Tag target (`v0.3.2^{}`) | `36340c473772781edafffb61ff1d8cc7caa42024` (tree `1a361d628d8a4160a6f44993f2ed954c50593341`) |
| Tag name / message / tagger | `v0.3.2` / `FantasyDisk v0.3.2` / `Sergey Fomin <fomamoney@gmail.com>`, 2026-09-26T18:42:50Z |
| `v0.3.1` (must never move) | still `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` → `448a0cc12f02eb05bc16becc69fde365021a9a17` |

Precedent followed: `v0.3.1` is annotated tag `676c0f6f…` on `dev` commit
`448a0cc1…`, and its `main` merge `1ec3d0df…` shares tree `3e02df83…` with
that commit (v0.3.0 has the same shape). `v0.3.2` repeats it: the tag on the
`dev` source commit, one non-fast-forward merge commit on `main` whose tree
equals the source tree. The v0.3.0/v0.3.1 objects were authored as
`Claude (FantasyDisk agent) <fomamoney@gmail.com>`; this run kept the
checkout's configured identity per the runtime's Git-identity rule (same
e-mail). Message, parents, tree and tag target are exactly as the card requires.

### Gates executed before the write

| Gate | Observed | Verdict |
| --- | --- | --- |
| Authority and hold | Card description records the FAN-3965 `owner_release_scope` transferred to v0.3.2 on 2026-09-26 (decision FAN-3964 comment `01a0de02-5e8c-7329-a272-b9c302ca98ec`) and the PM admission of 17:37Z with `dispatch_target_agent_id=1cba3f6b…`. FAN-2787: `workspace_manual_pause=false`, no administrative/hold/freeze key, reread at 18:41Z. | PASS |
| Dependency | FAN-3974 `done`; `dependency_status=satisfied`, `waiting_on_issue_ids=[]`; its `candidate_sha` = `qa_candidate_sha` = `integration_result_sha` = S; `qa_verdict=PASSED`, reviewer `d7bc8435…`, run `01a0de91…`; integration run `01a0dec5…`. | PASS |
| Preflight on exact S | See `preflight.md`: six core smoke suites + three supplementary suites exit 0; full certifying gate `passed`, `certifying=true`, 16/16 static, 559/559 Godot, `git_sha`=S; version mapping, scope guard, notes/poster/date, FAN-3973 export exclusions, fsck/LFS fsck all PASS. | PASS |
| Disposable merge probe | Throwaway detached worktree at `1ec3d0df…`: `git merge --no-commit --no-ff 36340c47…` clean, `git write-tree` = `1a361d62…`, aborted, worktree removed. | PASS |
| Local object construction | `git commit-tree 1a361d62… -p 1ec3d0df… -p 36340c47… -m "release: FantasyDisk v0.3.2 (merge dev)"` → `67b24d49…`; `git tag -a v0.3.2 -m "FantasyDisk v0.3.2" 36340c47…` → `90279733…`. Both inspected with `git cat-file -p` before pushing (`push_gate.log`). | PASS |
| Fresh readback before write (18:43:17Z) | `git ls-remote`: `dev`=S, `main`=`1ec3d0df…`, `v0.3.1`=`676c0f6f…`→`448a0cc1…`, `v0.3.2` absent. The push was gated on this comparison plus tree/parents/tag-target equality in the same script (`push_gate.log`, `pre_write_ls_remote.txt`). | PASS |
| Push | `git push --dry-run --atomic` accepted `1ec3d0dfb..67b24d499 main` and `[new tag] v0.3.2`. Real `git push --atomic origin 67b24d49…:refs/heads/main refs/tags/v0.3.2` exit 0, 18:43:18Z → 18:43:22Z. No `--force`, no `--force-with-lease`, no tag overwrite, no other ref touched. | PASS |

### Readback after the write

`git ls-remote origin` at 18:43:22Z (`post_write_ls_remote.txt`) and the GitHub
API afterwards (`api/*.json`) agree: `refs/heads/dev`=`36340c47…` (unchanged),
`refs/heads/main`=`67b24d49…`, `refs/tags/v0.3.2`=`90279733…` (type `tag`),
`v0.3.2^{}`=`36340c47…`, `refs/tags/v0.3.1`=`676c0f6f…`→`448a0cc1…`
(unchanged). The API commit object for `67b24d49…` reports tree `1a361d62…`
and the two parents above; the API tag object reports `tag=v0.3.2`, message
`FantasyDisk v0.3.2`, target commit `36340c47…`. All boolean checks in
`promotion_readback.json` are true.

### Recorded open items (unchanged by this promotion)

- Native Windows performance and final Windows verification stay with FAN-3964.
- Package build from tag `v0.3.2` is FAN-3976; publication is FAN-3965.
- The base/UI smoke logs carry the known benign `Parameter "t" is null.`
  screenshot-helper diagnostic (see `preflight.md`).

### Next gate

Independent verification by a Claude `qa_high` reviewer who is neither the
promoter (`1cba3f6b…`) nor a FAN-3974 author (`3614291e…`) compares the remote
refs above with the approved content. No `dev` integration is required for
this evidence-only candidate.
