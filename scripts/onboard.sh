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
RELEASE_VERSIONS_NAME=".${RELEASE_SKILL_NAME}.versions"
RELEASE_LOCK_NAME=".${RELEASE_SKILL_NAME}.lock"

RELEASE_MIRROR_PARENT=""
RELEASE_MIRROR=""
RELEASE_VERSIONS=""
RELEASE_LOCK_DIR=""
RELEASE_LOCK_OWNED="0"
RELEASE_LOCK_OWNER=""
RELEASE_LOCK_RECLAIM_OWNER=""
RELEASE_STAGE=""
RELEASE_SELECTION_STAGE=""
RELEASE_SELECTION_BACKUP=""
RELEASE_SELECTION_DEST=""
RELEASE_MIRROR_STAGE=""
RELEASE_MIRROR_BACKUP=""
RELEASE_INTERRUPT_REQUESTED="0"
RELEASE_TEST_PAUSE_ACTIVE="0"

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

validate_release_versions_root() {
  local expected_path="$RELEASE_MIRROR_PARENT/$RELEASE_VERSIONS_NAME"
  local physical_path

  # The private version store is a trust boundary.  Keep this check ahead of
  # the lock, residue reconciliation, and every glob/read/delete below it.
  # The lexical check also prevents a future caller from passing a path that
  # merely happens to resolve under the managed mirror parent.
  if [ "$RELEASE_VERSIONS" != "$expected_path" ]; then
    printf '  BLOCK %s (private version store must be the managed child path)\n' \
      "$RELEASE_VERSIONS" >&2
    return 1
  fi

  if [ -h "$RELEASE_VERSIONS" ]; then
    printf '  BLOCK %s (private version store must not be a symlink)\n' \
      "$RELEASE_VERSIONS" >&2
    return 1
  elif [ -d "$RELEASE_VERSIONS" ]; then
    :
  elif [ -e "$RELEASE_VERSIONS" ] || [ -p "$RELEASE_VERSIONS" ] \
    || [ -S "$RELEASE_VERSIONS" ] || [ -b "$RELEASE_VERSIONS" ] \
    || [ -c "$RELEASE_VERSIONS" ]; then
    printf '  BLOCK %s (private version store has an unsafe root type)\n' \
      "$RELEASE_VERSIONS" >&2
    return 1
  else
    # An absent root is the only path that onboarding may create.  Use mkdir
    # without -p so a late unexpected entry cannot be silently accepted.
    if ! mkdir "$RELEASE_VERSIONS"; then
      printf '  BLOCK %s (cannot create private version store safely)\n' \
        "$RELEASE_VERSIONS" >&2
      return 1
    fi
  fi

  if [ -h "$RELEASE_VERSIONS" ] || [ ! -d "$RELEASE_VERSIONS" ]; then
    printf '  BLOCK %s (private version store is not a real directory)\n' \
      "$RELEASE_VERSIONS" >&2
    return 1
  fi
  physical_path="$(cd -P "$RELEASE_VERSIONS" && pwd -P)" || {
    printf '  BLOCK %s (private version store path cannot be resolved safely)\n' \
      "$RELEASE_VERSIONS" >&2
    return 1
  }
  if [ "$physical_path" != "$expected_path" ]; then
    printf '  BLOCK %s (private version store resolves outside the managed child)\n' \
      "$RELEASE_VERSIONS" >&2
    return 1
  fi
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
  RELEASE_VERSIONS="$RELEASE_MIRROR_PARENT/$RELEASE_VERSIONS_NAME"
  RELEASE_LOCK_DIR="$RELEASE_MIRROR_PARENT/$RELEASE_LOCK_NAME"
  validate_release_versions_root || return 1
}

release_lock_owner_dir_is_complete() {
  local owner_dir="$1"
  local owner_prefix="${RELEASE_MIRROR_PARENT}/.${RELEASE_SKILL_NAME}.lock-owner."
  local entries line_count lock_pid

  [ -d "$owner_dir" ] && [ ! -h "$owner_dir" ] || return 1
  case "$owner_dir" in
    "$owner_prefix"*) ;;
    *) return 1 ;;
  esac
  [ "$(cd -P "$owner_dir" && pwd -P)" = "$owner_dir" ] || return 1
  entries="$(cd "$owner_dir" && find -P . ! -path . -print | LC_ALL=C sort)" || return 1
  [ "$entries" = "./pid" ] || return 1
  [ -f "$owner_dir/pid" ] && [ ! -h "$owner_dir/pid" ] || return 1
  line_count="$(wc -l < "$owner_dir/pid" | tr -d '[:space:]')" || return 1
  [ "$line_count" = "1" ] || return 1
  lock_pid="$(<"$owner_dir/pid")" || return 1
  case "$lock_pid" in
    ''|0|*[!0-9]*) return 1 ;;
  esac
}

release_lock_owner_target_at() {
  local lock_path="$1"
  local owner_dir

  [ -h "$lock_path" ] || return 1
  owner_dir="$(readlink "$lock_path")" || return 1
  release_lock_owner_dir_is_complete "$owner_dir" || return 1
  printf '%s\n' "$owner_dir"
}

# Return 0 for a complete/live record, 1 for an absent or complete/dead
# record, and 2 for malformed, unreadable, incomplete, or foreign state.
# Callers must never reclaim state in the third case.
release_lock_state_at() {
  local lock_path="$1"
  local owner_dir lock_pid

  if [ ! -e "$lock_path" ] && [ ! -h "$lock_path" ]; then
    return 1
  fi
  owner_dir="$(release_lock_owner_target_at "$lock_path")" || return 2
  lock_pid="$(<"$owner_dir/pid")" || return 2
  if kill -0 "$lock_pid" 2>/dev/null; then
    return 0
  fi
  return 1
}

release_lock_create_owner_record() {
  local owner_variable="$1"
  local owner_dir pid_stage

  owner_dir="$(mktemp -d "$RELEASE_MIRROR_PARENT/.${RELEASE_SKILL_NAME}.lock-owner.XXXXXX")" || return 1
  # Publish the PID into the private owner record before the record can ever
  # become reachable through a canonical lock path.  The caller publishes the
  # completed record with one atomic no-clobber symlink operation.
  printf -v "$owner_variable" '%s' "$owner_dir"
  pid_stage="$owner_dir/.pid.$$"
  if ! (umask 077; printf '%s\n' "$$" > "$pid_stage") \
    || ! mv "$pid_stage" "$owner_dir/pid"; then
    rm -rf "$owner_dir"
    return 1
  fi
  release_lock_owner_dir_is_complete "$owner_dir" || {
    rm -rf "$owner_dir"
    return 1
  }
}

release_lock_publish_owner_record() {
  local owner_dir="$1"
  local lock_path="$2"

  # os.symlink() is atomic and fails when lock_path already exists.  Using
  # Python here avoids mv/ln implementations that may silently place a new
  # entry inside an existing directory instead of failing closed.
  python3 -c 'import os, sys; os.symlink(sys.argv[1], sys.argv[2])' \
    "$owner_dir" "$lock_path"
}

release_lock_discard_owner_record() {
  local owner_dir="$1"

  if [ -n "$owner_dir" ] && [ -d "$owner_dir" ] && [ ! -h "$owner_dir" ]; then
    rm -rf "$owner_dir"
  fi
}

release_lock_reclaim_marker() {
  local marker="$RELEASE_LOCK_DIR.reclaim"
  local marker_state marker_owner

  if [ ! -e "$marker" ] && [ ! -h "$marker" ]; then
    return 0
  fi
  if release_lock_state_at "$marker"; then
    marker_state="0"
  else
    marker_state="$?"
  fi
  case "$marker_state" in
    0)
      printf '  BLOCK %s (another updater is reclaiming the managed mirror lock)\n' \
        "$RELEASE_MIRROR_PARENT" >&2
      return 1
      ;;
    2)
      printf '  BLOCK %s (managed mirror lock reclaimer state is malformed; preserved)\n' \
        "$RELEASE_MIRROR_PARENT" >&2
      return 1
      ;;
    1)
      marker_owner="$(release_lock_owner_target_at "$marker")" || {
        printf '  BLOCK %s (managed mirror lock reclaimer state is malformed; preserved)\n' \
          "$RELEASE_MIRROR_PARENT" >&2
        return 1
      }
      rm -f "$marker" || return 1
      release_lock_discard_owner_record "$marker_owner"
      ;;
  esac
}

release_lock_reconcile_orphan_owners() {
  local owner_dir owner_pid

  for owner_dir in "$RELEASE_MIRROR_PARENT"/.${RELEASE_SKILL_NAME}.lock-owner.*; do
    [ -e "$owner_dir" ] || [ -h "$owner_dir" ] || continue
    [ "$owner_dir" = "${RELEASE_LOCK_OWNER:-}" ] && continue
    [ "$owner_dir" = "${RELEASE_LOCK_RECLAIM_OWNER:-}" ] && continue
    if ! release_lock_owner_dir_is_complete "$owner_dir"; then
      printf '  BLOCK %s (managed mirror lock owner state is incomplete or foreign; preserved)\n' \
        "$owner_dir" >&2
      return 1
    fi
    owner_pid="$(<"$owner_dir/pid")"
    if kill -0 "$owner_pid" 2>/dev/null; then
      printf '  BLOCK %s (another onboarding updater is publishing the managed mirror lock)\n' \
        "$RELEASE_MIRROR_PARENT" >&2
      return 1
    fi
    rm -rf "$owner_dir" || return 1
  done
}

release_lock_start_reclaimer() {
  local marker="$RELEASE_LOCK_DIR.reclaim"

  release_lock_create_owner_record RELEASE_LOCK_RECLAIM_OWNER || return 1
  if ! release_lock_publish_owner_record "$RELEASE_LOCK_RECLAIM_OWNER" "$marker"; then
    release_lock_discard_owner_record "$RELEASE_LOCK_RECLAIM_OWNER"
    RELEASE_LOCK_RECLAIM_OWNER=""
    return 1
  fi
}

release_lock_finish_reclaimer() {
  local marker="$RELEASE_LOCK_DIR.reclaim"
  local linked_owner=""

  if [ -n "${RELEASE_LOCK_RECLAIM_OWNER:-}" ] && [ -h "$marker" ]; then
    linked_owner="$(readlink "$marker" 2>/dev/null || true)"
    if [ "$linked_owner" = "$RELEASE_LOCK_RECLAIM_OWNER" ]; then
      rm -f "$marker" || true
    fi
  fi
  release_lock_discard_owner_record "${RELEASE_LOCK_RECLAIM_OWNER:-}"
  RELEASE_LOCK_RECLAIM_OWNER=""
}

release_lock_reclaim_dead_canonical() {
  local stale_owner current_owner marker_state

  release_lock_start_reclaimer || {
    printf '  BLOCK %s (managed mirror lock changed while starting stale-state reclaim)\n' \
      "$RELEASE_MIRROR_PARENT" >&2
    return 1
  }
  if release_lock_state_at "$RELEASE_LOCK_DIR"; then
    marker_state="0"
  else
    marker_state="$?"
  fi
  if [ "$marker_state" != "1" ]; then
    printf '  BLOCK %s (managed mirror lock changed while reclaiming stale state)\n' \
      "$RELEASE_MIRROR_PARENT" >&2
    return 1
  fi
  stale_owner="$(release_lock_owner_target_at "$RELEASE_LOCK_DIR")" || return 1
  current_owner="$(release_lock_owner_target_at "$RELEASE_LOCK_DIR")" || return 1
  [ "$current_owner" = "$stale_owner" ] || return 1
  rm -f "$RELEASE_LOCK_DIR" || return 1
  release_lock_discard_owner_record "$stale_owner" || return 1
}

acquire_release_lock() {
  local lock_state

  release_lock_reclaim_marker || return 1
  if [ -e "$RELEASE_LOCK_DIR" ] || [ -h "$RELEASE_LOCK_DIR" ]; then
    if release_lock_state_at "$RELEASE_LOCK_DIR"; then
      lock_state="0"
    else
      lock_state="$?"
    fi
    case "$lock_state" in
      0)
        printf '  BLOCK %s (another onboarding updater owns the managed mirror lock)\n' \
          "$RELEASE_MIRROR_PARENT" >&2
        return 1
        ;;
      2)
        printf '  BLOCK %s (managed mirror lock is malformed or foreign; preserved)\n' \
          "$RELEASE_MIRROR_PARENT" >&2
        return 1
        ;;
      1)
        release_lock_reclaim_dead_canonical || {
          release_lock_finish_reclaimer || true
          return 1
        }
        ;;
    esac
  fi

  # A pre-publication owner record is deliberately fail-closed.  It is not
  # the canonical lock yet, but it proves another updater is in the process of
  # publishing one and must not be reclaimed or bypassed.
  release_lock_reconcile_orphan_owners || return 1
  if [ -e "$RELEASE_LOCK_DIR" ] || [ -h "$RELEASE_LOCK_DIR" ]; then
    printf '  BLOCK %s (managed mirror lock changed while acquiring)\n' \
      "$RELEASE_MIRROR_PARENT" >&2
    return 1
  fi

  release_lock_create_owner_record RELEASE_LOCK_OWNER || return 1
  if ! onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_LOCK_PUBLICATION; then
    return 1
  fi
  if ! release_lock_publish_owner_record "$RELEASE_LOCK_OWNER" "$RELEASE_LOCK_DIR"; then
    printf '  BLOCK %s (managed mirror lock changed before publication)\n' \
      "$RELEASE_MIRROR_PARENT" >&2
    return 1
  fi
  RELEASE_LOCK_OWNED="1"
  release_lock_finish_reclaimer
  if ! onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_LOCK_PUBLICATION; then
    return 1
  fi
}

release_lock() {
  local linked_owner=""

  if [ -n "${RELEASE_LOCK_OWNER:-}" ] && [ -h "$RELEASE_LOCK_DIR" ]; then
    linked_owner="$(readlink "$RELEASE_LOCK_DIR" 2>/dev/null || true)"
    if [ "$linked_owner" = "$RELEASE_LOCK_OWNER" ]; then
      rm -f "$RELEASE_LOCK_DIR" || true
    fi
  fi
  release_lock_discard_owner_record "${RELEASE_LOCK_OWNER:-}"
  RELEASE_LOCK_OWNER=""
  RELEASE_LOCK_OWNED="0"
}

onboard_test_pause() {
  local variable_name="$1"
  local marker="${!variable_name:-}"

  [ -n "$marker" ] || return 0
  RELEASE_TEST_PAUSE_ACTIVE="1"
  if ! : > "$marker"; then
    RELEASE_TEST_PAUSE_ACTIVE="0"
    return 1
  fi
  while [ -e "$marker" ]; do
    sleep 0.01
    if [ "${RELEASE_INTERRUPT_REQUESTED:-0}" = "1" ]; then
      RELEASE_TEST_PAUSE_ACTIVE="0"
      return 143
    fi
  done
  RELEASE_TEST_PAUSE_ACTIVE="0"
}

onboard_test_failure_requested() {
  [ "${1:-0}" = "1" ]
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
  local target="$2"

  mkdir -p "$(dirname "$dest")" || return 1
  RELEASE_SELECTION_STAGE="$(dirname "$dest")/.${RELEASE_SKILL_NAME}.selection.$$"
  if ! ln -s "$target" "$RELEASE_SELECTION_STAGE"; then
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

cleanup_release_runtime_residue() {
  local backup residue

  if [ -n "${RELEASE_STAGE:-}" ] && [ -d "$RELEASE_STAGE" ]; then
    rm -rf "$RELEASE_STAGE"
  fi
  RELEASE_STAGE=""
  if [ -n "${RELEASE_MIRROR_STAGE:-}" ] && [ -h "$RELEASE_MIRROR_STAGE" ]; then
    rm -f "$RELEASE_MIRROR_STAGE"
  fi
  RELEASE_MIRROR_STAGE=""
  if [ -n "${RELEASE_SELECTION_STAGE:-}" ] && [ -h "$RELEASE_SELECTION_STAGE" ]; then
    rm -f "$RELEASE_SELECTION_STAGE"
  fi
  RELEASE_SELECTION_STAGE=""
  if [ -n "${RELEASE_SELECTION_BACKUP:-}" ] && [ -d "$RELEASE_SELECTION_BACKUP" ]; then
    if [ -n "${RELEASE_SELECTION_DEST:-}" ] \
      && [ ! -e "$RELEASE_SELECTION_DEST" ] && [ ! -h "$RELEASE_SELECTION_DEST" ]; then
      mv "$RELEASE_SELECTION_BACKUP" "$RELEASE_SELECTION_DEST" || true
    else
      rm -rf "$RELEASE_SELECTION_BACKUP"
    fi
  fi
  RELEASE_SELECTION_BACKUP=""
  if [ -n "${RELEASE_MIRROR_BACKUP:-}" ] && [ -d "$RELEASE_MIRROR_BACKUP" ]; then
    rm -rf "$RELEASE_MIRROR_BACKUP"
  fi
  RELEASE_MIRROR_BACKUP=""
}

reconcile_release_residue() {
  local backup residue

  for residue in \
    "$RELEASE_MIRROR_PARENT"/.${RELEASE_SKILL_NAME}.staging.* \
    "$RELEASE_VERSIONS"/.${RELEASE_SKILL_NAME}.staging.* \
    "$RELEASE_MIRROR_PARENT"/.${RELEASE_SKILL_NAME}.mirror-stage.*; do
    if [ -d "$residue" ] || [ -h "$residue" ]; then
      rm -rf "$residue" || return 1
    fi
  done

  for residue in "$(dirname "$RELEASE_SELECTION_DEST")"/.${RELEASE_SKILL_NAME}.selection.*; do
    if [ -h "$residue" ]; then
      rm -f "$residue" || return 1
    fi
  done

  for backup in "$(dirname "$RELEASE_SELECTION_DEST")"/.${RELEASE_SKILL_NAME}.legacy.*; do
    if [ -d "$backup" ] && [ ! -h "$backup" ]; then
      if [ -e "$RELEASE_SELECTION_DEST" ] || [ -h "$RELEASE_SELECTION_DEST" ]; then
        rm -rf "$backup" || return 1
      elif [ "$(tree_fingerprint "$backup")" = "$KNOWN_LEGACY_RELEASE_SKILL_TREE_SHA256" ]; then
        mv "$backup" "$RELEASE_SELECTION_DEST" || return 1
      else
        printf '  BLOCK %s (stale selection backup is not the known legacy tree; preserved)\n' \
          "$backup" >&2
        return 1
      fi
    fi
  done

  # These backups are created only after selection has committed, so they are
  # never active targets.  Keep the check before removing them in case an
  # operator has placed an unrelated directory under the managed namespace.
  for backup in "$RELEASE_MIRROR_PARENT"/.${RELEASE_SKILL_NAME}.legacy-mirror.*; do
    if [ -d "$backup" ] && [ ! -h "$backup" ]; then
      release_skill_tree_is_valid "$backup" || {
        printf '  BLOCK %s (stale mirror backup is not a valid managed tree; preserved)\n' \
          "$backup" >&2
        return 1
      }
      rm -rf "$backup" || return 1
    fi
  done
}

release_mirror_target() {
  local target

  if [ -h "$RELEASE_MIRROR" ]; then
    target="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$RELEASE_MIRROR")" || return 1
    case "$target" in
      "$RELEASE_VERSIONS"/*) ;;
      *)
        printf '  BLOCK %s (managed mirror pointer leaves the private version store)\n' \
          "$RELEASE_MIRROR" >&2
        return 1
        ;;
    esac
    [ -d "$target" ] && [ ! -h "$target" ] || return 1
    release_skill_tree_is_valid "$target" || return 1
    printf '%s\n' "$target"
  elif [ -d "$RELEASE_MIRROR" ]; then
    release_skill_tree_is_valid "$RELEASE_MIRROR" || return 1
    printf '%s\n' "$RELEASE_MIRROR"
  elif [ -e "$RELEASE_MIRROR" ]; then
    printf '  BLOCK %s (managed mirror is not a directory or trusted version pointer)\n' \
      "$RELEASE_MIRROR" >&2
    return 1
  fi
  return 0
}

activate_mirror_pointer() {
  local target="$1"

  RELEASE_MIRROR_STAGE="$RELEASE_MIRROR_PARENT/.${RELEASE_SKILL_NAME}.mirror-stage.$$"
  ln -s "$target" "$RELEASE_MIRROR_STAGE" || return 1
  if [ -d "$RELEASE_MIRROR" ] && [ ! -h "$RELEASE_MIRROR" ]; then
    RELEASE_MIRROR_BACKUP="$RELEASE_MIRROR_PARENT/.${RELEASE_SKILL_NAME}.legacy-mirror.$$"
    mv "$RELEASE_MIRROR" "$RELEASE_MIRROR_BACKUP" || return 1
  fi
  if ! python3 -c 'import os, sys; os.replace(sys.argv[1], sys.argv[2])' \
    "$RELEASE_MIRROR_STAGE" "$RELEASE_MIRROR"; then
    printf '  BLOCK %s (cannot atomically update the managed mirror pointer)\n' \
      "$RELEASE_MIRROR" >&2
    return 1
  fi
  RELEASE_MIRROR_STAGE=""
}

install_release_skill() {
  local src_dir="$1"
  local dest="$2"
  local source_tree version_dir selection_target mirror_target
  local selected_needs_update="1"

  RELEASE_SELECTION_DEST="$dest"
  release_source_is_verified "$src_dir" || return 1
  prepare_release_mirror || return 1
  acquire_release_lock || return 1
  reconcile_release_residue || return 1
  release_selection_is_safe_to_replace "$dest" || return 1

  source_tree="$(tree_fingerprint "$src_dir")" || {
    printf '  BLOCK %s (cannot fingerprint verified release source)\n' "$src_dir" >&2
    return 1
  }
  mkdir -p "$RELEASE_VERSIONS" || return 1
  if [ -e "$RELEASE_VERSIONS/$source_tree" ] || [ -h "$RELEASE_VERSIONS/$source_tree" ]; then
    version_dir="$RELEASE_VERSIONS/$source_tree"
    if [ -h "$version_dir" ] || ! release_skill_tree_is_valid "$version_dir" \
      || [ "$(tree_fingerprint "$version_dir")" != "$source_tree" ]; then
      printf '  BLOCK %s (existing immutable version is invalid; preserved)\n' "$version_dir" >&2
      return 1
    fi
  else
    version_dir="$RELEASE_VERSIONS/$source_tree"
    RELEASE_STAGE="$RELEASE_VERSIONS/.${RELEASE_SKILL_NAME}.staging.$$"
    if ! mkdir "$RELEASE_STAGE" || ! cp -R "$src_dir/." "$RELEASE_STAGE" \
      || ! release_skill_tree_is_valid "$RELEASE_STAGE" \
      || [ "$(tree_fingerprint "$RELEASE_STAGE")" != "$source_tree" ] \
      || ! mv "$RELEASE_STAGE" "$version_dir"; then
      printf '  BLOCK %s (staged immutable version verification failed; kept last known-good selection)\n' \
        "$version_dir" >&2
      return 1
    fi
    RELEASE_STAGE=""
    printf '  MIRROR %s (verified immutable inventory/type/SHA-256)\n' "$version_dir"
  fi

  mirror_target="$(release_mirror_target)" || return 1
  if [ -h "$dest" ]; then
    selection_target="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$dest")" || return 1
    if [ "$selection_target" = "$version_dir" ] && release_skill_tree_is_valid "$selection_target"; then
      selected_needs_update="0"
    fi
  fi

  if [ "$selected_needs_update" = "1" ]; then
    make_staged_selection_link "$dest" "$version_dir" || return 1
    onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_SELECTION_COMMIT || return 1
    if onboard_test_failure_requested "${FANTASYDISK_ONBOARD_TEST_FAIL_BEFORE_SELECTION_COMMIT:-0}"; then
      printf '  BLOCK %s (test failure injected before selection commit)\n' "$dest" >&2
      return 1
    fi
    activate_staged_selection_link "$dest" || return 1
    printf '  SELECTION_COMMIT %s -> %s\n' "$dest" "$version_dir"
    if onboard_test_failure_requested "${FANTASYDISK_ONBOARD_TEST_FAIL_AFTER_SELECTION_COMMIT:-0}"; then
      printf '  BLOCK %s (test failure injected after selection commit)\n' "$dest" >&2
      return 1
    fi
    onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_SELECTION_COMMIT || return 1
  else
    printf '  SELECTION %s (verified and up-to-date)\n' "$dest"
  fi

  if [ "$mirror_target" != "$version_dir" ]; then
    activate_mirror_pointer "$version_dir" || return 1
    printf '  MIRROR_POINTER %s -> %s\n' "$RELEASE_MIRROR" "$version_dir"
  else
    printf '  MIRROR_POINTER %s (verified and up-to-date)\n' "$RELEASE_MIRROR"
  fi
  printf '  linked %s -> %s\n' "$dest" "$version_dir"
}

onboard_exit() {
  local status="$?"

  if [ "${RELEASE_LOCK_OWNED:-0}" = "1" ]; then
    cleanup_release_runtime_residue || true
  fi
  release_lock || true
  release_lock_finish_reclaimer || true
  trap - EXIT
  exit "$status"
}

# TERM/INT are observed by the deterministic pause hook before it can cross a
# selection boundary.  KILL cannot run a trap; its stale lock and private
# residue are reconciled by the next invocation after the owner disappears.
onboard_interrupt() {
  RELEASE_INTERRUPT_REQUESTED="1"
  if [ "${RELEASE_TEST_PAUSE_ACTIVE:-0}" != "1" ]; then
    exit 143
  fi
}

trap onboard_interrupt TERM INT
trap onboard_exit EXIT

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
