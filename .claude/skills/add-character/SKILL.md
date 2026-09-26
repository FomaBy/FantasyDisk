---
name: add-character
description: Add one FantasyDisk playable class from the official Class Sheet. Use only when the user explicitly asks to add a new class/character.
---

# Add Character

This is a routing skill, not a full prompt dump. Follow `AGENTS.md` first.

## Hard Gate

New playable classes must come from the Class Sheet in
`docs/design/mechanics_extract.md` / `source_docs/FantasyDisk_Mechanics.xlsx`.
Do not invent classes or attributes. Check `docs/design/content_registry.md`
before starting to confirm the class is not already implemented.

## Required Work Split

- Back-end: class config, three selectable weapons, data-driven mechanics,
  balance, tests, docs.
- Design: character/weapon source art through `fantasydisk-asset-generator`.
- Animator: SpriteFrames/rig/motion through `fantasydisk-pixellab-animation-integrator`.
- QA: separate acceptance pass.

Create Multica issues/handoffs (project FantasyDisk, `FAN-*`) for each discipline
instead of doing all roles in one task unless the user explicitly assigned a full
pipeline owner.

## Acceptance Summary

- Exactly three weapons, each with a distinct gameplay niche and no copied
  existing weapon pattern.
- Uses existing attributes; cross-class stat interpretations stay documented.
- Hero select, Codex, content registry, and relevant balance docs updated.
- Required focused tests and Godot smokes pass.
- Multica/mirrors reflect owner, status, locked paths, results, and QA state.
