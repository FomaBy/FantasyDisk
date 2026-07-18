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
KNOWN_LEGACY_RELEASE_SKILL_TREE_SHA256="e06e85fdd5fb3f78cffe172814e8dcc7878d573afe5ba6716b4c0613222da5ad"
RELEASE_SKILL_NAME="fantasydisk-release-director"
# This is intentionally an allowlist, not just a minimum set.  A persistent
# release skill must be a complete, type-safe mirror of the checked repo tree;
# a local extra file is operator data, not something onboarding may copy.
RELEASE_SKILL_FILES='SKILL.md
scripts/build_update_manifest.py
scripts/github_release_publish.py
scripts/github_release_verify.py
scripts/local_release.py
scripts/release_publish.py
scripts/telegram_publish.py'

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

# Return the permission bits without following symlinks.  The legacy allowlist
# is intentionally platform-aware because macOS and GNU stat use different
# format flags.
entry_mode() {
  local mode
  case "$(uname -s)" in
    Darwin) mode="$(stat -f '%Mp%Lp' "$1")" ;;
    *) mode="$(stat -c '%a' "$1")" ;;
  esac
  printf '%04s\n' "$mode" | tr ' ' '0'
}

# Print a deterministic fingerprint for a skill directory without exposing
# file contents.  Entry types and modes are included so symlinks, special
# entries, and permission drift cannot be mistaken for the known legacy
# snapshot.  Extended attributes are a documented platform residual: this
# portable fingerprint does not claim to cover xattr-only drift.
tree_fingerprint() {
  local dir="$1"
  (
    cd "$dir" || exit 1
    find -P . ! -path . -print | LC_ALL=C sort | while IFS= read -r rel; do
      if [ -L "$rel" ]; then
        link_target="$(readlink "$rel")" || exit 1
        printf 'L\t%s\t%s\n' "$rel" "$link_target"
      elif [ -d "$rel" ]; then
        mode="$(entry_mode "$rel")" || exit 1
        printf 'D\t%s\t%s\n' "$rel" "$mode"
      elif [ -f "$rel" ]; then
        hash="$(sha256_file "$rel")" || exit 1
        mode="$(entry_mode "$rel")" || exit 1
        printf 'F\t%s\t%s\t%s\n' "$rel" "$mode" "$hash"
      else
        printf 'O\t%s\n' "$rel"
      fi
    done
  ) | shasum -a 256 | awk '{print $1}'
}

release_skill_tree_is_valid() {
  local dir="$1"
  local actual_files actual_dirs entry

  [ -d "$dir" ] && [ ! -h "$dir" ] || return 1

  # Do not follow symlinks or accept special entries.  The fingerprint below
  # records type/mode/hash, while this allowlist prevents a matching-looking
  # tree from carrying extra or executable operator data into the mirror.
  while IFS= read -r entry; do
    if [ -L "$dir/$entry" ] || { [ ! -d "$dir/$entry" ] && [ ! -f "$dir/$entry" ]; }; then
      return 1
    fi
  done < <(cd "$dir" && find -P . ! -path . -print)

  actual_files="$(cd "$dir" && find -P . -type f -print | sed 's|^./||' | LC_ALL=C sort)"
  actual_dirs="$(cd "$dir" && find -P . ! -path . -type d -print | LC_ALL=C sort)"
  [ "$actual_files" = "$RELEASE_SKILL_FILES" ] && [ "$actual_dirs" = "./scripts" ]
}

release_source_is_verified() {
  local src_dir="$1"
  local relative_source="skills/codex/$RELEASE_SKILL_NAME"
  local file

  if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '  BLOCK %s (release source is not in a Git worktree)\n' "$src_dir" >&2
    return 1
  fi
  if ! release_skill_tree_is_valid "$src_dir"; then
    printf '  BLOCK %s (release source inventory/type check failed)\n' "$src_dir" >&2
    return 1
  fi
  while IFS= read -r file; do
    if ! git -C "$REPO_ROOT" ls-files --error-unmatch "$relative_source/$file" >/dev/null 2>&1; then
      printf '  BLOCK %s (release source contains an untracked required file)\n' "$src_dir" >&2
      return 1
    fi
  done <<< "$RELEASE_SKILL_FILES"
  if ! git -C "$REPO_ROOT" diff --quiet -- "$relative_source" \
    || ! git -C "$REPO_ROOT" diff --cached --quiet -- "$relative_source" \
    || [ -n "$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$relative_source")" ]; then
    printf '  BLOCK %s (release source has local or untracked drift)\n' "$src_dir" >&2
    return 1
  fi
}

path_is_ephemeral_or_repo_owned() {
  local path="$1"
  case "$path" in
    "$REPO_ROOT"|"$REPO_ROOT"/*|*/multica_workspaces/*/*/workdir|*/multica_workspaces/*/*/workdir/*)
      return 0
      ;;
  esac
  return 1
}

prepare_release_mirror() {
  local requested_parent="$HOME/.codex/skill-mirrors/FantasyDisk"
  local git_probe

  mkdir -p "$requested_parent" || return 1
  if [ -h "$requested_parent" ] || [ ! -d "$requested_parent" ]; then
    printf '  BLOCK %s (managed mirror parent must be a real directory)\n' "$requested_parent" >&2
    return 1
  fi
  RELEASE_MIRROR_PARENT="$(cd -P "$requested_parent" && pwd -P)" || return 1
  if path_is_ephemeral_or_repo_owned "$RELEASE_MIRROR_PARENT"; then
    printf '  BLOCK %s (managed mirror must not live in a repo or task worktree)\n' "$RELEASE_MIRROR_PARENT" >&2
    return 1
  fi
  git_probe="$(git -C "$RELEASE_MIRROR_PARENT" rev-parse --is-inside-work-tree 2>/dev/null || true)"
  if [ "$git_probe" = "true" ]; then
    printf '  BLOCK %s (managed mirror must not live in a Git worktree)\n' "$RELEASE_MIRROR_PARENT" >&2
    return 1
  fi
  RELEASE_MIRROR="$RELEASE_MIRROR_PARENT/$RELEASE_SKILL_NAME"
}

release_selection_is_safe_to_replace() {
  local dest="$1"
  local target_tree

  if [ -d "$dest" ] && [ ! -h "$dest" ]; then
    target_tree="$(tree_fingerprint "$dest")" || {
      printf '  BLOCK %s (cannot inspect existing real directory; kept)\n' "$dest" >&2
      return 1
    }
    if [ "$target_tree" != "$KNOWN_LEGACY_RELEASE_SKILL_TREE_SHA256" ]; then
      printf '  BLOCK %s (unknown real dir — preserved; remove or review it manually before relinking)\n' "$dest" >&2
      return 1
    fi
    printf '  MIGRATE %s (known repo-owned legacy release skill)\n' "$dest"
  elif [ -e "$dest" ] && [ ! -h "$dest" ]; then
    printf '  BLOCK %s (existing non-directory entry — preserved)\n' "$dest" >&2
    return 1
  elif [ -h "$dest" ]; then
    # Never resolve or copy an existing link.  It may be dangling, point into
    # a disposable task worktree, or lead to operator WIP.  Once the staged
    # durable mirror is verified, replacing this link is safe: its target is
    # untouched and it can never become the selected source.
    if [ "$(readlink "$dest")" != "$RELEASE_MIRROR" ]; then
      printf '  REJECT %s (untrusted selected link will be replaced after mirror verification)\n' "$dest"
    fi
  fi
}

make_staged_selection_link() {
  local dest="$1"

  mkdir -p "$(dirname "$dest")" || return 1
  RELEASE_SELECTION_STAGE="$(dirname "$dest")/.${RELEASE_SKILL_NAME}.selection.$$"
  if ! ln -s "$RELEASE_MIRROR" "$RELEASE_SELECTION_STAGE"; then
    printf '  BLOCK %s (cannot stage durable selected link)\n' "$dest" >&2
    return 1
  fi
}

activate_staged_selection_link() {
  local dest="$1"

  RELEASE_SELECTION_BACKUP=""
  if [ -d "$dest" ] && [ ! -h "$dest" ]; then
    RELEASE_SELECTION_BACKUP="$(dirname "$dest")/.${RELEASE_SKILL_NAME}.legacy.$$"
    if ! mv "$dest" "$RELEASE_SELECTION_BACKUP"; then
      printf '  BLOCK %s (cannot preserve known legacy directory before activation)\n' "$dest" >&2
      return 1
    fi
  fi
  if ! python3 -c 'import os, sys; os.replace(sys.argv[1], sys.argv[2])' \
    "$RELEASE_SELECTION_STAGE" "$dest"; then
    printf '  BLOCK %s (cannot atomically activate durable selected link)\n' "$dest" >&2
    if [ -n "$RELEASE_SELECTION_BACKUP" ]; then
      mv "$RELEASE_SELECTION_BACKUP" "$dest" || true
      RELEASE_SELECTION_BACKUP=""
    fi
    return 1
  fi
  RELEASE_SELECTION_STAGE=""
}

cleanup_release_stage() {
  if [ -n "${RELEASE_STAGE:-}" ] && [ -d "$RELEASE_STAGE" ]; then
    rm -rf "$RELEASE_STAGE"
  fi
  RELEASE_STAGE=""
  if [ -n "${RELEASE_SELECTION_BACKUP:-}" ] && [ -d "$RELEASE_SELECTION_BACKUP" ]; then
    rm -rf "$RELEASE_SELECTION_BACKUP"
  fi
  RELEASE_SELECTION_BACKUP=""
  if [ -n "${RELEASE_SELECTION_STAGE:-}" ] && [ -h "$RELEASE_SELECTION_STAGE" ]; then
    rm -f "$RELEASE_SELECTION_STAGE"
  fi
  RELEASE_SELECTION_STAGE=""
}

restore_release_mirror() {
  local failed_mirror

  if [ -z "${RELEASE_MIRROR_BACKUP:-}" ]; then
    if [ "${RELEASE_MIRROR_CREATED:-0}" = "1" ] && [ -d "$RELEASE_MIRROR" ]; then
      rm -rf "$RELEASE_MIRROR"
      RELEASE_MIRROR_CREATED="0"
    fi
    return 0
  fi
  failed_mirror="$RELEASE_MIRROR_PARENT/.${RELEASE_SKILL_NAME}.failed.$$"
  if [ -e "$RELEASE_MIRROR" ]; then
    mv "$RELEASE_MIRROR" "$failed_mirror" || return 1
  fi
  mv "$RELEASE_MIRROR_BACKUP" "$RELEASE_MIRROR" || return 1
  RELEASE_MIRROR_BACKUP=""
  RELEASE_MIRROR_CREATED="0"
  [ ! -e "$failed_mirror" ] || rm -rf "$failed_mirror"
}

install_release_skill() {
  local src_dir="$1"
  local dest="$2"
  local source_tree mirror_tree

  RELEASE_STAGE=""
  RELEASE_SELECTION_STAGE=""
  RELEASE_SELECTION_BACKUP=""
  RELEASE_MIRROR_BACKUP=""
  RELEASE_MIRROR_CREATED="0"
  release_source_is_verified "$src_dir" || return 1
  prepare_release_mirror || return 1
  release_selection_is_safe_to_replace "$dest" || return 1
  make_staged_selection_link "$dest" || return 1

  source_tree="$(tree_fingerprint "$src_dir")" || {
    printf '  BLOCK %s (cannot fingerprint verified release source)\n' "$src_dir" >&2
    cleanup_release_stage
    return 1
  }
  if [ -e "$RELEASE_MIRROR" ] || [ -h "$RELEASE_MIRROR" ]; then
    if [ -h "$RELEASE_MIRROR" ] || ! release_skill_tree_is_valid "$RELEASE_MIRROR"; then
      printf '  BLOCK %s (existing managed mirror is not a valid real tree)\n' "$RELEASE_MIRROR" >&2
      cleanup_release_stage
      return 1
    fi
    mirror_tree="$(tree_fingerprint "$RELEASE_MIRROR")" || {
      printf '  BLOCK %s (cannot fingerprint existing managed mirror)\n' "$RELEASE_MIRROR" >&2
      cleanup_release_stage
      return 1
    }
  else
    mirror_tree=""
  fi

  if [ "$mirror_tree" != "$source_tree" ]; then
    RELEASE_STAGE="$RELEASE_MIRROR_PARENT/.${RELEASE_SKILL_NAME}.staging.$$"
    if ! mkdir "$RELEASE_STAGE" || ! cp -R "$src_dir/." "$RELEASE_STAGE" \
      || ! release_skill_tree_is_valid "$RELEASE_STAGE" \
      || [ "$(tree_fingerprint "$RELEASE_STAGE")" != "$source_tree" ]; then
      printf '  BLOCK %s (staged mirror inventory/type/SHA-256 verification failed; kept last known-good mirror)\n' "$RELEASE_MIRROR" >&2
      cleanup_release_stage
      return 1
    fi
    if [ -n "$mirror_tree" ]; then
      RELEASE_MIRROR_BACKUP="$RELEASE_MIRROR_PARENT/.${RELEASE_SKILL_NAME}.backup.$$"
      if ! mv "$RELEASE_MIRROR" "$RELEASE_MIRROR_BACKUP"; then
        printf '  BLOCK %s (cannot prepare atomic mirror replacement)\n' "$RELEASE_MIRROR" >&2
        cleanup_release_stage
        return 1
      fi
    fi
    if ! mv "$RELEASE_STAGE" "$RELEASE_MIRROR"; then
      printf '  BLOCK %s (cannot activate staged mirror; restoring last known-good mirror)\n' "$RELEASE_MIRROR" >&2
      RELEASE_STAGE=""
      restore_release_mirror || true
      cleanup_release_stage
      return 1
    fi
    RELEASE_STAGE=""
    RELEASE_MIRROR_CREATED="1"
    printf '  MIRROR %s (verified staged inventory/type/SHA-256)\n' "$RELEASE_MIRROR"
  else
    printf '  MIRROR %s (verified and up-to-date)\n' "$RELEASE_MIRROR"
  fi

  if ! activate_staged_selection_link "$dest"; then
    cleanup_release_stage
    restore_release_mirror || true
    return 1
  fi
  if [ -n "$RELEASE_MIRROR_BACKUP" ]; then
    rm -rf "$RELEASE_MIRROR_BACKUP"
  fi
  RELEASE_MIRROR_BACKUP=""
  RELEASE_MIRROR_CREATED="0"
  if [ -n "$RELEASE_SELECTION_BACKUP" ]; then
    rm -rf "$RELEASE_SELECTION_BACKUP"
  fi
  RELEASE_SELECTION_BACKUP=""
  printf '  linked %s -> %s\n' "$dest" "$RELEASE_MIRROR"
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

    if [ "$src_dir" = "$REPO_ROOT/skills/codex" ] && [ "$name" = "$RELEASE_SKILL_NAME" ]; then
      install_release_skill "$skill_path" "$dest" || return 1
      linked=$((linked + 1))
      continue
    fi

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
