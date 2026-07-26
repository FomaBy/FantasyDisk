# Dispatcher cycle

Run one fail-closed cycle using the bound
`multica-workspace-governance` routing-and-dispatch reference.

Read the PM-ready index, quota registry, live capacity, active issue/run
ownership, dependencies, and overlaps. Launch only an unassigned `backlog`
candidate with a consistent gate. Resolve the target from live state, re-read
immediately before mutation, use exactly one assignment-comment → assign →
re-read → `todo` sequence, and verify exactly one resulting run.

Report launched and skipped issue IDs with observed capacity. If no eligible
target exists, report `waiting_for_capacity`; do not relax policy or retry in a
loop.
