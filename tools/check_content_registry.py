#!/usr/bin/env python3
"""Keep the split content registry and its compatibility index in agreement.

``docs/design/content_registry.md`` is no longer the registry itself: it is the
index that maps every registry section to the one file under
``docs/design/content/`` that owns it.  A section file declares itself with the
``<!-- content-registry-section -->`` marker, so unrelated pages in the same
directory are not mistaken for registry content.

The checks are the ones a split makes newly possible to get wrong:

* a section that exists in a file but not in the index, or the other way round,
  or listed against a different file than the one that holds it;
* a canonical id repeated inside one heading block, now that two owners edit
  two files instead of colliding in one;
* a class or actor id that no canonical registry backs.  A block opts in with
  ``<!-- canonical-ids: class -->`` or ``<!-- canonical-ids: actor -->``; the
  canonical ids come from ``data/ultimates/classes`` and ``data/animation``,
  never from a second hand-written list.

Every failure mode fails closed: an index that cannot be parsed, an empty
canonical registry and an unreadable section file are errors, not silence.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


INDEX_PATH = "docs/design/content_registry.md"
CONTENT_DIR = "docs/design/content"
SECTION_MARKER = "<!-- content-registry-section -->"
INDEX_TABLE_HEADING = "## Разделы Реестра"
INDEX_TABLE_HEADER = "| Раздел | Файл |"
INDEX_TABLE_SEPARATOR = "| --- | --- |"

HEADING_RE = re.compile(r"^(#{2,6})\s+(.*\S)\s*$")
INDEX_ROW_RE = re.compile(
    r"^\|\s*(?P<title>.+?)\s*\|\s*\[`(?P<label>[^`]+)`\]\((?P<target>[^)]+)\)\s*\|$"
)
ID_CELL_RE = re.compile(r"^`([a-z0-9_]+)`$")
ID_DOMAIN_RE = re.compile(r"^<!--\s*canonical-ids:\s*(?P<domain>[a-z_]+)\s*-->$")
CLASS_DIR = "data/ultimates/classes"
ACTOR_DIR = "data/animation"


class Block:
    """One heading and the lines that belong to it, up to the next heading."""

    def __init__(self, relative: str, level: int, title: str) -> None:
        self.relative = relative
        self.level = level
        self.title = title
        self.id_domain: str | None = None
        self.ids: list[str] = []

    @property
    def label(self) -> str:
        return f"{self.relative}: {'#' * self.level} {self.title}"


def canonical_ids(root: Path, domain: str) -> tuple[frozenset[str], list[str]]:
    """Canonical ids for a declared domain; an empty registry is an error."""
    if domain == "class":
        source = root / CLASS_DIR
        found = {path.name for path in source.glob("*") if path.is_dir()}
    elif domain == "actor":
        source = root / ACTOR_DIR
        found = {path.stem for path in source.rglob("*.json")}
    else:
        return frozenset(), [f"unknown canonical id domain {domain!r}"]
    if not found:
        return frozenset(), [f"canonical {domain} id registry {source.name} is empty"]
    return frozenset(found), []


def parse_blocks(relative: str, text: str) -> tuple[list[Block], list[str]]:
    """Heading blocks of one markdown page with their table ids and id domain."""
    blocks: list[Block] = []
    errors: list[str] = []
    current: Block | None = None
    for line in text.split("\n"):
        heading = HEADING_RE.match(line)
        if heading is not None:
            current = Block(relative, len(heading.group(1)), heading.group(2))
            blocks.append(current)
            continue
        domain = ID_DOMAIN_RE.match(line.strip())
        if current is None:
            if domain is not None:
                errors.append(f"{relative}: canonical id domain declared outside a section")
            continue
        if domain is not None:
            if current.id_domain is not None:
                errors.append(f"{current.label}: declares its canonical id domain twice")
            current.id_domain = domain.group("domain")
            continue
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        identifier = ID_CELL_RE.match(cells[0]) if cells else None
        if identifier is not None:
            current.ids.append(identifier.group(1))
    return blocks, errors


def parse_index(text: str) -> tuple[dict[str, str], list[str]]:
    """Map every listed section title to its declared section file."""
    errors: list[str] = []
    listed: dict[str, str] = {}
    lines = text.split("\n")
    try:
        start = lines.index(INDEX_TABLE_HEADING)
    except ValueError:
        return {}, [f"{INDEX_PATH}: section table {INDEX_TABLE_HEADING!r} is missing"]
    table = []
    for line in lines[start + 1 :]:
        if HEADING_RE.match(line):
            break
        if line.startswith("|"):
            table.append(line.strip())
    if table[:2] != [INDEX_TABLE_HEADER, INDEX_TABLE_SEPARATOR]:
        return {}, [
            f"{INDEX_PATH}: the section table must open with "
            f"{INDEX_TABLE_HEADER!r} and {INDEX_TABLE_SEPARATOR!r}"
        ]
    for line in table[2:]:
        row = INDEX_ROW_RE.match(line)
        if row is None:
            errors.append(f"{INDEX_PATH}: cannot read section row {line!r}")
            continue
        title = row.group("title")
        label, target = row.group("label"), row.group("target")
        if label != target:
            errors.append(
                f"{INDEX_PATH}: section {title!r} shows {label!r} but links to {target!r}"
            )
            continue
        if not target.startswith("content/") or not target.endswith(".md"):
            errors.append(
                f"{INDEX_PATH}: section {title!r} links outside {CONTENT_DIR} ({target})"
            )
            continue
        if title in listed:
            errors.append(f"{INDEX_PATH}: section {title!r} is listed more than once")
            continue
        listed[title] = f"docs/design/{target}"
    if not listed and not errors:
        errors.append(f"{INDEX_PATH}: the section table lists no sections")
    return listed, errors


def registry_errors(root: Path) -> list[str]:
    """Every disagreement between the index, the section files and canonical ids."""
    index_file = root / INDEX_PATH
    if not index_file.is_file():
        return [f"{INDEX_PATH}: the compatibility index is missing"]
    index_text = index_file.read_text(encoding="utf-8")
    listed, errors = parse_index(index_text)
    # The index routes to sections; a section left behind here would be content
    # nobody owns, and the split would be only half done.
    for line in index_text.split("\n"):
        heading = HEADING_RE.match(line)
        if heading is not None and heading.group(1) == "##" and line.strip() != INDEX_TABLE_HEADING:
            errors.append(f"{INDEX_PATH}: keeps registry section {heading.group(2)!r}")

    owned: dict[str, str] = {}
    blocks: list[Block] = []
    marked: set[str] = set()
    for path in sorted((root / CONTENT_DIR).glob("*.md")):
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        if SECTION_MARKER not in text:
            continue
        marked.add(relative)
        page_blocks, page_errors = parse_blocks(relative, text)
        errors += page_errors
        blocks += page_blocks
        for block in page_blocks:
            if block.level != 2:
                continue
            if block.title in owned:
                errors.append(
                    f"{relative}: section {block.title!r} also exists in {owned[block.title]}"
                )
                continue
            owned[block.title] = relative

    for title, relative in sorted(owned.items()):
        declared = listed.get(title)
        if declared is None:
            errors.append(f"{relative}: section {title!r} is not listed in {INDEX_PATH}")
        elif declared != relative:
            errors.append(
                f"{INDEX_PATH}: section {title!r} is listed in {declared} but lives in {relative}"
            )
    for title, relative in sorted(listed.items()):
        if title not in owned:
            errors.append(
                f"{INDEX_PATH}: section {title!r} is listed in {relative}, which does not hold it"
            )
    for relative in sorted(marked - set(listed.values())):
        errors.append(f"{relative}: a registry section file absent from {INDEX_PATH}")

    errors += _id_errors(root, blocks)
    return errors


def _id_errors(root: Path, blocks: list[Block]) -> list[str]:
    registries: dict[str, frozenset[str]] = {}
    errors: list[str] = []
    for block in blocks:
        seen: set[str] = set()
        for identifier in block.ids:
            if identifier in seen:
                errors.append(f"{block.label}: duplicate canonical id {identifier!r}")
            seen.add(identifier)
        if block.id_domain is None:
            continue
        domain = block.id_domain
        if domain not in registries:
            known, problems = canonical_ids(root, domain)
            errors += [f"{block.label}: {problem}" for problem in problems]
            if problems:
                continue
            registries[domain] = known
        for identifier in sorted(seen - registries[domain]):
            errors.append(f"{block.label}: unknown {domain} id {identifier!r}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = registry_errors(args.root.resolve())
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        print(f"Content registry check failed: {len(errors)} error(s).", file=sys.stderr)
        return 1
    print("Content registry passed (index/sections/canonical ids).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
