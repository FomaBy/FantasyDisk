from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import sys


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import check_gdscript_contracts as contracts


class GDScriptContractTest(unittest.TestCase):
    def write(self, root: Path, relative: str, source: str) -> None:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")

    def spec(self, *, facade: str = "facade.gd", module_directory: str = "modules") -> contracts.ChainSpec:
        return contracts.ChainSpec(
            name="fixture",
            facade=facade,
            module_directory=module_directory,
            forward_api=f"{module_directory}/shared_api.gd",
            terminal_base="RefCounted",
            facade_class_name="Facade",
        )

    def errors(self, root: Path, spec: contracts.ChainSpec | None = None) -> list[str]:
        return contracts._contract_errors_for_spec(root, spec or self.spec())

    def write_valid_chain(self, root: Path, override: str | None = None) -> None:
        self.write(
            root,
            "modules/base.gd",
            "# a comment with func hidden() -> void:\n"
            "@tool\n"
            "class_name Base\n"
            "extends RefCounted\n"
            "static func utility(value: Array[Dictionary] := [{\"x\": 1}]) -> Array[Dictionary]:\n"
            "\treturn value\n",
        )
        self.write(
            root,
            "modules/shared_api.gd",
            "extends \"res://modules/base.gd\"\n"
            "@warning_ignore(\"unused_parameter\")\n"
            "func required(\n"
            "\tvalue: Dictionary = {\n"
            "\t\t\"nested\": [1, 2],\n"
            "\t},\n"
            ") -> Dictionary:\n"
            "\treturn {}\n",
        )
        self.write(
            root,
            "modules/implementation.gd",
            "extends \"res://modules/shared_api.gd\"\n"
            + (override if override is not None else "func required(value: Dictionary = {\"nested\": [1, 2]}) -> Dictionary:\n\treturn value\n"),
        )
        self.write(
            root,
            "facade.gd",
            "class_name Facade\n"
            "extends \"res://modules/implementation.gd\"\n",
        )

    def test_current_checkout_contracts_pass(self):
        self.assertEqual(contracts.contract_errors(ROOT), [])

    def test_parser_accepts_comments_annotations_multiline_defaults_and_static_methods(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root)

            script = contracts.parse_script(root / "modules/shared_api.gd", root)
            base = contracts.parse_script(root / "modules/base.gd", root)

            self.assertEqual(script.functions[0].annotations, ("warning_ignore",))
            self.assertEqual(script.functions[0].parameters[0].type_name, "Dictionary")
            self.assertTrue(script.functions[0].parameters[0].has_default)
            self.assertTrue(base.functions[0].is_static)
            self.assertTrue(base.functions[0].parameters[0].has_default)
            self.assertEqual(self.errors(root), [])

    def test_missing_required_override_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root, override="func unrelated() -> void:\n\tpass\n")

            self.assertTrue(
                any("forward API method required has no required downstream override" in error for error in self.errors(root))
            )

    def test_incompatible_signature_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root, override="func required(value: String) -> Dictionary:\n\treturn {}\n")

            self.assertTrue(any("incompatible signature for required" in error for error in self.errors(root)))

    def test_missing_path_and_unresolved_named_base_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write(root, "modules/shared_api.gd", "extends \"res://modules/missing.gd\"\nfunc required() -> void:\n\tpass\n")
            self.write(root, "facade.gd", "class_name Facade\nextends \"res://modules/shared_api.gd\"\n")
            self.assertTrue(any("unresolved base" in error for error in self.errors(root)))

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write(root, "modules/shared_api.gd", "extends UnknownBase\nfunc required() -> void:\n\tpass\n")
            self.write(root, "facade.gd", "class_name Facade\nextends \"res://modules/shared_api.gd\"\n")
            self.assertTrue(any("unresolved base 'UnknownBase'" in error for error in self.errors(root)))

    def test_cycle_and_unsupported_extends_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write(root, "modules/shared_api.gd", "extends \"res://modules/implementation.gd\"\nfunc required() -> void:\n\tpass\n")
            self.write(root, "modules/implementation.gd", "extends \"res://modules/shared_api.gd\"\nfunc required() -> void:\n\tpass\n")
            self.write(root, "facade.gd", "class_name Facade\nextends \"res://modules/implementation.gd\"\n")
            self.assertTrue(any("inheritance cycle" in error for error in self.errors(root)))

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write(root, "modules/shared_api.gd", "extends preload(\"res://base.gd\")\nfunc required() -> void:\n\tpass\n")
            self.write(root, "facade.gd", "class_name Facade\nextends \"res://modules/shared_api.gd\"\n")
            self.assertTrue(any("unsupported extends target" in error for error in self.errors(root)))

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write(root, "modules/shared_api.gd", "extends RefCounted\nfunc required[T]() -> void:\n\tpass\n")
            self.write(root, "facade.gd", "class_name Facade\nextends \"res://modules/shared_api.gd\"\n")
            self.assertTrue(any("unsupported function declaration" in error for error in self.errors(root)))

    def test_virtual_override_is_valid_but_accidental_sibling_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root)
            self.assertEqual(self.errors(root), [])
            self.write(
                root,
                "modules/accidental_sibling.gd",
                "extends \"res://modules/shared_api.gd\"\nfunc required(value: Dictionary = {}) -> Dictionary:\n\treturn value\n",
            )

            self.assertTrue(any("accidental sibling" in error for error in self.errors(root)))


if __name__ == "__main__":
    unittest.main()
