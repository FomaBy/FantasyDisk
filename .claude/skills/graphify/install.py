"""Install the project-pinned Graphify revision into the project venv."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import venv
from pathlib import Path


PIN_FILE = Path(__file__).with_name(".graphify_pin.json")
SHA_PATTERN = re.compile(r"[0-9a-f]{40}")
EXTRA_PATTERN = re.compile(r"[A-Za-z0-9_-]+")


def load_pin() -> dict:
    pin = json.loads(PIN_FILE.read_text(encoding="utf-8"))
    revision = pin.get("revision", "")
    repository = pin.get("repository", "")
    package = pin.get("package", "")
    if not SHA_PATTERN.fullmatch(revision):
        raise ValueError("Graphify pin must contain a lowercase 40-hex revision")
    if not repository.startswith("https://github.com/") or not repository.endswith(".git"):
        raise ValueError("Graphify pin must use an HTTPS GitHub repository")
    if not package or not re.fullmatch(r"[A-Za-z0-9_.-]+", package):
        raise ValueError("Graphify pin has an invalid package name")
    return pin


def requirement(pin: dict, extras: tuple[str, ...] = ()) -> str:
    configured = tuple(pin.get("extras", ()))
    all_extras = tuple(dict.fromkeys((*configured, *extras)))
    for extra in all_extras:
        if not EXTRA_PATTERN.fullmatch(extra):
            raise ValueError(f"invalid Graphify extra: {extra}")
    suffix = f"[{','.join(all_extras)}]" if all_extras else ""
    return f"{pin['package']}{suffix} @ git+{pin['repository']}@{pin['revision']}"


def project_root() -> Path:
    return Path(__file__).resolve().parents[3]


def venv_python(root: Path) -> Path:
    relative = Path(load_pin().get("venv", ".claude/skills/graphify/.venv"))
    venv_dir = root / relative
    return venv_dir / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")


def _verify_code() -> str:
    return (
        "import importlib.metadata as metadata, json, sys; "
        "dist = metadata.distribution(sys.argv[1]); "
        "direct = json.loads(dist.read_text('direct_url.json') or '{}'); "
        "commit = direct.get('vcs_info', {}).get('commit_id'); "
        "assert commit == sys.argv[2], f'installed Graphify revision: {commit!r}'"
    )


def install(root: Path, extras: tuple[str, ...] = ()) -> Path:
    if sys.version_info < (3, 10):
        raise RuntimeError("Graphify requires Python 3.10 or newer")
    pin = load_pin()
    python = venv_python(root)
    venv.EnvBuilder(with_pip=True, clear=True, symlinks=True).create(python.parent.parent)
    subprocess.run(
        [
            str(python),
            "-m",
            "pip",
            "install",
            "--disable-pip-version-check",
            "--no-cache-dir",
            requirement(pin, extras),
        ],
        cwd=root,
        check=True,
    )
    subprocess.run(
        [str(python), "-c", _verify_code(), pin["package"], pin["revision"]],
        cwd=root,
        check=True,
    )
    print(f"Installed {pin['package']} at {pin['revision']} into {python.parent.parent}")
    return python


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extra", action="append", default=[], help="Graphify optional extra")
    parser.add_argument("--print-requirement", action="store_true")
    parser.add_argument("--print-command", action="store_true")
    args = parser.parse_args(argv)

    pin = load_pin()
    extras = tuple(args.extra)
    if args.print_requirement:
        print(requirement(pin, extras))
        return 0
    if args.print_command:
        print(
            " ".join(
                [
                    sys.executable,
                    str(Path(__file__).relative_to(project_root())),
                    *sum((["--extra", extra] for extra in extras), []),
                ]
            )
        )
        return 0
    install(project_root(), extras)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
