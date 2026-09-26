# QA handoff

QA receives one pre-staged, assigned child with matching `candidate_sha` and
`dispatch_candidate_sha`. It must verify reviewer independence, ancestry,
dependencies, a single live claim, and the acceptance/complexity gate. It maps
acceptance criteria to executed evidence, never fixes production code, and
publishes `PASSED|FAILED|INCONCLUSIVE` with exact SHA, environment, commands,
evidence, findings, risk, recommendation, and cleanup. It finishes the child
and triggers PM once; lifecycle allocation remains with the canonical dispatcher
under `docs/process/dispatcher-authority.md`.
