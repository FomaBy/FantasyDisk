# Human-readable Multica comments

User directive (Sergey Fomin), 2026-07-15. This applies to every FantasyDisk agent and every Multica issue. Sergey manages the project through Multica comments and must understand a task without opening code, logs, or agent shorthand.

## Main rule

Begin every Multica comment with a short plain-language summary in the language of the person being addressed. For Russian-facing owner communication, that means a concise Russian summary; retain direct historical quotations in their original language. Then provide technical evidence. Maintained instructions and operational wrappers are English, but human-facing replies follow the recipient's language.

- Write 1–5 ordinary sentences without raw logs, arrow shorthand, or unexplained internal code names.
- Explain the product meaning (for example, “hero selection screen” or “Berserk damage”), not only a file or method name.
- SHA, commands, paths, tests, and logs remain necessary, but come after the summary.
- English technical terms are acceptable when the surrounding explanation is clear to the recipient.

## Blockers and problems

Every blocker, bug, conflict, or unexpected problem must state:

```text
Problem: what is broken or preventing progress, in plain language.
Project impact: what does not work or is delayed.
What I tried: a short human explanation.
Unblock action: the concrete action and who can take it.
```

Bad: `blocked: ff-merge failed, dirty tree, see log`.

Good: explain that another owner's uncommitted inventory-screen work prevents a safe merge, that the Berserk balance task waits, that no destructive method was used, and that the owner must commit or remove the WIP.

## All comment types and self-check

This applies to claim/start comments, heartbeats, handoffs, QA verdicts, final reports, and thread replies. Required process fields—owner, lane, locked paths, SHA, and `Disk cleanup:`—remain after the plain-language summary.

Before `multica issue comment add`, ask:

1. Do the first lines explain what happened and what follows?
2. If there is a problem, are the failure, impact, and unblock action clear?
3. Did the summary avoid raw logs, stacks, and unexplained abbreviations?

If any answer is no, rewrite the summary first. Comments are evidence, not authority to override live issue ownership, candidate pins, or lifecycle state.
