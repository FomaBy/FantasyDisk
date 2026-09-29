#!/usr/bin/env python3
"""FAN-3985 exported-build regression gate for the 51 weapon ultimates.

Editor and headless-editor suites cannot catch an export-only regression: the
source ``.gd`` scripts and the ``docs/`` tree exist there.  This gate exports
the macOS preset headlessly, then runs ``tools/ultimate_export_probe.gd``
INSIDE the exported app — the exported binary, the exported PCK, the remapped
``.gdc`` scripts and the exported data — and judges its report:

* every canonical class/weapon pair resolves with ``resolution_source =
  weapon_profile`` (never ``legacy_class_fallback``), admits its executor,
  resolves its class-owned presentation scene and ``begin()`` succeeds with
  that scene instantiated;
* the exported app carries no ``docs/``, ``evidence/``, ``tests/``,
  ``tools/`` or ``skills/`` entries and does carry the runtime presentation
  documents (listed from the PCK directory);
* mutation checks: with one class document removed from the export the probe
  must fail for that class, and with one executor remap removed the pair must
  fall back to ``legacy_class_fallback`` and fail — so a green probe is never
  vacuous;
* optionally (``--captures``) a windowed run of the exported app screenshots
  one weapon per class at its ``active`` beat.

Official export templates are built with ``disable_path_overrides``, so the
probe cannot be injected with ``--script`` or a scene argument.  Instead the
exported app is cloned and an ``override.cfg`` beside its executable points
``application/run/main_scene`` at a generated scene carrying the probe script.
The exported PCK is never modified for the main run; mutation runs patch a
copy of the PCK directory in place (same-length path rename), which is the
only way to remove a file from an already exported pack.

Usage (from the repository root, macOS):
    python3 tools/ultimate_export_probe.py --captures --evidence-dir evidence/FAN-3985
    python3 tools/ultimate_export_probe.py --skip-export   # reuse the last export
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "tools" / "godot_gate.py"
PROBE_SCRIPT = ROOT / "tools" / "ultimate_export_probe.gd"
DEFAULT_OUTPUT = ROOT / "build" / "ultimate_export_probe"
PRESET = "macOS"
APP_NAME = "FantasyDisk.app"
EXPECTED_PAIRS = 51
EXPECTED_CLASSES = 17
# PCK directory paths are stored without the `res://` prefix since format 4;
# older packs keep it. Entries are normalised to the prefix-less form.
RESOURCE_PREFIX = "res://"
PRESENTATION_PREFIX = "data/ultimates/presentation/"
FORBIDDEN_PREFIXES = ("docs/", "evidence/", "tests/", "tools/", "skills/")
PROBE_TIMEOUT = 900.0
PACK_DIR_ENCRYPTED = 1 << 0
PACK_REL_FILEBASE = 1 << 1

MUTATIONS = (
    {
        "name": "presentation_document_removed",
        "entry": "data/ultimates/presentation/knight.json",
        "renamed": "data/ultimates/presentation/knight.jsxn",
        "affected_keys": ("knight/long_spear", "knight/tower_shield", "knight/holy_flail"),
        "expect": {"record_found": False, "begin_ok": False},
    },
    {
        "name": "executor_remap_removed",
        "entry": "scripts/ultimates/classes/knight/long_spear.gd.remap",
        "renamed": "scripts/ultimates/classes/knight/long_spear.gd.remxp",
        "affected_keys": ("knight/long_spear",),
        "expect": {"resolution_source": "legacy_class_fallback"},
    },
)


class ProbeError(RuntimeError):
    pass


def log(message: str) -> None:
    print(f"ultimate_export_probe: {message}", flush=True)


# --- PCK directory -----------------------------------------------------------


def read_pck_directory(pck_path: Path) -> dict:
    """Header and file table of a Godot 4 PCK (format 2–4, plain directory)."""
    with pck_path.open("rb") as handle:
        if handle.read(4) != b"GDPC":
            raise ProbeError(f"{pck_path}: not a Godot PCK")
        version, major, minor, patch, flags = struct.unpack("<5I", handle.read(20))
        if flags & PACK_DIR_ENCRYPTED:
            raise ProbeError(f"{pck_path}: encrypted PCK directory cannot be listed")
        file_base = struct.unpack("<Q", handle.read(8))[0]
        if version >= 3:
            dir_offset = struct.unpack("<Q", handle.read(8))[0]
            handle.seek(dir_offset)
        else:
            handle.read(16 * 4)
        directory_offset = handle.tell()
        file_count = struct.unpack("<I", handle.read(4))[0]
        entries = []
        for _ in range(file_count):
            path_length = struct.unpack("<I", handle.read(4))[0]
            path_offset = handle.tell()
            raw_path = handle.read(path_length).split(b"\0", 1)[0]
            path = raw_path.decode("utf-8").removeprefix(RESOURCE_PREFIX)
            offset, size = struct.unpack("<QQ", handle.read(16))
            handle.read(16)  # md5
            entry_flags = struct.unpack("<I", handle.read(4))[0]
            if flags & PACK_REL_FILEBASE:
                offset += file_base
            entries.append({
                "path": path,
                "raw_path": raw_path,
                "path_offset": path_offset,
                "path_length": path_length,
                "offset": offset,
                "size": size,
                "flags": entry_flags,
            })
    return {
        "format_version": version,
        "engine_version": f"{major}.{minor}.{patch}",
        "flags": flags,
        "directory_offset": directory_offset,
        "entries": entries,
    }


def rename_pck_entry(pck_path: Path, old_path: str, new_path: str) -> None:
    """Rename one directory entry in place (same byte length), removing the old path."""
    if len(old_path.encode("utf-8")) != len(new_path.encode("utf-8")):
        raise ProbeError("PCK rename needs equal-length paths")
    directory = read_pck_directory(pck_path)
    matches = [entry for entry in directory["entries"] if entry["path"] == old_path]
    if len(matches) != 1:
        raise ProbeError(f"{old_path} occurs {len(matches)} times in {pck_path}")
    entry = matches[0]
    raw_old: bytes = entry["raw_path"]
    prefix = raw_old[: len(raw_old) - len(old_path.encode("utf-8"))]
    encoded = prefix + new_path.encode("utf-8")
    with pck_path.open("r+b") as handle:
        handle.seek(entry["path_offset"])
        current = handle.read(len(raw_old))
        if current != raw_old:
            raise ProbeError("PCK directory bytes do not match the parsed entry")
        handle.seek(entry["path_offset"])
        handle.write(encoded)
    after = read_pck_directory(pck_path)["entries"]
    if any(entry["path"] == old_path for entry in after) or not any(entry["path"] == new_path for entry in after):
        raise ProbeError("PCK rename did not take effect")


def pck_listing(directory: dict) -> dict:
    entries = directory["entries"]
    by_top: dict[str, int] = {}
    for entry in entries:
        top = entry["path"].split("/", 1)[0]
        by_top[top] = by_top.get(top, 0) + 1
    presentation = sorted(
        ({"path": e["path"], "size": e["size"]} for e in entries if e["path"].startswith(PRESENTATION_PREFIX)),
        key=lambda e: e["path"],
    )
    classes_dir = "scripts/ultimates/classes/"
    class_files = [e["path"] for e in entries if e["path"].startswith(classes_dir)]
    by_ext: dict[str, int] = {}
    for path in class_files:
        name = path.rsplit("/", 1)[-1]
        ext = name.split(".", 1)[1] if "." in name else ""
        by_ext[ext] = by_ext.get(ext, 0) + 1
    forbidden = sorted(e["path"] for e in entries if e["path"].startswith(FORBIDDEN_PREFIXES))
    return {
        "format_version": directory["format_version"],
        "engine_version": directory["engine_version"],
        "entry_count": len(entries),
        "entries_by_top_level": dict(sorted(by_top.items())),
        "presentation_documents": presentation,
        "ultimate_class_package_files_by_extension": dict(sorted(by_ext.items())),
        "forbidden_entries": forbidden,
    }


# --- exported app ------------------------------------------------------------


def run(command: list[str], *, cwd: Path = ROOT, timeout: float | None = None, log_path: Path | None = None) -> subprocess.CompletedProcess:
    log("$ " + " ".join(str(part) for part in command))
    with (log_path.open("wb") if log_path else open(os.devnull, "wb")) as sink:
        return subprocess.run(command, cwd=cwd, stdout=sink, stderr=subprocess.STDOUT, timeout=timeout, check=False)


def export_app(output_dir: Path, *, skip_import: bool) -> Path:
    export_dir = output_dir / "export"
    if export_dir.exists():
        shutil.rmtree(export_dir)
    export_dir.mkdir(parents=True)
    if not skip_import:
        result = run([sys.executable, str(GATE), "--ensure-import-cache", "--headless", "--path", str(ROOT)], log_path=export_dir / "import.log")
        if result.returncode != 0:
            raise ProbeError(f"import cache warm-up failed ({result.returncode}); see {export_dir / 'import.log'}")
    archive = export_dir / "FantasyDisk-macos.zip"
    result = run(
        [sys.executable, str(GATE), "--headless", "--path", str(ROOT), "--export-release", PRESET, str(archive)],
        log_path=export_dir / "export.log",
        timeout=3600,
    )
    if result.returncode != 0 or not archive.is_file():
        raise ProbeError(f"export failed ({result.returncode}); see {export_dir / 'export.log'}")
    result = run(["unzip", "-q", "-o", str(archive), "-d", str(export_dir)], log_path=export_dir / "unzip.log")
    app = export_dir / APP_NAME
    if result.returncode != 0 or not app.is_dir():
        raise ProbeError(f"unzip failed ({result.returncode}); see {export_dir / 'unzip.log'}")
    return app


def app_binary(app: Path) -> Path:
    binaries = list((app / "Contents" / "MacOS").iterdir()) if (app / "Contents" / "MacOS").is_dir() else []
    binaries = [path for path in binaries if path.is_file() and os.access(path, os.X_OK) and path.suffix == ""]
    if len(binaries) != 1:
        raise ProbeError(f"expected one executable in {app}/Contents/MacOS, found {binaries}")
    return binaries[0]


def app_pck(app: Path) -> Path:
    packs = sorted((app / "Contents" / "Resources").glob("*.pck"))
    if len(packs) != 1:
        raise ProbeError(f"expected one .pck in {app}/Contents/Resources, found {packs}")
    return packs[0]


def clone_app(app: Path, destination: Path) -> Path:
    if destination.exists():
        shutil.rmtree(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(["cp", "-Rc", str(app), str(destination)], check=False, capture_output=True)
    if result.returncode != 0:
        shutil.copytree(app, destination, symlinks=True)
    return destination


def write_probe_scene(output_dir: Path) -> Path:
    scene = output_dir / "ultimate_export_probe.tscn"
    scene.write_text(
        "[gd_scene load_steps=2 format=3]\n\n"
        f'[ext_resource type="Script" path="{PROBE_SCRIPT}" id="1_probe"]\n\n'
        '[node name="Fan3985ExportProbe" type="Node2D"]\n'
        'script = ExtResource("1_probe")\n',
        encoding="utf-8",
    )
    return scene


def install_override(app: Path, scene: Path) -> None:
    override = app_binary(app).parent / "override.cfg"
    override.write_text(f'[application]\nrun/main_scene="{scene}"\n', encoding="utf-8")


def run_probe(app: Path, report_path: Path, log_path: Path, *, windowed: bool, capture_dir: Path | None) -> subprocess.CompletedProcess:
    binary = app_binary(app)
    command = [str(binary)]
    if windowed:
        command += ["--windowed", "--resolution", "1280x720", "--fixed-fps", "60", "--disable-vsync"]
    else:
        command += ["--headless"]
    command += ["--", f"--report={report_path}"]
    if capture_dir is not None:
        command.append(f"--captures={capture_dir}")
    if report_path.exists():
        report_path.unlink()
    return run(command, cwd=binary.parent, timeout=PROBE_TIMEOUT, log_path=log_path)


def load_report(report_path: Path) -> dict:
    if not report_path.is_file():
        raise ProbeError(f"probe wrote no report: {report_path}")
    return json.loads(report_path.read_text(encoding="utf-8"))


# --- judgement ---------------------------------------------------------------


def judge_main_report(report: dict, expected_documents: list[str]) -> list[str]:
    problems: list[str] = []
    env = report.get("environment", {})
    if env.get("editor_feature") is not False:
        problems.append("probe did not run in an exported binary (editor feature present)")
    if env.get("docs_manifest_present") is not False:
        problems.append("docs manifests are present in the export; the probe is not running against the exported PCK")
    if sorted(env.get("presentation_documents", [])) != expected_documents:
        problems.append(f"exported presentation documents {env.get('presentation_documents')} != {expected_documents}")
    pairs = report.get("pairs", [])
    if len(pairs) != EXPECTED_PAIRS:
        problems.append(f"probe reported {len(pairs)} pairs, expected {EXPECTED_PAIRS}")
    classes = {pair.get("class_id") for pair in pairs}
    if len(classes) != EXPECTED_CLASSES:
        problems.append(f"probe covered {len(classes)} classes, expected {EXPECTED_CLASSES}")
    for pair in pairs:
        key = pair.get("key", "?")
        if pair.get("resolution_source") != "weapon_profile":
            problems.append(f"{key}: resolution_source={pair.get('resolution_source')}")
        if not pair.get("executor_admitted"):
            problems.append(f"{key}: executor not admitted")
        if not pair.get("begin_ok"):
            problems.append(f"{key}: begin() failed ({pair.get('budget_diagnostic') or pair.get('failures')})")
        scene = str(pair.get("scene_path", ""))
        if not scene.startswith(f"res://scenes/vfx/ultimates/{pair.get('class_id')}/"):
            problems.append(f"{key}: scene_path {scene!r} is not class-owned")
        if pair.get("instantiated_scene_file") != scene:
            problems.append(f"{key}: instantiated {pair.get('instantiated_scene_file')!r}, resolved {scene!r}")
        if not pair.get("pass"):
            problems.append(f"{key}: {pair.get('failures')}")
    if report.get("errors"):
        problems.append(f"probe errors: {report['errors']}")
    return problems


def judge_mutation_report(mutation: dict, report: dict, exit_code: int) -> list[str]:
    problems: list[str] = []
    if exit_code == 0 or report.get("pass"):
        problems.append(f"{mutation['name']}: the probe passed although {mutation['entry']} was removed")
    pairs = {pair.get("key"): pair for pair in report.get("pairs", [])}
    for key in mutation["affected_keys"]:
        pair = pairs.get(key)
        if pair is None:
            problems.append(f"{mutation['name']}: {key} missing from the mutated report")
            continue
        if pair.get("pass"):
            problems.append(f"{mutation['name']}: {key} still passes")
        for field, expected in mutation["expect"].items():
            if pair.get(field) != expected:
                problems.append(f"{mutation['name']}: {key}.{field}={pair.get(field)!r}, expected {expected!r}")
    unaffected = [key for key, pair in pairs.items() if key not in mutation["affected_keys"] and not pair.get("pass")]
    if unaffected:
        problems.append(f"{mutation['name']}: unrelated pairs failed: {unaffected}")
    return problems


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ProbeError(f"{path} is not a PNG")
    return struct.unpack(">II", header[16:24])


def judge_captures(report: dict, capture_dir: Path) -> list[str]:
    problems: list[str] = []
    captures = report.get("captures", [])
    classes = set()
    for capture in captures:
        path = Path(str(capture.get("path", "")))
        if not capture.get("ok") or not path.is_file():
            problems.append(f"capture {capture.get('key')} failed: {capture.get('error')}")
            continue
        width, height = png_size(path)
        if width < 640 or height < 360:
            problems.append(f"capture {path.name} is only {width}x{height}")
        classes.add(str(capture.get("key")).split("/", 1)[0])
    if len(classes) != EXPECTED_CLASSES:
        problems.append(f"captures cover {len(classes)} classes, expected {EXPECTED_CLASSES}")
    if not any(capture_dir.glob("*.png")):
        problems.append(f"no PNG captures under {capture_dir}")
    return problems


def git_output(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


# --- main --------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--evidence-dir", type=Path, default=None, help="copy report, listing and captures here")
    parser.add_argument("--skip-export", action="store_true", help="reuse <output-dir>/export/FantasyDisk.app")
    parser.add_argument("--skip-import", action="store_true", help="do not warm the import cache before exporting")
    parser.add_argument("--skip-mutations", action="store_true")
    parser.add_argument("--captures", action="store_true", help="also run windowed and screenshot one weapon per class")
    parser.add_argument("--capture-all", action="store_true", help="screenshot all 51 pairs (implies --captures)")
    args = parser.parse_args(argv)
    if sys.platform != "darwin":
        print("ultimate_export_probe: the macOS preset export needs a macOS host", file=sys.stderr)
        return 2
    output_dir: Path = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    started = time.time()
    summary: dict = {
        "gate": "tools/ultimate_export_probe.py",
        "preset": PRESET,
        "source": {
            "commit": git_output("rev-parse", "HEAD"),
            "tree": git_output("rev-parse", "HEAD^{tree}"),
            "dirty_paths": [line for line in git_output("status", "--porcelain").splitlines()],
        },
        "problems": [],
    }
    problems: list[str] = summary["problems"]
    try:
        app = output_dir / "export" / APP_NAME if args.skip_export else export_app(output_dir, skip_import=args.skip_import)
        if not app.is_dir():
            raise ProbeError(f"exported app missing: {app}")
        binary = app_binary(app)
        pck = app_pck(app)
        summary["export"] = {"app": str(app), "binary": str(binary), "pck": str(pck), "pck_size": pck.stat().st_size, "pck_sha256": sha256_of(pck)}

        directory = read_pck_directory(pck)
        listing = pck_listing(directory)
        (output_dir / "pck_listing.json").write_text(json.dumps(listing, indent=2) + "\n", encoding="utf-8")
        (output_dir / "pck_entries.txt").write_text("\n".join(sorted(e["path"] for e in directory["entries"])) + "\n", encoding="utf-8")
        expected_documents = sorted(path.name for path in (ROOT / "data" / "ultimates" / "presentation").glob("*.json"))
        listed_documents = sorted(Path(e["path"]).name for e in listing["presentation_documents"])
        if listed_documents != expected_documents:
            problems.append(f"PCK presentation documents {listed_documents} != repository {expected_documents}")
        if listing["forbidden_entries"]:
            problems.append(f"PCK carries excluded trees: {listing['forbidden_entries'][:5]} (+{max(0, len(listing['forbidden_entries']) - 5)})")
        summary["pck"] = {k: v for k, v in listing.items() if k != "presentation_documents"}
        summary["pck"]["presentation_document_count"] = len(listed_documents)
        log(f"PCK format {listing['format_version']}, {listing['entry_count']} entries, {len(listed_documents)} presentation documents, forbidden entries: {len(listing['forbidden_entries'])}")

        scene = write_probe_scene(output_dir)
        probe_app = clone_app(app, output_dir / "probe" / APP_NAME)
        install_override(probe_app, scene)
        report_path = output_dir / "probe_report.json"
        result = run_probe(probe_app, report_path, output_dir / "probe.log", windowed=False, capture_dir=None)
        report = load_report(report_path)
        main_problems = judge_main_report(report, expected_documents)
        summary["headless_probe"] = {
            "exit_code": result.returncode,
            "report": str(report_path),
            "pairs": len(report.get("pairs", [])),
            "pairs_passing": sum(1 for pair in report.get("pairs", []) if pair.get("pass")),
            "problems": main_problems,
        }
        if result.returncode != 0:
            main_problems.append(f"headless probe exited {result.returncode}")
        problems.extend(main_problems)
        log(f"headless probe: {summary['headless_probe']['pairs_passing']}/{summary['headless_probe']['pairs']} pairs pass, exit {result.returncode}")

        summary["mutations"] = []
        if not args.skip_mutations:
            for mutation in MUTATIONS:
                mutated_app = clone_app(app, output_dir / "mutations" / mutation["name"] / APP_NAME)
                install_override(mutated_app, scene)
                rename_pck_entry(app_pck(mutated_app), mutation["entry"], mutation["renamed"])
                mutated_report_path = output_dir / "mutations" / mutation["name"] / "probe_report.json"
                mutated_result = run_probe(mutated_app, mutated_report_path, mutated_report_path.parent / "probe.log", windowed=False, capture_dir=None)
                mutated_report = load_report(mutated_report_path)
                mutation_problems = judge_mutation_report(mutation, mutated_report, mutated_result.returncode)
                summary["mutations"].append({
                    "name": mutation["name"],
                    "removed_entry": mutation["entry"],
                    "exit_code": mutated_result.returncode,
                    "report": str(mutated_report_path),
                    "pairs_passing": sum(1 for pair in mutated_report.get("pairs", []) if pair.get("pass")),
                    "affected": {key: {field: pair.get(field) for field in ("resolution_source", "record_found", "begin_ok", "pass")}
                                 for pair in mutated_report.get("pairs", []) for key in [pair.get("key")] if key in mutation["affected_keys"]},
                    "problems": mutation_problems,
                })
                problems.extend(mutation_problems)
                log(f"mutation {mutation['name']}: exit {mutated_result.returncode}, {summary['mutations'][-1]['pairs_passing']} pairs pass, problems {len(mutation_problems)}")

        if args.captures or args.capture_all:
            capture_dir = output_dir / "captures"
            if capture_dir.exists():
                shutil.rmtree(capture_dir)
            capture_dir.mkdir(parents=True)
            capture_report_path = output_dir / "capture_report.json"
            capture_result = run_probe(probe_app, capture_report_path, output_dir / "capture.log", windowed=True, capture_dir=capture_dir)
            capture_report = load_report(capture_report_path)
            capture_problems = judge_main_report(capture_report, expected_documents) + judge_captures(capture_report, capture_dir)
            if capture_result.returncode != 0:
                capture_problems.append(f"windowed probe exited {capture_result.returncode}")
            summary["captures"] = {
                "exit_code": capture_result.returncode,
                "report": str(capture_report_path),
                "directory": str(capture_dir),
                "files": sorted(path.name for path in capture_dir.glob("*.png")),
                "problems": capture_problems,
            }
            problems.extend(capture_problems)
            log(f"captures: {len(summary['captures']['files'])} PNGs, exit {capture_result.returncode}, problems {len(capture_problems)}")
    except (ProbeError, subprocess.TimeoutExpired, OSError, json.JSONDecodeError) as exc:
        problems.append(f"{type(exc).__name__}: {exc}")

    summary["pass"] = not problems
    summary["duration_seconds"] = round(time.time() - started, 1)
    summary_path = output_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    if args.evidence_dir is not None:
        evidence = args.evidence_dir if args.evidence_dir.is_absolute() else ROOT / args.evidence_dir
        evidence.mkdir(parents=True, exist_ok=True)
        for name in ("summary.json", "probe_report.json", "pck_listing.json", "probe.log"):
            source = output_dir / name
            if source.is_file():
                shutil.copy2(source, evidence / f"export_probe_{name}")
        for mutation in summary.get("mutations", []):
            report_file = Path(mutation["report"])
            if report_file.is_file():
                shutil.copy2(report_file, evidence / f"export_probe_mutation_{mutation['name']}.json")
        if "captures" in summary:
            capture_evidence = evidence / "exported_app_captures"
            capture_evidence.mkdir(exist_ok=True)
            for name in summary["captures"]["files"]:
                shutil.copy2(output_dir / "captures" / name, capture_evidence / name)
            capture_report_file = output_dir / "capture_report.json"
            if capture_report_file.is_file():
                shutil.copy2(capture_report_file, evidence / "export_probe_capture_report.json")
        log(f"evidence copied to {evidence}")

    for problem in problems:
        print(f"ultimate_export_probe: FAIL {problem}", file=sys.stderr)
    log(f"{'PASS' if summary['pass'] else 'FAIL'} in {summary['duration_seconds']}s; summary {summary_path}")
    return 0 if summary["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
