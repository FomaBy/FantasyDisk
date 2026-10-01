#!/usr/bin/env python3
"""FAN-3994: prove every built 0.3.1.2 artifact hash differs from every file of
every retained package under the releases root (v0.3.1, v0.3.1.1, archives,
other versions). Writes a JSON proof with the per-package top-level hashes and
the list of collisions (expected: only the poster image, which by PM decision
is the unchanged 0.3.1 image under a new name)."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def top_level(package: Path) -> dict[str, str]:
    return {p.name: sha256(p) for p in sorted(package.iterdir()) if p.is_file() and p.name != ".DS_Store"}


def main() -> int:
    releases = Path(sys.argv[1])
    new_tag = sys.argv[2]
    out = Path(sys.argv[3])
    new_package = top_level(releases / new_tag)
    retained: dict[str, dict[str, str]] = {}
    for candidate in sorted(list(releases.iterdir()) + list((releases / "archive").iterdir())):
        if not candidate.is_dir() or candidate.is_symlink() or candidate.name in {new_tag, "archive"}:
            continue
        files = top_level(candidate)
        if files:
            retained[str(candidate.relative_to(releases))] = files
    collisions = []
    for package, files in retained.items():
        for name, digest in files.items():
            for new_name, new_digest in new_package.items():
                if digest == new_digest:
                    collisions.append({"package": package, "file": name, "new_file": new_name, "sha256": digest})
    installers = {k for k in new_package if k.endswith((".dmg", ".exe"))}
    result = {
        "new_package": new_package,
        "retained_packages": retained,
        "collisions": collisions,
        "all_built_artifacts_differ": not [c for c in collisions if not c["new_file"].endswith("announcement.png")],
        "installer_collisions": [c for c in collisions if c["new_file"] in installers],
    }
    out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("collisions", "all_built_artifacts_differ", "installer_collisions")}, indent=2))
    return 0 if result["all_built_artifacts_differ"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
