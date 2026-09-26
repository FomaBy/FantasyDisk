## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `python ".claude/skills/graphify/run.py" query "<question>"` when graphify-out/graph.json exists. Use the same project runner with `path "<A>" "<B>"` for relationships and `explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- Always verify a graph result against the actual source file before relying on it. Fall back to direct search/read when the graph is missing, stale, incomplete, or the file's language is not indexed (e.g. graphify-out/ absent, `graphify-out/graph.json` older than the file you're checking, or a `.tscn`/`.import`/non-`.gd` file).
- After modifying code, run `python ".claude/skills/graphify/run.py" update .` to keep the graph current (AST-only, no API cost).
- `graphify-out/` is a local build artifact for this project and is git-ignored; each checkout regenerates it with `python ".claude/skills/graphify/run.py" extract . --code-only`.
