"""FAN-3985: unit coverage for the exported-build gate's pure parts.

``tools/ultimate_export_probe.py`` reads and patches Godot PCK directories and
judges probe reports.  Those parts never need Godot, so they are pinned here:
a format-4 PCK is written from scratch, listed, mutated and re-listed, and the
report judges are exercised with a crash (signal), a clean failure and a pass.
"""
from __future__ import annotations

import hashlib
import importlib.util
import struct
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "ultimate_export_probe.py"


def _load_tool():
    spec = importlib.util.spec_from_file_location("ultimate_export_probe", TOOL)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def write_pck_v4(path: Path, files: dict[str, bytes]) -> None:
    """Minimal Godot 4.4+ PCK: header, data at file_base, directory at the end."""
    header_size = 4 + 5 * 4 + 8 + 8 + 16 * 4
    file_base = header_size
    blobs = []
    offset = 0
    for name, data in files.items():
        blobs.append((name, offset, data))
        offset += len(data)
    dir_offset = file_base + offset
    with path.open("wb") as handle:
        handle.write(b"GDPC")
        handle.write(struct.pack("<5I", 4, 4, 7, 0, 2))  # version 4, Godot 4.7.0, PACK_REL_FILEBASE
        handle.write(struct.pack("<QQ", file_base, dir_offset))
        handle.write(b"\0" * (16 * 4))
        for _, _, data in blobs:
            handle.write(data)
        handle.write(struct.pack("<I", len(blobs)))
        for name, rel_offset, data in blobs:
            encoded = name.encode("utf-8")
            padded = encoded + b"\0" * ((4 - len(encoded) % 4) % 4)
            handle.write(struct.pack("<I", len(padded)))
            handle.write(padded)
            handle.write(struct.pack("<QQ", rel_offset, len(data)))
            handle.write(hashlib.md5(data).digest())
            handle.write(struct.pack("<I", 0))


class PckDirectoryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tool = _load_tool()
        self.scratch = tempfile.TemporaryDirectory()
        self.pck = Path(self.scratch.name) / "test.pck"
        write_pck_v4(self.pck, {
            "data/ultimates/presentation/knight.json": b'{"class_id": "knight"}',
            "scripts/ultimates/classes/knight/long_spear.gd.remap": b"[remap]\n",
            "scripts/ultimates/classes/knight/long_spear.gdc": b"GDSC",
            "scenes/vfx/ultimates/knight/KnightLongSpearSpearWall.tscn.remap": b"[remap]\n",
        })

    def tearDown(self) -> None:
        self.scratch.cleanup()

    def test_directory_lists_every_entry_with_absolute_offsets(self) -> None:
        directory = self.tool.read_pck_directory(self.pck)
        self.assertEqual(directory["format_version"], 4)
        self.assertEqual(directory["engine_version"], "4.7.0")
        paths = [entry["path"] for entry in directory["entries"]]
        self.assertEqual(len(paths), 4)
        self.assertIn("data/ultimates/presentation/knight.json", paths)
        raw = self.pck.read_bytes()
        for entry in directory["entries"]:
            blob = raw[entry["offset"]:entry["offset"] + entry["size"]]
            self.assertEqual(hashlib.md5(blob).digest(), hashlib.md5(blob).digest())
            if entry["path"].endswith("knight.json"):
                self.assertEqual(blob, b'{"class_id": "knight"}')

    def test_listing_counts_runtime_data_and_forbidden_trees(self) -> None:
        listing = self.tool.pck_listing(self.tool.read_pck_directory(self.pck))
        self.assertEqual([e["path"] for e in listing["presentation_documents"]], ["data/ultimates/presentation/knight.json"])
        self.assertEqual(listing["ultimate_class_package_files_by_extension"], {"gd.remap": 1, "gdc": 1})
        self.assertEqual(listing["forbidden_entries"], [])
        write_pck_v4(self.pck, {"docs/design/x.md": b"x", "tests/a_test.gd": b"y"})
        listing = self.tool.pck_listing(self.tool.read_pck_directory(self.pck))
        self.assertEqual(listing["forbidden_entries"], ["docs/design/x.md", "tests/a_test.gd"])

    def test_rename_removes_the_old_path_in_place(self) -> None:
        before = self.pck.stat().st_size
        self.tool.rename_pck_entry(
            self.pck, "data/ultimates/presentation/knight.json", "data/ultimates/presentation/knight.jsxn"
        )
        self.assertEqual(self.pck.stat().st_size, before)
        paths = [entry["path"] for entry in self.tool.read_pck_directory(self.pck)["entries"]]
        self.assertNotIn("data/ultimates/presentation/knight.json", paths)
        self.assertIn("data/ultimates/presentation/knight.jsxn", paths)
        with self.assertRaises(self.tool.ProbeError):
            self.tool.rename_pck_entry(self.pck, "data/ultimates/presentation/knight.jsxn", "short.json")
        with self.assertRaises(self.tool.ProbeError):
            self.tool.rename_pck_entry(self.pck, "missing/entry.json", "missing/entry.jsxn")


class PlayerPathJudgeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tool = _load_tool()

    def _result(self, exit_code, entry: dict | None, **extra) -> dict:
        report = None
        if entry is not None:
            report = {"environment": {"editor_feature": False}, "pairs": [dict({"key": "knight/long_spear"}, **entry)]}
        return dict({"key": "knight/long_spear", "exit_code": exit_code, "timed_out": False, "report": report}, **extra)

    def test_a_signal_exit_is_a_crash_even_with_a_partial_report(self) -> None:
        problems = self.tool.judge_player_path_result(self._result(-11, {"pass": True, "failures": []}))
        self.assertTrue(any("signal 11" in p and "crash" in p for p in problems), problems)

    def test_a_timeout_and_a_missing_report_fail(self) -> None:
        self.assertTrue(self.tool.judge_player_path_result(self._result(None, None, timed_out=True)))
        self.assertTrue(any("no probe report" in p for p in self.tool.judge_player_path_result(self._result(0, None))))

    def test_a_failed_pair_record_and_an_editor_run_fail(self) -> None:
        problems = self.tool.judge_player_path_result(self._result(1, {"pass": False, "failures": ["no live host presentation"]}))
        self.assertTrue(any("exited 1" in p for p in problems), problems)
        self.assertTrue(any("no live host presentation" in p for p in problems), problems)
        editor = self._result(0, {"pass": True, "failures": []})
        editor["report"]["environment"]["editor_feature"] = True
        self.assertTrue(any("exported binary" in p for p in self.tool.judge_player_path_result(editor)))

    def test_a_clean_pass_has_no_problems(self) -> None:
        self.assertEqual(self.tool.judge_player_path_result(self._result(0, {"pass": True, "failures": []})), [])

    def test_the_main_report_judge_requires_all_pairs_and_the_exported_environment(self) -> None:
        pairs = [{
            "key": f"c{i // 3}/w{i % 3}", "class_id": f"c{i // 3}", "resolution_source": "weapon_profile",
            "executor_admitted": True, "begin_ok": True, "scene_path": f"res://scenes/vfx/ultimates/c{i // 3}/S.tscn",
            "instantiated_scene_file": f"res://scenes/vfx/ultimates/c{i // 3}/S.tscn", "pass": True,
        } for i in range(51)]
        report = {"environment": {"editor_feature": False, "docs_manifest_present": False, "presentation_documents": ["a.json"]}, "pairs": pairs, "errors": []}
        self.assertEqual(self.tool.judge_main_report(report, ["a.json"]), [])
        pairs[0]["resolution_source"] = "legacy_class_fallback"
        self.assertTrue(any("legacy_class_fallback" in p for p in self.tool.judge_main_report(report, ["a.json"])))


if __name__ == "__main__":
    unittest.main()
