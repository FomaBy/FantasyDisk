from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TESTS_DIR = ROOT / "tests"
RUNTIME_SMOKE_SUITE = "runtime_smoke_test.gd"
EXPECTED_RUNTIME_SMOKE_DESCENDANTS = frozenset(
    {
        "dev_console_smoke_test.gd",
        "dev_console_win_flow_test.gd",
        "gamepad_combat_actions_test.gd",
        "gamepad_full_flow_smoke_test.gd",
        "gamepad_inrun_ui_test.gd",
        "gamepad_menu_focus_test.gd",
        "gamepad_settings_rebind_test.gd",
        "main_menu_title_no_overlap_test.gd",
        "route_elite_invariant_test.gd",
        "runtime_smoke_boss_elite_test.gd",
        "runtime_smoke_combat_test.gd",
        "runtime_smoke_progression_economy_test.gd",
        "runtime_smoke_triggered_artifacts_test.gd",
        "runtime_smoke_ui_test.gd",
        "runtime_smoke_weapon_mechanics_test.gd",
        "scrum1059_main_menu_single_column_test.gd",
        "scrum1093_main_menu_version_corner_test.gd",
        "scrum981_gold_menu_shell_test.gd",
        "scrum993_shop_gold_shell_test.gd",
    }
)

EXTENDS_TEST_RE = re.compile(
    r'^\s*extends\s+["\']res://tests/(?P<parent>[^"\']+\.gd)["\']',
    re.MULTILINE,
)
SUCCESS_QUIT_RE = re.compile(
    r"(?<![\w.])(?:(?:self|get_tree\s*\(\s*\))\s*\.\s*)?"
    r"quit\s*\(\s*(?:0\s*)?\)",
)
FINISH_CALL_RE = re.compile(r"^[ \t]*_finish\s*\(", re.MULTILINE)


def _test_inheritance() -> dict[str, str]:
    inheritance: dict[str, str] = {}
    for path in TESTS_DIR.rglob("*.gd"):
        source = path.read_text(encoding="utf-8")
        match = EXTENDS_TEST_RE.search(source)
        if match is not None:
            inheritance[path.relative_to(TESTS_DIR).as_posix()] = match.group("parent")
    return inheritance


def _inherits_from(
    child: str,
    ancestor: str,
    inheritance: dict[str, str],
) -> bool:
    visited: set[str] = set()
    current = child
    while current in inheritance and current not in visited:
        visited.add(current)
        current = inheritance[current]
        if current == ancestor:
            return True
    return False


def _runtime_smoke_descendants() -> list[str]:
    inheritance = _test_inheritance()
    return sorted(
        child
        for child in inheritance
        if _inherits_from(child, RUNTIME_SMOKE_SUITE, inheritance)
    )


def _mask_strings_and_comments(source: str) -> str:
    masked: list[str] = []
    index = 0
    quote = ""
    triple = False
    while index < len(source):
        if quote:
            delimiter = quote * (3 if triple else 1)
            if source.startswith(delimiter, index):
                masked.extend(" " for _ in delimiter)
                index += len(delimiter)
                quote = ""
                triple = False
                continue
            character = source[index]
            if not triple and character == "\\" and index + 1 < len(source):
                masked.append(" ")
                masked.append("\n" if source[index + 1] == "\n" else " ")
                index += 2
                continue
            masked.append("\n" if character == "\n" else " ")
            index += 1
            continue

        character = source[index]
        if character == "#":
            while index < len(source) and source[index] != "\n":
                masked.append(" ")
                index += 1
            continue
        if character in {'"', "'"}:
            triple = source.startswith(character * 3, index)
            quote = character
            delimiter_length = 3 if triple else 1
            masked.extend(" " for _ in range(delimiter_length))
            index += delimiter_length
            continue
        masked.append(character)
        index += 1
    return "".join(masked)


def _successful_quit_calls(source: str) -> list[tuple[int, str]]:
    masked = _mask_strings_and_comments(source)
    return [
        (masked.count("\n", 0, match.start()) + 1, match.group(0))
        for match in SUCCESS_QUIT_RE.finditer(masked)
    ]


class GodotSuiteExitContractTests(unittest.TestCase):
    def test_runtime_smoke_descendant_inventory_is_complete(self) -> None:
        self.assertEqual(
            EXPECTED_RUNTIME_SMOKE_DESCENDANTS,
            frozenset(_runtime_smoke_descendants()),
            "The runtime_smoke inheritance inventory changed. Review every new or "
            "removed descendant before updating this contract.",
        )

    def test_successful_quit_detector_ignores_non_executable_text_and_failures(self) -> None:
        sample = '''
# quit()
var text := """quit(0)"""
quit(1)
if legacy:
    self.quit(0)
get_tree().quit()
'''
        self.assertEqual(
            [(6, "self.quit(0)"), (7, "get_tree().quit()")],
            _successful_quit_calls(sample),
        )

    def test_runtime_smoke_descendants_use_failure_aware_success_exit(self) -> None:
        descendants = _runtime_smoke_descendants()

        violations: list[str] = []
        for relative_path in descendants:
            source = (TESTS_DIR / relative_path).read_text(encoding="utf-8")
            for line, call in _successful_quit_calls(source):
                violations.append(
                    f"{relative_path}:{line} calls {call.strip()} directly"
                )
            if FINISH_CALL_RE.search(_mask_strings_and_comments(source)) is None:
                violations.append(
                    f"{relative_path} has no _finish(...) success exit"
                )

        self.assertEqual(
            [],
            violations,
            "runtime_smoke descendants must delegate every successful exit to "
            "_finish(...), which re-checks the sticky failure flag:\n"
            + "\n".join(violations),
        )


if __name__ == "__main__":
    unittest.main()
