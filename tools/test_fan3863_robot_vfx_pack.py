#!/usr/bin/env python3
"""Focused offline rebuild/integrity test for the FAN-3863 Robot VFX trio."""

from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "tools" / "build_fan3863_robot_vfx_pack.py"
PACKS = ("magnetic_anchor", "hydraulic_press", "reactor_core")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def derived_paths(root: Path, pack: str) -> list[Path]:
    source = root / "docs" / "design" / "reference-assets-lfs" / "robot-vfx-FAN-3320-art" / pack
    runtime = root / "assets" / "sprites" / "effects" / "robot" / pack
    return sorted(
        [*source.glob(f"{pack}_f*.png"), source / f"{pack}_contact_sheet.png", source / "pixel_quality_evidence.json"]
        + list(runtime.iterdir())
    )


def run_builder(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(BUILDER), "--root", str(root), *args],
        check=False,
        capture_output=True,
        text=True,
    )


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="fan3863_robot_vfx_") as temp_dir:
        temp = Path(temp_dir)
        expected: dict[Path, str] = {}
        for pack in PACKS:
            for relative in (
                Path("docs/design/reference-assets-lfs/robot-vfx-FAN-3320-art") / pack,
                Path("assets/sprites/effects/robot") / pack,
            ):
                shutil.copytree(ROOT / relative, temp / relative)
            for path in derived_paths(temp, pack):
                expected[path.relative_to(temp)] = sha256(path)
                path.unlink()

        rebuilt = run_builder(temp)
        assert rebuilt.returncode == 0, rebuilt.stderr or rebuilt.stdout
        actual = {relative: sha256(temp / relative) for relative in expected}
        assert actual == expected, "offline rebuild did not reproduce the committed Robot VFX outputs byte-for-byte"

        checked = run_builder(temp, "--check")
        assert checked.returncode == 0, checked.stderr or checked.stdout

        corrupted = temp / "assets/sprites/effects/robot/magnetic_anchor/magnetic_anchor_f00.png"
        corrupted.write_bytes(b"corrupted")
        rejected = run_builder(temp, "--check")
        assert rejected.returncode != 0, "integrity check accepted a corrupted runtime frame"
        assert "magnetic_anchor_f00.png" in rejected.stderr, rejected.stderr

    print("PASS: FAN-3863 Robot VFX trio rebuilds offline and rejects drift")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
