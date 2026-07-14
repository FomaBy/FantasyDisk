#!/usr/bin/env python3
"""Persist, install, and verify a FantasyDisk release on the operator machine.

The release build may run from an ephemeral worktree.  This helper copies the
complete package to a configured durable checkout, stores an exact git-tag
snapshot for Godot, installs the final DMG app on macOS, and updates a stable
``releases/current-project`` link only after every required check succeeds.
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
import subprocess
import sys
import tarfile
import tempfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable, Sequence


SEMVER_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
MANIFEST_NAME = "LOCAL_RELEASE.json"
CONFIG_ENV = "FANTASYDISK_LOCAL_RELEASE_CONFIG"
ROOT_ENV = "FANTASYDISK_LOCAL_ROOT"
APP_ENV = "FANTASYDISK_LOCAL_APP"


class LocalReleaseError(RuntimeError):
    """A release cannot be safely materialized or verified."""


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
            text=True,
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
    poster = f"fantasydisk_{version.replace('.', '')}_announcement_telegram_discord.png"
    required = {
        f"FantasyDisk-{version}-macos.dmg",
        f"FantasyDisk-{version}-windows-setup.exe",
        f"CHANGELOG-{version}.md",
        "SHA256SUMS.txt",
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
    return files


def _extract_tag(repo_root: Path, tag: str, destination: Path) -> str:
    commit = _run(["git", "rev-parse", f"{tag}^{{commit}}"], cwd=repo_root).stdout.strip()
    destination.mkdir(parents=True, exist_ok=False)
    with tempfile.NamedTemporaryFile(suffix=".tar") as handle:
        try:
            subprocess.run(
                ["git", "archive", "--format=tar", tag],
                cwd=repo_root,
                check=True,
                stdout=handle,
                stderr=subprocess.PIPE,
                timeout=120,
            )
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
            raise LocalReleaseError(f"cannot archive exact tag {tag}") from exc
        handle.flush()
        with tarfile.open(handle.name, "r:") as bundle:
            members = bundle.getmembers()
            for member in members:
                pure = PurePosixPath(member.name)
                if pure.is_absolute() or ".." in pure.parts:
                    raise LocalReleaseError(f"unsafe path in git archive: {member.name}")
            bundle.extractall(destination, members=members)
    return commit


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
    tag: str,
    commit: str,
    source_tree_sha256: str,
    release_dir: Path,
    package_files: Iterable[str],
    app_target: Path,
    app_required: bool,
) -> dict:
    return {
        "schema": 1,
        "version": version,
        "tag": tag,
        "tag_commit": commit,
        "project_path": "project/project.godot",
        "godot_project_path": "godot-project/project.godot",
        "source_tree_sha256": source_tree_sha256,
        "package_sha256": {
            relative: _sha256(release_dir / relative) for relative in sorted(package_files)
        },
        "macos_app": os.fspath(app_target),
        "macos_app_required": app_required,
    }


def materialize_package(
    *,
    version: str,
    repo_root: Path,
    source_release: Path,
    config: LocalConfig,
    dry_run: bool = False,
) -> tuple[Path, dict]:
    if not SEMVER_RE.fullmatch(version):
        raise LocalReleaseError(f"invalid SemVer release version: {version}")
    tag = f"v{version}"
    source_release = source_release.resolve()
    source_files = _validate_package(source_release, version)
    releases_root = config.local_root / "releases"
    destination = releases_root / tag

    with tempfile.TemporaryDirectory(prefix=f"fantasydisk-{tag}-") as temporary:
        expected_project = Path(temporary) / "project"
        commit = _extract_tag(repo_root.resolve(), tag, expected_project)
        if _project_version(expected_project / "project.godot") != version:
            raise LocalReleaseError(f"{tag} project.godot does not contain version {version}")
        expected_tree = _tree_digest(expected_project)

        if dry_run:
            if destination.exists():
                _compare_package(source_files, destination)
                project = destination / "project"
                if not project.is_dir() or _tree_digest(project) != expected_tree:
                    raise LocalReleaseError(f"existing {tag} source snapshot differs from git tag")
            return destination, {
                "version": version,
                "tag": tag,
                "tag_commit": commit,
                "source_tree_sha256": expected_tree,
                "package_files": sorted(source_files),
            }

        releases_root.mkdir(parents=True, exist_ok=True)
        (releases_root / ".gdignore").touch(exist_ok=True)
        if destination.exists():
            _compare_package(source_files, destination)
            project = destination / "project"
            if project.exists():
                if _tree_digest(project) != expected_tree:
                    raise LocalReleaseError(f"existing {tag} source snapshot differs from git tag")
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
        tag=tag,
        commit=commit,
        source_tree_sha256=expected_tree,
        release_dir=destination,
        package_files=source_files,
        app_target=config.macos_app,
        app_required=platform.system() == "Darwin",
    )
    _atomic_json(destination / MANIFEST_NAME, manifest)
    return destination, manifest


def _bundle_version(app: Path) -> str:
    plist = app / "Contents" / "Info.plist"
    if not plist.is_file():
        raise LocalReleaseError(f"installed app has no Info.plist: {app}")
    with plist.open("rb") as handle:
        payload = plistlib.load(handle)
    value = payload.get("CFBundleShortVersionString") or payload.get("CFBundleVersion")
    if not value:
        raise LocalReleaseError(f"installed app has no bundle version: {app}")
    return str(value)


def verify_macos_app(app: Path, version: str, *, launch_smoke: bool) -> None:
    if not app.is_dir():
        raise LocalReleaseError(f"macOS app is not installed: {app}")
    if _bundle_version(app) != version:
        raise LocalReleaseError(
            f"installed app version is {_bundle_version(app)}, expected {version}"
        )
    _run(["codesign", "--verify", "--deep", "--strict", "--verbose=4", app])
    _run(["xcrun", "stapler", "validate", app])
    _run(["spctl", "--assess", "--type", "execute", "--verbose=4", app])
    if launch_smoke:
        executables = [
            path
            for path in (app / "Contents" / "MacOS").iterdir()
            if path.is_file() and os.access(path, os.X_OK)
        ]
        if len(executables) != 1:
            raise LocalReleaseError(f"cannot identify app executable in {app}")
        _run([executables[0], "--headless", "--quit-after", "2"], timeout=30)


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


def verify_macos_dmg(dmg: Path, version: str) -> None:
    _run(["hdiutil", "verify", dmg], timeout=300)
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
            verify_macos_app(apps[0], version, launch_smoke=False)
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
) -> None:
    verify_macos_dmg(dmg, version)
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="fantasydisk-dmg-") as temporary:
        device = ""
        try:
            mountpoint, device = _mount_dmg(dmg, Path(temporary) / "mount")
            apps = list(mountpoint.glob("*.app"))
            if len(apps) != 1:
                raise LocalReleaseError(f"DMG must contain exactly one app: {dmg}")
            verify_macos_app(apps[0], version, launch_smoke=False)

            stage = target.parent / f".{target.name}.stage.{os.getpid()}"
            backup = target.parent / f".{target.name}.backup.{os.getpid()}"
            if stage.exists() or backup.exists():
                raise LocalReleaseError(f"stale app install stage exists beside {target}")
            _run(["ditto", "--rsrc", "--extattr", apps[0], stage])
            verify_macos_app(stage, version, launch_smoke=False)
            moved_old = False
            try:
                if target.exists():
                    os.replace(target, backup)
                    moved_old = True
                os.replace(stage, target)
                verify_macos_app(target, version, launch_smoke=launch_smoke)
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


def _update_current_project(releases_root: Path, version: str) -> Path:
    current = releases_root / "current-project"
    if current.exists() and not current.is_symlink():
        raise LocalReleaseError(f"current-project exists and is not a symlink: {current}")
    temporary = releases_root / f".current-project.tmp.{os.getpid()}"
    if temporary.exists() or temporary.is_symlink():
        temporary.unlink()
    temporary.symlink_to(f"v{version}/godot-project")
    os.replace(temporary, current)
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
) -> dict:
    tag = f"v{version}"
    release_dir = config.local_root / "releases" / tag
    package_files = _validate_package(release_dir, version)
    manifest_path = release_dir / MANIFEST_NAME
    manifest = _load_json(manifest_path)
    commit = _run(["git", "rev-parse", f"{tag}^{{commit}}"], cwd=repo_root).stdout.strip()
    if manifest.get("version") != version or manifest.get("tag_commit") != commit:
        raise LocalReleaseError(f"local manifest does not match {tag}")
    with tempfile.TemporaryDirectory(prefix=f"fantasydisk-verify-{tag}-") as temporary:
        expected_project = Path(temporary) / "project"
        archived_commit = _extract_tag(repo_root, tag, expected_project)
        expected_tree = _tree_digest(expected_project)
    if archived_commit != commit or manifest.get("source_tree_sha256") != expected_tree:
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

    current = config.local_root / "releases" / "current-project"
    if not (config.local_root / "releases" / ".gdignore").is_file():
        raise LocalReleaseError("durable releases root is missing .gdignore")
    if not current.is_symlink() or os.readlink(current) != f"v{version}/godot-project":
        raise LocalReleaseError(f"current-project does not point to {tag}")
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
        verify_macos_dmg(release_dir / f"FantasyDisk-{version}-macos.dmg", version)
        verify_macos_app(config.macos_app, version, launch_smoke=launch_smoke)
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
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--launch-smoke", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    repo_root = args.repo_root.resolve()
    try:
        config = resolve_config(
            repo_root=repo_root,
            config_path=args.config,
            local_root=args.local_root,
            macos_app=args.macos_app,
            godot_projects_file=args.godot_projects_file,
        )
        require_app = platform.system() == "Darwin"
        if args.action == "materialize":
            source_release = args.release_dir or repo_root / "releases" / f"v{args.version}"
            destination, summary = materialize_package(
                version=args.version,
                repo_root=repo_root,
                source_release=source_release,
                config=config,
                dry_run=args.dry_run,
            )
            if args.dry_run:
                print(json.dumps({"destination": os.fspath(destination), **summary}, indent=2))
                return 0
            if require_app:
                install_macos_from_dmg(
                    dmg=destination / f"FantasyDisk-{args.version}-macos.dmg",
                    target=config.macos_app,
                    version=args.version,
                    launch_smoke=True,
                )
            current = _update_current_project(destination.parent, args.version)
            _register_godot(config.godot_projects_file, current)
        manifest = verify_local_release(
            version=args.version,
            repo_root=repo_root,
            config=config,
            require_app=require_app,
            launch_smoke=args.launch_smoke,
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
                "tag_commit": manifest["tag_commit"],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
