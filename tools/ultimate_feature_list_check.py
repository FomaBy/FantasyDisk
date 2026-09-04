#!/usr/bin/env python3
"""Ultimate feature-list checker with a fresh-evidence pass gate (FAN-3904).

``data/ultimates/feature_list.json`` maps every canonical weapon ultimate
(17 classes, 51 weapons) to a behavior summary and a verification recipe.  The
canonical identities come from the immutable schema-v1 catalog under
``data/ultimates/schema/v1/classes`` cross-checked against the class overlays
under ``data/ultimates/classes``; the feature list never becomes a second
editable roster.

A ``passing`` state is never read from the repository.  It exists only in a
report this checker generated from a successful fresh run, bound to the
candidate SHA, the normalized recipe digest and the digest of the actual log.
``--verify-report`` re-derives every binding, so a stale, manual or edited
record fails closed.

Recipes are argv arrays executed without shell interpretation.  The only
allowlisted shape is the repository-local Godot gate launching one suite from
``tests/``; escaping paths, other interpreters, other tools, extra options and
shell metacharacters are refused before anything runs.  Every run is bounded
by a timeout and an output limit, keeps ``user://`` in a scratch directory and
writes only under the task-owned report directory.

Exit status: 0 = every check passed (missing or blocked verification is a
truthful non-failure); 1 = a validation, verification or recipe failure;
2 = usage or environment refusal (including a nested invocation).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

try:
    from tools.quality_gate import EXTENDS_RE, TIMING_SENSITIVE_GODOT_SCRIPTS, fatal_output_signal
except ModuleNotFoundError:
    from quality_gate import EXTENDS_RE, TIMING_SENSITIVE_GODOT_SCRIPTS, fatal_output_signal

REPO_ROOT = Path(__file__).resolve().parents[1]
FEATURE_LIST_PATH = "data/ultimates/feature_list.json"
CATALOG_DIR = "data/ultimates/schema/v1/classes"
OVERLAY_DIR = "data/ultimates/classes"
DEFAULT_REPORT_PATH = "build/ultimate_feature_list/report.json"
DEFAULT_LOG_DIR = "build/ultimate_feature_list/logs"
TASK_OUTPUT_DIR = "build"
EXPECTED_CLASS_COUNT = 17
EXPECTED_WEAPON_COUNT = 51
FEATURE_LIST_SCHEMA_VERSION = 1
REPORT_SCHEMA_VERSION = 1
ENTRY_FIELDS = ("id", "class_id", "weapon_key", "behavior", "state", "verification")
OPTIONAL_ENTRY_FIELDS = ("blocked_reason",)
COMMITTED_STATES = ("not_started", "active", "blocked")
GENERATED_STATES = ("passing", "failed")
ID_RE = re.compile(r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$")
# Any of these inside an argv token would only make sense to a shell; the
# checker never uses one, so the token is a smuggling attempt, not a path.
SHELL_METACHARACTER_RE = re.compile(r"[\s;&|<>$`\\\"'*?()\[\]{}#!\x00-\x1f]")
RECIPE_INTERPRETER = "python3"
RECIPE_RUNNER = "tools/godot_gate.py"
RECIPE_PREFIX = (RECIPE_INTERPRETER, RECIPE_RUNNER, "--headless", "--path", ".", "--script")
RECIPE_ARGV_LENGTH = len(RECIPE_PREFIX) + 1
SCRIPT_PREFIX = "res://tests/"
DEFAULT_TIMEOUT = 900.0
DEFAULT_OUTPUT_LIMIT = 4_000_000
_CLEANUP_TIMEOUT = 30.0
NESTED_GUARD_ENV = "FSD_ULTIMATE_FEATURE_LIST_ACTIVE"
LOG_TAIL_BYTES = 6000


def failure(what: str, consequence: str, fix: str) -> str:
    """Three-part diagnostic: what failed, why it matters, how to correct it."""
    return f"{what}\n  consequence: {consequence}\n  fix: {fix}"


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def normalized_argv(argv: Sequence[str]) -> list[str]:
    """Canonical argv used for the digest: the literal recipe, interpreter token fixed."""
    return [RECIPE_INTERPRETER if index == 0 else token for index, token in enumerate(argv)]


def argv_digest(argv: Sequence[str]) -> str:
    encoded = json.dumps(normalized_argv(argv), ensure_ascii=False, separators=(",", ":"))
    return sha256_bytes(encoded.encode("utf-8"))


def _read_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout.strip()


def candidate_sha(root: Path) -> str:
    sha = _git(root, "rev-parse", "HEAD")
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise RuntimeError(f"HEAD is not a 40-hex commit: {sha!r}")
    return sha


def worktree_dirty_paths(root: Path) -> list[str]:
    status = _git(root, "status", "--porcelain=v1", "--untracked-files=all")
    return [line for line in status.splitlines() if line]


# --------------------------------------------------------------------------
# Canonical discovery
# --------------------------------------------------------------------------


def canonical_identities(root: Path) -> tuple[list[str], dict[str, dict], list[str]]:
    """Ordered class ids and ``class/weapon`` identities from the canonical catalog.

    The schema-v1 catalog is the identity source; the class overlays must name
    exactly the same pairs, otherwise discovery itself is inconsistent and the
    feature list cannot be validated against a single truth.
    """
    errors: list[str] = []
    catalog_dir = root / CATALOG_DIR
    overlay_dir = root / OVERLAY_DIR
    if not catalog_dir.is_dir():
        return [], {}, [failure(
            f"canonical catalog directory {CATALOG_DIR} is missing",
            "no canonical identities exist to validate the feature list against",
            "run the checker from a FantasyDisk checkout that carries the schema-v1 catalog",
        )]
    ordered: list[tuple[int, str]] = []
    identities: dict[str, dict] = {}
    for path in sorted(catalog_dir.glob("*.json")):
        try:
            document = _read_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(failure(
                f"canonical catalog {path.relative_to(root).as_posix()} cannot be parsed: {exc}",
                "identities for that class are unknown",
                "repair the catalog file; the feature list checker never edits it",
            ))
            continue
        class_id = document.get("class_id") if isinstance(document, dict) else None
        if class_id != path.stem or not isinstance(class_id, str) or not ID_RE.match(class_id):
            errors.append(failure(
                f"canonical catalog {path.name} declares class_id {class_id!r}",
                "the class cannot be identified consistently by file and content",
                "keep the catalog file name equal to its class_id",
            ))
            continue
        order = document.get("class_order")
        ordered.append((order if isinstance(order, int) else len(ordered), class_id))
        profiles = document.get("profiles")
        if not isinstance(profiles, list):
            errors.append(failure(
                f"canonical catalog {path.name} has no profiles list",
                "no weapons are known for {class_id}",
                "repair the catalog file",
            ))
            continue
        for profile in profiles:
            weapon_id = profile.get("weapon_id") if isinstance(profile, dict) else None
            if not isinstance(weapon_id, str) or not ID_RE.match(weapon_id):
                errors.append(failure(
                    f"canonical catalog {path.name} carries a profile without a valid weapon_id",
                    "that weapon cannot be mapped",
                    "repair the catalog profile",
                ))
                continue
            key = f"{class_id}/{weapon_id}"
            if key in identities:
                errors.append(failure(
                    f"canonical catalog {path.name} lists weapon {weapon_id} twice",
                    "the feature list cannot map one identity to one entry",
                    "remove the duplicate profile from the catalog",
                ))
                continue
            identity = profile.get("identity") if isinstance(profile.get("identity"), dict) else {}
            identities[key] = {
                "class_id": class_id,
                "weapon_key": weapon_id,
                "profile_id": identity.get("profile_id", ""),
            }
    ordered.sort()
    classes = [class_id for _, class_id in ordered]
    overlays = {
        f"{path.parent.name}/{path.stem}"
        for path in overlay_dir.glob("*/*.json")
    } if overlay_dir.is_dir() else set()
    if overlays != set(identities):
        missing = sorted(set(identities) - overlays)
        extra = sorted(overlays - set(identities))
        errors.append(failure(
            "canonical catalog and class overlays disagree: "
            f"overlay missing {missing or 'none'}, overlay extra {extra or 'none'}",
            "canonical discovery is inconsistent, so no roster can be trusted",
            f"reconcile {CATALOG_DIR} and {OVERLAY_DIR} before mapping the feature list",
        ))
    return classes, identities, errors


# --------------------------------------------------------------------------
# Recipe allowlist
# --------------------------------------------------------------------------


def _token_errors(token: object, position: int) -> list[str]:
    if not isinstance(token, str) or not token:
        return [failure(
            f"argv[{position}] is not a non-empty string",
            "the recipe cannot be executed without shell interpretation",
            "write every argv element as a plain string",
        )]
    if SHELL_METACHARACTER_RE.search(token):
        return [failure(
            f"argv[{position}] {token!r} contains whitespace or a shell metacharacter",
            "the token only has meaning to a shell, which the checker never invokes",
            "use one plain token per argv element with no quoting, pipes or expansions",
        )]
    if os.path.isabs(token) or token.startswith(("~", "/", "\\")) or re.match(r"^[A-Za-z]:", token):
        return [failure(
            f"argv[{position}] {token!r} is an absolute or home-relative path",
            "the recipe could reach outside the repository",
            "reference repository files by their repository-relative path",
        )]
    if ".." in token.split("/") or ".." in token.split("\\") or "\\" in token:
        return [failure(
            f"argv[{position}] {token!r} escapes or uses a non-canonical separator",
            "the recipe could reach outside the repository",
            "use forward-slash repository-relative paths without '..'",
        )]
    return []


def validate_recipe(argv: object, root: Path) -> tuple[str, list[str]]:
    """Return ``(script_resource_path, errors)`` for an argv recipe.

    Only the exact ``python3 tools/godot_gate.py --headless --path . --script
    res://tests/<suite>.gd`` shape is admitted.  The runner must be the real
    repository file, the suite must be a Godot test under ``tests/`` and never
    a timing-exclusive suite, and no other interpreter, tool or option exists.
    """
    if not isinstance(argv, list) or not argv:
        return "", [failure(
            "verification is not a non-empty argv array",
            "nothing can be executed for the entry",
            "write verification as a JSON array of plain string tokens",
        )]
    errors: list[str] = []
    for position, token in enumerate(argv):
        errors.extend(_token_errors(token, position))
    if errors:
        return "", errors
    if argv[0] != RECIPE_INTERPRETER:
        return "", [failure(
            f"argv[0] {argv[0]!r} is not the allowlisted interpreter {RECIPE_INTERPRETER!r}",
            "arbitrary interpreters and binaries could run under the checker",
            f"start every recipe with {RECIPE_INTERPRETER!r}",
        )]
    if len(argv) < 2 or argv[1] != RECIPE_RUNNER:
        runner = argv[1] if len(argv) > 1 else "<missing>"
        return "", [failure(
            f"argv[1] {runner!r} is not the allowlisted runner {RECIPE_RUNNER!r}",
            "only the repository Godot gate may launch a suite; this also refuses "
            "recursive quality-gate and checker invocations",
            f"launch suites through {RECIPE_RUNNER!r}",
        )]
    if len(argv) != RECIPE_ARGV_LENGTH or tuple(argv[:len(RECIPE_PREFIX)]) != RECIPE_PREFIX:
        return "", [failure(
            f"argv {argv!r} does not match the allowlisted shape {list(RECIPE_PREFIX) + ['res://tests/<suite>.gd']}",
            "unapproved options could change what the Godot gate does",
            "use exactly the allowlisted argv shape with one suite path",
        )]
    script = argv[-1]
    if not script.startswith(SCRIPT_PREFIX) or not script.endswith(".gd"):
        return "", [failure(
            f"suite {script!r} is not a res://tests/ GDScript path",
            "only repository test suites are approved evidence",
            f"point --script at a suite under {SCRIPT_PREFIX}",
        )]
    relative = script[len("res://"):]
    tests_dir = (root / "tests").resolve()
    try:
        resolved = (root / relative).resolve(strict=True)
    except (OSError, RuntimeError):
        return "", [failure(
            f"suite {script!r} does not exist",
            "the entry would claim evidence from a suite that cannot run",
            "map the entry to an existing suite or mark it blocked with the missing-suite reason",
        )]
    if not resolved.is_file() or tests_dir not in resolved.parents:
        return "", [failure(
            f"suite {script!r} resolves outside {tests_dir}",
            "a symlink or path trick would execute code outside the test tree",
            "use a regular file that lives under tests/",
        )]
    if not (root / RECIPE_RUNNER).is_file():
        return "", [failure(
            f"runner {RECIPE_RUNNER} is missing from the repository",
            "the recipe cannot be executed",
            "run the checker from a complete checkout",
        )]
    try:
        source = resolved.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return "", [failure(
            f"suite {script!r} cannot be read: {exc}",
            "the suite cannot be proven to be a Godot test",
            "fix the file encoding or map a different suite",
        )]
    if not EXTENDS_RE.search(source):
        return "", [failure(
            f"suite {script!r} is not a SceneTree test suite",
            "the Godot gate would run a helper, not a verification",
            "map the entry to a suite that extends SceneTree or a tests/ base suite",
        )]
    if script in TIMING_SENSITIVE_GODOT_SCRIPTS:
        return "", [failure(
            f"suite {script!r} requires machine-wide exclusivity",
            "the checker runs suites without the exclusive lease, so its verdict would be noise",
            "map the entry to a non-exclusive suite; exclusive suites belong to the quality gate",
        )]
    return script, []


# --------------------------------------------------------------------------
# Feature list validation
# --------------------------------------------------------------------------


def load_feature_list(path: Path) -> tuple[dict, list[str]]:
    try:
        document = _read_json(path)
    except (OSError, json.JSONDecodeError) as exc:
        return {}, [failure(
            f"feature list {path} cannot be parsed: {exc}",
            "no entry can be validated or verified",
            "restore a valid JSON feature list",
        )]
    if not isinstance(document, dict):
        return {}, [failure(
            "feature list root is not a JSON object",
            "no entry can be validated or verified",
            'use {"schema_version": 1, "entries": [...]}',
        )]
    return document, []


def validate_feature_list(
    document: dict, classes: Sequence[str], identities: dict[str, dict], root: Path
) -> tuple[list[dict], list[str]]:
    """Validate structure, cardinality, identity and recipes; return ``(entries, errors)``."""
    errors: list[str] = []
    if document.get("schema_version") != FEATURE_LIST_SCHEMA_VERSION:
        errors.append(failure(
            f"feature list schema_version is {document.get('schema_version')!r}",
            "the checker cannot interpret the file",
            f"set schema_version to {FEATURE_LIST_SCHEMA_VERSION}",
        ))
    entries = document.get("entries")
    if not isinstance(entries, list):
        errors.append(failure(
            "feature list has no entries array",
            "no ultimate is mapped",
            "add an entries array with one object per canonical weapon",
        ))
        return [], errors
    seen_ids: dict[str, int] = {}
    valid: list[dict] = []
    for index, entry in enumerate(entries):
        label = f"entry #{index}"
        if not isinstance(entry, dict):
            errors.append(failure(
                f"{label} is not an object",
                "the entry cannot be mapped",
                "write every entry as a JSON object",
            ))
            continue
        entry_id = entry.get("id")
        label = f"entry {entry_id!r}" if isinstance(entry_id, str) else label
        unknown = sorted(set(entry) - set(ENTRY_FIELDS) - set(OPTIONAL_ENTRY_FIELDS))
        missing = [field for field in ENTRY_FIELDS if field not in entry]
        if "evidence" in unknown:
            errors.append(failure(
                f"{label} carries committed evidence",
                "committed evidence is fabricated by definition and is never proof",
                "delete the evidence field; evidence exists only in the generated report",
            ))
            unknown.remove("evidence")
        if unknown:
            errors.append(failure(
                f"{label} has unknown fields {unknown}",
                "the entry does not follow the contract",
                f"keep only {list(ENTRY_FIELDS)} plus optional {list(OPTIONAL_ENTRY_FIELDS)}",
            ))
        if missing:
            errors.append(failure(
                f"{label} is missing fields {missing}",
                "the entry cannot be mapped or verified",
                f"add {missing}",
            ))
            continue
        class_id = entry.get("class_id")
        weapon_key = entry.get("weapon_key")
        if not isinstance(entry_id, str) or not isinstance(class_id, str) or not isinstance(weapon_key, str):
            errors.append(failure(
                f"{label} has a non-string id, class_id or weapon_key",
                "the entry cannot be matched to a canonical identity",
                "write id, class_id and weapon_key as strings",
            ))
            continue
        if entry_id != f"{class_id}/{weapon_key}":
            errors.append(failure(
                f"{label} id does not equal class_id/weapon_key ({class_id}/{weapon_key})",
                "a swapped or mistyped key would attach evidence to the wrong ultimate",
                "set id to exactly '<class_id>/<weapon_key>' from the canonical catalog",
            ))
            continue
        if entry_id not in identities:
            errors.append(failure(
                f"{label} is not a canonical class/weapon identity",
                "an extra or misspelled entry would count as coverage that does not exist",
                f"use only identities discovered from {CATALOG_DIR}",
            ))
            continue
        if entry_id in seen_ids:
            errors.append(failure(
                f"{label} is duplicated (also entry #{seen_ids[entry_id]})",
                "duplicate entries would double-count one ultimate",
                "keep exactly one entry per canonical identity",
            ))
            continue
        seen_ids[entry_id] = index
        behavior = entry.get("behavior")
        if not isinstance(behavior, str) or not behavior.strip():
            errors.append(failure(
                f"{label} has an empty behavior summary",
                "a reader cannot tell what the verification is supposed to prove",
                "describe the ultimate's behavior in one or two sentences",
            ))
        state = entry.get("state")
        if state in GENERATED_STATES:
            errors.append(failure(
                f"{label} commits state {state!r}",
                "a committed pass is a manual claim, never a verification result",
                f"commit only {list(COMMITTED_STATES)}; passing exists only in a fresh report",
            ))
            continue
        if state not in COMMITTED_STATES:
            errors.append(failure(
                f"{label} has unknown state {state!r}",
                "the checker cannot decide whether to run, skip or block the entry",
                f"use one of {list(COMMITTED_STATES)}",
            ))
            continue
        verification = entry.get("verification")
        blocked_reason = entry.get("blocked_reason")
        if state == "active":
            script, recipe_errors = validate_recipe(verification, root)
            errors.extend(f"{label}: {error}" for error in recipe_errors)
            if recipe_errors:
                continue
            if blocked_reason is not None:
                errors.append(failure(
                    f"{label} is active but carries blocked_reason",
                    "the entry contradicts itself",
                    "remove blocked_reason or set state to blocked",
                ))
                continue
            valid.append({**entry, "script": script, "argv_digest": argv_digest(verification)})
            continue
        if verification is not None:
            errors.append(failure(
                f"{label} is {state} but declares a verification recipe",
                "a recipe on a non-active entry would either run unexpectedly or hide a runnable check",
                "set state to active or remove the recipe",
            ))
            continue
        if state == "blocked" and (not isinstance(blocked_reason, str) or not blocked_reason.strip()):
            errors.append(failure(
                f"{label} is blocked without a blocked_reason naming the missing suite",
                "a blocker without a named condition cannot be resolved",
                "name the missing or broken suite in blocked_reason",
            ))
            continue
        if state == "not_started" and blocked_reason is not None:
            errors.append(failure(
                f"{label} is not_started but carries blocked_reason",
                "the entry contradicts itself",
                "remove blocked_reason or set state to blocked",
            ))
            continue
        valid.append(dict(entry))
    missing_ids = sorted(set(identities) - set(seen_ids))
    if missing_ids:
        errors.append(failure(
            f"feature list is missing canonical entries {missing_ids}",
            "coverage would silently be less than 17 classes / 51 weapons",
            "add one entry per missing identity (not_started is acceptable)",
        ))
    covered_classes = {identities[key]["class_id"] for key in seen_ids}
    if not errors and (
        len(classes) != EXPECTED_CLASS_COUNT
        or len(identities) != EXPECTED_WEAPON_COUNT
        or len(covered_classes) != EXPECTED_CLASS_COUNT
        or len(seen_ids) != EXPECTED_WEAPON_COUNT
    ):
        errors.append(failure(
            f"coverage is {len(covered_classes)} classes / {len(seen_ids)} weapons "
            f"against {len(classes)} / {len(identities)} canonical; "
            f"expected {EXPECTED_CLASS_COUNT} / {EXPECTED_WEAPON_COUNT}",
            "the 17-class / 51-weapon invariant is broken",
            "reconcile the canonical catalog and the feature list",
        ))
    return valid, errors


# --------------------------------------------------------------------------
# Bounded execution
# --------------------------------------------------------------------------


def _descendant_pids(pid: int) -> list[int]:
    if os.name == "nt":
        return []
    listing = subprocess.run(
        ["ps", "-Ao", "pid=,ppid="],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    children: dict[int, list[int]] = {}
    for line in listing.stdout.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[0].isdigit() and fields[1].isdigit():
            children.setdefault(int(fields[1]), []).append(int(fields[0]))
    found: list[int] = []
    pending = [pid]
    while pending:
        for child in children.get(pending.pop(), ()):
            if child not in found and child != pid:
                found.append(child)
                pending.append(child)
    return found


def _terminate(process: subprocess.Popen) -> None:
    descendants = _descendant_pids(process.pid)
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/F", "/T", "/PID", str(process.pid)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if process.poll() is None:
            process.kill()
        return
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    for pid in descendants:
        try:
            os.kill(pid, signal.SIGKILL)
        except (ProcessLookupError, OSError):
            continue


def execution_environment(scratch: Path) -> dict[str, str]:
    """Scratch HOME and user data; Godot resolved before HOME is redirected."""
    env = os.environ.copy()
    if not env.get("GODOT_BIN") and not env.get("GODOT"):
        candidates = [shutil.which("godot4"), shutil.which("godot")]
        if sys.platform == "darwin":
            candidates.insert(0, str(Path.home() / "Downloads/Godot.app/Contents/MacOS/Godot"))
        for candidate in candidates:
            if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
                env["GODOT_BIN"] = candidate
                break
    env["HOME"] = str(scratch)
    env["XDG_DATA_HOME"] = str(scratch)
    env["APPDATA"] = str(scratch)
    env["LOCALAPPDATA"] = str(scratch)
    env["FSD_GODOT_EXCLUSIVE"] = ""
    env["PYTHONPYCACHEPREFIX"] = str(scratch / "pycache")
    env[NESTED_GUARD_ENV] = "1"
    return env


def execute_recipe(
    argv: Sequence[str],
    root: Path,
    timeout: float,
    output_limit: int,
) -> dict:
    """Run one allowlisted recipe without a shell, bounded by time and output."""
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="fsd-ultimate-feature-") as scratch_dir:
        scratch = Path(scratch_dir).resolve()
        command = [sys.executable, str(root / RECIPE_RUNNER), *argv[2:-1], argv[-1]]
        # Keep user:// out of the checkout; the suite path itself is untouched.
        command.append(f"--user-data-dir={scratch / 'user'}")
        command.insert(len(command) - 1, "--")
        kwargs: dict = {
            "cwd": root,
            "env": execution_environment(scratch),
            "stdin": subprocess.DEVNULL,
            "stdout": subprocess.PIPE,
            "stderr": subprocess.STDOUT,
        }
        if os.name == "nt":
            kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
        else:
            kwargs["start_new_session"] = True
        process = subprocess.Popen(command, **kwargs)
        chunks: list[bytes] = []
        size = [0]
        overflow = threading.Event()
        done = threading.Event()

        def drain() -> None:
            assert process.stdout is not None
            try:
                while True:
                    chunk = process.stdout.read1(65536) if hasattr(process.stdout, "read1") \
                        else process.stdout.read(65536)
                    if not chunk:
                        return
                    if size[0] + len(chunk) > output_limit:
                        chunks.append(chunk[: max(0, output_limit - size[0])])
                        size[0] = output_limit
                        overflow.set()
                        return
                    chunks.append(chunk)
                    size[0] += len(chunk)
            except (OSError, ValueError):
                pass
            finally:
                done.set()

        reader = threading.Thread(target=drain, name="ultimate-feature-reader", daemon=True)
        reader.start()
        timed_out = False
        while process.poll() is None or not done.is_set():
            if time.monotonic() - started >= timeout:
                timed_out = True
                break
            if overflow.is_set():
                break
            time.sleep(0.01)
        if timed_out or overflow.is_set():
            _terminate(process)
        try:
            process.wait(timeout=_CLEANUP_TIMEOUT)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=_CLEANUP_TIMEOUT)
        reader.join(timeout=_CLEANUP_TIMEOUT)
        if process.stdout is not None:
            process.stdout.close()
        reader.join(timeout=_CLEANUP_TIMEOUT)
    output = b"".join(chunks)
    exit_code = 124 if timed_out else process.returncode
    text = output.decode("utf-8", errors="replace")
    diagnostic = fatal_output_signal(text)
    reasons: list[str] = []
    if timed_out:
        reasons.append(f"timeout after {timeout:.0f}s")
    if overflow.is_set():
        reasons.append(f"output exceeded {output_limit} bytes")
    if diagnostic:
        reasons.append(f"fatal diagnostic: {diagnostic}")
    if exit_code != 0 and not timed_out:
        reasons.append(f"exit {exit_code}")
    return {
        "executed_argv": command,
        "exit_code": exit_code,
        "timed_out": timed_out,
        "output_truncated": overflow.is_set(),
        "fatal_diagnostic": diagnostic,
        "duration_seconds": round(time.monotonic() - started, 3),
        "log_bytes": output,
        "passed": not reasons,
        "reasons": reasons,
    }


# --------------------------------------------------------------------------
# Report generation and verification
# --------------------------------------------------------------------------


def _within_task_output(root: Path, path: Path) -> bool:
    try:
        resolved = path.resolve()
    except OSError:
        return False
    return (root / TASK_OUTPUT_DIR).resolve() in resolved.parents


def load_profile_results(root: Path, path: Path | None, sha: str) -> tuple[dict[str, dict], list[str]]:
    """Suites the invoking quality-gate profile already executed on this candidate."""
    if path is None:
        return {}, []
    try:
        document = _read_json(path)
    except (OSError, json.JSONDecodeError) as exc:
        return {}, [failure(
            f"profile results {path} cannot be parsed: {exc}",
            "profile evidence cannot be reused, so nothing is deduplicated",
            "pass the manifest written by tools/quality_gate.py or omit --profile-results",
        )]
    if not isinstance(document, dict) or document.get("candidate_sha") != sha:
        return {}, [failure(
            f"profile results {path} do not belong to candidate {sha}",
            "evidence from another candidate would be attached to this one",
            "regenerate the manifest in the same quality-gate run",
        )]
    suites = document.get("suites")
    if not isinstance(suites, dict):
        return {}, []
    reusable: dict[str, dict] = {}
    for script, result in suites.items():
        if not isinstance(result, dict) or not isinstance(result.get("log_path"), str):
            continue
        log_path = root / result["log_path"]
        if not _within_task_output(root, log_path) or not log_path.is_file():
            continue
        reusable[script] = {**result, "log_file": log_path}
    return reusable, []


def _entry_record(entry: dict, state: str, reason: str = "", evidence: dict | None = None) -> dict:
    record = {
        "id": entry["id"],
        "class_id": entry["class_id"],
        "weapon_key": entry["weapon_key"],
        "behavior": entry.get("behavior", ""),
        "state": state,
    }
    if reason:
        record["reason"] = reason
    if evidence is not None:
        record["evidence"] = evidence
    return record


def generate_report(
    root: Path,
    entries: Sequence[dict],
    sha: str,
    feature_list_digest: str,
    report_path: Path,
    log_dir: Path,
    timeout: float,
    output_limit: int,
    profile_results: dict[str, dict],
    execute: bool = True,
) -> tuple[dict, list[str]]:
    """Execute every distinct recipe once and bind its evidence to all covered entries.

    With ``execute=False`` (the quality gate's ``--bind-only``) nothing is
    launched: a recipe the invoking profile did not run fails as unexecuted.
    """
    errors: list[str] = []
    log_dir.mkdir(parents=True, exist_ok=True)
    for stale in log_dir.glob("*.log"):
        stale.unlink()
    recipes: dict[str, dict] = {}
    for entry in entries:
        if entry["state"] != "active":
            continue
        recipe = recipes.setdefault(entry["argv_digest"], {
            "argv": list(entry["verification"]),
            "script": entry["script"],
            "entries": [],
        })
        recipe["entries"].append(entry["id"])
    print(
        f"ultimate_feature_list: {len(entries)} entries, {len(recipes)} distinct recipes, "
        f"candidate {sha}",
        flush=True,
    )
    results: dict[str, dict] = {}
    for index, (digest, recipe) in enumerate(recipes.items(), start=1):
        script = recipe["script"]
        reused = profile_results.get(script)
        print(
            f"RECIPE {index}/{len(recipes)} {script} -> {', '.join(recipe['entries'])}",
            flush=True,
        )
        if reused is not None:
            log_bytes = Path(reused["log_file"]).read_bytes()
            text = log_bytes.decode("utf-8", errors="replace")
            diagnostic = fatal_output_signal(text)
            timed_out = bool(reused.get("timed_out"))
            exit_code = reused.get("exit_code")
            reasons = []
            if timed_out:
                reasons.append("timeout in the invoking profile")
            if diagnostic:
                reasons.append(f"fatal diagnostic: {diagnostic}")
            if exit_code != 0 and not timed_out:
                reasons.append(f"exit {exit_code}")
            outcome = {
                "executed_argv": reused.get("executed_argv", []),
                "exit_code": exit_code,
                "timed_out": timed_out,
                "output_truncated": False,
                "fatal_diagnostic": diagnostic,
                "duration_seconds": reused.get("duration_seconds", 0.0),
                "log_bytes": log_bytes,
                "passed": not reasons,
                "reasons": reasons,
                "executed_by": "quality_gate_profile",
            }
        elif not execute:
            outcome = {
                "executed_argv": [],
                "exit_code": None,
                "timed_out": False,
                "output_truncated": False,
                "fatal_diagnostic": "",
                "duration_seconds": 0.0,
                "log_bytes": b"",
                "passed": False,
                "reasons": ["not executed by the invoking profile"],
                "executed_by": "none",
            }
        else:
            outcome = execute_recipe(recipe["argv"], root, timeout, output_limit)
            outcome["executed_by"] = "ultimate_feature_list_check"
        log_path = log_dir / f"{digest}.log"
        log_path.write_bytes(outcome["log_bytes"])
        log_digest = sha256_bytes(outcome["log_bytes"])
        verdict = "PASS" if outcome["passed"] else "FAIL"
        print(
            f"{verdict}  {script} ({outcome['duration_seconds']:.1f}s"
            + (f"; {'; '.join(outcome['reasons'])}" if outcome["reasons"] else "")
            + ")",
            file=sys.stdout if outcome["passed"] else sys.stderr,
            flush=True,
        )
        if not outcome["passed"]:
            tail = outcome["log_bytes"][-LOG_TAIL_BYTES:].decode("utf-8", errors="replace")
            print(tail, file=sys.stderr, flush=True)
            errors.append(failure(
                f"recipe {script} failed: {'; '.join(outcome['reasons'])}",
                f"entries {recipe['entries']} cannot pass on candidate {sha}",
                f"fix the suite or the ultimate it verifies; see {log_path.relative_to(root).as_posix()}",
            ))
        results[digest] = {
            "argv": recipe["argv"],
            "script": script,
            "executed_argv": outcome["executed_argv"],
            "executed_by": outcome["executed_by"],
            "exit_code": outcome["exit_code"],
            "timed_out": outcome["timed_out"],
            "output_truncated": outcome["output_truncated"],
            "fatal_diagnostic": outcome["fatal_diagnostic"],
            "duration_seconds": outcome["duration_seconds"],
            "log_path": log_path.relative_to(root).as_posix(),
            "log_digest": log_digest,
            "passed": outcome["passed"],
            "reasons": outcome["reasons"],
            "entries": recipe["entries"],
        }
    records: list[dict] = []
    for entry in entries:
        state = entry["state"]
        if state == "active":
            result = results[entry["argv_digest"]]
            evidence = {
                "candidate_sha": sha,
                "argv_digest": entry["argv_digest"],
                "log_digest": result["log_digest"],
                "log_path": result["log_path"],
                "exit_code": result["exit_code"],
                "executed_by": result["executed_by"],
            }
            if result["passed"]:
                records.append(_entry_record(entry, "passing", evidence=evidence))
            else:
                records.append(_entry_record(
                    entry, "failed", reason="; ".join(result["reasons"]), evidence=evidence
                ))
        elif state == "blocked":
            records.append(_entry_record(entry, "blocked", reason=entry["blocked_reason"]))
        else:
            records.append(_entry_record(entry, "not_started", reason="no verification recipe mapped"))
    summary = {state: 0 for state in ("passing", "failed", "blocked", "not_started")}
    for record in records:
        summary[record["state"]] += 1
    report = {
        "schema_version": REPORT_SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "candidate_sha": sha,
        "worktree_dirty": worktree_dirty_paths(root),
        "feature_list_digest": feature_list_digest,
        "canonical": {"classes": EXPECTED_CLASS_COUNT, "weapons": EXPECTED_WEAPON_COUNT},
        "recipes": results,
        "entries": records,
        "summary": summary,
        "status": "failed" if errors else "passed",
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report, errors


def verify_report(
    root: Path, report_path: Path, entries: Sequence[dict], sha: str
) -> list[str]:
    """Re-derive every binding of a stored report against the current candidate."""
    try:
        report = _read_json(report_path)
    except (OSError, json.JSONDecodeError) as exc:
        return [failure(
            f"report {report_path} cannot be parsed: {exc}",
            "no evidence can be verified",
            "regenerate the report with a fresh checker run",
        )]
    errors: list[str] = []
    if not isinstance(report, dict) or report.get("schema_version") != REPORT_SCHEMA_VERSION:
        return [failure(
            f"report {report_path} has an unsupported schema",
            "no evidence can be verified",
            "regenerate the report with the current checker",
        )]
    if report.get("candidate_sha") != sha:
        errors.append(failure(
            f"report candidate {report.get('candidate_sha')!r} is not HEAD {sha}",
            "every passing record is stale: it proves another commit",
            "regenerate the report on the current candidate",
        ))
    by_id = {entry["id"]: entry for entry in entries}
    records = report.get("entries")
    if not isinstance(records, list):
        return errors + [failure(
            "report has no entries array",
            "no evidence can be verified",
            "regenerate the report",
        )]
    seen: set[str] = set()
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("id"), str):
            errors.append(failure(
                "report carries a malformed entry record",
                "the record cannot be matched to an ultimate",
                "regenerate the report",
            ))
            continue
        entry_id = record["id"]
        seen.add(entry_id)
        entry = by_id.get(entry_id)
        if entry is None:
            errors.append(failure(
                f"report entry {entry_id!r} is not in the current feature list",
                "evidence would be attached to an ultimate that is not mapped",
                "regenerate the report against the current feature list",
            ))
            continue
        state = record.get("state")
        if state in ("blocked", "not_started"):
            if entry["state"] != state:
                errors.append(failure(
                    f"report entry {entry_id!r} is {state} but the feature list says {entry['state']}",
                    "the report no longer describes the committed mapping",
                    "regenerate the report",
                ))
            continue
        if state != "passing":
            errors.append(failure(
                f"report entry {entry_id!r} is {state!r}",
                "the candidate carries a failed or unknown verification",
                "fix the failure and regenerate the report",
            ))
            continue
        if entry["state"] != "active":
            errors.append(failure(
                f"report entry {entry_id!r} passes but the feature list marks it {entry['state']}",
                "a pass without a recipe is a manual claim",
                "regenerate the report",
            ))
            continue
        evidence = record.get("evidence")
        if not isinstance(evidence, dict):
            errors.append(failure(
                f"report entry {entry_id!r} passes without evidence",
                "a pass without evidence is a manual claim",
                "regenerate the report with a fresh run",
            ))
            continue
        if evidence.get("candidate_sha") != sha:
            errors.append(failure(
                f"report entry {entry_id!r} evidence is bound to {evidence.get('candidate_sha')!r}, not HEAD",
                "the pass proves another commit",
                "regenerate the report on the current candidate",
            ))
            continue
        if evidence.get("argv_digest") != entry["argv_digest"]:
            errors.append(failure(
                f"report entry {entry_id!r} evidence was produced by a different recipe",
                "the committed recipe changed after the run, so the pass does not describe it",
                "regenerate the report with the current recipe",
            ))
            continue
        if evidence.get("exit_code") != 0:
            errors.append(failure(
                f"report entry {entry_id!r} passes with exit code {evidence.get('exit_code')!r}",
                "a non-zero run can never be a pass",
                "regenerate the report",
            ))
            continue
        log_relative = evidence.get("log_path")
        log_path = root / log_relative if isinstance(log_relative, str) else None
        if log_path is None or not _within_task_output(root, log_path) or not log_path.is_file():
            errors.append(failure(
                f"report entry {entry_id!r} log {log_relative!r} is missing or outside build/",
                "the pass cannot be traced to an actual run",
                "regenerate the report; logs live under build/",
            ))
            continue
        log_bytes = log_path.read_bytes()
        if sha256_bytes(log_bytes) != evidence.get("log_digest"):
            errors.append(failure(
                f"report entry {entry_id!r} log digest does not match {log_relative}",
                "the log was edited or replaced after the run",
                "regenerate the report with a fresh run",
            ))
            continue
        diagnostic = fatal_output_signal(log_bytes.decode("utf-8", errors="replace"))
        if diagnostic:
            errors.append(failure(
                f"report entry {entry_id!r} log carries a fatal diagnostic ({diagnostic})",
                "the suite announced a failure, so the pass is false",
                "fix the suite or the ultimate and regenerate the report",
            ))
    missing = sorted(set(by_id) - seen)
    if missing:
        errors.append(failure(
            f"report lacks entries {missing}",
            "coverage in the report is incomplete",
            "regenerate the report",
        ))
    return errors


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="repository root (default: this checkout)")
    parser.add_argument("--feature-list", default=FEATURE_LIST_PATH, help="feature list path relative to root")
    parser.add_argument("--report", default=DEFAULT_REPORT_PATH, help="generated report path relative to root")
    parser.add_argument("--log-dir", default=DEFAULT_LOG_DIR, help="recipe log directory relative to root")
    parser.add_argument("--validate-only", action="store_true", help="validate the list and recipes; run nothing")
    parser.add_argument("--verify-report", help="verify a stored report against HEAD instead of running")
    parser.add_argument(
        "--profile-results",
        help="quality-gate manifest of suites already executed on this candidate (deduplication)",
    )
    parser.add_argument(
        "--bind-only",
        action="store_true",
        help="never launch a recipe; bind evidence from --profile-results and fail unexecuted recipes",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=float(os.getenv("FSD_GODOT_TEST_TIMEOUT", str(DEFAULT_TIMEOUT))),
        help="per-recipe timeout in seconds",
    )
    parser.add_argument(
        "--output-limit", type=int, default=DEFAULT_OUTPUT_LIMIT, help="per-recipe captured output limit in bytes"
    )
    return parser.parse_args(argv)


def _print_errors(errors: Sequence[str]) -> None:
    for error in errors:
        print(f"ULTIMATE FEATURE LIST FAIL: {error}", file=sys.stderr, flush=True)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    if os.environ.get(NESTED_GUARD_ENV):
        print(
            "ultimate_feature_list_check: refusing a nested invocation (a recipe may not "
            "call the checker or the quality gate)",
            file=sys.stderr,
        )
        return 2
    if args.timeout <= 0 or args.output_limit <= 0:
        print("ultimate_feature_list_check: timeout and output limit must be positive", file=sys.stderr)
        return 2
    if args.bind_only and not args.profile_results:
        print("ultimate_feature_list_check: --bind-only requires --profile-results", file=sys.stderr)
        return 2
    root = args.root.resolve()
    report_path = root / args.report
    log_dir = root / args.log_dir
    if not args.validate_only and not args.verify_report:
        for label, path in (("--report", report_path), ("--log-dir", log_dir)):
            if not _within_task_output(root, path):
                print(
                    f"ultimate_feature_list_check: {label} must stay under {TASK_OUTPUT_DIR}/ "
                    "(task-owned output only)",
                    file=sys.stderr,
                )
                return 2
    feature_list_path = root / args.feature_list
    classes, identities, errors = canonical_identities(root)
    document, load_errors = load_feature_list(feature_list_path)
    errors.extend(load_errors)
    entries: list[dict] = []
    if not load_errors:
        entries, list_errors = validate_feature_list(document, classes, identities, root)
        errors.extend(list_errors)
    if errors:
        _print_errors(errors)
        print(f"ULTIMATE FEATURE LIST FAILED: {len(errors)} validation error(s)", file=sys.stderr)
        return 1
    active = sum(1 for entry in entries if entry["state"] == "active")
    recipes = len({entry["argv_digest"] for entry in entries if entry["state"] == "active"})
    print(
        f"ultimate_feature_list: {len(classes)} classes / {len(identities)} weapons validated; "
        f"{active} active entries over {recipes} distinct recipes",
        flush=True,
    )
    if args.validate_only:
        return 0
    try:
        sha = candidate_sha(root)
    except RuntimeError as exc:
        print(f"ultimate_feature_list_check: {exc}", file=sys.stderr)
        return 2
    if args.verify_report:
        verify_errors = verify_report(root, root / args.verify_report, entries, sha)
        if verify_errors:
            _print_errors(verify_errors)
            print(f"ULTIMATE FEATURE LIST FAILED: {len(verify_errors)} verification error(s)", file=sys.stderr)
            return 1
        print(f"ULTIMATE FEATURE LIST VERIFIED: report bound to candidate {sha}", flush=True)
        return 0
    profile_results, profile_errors = load_profile_results(
        root, root / args.profile_results if args.profile_results else None, sha
    )
    if profile_errors:
        _print_errors(profile_errors)
        return 1
    report, run_errors = generate_report(
        root,
        entries,
        sha,
        sha256_bytes(feature_list_path.read_bytes()),
        report_path,
        log_dir,
        args.timeout,
        args.output_limit,
        profile_results,
        execute=not args.bind_only,
    )
    _print_errors(run_errors)
    summary = report["summary"]
    print(
        f"ULTIMATE FEATURE LIST {report['status'].upper()}: "
        f"{summary['passing']} passing, {summary['failed']} failed, {summary['blocked']} blocked, "
        f"{summary['not_started']} not_started; report={report_path.relative_to(root).as_posix()}",
        flush=True,
    )
    return 1 if run_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
