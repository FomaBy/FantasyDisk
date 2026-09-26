# Context engineering policy

Updated: 2026-07-26

This repository follows the context-engineering principles described in
Anthropic's article
[The new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models).

## Architecture

Context is intentionally layered:

1. Workspace context contains durable cross-project invariants.
2. Agent instructions contain only role and authority deltas.
3. Bound skills route PM, the canonical dispatcher, developer, and QA work to
   the needed procedure; the authority record is
   `docs/process/dispatcher-authority.md`.
4. Repository `AGENTS.md` contains project gotchas and links to domain context.
5. Process/design docs, tests, fixtures, and code are rich references loaded
   only when the current scope needs them.

Do not copy a rule into every layer. Keep one authoritative home and link to it.
Current agent IDs, quota state, reset dates, incident history, temporary paths,
closed issue exceptions, and candidate SHA belong in live Multica state—not
durable prompts.

## Writing guidance

- Assume the model can use professional judgment. State the outcome, authority
  boundary, non-obvious gotchas, and verification contract.
- Keep exact step sequences only for fragile operations such as dispatch,
  secrets, destructive changes, release publication, and exact-SHA QA.
- Prefer expressive command/tool interfaces and enums over long collections of
  examples.
- Put tool-specific behavior with the tool or skill that owns it.
- Use references for detailed workflows, schemas, rubrics, and platform
  variants. Keep references directly discoverable from `AGENTS.md` or
  `SKILL.md`.
- Treat code, tests, fixtures, and structured artifacts as high-fidelity
  references when they describe the expected behavior better than prose.

## Review checklist

- Does the text contain project/team knowledge the model cannot infer locally?
- Is the same policy repeated or contradicted elsewhere?
- Does transient operational state appear in durable context?
- Can a long procedure move behind a role/domain trigger?
- Are safety, ownership, transaction, exact-SHA, and evidence gates still
  explicit?
- Are all referenced files real and is the nearest authoritative source clear?
- Was quality verified with scenarios and diffs, not just a smaller word count?
