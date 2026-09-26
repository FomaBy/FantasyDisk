# Canonical dispatcher authority

This is the repository contract for the one live Multica dispatcher route.
The control-plane record is authoritative for dispatcher identity, promotion,
capacity, and lifecycle permissions; provider or model names are not routing
authority.

Authority ID: `dispatcher-authority:v1:4874c472-e690-4801-ab62-2608175d5251`

Authority revision: `2026-08-25T08:48:36Z`

Control-plane source: `FAN-3436`.

The active repository surfaces must point back to this record and fail closed
when the ID or revision drifts. Validate the contract with:

```bash
python3 tools/validate_dispatcher_contract.py
```

Historical Jira and migration material remains read-only historical context.
It is excluded from runtime dispatch validation and must never be used to
assign work, change lifecycle state, or select a worker.
