# Attempt 2 (stopped) — preserved record

Attempt 2 of FAN-3982 (2026-09-28, promoter `1cba3f6b`) stopped before any remote
write because the certifying `quality_gate.py --profile changed` run on the then
approved source `338fb7bf…` (tree `7a50852f…`) was red (two whitespace static checks
and the three stale certification-capture suites). The full record was pushed as
commit `9bbea63bd58b3c616b7282fccb55a09c98c731d4` (tree `22ba146b…`) on
`agent/claude-dev-fable/13a5f6ba39b5`; stop comment `01a0e6c3-f66c-7b3c-85e0-f51e5a98b850`.
FAN-3984 fixed both findings; the PM re-pinned this card to the new `dev` tip
`f4d05fea…`. These four text files are copied verbatim from that commit for history;
the 450 KB raw gate log and JSON report of the red run are not carried forward.
The current attempt's report is `../README.md`.
