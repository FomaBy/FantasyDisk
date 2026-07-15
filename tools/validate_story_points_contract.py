#!/usr/bin/env python3
"""Reject incompatible CUE rubrics in FantasyDisk process materials."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CANONICAL_DOCUMENTS = (
    Path("docs/process/story_points.md"),
    Path("docs/process/multica_story_points_instruction.md"),
    Path("docs/process/pm_workflow.md"),
    Path("docs/process/multica_workflow.md"),
    Path("skills/codex/fantasydisk-agent-dispatcher/SKILL.md"),
)
REQUIRED_MARKERS = (
    "1, 2, 3, 5, 8, 13",
    "SP:<N>",
    "story_points",
    "estimation_model",
)
FORMULA_RE = re.compile(r"\bC\s*\+\s*U\s*\+\s*E\b")
FACTOR_SCALE_RE = re.compile(
    r"\b(?:from\s+)?1\s*(?:[-–—]|to|до)\s*5\b"
    r"|\b(?:from\s+)?one\s+to\s+five\b"
    r"|\b(?:от\s+)?одного\s+до\s+пяти\b"
    r"|(?:пяти|five)[-\s]?(?:балльн\w*|points?)",
    re.IGNORECASE,
)
CUE_FACTOR_RE = (
    re.compile(r"\bcomplexity\b|сложност\w*", re.IGNORECASE),
    re.compile(r"\buncertainty\b|неопредел[её]нн?\w*", re.IGNORECASE),
    re.compile(r"\befforts?\b|усили\w*|трудозатрат\w*", re.IGNORECASE),
)
CUE_ABBREVIATION_RE = re.compile(
    r"\bC\s*(?:(?:,|/|&|\+)\s*)?(?:(?:and|и)\s+)?U\s*"
    r"(?:(?:,|/|&|\+)\s*)?(?:(?:and|и)\s+)?E\b",
    re.IGNORECASE,
)
PER_FACTOR_RE = re.compile(r"(?:кажд\w*|each)\s+(?:фактор\w*|factors?)\b", re.IGNORECASE)
NUMERIC_RANGE_RE = re.compile(r"\b\d+\s*(?:[-–—]|to|до)\s*\d+\b", re.IGNORECASE)
SP_VALUE_RE = r"(?:SP\s*[:=]?\s*\d+|\d+\s*SP)\b"
NUMERIC_THRESHOLD_RE = re.compile(
    NUMERIC_RANGE_RE.pattern
    + r"(?:\s+(?:балл\w*|points?))?\s*"
    + r"(?:=|:|→|->|соответству\w*|gives?|maps?\s+to|becomes?)\s*"
    + SP_VALUE_RE,
    re.IGNORECASE,
)
NUMBER_WORD_RE = (
    r"(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|"
    r"thirteen|fourteen|fifteen|один|одного|одна|одну|два|двух|три|тр[её]х|"
    r"четыре|четыр[её]х|пять|пяти|шесть|шести|семь|семи|восемь|восьми|"
    r"девять|девяти|десять|десяти)"
)
WORDED_THRESHOLD_RE = re.compile(
    r"\b(?:from\s+|от\s+)?"
    + NUMBER_WORD_RE
    + r"\s+(?:to|до)\s+"
    + NUMBER_WORD_RE
    + r"\s*(?:=|:|→|->|соответству\w*|gives?|maps?\s+to|becomes?)\s*"
    + SP_VALUE_RE,
    re.IGNORECASE,
)
MARKDOWN_TABLE_ROW_RE = re.compile(r"^\s*\|(?P<cells>.*)\|\s*$")
MARKDOWN_LIST_ITEM_RE = re.compile(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)")
SENTENCE_BOUNDARY_RE = re.compile(r"(?<=[.!?;])\s+")
STORY_POINTS_HEADER_RE = re.compile(
    r"\b(?:SP|story\s*points?|storypoints?|стори[-\s]?поинт\w*|"
    r"балл\w*\s+истори\w*|истори\w*\s+балл\w*)\b",
    re.IGNORECASE,
)
SEPARATE_CHECKLIST_RE = re.compile(
    r"(?:\bseparate\b|\bотдельн\w*)\s+(?:[\w-]+\s+){0,3}"
    r"(?:checklists?|чек[-\s]?лист\w*)",
    re.IGNORECASE,
)
NON_CUE_CHECKLIST_SUBJECT_RE = re.compile(
    r"\b(?:accessibility|document|presentation|formatting|clarity|text)\b"
    r"|(?:доступност\w*|документ\w*|оформлен\w*|ясност\w*|текст\w*)",
    re.IGNORECASE,
)
CUE_SCORING_ACTION_RE = re.compile(
    r"\b(?:rate|rates|rated|rating|score|scores|scored|scoring|evaluate|evaluates|"
    r"evaluated|evaluating|assess|assesses|assessed|assessing)\b|оцен\w*",
    re.IGNORECASE,
)
CUE_HOLISTIC_MARKER_RE = re.compile(
    r"\bholistically\b|целостно|целиком",
    re.IGNORECASE,
)
SEPARATE_CHECKLIST_START_RE = re.compile(
    r"(?:\b(?:while|and)\s+(?:(?:a|the)\s+)?|[,;]\s*(?:а|и)\s*)"
    r"(?P<checklist>separate|отдельн\w*)\b",
    re.IGNORECASE,
)
OPERATIONAL_RANGE_SUFFIX_RE = re.compile(
    r"^\s*(?:[\w-]+\s+){0,4}(?:times?|attempts?|retries?|раз(?:а)?|попыт\w*)\b",
    re.IGNORECASE,
)


def semantic_instruction_units(source: str) -> list[str]:
    """Keep Markdown paragraphs and list items intact across soft line wraps."""
    units: list[str] = []
    current: list[str] = []
    current_is_list = False

    def flush() -> None:
        nonlocal current, current_is_list
        if current:
            units.append(" ".join(current))
        current = []
        current_is_list = False

    for line in source.splitlines():
        stripped = line.strip()
        if not stripped:
            flush()
            continue
        if MARKDOWN_TABLE_ROW_RE.match(line):
            flush()
            units.append(stripped)
            continue
        if MARKDOWN_LIST_ITEM_RE.match(line):
            flush()
            current.append(MARKDOWN_LIST_ITEM_RE.sub("", line).strip())
            current_is_list = True
            continue
        if current_is_list and not line[:1].isspace():
            flush()
        current.append(stripped)
    flush()
    return units


def has_cue_reference(source: str) -> bool:
    """Return whether text explicitly names the CUE rubric."""
    return (
        all(factor.search(source) for factor in CUE_FACTOR_RE)
        or bool(CUE_ABBREVIATION_RE.search(source))
        or bool(FORMULA_RE.search(source))
    )


def is_separate_checklist(source: str) -> bool:
    """Recognize a checklist explicitly separated from CUE scoring."""
    return bool(SEPARATE_CHECKLIST_RE.search(source))


def scoring_context_after_holistic_cue_action(before_scale: str) -> str:
    """Drop one completed holistic CUE predicate before a separate checklist."""
    for boundary in SEPARATE_CHECKLIST_START_RE.finditer(before_scale):
        predicate_context = before_scale[: boundary.start()]
        if (
            has_cue_reference(predicate_context)
            and CUE_HOLISTIC_MARKER_RE.search(predicate_context)
            and len(CUE_SCORING_ACTION_RE.findall(predicate_context)) == 1
        ):
            return before_scale[boundary.start("checklist") :]
    return before_scale


def is_independent_non_cue_checklist_scale(sentence: str, scale: re.Match[str]) -> bool:
    """Allow a scale only when a separate checklist proves its non-CUE subject."""
    before_scale = sentence[: scale.start()]
    direct_context = scoring_context_after_holistic_cue_action(before_scale)
    if has_cue_reference(direct_context) and CUE_SCORING_ACTION_RE.search(direct_context):
        return False

    for checklist in SEPARATE_CHECKLIST_RE.finditer(sentence):
        if checklist.start() <= scale.start() <= checklist.end():
            subject_context = sentence[checklist.start() :]
        elif scale.start() > checklist.end():
            subject_context = sentence[checklist.start() : scale.start()]
        else:
            continue
        if NON_CUE_CHECKLIST_SUBJECT_RE.search(subject_context):
            return True
    return False


def is_operational_range(sentence: str, scale: re.Match[str]) -> bool:
    """Distinguish retry/attempt counts from a scale applied to CUE factors."""
    after = sentence[scale.end() : scale.end() + 40]
    return bool(OPERATIONAL_RANGE_SUFFIX_RE.match(after))


def has_natural_language_factor_scale(source: str) -> bool:
    """Detect a scale applied to CUE factors within one Markdown unit."""
    for unit in semantic_instruction_units(source):
        if not has_cue_reference(unit):
            continue
        for sentence in SENTENCE_BOUNDARY_RE.split(unit):
            for scale in FACTOR_SCALE_RE.finditer(sentence):
                if is_operational_range(sentence, scale):
                    continue
                if is_independent_non_cue_checklist_scale(sentence, scale):
                    continue
                return True
    return False


def has_per_factor_score(source: str) -> bool:
    """Detect an explicit instruction to score each factor from one to five."""
    for unit in semantic_instruction_units(source):
        sentences = [sentence.strip() for sentence in SENTENCE_BOUNDARY_RE.split(unit) if sentence.strip()]
        for sentence in sentences:
            scale = FACTOR_SCALE_RE.search(sentence)
            if not (PER_FACTOR_RE.search(sentence) and scale):
                continue
            if is_operational_range(sentence, scale):
                continue
            if is_independent_non_cue_checklist_scale(sentence, scale):
                continue
            if has_cue_reference(unit):
                return True
    return False


def has_markdown_threshold_table(source: str) -> bool:
    """Detect a numeric range-to-SP mapping in one Markdown table."""
    lines = source.splitlines()
    for header_index, header in enumerate(lines):
        header_match = MARKDOWN_TABLE_ROW_RE.match(header)
        if not header_match or not any(
            STORY_POINTS_HEADER_RE.search(cell)
            for cell in header_match.group("cells").split("|")
        ):
            continue
        for row in lines[header_index + 1 :]:
            row_match = MARKDOWN_TABLE_ROW_RE.match(row)
            if not row_match:
                break
            cells = [cell.strip() for cell in row_match.group("cells").split("|")]
            if any(NUMERIC_RANGE_RE.search(cell) for cell in cells) and any(
                re.fullmatch(r"(?:SP\s*[:=]?\s*)?\d+(?:\s*SP)?", cell, re.IGNORECASE)
                for cell in cells
            ):
                return True
    return False


def has_threshold_conversion(source: str) -> bool:
    """Detect explicit numeric or worded conversion of a range to an SP value."""
    return bool(
        NUMERIC_THRESHOLD_RE.search(source)
        or WORDED_THRESHOLD_RE.search(source)
        or has_markdown_threshold_table(source)
    )


def validate(path: Path) -> list[str]:
    try:
        source = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [f"cannot read {path}: {exc}"]

    errors = [f"{path}: missing {marker!r}" for marker in REQUIRED_MARKERS if marker not in source]
    if not (
        "не складывается по формуле" in source
        or "does not sum by formula" in source
    ):
        errors.append(f"{path}: missing integral CUE/no-formula rule")
    if FORMULA_RE.search(source):
        errors.append(f"{path}: forbidden C + U + E conversion formula")
    if has_per_factor_score(source):
        errors.append(f"{path}: forbidden per-factor 1-to-5 CUE rubric")
    if has_natural_language_factor_scale(source):
        errors.append(f"{path}: forbidden natural-language per-factor 1-to-5 CUE rubric")
    if has_threshold_conversion(source):
        errors.append(f"{path}: forbidden conversion-threshold CUE rubric")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--document",
        action="append",
        type=Path,
        help="validate one additional document instead of the canonical set",
    )
    args = parser.parse_args(argv)
    documents = args.document or [ROOT / path for path in CANONICAL_DOCUMENTS]
    errors = [error for document in documents for error in validate(document)]
    if errors:
        print("story-points contract failed:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print(f"story-points contract passed: {len(documents)} document(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
