"""FAN-3985: the exported weapon-ultimate presentation data and its export safety.

The 0.3.1 macOS/Windows builds shipped without the new weapon ultimate
presentations: the runtime read the class reference manifests under
``docs/design/references/weapon_ultimates/`` and both export presets exclude
``docs/*``.  The runtime now reads derived documents under
``data/ultimates/presentation/<class>.json`` that
``tools/build_ultimate_presentation_runtime_data.py`` generates from the
authored manifests.  This suite keeps the two from drifting and keeps every
runtime-read path out of the export exclusions.
"""
from __future__ import annotations

import importlib.util
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "build_ultimate_presentation_runtime_data.py"
EXPORT_PRESETS = ROOT / "export_presets.cfg"
PRESET_NAMES = ("macOS", "Windows Desktop")
EXPECTED_CLASS_COUNT = 17
EXPECTED_WEAPON_COUNT = 51

# ``res://`` roots and files the exported game reads at runtime for the weapon
# ultimate system.  The Godot-side gate (``tests/ultimates/
# export_runtime_paths_test.gd``) derives the same set from the script
# constants; this Python copy keeps the check in the Python unit gate, which
# runs in every quality profile.
RUNTIME_READ_ROOTS = (
    "data/ultimates/presentation",
    "data/ultimates/classes",
    "data/ultimates/schema",
    "data/ultimates/presentation_schema",
    "data/ultimates/text",
    "scripts/ultimates",
    "scenes/vfx/ultimates",
    "assets/audio/sfx/sfx_hit_magic.ogg",
)


def _load_tool():
    spec = importlib.util.spec_from_file_location("build_ultimate_presentation_runtime_data", TOOL)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def _preset_blocks(text: str) -> dict[str, str]:
    blocks: dict[str, str] = {}
    for match in re.finditer(r"\[preset\.(\d+)\]\n(.*?)(?=\n\[preset\.|\Z)", text, re.S):
        body = match.group(2)
        name = re.search(r'^name="([^"]*)"', body, re.M)
        if name:
            blocks[name.group(1)] = body
    return blocks


def _exclude_filter(block: str) -> list[str]:
    match = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
    if not match:
        return []
    return [fragment.strip() for fragment in match.group(1).split(",") if fragment.strip()]


def _godot_match(text: str, pattern: str) -> bool:
    """Godot ``String.matchn``: ``*`` spans any characters (including ``/``), ``?`` one."""
    regex = "".join(".*" if ch == "*" else "." if ch == "?" else re.escape(ch) for ch in pattern)
    return re.fullmatch(regex, text, re.IGNORECASE) is not None


def excluded_by(path: str, fragments: list[str]) -> list[str]:
    """Export filters matching *path* the way the exporter tests them.

    ``EditorExportPlatform`` tests every filter against the ``res://`` path and
    against the path without the prefix, case-insensitively.
    """
    relative = path.removeprefix("res://")
    full = f"res://{relative}"
    return [f for f in fragments if _godot_match(full, f) or _godot_match(relative, f)]


def _runtime_files() -> list[str]:
    files: list[str] = []
    for root in RUNTIME_READ_ROOTS:
        path = ROOT / root
        if path.is_file():
            files.append(root)
            continue
        for child in sorted(path.rglob("*")):
            if child.is_file() and child.suffix not in {".uid", ".import"}:
                files.append(child.relative_to(ROOT).as_posix())
    return files


class RuntimePresentationDataTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tool = _load_tool()
        cls.rendered = cls.tool.build_all()

    def test_every_class_manifest_has_a_committed_runtime_document(self) -> None:
        self.assertEqual(len(self.rendered), EXPECTED_CLASS_COUNT)
        for class_id in self.rendered:
            path = self.tool.runtime_document_path(class_id)
            self.assertTrue(path.is_file(), f"missing {path.relative_to(ROOT).as_posix()}; run python3 {self.tool.GENERATOR}")

    def test_committed_runtime_documents_match_regeneration_byte_for_byte(self) -> None:
        problems = self.tool.stale_documents(self.rendered)
        self.assertEqual(problems, [], f"runtime documents drifted from the class manifests; run python3 {self.tool.GENERATOR}")

    def test_runtime_documents_carry_only_runtime_fields(self) -> None:
        allowed = set(self.tool.REQUIRED_WEAPON_FIELDS) | set(self.tool.OPTIONAL_WEAPON_FIELDS)
        weapons_seen = 0
        for class_id, text in self.rendered.items():
            document = json.loads(text)
            self.assertEqual(
                set(document), {"schema_version", "class_id", "generated_from", "generator", "weapons"},
                f"{class_id}: unexpected top-level keys",
            )
            self.assertEqual(document["class_id"], class_id)
            self.assertEqual(document["generator"], self.tool.GENERATOR)
            self.assertTrue((ROOT / document["generated_from"]).is_file())
            for weapon in document["weapons"]:
                weapons_seen += 1
                self.assertLessEqual(set(weapon), allowed, f"{class_id}/{weapon['weapon_id']}: non-runtime field leaked into the export")
                self.assertTrue((ROOT / weapon["scene_path"].removeprefix("res://")).is_file())
        self.assertEqual(weapons_seen, EXPECTED_WEAPON_COUNT)

    def test_runtime_documents_agree_with_the_authored_records(self) -> None:
        for class_id, text in self.rendered.items():
            document = json.loads(text)
            authored = json.loads((ROOT / document["generated_from"]).read_text(encoding="utf-8"))
            authored_by_id = {weapon["weapon_id"]: weapon for weapon in authored["weapons"]}
            self.assertEqual(list(authored_by_id), [weapon["weapon_id"] for weapon in document["weapons"]])
            for weapon in document["weapons"]:
                source = authored_by_id[weapon["weapon_id"]]
                for field, value in weapon.items():
                    expected = source[field]
                    if field == "scene_path":
                        # The generator normalises the authored path to `res://`.
                        expected = "res://" + str(expected).removeprefix("res://")
                    self.assertEqual(value, expected, f"{class_id}/{weapon['weapon_id']}.{field} differs from the authored manifest")

    def test_generator_rejects_a_manifest_without_a_scene(self) -> None:
        manifest_path = self.tool.REFERENCE_ROOT / "knight" / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["weapons"][0]["scene_path"] = "res://scenes/vfx/ultimates/knight/__missing__.tscn"
        with self.assertRaises(self.tool.RuntimeDataError):
            self.tool.build_document(manifest, manifest_path)
        del manifest["weapons"][0]["timing_seconds"]
        with self.assertRaises(self.tool.RuntimeDataError):
            self.tool.build_document(manifest, manifest_path)

    def test_stale_and_orphan_documents_are_reported(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as scratch:
            runtime_root = Path(scratch)
            self.tool.write_all(self.rendered, runtime_root)
            self.assertEqual(self.tool.stale_documents(self.rendered, runtime_root), [])
            (runtime_root / "knight.json").write_text("{}\n", encoding="utf-8")
            (runtime_root / "ghost.json").write_text("{}\n", encoding="utf-8")
            problems = self.tool.stale_documents(self.rendered, runtime_root)
            self.assertEqual(len(problems), 2, problems)
            self.assertTrue(any("stale" in problem and "knight.json" in problem for problem in problems), problems)
            self.assertTrue(any("orphan" in problem and "ghost.json" in problem for problem in problems), problems)


class RuntimePathsStayExportedTest(unittest.TestCase):
    """No runtime-read path may fall under an ``exclude_filter`` of either preset."""

    def setUp(self) -> None:
        self.presets = _preset_blocks(EXPORT_PRESETS.read_text(encoding="utf-8"))
        for name in PRESET_NAMES:
            self.assertIn(name, self.presets)

    def test_runtime_read_roots_exist(self) -> None:
        for root in RUNTIME_READ_ROOTS:
            self.assertTrue((ROOT / root).exists(), f"runtime-read path {root} does not exist")
        self.assertEqual(len(list((ROOT / "data/ultimates/presentation").glob("*.json"))), EXPECTED_CLASS_COUNT)

    def test_no_runtime_read_path_is_excluded_from_an_export(self) -> None:
        files = _runtime_files()
        self.assertGreater(len(files), EXPECTED_WEAPON_COUNT)
        for name in PRESET_NAMES:
            fragments = _exclude_filter(self.presets[name])
            self.assertTrue(fragments)
            for path in files:
                self.assertEqual(
                    excluded_by(path, fragments), [],
                    f"export preset {name!r} excludes the runtime-read path {path}",
                )

    def test_the_old_docs_location_is_excluded_and_unused_by_the_runtime(self) -> None:
        for name in PRESET_NAMES:
            fragments = _exclude_filter(self.presets[name])
            self.assertTrue(excluded_by("docs/design/references/weapon_ultimates/knight/manifest.json", fragments))
        # Evidence gates that only tests call may read the authored manifests;
        # contact-sheet renderers write their PNG evidence there; provenance
        # strings are metadata. Everything else under scripts/ and scenes/ runs
        # in the exported game and must not open the docs tree.
        evidence_only = {
            "scripts/ultimates/presentation/ultimate_visual_direction_contract.gd",
            "scripts/ultimates/presentation/contact_sheet_beats_contract.gd",
        }
        runtime_scripts = [
            path for path in (ROOT / "scripts").rglob("*.gd")
        ] + [path for path in (ROOT / "scenes").rglob("*.gd")]
        offenders = []
        for path in runtime_scripts:
            relative = path.relative_to(ROOT).as_posix()
            if relative in evidence_only:
                continue
            text = path.read_text(encoding="utf-8")
            for line in text.splitlines():
                stripped = line.strip()
                if stripped.startswith("#"):
                    continue
                if "res://docs/design/references/weapon_ultimates" in line and "OUTPUT_PATH" not in line \
                        and "source_directory" not in line:
                    offenders.append(f"{relative}: {stripped}")
        self.assertEqual(
            offenders, [],
            "runtime scripts must not read the docs manifests, which are excluded from every export",
        )

    def test_filter_matching_follows_the_exporter(self) -> None:
        self.assertEqual(excluded_by("docs/design/x.json", ["docs/*"]), ["docs/*"])
        self.assertEqual(excluded_by("res://docs/design/x.json", ["docs/*"]), ["docs/*"])
        self.assertEqual(excluded_by("data/docs/x.json", ["docs/*"]), [])
        self.assertEqual(excluded_by("README.md", ["*.md"]), ["*.md"])
        self.assertEqual(excluded_by("data/ultimates/presentation/knight.json", ["docs/*", "*.md", "tools/*"]), [])


if __name__ == "__main__":
    unittest.main()
