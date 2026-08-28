#!/usr/bin/env python3
"""FAN-3308 visual regression gate for FantasyDisk key screens and combat scenes.

The gate renders the manifest cases through `tests/visual_regression/capture.gd`
and compares each PNG against a committed baseline.  Rendering needs a real
display: Godot's headless display server owns no SubViewport texture, so a
headless capture can only read back empty images.  Baselines are therefore
stored per capture platform and the manifest names the certified one.

Modes:
    (default)             capture and compare; never writes a baseline
    --update-baselines    rewrite baselines; requires --review "<marker>"
    --verify-determinism  capture N times and require identical hashes
    --negative-probe      prove a visible mutation is detected (exit 1)
    --validate-only       manifest and baseline integrity; needs no display

Exit status:
    0  success (for --negative-probe: the mutation was NOT detected)
    1  comparison failed (for --negative-probe: the mutation WAS detected)
    2  usage or internal error
    3  capture failed
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "tests" / "visual_regression" / "manifest.json"
BASELINE_ROOT = ROOT / "tests" / "visual_regression" / "baselines"
DEFAULT_OUTPUT = ROOT / "build" / "visual_gate"
CAPTURE_SCRIPT = "res://tests/visual_regression/capture.gd"
INDEX_NAME = "index.json"
MIN_CASES = 8
MAX_CASES = 12
# Magenta is effectively absent from the game's art, so a filled block of it is
# a visible mutation for every case regardless of what the case renders.
PROBE_COLOR = (255, 0, 255)
PROBE_AREA_FRACTION = 0.10

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_ERROR = 2
EXIT_CAPTURE = 3


def platform_key() -> str:
    if sys.platform == "darwin":
        return "macos"
    if sys.platform.startswith("linux"):
        return "linux"
    if sys.platform.startswith("win"):
        return "windows"
    return sys.platform


def load_manifest(path: Path) -> dict:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or not isinstance(manifest.get("cases"), list):
        raise ValueError(f"{path}: manifest must be an object with a 'cases' list")
    return manifest


def selected_cases(manifest: dict, only: list[str]) -> list[dict]:
    cases = manifest["cases"]
    if not only:
        return cases
    by_id = {str(case.get("id", "")): case for case in cases}
    missing = [case_id for case_id in only if case_id not in by_id]
    if missing:
        raise ValueError(f"unknown case id(s): {', '.join(sorted(missing))}")
    return [by_id[case_id] for case_id in only]


def case_threshold(case: dict, defaults: dict) -> tuple[int, float]:
    tolerance = int(case.get("pixel_tolerance", defaults.get("pixel_tolerance", 8)))
    ratio = float(case.get("max_diff_ratio", defaults.get("max_diff_ratio", 0.004)))
    return tolerance, ratio


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def res_to_path(res_path: str) -> Path:
    return ROOT / res_path.removeprefix("res://")


def compare(expected: Image.Image, actual: Image.Image, tolerance: int) -> dict:
    """Return the differing-pixel ratio plus a human-readable diff overlay."""
    expected = expected.convert("RGB")
    actual = actual.convert("RGB")
    if expected.size != actual.size:
        return {
            "size_mismatch": True,
            "expected_size": list(expected.size),
            "actual_size": list(actual.size),
            "diff_ratio": 1.0,
            "differing_pixels": expected.size[0] * expected.size[1],
            "total_pixels": expected.size[0] * expected.size[1],
            "max_channel_delta": 255,
            "diff_image": None,
        }
    delta = ImageChops.difference(expected, actual)
    red, green, blue = delta.split()
    worst = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    mask = worst.point(lambda value: 255 if value > tolerance else 0, mode="L")
    differing = mask.histogram()[255]
    total = expected.size[0] * expected.size[1]
    dimmed = Image.blend(actual.convert("L").convert("RGB"), Image.new("RGB", actual.size), 0.55)
    overlay = Image.composite(Image.new("RGB", actual.size, (255, 0, 0)), dimmed, mask)
    return {
        "size_mismatch": False,
        "diff_ratio": differing / total if total else 0.0,
        "differing_pixels": differing,
        "total_pixels": total,
        "max_channel_delta": worst.getextrema()[1],
        "diff_image": overlay,
    }


def run_capture(output_dir: Path, only: list[str]) -> int:
    """Render the manifest cases through the shared Godot gate runner."""
    output_dir.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable,
        str(ROOT / "tools" / "godot_gate.py"),
        "--path",
        str(ROOT),
        "--script",
        CAPTURE_SCRIPT,
        "--",
        "--out",
        str(output_dir),
    ]
    if len(only) == 1:
        command += ["--case", only[0]]
    return subprocess.call(command)


def baseline_dir(platform: str) -> Path:
    return BASELINE_ROOT / platform


def read_index(platform: str) -> dict:
    index_path = baseline_dir(platform) / INDEX_NAME
    if not index_path.is_file():
        return {}
    return json.loads(index_path.read_text(encoding="utf-8"))


def cmd_validate(manifest: dict, platform: str, strict_baselines: bool) -> int:
    """Manifest and baseline integrity; runs anywhere, no display required."""
    problems: list[str] = []
    cases = manifest["cases"]
    if not MIN_CASES <= len(cases) <= MAX_CASES:
        problems.append(f"manifest defines {len(cases)} cases, expected {MIN_CASES}-{MAX_CASES}")
    seen: set[str] = set()
    defaults = manifest.get("defaults", {})
    required = {
        "ultimate_v2": ("scene", "advance_seconds"),
        "flipbook": ("pack", "animation", "frame"),
        "main_menu": ("scene",),
        "hud_widget": ("scene",),
    }
    for case in cases:
        case_id = str(case.get("id", ""))
        if not case_id or case_id in seen:
            problems.append(f"duplicate or missing case id: {case_id!r}")
            continue
        seen.add(case_id)
        kind = str(case.get("kind", ""))
        if kind not in required:
            problems.append(f"{case_id}: unknown kind {kind!r}")
            continue
        for field in required[kind]:
            if field not in case:
                problems.append(f"{case_id}: missing required field {field!r}")
        for field in ("scene", "pack"):
            if field in case and not res_to_path(str(case[field])).exists():
                problems.append(f"{case_id}: {field} does not exist: {case[field]}")
        viewport = case.get("viewport", [])
        if not (isinstance(viewport, list) and len(viewport) == 2 and all(int(v) > 0 for v in viewport)):
            problems.append(f"{case_id}: viewport must be [width, height]")
        tolerance, ratio = case_threshold(case, defaults)
        if not 0 <= tolerance <= 255 or not 0.0 < ratio <= 1.0:
            problems.append(f"{case_id}: invalid pixel_tolerance/max_diff_ratio")

    index = read_index(platform)
    directory = baseline_dir(platform)
    if strict_baselines or directory.is_dir():
        for case in cases:
            case_id = str(case.get("id", ""))
            image_path = directory / f"{case_id}.png"
            if not image_path.is_file():
                problems.append(f"{case_id}: no baseline for platform {platform}")
                continue
            entry = index.get(case_id)
            if not entry:
                problems.append(f"{case_id}: baseline is not recorded in {platform}/{INDEX_NAME}")
                continue
            if entry.get("sha256") != sha256_file(image_path):
                problems.append(f"{case_id}: baseline bytes do not match the recorded sha256")
            if not str(entry.get("review", "")).strip():
                problems.append(f"{case_id}: baseline carries no review marker")
            with Image.open(image_path) as image:
                if list(image.size) != [int(v) for v in case.get("viewport", [])]:
                    problems.append(f"{case_id}: baseline size {image.size} != manifest viewport")
    elif not directory.is_dir():
        print(f"visual_gate: no baselines for platform {platform}; integrity check skipped")

    for problem in problems:
        print(f"visual_gate: {problem}", file=sys.stderr)
    if problems:
        return EXIT_FAILED
    print(f"visual_gate: manifest and {platform} baselines are consistent ({len(cases)} cases)")
    return EXIT_OK


def cmd_compare(manifest: dict, cases: list[dict], platform: str, output_dir: Path, only: list[str]) -> int:
    directory = baseline_dir(platform)
    if not directory.is_dir():
        print(
            f"visual_gate: no baselines for platform {platform}; "
            f"create them with --update-baselines --review \"<marker>\"",
            file=sys.stderr,
        )
        return EXIT_ERROR
    actual_dir = output_dir / "actual"
    if run_capture(actual_dir, only) != 0:
        print("visual_gate: capture failed", file=sys.stderr)
        return EXIT_CAPTURE

    defaults = manifest.get("defaults", {})
    results = []
    failed = False
    for case in cases:
        case_id = str(case["id"])
        tolerance, max_ratio = case_threshold(case, defaults)
        expected_path = directory / f"{case_id}.png"
        actual_path = actual_dir / f"{case_id}.png"
        record = {"id": case_id, "max_diff_ratio": max_ratio, "pixel_tolerance": tolerance}
        if not actual_path.is_file():
            record.update(status="missing_capture")
            results.append(record)
            failed = True
            continue
        if not expected_path.is_file():
            record.update(status="missing_baseline")
            results.append(record)
            failed = True
            continue
        with Image.open(expected_path) as expected, Image.open(actual_path) as actual:
            outcome = compare(expected, actual, tolerance)
            diff_image = outcome.pop("diff_image")
            record.update(outcome)
            if outcome["diff_ratio"] <= max_ratio and not outcome["size_mismatch"]:
                record["status"] = "passed"
            else:
                record["status"] = "failed"
                failed = True
                artifacts = output_dir / case_id
                artifacts.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(expected_path, artifacts / "expected.png")
                shutil.copyfile(actual_path, artifacts / "actual.png")
                if diff_image is not None:
                    diff_image.save(artifacts / "diff.png")
                record["artifacts"] = str(artifacts.relative_to(ROOT))
        results.append(record)

    summary = {
        "platform": platform,
        "capture": manifest.get("capture", {}),
        "passed": sum(1 for r in results if r["status"] == "passed"),
        "failed": sum(1 for r in results if r["status"] != "passed"),
        "cases": results,
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    for record in results:
        if record["status"] == "passed":
            print(f"  ok   {record['id']}  ratio={record['diff_ratio']:.6f} <= {record['max_diff_ratio']}")
        else:
            print(
                f"  FAIL {record['id']}  status={record['status']} "
                f"ratio={record.get('diff_ratio', 1.0):.6f} > {record['max_diff_ratio']}",
                file=sys.stderr,
            )
    print(f"visual_gate: {summary['passed']} passed, {summary['failed']} failed; summary in {output_dir / 'summary.json'}")
    return EXIT_FAILED if failed else EXIT_OK


def cmd_update(manifest: dict, cases: list[dict], platform: str, output_dir: Path, only: list[str], review: str) -> int:
    actual_dir = output_dir / "actual"
    if run_capture(actual_dir, only) != 0:
        print("visual_gate: capture failed", file=sys.stderr)
        return EXIT_CAPTURE
    directory = baseline_dir(platform)
    directory.mkdir(parents=True, exist_ok=True)
    index = read_index(platform)
    for case in cases:
        case_id = str(case["id"])
        captured = actual_dir / f"{case_id}.png"
        if not captured.is_file():
            print(f"visual_gate: {case_id}: capture missing, baseline not updated", file=sys.stderr)
            return EXIT_CAPTURE
        target = directory / f"{case_id}.png"
        shutil.copyfile(captured, target)
        index[case_id] = {"sha256": sha256_file(target), "review": review}
    for stale in sorted(set(index) - {str(case["id"]) for case in manifest["cases"]}):
        del index[stale]
    (directory / INDEX_NAME).write_text(
        json.dumps(dict(sorted(index.items())), indent=2) + "\n", encoding="utf-8"
    )
    print(f"visual_gate: updated {len(cases)} baseline(s) for {platform} with review marker {review!r}")
    return EXIT_OK


def cmd_determinism(cases: list[dict], output_dir: Path, only: list[str], runs: int) -> int:
    digests: dict[str, set[str]] = {str(case["id"]): set() for case in cases}
    with tempfile.TemporaryDirectory(prefix="visual-gate-determinism-") as temp:
        for run_index in range(runs):
            run_dir = Path(temp) / f"run{run_index}"
            if run_capture(run_dir, only) != 0:
                print("visual_gate: capture failed", file=sys.stderr)
                return EXIT_CAPTURE
            for case_id in digests:
                image = run_dir / f"{case_id}.png"
                if not image.is_file():
                    print(f"visual_gate: {case_id}: run {run_index} produced no capture", file=sys.stderr)
                    return EXIT_CAPTURE
                digests[case_id].add(sha256_file(image))
    unstable = sorted(case_id for case_id, seen in digests.items() if len(seen) != 1)
    for case_id in sorted(digests):
        marker = "ok  " if case_id not in unstable else "DRIFT"
        print(f"  {marker} {case_id}  {sorted(digests[case_id])[0][:16]}  variants={len(digests[case_id])}")
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "determinism.json").write_text(
        json.dumps(
            {"runs": runs, "unstable": unstable, "digests": {k: sorted(v) for k, v in digests.items()}},
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    if unstable:
        print(f"visual_gate: {len(unstable)} case(s) are not deterministic across {runs} runs", file=sys.stderr)
        return EXIT_FAILED
    print(f"visual_gate: all {len(digests)} case(s) produced identical hashes across {runs} runs")
    return EXIT_OK


def cmd_negative_probe(manifest: dict, cases: list[dict], platform: str) -> int:
    """Mutate a copy of a baseline and require the comparison to reject it.

    Everything happens in a temporary directory, so the checkout is untouched;
    the probe verifies that afterwards and reports the measured ratio.
    """
    directory = baseline_dir(platform)
    if not directory.is_dir():
        print(f"visual_gate: no baselines for platform {platform} to probe", file=sys.stderr)
        return EXIT_ERROR
    tracked = sorted(p for p in directory.rglob("*") if p.is_file())
    before = {p: sha256_file(p) for p in tracked}
    defaults = manifest.get("defaults", {})
    detected: list[str] = []
    undetected: list[str] = []
    with tempfile.TemporaryDirectory(prefix="visual-gate-probe-") as temp:
        for case in cases:
            case_id = str(case["id"])
            baseline = directory / f"{case_id}.png"
            if not baseline.is_file():
                continue
            tolerance, max_ratio = case_threshold(case, defaults)
            mutated_path = Path(temp) / f"{case_id}.png"
            with Image.open(baseline) as source:
                mutated = source.convert("RGB").copy()
            width, height = mutated.size
            side = max(1, int((width * height * PROBE_AREA_FRACTION) ** 0.5))
            ImageDraw.Draw(mutated).rectangle([0, 0, side - 1, side - 1], fill=PROBE_COLOR)
            mutated.save(mutated_path)
            with Image.open(baseline) as expected, Image.open(mutated_path) as actual:
                outcome = compare(expected, actual, tolerance)
            if outcome["diff_ratio"] > max_ratio:
                detected.append(f"{case_id} ratio={outcome['diff_ratio']:.6f} > {max_ratio}")
            else:
                undetected.append(f"{case_id} ratio={outcome['diff_ratio']:.6f} <= {max_ratio}")

    after = {p: sha256_file(p) for p in sorted(p for p in directory.rglob("*") if p.is_file())}
    if before != after:
        print("visual_gate: negative probe modified the checkout", file=sys.stderr)
        return EXIT_ERROR
    for line in detected:
        print(f"  detected {line}")
    for line in undetected:
        print(f"  MISSED   {line}", file=sys.stderr)
    if undetected or not detected:
        print("visual_gate: negative probe was NOT detected; the gate is blind", file=sys.stderr)
        return EXIT_OK
    print(
        f"visual_gate: negative probe detected on all {len(detected)} case(s); "
        f"checkout unchanged. Exiting 1 by contract."
    )
    return EXIT_FAILED


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--platform", default=platform_key())
    parser.add_argument("--case", action="append", default=[], help="limit to one case id (repeatable)")
    parser.add_argument("--update-baselines", action="store_true")
    parser.add_argument("--review", default="", help="review marker recorded with updated baselines")
    parser.add_argument("--verify-determinism", action="store_true")
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--negative-probe", action="store_true")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument(
        "--require-baselines",
        action="store_true",
        help="with --validate-only, fail when the platform has no baselines",
    )
    args = parser.parse_args(argv)

    modes = [args.update_baselines, args.verify_determinism, args.negative_probe, args.validate_only]
    if sum(bool(mode) for mode in modes) > 1:
        parser.error("choose at most one mode")
    try:
        manifest = load_manifest(args.manifest)
        cases = selected_cases(manifest, args.case)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"visual_gate: {exc}", file=sys.stderr)
        return EXIT_ERROR

    if args.validate_only:
        return cmd_validate(manifest, args.platform, args.require_baselines)
    if args.negative_probe:
        return cmd_negative_probe(manifest, cases, args.platform)
    if args.verify_determinism:
        if args.runs < 2:
            parser.error("--runs must be at least 2")
        return cmd_determinism(cases, args.output_dir, args.case, args.runs)
    if args.update_baselines:
        if not args.review.strip():
            print(
                "visual_gate: --update-baselines requires --review \"<marker>\" "
                "so the new pixels carry a documented reviewer decision",
                file=sys.stderr,
            )
            return EXIT_ERROR
        return cmd_update(manifest, cases, args.platform, args.output_dir, args.case, args.review.strip())
    return cmd_compare(manifest, cases, args.platform, args.output_dir, args.case)


if __name__ == "__main__":
    raise SystemExit(main())
