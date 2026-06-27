# Jira Ticket Templates

Use these templates as content standards, not rigid scripts. Keep sections that matter, omit sections that truly do not apply, and add only domain-specific details that help product, development, or QA.

## Writing Style

Default to concise tickets:

- Write for a non-expert reader: simple words, direct sentences, no hidden assumptions.
- Keep each section to 1 short paragraph or 3-5 bullets unless the user explicitly asks for a deep technical ticket.
- Do not repeat the same fact in `Context / problem`, `Required change`, and `Acceptance criteria`.
- Combine context and problem/current limitation into one short paragraph by default.
- Do not add `Impact` or `Fix direction` sections unless the user explicitly asks for them.
- Do not add generic product-management language, obvious background, or filler.
- Include only information that changes understanding, implementation, testing, priority, or risk.
- Use technical terms only when they identify an exact field, API, object, screen, table, error, or behavior.
- Mark unknowns briefly. Do not invent values such as version, assignee, root cause, customer, or exact impact.
- Do not add an `Example` section by default. Add it only when the user explicitly asks for an example or the ticket cannot be understood/tested without one.

Before writing to Jira, compress the draft: remove any sentence that a developer or QA engineer could delete without losing meaning.

## Standard Description

Use this structure for Task, Improvement, Story, and User Story tickets:

1. `Context / problem`
   - In one short paragraph, state the product area and what is wrong, missing, or requested.
   - Link only the most relevant source ticket/page/example.
   - Mention current behavior that must remain unchanged only if it affects implementation.

2. `Required change`
   - Say exactly what should change.
   - Include filters, permissions, compatibility, performance, privacy, or backend/frontend ownership only when relevant.

3. `Acceptance criteria`
   - Write testable criteria.
   - Include only criteria that QA or dev can verify.
   - Cover edge cases, backward compatibility, performance, permissions/privacy, or regression only when the ticket touches them.
   - Use labels inside criteria when useful, for example `Export action:`, `Filter consistency:`, `Backward compatibility:`.

Optional: `Example`
- Add only if explicitly requested or needed to make the ticket testable.
- Keep it to one concrete scenario, API request, payload, file name, UI flow, data sample, or before/after behavior.

## Bug Description

Use this fuller structure for Bug tickets. Keep OPENTUNNEL-12575-style headings where possible, but include QA-critical details.

1. `Context / problem`
   - In one short paragraph, state the product area, environment/version if known, source link if useful, and the bug in plain language.

2. `Environment`
   - Environment: PROD/ACC/TEST/local.
   - Add version/build/browser/database/customer only when known or necessary.
   - Mark important unknowns briefly.

3. `Steps to reproduce`
   - Numbered steps from a clean starting point.
   - Include only required test data, permissions, filters, payloads, screenshots, timestamps, or logs.
   - If the bug is intermittent, state observed frequency and known triggers.

4. `Expected result`
   - What should happen.

5. `Actual result`
   - What happens instead, including exact errors.

6. `Acceptance criteria`
   - Reproduction no longer occurs.
   - Expected behavior is verified for affected environment/data.
   - Add regression, logs, or data repair criteria only when relevant.

## Title Patterns

- Improvement/Task: `<Area>: <verb> <capability/outcome>`
- Bug: `<Area>: <actual problem or user-visible failure>`
- Story/User Story: `<User/persona> can <capability> so that <benefit>` or a shorter Jira-native variant if the project uses it.

Keep titles specific enough to scan in backlog lists. Avoid vague titles like `CSV reports`, `Fix issue`, or `Improve UI`.

## Similar Ticket Search

Search Jira before creating:

- Same project + quoted product terms from the request.
- Same project + key nouns and action verbs.
- Related projects if the request mentions shared product areas.
- Existing epics for the same release/theme.

Prefer similar tickets that are:

- Same issue type.
- Recently created or updated.
- Resolved or in progress.
- Written by the same team/product area.
- Linked by the user or sharing the same epic/component.

Use similar tickets to infer:

- Expected section names and phrasing.
- Required fields or domain vocabulary.
- Known file naming conventions.
- Data fields that must appear in exports/reports.
- Common acceptance criteria and regression checks.

Do not silently duplicate an open ticket that already covers the same work.

## Self-Review Checklist

Before creating/updating Jira, verify:

- Project/space is resolved and not ambiguous.
- Issue type is appropriate.
- Summary is specific and action-oriented.
- `Context / problem` explains what is needed or wrong without extra history.
- Required change is clear for non-bug tickets and avoids implementation advice unless needed.
- `Example` is omitted unless explicitly requested or needed for clarity.
- Acceptance criteria are testable.
- Bug tickets include environment, reproduction, expected/actual behavior, evidence, and explicit unknowns where needed.
- Similar tickets were checked and no likely duplicate was ignored.
- Any assumptions are either safe, stated in the ticket, or asked as questions before creation.
- No duplicated facts, filler, or generic explanations remain.
