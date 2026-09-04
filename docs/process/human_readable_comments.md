# Human-readable Multica comments

Write maintained instructions and operational prose in English. Preserve exact machine values, IDs, user quotations, localisation strings, links, and historical evidence unchanged. Comments should lead with the outcome and then give only the evidence a reader needs.

## Delivery comment

State the result, affected scope, exact candidate SHA/tree/base/source ref, changed paths, commands and outcomes, unexecuted checks, residual risk, and next same-card lifecycle state. Do not call unexecuted work a pass. Avoid absolute runtime paths, secrets, stack traces containing credentials, or false performance claims.

## Blocker comment

State impact, checks already made, the precise `waiting_on` condition, and the safe unblock criterion. A broad label, stale dependency, or lack of enthusiasm is not a blocker.

## QA comment

Use the exact verdict vocabulary `PASSED`, `FAILED`, or `INCONCLUSIVE`; identify the exact candidate and map acceptance criteria to executed evidence. QA does not repair production code or select rework.

## Lifecycle rules

One deliverable card contains development, independent same-card QA, bounded rework, and routine exact-content integration. Developers publish immutable candidates; the lifecycle PM admits review under the shared guard, and the dedicated integrator serially promotes approved content into `dev`. Do not create routine QA/DevOps duplicate cards or use mentions as courtesy notifications.

Post comments using the Multica CLI's file-backed content mode. Comments are evidence, not authority to override the live issue, ownership, or candidate pin.
