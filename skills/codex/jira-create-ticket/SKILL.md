---
name: jira-create-ticket
description: Create high-quality Jira tickets from user notes, source links, screenshots, related issues, or rough product thoughts. Use when the user asks to "create ticket", create or draft a Jira Task, Improvement, Bug, Story, or User Story, or standardize a ticket description like OPENTUNNEL-12575.
---

# Jira Create Ticket

## Goal

Create Jira tickets that are ready for development, QA, and backlog refinement. Think like a product manager, scrum master, and QA engineer: clarify the problem, infer missing requirements from context and similar tickets, preserve user intent, and produce a short but complete ticket.

Default style: write only necessary information. Keep the ticket clear enough for a non-expert to understand, but concise enough that a product manager, developer, and QA engineer can scan it quickly.

## Trigger Pattern

When the user says:

`create ticket`

or adds a project/space hint like:

`create ticket with information for OT/MID/I2/CC that's spaces: ...`

Interpret any short code as a Jira project/space hint, not as guaranteed truth. Resolve it in Jira before creating the issue.

Known likely aliases:

- `OT`: OpenTunnel / `OPENTUNNEL`
- `CC`: Cloud Connector or related connector project; verify
- `MID`: Managed Integration Dashboard or related project; verify
- `I2`: Integration/iDashboard-related project; verify

If multiple Jira projects match an alias, ask which project to use before creating the ticket.

## Workflow

1. **Collect the request**
   - Extract target project/space, issue type, desired title, user notes, source links, screenshots, logs, and related tickets.
   - If issue type is not explicit, infer it:
     - `Bug`: broken existing behavior, regression, error, data loss, security issue.
     - `Improvement`: enhance existing feature or workflow.
     - `Task`: technical/internal work without direct user-facing story.
     - `Story` / `User Story`: user-facing capability with business value.
   - Ask a concise question if project, issue type, or core outcome is ambiguous enough that a wrong assumption would create a bad ticket.

2. **Check Jira context before writing**
   - Resolve the project via Jira project search or known key.
   - Fetch any linked/source tickets the user provided.
   - Search for similar tickets in the same project and nearby projects using 3-6 keywords from the request. Prefer recent and same issue type, then same epic/component/domain.
   - Read 2-5 relevant similar tickets and copy useful conventions: section names, acceptance criteria style, field vocabulary, filenames, API naming, expected CSV naming, error wording, and related epics.
   - If the user asks to mirror a template ticket such as `OPENTUNNEL-12575`, fetch it and match its structure.

3. **Draft the ticket**
   - Use English unless the user explicitly asks for another language.
   - Use Jira Atlassian Document Format for the description when updating/creating Jira via API.
   - Use the standard structure from `references/ticket-templates.md`.
   - Preserve concrete facts from the user's request; mark inferred requirements as implementation direction, not confirmed facts.
   - Include links to related Jira issues and Confluence pages when available.
   - Prefer precise, testable acceptance criteria over vague statements.
   - Keep sections short. Combine context and problem/current limitation into one short paragraph.
   - Do not add `Impact` or `Fix direction` sections unless the user explicitly asks for them.
   - Do not repeat the same fact in multiple sections unless it is necessary for clarity.
   - Prefer plain product language over architecture language unless technical detail is needed for implementation or QA.
   - Do not add an `Example` section by default. Add it only if the user explicitly asks for an example or the ticket is unclear without one.

4. **Self-review before writing**
   - Check the draft against the checklist in `references/ticket-templates.md`.
   - Verify that the title, issue type, and project make sense.
   - Verify that acceptance criteria are testable and cover positive path, filter/state behavior, edge cases, compatibility, and regression risk.
   - For bugs, verify that reproduction evidence, expected/actual behavior, environment, and severity signals are present or explicitly marked as unknown.
   - Delete filler, duplicated context, generic explanations, and requirements that do not change development or QA behavior.
   - Delete optional sections such as `Example` unless they materially improve clarity.
   - Ask questions before creating if missing details would materially change scope, implementation, or testing.

5. **Create or update in Jira**
   - If the user asked to create a ticket, create it only after project and issue type are clear.
   - If the user asks for a dummy ticket, create it in the requested project but make the summary clearly identifiable as a test/dummy ticket.
   - If the user asked to update an existing ticket, update only requested fields unless clearly necessary.
   - After writing, read back the ticket summary and description headings to verify the result.
   - Return the Jira link plus a short summary of what was created/updated.

## Jira Safety

- Never print or store API tokens.
- Use authenticated Jira access already available in the session when possible.
- If authentication is missing, ask for site URL, account email, and token setup details.
- Do not change status, assignee, sprint, rank, priority, labels, components, fix versions, or parent/epic unless requested or clearly confirmed by similar-ticket context and safe to infer.
- Do not create duplicate tickets when a highly similar open ticket already exists; show the likely duplicate and ask whether to update/link instead.

## Resources

- Read `references/ticket-templates.md` when drafting or reviewing ticket content.
