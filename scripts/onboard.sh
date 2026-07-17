#!/usr/bin/env bash
# usage: bash scripts/onboard.sh
#
# FantasyDisk one-line onboarding. Run ONCE after cloning the repo.
# Symlinks repo-tracked skills into your home Codex/Claude skill dirs and
# prints a short orientation banner. Safe to re-run (idempotent).

set -euo pipefail

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

# The release skill was historically copied as a real directory by older
# onboarding runs.  This is the exact repo-owned 179-line snapshot that is
# safe to replace; any other real directory may contain operator data and must
# remain untouched.  The tree fingerprint includes every entry and every file
# hash, so an added or changed local file cannot pass this allowlist.
KNOWN_LEGACY_RELEASE_SKILL_MD_SHA256="9ae5871b81165d655f262efbae410891af4eb384504dd7158c2de79d9a348a50"
KNOWN_LEGACY_RELEASE_SKILL_TREE_SHA256="e8a6fc5c6ec25892d6043bcf605064c54a6ba54be85593314b5b26786ea865d9"

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

# Print a deterministic fingerprint for a skill directory without exposing
# file contents.  Entry types are included so symlinks and empty directories
# containing operator data cannot be mistaken for the known legacy snapshot.
tree_fingerprint() {
  local dir="$1"
  (
    cd "$dir" || exit 1
    find -P . ! -path . -print | LC_ALL=C sort | while IFS= read -r rel; do
      if [ -d "$rel" ]; then
        printf 'D\t%s\n' "$rel"
      elif [ -f "$rel" ]; then
        hash="$(sha256_file "$rel")" || exit 1
        printf 'F\t%s\t%s\n' "$rel" "$hash"
      else
        printf 'O\t%s\n' "$rel"
      fi
    done
  ) | shasum -a 256 | awk '{print $1}'
}

sync_release_skill_dir() {
  local src_dir="$1"
  local dest="$2"
  local source_tree target_tree target_skill_hash

  source_tree="$(tree_fingerprint "$src_dir")" || {
    printf '  BLOCK %s (cannot fingerprint repo skill source)\n' "$dest" >&2
    return 1
  }
  target_tree="$(tree_fingerprint "$dest")" || {
    printf '  BLOCK %s (cannot inspect existing real directory; kept)\n' "$dest" >&2
    return 1
  }

  if [ -f "$dest/SKILL.md" ]; then
    target_skill_hash="$(sha256_file "$dest/SKILL.md")" || {
      printf '  BLOCK %s (cannot inspect SKILL.md; kept)\n' "$dest" >&2
      return 1
    }
  else
    target_skill_hash=""
  fi

  if [ "$target_tree" = "$KNOWN_LEGACY_RELEASE_SKILL_TREE_SHA256" ] \
    && [ "$target_skill_hash" = "$KNOWN_LEGACY_RELEASE_SKILL_MD_SHA256" ]; then
    printf '  MIGRATE %s (known repo-owned legacy release skill)\n' "$dest"
  elif [ "$target_tree" = "$source_tree" ]; then
    printf '  relink %s (exact repo mirror)\n' "$dest"
  else
    printf '  BLOCK %s (unknown real dir — preserved; remove or review it manually before relinking)\n' "$dest" >&2
    return 1
  fi

  rm -rf "$dest"
  ln -s "$src_dir" "$dest"
}

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

    # SAFETY: only the known repo-owned release snapshot may be migrated. Any
    # other real release directory may hold local secrets/operator WIP and is
    # preserved with a fail-closed blocker. Other skills retain the historical
    # skip behavior because their provenance is not part of this migration.
    if [ -d "$dest" ] && [ ! -h "$dest" ]; then
      if [ "$name" = "fantasydisk-release-director" ]; then
        sync_release_skill_dir "$skill_path" "$dest"
      else
        printf '  SKIP %s (existing real dir — kept; remove it manually to relink)\n' "$dest"
      fi
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

# (3) Claude skills: <repo>/.claude/skills/* -> ~/.claude/skills/<name>
printf 'Linking Claude skills...\n'
link_skills "$REPO_ROOT/.claude/skills" "$HOME/.claude/skills"

# (4) Remove only the retired repo-owned background autoland hook setting.
#     Preserve any unrelated custom hooksPath configured by the user.
LEGACY_HOOKS_PATH="$(git -C "$REPO_ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
case "$LEGACY_HOOKS_PATH" in
  .githooks|"$REPO_ROOT/.githooks")
    git -C "$REPO_ROOT" config --local --unset core.hooksPath
    printf 'Retired background autoland hook disabled.\n'
    ;;
esac

# (5) Multica runtime check. Onboarding stays usable on machines that only run
#     the game, so a missing CLI is a warning rather than a failure.
if command -v multica >/dev/null 2>&1; then
  if multica daemon status >/dev/null 2>&1; then
    printf 'Multica daemon connected.\n'
  else
    printf 'WARN: Multica CLI found, but daemon is not connected; run multica setup cloud.\n'
  fi
else
  printf 'WARN: Multica CLI not found; agent task execution requires Multica.\n'
fi

# (6) Onboarding banner.
cat <<'BANNER'

============================================================
  FantasyDisk — onboarding complete
============================================================
  Start here:
    .claude/skills/fantasydisk-onboarding/SKILL.md
    docs/process/ai_agent_memorandum.md
    docs/process/multica_workflow.md

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
