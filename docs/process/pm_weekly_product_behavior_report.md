# PM weekly product-behavior report

This is the contract for one weekly number: of everything the FantasyDisk board
finished in a week, what share was work a player can see. PM owns the
classification, `tools/pm_weekly_report.py` owns the counting, and the two are
deliberately separate — the tool never decides what "player-visible" means and
never writes to the board it measures.

Delivery lifecycle, readiness and dispatch live in `docs/process/pm_workflow.md`
and the bound `multica-workspace-governance` references; this document adds only
the report.

## 1. The `product-behavior` label

PM creates or reuses one workspace label, `product-behavior`, and attaches it to
the delivery card whose completion changed what a player experiences. The label
is the only classification input the report reads, so an unlabelled card counts
as pipeline work.

Include when the finished card ships:

- gameplay behavior — mechanics, abilities, ultimates, balance a player feels;
- playable content — classes, weapons, artifacts, enemies, bosses, arenas,
  routes, events;
- art and animation that reach the running game — sprites, VFX, backgrounds,
  icons, audio;
- player-facing UI — screens, HUD, menus, dialogs, readable text and
  localization.

Exclude:

- pure process work — board contracts, documentation, estimation, ownership;
- QA and review cards, including exact-SHA certification of someone else's work;
- integration, release mechanics, CI, tooling and agent-harness work;
- rework that restores previously accepted behavior without adding new behavior.

Two rules settle most boundary cases. A card counts once, on the card that
actually shipped the behavior — a QA card that certifies an ultimate is pipeline
work even though the ultimate is not. And a refactor counts only when a player
could notice the result; an internal cleanup that keeps behavior identical is
pipeline work however large it was.

The classification is a PM decision recorded on the delivery card. It is never
inferred from the title, the assignee or the routing lane, and repository QA
does not certify label mutations.

## 2. Running the report

```bash
python3 tools/pm_weekly_report.py \
    --since 2026-08-30T22:00:00Z --until 2026-09-06T22:00:00Z \
    --snapshot-out build/FAN-3903/week-2026-08-31.json
```

The interval is start-inclusive and end-exclusive: `[--since, --until)`. Both
bounds are RFC3339 and must carry an explicit offset, so a Europe/Warsaw week
can be written either way — `2026-08-31T00:00:00+02:00` and
`2026-08-30T22:00:00Z` are the same instant and select the same cards.

`--format json` prints the same numbers for machine checks. `--label` and
`--project` exist for a dry run against a different label or project; the
defaults are the live ones. Passed alongside `--from-snapshot`, they — like
`--since` and `--until` — are a claim about that snapshot, and a mismatch is
refused rather than silently ignored.

The tool reads Multica only through the CLI, and only through `issue list` and
`issue timeline`. Any other command is refused before a process starts, so the
report cannot write to the board, cannot reopen a terminal card and cannot
touch a label.

## 3. What a completion is

A card counts as completed in the window when it is sitting in `done` and its
**latest** `status_changed` transition into `done` falls inside it. `updated_at`
is never a completion time: a comment, a label or a metadata write moves it
without finishing anything. A card that was reopened and finished again counts
once, at its latest entry into `done`; a card that entered `done` during the
week and was reopened afterwards is not a completion of that week, because the
week's number reports work that actually finished.

`updated_at` is used for one thing only — deciding which timelines are worth
reading. A card last touched before the window cannot have entered `done` inside
it, and a card created at or after the window end cannot have finished before
it. Everything that survives those bounds is dated from its own timeline.

## 4. Refusals

A number nobody can reproduce is worse than no number, so the tool refuses the
whole report — it never publishes a partial count — when:

- a page comes back short while more pages are pending, or larger than the
  100-issue server cap;
- the reported total moves between pages, which means the board changed under
  the read (re-run the report);
- an issue id appears twice, or the final count disagrees with the server;
- the server caps a timeline read, so the latest transition into `done` cannot
  be concluded;
- a card sitting in `done` has no recorded transition into `done`.

The first three are transient: re-run. The last two are data problems worth
raising on the affected card, named in the refusal message.

## 5. The legacy `REWORK` proxy

The report prints a third line: completions whose title carries the standalone
token `REWORK`, case-insensitively (`REWORK:` and `pre-rework` match,
`reworked` and `REWORKS` do not).

This is a title convention from the pre-label era and nothing more. It is **not**
the same-card rework history: a card reworked after a failed review, without
that token in its title, is not counted. Publish it as the legacy title-token
proxy it is; never as "all rework" and never as a rework rate.

## 6. Publication and independent QA

Publish the complete report for a week only after that week has ended. The tool
enforces this: when the inputs were collected before `--until`, it exits 2 and
prints nothing. `--allow-partial` produces the report anyway, marked
`Interval: PARTIAL — not a full week` in its header — an interim reading during
the week, never the week's report.

`--snapshot-out` writes the timestamped immutable inputs: the window, the
collection instant, the population counts, a digest binding the snapshot to the
`done` population it was read from, and one record per scanned card with its
exact source ids, title, labels and completion instant.

```bash
python3 tools/pm_weekly_report.py --from-snapshot build/FAN-3903/week-2026-08-31.json
```

Replay recomputes the published numbers from the snapshot alone, without
touching Multica. That is how independent QA reproduces a report after the live
board has moved on: the same snapshot always renders the same report, byte for
byte, and a snapshot collected mid-week stays partial on replay.

Keep snapshots out of the repository — write them under `build/`, which is
ignored, and attach the snapshot to the card alongside the published report so
the numbers stay checkable.
