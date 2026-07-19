#!/usr/bin/env bash
# usage: bash scripts/onboard.sh [--release-only]
#
# FantasyDisk one-line onboarding. Run ONCE after cloning the repo.
# Symlinks repo-tracked skills into your home Codex/Claude skill dirs and
# prints a short orientation banner. Safe to re-run (idempotent).
#
# --release-only invokes only the managed, atomic release-skill activation
# path. It deliberately skips all unrelated skill linking, Git hook cleanup,
# Multica checks, and the general onboarding banner.

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
RELEASE_SELECTION_PARENT=""
RELEASE_LOCK_OWNED="0"
RELEASE_LOCK_OWNER=""
RELEASE_LOCK_RECLAIM_OWNER=""
RELEASE_STAGE=""
RELEASE_STAGE_MARKER=""
RELEASE_STAGE_IDENTITY=""
RELEASE_SELECTION_STAGE=""
RELEASE_SELECTION_STAGE_MARKER=""
RELEASE_SELECTION_STAGE_IDENTITY=""
RELEASE_SELECTION_DEST_IDENTITY=""
RELEASE_SELECTION_COMMITTED_IDENTITY=""
RELEASE_SELECTION_LEGACY_TREE=""
RELEASE_SELECTION_BACKUP=""
RELEASE_SELECTION_BACKUP_MARKER=""
RELEASE_SELECTION_BACKUP_IDENTITY=""
RELEASE_SELECTION_DEST=""
RELEASE_MIRROR_STAGE=""
RELEASE_MIRROR_STAGE_MARKER=""
RELEASE_MIRROR_STAGE_IDENTITY=""
RELEASE_MIRROR_DEST_IDENTITY=""
RELEASE_MIRROR_COMMITTED_IDENTITY=""
RELEASE_MIRROR_BACKUP=""
RELEASE_MIRROR_BACKUP_MARKER=""
RELEASE_MIRROR_BACKUP_IDENTITY=""
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

release_residue_marker_path() {
  local parent="$1"
  local namespace="$2"
  local suffix="$3"

  printf '%s/.%s.residue-owner.%s.%s\n' \
    "$parent" "$RELEASE_SKILL_NAME" "$namespace" "$suffix"
}

release_residue_write_marker() {
  local marker_variable="$1"
  local parent="$2"
  local namespace="$3"
  local suffix="$4"
  local kind="$5"
  local target="$6"
  local tree="$7"
  local owner_pid="$$"
  local expected_parent_identity="${8:-}"
  local marker

  marker="$(release_residue_marker_path "$parent" "$namespace" "$suffix")" || return 1
  python3 -c '
import base64
import os
import re
import sys

marker, parent, skill_name, namespace, suffix, kind, target, tree, owner_pid, expected_parent_identity = sys.argv[1:]
if os.path.realpath(parent) != parent or not os.path.isdir(parent):
    raise SystemExit(1)
if not re.fullmatch(r"[A-Za-z0-9._-]+", namespace):
    raise SystemExit(1)
if not re.fullmatch(r"[A-Za-z0-9._-]+", suffix):
    raise SystemExit(1)
if kind not in {"directory", "symlink"} or not re.fullmatch(r"[0-9a-f]{64}", tree):
    raise SystemExit(1)
residue_name = f".{skill_name}.{namespace}.{suffix}"
expected_marker = os.path.join(parent, f".{skill_name}.residue-owner.{namespace}.{suffix}")
if marker != expected_marker:
    raise SystemExit(1)
if expected_parent_identity:
    try:
        expected_parent = tuple(int(part) for part in expected_parent_identity.split(":"))
    except ValueError:
        raise SystemExit(1)
    if len(expected_parent) != 3:
        raise SystemExit(1)
target_b64 = base64.urlsafe_b64encode(target.encode("utf-8")).decode("ascii")
content = (
    "magic=fantasydisk-release-director-residue-v1\n"
    f"namespace={namespace}\n"
    f"residue={residue_name}\n"
    f"parent={parent}\n"
    f"kind={kind}\n"
    f"target={target_b64}\n"
    f"tree={tree}\n"
    f"pid={owner_pid}\n"
    "files=7\n"
).encode("ascii")
parent_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
try:
    parent_fd = os.open(parent, parent_flags)
except OSError:
    raise SystemExit(1)
try:
    parent_stat = os.fstat(parent_fd)
    if expected_parent_identity and (
        parent_stat.st_dev,
        parent_stat.st_ino,
        parent_stat.st_ctime_ns,
    ) != expected_parent:
        raise SystemExit(1)
    try:
        fd = os.open(os.path.basename(marker), flags, 0o600, dir_fd=parent_fd)
    except OSError:
        raise SystemExit(1)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
    except Exception:
        try:
            os.unlink(os.path.basename(marker), dir_fd=parent_fd)
        except OSError:
            pass
        raise SystemExit(1)
finally:
    os.close(parent_fd)
' "$marker" "$parent" "$RELEASE_SKILL_NAME" "$namespace" "$suffix" \
    "$kind" "$target" "$tree" "$owner_pid" "$expected_parent_identity" || {
    printf '  BLOCK %s (cannot publish residue ownership record safely)\n' "$marker" >&2
    return 1
  }
  printf -v "$marker_variable" '%s' "$marker"
}

release_residue_parent_is_real_or_absent() {
  local parent="$1"

  python3 -c '
import os
import stat
import sys

parent = os.path.abspath(sys.argv[1])
home_lexical = os.path.abspath(os.environ["HOME"])
for home in (home_lexical, os.path.realpath(home_lexical)):
    try:
        relative = os.path.relpath(parent, home)
    except ValueError:
        continue
    if relative == ".." or relative.startswith(f"..{os.sep}"):
        continue
    current = home
    if relative == ".":
        raise SystemExit(0)
    for component in relative.split(os.sep):
        current = os.path.join(current, component)
        try:
            entry = os.lstat(current)
        except FileNotFoundError:
            # A missing managed child has no entries to inspect and may be
            # created later by the regular parent preparation path.
            raise SystemExit(0)
        except OSError:
            raise SystemExit(1)
        if not stat.S_ISDIR(entry.st_mode) or stat.S_ISLNK(entry.st_mode):
            raise SystemExit(1)
    raise SystemExit(0)
raise SystemExit(1)
' "$parent"
}

release_residue_namespace_check() {
  local parent="$1"
  local namespace="$2"
  local residue marker

  if ! release_residue_parent_is_real_or_absent "$parent"; then
    printf '  BLOCK %s (managed residue parent is not a real directory; preserved)\n' \
      "$parent" >&2
    return 1
  fi

  # Persistent filesystem evidence is same-UID forgeable.  Do not inspect its
  # contents, target, tree, PID, xattrs, or mode in an attempt to recover it:
  # any existing matching entry is preserved and requires explicit operator
  # remediation before onboarding can mutate the managed selection or mirror.
  for residue in "$parent"/.${RELEASE_SKILL_NAME}.${namespace}.*; do
    if [ ! -e "$residue" ] && [ ! -h "$residue" ]; then
      continue
    fi
    printf '  BLOCK %s (pre-existing %s residue preserved; remove it manually before retrying)\n' \
      "$residue" "$namespace" >&2
    return 1
  done

  for marker in "$parent"/.${RELEASE_SKILL_NAME}.residue-owner.${namespace}.*; do
    if [ ! -e "$marker" ] && [ ! -h "$marker" ]; then
      continue
    fi
    printf '  BLOCK %s (pre-existing %s ownership record preserved; remove it manually before retrying)\n' \
      "$marker" "$namespace" >&2
    return 1
  done
}

release_residue_preflight() {
  local mirror_parent="$1"
  local versions="$2"
  local selection_parent="$3"

  if ! release_residue_parent_is_real_or_absent "$versions"; then
    printf '  BLOCK %s (private version store must be a real directory; preserved)\n' \
      "$versions" >&2
    return 1
  fi

  release_residue_namespace_check "$mirror_parent" "staging" || return 1
  release_residue_namespace_check "$versions" "staging" || return 1
  release_residue_namespace_check "$mirror_parent" "mirror-stage" || return 1
  release_residue_namespace_check "$selection_parent" "selection" || return 1
  release_residue_namespace_check "$selection_parent" "legacy" || return 1
  release_residue_namespace_check "$mirror_parent" "legacy-mirror" || return 1
}

release_residue_capture_runtime_identity() {
  local variable_name="$1"
  local parent="$2"
  local residue="$3"
  local marker="$4"
  local kind="$5"
  local identity

  identity="$(python3 -c '
import os
import stat
import sys

parent, residue, marker, kind = sys.argv[1:]
parent_stat = os.lstat(parent)
residue_stat = os.lstat(residue)
marker_stat = os.lstat(marker)
if not stat.S_ISDIR(parent_stat.st_mode) or stat.S_ISLNK(parent_stat.st_mode):
    raise SystemExit(1)
if kind == "directory":
    if not stat.S_ISDIR(residue_stat.st_mode) or stat.S_ISLNK(residue_stat.st_mode):
        raise SystemExit(1)
elif kind == "symlink":
    if not stat.S_ISLNK(residue_stat.st_mode):
        raise SystemExit(1)
else:
    raise SystemExit(1)
if not stat.S_ISREG(marker_stat.st_mode) or stat.S_ISLNK(marker_stat.st_mode):
    raise SystemExit(1)
print(
    f"{parent_stat.st_dev}:{parent_stat.st_ino}:{parent_stat.st_ctime_ns}:"
    f"{residue_stat.st_dev}:{residue_stat.st_ino}:{residue_stat.st_ctime_ns}:"
    f"{marker_stat.st_dev}:{marker_stat.st_ino}:{marker_stat.st_ctime_ns}"
)
' "$parent" "$residue" "$marker" "$kind")" || return 1
  printf -v "$variable_name" '%s' "$identity"
}

# A successful owned mutation (for example, moving a legacy directory or
# publishing its ownership marker) changes the parent's ctime.  Keep the
# original stage and marker identities, but rebase only the parent component
# after proving those entries have not changed.
release_residue_refresh_runtime_identity() {
  local variable_name="$1"
  local identity="$2"
  local parent="$3"
  local residue="$4"
  local marker="$5"
  local kind="$6"
  local allow_residue_ctime_change="${7:-0}"
  local refreshed

  refreshed="$(python3 -c '
import os
import stat
import sys

identity, parent, residue, marker, kind, allow_residue_ctime_change = sys.argv[1:]
try:
    expected = tuple(int(part) for part in identity.split(":"))
except ValueError:
    raise SystemExit(1)
if len(expected) != 9 or allow_residue_ctime_change not in {"0", "1"}:
    raise SystemExit(1)
if os.path.dirname(residue) != parent or os.path.dirname(marker) != parent:
    raise SystemExit(1)
flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
parent_fd = os.open(parent, flags)
try:
    parent_stat = os.fstat(parent_fd)
    residue_stat = os.stat(os.path.basename(residue), dir_fd=parent_fd, follow_symlinks=False)
    marker_stat = os.stat(os.path.basename(marker), dir_fd=parent_fd, follow_symlinks=False)
    if (residue_stat.st_dev, residue_stat.st_ino) != expected[3:5]:
        raise SystemExit(1)
    if allow_residue_ctime_change == "0" and residue_stat.st_ctime_ns != expected[5]:
        raise SystemExit(1)
    if (marker_stat.st_dev, marker_stat.st_ino, marker_stat.st_ctime_ns) != expected[6:9]:
        raise SystemExit(1)
    if kind == "directory":
        if not stat.S_ISDIR(residue_stat.st_mode) or stat.S_ISLNK(residue_stat.st_mode):
            raise SystemExit(1)
    elif kind == "symlink":
        if not stat.S_ISLNK(residue_stat.st_mode):
            raise SystemExit(1)
    else:
        raise SystemExit(1)
    if not stat.S_ISREG(marker_stat.st_mode) or stat.S_ISLNK(marker_stat.st_mode):
        raise SystemExit(1)
    print(
        f"{parent_stat.st_dev}:{parent_stat.st_ino}:{parent_stat.st_ctime_ns}:"
        f"{residue_stat.st_dev}:{residue_stat.st_ino}:{residue_stat.st_ctime_ns}:"
        f"{marker_stat.st_dev}:{marker_stat.st_ino}:{marker_stat.st_ctime_ns}"
    )
finally:
    os.close(parent_fd)
' "$identity" "$parent" "$residue" "$marker" "$kind" "$allow_residue_ctime_change")" || return 1
  printf -v "$variable_name" '%s' "$refreshed"
}

release_residue_capture_entry_identity() {
  local variable_name="$1"
  local parent="$2"
  local entry="$3"
  local identity

  identity="$(python3 -c '
import os
import stat
import sys

parent, entry = sys.argv[1:]
if os.path.dirname(entry) != parent:
    raise SystemExit(1)
flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
parent_fd = os.open(parent, flags)
try:
    parent_stat = os.fstat(parent_fd)
    try:
        entry_stat = os.stat(os.path.basename(entry), dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError:
        print(f"{parent_stat.st_dev}:{parent_stat.st_ino}:{parent_stat.st_ctime_ns}:absent")
        raise SystemExit(0)
    if stat.S_ISLNK(entry_stat.st_mode):
        kind = "symlink"
    elif stat.S_ISDIR(entry_stat.st_mode):
        kind = "directory"
    elif stat.S_ISREG(entry_stat.st_mode):
        kind = "file"
    else:
        kind = "other"
    print(
        f"{parent_stat.st_dev}:{parent_stat.st_ino}:{parent_stat.st_ctime_ns}:"
        f"{kind}:{entry_stat.st_dev}:{entry_stat.st_ino}:{entry_stat.st_ctime_ns}"
    )
finally:
    os.close(parent_fd)
' "$parent" "$entry")" || return 1
  printf -v "$variable_name" '%s' "$identity"
}

release_residue_entry_identity_matches() {
  local parent="$1"
  local entry="$2"
  local expected="$3"
  local actual

  release_residue_capture_entry_identity actual "$parent" "$entry" || return 1
  [ "$actual" = "$expected" ]
}

release_residue_identity_kind() {
  local identity="$1"
  local _parent_device _parent_inode _parent_ctime kind _entry_device _entry_inode _entry_ctime

  IFS=: read -r _parent_device _parent_inode _parent_ctime kind _entry_device _entry_inode _entry_ctime <<< "$identity"
  printf '%s\n' "$kind"
}

release_residue_identity_parent() {
  local identity="$1"
  local parent_device parent_inode parent_ctime _rest

  IFS=: read -r parent_device parent_inode parent_ctime _rest <<< "$identity"
  printf '%s:%s:%s\n' "$parent_device" "$parent_inode" "$parent_ctime"
}

release_residue_move_runtime_directory() {
  local identity="$1"
  local parent="$2"
  local residue="$3"
  local backup="$4"

  python3 -c '
import ctypes
import errno
import os
import platform
import stat
import sys

identity, parent, residue, backup = sys.argv[1:]
try:
    expected = identity.split(":")
    parent_expected = (int(expected[0]), int(expected[1]), int(expected[2]))
    kind = expected[3]
    residue_expected = (int(expected[4]), int(expected[5]), int(expected[6]))
except (IndexError, ValueError):
    raise SystemExit(1)
if len(expected) != 7 or kind != "directory":
    raise SystemExit(1)
if os.path.dirname(residue) != parent or os.path.dirname(backup) != parent:
    raise SystemExit(1)
flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)

def rename_no_replace(parent_fd, source, destination):
    libc = ctypes.CDLL(None, use_errno=True)
    source_b = source.encode("utf-8")
    destination_b = destination.encode("utf-8")
    if sys.platform == "darwin":
        operation = getattr(libc, "renameatx_np", None)
        if operation is None:
            raise OSError(errno.ENOSYS, "renameatx_np unavailable")
        operation.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        operation.restype = ctypes.c_int
        result = operation(parent_fd, source_b, parent_fd, destination_b, 0x00000004)
    elif sys.platform.startswith("linux"):
        operation = getattr(libc, "renameat2", None)
        if operation is not None:
            operation.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
            operation.restype = ctypes.c_int
            result = operation(parent_fd, source_b, parent_fd, destination_b, 1)
        else:
            syscall_numbers = {"x86_64": 316, "amd64": 316, "aarch64": 276, "arm64": 276, "riscv64": 276}
            number = syscall_numbers.get(platform.machine().lower())
            if number is None:
                raise OSError(errno.ENOSYS, "renameat2 unavailable")
            result = libc.syscall(number, parent_fd, source_b, parent_fd, destination_b, 1)
    else:
        raise OSError(errno.ENOSYS, "atomic no-replace rename unavailable")
    if result != 0:
        error = ctypes.get_errno()
        raise OSError(error or errno.EIO, os.strerror(error or errno.EIO))

parent_fd = os.open(parent, flags)
try:
    parent_stat = os.fstat(parent_fd)
    if (parent_stat.st_dev, parent_stat.st_ino, parent_stat.st_ctime_ns) != parent_expected:
        raise SystemExit(1)
    residue_name = os.path.basename(residue)
    backup_name = os.path.basename(backup)
    residue_stat = os.stat(residue_name, dir_fd=parent_fd, follow_symlinks=False)
    if (residue_stat.st_dev, residue_stat.st_ino, residue_stat.st_ctime_ns) != residue_expected:
        raise SystemExit(1)
    if not stat.S_ISDIR(residue_stat.st_mode) or stat.S_ISLNK(residue_stat.st_mode):
        raise SystemExit(1)
    try:
        os.stat(backup_name, dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise SystemExit(1)
    rename_no_replace(parent_fd, residue_name, backup_name)
finally:
    os.close(parent_fd)
' "$identity" "$parent" "$residue" "$backup" || {
    printf '  BLOCK %s (legacy destination changed before safe backup activation)\n' "$residue" >&2
    return 1
  }
}

release_residue_replace_runtime_link() {
  local identity="$1"
  local parent="$2"
  local stage="$3"
  local marker="$4"
  local dest="$5"
  local dest_identity="$6"

  python3 -c '
import os
import stat
import sys

identity, parent, stage, marker, dest, dest_identity = sys.argv[1:]
try:
    expected = tuple(int(part) for part in identity.split(":"))
except ValueError:
    raise SystemExit(1)
if len(expected) != 9:
    raise SystemExit(1)
parts = dest_identity.split(":")
try:
    dest_parent = (int(parts[0]), int(parts[1]), int(parts[2]))
except (IndexError, ValueError):
    raise SystemExit(1)
if dest_parent != expected[:3] or len(parts) not in {4, 7}:
    raise SystemExit(1)
if len(parts) == 4:
    if parts[3] != "absent":
        raise SystemExit(1)
    dest_expected = None
else:
    try:
        dest_expected = (parts[3], int(parts[4]), int(parts[5]), int(parts[6]))
    except ValueError:
        raise SystemExit(1)
if os.path.dirname(stage) != parent or os.path.dirname(marker) != parent or os.path.dirname(dest) != parent:
    raise SystemExit(1)
flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
parent_fd = os.open(parent, flags)
try:
    parent_stat = os.fstat(parent_fd)
    if (parent_stat.st_dev, parent_stat.st_ino, parent_stat.st_ctime_ns) != expected[:3]:
        raise SystemExit(1)
    stage_name = os.path.basename(stage)
    marker_name = os.path.basename(marker)
    dest_name = os.path.basename(dest)
    stage_stat = os.stat(stage_name, dir_fd=parent_fd, follow_symlinks=False)
    marker_stat = os.stat(marker_name, dir_fd=parent_fd, follow_symlinks=False)
    if (stage_stat.st_dev, stage_stat.st_ino, stage_stat.st_ctime_ns) != expected[3:6] or not stat.S_ISLNK(stage_stat.st_mode):
        raise SystemExit(1)
    if (marker_stat.st_dev, marker_stat.st_ino, marker_stat.st_ctime_ns) != expected[6:9] or not stat.S_ISREG(marker_stat.st_mode):
        raise SystemExit(1)
    try:
        dest_stat = os.stat(dest_name, dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError:
        if dest_expected is not None:
            raise SystemExit(1)
    else:
        if dest_expected is None:
            raise SystemExit(1)
        if stat.S_ISLNK(dest_stat.st_mode):
            dest_kind = "symlink"
        elif stat.S_ISDIR(dest_stat.st_mode):
            dest_kind = "directory"
        elif stat.S_ISREG(dest_stat.st_mode):
            dest_kind = "file"
        else:
            dest_kind = "other"
        if (dest_kind, dest_stat.st_dev, dest_stat.st_ino, dest_stat.st_ctime_ns) != dest_expected:
            raise SystemExit(1)
        if dest_kind == "directory":
            raise SystemExit(1)
    os.replace(stage_name, dest_name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
finally:
    os.close(parent_fd)
' "$identity" "$parent" "$stage" "$marker" "$dest" "$dest_identity" || {
    printf '  BLOCK %s (activation identity changed; replacement preserved)\n' "$dest" >&2
    return 1
  }
}

release_residue_remove_runtime_entry() {
  local identity="$1"
  local parent="$2"
  local residue="$3"
  local marker="$4"
  local kind="$5"

  [ -n "$identity" ] || return 1
  onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_RUNTIME_CLEANUP || return 1
  python3 -c '
import os
import stat
import sys

identity, parent, residue, marker, kind = sys.argv[1:]
try:
    expected = tuple(int(part) for part in identity.split(":"))
except ValueError:
    raise SystemExit(1)
if len(expected) != 9:
    raise SystemExit(1)
residue_name = os.path.basename(residue)
marker_name = os.path.basename(marker)
if os.path.dirname(residue) != parent or os.path.dirname(marker) != parent:
    raise SystemExit(1)
flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)

def remove_directory_contents(directory_fd):
    for entry in os.listdir(directory_fd):
        entry_stat = os.stat(entry, dir_fd=directory_fd, follow_symlinks=False)
        if stat.S_ISDIR(entry_stat.st_mode) and not stat.S_ISLNK(entry_stat.st_mode):
            child_fd = os.open(entry, flags, dir_fd=directory_fd)
            try:
                child_stat = os.fstat(child_fd)
                if (child_stat.st_dev, child_stat.st_ino) != (entry_stat.st_dev, entry_stat.st_ino):
                    raise SystemExit(1)
                remove_directory_contents(child_fd)
            finally:
                os.close(child_fd)
            current = os.stat(entry, dir_fd=directory_fd, follow_symlinks=False)
            if (current.st_dev, current.st_ino) != (entry_stat.st_dev, entry_stat.st_ino):
                raise SystemExit(1)
            os.rmdir(entry, dir_fd=directory_fd)
        else:
            os.unlink(entry, dir_fd=directory_fd)

parent_fd = os.open(parent, flags)
try:
    parent_stat = os.fstat(parent_fd)
    residue_stat = os.stat(residue_name, dir_fd=parent_fd, follow_symlinks=False)
    marker_stat = os.stat(marker_name, dir_fd=parent_fd, follow_symlinks=False)
    if (residue_stat.st_dev, residue_stat.st_ino, residue_stat.st_ctime_ns) != expected[3:6]:
        raise SystemExit(1)
    if (marker_stat.st_dev, marker_stat.st_ino, marker_stat.st_ctime_ns) != expected[6:9]:
        raise SystemExit(1)
    if kind == "directory":
        if not stat.S_ISDIR(residue_stat.st_mode):
            raise SystemExit(1)
        residue_fd = os.open(residue_name, flags, dir_fd=parent_fd)
        try:
            opened_residue = os.fstat(residue_fd)
            if (opened_residue.st_dev, opened_residue.st_ino, opened_residue.st_ctime_ns) != expected[3:6]:
                raise SystemExit(1)
            remove_directory_contents(residue_fd)
        finally:
            os.close(residue_fd)
        residue_stat = os.stat(residue_name, dir_fd=parent_fd, follow_symlinks=False)
        # Removing owned children updates the directory ctime.  Its inode
        # remains the already-verified directory until rmdir below.
        if (residue_stat.st_dev, residue_stat.st_ino) != expected[3:5]:
            raise SystemExit(1)
        os.rmdir(residue_name, dir_fd=parent_fd)
    elif kind == "symlink":
        if not stat.S_ISLNK(residue_stat.st_mode):
            raise SystemExit(1)
        os.unlink(residue_name, dir_fd=parent_fd)
    else:
        raise SystemExit(1)
    marker_stat = os.stat(marker_name, dir_fd=parent_fd, follow_symlinks=False)
    if (marker_stat.st_dev, marker_stat.st_ino, marker_stat.st_ctime_ns) != expected[6:9]:
        raise SystemExit(1)
    os.unlink(marker_name, dir_fd=parent_fd)
finally:
    os.close(parent_fd)
' "$identity" "$parent" "$residue" "$marker" "$kind" || {
    printf '  BLOCK %s (current-run residue changed; preserved)\n' "$residue" >&2
    return 1
  }
}

release_residue_remove_runtime_marker() {
  local identity="$1"
  local parent="$2"
  local marker="$3"

  [ -n "$identity" ] || return 1
  python3 -c '
import os
import stat
import sys

identity, parent, marker = sys.argv[1:]
try:
    expected = tuple(int(part) for part in identity.split(":"))
except ValueError:
    raise SystemExit(1)
if len(expected) != 9 or os.path.dirname(marker) != parent:
    raise SystemExit(1)
flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
parent_fd = os.open(parent, flags)
try:
    parent_stat = os.fstat(parent_fd)
    marker_stat = os.stat(os.path.basename(marker), dir_fd=parent_fd, follow_symlinks=False)
    if (marker_stat.st_dev, marker_stat.st_ino, marker_stat.st_ctime_ns) != expected[6:9]:
        raise SystemExit(1)
    if not stat.S_ISREG(marker_stat.st_mode):
        raise SystemExit(1)
    os.unlink(os.path.basename(marker), dir_fd=parent_fd)
finally:
    os.close(parent_fd)
' "$identity" "$parent" "$marker" || {
    printf '  BLOCK %s (current-run ownership record changed; preserved)\n' "$marker" >&2
    return 1
  }
}

release_residue_restore_runtime_directory() {
  local identity="$1"
  local parent="$2"
  local residue="$3"
  local dest="$4"
  local marker="$5"

  [ -n "$identity" ] || return 1
  onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_RUNTIME_CLEANUP || return 1
  python3 -c '
import ctypes
import errno
import os
import platform
import stat
import sys

identity, parent, residue, dest, marker = sys.argv[1:]
try:
    expected = tuple(int(part) for part in identity.split(":"))
except ValueError:
    raise SystemExit(1)
if len(expected) != 9 or os.path.dirname(residue) != parent or os.path.dirname(dest) != parent or os.path.dirname(marker) != parent:
    raise SystemExit(1)
flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)

def rename_no_replace(parent_fd, source, destination):
    libc = ctypes.CDLL(None, use_errno=True)
    source_b = source.encode("utf-8")
    destination_b = destination.encode("utf-8")
    if sys.platform == "darwin":
        operation = getattr(libc, "renameatx_np", None)
        if operation is None:
            raise OSError(errno.ENOSYS, "renameatx_np unavailable")
        operation.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        operation.restype = ctypes.c_int
        result = operation(parent_fd, source_b, parent_fd, destination_b, 0x00000004)
    elif sys.platform.startswith("linux"):
        operation = getattr(libc, "renameat2", None)
        if operation is not None:
            operation.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
            operation.restype = ctypes.c_int
            result = operation(parent_fd, source_b, parent_fd, destination_b, 1)
        else:
            syscall_numbers = {"x86_64": 316, "amd64": 316, "aarch64": 276, "arm64": 276, "riscv64": 276}
            number = syscall_numbers.get(platform.machine().lower())
            if number is None:
                raise OSError(errno.ENOSYS, "renameat2 unavailable")
            result = libc.syscall(number, parent_fd, source_b, parent_fd, destination_b, 1)
    else:
        raise OSError(errno.ENOSYS, "atomic no-replace rename unavailable")
    if result != 0:
        error = ctypes.get_errno()
        raise OSError(error or errno.EIO, os.strerror(error or errno.EIO))

parent_fd = os.open(parent, flags)
try:
    parent_stat = os.fstat(parent_fd)
    residue_stat = os.stat(os.path.basename(residue), dir_fd=parent_fd, follow_symlinks=False)
    marker_stat = os.stat(os.path.basename(marker), dir_fd=parent_fd, follow_symlinks=False)
    if (
        (residue_stat.st_dev, residue_stat.st_ino, residue_stat.st_ctime_ns) != expected[3:6]
        or (marker_stat.st_dev, marker_stat.st_ino, marker_stat.st_ctime_ns) != expected[6:9]
    ):
        raise SystemExit(1)
    if not stat.S_ISDIR(residue_stat.st_mode) or stat.S_ISLNK(residue_stat.st_mode) or not stat.S_ISREG(marker_stat.st_mode):
        raise SystemExit(1)
    try:
        os.stat(os.path.basename(dest), dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise SystemExit(1)
    rename_no_replace(parent_fd, os.path.basename(residue), os.path.basename(dest))
finally:
    os.close(parent_fd)
' "$identity" "$parent" "$residue" "$dest" "$marker" || {
    printf '  BLOCK %s (current-run backup changed; preserved)\n' "$residue" >&2
    return 1
  }
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

prepare_release_selection_parent() {
  local requested_dest="$1"
  local expected_parent="$HOME/.codex/skills"
  local codex_parent="$HOME/.codex"
  local path physical_path

  if [ "$(dirname "$requested_dest")" != "$expected_parent" ]; then
    printf '  BLOCK %s (selected skill parent is not the managed child path)\n' \
      "$requested_dest" >&2
    return 1
  fi

  for path in "$codex_parent" "$expected_parent"; do
    if [ -h "$path" ]; then
      printf '  BLOCK %s (selected skill parent must not contain a symlink)\n' \
        "$path" >&2
      return 1
    elif [ -e "$path" ] && [ ! -d "$path" ]; then
      printf '  BLOCK %s (selected skill parent has an unsafe root type)\n' \
        "$path" >&2
      return 1
    elif [ ! -e "$path" ]; then
      mkdir "$path" || {
        printf '  BLOCK %s (cannot create selected skill parent safely)\n' "$path" >&2
        return 1
      }
    fi
  done
  physical_path="$(cd -P "$expected_parent" && pwd -P)" || return 1
  RELEASE_SELECTION_PARENT="$physical_path"
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

# Classify an owner PID as live (0), conclusively dead (1), or unknown (2).
# Only the dead result permits callers to reclaim state.
release_lock_probe_liveness() {
  local lock_pid="$1"
  local probe_result

  # Python exposes portable errno-specific exceptions without parsing
  # localized shell diagnostics. Only ProcessLookupError proves that the
  # owner is gone; permission errors, other probe errors, and invalid PIDs
  # remain unknown so callers fail closed.
  probe_result="$(python3 -c '
import os
import sys

try:
    pid = int(sys.argv[1])
    os.kill(pid, 0)
except ProcessLookupError:
    print("dead")
except PermissionError:
    print("unknown")
except OSError:
    print("unknown")
except (TypeError, ValueError, OverflowError):
    print("unknown")
except Exception:
    print("unknown")
else:
    print("live")
' "$lock_pid" 2>/dev/null)" || return 2
  case "$probe_result" in
    live) return 0 ;;
    dead) return 1 ;;
    *) return 2 ;;
  esac
}

# Return 0 for a complete/live record, 1 for an absent or complete/dead
# record, and 2 for malformed, unreadable, incomplete, foreign, or unknown
# state. Callers must never reclaim state in the third case.
release_lock_state_at() {
  local lock_path="$1"
  local owner_dir lock_pid liveness_state

  if [ ! -e "$lock_path" ] && [ ! -h "$lock_path" ]; then
    return 1
  fi
  owner_dir="$(release_lock_owner_target_at "$lock_path")" || return 2
  lock_pid="$(<"$owner_dir/pid")" || return 2
  if release_lock_probe_liveness "$lock_pid"; then
    liveness_state="0"
  else
    liveness_state="$?"
  fi
  return "$liveness_state"
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
  local owner_dir owner_pid liveness_state

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
    if release_lock_probe_liveness "$owner_pid"; then
      liveness_state="0"
    else
      liveness_state="$?"
    fi
    case "$liveness_state" in
      0)
        printf '  BLOCK %s (another onboarding updater is publishing the managed mirror lock)\n' \
          "$RELEASE_MIRROR_PARENT" >&2
        return 1
        ;;
      2)
        printf '  BLOCK %s (managed mirror lock owner liveness is unknown; preserved)\n' \
          "$RELEASE_MIRROR_PARENT" >&2
        return 1
        ;;
      1)
        rm -rf "$owner_dir" || return 1
        ;;
      *)
        printf '  BLOCK %s (managed mirror lock owner liveness probe failed; preserved)\n' \
          "$RELEASE_MIRROR_PARENT" >&2
        return 1
        ;;
    esac
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
    RELEASE_SELECTION_LEGACY_TREE="$target_tree"
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
  local tree="$3"
  local selection_parent="${RELEASE_SELECTION_PARENT:-$(dirname "$dest")}"

  mkdir -p "$selection_parent" || return 1
  RELEASE_SELECTION_STAGE="$selection_parent/.${RELEASE_SKILL_NAME}.selection.$$"
  if ! ln -s "$target" "$RELEASE_SELECTION_STAGE"; then
    printf '  BLOCK %s (cannot stage durable selected link)\n' "$dest" >&2
    return 1
  fi
  release_residue_write_marker RELEASE_SELECTION_STAGE_MARKER \
    "$selection_parent" "selection" "$$" "symlink" "$target" "$tree" || return 1
  release_residue_capture_runtime_identity RELEASE_SELECTION_STAGE_IDENTITY \
    "$selection_parent" "$RELEASE_SELECTION_STAGE" "$RELEASE_SELECTION_STAGE_MARKER" \
    "symlink" || return 1
}

activate_staged_selection_link() {
  local dest="$1"
  local backup_tree parent_identity legacy_dest_identity
  local parent_device parent_inode parent_ctime stage_device stage_inode stage_ctime
  local committed_parent_device committed_parent_inode committed_parent_ctime committed_kind
  local committed_device committed_inode committed_ctime _marker_device _marker_inode _marker_ctime

  RELEASE_SELECTION_BACKUP=""
  if [ "$(release_residue_identity_kind "$RELEASE_SELECTION_DEST_IDENTITY")" = "directory" ]; then
    legacy_dest_identity="$RELEASE_SELECTION_DEST_IDENTITY"
    RELEASE_SELECTION_BACKUP="$RELEASE_SELECTION_PARENT/.${RELEASE_SKILL_NAME}.legacy.$$"
    backup_tree="$RELEASE_SELECTION_LEGACY_TREE"
    [ -n "$backup_tree" ] || return 1
    release_residue_move_runtime_directory "$RELEASE_SELECTION_DEST_IDENTITY" \
      "$RELEASE_SELECTION_PARENT" "$dest" "$RELEASE_SELECTION_BACKUP" || return 1
    release_residue_capture_entry_identity RELEASE_SELECTION_DEST_IDENTITY \
      "$RELEASE_SELECTION_PARENT" "$dest" || return 1
    [ "$(release_residue_identity_kind "$RELEASE_SELECTION_DEST_IDENTITY")" = "absent" ] || return 1
    parent_identity="$(release_residue_identity_parent "$RELEASE_SELECTION_DEST_IDENTITY")"
    release_residue_write_marker RELEASE_SELECTION_BACKUP_MARKER \
      "$RELEASE_SELECTION_PARENT" "legacy" "$$" "directory" "-" "$backup_tree" \
      "$parent_identity" || return 1
    release_residue_capture_runtime_identity RELEASE_SELECTION_BACKUP_IDENTITY \
      "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_BACKUP" \
      "$RELEASE_SELECTION_BACKUP_MARKER" "directory" || return 1
    release_residue_refresh_runtime_identity RELEASE_SELECTION_STAGE_IDENTITY \
      "$RELEASE_SELECTION_STAGE_IDENTITY" "$RELEASE_SELECTION_PARENT" \
      "$RELEASE_SELECTION_STAGE" "$RELEASE_SELECTION_STAGE_MARKER" "symlink" || return 1
    release_residue_capture_entry_identity RELEASE_SELECTION_DEST_IDENTITY \
      "$RELEASE_SELECTION_PARENT" "$dest" || return 1
    [ "$(release_residue_identity_kind "$RELEASE_SELECTION_DEST_IDENTITY")" = "absent" ] || return 1
    onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_SELECTION_LEGACY_BACKUP || return 1
  fi
  if ! release_residue_replace_runtime_link "$RELEASE_SELECTION_STAGE_IDENTITY" \
    "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_STAGE" \
    "$RELEASE_SELECTION_STAGE_MARKER" "$dest" "$RELEASE_SELECTION_DEST_IDENTITY"; then
    if [ -n "$RELEASE_SELECTION_BACKUP" ]; then
      release_residue_restore_runtime_directory "$RELEASE_SELECTION_BACKUP_IDENTITY" \
        "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_BACKUP" "$dest" \
        "$RELEASE_SELECTION_BACKUP_MARKER" || true
      if release_residue_entry_identity_matches "$RELEASE_SELECTION_PARENT" "$dest" \
        "$legacy_dest_identity"; then
        release_residue_remove_runtime_marker "$RELEASE_SELECTION_BACKUP_IDENTITY" \
          "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_BACKUP_MARKER" || true
        RELEASE_SELECTION_BACKUP=""
        RELEASE_SELECTION_BACKUP_MARKER=""
        RELEASE_SELECTION_BACKUP_IDENTITY=""
      fi
    fi
    return 1
  fi
  IFS=: read -r parent_device parent_inode parent_ctime stage_device stage_inode stage_ctime \
    _marker_device _marker_inode _marker_ctime \
    <<< "$RELEASE_SELECTION_STAGE_IDENTITY"
  RELEASE_SELECTION_STAGE=""
  release_residue_capture_entry_identity RELEASE_SELECTION_COMMITTED_IDENTITY \
    "$RELEASE_SELECTION_PARENT" "$dest" || return 1
  IFS=: read -r committed_parent_device committed_parent_inode committed_parent_ctime \
    committed_kind committed_device committed_inode committed_ctime \
    <<< "$RELEASE_SELECTION_COMMITTED_IDENTITY"
  # rename(2) is allowed to update the moved symlink's ctime.  Its device and
  # inode must still be the staged object; the freshly captured ctime becomes
  # the committed identity used for the immediate pre-signal revalidation.
  if [ "$committed_kind" != "symlink" ] \
    || [ "${committed_device}:${committed_inode}" \
      != "${stage_device}:${stage_inode}" ] \
    || ! release_residue_entry_identity_matches "$RELEASE_SELECTION_PARENT" "$dest" \
      "$RELEASE_SELECTION_COMMITTED_IDENTITY"; then
    printf '  BLOCK %s (selected link changed after activation; legacy backup preserved)\n' "$dest" >&2
    return 1
  fi
  # Keep the current-run ownership marker until the normal EXIT cleanup.  A
  # SIGKILL immediately after this verified commit cannot run that cleanup,
  # so the marker deliberately remains as fail-closed evidence for the next
  # invocation instead of allowing it to mistake the interrupted run for a
  # completed one.
  if [ -n "$RELEASE_SELECTION_BACKUP" ]; then
    release_residue_remove_runtime_entry "$RELEASE_SELECTION_BACKUP_IDENTITY" \
      "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_BACKUP" \
      "$RELEASE_SELECTION_BACKUP_MARKER" "directory" || return 1
    RELEASE_SELECTION_BACKUP=""
    RELEASE_SELECTION_BACKUP_MARKER=""
    RELEASE_SELECTION_BACKUP_IDENTITY=""
  fi
}

cleanup_release_runtime_residue() {
  if [ -n "${RELEASE_STAGE:-}" ] && [ -n "${RELEASE_STAGE_IDENTITY:-}" ]; then
    release_residue_remove_runtime_entry "$RELEASE_STAGE_IDENTITY" "$RELEASE_VERSIONS" \
      "$RELEASE_STAGE" "$RELEASE_STAGE_MARKER" "directory" || true
    RELEASE_STAGE=""
    RELEASE_STAGE_MARKER=""
    RELEASE_STAGE_IDENTITY=""
  elif [ -n "${RELEASE_STAGE_MARKER:-}" ] && [ -n "${RELEASE_STAGE_IDENTITY:-}" ]; then
    release_residue_remove_runtime_marker "$RELEASE_STAGE_IDENTITY" "$RELEASE_VERSIONS" \
      "$RELEASE_STAGE_MARKER" || true
    RELEASE_STAGE_MARKER=""
    RELEASE_STAGE_IDENTITY=""
  fi
  if [ -n "${RELEASE_MIRROR_STAGE:-}" ] && [ -n "${RELEASE_MIRROR_STAGE_IDENTITY:-}" ]; then
    release_residue_remove_runtime_entry "$RELEASE_MIRROR_STAGE_IDENTITY" \
      "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_STAGE" "$RELEASE_MIRROR_STAGE_MARKER" \
      "symlink" || true
    RELEASE_MIRROR_STAGE=""
    RELEASE_MIRROR_STAGE_MARKER=""
    RELEASE_MIRROR_STAGE_IDENTITY=""
  elif [ -n "${RELEASE_MIRROR_STAGE_MARKER:-}" ] && [ -n "${RELEASE_MIRROR_STAGE_IDENTITY:-}" ]; then
    release_residue_remove_runtime_marker "$RELEASE_MIRROR_STAGE_IDENTITY" \
      "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_STAGE_MARKER" || true
    RELEASE_MIRROR_STAGE_MARKER=""
    RELEASE_MIRROR_STAGE_IDENTITY=""
  fi
  if [ -n "${RELEASE_SELECTION_STAGE:-}" ] && [ -n "${RELEASE_SELECTION_STAGE_IDENTITY:-}" ]; then
    release_residue_remove_runtime_entry "$RELEASE_SELECTION_STAGE_IDENTITY" \
      "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_STAGE" "$RELEASE_SELECTION_STAGE_MARKER" \
      "symlink" || true
    RELEASE_SELECTION_STAGE=""
    RELEASE_SELECTION_STAGE_MARKER=""
    RELEASE_SELECTION_STAGE_IDENTITY=""
  elif [ -n "${RELEASE_SELECTION_STAGE_MARKER:-}" ] && [ -n "${RELEASE_SELECTION_STAGE_IDENTITY:-}" ]; then
    release_residue_remove_runtime_marker "$RELEASE_SELECTION_STAGE_IDENTITY" \
      "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_STAGE_MARKER" || true
    RELEASE_SELECTION_STAGE_MARKER=""
    RELEASE_SELECTION_STAGE_IDENTITY=""
  fi
  if [ -n "${RELEASE_SELECTION_BACKUP:-}" ] && [ -n "${RELEASE_SELECTION_BACKUP_IDENTITY:-}" ]; then
    if [ -n "${RELEASE_SELECTION_DEST:-}" ] \
      && [ ! -e "$RELEASE_SELECTION_DEST" ] && [ ! -h "$RELEASE_SELECTION_DEST" ]; then
      if release_residue_restore_runtime_directory "$RELEASE_SELECTION_BACKUP_IDENTITY" \
        "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_BACKUP" "$RELEASE_SELECTION_DEST" \
        "$RELEASE_SELECTION_BACKUP_MARKER"; then
        release_residue_remove_runtime_marker "$RELEASE_SELECTION_BACKUP_IDENTITY" \
          "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_BACKUP_MARKER" || true
      fi
    elif [ -n "${RELEASE_SELECTION_COMMITTED_IDENTITY:-}" ] \
      && release_residue_entry_identity_matches "$RELEASE_SELECTION_PARENT" \
        "$RELEASE_SELECTION_DEST" "$RELEASE_SELECTION_COMMITTED_IDENTITY"; then
      release_residue_remove_runtime_entry "$RELEASE_SELECTION_BACKUP_IDENTITY" \
        "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_BACKUP" \
        "$RELEASE_SELECTION_BACKUP_MARKER" "directory" || true
    else
      printf '  BLOCK %s (legacy selection backup preserved after destination changed)\n' \
        "$RELEASE_SELECTION_BACKUP" >&2
    fi
    RELEASE_SELECTION_BACKUP=""
    RELEASE_SELECTION_BACKUP_MARKER=""
    RELEASE_SELECTION_BACKUP_IDENTITY=""
  elif [ -n "${RELEASE_SELECTION_BACKUP_MARKER:-}" ] && [ -n "${RELEASE_SELECTION_BACKUP_IDENTITY:-}" ]; then
    release_residue_remove_runtime_marker "$RELEASE_SELECTION_BACKUP_IDENTITY" \
      "$RELEASE_SELECTION_PARENT" "$RELEASE_SELECTION_BACKUP_MARKER" || true
    RELEASE_SELECTION_BACKUP_MARKER=""
    RELEASE_SELECTION_BACKUP_IDENTITY=""
  fi
  if [ -n "${RELEASE_MIRROR_BACKUP:-}" ] && [ -n "${RELEASE_MIRROR_BACKUP_IDENTITY:-}" ]; then
    if [ ! -e "$RELEASE_MIRROR" ] && [ ! -h "$RELEASE_MIRROR" ]; then
      if release_residue_restore_runtime_directory "$RELEASE_MIRROR_BACKUP_IDENTITY" \
        "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_BACKUP" "$RELEASE_MIRROR" \
        "$RELEASE_MIRROR_BACKUP_MARKER"; then
        release_residue_remove_runtime_marker "$RELEASE_MIRROR_BACKUP_IDENTITY" \
          "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_BACKUP_MARKER" || true
      fi
    elif [ -n "${RELEASE_MIRROR_COMMITTED_IDENTITY:-}" ] \
      && release_residue_entry_identity_matches "$RELEASE_MIRROR_PARENT" \
        "$RELEASE_MIRROR" "$RELEASE_MIRROR_COMMITTED_IDENTITY"; then
      release_residue_remove_runtime_entry "$RELEASE_MIRROR_BACKUP_IDENTITY" \
        "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_BACKUP" "$RELEASE_MIRROR_BACKUP_MARKER" \
        "directory" || true
    else
      printf '  BLOCK %s (legacy mirror backup preserved after destination changed)\n' \
        "$RELEASE_MIRROR_BACKUP" >&2
    fi
    RELEASE_MIRROR_BACKUP=""
    RELEASE_MIRROR_BACKUP_MARKER=""
    RELEASE_MIRROR_BACKUP_IDENTITY=""
  elif [ -n "${RELEASE_MIRROR_BACKUP_MARKER:-}" ] && [ -n "${RELEASE_MIRROR_BACKUP_IDENTITY:-}" ]; then
    release_residue_remove_runtime_marker "$RELEASE_MIRROR_BACKUP_IDENTITY" \
      "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_BACKUP_MARKER" || true
    RELEASE_MIRROR_BACKUP_MARKER=""
    RELEASE_MIRROR_BACKUP_IDENTITY=""
  fi
}

reconcile_release_residue() {
  local selection_parent

  selection_parent="${RELEASE_SELECTION_PARENT:-$(dirname "$RELEASE_SELECTION_DEST")}"

  release_residue_preflight "$RELEASE_MIRROR_PARENT" "$RELEASE_VERSIONS" "$selection_parent"
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
  local target_tree backup_tree parent_identity legacy_dest_identity
  local parent_device parent_inode parent_ctime stage_device stage_inode stage_ctime
  local committed_parent_device committed_parent_inode committed_parent_ctime committed_kind
  local committed_device committed_inode committed_ctime _marker_device _marker_inode _marker_ctime

  RELEASE_MIRROR_STAGE="$RELEASE_MIRROR_PARENT/.${RELEASE_SKILL_NAME}.mirror-stage.$$"
  target_tree="$(tree_fingerprint "$target")" || return 1
  ln -s "$target" "$RELEASE_MIRROR_STAGE" || return 1
  release_residue_write_marker RELEASE_MIRROR_STAGE_MARKER \
    "$RELEASE_MIRROR_PARENT" "mirror-stage" "$$" "symlink" "$target" "$target_tree" || return 1
  release_residue_capture_runtime_identity RELEASE_MIRROR_STAGE_IDENTITY \
    "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_STAGE" "$RELEASE_MIRROR_STAGE_MARKER" \
    "symlink" || return 1
  # Stage publication changes the parent ctime, so capture the destination
  # identity only after that owned mutation and before the commit pause.
  release_residue_capture_entry_identity RELEASE_MIRROR_DEST_IDENTITY \
    "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR" || return 1
  if [ "$(release_residue_identity_kind "$RELEASE_MIRROR_DEST_IDENTITY")" = "directory" ]; then
    backup_tree="$(tree_fingerprint "$RELEASE_MIRROR")" || return 1
  fi
  onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_BEFORE_MIRROR_COMMIT || return 1
  if [ "$(release_residue_identity_kind "$RELEASE_MIRROR_DEST_IDENTITY")" = "directory" ]; then
    legacy_dest_identity="$RELEASE_MIRROR_DEST_IDENTITY"
    RELEASE_MIRROR_BACKUP="$RELEASE_MIRROR_PARENT/.${RELEASE_SKILL_NAME}.legacy-mirror.$$"
    release_residue_move_runtime_directory "$RELEASE_MIRROR_DEST_IDENTITY" \
      "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR" "$RELEASE_MIRROR_BACKUP" || return 1
    release_residue_capture_entry_identity RELEASE_MIRROR_DEST_IDENTITY \
      "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR" || return 1
    [ "$(release_residue_identity_kind "$RELEASE_MIRROR_DEST_IDENTITY")" = "absent" ] || return 1
    parent_identity="$(release_residue_identity_parent "$RELEASE_MIRROR_DEST_IDENTITY")"
    release_residue_write_marker RELEASE_MIRROR_BACKUP_MARKER \
      "$RELEASE_MIRROR_PARENT" "legacy-mirror" "$$" "directory" "-" "$backup_tree" \
      "$parent_identity" || return 1
    release_residue_capture_runtime_identity RELEASE_MIRROR_BACKUP_IDENTITY \
      "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_BACKUP" \
      "$RELEASE_MIRROR_BACKUP_MARKER" "directory" || return 1
    release_residue_refresh_runtime_identity RELEASE_MIRROR_STAGE_IDENTITY \
      "$RELEASE_MIRROR_STAGE_IDENTITY" "$RELEASE_MIRROR_PARENT" \
      "$RELEASE_MIRROR_STAGE" "$RELEASE_MIRROR_STAGE_MARKER" "symlink" || return 1
    release_residue_capture_entry_identity RELEASE_MIRROR_DEST_IDENTITY \
      "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR" || return 1
    [ "$(release_residue_identity_kind "$RELEASE_MIRROR_DEST_IDENTITY")" = "absent" ] || return 1
    onboard_test_pause FANTASYDISK_ONBOARD_TEST_PAUSE_AFTER_MIRROR_LEGACY_BACKUP || return 1
  fi
  if ! release_residue_replace_runtime_link "$RELEASE_MIRROR_STAGE_IDENTITY" \
    "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_STAGE" "$RELEASE_MIRROR_STAGE_MARKER" \
    "$RELEASE_MIRROR" "$RELEASE_MIRROR_DEST_IDENTITY"; then
    if [ -n "$RELEASE_MIRROR_BACKUP" ]; then
      release_residue_restore_runtime_directory "$RELEASE_MIRROR_BACKUP_IDENTITY" \
        "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_BACKUP" "$RELEASE_MIRROR" \
        "$RELEASE_MIRROR_BACKUP_MARKER" || true
      if release_residue_entry_identity_matches "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR" \
        "$legacy_dest_identity"; then
        release_residue_remove_runtime_marker "$RELEASE_MIRROR_BACKUP_IDENTITY" \
          "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_BACKUP_MARKER" || true
        RELEASE_MIRROR_BACKUP=""
        RELEASE_MIRROR_BACKUP_MARKER=""
        RELEASE_MIRROR_BACKUP_IDENTITY=""
      fi
    fi
    return 1
  fi
  IFS=: read -r parent_device parent_inode parent_ctime stage_device stage_inode stage_ctime \
    _marker_device _marker_inode _marker_ctime \
    <<< "$RELEASE_MIRROR_STAGE_IDENTITY"
  RELEASE_MIRROR_STAGE=""
  release_residue_capture_entry_identity RELEASE_MIRROR_COMMITTED_IDENTITY \
    "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR" || return 1
  IFS=: read -r committed_parent_device committed_parent_inode committed_parent_ctime \
    committed_kind committed_device committed_inode committed_ctime \
    <<< "$RELEASE_MIRROR_COMMITTED_IDENTITY"
  # See selection activation: rename may change symlink ctime, so record the
  # post-rename identity and revalidate it before reporting a committed mirror.
  if [ "$committed_kind" != "symlink" ] \
    || [ "${committed_device}:${committed_inode}" \
      != "${stage_device}:${stage_inode}" ] \
    || ! release_residue_entry_identity_matches "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR" \
      "$RELEASE_MIRROR_COMMITTED_IDENTITY"; then
    printf '  BLOCK %s (mirror link changed after activation; legacy backup preserved)\n' \
      "$RELEASE_MIRROR" >&2
    return 1
  fi
  # See the corresponding selection marker: retain this marker until EXIT so
  # a hard-killed process leaves evidence that blocks an unsafe retry.
  if [ -n "$RELEASE_MIRROR_BACKUP" ]; then
    release_residue_remove_runtime_entry "$RELEASE_MIRROR_BACKUP_IDENTITY" \
      "$RELEASE_MIRROR_PARENT" "$RELEASE_MIRROR_BACKUP" \
      "$RELEASE_MIRROR_BACKUP_MARKER" "directory" || return 1
    RELEASE_MIRROR_BACKUP=""
    RELEASE_MIRROR_BACKUP_MARKER=""
    RELEASE_MIRROR_BACKUP_IDENTITY=""
  fi
}

install_release_skill() {
  local src_dir="$1"
  local dest="$2"
  local source_tree version_dir selection_target mirror_target
  local selected_needs_update="1"

  RELEASE_SELECTION_DEST="$dest"
  release_residue_preflight "$HOME/.codex/skill-mirrors/FantasyDisk" \
    "$HOME/.codex/skill-mirrors/FantasyDisk/$RELEASE_VERSIONS_NAME" \
    "$HOME/.codex/skills" || return 1
  prepare_release_selection_parent "$dest" || return 1
  RELEASE_SELECTION_DEST="$RELEASE_SELECTION_PARENT/$RELEASE_SKILL_NAME"
  dest="$RELEASE_SELECTION_DEST"
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
    mkdir "$RELEASE_STAGE" || return 1
    release_residue_write_marker RELEASE_STAGE_MARKER \
    "$RELEASE_VERSIONS" "staging" "$$" "directory" "-" "$source_tree" || return 1
    release_residue_capture_runtime_identity RELEASE_STAGE_IDENTITY \
      "$RELEASE_VERSIONS" "$RELEASE_STAGE" "$RELEASE_STAGE_MARKER" "directory" || return 1
    if ! cp -R "$src_dir/." "$RELEASE_STAGE" \
      || ! release_skill_tree_is_valid "$RELEASE_STAGE" \
      || [ "$(tree_fingerprint "$RELEASE_STAGE")" != "$source_tree" ] \
      || ! mv "$RELEASE_STAGE" "$version_dir"; then
      # Copying into the owned staging directory changes its ctime.  Refresh
      # only after proving the stage and marker are still our original entries
      # so EXIT cleanup can remove a locally failed stage without touching a
      # replacement.
      release_residue_refresh_runtime_identity RELEASE_STAGE_IDENTITY \
        "$RELEASE_STAGE_IDENTITY" "$RELEASE_VERSIONS" "$RELEASE_STAGE" \
        "$RELEASE_STAGE_MARKER" "directory" "1" || true
      printf '  BLOCK %s (staged immutable version verification failed; kept last known-good selection)\n' \
        "$version_dir" >&2
      return 1
    fi
    RELEASE_STAGE=""
    release_residue_remove_runtime_marker "$RELEASE_STAGE_IDENTITY" "$RELEASE_VERSIONS" \
      "$RELEASE_STAGE_MARKER" || return 1
    RELEASE_STAGE_MARKER=""
    RELEASE_STAGE_IDENTITY=""
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
    make_staged_selection_link "$dest" "$version_dir" "$source_tree" || return 1
    release_residue_capture_entry_identity RELEASE_SELECTION_DEST_IDENTITY \
      "$RELEASE_SELECTION_PARENT" "$dest" || return 1
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
# selection boundary. KILL cannot run a trap, so its private residue is left
# untouched and the next invocation fails closed until an operator removes it.
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

  if [ "$src_dir" = "$REPO_ROOT/skills/codex" ] \
    && [ -d "$src_dir/$RELEASE_SKILL_NAME" ]; then
    release_residue_preflight "$HOME/.codex/skill-mirrors/FantasyDisk" \
      "$HOME/.codex/skill-mirrors/FantasyDisk/$RELEASE_VERSIONS_NAME" \
      "$HOME/.codex/skills" || return 1
    prepare_release_selection_parent "$dest_dir/$RELEASE_SKILL_NAME" || return 1
  else
    mkdir -p "$dest_dir"
  fi

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

run_release_only() {
  local source_dir="$REPO_ROOT/skills/codex/$RELEASE_SKILL_NAME"
  local destination="$HOME/.codex/skills/$RELEASE_SKILL_NAME"

  if [ "$#" -ne 1 ]; then
    printf 'usage: bash scripts/onboard.sh --release-only\n' >&2
    return 2
  fi
  if [ ! -d "$source_dir" ]; then
    printf '  BLOCK %s (managed release source is absent)\n' "$source_dir" >&2
    return 1
  fi

  # Keep this mode intentionally narrow: install_release_skill is the sole
  # entrypoint for source verification, immutable version materialization,
  # durable mirror activation, and selected-runtime activation.
  install_release_skill "$source_dir" "$destination"
}

if [ "${1:-}" = "--release-only" ]; then
  run_release_only "$@"
  exit "$?"
fi

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
