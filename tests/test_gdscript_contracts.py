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

    def spec(
        self,
        *,
        facade: str = "facade.gd",
        module_directory: str = "modules",
        composed_directory: str | None = None,
    ) -> contracts.ChainSpec:
        return contracts.ChainSpec(
            name="fixture",
            facade=facade,
            module_directory=module_directory,
            forward_api=f"{module_directory}/shared_api.gd",
            terminal_base="RefCounted",
            facade_class_name="Facade",
            composed_directory=composed_directory,
        )

    def composed_spec(self) -> contracts.ChainSpec:
        return self.spec(composed_directory="modules/executors")

    # A composed helper that reuses a forward-API method name: legitimate on a
    # separate object, so it must count neither as an override nor as a duplicate.
    HELPER = (
        "extends RefCounted\n"
        "var _context\n"
        "func _init(context) -> void:\n"
        "\t_context = context\n"
        "func required(value: Dictionary = {}) -> Dictionary:\n"
        "\treturn value\n"
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

    # --- FAN-3926: composed collaborators under <module_directory>/executors ---

    def test_composed_refcounted_collaborator_is_accepted_and_stays_off_the_chain(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root)
            self.write(root, "modules/executors/helper.gd", self.HELPER)
            self.write(root, "modules/executors/nested/context.gd", "extends RefCounted\nvar _weapon\n")

            self.assertEqual(self.errors(root, self.composed_spec()), [])
            scripts = contracts._scripts_for_spec(root, self.composed_spec())
            chain = contracts._resolve_chain(self.composed_spec(), scripts)
            self.assertEqual(
                chain,
                ["facade.gd", "modules/implementation.gd", "modules/shared_api.gd", "modules/base.gd"],
            )
            # A spec without a composed directory keeps the strict rule: the same
            # helper is an accidental sibling for it.
            self.assertTrue(
                any("modules/executors/helper.gd is an accidental sibling" in error for error in self.errors(root))
            )

    def test_inherited_sibling_is_rejected_inside_and_outside_the_composed_directory(self):
        for extends in (
            "extends \"res://modules/shared_api.gd\"",
            "extends \"res://facade.gd\"",
            "extends Base",
        ):
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                self.write_valid_chain(root)
                self.write(root, "modules/executors/helper.gd", f"{extends}\nfunc helper() -> void:\n\tpass\n")
                errors = self.errors(root, self.composed_spec())
                self.assertTrue(
                    any("modules/executors/helper.gd is an accidental sibling" in error for error in errors),
                    (extends, errors),
                )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root)
            self.write(root, "modules/executors/helper.gd", self.HELPER)
            self.write(root, "modules/stray.gd", "extends \"res://modules/shared_api.gd\"\n")
            errors = self.errors(root, self.composed_spec())
            self.assertTrue(any("modules/stray.gd is an accidental sibling" in error for error in errors), errors)
            self.assertFalse(any("helper.gd" in error for error in errors), errors)

    def test_composed_collaborator_pulled_onto_the_chain_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root)
            self.write(root, "modules/executors/helper.gd", "extends RefCounted\n")
            self.write(root, "modules/base.gd", "class_name Base\nextends \"res://modules/executors/helper.gd\"\n")
            errors = self.errors(root, self.composed_spec())
            self.assertTrue(
                any("modules/executors/helper.gd is a composed collaborator but sits on the facade chain" in error for error in errors),
                errors,
            )

    def test_composed_collaborator_with_missing_wrong_or_malformed_base_fails_closed(self):
        cases = {
            "func helper() -> void:\n\tpass\n": "composed collaborator without an extends declaration",
            "extends Node\n": "must extend RefCounted, found Node",
            "extends UnknownBase\n": "unresolved base 'UnknownBase'",
            "extends preload(\"res://modules/base.gd\")\n": "unsupported extends target",
            "extends \"res://modules/executors/missing.gd\"\n": "accidental sibling",
        }
        for source, expected in cases.items():
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                self.write_valid_chain(root)
                self.write(root, "modules/executors/helper.gd", source)
                errors = self.errors(root, self.composed_spec())
                self.assertTrue(any(expected in error for error in errors), (source, errors))

    def test_composed_collaborator_parse_errors_and_class_name_collisions_fail_closed(self):
        cases = {
            "extends RefCounted\nfunc broken[T]() -> void:\n\tpass\n": "unsupported function declaration",
            "extends RefCounted\nfunc twice() -> void:\n\tpass\nfunc twice() -> void:\n\tpass\n": "duplicate function declaration",
            "class_name Base\nextends RefCounted\n": "class_name 'Base' is declared by both",
        }
        for source, expected in cases.items():
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                self.write_valid_chain(root)
                self.write(root, "modules/executors/helper.gd", source)
                errors = self.errors(root, self.composed_spec())
                self.assertTrue(any(expected in error for error in errors), (source, errors))

    def test_chain_checks_survive_a_composed_collaborator(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root, override="func unrelated() -> void:\n\tpass\n")
            self.write(root, "modules/executors/helper.gd", self.HELPER)
            errors = self.errors(root, self.composed_spec())
            self.assertTrue(
                any("forward API method required has no required downstream override" in error for error in errors),
                errors,
            )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root, override="func required(value: String) -> Dictionary:\n\treturn {}\n")
            self.write(root, "modules/executors/helper.gd", self.HELPER)
            self.assertTrue(any("incompatible signature for required" in error for error in self.errors(root, self.composed_spec())))
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.write_valid_chain(root)
            self.write(root, "modules/executors/helper.gd", self.HELPER)
            self.write(root, "modules/base.gd", "class_name Base\nextends \"res://modules/implementation.gd\"\n")
            self.assertTrue(any("inheritance cycle" in error for error in self.errors(root, self.composed_spec())))

    def test_class_weapon_spec_composes_executors_and_ui_spec_stays_strict(self):
        by_name = {spec.name: spec for spec in contracts.CHAIN_SPECS}
        self.assertEqual(by_name["class_weapon"].composed_directory, "scripts/classes/executors")
        self.assertEqual(by_name["class_weapon"].composed_base, "RefCounted")
        self.assertIsNone(by_name["ui_screens"].composed_directory)


if __name__ == "__main__":
    unittest.main()
