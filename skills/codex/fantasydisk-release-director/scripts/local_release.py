#!/usr/bin/env python3
"""Persist, install, and verify a FantasyDisk release on the operator machine.

The release build may run from an ephemeral worktree.  This helper copies the
complete package to a configured durable checkout, stores an exact tag or
candidate snapshot for Godot, installs the final DMG app on macOS, and updates
a stable ``releases/current-project`` link only after every required check
succeeds.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable, Sequence


TOOLS_DIR = Path(__file__).resolve().parents[4] / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from release_version_contract import RELEASE_VERSION_RE, is_valid_release_version, release_version_key
from release_version_mapping import PlatformVersionMapping, platform_version_mapping


MANIFEST_NAME = "LOCAL_RELEASE.json"
CONFIG_ENV = "FANTASYDISK_LOCAL_RELEASE_CONFIG"
ROOT_ENV = "FANTASYDISK_LOCAL_ROOT"
APP_ENV = "FANTASYDISK_LOCAL_APP"
CHANNEL_ENV = "FANTASYDISK_MACOS_CHANNEL"
MACOS_CHANNELS = ("signed", "unsigned")
MACOS_BUNDLE_VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
GIT_SHA_RE = re.compile(r"^[0-9a-fA-F]{40}$")
REMOTE_CANDIDATE_REF_RE = re.compile(r"^refs/heads/[A-Za-z0-9][A-Za-z0-9._/-]*$")


class LocalReleaseError(RuntimeError):
    """A release cannot be safely materialized or verified."""


@dataclass(frozen=True)
class MacOSBundleVersions:
    short_version: str
    build_version: str


@dataclass(frozen=True)
class CandidateProvenance:
    repository: str
    ref: str
    commit: str
    tree: str


def _version_key(version: str) -> tuple[int, int, int, int]:
    try:
        return release_version_key(version)
    except ValueError as error:
        raise LocalReleaseError(f"invalid release version: {error}: {version}") from error


def resolve_macos_channel(value: str | None = None) -> str:
    """Resolve the explicit macOS trust channel; the default is strict signed.

    The unsigned channel (owner decision, FAN-1121) must be requested explicitly
    via --macos-channel or FANTASYDISK_MACOS_CHANNEL — verification never
    downgrades on its own.
    """
    channel = value or os.environ.get(CHANNEL_ENV, "") or "signed"
    if channel not in MACOS_CHANNELS:
        raise LocalReleaseError(
            f"macOS channel must be one of {'/'.join(MACOS_CHANNELS)}: {channel}"
        )
    return channel


@dataclass(frozen=True)
class LocalConfig:
    local_root: Path
    macos_app: Path
    godot_projects_file: Path


def _run(
    args: Sequence[str | os.PathLike[str]],
    *,
    cwd: Path | None = None,
    timeout: int = 120,
) -> subprocess.CompletedProcess[str]:
    command = [os.fspath(value) for value in args]
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            check=True,
            encoding="utf-8",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        detail = ""
        if isinstance(exc, subprocess.CalledProcessError):
            detail = (exc.stderr or exc.stdout or "").strip().splitlines()[-1:]
            detail = (": " + detail[0]) if detail else ""
        raise LocalReleaseError(f"command failed: {' '.join(command)}{detail}") from exc


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _project_version(project_file: Path) -> str:
    match = re.search(
        r'^config/version="([^"]+)"$',
        project_file.read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    if not match:
        raise LocalReleaseError(f"config/version is missing in {project_file}")
    return match.group(1)


def _candidate_provenance(
    repository: str | None,
    ref: str | None,
    commit: str | None,
    tree: str | None,
) -> CandidateProvenance | None:
    values = (repository, ref, commit, tree)
    if not any(values):
        return None
    if not all(values):
        raise LocalReleaseError(
            "candidate provenance requires repository, ref, commit, and tree"
        )
    assert repository is not None and ref is not None and commit is not None and tree is not None
    if not repository.strip() or repository.lstrip().startswith("-") or "\x00" in repository:
        raise LocalReleaseError("candidate repository is unsafe")
    if (
        not REMOTE_CANDIDATE_REF_RE.fullmatch(ref)
        or ".." in ref
        or "//" in ref
        or ref.endswith("/")
    ):
        raise LocalReleaseError("candidate ref must be a safe refs/heads/* remote ref")
    if not GIT_SHA_RE.fullmatch(commit):
        raise LocalReleaseError("candidate commit must be a full 40-hex SHA")
    if not GIT_SHA_RE.fullmatch(tree):
        raise LocalReleaseError("candidate tree must be a full 40-hex SHA")
    return CandidateProvenance(repository, ref, commit.lower(), tree.lower())


def _manifest_candidate(manifest: dict) -> CandidateProvenance | None:
    value = manifest.get("candidate")
    if value is None:
        return None
    if not isinstance(value, dict):
        raise LocalReleaseError("local manifest candidate provenance is invalid")
    if "tag" in manifest or "tag_commit" in manifest:
        raise LocalReleaseError("candidate manifest must not contain tag provenance")
    candidate = _candidate_provenance(
        value.get("repository"), value.get("ref"), value.get("commit"), value.get("tree")
    )
    if candidate is None:
        raise LocalReleaseError("local manifest candidate provenance is incomplete")
    return candidate


def _validate_candidate_provenance_file(
    source_release: Path, candidate: CandidateProvenance
) -> None:
    path = source_release / "CANDIDATE_PROVENANCE.json"
    if (
        not path.is_file()
        or path.is_symlink()
        or path.resolve().parent != source_release.resolve()
    ):
        raise LocalReleaseError("candidate package has unsafe pre-build provenance")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise LocalReleaseError("candidate package is missing valid pre-build provenance") from exc
    if not isinstance(payload, dict):
        raise LocalReleaseError("candidate package provenance must be an object")
    recorded = _candidate_provenance(
        payload.get("repository"), payload.get("ref"), payload.get("commit"), payload.get("tree")
    )
    if recorded != candidate:
        raise LocalReleaseError("candidate package provenance does not match requested candidate")


def _tree_digest(root: Path) -> str:
    """Hash archived source content while ignoring Godot's generated cache."""
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(root)
        if relative.parts and relative.parts[0] == ".godot":
            continue
        encoded = relative.as_posix().encode("utf-8")
        if path.is_symlink():
            digest.update(b"L\0" + encoded + b"\0" + os.readlink(path).encode("utf-8") + b"\0")
        elif path.is_file():
            digest.update(b"F\0" + encoded + b"\0")
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
            digest.update(b"\0")
    return digest.hexdigest()


def _atomic_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    os.replace(temporary, path)


def _load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise LocalReleaseError(f"invalid local release config: {path}") from exc
    if not isinstance(value, dict):
        raise LocalReleaseError(f"local release config must be an object: {path}")
    return value


def resolve_config(
    *,
    repo_root: Path,
    config_path: Path | None = None,
    local_root: Path | None = None,
    macos_app: Path | None = None,
    godot_projects_file: Path | None = None,
) -> LocalConfig:
    config_file = config_path or Path(
        os.environ.get(CONFIG_ENV, "~/.config/fantasydisk/release.json")
    ).expanduser()
    payload = _load_json(config_file)

    root_value = local_root or (
        Path(os.environ[ROOT_ENV]).expanduser() if os.environ.get(ROOT_ENV) else None
    )
    if root_value is None and payload.get("local_root"):
        root_value = Path(str(payload["local_root"])).expanduser()
    if root_value is None:
        raise LocalReleaseError(
            "durable local root is not configured; set --local-root, "
            f"{ROOT_ENV}, or local_root in {config_file}"
        )
    root_value = root_value.resolve()
    if any(part.startswith("multica_workspaces") for part in root_value.parts):
        raise LocalReleaseError(f"ephemeral Multica worktree cannot be durable: {root_value}")
    if not (root_value / "project.godot").is_file():
        raise LocalReleaseError(f"local root is not a FantasyDisk project: {root_value}")

    app_value = macos_app or (
        Path(os.environ[APP_ENV]).expanduser() if os.environ.get(APP_ENV) else None
    )
    if app_value is None and payload.get("macos_app"):
        app_value = Path(str(payload["macos_app"])).expanduser()
    if app_value is None:
        app_value = Path.home() / "Applications" / "FantasyDisk.app"

    projects_value = godot_projects_file
    if projects_value is None and payload.get("godot_projects_file"):
        projects_value = Path(str(payload["godot_projects_file"])).expanduser()
    if projects_value is None:
        system = platform.system()
        if system == "Darwin":
            projects_value = (
                Path.home() / "Library" / "Application Support" / "Godot" / "projects.cfg"
            )
        elif system == "Windows":
            projects_value = Path(
                os.environ.get("APPDATA", Path.home() / "AppData" / "Roaming")
            ) / "Godot" / "projects.cfg"
        else:
            projects_value = Path.home() / ".config" / "godot" / "projects.cfg"

    return LocalConfig(root_value, app_value.resolve(), projects_value.resolve())


def _release_files(release_dir: Path) -> dict[str, Path]:
    files: dict[str, Path] = {}
    for path in sorted(release_dir.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(release_dir)
        if relative.parts[0] in {"project", "godot-project", ".godot"} or relative.name == MANIFEST_NAME:
            continue
        if len(relative.parts) == 1 and (
            relative.name == ".DS_Store" or relative.name.endswith(".import")
        ):
            continue
        files[relative.as_posix()] = path
    return files


def _validate_package(release_dir: Path, version: str) -> dict[str, Path]:
    poster_suffix = "announcement_telegram_discord" if version == "0.2.2" else "announcement"
    poster = f"fantasydisk_{version.replace('.', '')}_{poster_suffix}.png"
    required = {
        f"FantasyDisk-{version}-macos.dmg",
        f"FantasyDisk-{version}-windows-setup.exe",
        f"CHANGELOG-{version}.md",
        "SHA256SUMS.txt",
        "update-manifest.json",
        poster,
    }
    files = _release_files(release_dir)
    missing = sorted(required - set(files))
    if missing:
        raise LocalReleaseError(f"release package is incomplete: {', '.join(missing)}")

    checksums = files["SHA256SUMS.txt"].read_text(encoding="utf-8").splitlines()
    expected_installers = {
        f"FantasyDisk-{version}-macos.dmg",
        f"FantasyDisk-{version}-windows-setup.exe",
    }
    checked: dict[str, str] = {}
    for line in checksums:
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split(maxsplit=1)
        if len(parts) != 2 or not re.fullmatch(r"[0-9a-fA-F]{64}", parts[0]):
            raise LocalReleaseError("malformed SHA256SUMS entry")
        expected, name = parts
        name = name.lstrip("*./")
        if name in checked:
            raise LocalReleaseError(f"duplicate SHA256SUMS entry: {name}")
        if name not in expected_installers:
            raise LocalReleaseError(f"unexpected SHA256SUMS entry: {name}")
        candidate = release_dir / name
        if not candidate.is_file() or candidate.resolve().parent != release_dir.resolve():
            raise LocalReleaseError(f"unsafe or missing SHA256SUMS entry: {name}")
        if _sha256(candidate) != expected.lower():
            raise LocalReleaseError(f"SHA256 mismatch: {name}")
        checked[name] = expected.lower()
    if set(checked) != expected_installers:
        raise LocalReleaseError("SHA256SUMS.txt must verify both platform installers")
    _validate_update_manifest(files["update-manifest.json"], release_dir, version, checked)
    return files


def _validate_update_manifest(
    manifest_path: Path,
    release_dir: Path,
    version: str,
    installer_hashes: dict[str, str],
) -> None:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise LocalReleaseError("invalid update-manifest.json") from exc
    expected_release_url = f"https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v{version}"
    if (
        not isinstance(manifest, dict)
        or manifest.get("schema_version") != 1
        or manifest.get("version") != version
        or not RELEASE_VERSION_RE.fullmatch(str(manifest.get("minimum_supported_version", "")))
        or manifest.get("release_url") != expected_release_url
    ):
        raise LocalReleaseError("update manifest metadata does not match the release")
    minimum_supported = str(manifest["minimum_supported_version"])
    if _version_key(minimum_supported) > _version_key(version):
        raise LocalReleaseError("update manifest minimum version is newer than the release")
    assets = manifest.get("assets")
    if not isinstance(assets, dict) or set(assets) != {"macos", "windows"}:
        raise LocalReleaseError("update manifest must contain macOS and Windows assets")
    expected_names = {
        "macos": f"FantasyDisk-{version}-macos.dmg",
        "windows": f"FantasyDisk-{version}-windows-setup.exe",
    }
    for platform_name, name in expected_names.items():
        asset = assets.get(platform_name)
        expected_url = (
            f"https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v{version}/{name}"
        )
        installer = release_dir / name
        if (
            not isinstance(asset, dict)
            or asset.get("name") != name
            or asset.get("url") != expected_url
            or asset.get("sha256") != installer_hashes[name]
            or asset.get("size") != installer.stat().st_size
        ):
            raise LocalReleaseError(f"update manifest asset does not match {name}")


def _extract_commit(
    repo_root: Path, commit: str, destination: Path, source: str
) -> tuple[str, str]:
    resolved_commit = _run(
        ["git", "rev-parse", f"{commit}^{{commit}}"], cwd=repo_root
    ).stdout.strip().lower()
    if resolved_commit != commit.lower():
        raise LocalReleaseError(f"{source} does not resolve to the pinned commit")
    tree = _run(
        ["git", "rev-parse", f"{resolved_commit}^{{tree}}"], cwd=repo_root
    ).stdout.strip().lower()
    destination.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="fantasydisk-git-archive-") as temporary:
        archive = Path(temporary) / "source.tar"
        try:
            with archive.open("wb") as handle:
                subprocess.run(
                    ["git", "archive", "--format=tar", resolved_commit],
                    cwd=repo_root,
                    check=True,
                    stdout=handle,
                    stderr=subprocess.PIPE,
                    timeout=120,
                )
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
            raise LocalReleaseError(f"cannot archive {source}") from exc
        with tarfile.open(archive, "r:") as bundle:
            members = bundle.getmembers()
            for member in members:
                pure = PurePosixPath(member.name)
                if pure.is_absolute() or ".." in pure.parts:
                    raise LocalReleaseError(f"unsafe path in git archive: {member.name}")
            bundle.extractall(destination, members=members)
    return resolved_commit, tree


def _extract_tag(repo_root: Path, tag: str, destination: Path) -> str:
    commit = _run(["git", "rev-parse", f"{tag}^{{commit}}"], cwd=repo_root).stdout.strip()
    archived_commit, _tree = _extract_commit(repo_root, commit, destination, f"exact tag {tag}")
    return archived_commit


def _copy_package(source_files: dict[str, Path], destination: Path) -> None:
    for relative, source in source_files.items():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        if _sha256(source) != _sha256(target):
            raise LocalReleaseError(f"local copy verification failed: {relative}")


def _compare_package(source_files: dict[str, Path], destination: Path) -> None:
    destination_files = _release_files(destination)
    if set(destination_files) != set(source_files):
        missing = sorted(set(source_files) - set(destination_files))
        extra = sorted(set(destination_files) - set(source_files))
        raise LocalReleaseError(
            f"existing local release differs (missing={missing}, extra={extra})"
        )
    for relative, source in source_files.items():
        if _sha256(source) != _sha256(destination_files[relative]):
            raise LocalReleaseError(f"existing local release differs: {relative}")


def _clone_godot_project(source: Path, destination: Path) -> None:
    """Create an editable copy while keeping the exact archived source untouched."""
    stage = destination.with_name(f".{destination.name}.stage.{os.getpid()}")
    if stage.exists():
        raise LocalReleaseError(f"stale Godot project stage exists: {stage}")
    try:
        if platform.system() == "Darwin":
            _run(["cp", "-cR", source, stage], timeout=300)
        else:
            shutil.copytree(source, stage, symlinks=True)
        os.replace(stage, destination)
    except Exception:
        shutil.rmtree(stage, ignore_errors=True)
        raise


def _manifest(
    *,
    version: str,
    tag: str | None,
    commit: str,
    candidate: CandidateProvenance | None,
    source_tree_sha256: str,
    release_dir: Path,
    package_files: Iterable[str],
    app_target: Path,
    app_required: bool,
    macos_channel: str,
) -> dict:
    package_inventory = {
        relative: {
            "sha256": _sha256(release_dir / relative),
            "size": (release_dir / relative).stat().st_size,
        }
        for relative in sorted(package_files)
    }
    manifest = {
        "schema": 1,
        "version": version,
        "project_path": "project/project.godot",
        "godot_project_path": "godot-project/project.godot",
        "source_tree_sha256": source_tree_sha256,
        "package_sha256": {relative: item["sha256"] for relative, item in package_inventory.items()},
        "package_inventory": package_inventory,
        "macos_app": os.fspath(app_target),
        "macos_app_required": app_required,
        "macos_channel": macos_channel,
    }
    if candidate is None:
        assert tag is not None
        manifest.update({"tag": tag, "tag_commit": commit})
    else:
        manifest["candidate"] = {
            "repository": candidate.repository,
            "ref": candidate.ref,
            "commit": candidate.commit,
            "tree": candidate.tree,
        }
    return manifest


def materialize_package(
    *,
    version: str,
    repo_root: Path,
    source_release: Path,
    config: LocalConfig,
    dry_run: bool = False,
    macos_channel: str = "signed",
    candidate: CandidateProvenance | None = None,
) -> tuple[Path, dict]:
    _version_key(version)
    if macos_channel not in MACOS_CHANNELS:
        raise LocalReleaseError(f"invalid macOS channel: {macos_channel}")
    if candidate is not None:
        candidate = _candidate_provenance(
            candidate.repository, candidate.ref, candidate.commit, candidate.tree
        )
        assert candidate is not None
    tag = f"v{version}"
    source_release = source_release.resolve()
    source_files = _validate_package(source_release, version)
    if candidate is not None:
        _validate_candidate_provenance_file(source_release, candidate)
    releases_root = config.local_root / "releases"
    destination = releases_root / tag
    existing_manifest = _load_json(destination / MANIFEST_NAME) if destination.exists() else {}
    recorded_channel = existing_manifest.get("macos_channel")
    if recorded_channel is not None and recorded_channel != macos_channel:
        raise LocalReleaseError(
            f"existing local release {tag} is recorded as '{recorded_channel}'; "
            f"refusing to relabel it as '{macos_channel}'"
        )
    existing_candidate = _manifest_candidate(existing_manifest) if existing_manifest else None
    if existing_manifest and existing_candidate != candidate:
        raise LocalReleaseError(f"existing local release {tag} has different source provenance")

    with tempfile.TemporaryDirectory(prefix=f"fantasydisk-{tag}-") as temporary:
        expected_project = Path(temporary) / "project"
        if candidate is None:
            commit = _extract_tag(repo_root.resolve(), tag, expected_project)
            expected_git_tree = _run(
                ["git", "rev-parse", f"{commit}^{{tree}}"], cwd=repo_root
            ).stdout.strip().lower()
            source_name = f"git tag {tag}"
        else:
            commit, expected_git_tree = _extract_commit(
                repo_root.resolve(), candidate.commit, expected_project, "pinned candidate"
            )
            if expected_git_tree != candidate.tree:
                raise LocalReleaseError("candidate tree does not match the pinned commit")
            source_name = "pinned candidate"
        if _project_version(expected_project / "project.godot") != version:
            raise LocalReleaseError(f"{source_name} project.godot does not contain version {version}")
        expected_tree = _tree_digest(expected_project)

        if dry_run:
            if destination.exists():
                _compare_package(source_files, destination)
                project = destination / "project"
                if not project.is_dir() or _tree_digest(project) != expected_tree:
                    raise LocalReleaseError(f"existing {tag} source snapshot differs from {source_name}")
            return destination, {
                "version": version,
                "tag": tag if candidate is None else None,
                "tag_commit": commit if candidate is None else None,
                "candidate": (
                    None
                    if candidate is None
                    else {
                        "repository": candidate.repository,
                        "ref": candidate.ref,
                        "commit": candidate.commit,
                        "tree": candidate.tree,
                    }
                ),
                "git_tree": expected_git_tree,
                "source_tree_sha256": expected_tree,
                "package_files": sorted(source_files),
                "macos_channel": macos_channel,
            }

        releases_root.mkdir(parents=True, exist_ok=True)
        (releases_root / ".gdignore").touch(exist_ok=True)
        if destination.exists():
            _compare_package(source_files, destination)
            project = destination / "project"
            if project.exists():
                if _tree_digest(project) != expected_tree:
                    raise LocalReleaseError(f"existing {tag} source snapshot differs from {source_name}")
            else:
                shutil.copytree(expected_project, project, symlinks=True)
        else:
            stage = releases_root / f".{tag}.stage.{os.getpid()}"
            if stage.exists():
                raise LocalReleaseError(f"stale local release stage exists: {stage}")
            stage.mkdir()
            try:
                _copy_package(source_files, stage)
                shutil.copytree(expected_project, stage / "project", symlinks=True)
                os.replace(stage, destination)
            except Exception:
                shutil.rmtree(stage, ignore_errors=True)
                raise

    godot_project = destination / "godot-project"
    if godot_project.exists():
        if _project_version(godot_project / "project.godot") != version:
            raise LocalReleaseError(f"editable Godot project does not match {version}")
    else:
        _clone_godot_project(destination / "project", godot_project)

    manifest = _manifest(
        version=version,
        tag=tag if candidate is None else None,
        commit=commit,
        candidate=candidate,
        source_tree_sha256=expected_tree,
        release_dir=destination,
        package_files=source_files,
        app_target=config.macos_app,
        app_required=platform.system() == "Darwin",
        macos_channel=macos_channel,
    )
    _atomic_json(destination / MANIFEST_NAME, manifest)
    return destination, manifest


def _macos_bundle_versions_from_project(project_root: Path) -> MacOSBundleVersions:
    presets = project_root / "export_presets.cfg"
    if not presets.is_file():
        raise LocalReleaseError(f"macOS export presets are missing: {presets}")
    source = presets.read_text(encoding="utf-8")
    values = {
        key: re.search(rf'(?m)^{re.escape(key)}="([^"]*)"$', source)
        for key in ("application/short_version", "application/version")
    }
    short_match = values["application/short_version"]
    build_match = values["application/version"]
    if short_match is None or build_match is None:
        raise LocalReleaseError("macOS export presets are missing bundle version fields")
    versions = MacOSBundleVersions(short_match.group(1), build_match.group(1))
    if not MACOS_BUNDLE_VERSION_RE.fullmatch(versions.short_version) \
            or not MACOS_BUNDLE_VERSION_RE.fullmatch(versions.build_version):
        raise LocalReleaseError("macOS export versions must each have three numeric components")
    return versions


def _macos_bundle_versions_from_logical(version: str) -> MacOSBundleVersions:
    try:
        mapping: PlatformVersionMapping = platform_version_mapping(version)
    except ValueError as error:
        raise LocalReleaseError(str(error)) from error
    return MacOSBundleVersions(mapping.macos_short_version, mapping.macos_build_version)


def _bundle_versions(app: Path) -> MacOSBundleVersions:
    plist = app / "Contents" / "Info.plist"
    if not plist.is_file():
        raise LocalReleaseError(f"installed app has no Info.plist: {app}")
    with plist.open("rb") as handle:
        payload = plistlib.load(handle)
    short_version = payload.get("CFBundleShortVersionString")
    build_version = payload.get("CFBundleVersion")
    if not short_version or not build_version:
        raise LocalReleaseError(f"installed app has incomplete bundle versions: {app}")
    return MacOSBundleVersions(str(short_version), str(build_version))


def _bundle_executable(app: Path) -> Path:
    plist = app / "Contents" / "Info.plist"
    if not plist.is_file():
        raise LocalReleaseError(f"installed app has no Info.plist: {app}")
    with plist.open("rb") as handle:
        payload = plistlib.load(handle)
    executable_name = payload.get("CFBundleExecutable")
    if (
        not isinstance(executable_name, str)
        or not executable_name
        or Path(executable_name).name != executable_name
        or executable_name in {".", ".."}
    ):
        raise LocalReleaseError(f"installed app has an invalid CFBundleExecutable: {app}")
    executable = app / "Contents" / "MacOS" / executable_name
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise LocalReleaseError(
            f"CFBundleExecutable does not name an executable file: {executable}"
        )
    return executable


def verify_macos_app(
    app: Path,
    version: str,
    *,
    launch_smoke: bool,
    signed: bool = True,
    expected_versions: MacOSBundleVersions | None = None,
) -> None:
    if not app.is_dir():
        raise LocalReleaseError(f"macOS app is not installed: {app}")
    expected = expected_versions or _macos_bundle_versions_from_logical(version)
    actual = _bundle_versions(app)
    if actual != expected:
        raise LocalReleaseError(
            "installed app bundle versions are "
            f"short={actual.short_version}, build={actual.build_version}; expected "
            f"short={expected.short_version}, build={expected.build_version}"
        )
    executable = _bundle_executable(app)
    # Both Apple Silicon and Intel slices are contractual for the universal
    # macOS preset.  Verify the bundle's declared executable, not an arbitrary
    # executable file that happens to be in Contents/MacOS.
    _run(["lipo", executable, "-verify_arch", "x86_64", "arm64"])
    # This is an integrity check, not a publisher-trust check: it must pass for
    # both Developer ID and explicitly unsigned (ad-hoc sealed) artifacts.
    _run(["codesign", "--verify", "--deep", "--strict", "--verbose=4", app])
    if signed:
        _run(["xcrun", "stapler", "validate", app])
        _run(["spctl", "--assess", "--type", "execute", "--verbose=4", app])
    if launch_smoke:
        # Route the smoke through LaunchServices so the test covers Finder's
        # bundle validation rather than merely executing the Mach-O directly.
        _run(
            ["open", "-n", "-W", app, "--args", "--headless", "--quit-after", "2"],
            timeout=30,
        )


def _mount_dmg(dmg: Path, mountpoint: Path) -> tuple[Path, str]:
    mountpoint.mkdir(parents=True, exist_ok=False)
    result = _run(
        [
            "hdiutil",
            "attach",
            "-readonly",
            "-noverify",
            "-noautoopen",
            "-nobrowse",
            "-plist",
            "-mountpoint",
            mountpoint,
            dmg,
        ]
    )
    try:
        payload = plistlib.loads(result.stdout.encode("utf-8"))
    except Exception as exc:
        raise LocalReleaseError(f"cannot parse hdiutil output for {dmg}") from exc
    for entity in payload.get("system-entities", []):
        mounted = entity.get("mount-point")
        device = entity.get("dev-entry")
        if mounted and device:
            return Path(mounted), str(device)
    raise LocalReleaseError(f"DMG did not mount: {dmg}")


def verify_macos_dmg(
    dmg: Path,
    version: str,
    *,
    signed: bool = True,
    expected_versions: MacOSBundleVersions | None = None,
) -> None:
    _run(["hdiutil", "verify", dmg], timeout=300)
    if signed:
        _run(["codesign", "--verify", "--strict", "--verbose=4", dmg])
        _run(["xcrun", "stapler", "validate", dmg])
        _run(
            [
                "spctl",
                "--assess",
                "--type",
                "open",
                "--context",
                "context:primary-signature",
                "--verbose=4",
                dmg,
            ]
        )
    with tempfile.TemporaryDirectory(prefix="fantasydisk-dmg-verify-") as temporary:
        device = ""
        try:
            mountpoint, device = _mount_dmg(dmg, Path(temporary) / "mount")
            applications = mountpoint / "Applications"
            if not applications.is_symlink() or os.readlink(applications) != "/Applications":
                raise LocalReleaseError(f"DMG Applications link is invalid: {dmg}")
            apps = list(mountpoint.glob("*.app"))
            if len(apps) != 1:
                raise LocalReleaseError(f"DMG must contain exactly one app: {dmg}")
            verify_macos_app(
                apps[0],
                version,
                launch_smoke=False,
                signed=signed,
                expected_versions=expected_versions,
            )
        finally:
            if device:
                try:
                    _run(["hdiutil", "detach", device, "-force"])
                except LocalReleaseError:
                    pass


def install_macos_from_dmg(
    *,
    dmg: Path,
    target: Path,
    version: str,
    launch_smoke: bool = True,
    signed: bool = True,
    expected_versions: MacOSBundleVersions | None = None,
) -> None:
    verify_macos_dmg(dmg, version, signed=signed, expected_versions=expected_versions)
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="fantasydisk-dmg-") as temporary:
        device = ""
        try:
            mountpoint, device = _mount_dmg(dmg, Path(temporary) / "mount")
            apps = list(mountpoint.glob("*.app"))
            if len(apps) != 1:
                raise LocalReleaseError(f"DMG must contain exactly one app: {dmg}")
            verify_macos_app(
                apps[0],
                version,
                launch_smoke=False,
                signed=signed,
                expected_versions=expected_versions,
            )

            stage = target.parent / f".{target.name}.stage.{os.getpid()}"
            backup = target.parent / f".{target.name}.backup.{os.getpid()}"
            if stage.exists() or backup.exists():
                raise LocalReleaseError(f"stale app install stage exists beside {target}")
            _run(["ditto", "--rsrc", "--extattr", apps[0], stage])
            verify_macos_app(
                stage,
                version,
                launch_smoke=False,
                signed=signed,
                expected_versions=expected_versions,
            )
            moved_old = False
            try:
                if target.exists():
                    os.replace(target, backup)
                    moved_old = True
                os.replace(stage, target)
                verify_macos_app(
                    target,
                    version,
                    launch_smoke=launch_smoke,
                    signed=signed,
                    expected_versions=expected_versions,
                )
            except Exception:
                if target.exists():
                    shutil.rmtree(target, ignore_errors=True)
                if moved_old and backup.exists():
                    os.replace(backup, target)
                raise
            if backup.exists():
                shutil.rmtree(backup)
        finally:
            if device:
                try:
                    _run(["hdiutil", "detach", device, "-force"])
                except LocalReleaseError:
                    pass


def _is_project_pointer(path: Path) -> bool:
    try:
        metadata = os.lstat(path)
    except OSError:
        return False
    if platform.system() == "Windows":
        return bool(
            getattr(metadata, "st_file_attributes", 0)
            & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
        )
    return path.is_symlink()


def _project_pointer_target(
    releases_root: Path, pointer: Path, version: str | None = None
) -> Path:
    if not _is_project_pointer(pointer):
        raise LocalReleaseError(f"current-project is not a supported pointer: {pointer}")
    try:
        root = releases_root.resolve(strict=True)
        target = pointer.resolve(strict=True)
        relative = target.relative_to(root)
    except (OSError, ValueError) as exc:
        raise LocalReleaseError(
            f"current-project has an unsafe, stale, or malformed target: {pointer}"
        ) from exc
    expected = Path(f"v{version}") / "godot-project" if version is not None else None
    if (
        len(relative.parts) != 2
        or relative.name != "godot-project"
        or not relative.parts[0].startswith("v")
        or not is_valid_release_version(relative.parts[0][1:])
        or (expected is not None and relative != expected)
    ):
        raise LocalReleaseError(f"current-project has an unexpected target: {target}")
    return target


def _create_project_pointer(pointer: Path, target: Path, relative_target: str) -> None:
    if platform.system() != "Windows":
        pointer.symlink_to(relative_target, target_is_directory=True)
        return
    environment = os.environ.copy()
    environment["FANTASYDISK_JUNCTION_LINK"] = os.fspath(pointer)
    environment["FANTASYDISK_JUNCTION_TARGET"] = os.fspath(target)
    try:
        subprocess.run(
            [
                "powershell.exe",
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                "$ErrorActionPreference='Stop'; "
                "New-Item -ItemType Junction -Path $env:FANTASYDISK_JUNCTION_LINK "
                "-Target $env:FANTASYDISK_JUNCTION_TARGET | Out-Null",
            ],
            check=True,
            env=environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=30,
        )
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        raise LocalReleaseError(f"cannot create current-project junction: {pointer}") from exc


def _remove_project_pointer(pointer: Path) -> None:
    if not os.path.lexists(pointer):
        return
    if not _is_project_pointer(pointer):
        raise LocalReleaseError(f"refusing to remove non-pointer path: {pointer}")
    if platform.system() == "Windows":
        pointer.rmdir()
    else:
        pointer.unlink()


def _update_current_project(releases_root: Path, version: str) -> Path:
    current = releases_root / "current-project"
    if os.path.lexists(current):
        _project_pointer_target(releases_root, current)
    relative_target = f"v{version}/godot-project"
    target = releases_root / relative_target
    try:
        resolved_target = target.resolve(strict=True)
        if resolved_target.relative_to(releases_root.resolve(strict=True)) != Path(relative_target):
            raise ValueError
    except (OSError, ValueError) as exc:
        raise LocalReleaseError(f"current-project target is unsafe or missing: {target}") from exc

    temporary = releases_root / f".current-project.tmp.{os.getpid()}"
    backup = releases_root / f".current-project.old.{os.getpid()}"
    if os.path.lexists(temporary) or os.path.lexists(backup):
        raise LocalReleaseError("stale current-project update path exists")

    moved_old = False
    try:
        _create_project_pointer(temporary, resolved_target, relative_target)
        _project_pointer_target(releases_root, temporary, version)
        if platform.system() == "Windows" and os.path.lexists(current):
            os.replace(current, backup)
            moved_old = True
        os.replace(temporary, current)
        _project_pointer_target(releases_root, current, version)
    except Exception:
        if moved_old:
            if os.path.lexists(current):
                _remove_project_pointer(current)
            if not os.path.lexists(current) and os.path.lexists(backup):
                os.replace(backup, current)
        raise
    finally:
        if os.path.lexists(temporary):
            _remove_project_pointer(temporary)
    if moved_old:
        _remove_project_pointer(backup)
    return current


def _register_godot(projects_file: Path, current_project: Path) -> None:
    section = f"[{current_project}]"
    existing = projects_file.read_text(encoding="utf-8") if projects_file.exists() else ""
    projects_file.parent.mkdir(parents=True, exist_ok=True)
    if section not in existing:
        addition = f"{section}\n\nfavorite=true\n"
        content = existing.rstrip() + ("\n\n" if existing.strip() else "") + addition
    else:
        start = existing.index(section)
        next_section = existing.find("\n[", start + len(section))
        end = len(existing) if next_section < 0 else next_section + 1
        block = existing[start:end]
        if re.search(r"(?m)^favorite=", block):
            updated = re.sub(r"(?m)^favorite=.*$", "favorite=true", block)
        else:
            updated = block.rstrip() + "\n\nfavorite=true\n"
        content = existing[:start] + updated + existing[end:]
        if content == existing:
            return
    temporary = projects_file.with_name(f".{projects_file.name}.tmp.{os.getpid()}")
    temporary.write_text(content, encoding="utf-8")
    os.replace(temporary, projects_file)


def verify_local_release(
    *,
    version: str,
    repo_root: Path,
    config: LocalConfig,
    require_app: bool,
    launch_smoke: bool = False,
    macos_channel: str = "signed",
    require_tag_match: bool = True,
) -> dict:
    _version_key(version)
    tag = f"v{version}"
    release_dir = config.local_root / "releases" / tag
    package_files = _validate_package(release_dir, version)
    manifest_path = release_dir / MANIFEST_NAME
    manifest = _load_json(manifest_path)
    if manifest.get("version") != version:
        raise LocalReleaseError(f"local manifest does not match {tag}")
    candidate = _manifest_candidate(manifest)
    if macos_channel not in MACOS_CHANNELS:
        raise LocalReleaseError(f"invalid macOS channel: {macos_channel}")
    # Releases materialized before the channel existed are strict signed ones.
    recorded_channel = str(manifest.get("macos_channel", "signed"))
    if recorded_channel not in MACOS_CHANNELS:
        raise LocalReleaseError(f"local manifest has an unknown macOS channel: {recorded_channel}")
    if recorded_channel != macos_channel:
        raise LocalReleaseError(
            f"local release {tag} is recorded as '{recorded_channel}' but verification "
            f"was requested for '{macos_channel}'; pass the matching --macos-channel "
            f"(or {CHANNEL_ENV}) explicitly"
        )
    with tempfile.TemporaryDirectory(prefix=f"fantasydisk-verify-{tag}-") as temporary:
        expected_project = Path(temporary) / "project"
        if candidate is None:
            commit = _run(["git", "rev-parse", f"{tag}^{{commit}}"], cwd=repo_root).stdout.strip()
            if manifest.get("tag_commit") != commit:
                raise LocalReleaseError(f"local manifest does not match {tag}")
            archived_commit = _extract_tag(repo_root, tag, expected_project)
        else:
            archived_commit, archived_git_tree = _extract_commit(
                repo_root, candidate.commit, expected_project, "pinned candidate"
            )
            if archived_git_tree != candidate.tree:
                raise LocalReleaseError("candidate tree does not match the pinned commit")
            if require_tag_match:
                tag_commit = _run(
                    ["git", "rev-parse", f"{tag}^{{commit}}"], cwd=repo_root
                ).stdout.strip().lower()
                tag_tree = _run(
                    ["git", "rev-parse", f"{tag_commit}^{{tree}}"], cwd=repo_root
                ).stdout.strip().lower()
                if tag_commit != candidate.commit or tag_tree != candidate.tree:
                    raise LocalReleaseError(f"candidate provenance does not match {tag}")
        expected_tree = _tree_digest(expected_project)
    if manifest.get("source_tree_sha256") != expected_tree:
        raise LocalReleaseError(f"local manifest source digest does not match {tag}")
    project = release_dir / "project"
    if _project_version(project / "project.godot") != version:
        raise LocalReleaseError(f"local Godot snapshot does not match {version}")
    if _tree_digest(project) != expected_tree:
        raise LocalReleaseError(f"local Godot snapshot differs from {tag}")
    godot_project = release_dir / "godot-project"
    if _project_version(godot_project / "project.godot") != version:
        raise LocalReleaseError(f"editable Godot project does not match {version}")
    expected_hashes = manifest.get("package_sha256")
    if not isinstance(expected_hashes, dict) or set(expected_hashes) != set(package_files):
        raise LocalReleaseError("local package manifest is incomplete")
    for relative, expected in expected_hashes.items():
        if _sha256(release_dir / relative) != expected:
            raise LocalReleaseError(f"local package changed: {relative}")
    inventory = manifest.get("package_inventory")
    if inventory is None and candidate is not None:
        raise LocalReleaseError("candidate local package inventory is incomplete")
    if inventory is not None:
        if not isinstance(inventory, dict) or set(inventory) != set(package_files):
            raise LocalReleaseError("local package inventory is incomplete")
        for relative, item in inventory.items():
            path = release_dir / relative
            if (
                not isinstance(item, dict)
                or item.get("sha256") != _sha256(path)
                or item.get("size") != path.stat().st_size
            ):
                raise LocalReleaseError(f"local package inventory changed: {relative}")

    current = config.local_root / "releases" / "current-project"
    if not (config.local_root / "releases" / ".gdignore").is_file():
        raise LocalReleaseError("durable releases root is missing .gdignore")
    try:
        _project_pointer_target(config.local_root / "releases", current, version)
    except LocalReleaseError as exc:
        raise LocalReleaseError(f"current-project does not point to {tag}: {exc}") from exc
    projects_content = (
        config.godot_projects_file.read_text(encoding="utf-8")
        if config.godot_projects_file.exists()
        else ""
    )
    section = f"[{current}]"
    if section not in projects_content:
        raise LocalReleaseError("current-project is not registered in Godot")
    start = projects_content.index(section)
    next_section = projects_content.find("\n[", start + len(section))
    end = len(projects_content) if next_section < 0 else next_section + 1
    if not re.search(r"(?m)^favorite=true$", projects_content[start:end]):
        raise LocalReleaseError("current-project is not a Godot favorite")
    if require_app:
        signed = recorded_channel == "signed"
        expected_versions = _macos_bundle_versions_from_project(project)
        verify_macos_dmg(
            release_dir / f"FantasyDisk-{version}-macos.dmg",
            version,
            signed=signed,
            expected_versions=expected_versions,
        )
        verify_macos_app(
            config.macos_app,
            version,
            launch_smoke=launch_smoke,
            signed=signed,
            expected_versions=expected_versions,
        )
    return manifest


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("materialize", "verify"))
    parser.add_argument("--version", required=True)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--release-dir", type=Path)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--local-root", type=Path)
    parser.add_argument("--macos-app", type=Path)
    parser.add_argument("--godot-projects-file", type=Path)
    parser.add_argument("--candidate-repository")
    parser.add_argument("--candidate-ref")
    parser.add_argument("--candidate-sha")
    parser.add_argument("--candidate-tree")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--launch-smoke", action="store_true")
    parser.add_argument(
        "--macos-channel",
        choices=MACOS_CHANNELS,
        help=(
            "explicit macOS trust channel; default is strict 'signed', "
            f"falls back to ${CHANNEL_ENV} when omitted"
        ),
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    repo_root = args.repo_root.resolve()
    try:
        candidate = _candidate_provenance(
            args.candidate_repository,
            args.candidate_ref,
            args.candidate_sha,
            args.candidate_tree,
        )
        if args.action == "verify" and candidate is not None:
            raise LocalReleaseError("verify reads candidate provenance from LOCAL_RELEASE.json")
        config = resolve_config(
            repo_root=repo_root,
            config_path=args.config,
            local_root=args.local_root,
            macos_app=args.macos_app,
            godot_projects_file=args.godot_projects_file,
        )
        require_app = platform.system() == "Darwin"
        macos_channel = resolve_macos_channel(args.macos_channel)
        if args.action == "materialize":
            source_release = args.release_dir or repo_root / "releases" / f"v{args.version}"
            destination, summary = materialize_package(
                version=args.version,
                repo_root=repo_root,
                source_release=source_release,
                config=config,
                dry_run=args.dry_run,
                macos_channel=macos_channel,
                candidate=candidate,
            )
            if args.dry_run:
                print(json.dumps({"destination": os.fspath(destination), **summary}, indent=2))
                return 0
            if require_app:
                expected_versions = _macos_bundle_versions_from_project(destination / "project")
                install_macos_from_dmg(
                    dmg=destination / f"FantasyDisk-{args.version}-macos.dmg",
                    target=config.macos_app,
                    version=args.version,
                    launch_smoke=True,
                    signed=macos_channel == "signed",
                    expected_versions=expected_versions,
                )
            current = _update_current_project(destination.parent, args.version)
            _register_godot(config.godot_projects_file, current)
        manifest = verify_local_release(
            version=args.version,
            repo_root=repo_root,
            config=config,
            require_app=require_app,
            launch_smoke=args.launch_smoke,
            macos_channel=macos_channel,
            require_tag_match=args.action == "verify",
        )
    except LocalReleaseError as exc:
        print(f"local release ERROR: {exc}", file=sys.stderr)
        return 2
    print(
        json.dumps(
            {
                "status": "verified",
                "version": args.version,
                "local_release": os.fspath(config.local_root / "releases" / f"v{args.version}"),
                "current_project": os.fspath(config.local_root / "releases" / "current-project"),
                "macos_app": os.fspath(config.macos_app) if require_app else "platform-exception",
                "tag_commit": manifest.get("tag_commit"),
                "candidate": manifest.get("candidate"),
                "macos_channel": str(manifest.get("macos_channel", "signed")),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
