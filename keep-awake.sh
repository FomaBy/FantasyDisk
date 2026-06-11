#!/usr/bin/env bash
set -euo pipefail

duration="${1:-}"

echo "Keeping this Mac awake. Press Ctrl+C to stop."

if [[ -n "$duration" ]]; then
  echo "Duration: ${duration} seconds"
  exec caffeinate -dimsu -t "$duration"
else
  exec caffeinate -dimsu
fi
