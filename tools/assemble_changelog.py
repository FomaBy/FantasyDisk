#!/usr/bin/env python3
"""Assemble the canonical changelog region from independently owned fragments.

Each fragment is a UTF-8 ``changelog.d/FAN-<number>.md`` file with exactly one
level-three section heading followed by Markdown bullets. The strict shape keeps
fragments additive: they can contribute entries but cannot replace a release
heading, escape the generated region, or silently duplicate another entry.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FRAGMENT_DIR = ROOT / "changelog.d"
DEFAULT_CHANGELOG_PATH = ROOT / "CHANGELOG.md"
BEGIN_MARKER = "<!-- BEGIN GENERATED CHANGELOG FRAGMENTS -->"
END_MARKER = "<!-- END GENERATED CHANGELOG FRAGMENTS -->"
FRAGMENT_NAME_RE = re.compile(r"^FAN-([1-9][0-9]*)\.md$")
SECTION_HEADING_RE = re.compile(r"^### ([^#\r\n].*?)$")
ANY_HEADING_RE = re.compile(r"^#{1,6}(?:\s|$)")


class FragmentError(ValueError):
    """Raised when an input fragment cannot be safely assembled."""


@dataclass(frozen=True)
class Fragment:
    identifier: str
    number: int
    section: str
    body_lines: tuple[str, ...]


def _error(path: Path, message: str) -> FragmentError:
    return FragmentError(f"{path.name}: {message}")


def _parse_fragment(path: Path) -> Fragment:
    name_match = FRAGMENT_NAME_RE.fullmatch(path.name)
    if name_match is None:
        raise _error(path, "filename must be FAN-<positive-number>.md")
    if path.is_symlink():
        raise _error(path, "symlinked fragments are not allowed")
    if not path.is_file():
        raise _error(path, "must be a regular file")

    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        raise _error(path, "must be valid UTF-8") from error

    if not text:
        raise _error(path, "must not be empty")
    if text.startswith("\ufeff"):
        raise _error(path, "must not contain a UTF-8 byte-order mark")
    if "\r" in text:
        raise _error(path, "must use LF line endings")
    if not text.endswith("\n"):
        raise _error(path, "must end with a newline")

    lines = text.splitlines()
    if not lines or not lines[0]:
        raise _error(path, "must start with a level-three section heading")
    for line_number, line in enumerate(lines, start=1):
        if line != line.rstrip():
            raise _error(path, f"line {line_number} has trailing whitespace")
        if BEGIN_MARKER in line or END_MARKER in line:
            raise _error(path, "must not contain generated-region markers")

    heading_match = SECTION_HEADING_RE.fullmatch(lines[0])
    if heading_match is None:
        raise _error(path, "must start with a level-three section heading")
    section = heading_match.group(1).strip()
    if not section:
        raise _error(path, "section heading must not be empty")

    body = list(lines[1:])
    while body and not body[0]:
        body.pop(0)
    while body and not body[-1]:
        body.pop()
    body_lines = tuple(body)
    saw_bullet = False
    for line_number, line in enumerate(body_lines, start=2):
        if not line:
            continue
        if line.startswith("- "):
            if not line[2:].strip():
                raise _error(path, f"line {line_number} has an empty bullet")
            saw_bullet = True
            continue
        if line.startswith("  "):
            if not saw_bullet:
                raise _error(path, f"line {line_number} continues no bullet")
            continue
        if ANY_HEADING_RE.match(line):
            raise _error(path, f"line {line_number} adds an unsupported heading")
        raise _error(
            path,
            f"line {line_number} must be a bullet or an indented bullet continuation",
        )
    if not saw_bullet:
        raise _error(path, "must contain at least one bullet")

    number = int(name_match.group(1))
    return Fragment(
        identifier=f"FAN-{number}",
        number=number,
        section=section,
        body_lines=body_lines,
    )


def load_fragments(fragment_dir: Path) -> list[Fragment]:
    """Load a complete, validated, and deterministically sorted fragment set."""
    if fragment_dir.is_symlink():
        raise FragmentError(f"{fragment_dir}: symlinked fragment directories are not allowed")
    if not fragment_dir.is_dir():
        raise FragmentError(f"{fragment_dir}: fragment directory does not exist")

    paths = sorted(
        (path for path in fragment_dir.iterdir() if path.suffix.lower() == ".md"),
        key=lambda path: path.name,
    )
    if not paths:
        raise FragmentError(f"{fragment_dir}: no changelog fragments found")

    fragments: list[Fragment] = []
    identifiers: dict[str, str] = {}
    contents: dict[tuple[str, tuple[str, ...]], str] = {}
    for path in paths:
        fragment = _parse_fragment(path)
        previous_identifier = identifiers.get(fragment.identifier)
        if previous_identifier is not None:
            raise _error(
                path,
                f"duplicates fragment ID {fragment.identifier} from {previous_identifier}",
            )
        identifiers[fragment.identifier] = path.name

        content_key = (fragment.section, fragment.body_lines)
        previous_content = contents.get(content_key)
        if previous_content is not None:
            raise _error(
                path,
                f"duplicates fragment content from {previous_content}",
            )
        contents[content_key] = path.name
        fragments.append(fragment)

    return sorted(
        fragments,
        key=lambda fragment: (
            fragment.section.casefold(),
            fragment.number,
            fragment.identifier,
        ),
    )


def render_fragment_region(fragments: list[Fragment]) -> str:
    """Render the exact generated region without relying on filesystem order."""
    by_section: dict[str, list[Fragment]] = {}
    for fragment in fragments:
        by_section.setdefault(fragment.section, []).append(fragment)

    lines = [BEGIN_MARKER]
    for section in sorted(by_section, key=str.casefold):
        lines.extend(("", f"### {section}", ""))
        for index, fragment in enumerate(by_section[section]):
            if index:
                lines.append("")
            lines.extend(fragment.body_lines)
    lines.extend(("", END_MARKER))
    return "\n".join(lines)


def replace_generated_region(changelog_text: str, generated_region: str) -> str:
    """Replace exactly one bounded generated region, failing closed otherwise."""
    begin_count = changelog_text.count(BEGIN_MARKER)
    end_count = changelog_text.count(END_MARKER)
    if begin_count != 1 or end_count != 1:
        raise FragmentError(
            "CHANGELOG.md must contain exactly one generated-region begin and end marker"
        )

    begin_index = changelog_text.index(BEGIN_MARKER)
    end_index = changelog_text.index(END_MARKER)
    if end_index <= begin_index:
        raise FragmentError("CHANGELOG.md generated-region markers are out of order")
    end_after_marker = end_index + len(END_MARKER)
    return changelog_text[:begin_index] + generated_region + changelog_text[end_after_marker:]


def assemble_changelog(changelog_text: str, fragment_dir: Path) -> str:
    """Return the canonical changelog text for the supplied accepted fragments."""
    return replace_generated_region(changelog_text, render_fragment_region(load_fragments(fragment_dir)))


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fragments", type=Path, default=DEFAULT_FRAGMENT_DIR)
    parser.add_argument("--changelog", type=Path, default=DEFAULT_CHANGELOG_PATH)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="write the canonical region")
    mode.add_argument("--check", action="store_true", help="check that the region is current")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        original = args.changelog.read_text(encoding="utf-8")
        assembled = assemble_changelog(original, args.fragments)
    except (FragmentError, OSError, UnicodeError) as error:
        print(f"ERROR: {error}")
        return 2

    if args.write:
        if original != assembled:
            args.changelog.write_text(assembled, encoding="utf-8")
        print(f"OK: assembled canonical changelog from {len(load_fragments(args.fragments))} fragments")
        return 0

    if original != assembled:
        print("ERROR: canonical changelog region is stale; rerun with --write")
        return 2
    print(f"OK: canonical changelog region matches {len(load_fragments(args.fragments))} fragments")
    return 0


if __name__ == "__main__":
    sys.exit(main())
