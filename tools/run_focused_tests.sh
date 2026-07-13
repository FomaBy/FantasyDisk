#!/usr/bin/env bash
# Compatibility wrapper. The Python runner is portable to Windows, discovers
# inherited suites, isolates user://, and routes Godot through the semaphore.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARGS=(--profile full --skip-static)
if [[ "${SKIP_UMBRELLA:-0}" == "1" ]]; then
	ARGS+=(--skip-umbrella)
fi
exec python3 "${ROOT}/tools/quality_gate.py" "${ARGS[@]}" "$@"
