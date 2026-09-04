# Versioning and branching

`dev` is the normal serial integration target. `main`, published tags, public binaries, and production are protected release history and require explicit separately scoped authorization. Never infer release permission from a refactor or feature card.

Developers work in isolated task branches/worktrees from a fresh declared base, preserve unrelated changes, run required checks, and push an immutable candidate. A changed candidate creates a new SHA and requires independent review again. Same-card QA verifies the exact candidate; a dedicated integrator promotes approved content to `dev` without content edits.

Do not force-push, rewrite protected history, push a probe merge, or use a temporary merge commit as an integration commit. A mergeability probe uses GitHub metadata or `git merge --no-commit --no-ff` followed by `git merge --abort` in a disposable worktree. Integration is serialized by the `git:FomaBy/FantasyDisk:dev` lease.

After a successful push to `origin/dev`, fast-forward `/Users/sergeyfomin/Documents/AI Agent` only when it exists, is clean, and can fast-forward. Never overwrite operator WIP; record a successful mirror SHA or the non-blocking reason it was skipped.

Release work requires full ancestry/tags, an exact source, final native Windows validation, authorized publication artifacts, and separately authorized external/financial actions. Do not change canonical IDs, save formats, art provenance, localisation, or balance/RNG behaviour without explicit acceptance criteria.
