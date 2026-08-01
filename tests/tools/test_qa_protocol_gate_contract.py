"""Keep the QA protocol's gate evidence names tied to the gate implementation."""
from __future__ import annotations

import ast
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROTOCOL = ROOT / "docs" / "process" / "qa_protocol.md"
QUALITY_GATE = ROOT / "tools" / "quality_gate.py"


def _between(text: str, start: str, end: str) -> str:
    """Return a documented contract block, rejecting an unmarked rewrite."""
    start_index = text.find(start)
    if start_index == -1:
        raise AssertionError(f"missing protocol marker: {start!r}")
    end_index = text.find(end, start_index + len(start))
    if end_index == -1:
        raise AssertionError(f"missing protocol marker: {end!r}")
    return text[start_index + len(start):end_index]


def _bullet_code_values(text: str) -> set[str]:
    """Read only inline-code labels from the protocol's contract bullet lists."""
    values = set()
    for line in text.splitlines():
        if line.startswith("- `"):
            _, separator, remainder = line.partition("`")
            value, closing, _ = remainder.partition("`")
            if separator and closing:
                values.add(value)
    return values


def _gate_evidence_section() -> str:
    protocol = PROTOCOL.read_text(encoding="utf-8")
    return _between(protocol, "## Gate evidence contract\n", "\n## Runtime safety")


def _quality_gate_tree() -> ast.Module:
    return ast.parse(QUALITY_GATE.read_text(encoding="utf-8"), filename=str(QUALITY_GATE))


def _string_dict_value(node: ast.Dict, key: str) -> str:
    for candidate_key, value in zip(node.keys, node.values):
        if isinstance(candidate_key, ast.Constant) and candidate_key.value == key:
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                return value.value
            raise AssertionError(f"quality_gate.py field {key!r} must be a string literal")
    raise AssertionError(f"quality_gate.py dictionary is missing {key!r}")


def _quality_gate_function(tree: ast.Module, name: str) -> ast.FunctionDef:
    matches = [
        node
        for node in tree.body
        if isinstance(node, ast.FunctionDef) and node.name == name
    ]
    if len(matches) != 1:
        raise AssertionError(f"expected one quality_gate.py function {name!r}, got {len(matches)}")
    return matches[0]


def _discovery_check_name(tree: ast.Module) -> str:
    required_fields = {
        "errors",
        "discovered_godot_tests",
        "selected_godot_tests",
        "discovered_python_tests",
    }
    matches = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Dict):
            continue
        keys = {
            key.value
            for key in node.keys
            if isinstance(key, ast.Constant) and isinstance(key.value, str)
        }
        if required_fields <= keys:
            matches.append(node)
    if len(matches) != 1:
        raise AssertionError(
            "expected one discovery evidence record in quality_gate.py, "
            f"got {len(matches)}"
        )
    return _string_dict_value(matches[0], "name")


def _relative_root_template(expression: ast.JoinedStr) -> str:
    parts = []
    for value in expression.values:
        if isinstance(value, ast.Constant) and isinstance(value.value, str):
            parts.append(value.value)
        elif isinstance(value, ast.FormattedValue) and isinstance(value.value, ast.Name):
            if value.value.id != "relative":
                raise AssertionError("python-unit template must format the relative discovery root")
            parts.append("<root-relative dir>")
        else:
            raise AssertionError("python-unit template has an unsupported dynamic component")
    return "".join(parts)


def _python_unit_check_names(tree: ast.Module) -> set[str]:
    function = _quality_gate_function(tree, "python_unit_commands")
    assignments = [
        node
        for node in ast.walk(function)
        if isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == "name" for target in node.targets)
    ]
    if len(assignments) != 1 or not isinstance(assignments[0].value, ast.IfExp):
        raise AssertionError("python_unit_commands must define one conditional check name")

    expression = assignments[0].value
    if not isinstance(expression.body, ast.Constant) or not isinstance(expression.body.value, str):
        raise AssertionError("python-unit root check name must be a string literal")
    if not isinstance(expression.orelse, ast.JoinedStr):
        raise AssertionError("nested python-unit check name must be an f-string")
    return {expression.body.value, _relative_root_template(expression.orelse)}


def _report_keys(tree: ast.Module) -> set[str]:
    anchors = {"git_sha", "static_checks", "godot_tests"}
    matches = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Dict):
            continue
        keys = {
            key.value
            for key in node.keys
            if isinstance(key, ast.Constant) and isinstance(key.value, str)
        }
        if anchors <= keys:
            matches.append(keys)
    if len(matches) != 1:
        raise AssertionError(f"expected one quality gate report payload, got {len(matches)}")
    return matches[0]


def _assert_same_contract(
    testcase: unittest.TestCase,
    label: str,
    documented: set[str],
    implemented: set[str],
) -> None:
    missing = implemented - documented
    unexpected = documented - implemented
    testcase.assertFalse(missing, f"qa_protocol.md is missing {label}: {sorted(missing)}")
    testcase.assertFalse(
        unexpected,
        f"qa_protocol.md names {label} absent from quality_gate.py: {sorted(unexpected)}",
    )


class QaProtocolGateContractTests(unittest.TestCase):
    def test_documented_check_names_match_quality_gate(self) -> None:
        section = _gate_evidence_section()
        documented = _bullet_code_values(
            _between(section, "names, not the exit code:\n", "\nThe gate emits no other names")
        )
        tree = _quality_gate_tree()
        implemented = {_discovery_check_name(tree), *_python_unit_check_names(tree)}
        _assert_same_contract(self, "quality-gate check names", documented, implemented)

    def test_documented_report_keys_exist_in_quality_gate(self) -> None:
        section = _gate_evidence_section()
        documented = _bullet_code_values(
            _between(
                section,
                "Confirm execution in\n`build/quality_gate_report.json`:\n",
                "\n\n",
            )
        )
        missing = documented - _report_keys(_quality_gate_tree())
        self.assertFalse(
            missing,
            f"qa_protocol.md names report keys absent from quality_gate.py: {sorted(missing)}",
        )


if __name__ == "__main__":
    unittest.main()
