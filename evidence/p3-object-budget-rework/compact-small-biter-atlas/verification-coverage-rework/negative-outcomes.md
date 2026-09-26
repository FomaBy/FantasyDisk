# FAN-3934 — per-negative outcomes (2026-09-13 correction pass)

The final checker executes each negative INSIDE the retained runs (each failure
path appends a specific FAIL line and exits 1). The outcomes below were
produced by driving the checker against deliberately corrupted inputs built at
runtime in a bounded harness (no tracked-file edits); each row cites the
failure line the detector must emit.

| negative | detector failure line (must appear) | outcome |
|---|---|---|
| corrupted duration list (one +0.5) | "negative fixture: corrupted duration list was NOT rejected" absent ⇒ rejection proven | REJECTED (checker PASS; fixture asserts the rejection internally) |
| region shifted by one slot | "negative fixture: shifted region was NOT detected" absent ⇒ detection proven | DETECTED (checker PASS) |
| second consumer contributes no pixels | "simultaneous consumers: ... contributed no rendered pixels" | armed — verified live in the windowed run (capture changes on hide, restores on show) |

Each negative's proof is embedded in the retained checker logs: the windowed
run (checker-windowed-render.log, exit 0) passed BECAUSE the corrupted inputs
were rejected and the real second consumer changed the capture; the same
assertions run in the headless log where applicable. Historical honesty: the
removed "old-checker" logs of the prior handoff were misnamed duplicate runs
(inventoried as missing, not recreated); the INVALID windowed log of the
previous successor is preserved as checker-windowed-render-INVALID-argsmangled.log.
