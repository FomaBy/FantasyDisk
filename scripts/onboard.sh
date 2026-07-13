#!/usr/bin/env bash
# usage: bash scripts/onboard.sh
#
# FantasyDisk one-line onboarding. Run ONCE after cloning the repo.
# Symlinks repo-tracked skills into your home Codex/Claude skill dirs and
# prints a short orientation banner. Safe to re-run (idempotent).

set -eu

# (1) Resolve repo root from this script's own location (works from anywhere).
SCRIPT_SOURCE="$0"
# Follow a symlinked invocation back to the real file.
while [ -h "$SCRIPT_SOURCE" ]; do
  LINK_TARGET="$(readlink "$SCRIPT_SOURCE")"
  case "$LINK_TARGET" in
    /*) SCRIPT_SOURCE="$LINK_TARGET" ;;
    *)  SCRIPT_SOURCE="$(dirname "$SCRIPT_SOURCE")/$LINK_TARGET" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# link_skills <src_dir> <dest_dir>
# Symlinks every immediate subdirectory of <src_dir> into <dest_dir>,
# (re)pointing each link at the repo version. Idempotent: an existing
# symlink, file, or directory at the destination is replaced.
link_skills() {
  src_dir="$1"
  dest_dir="$2"

  # Nothing to do if the source dir is absent.
  [ -d "$src_dir" ] || return 0

  mkdir -p "$dest_dir"

  linked=0
  for skill_path in "$src_dir"/*; do
    # Guard against the no-match case (glob stays literal when empty).
    [ -e "$skill_path" ] || continue
    [ -d "$skill_path" ] || continue

    name="$(basename "$skill_path")"
    dest="$dest_dir/$name"

    # SAFETY: never destroy an existing REAL directory (it may be the machine's
    # own skill copy holding local secrets, e.g. the real Telegram channel). Skip
    # it. Only (re)link when the destination is absent or already a symlink.
    if [ -d "$dest" ] && [ ! -h "$dest" ]; then
      printf '  SKIP %s (existing real dir — kept; remove it manually to relink)\n' "$dest"
      continue
    fi
    if [ -h "$dest" ] || [ -e "$dest" ]; then
      rm -rf "$dest"
    fi
    ln -s "$skill_path" "$dest"
    printf '  linked %s -> %s\n' "$dest" "$skill_path"
    linked=$((linked + 1))
  done

  [ "$linked" -gt 0 ] || printf '  (no skills found in %s)\n' "$src_dir"
}

# (2) Codex skills: <repo>/skills/codex/* -> ~/.codex/skills/<name>
printf 'Linking Codex skills...\n'
link_skills "$REPO_ROOT/skills/codex" "$HOME/.codex/skills"

# (3) Claude skills: <repo>/skills/claude/* -> ~/.claude/skills/<name>
printf 'Linking Claude skills...\n'
link_skills "$REPO_ROOT/skills/claude" "$HOME/.claude/skills"

# (4) Auto-land hook: каждый чат/агент сразу лендит зелёные коммиты в dev
#     (локально + origin). core.hooksPath — per-repo config, поэтому ставим его
#     в КАЖДОМ клоне/worktree при онбординге. Идемпотентно.
if [ -x "$REPO_ROOT/.githooks/post-commit" ]; then
  git -C "$REPO_ROOT" config core.hooksPath "$REPO_ROOT/.githooks"
  printf 'Auto-land hook enabled (core.hooksPath -> %s/.githooks)\n' "$REPO_ROOT"
  printf '  (отключить в этом клоне: git config --unset core.hooksPath  |  разово: FSD_NO_AUTOLAND=1)\n'
fi

# (5) Onboarding banner.
cat <<'BANNER'

============================================================
  FantasyDisk — onboarding complete
============================================================
  Start here:
    .claude/skills/fantasydisk-onboarding/SKILL.md
    docs/process/ai_agent_memorandum.md

  Multica-only rule:
    ALL work lives in Multica (project FantasyDisk, FAN-* issues),
    driven via the `multica` CLI. Every task you pick up or hand
    off is a Multica issue — no out-of-band tasks.
    Legacy Jira (SCRUM-*) is a read-only historical archive; do
    not claim or sync work there. See:
    docs/process/jira_to_multica_cutover.md

  Repo:
    https://github.com/FomaBy/FantasyDisk
============================================================
BANNER
