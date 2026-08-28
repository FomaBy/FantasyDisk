#!/usr/bin/env bash
# Installs the repository's local git hooks (FAN-3593). Idempotent: safe to
# re-run after a fresh clone or a new worktree.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
case "$GIT_COMMON_DIR" in
	/*) : ;;
	*) GIT_COMMON_DIR="$ROOT/$GIT_COMMON_DIR" ;;
esac
HOOKS_DIR="$GIT_COMMON_DIR/hooks"
mkdir -p "$HOOKS_DIR"

MARKER="Installed by tools/install_hooks.sh (FAN-3593)"
if [ -e "$HOOKS_DIR/pre-push" ] && ! grep -q "$MARKER" "$HOOKS_DIR/pre-push" 2>/dev/null; then
	echo "error: $HOOKS_DIR/pre-push already exists and was not installed by this script." >&2
	echo "Refusing to overwrite an unrelated pre-push hook. Back it up or remove it, then re-run bash tools/install_hooks.sh." >&2
	exit 1
fi

cat >"$HOOKS_DIR/pre-push" <<'HOOK'
#!/usr/bin/env bash
# Installed by tools/install_hooks.sh (FAN-3593). Blocks a push that would
# land a .gd script without its committed .uid sidecar (or any other static
# quality guard failure) on the remote.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
exec python3 "$ROOT/tools/quality_static_guard.py"
HOOK
chmod +x "$HOOKS_DIR/pre-push"

echo "Installed pre-push hook at $HOOKS_DIR/pre-push"
