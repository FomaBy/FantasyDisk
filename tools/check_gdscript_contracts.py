#!/usr/bin/env python3
"""Verify the deliberately linear GDScript contracts behind FantasyDisk facades.

This is intentionally a small structural parser, not a replacement for Godot's
parser.  It understands the inheritance and function-signature forms used by
the facade chains and rejects a declaration form it cannot certify.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


IDENTIFIER_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*$")
FUNCTION_START_RE = re.compile(r"(?m)^(?:(static)\s+)?func\b")
EXTENDS_RE = re.compile(r"(?m)^extends\s+(.+?)\s*$")
CLASS_NAME_RE = re.compile(r"(?m)^class_name\s+(.+?)\s*$")
ANNOTATION_RE = re.compile(r"^@([A-Za-z_][A-Za-z0-9_]*)")
EXTERNAL_BASES = frozenset({"Object", "RefCounted", "Node", "Node2D", "Control"})


class GDScriptContractError(ValueError):
    """A declaration cannot be safely understood by this static checker."""


@dataclass(frozen=True)
class Parameter:
    name: str
    type_name: str | None
    has_default: bool


@dataclass(frozen=True)
class Function:
    name: str
    is_static: bool
    parameters: tuple[Parameter, ...]
    return_type: str | None
    annotations: tuple[str, ...]
    line: int


@dataclass(frozen=True)
class Script:
    path: str
    extends: str | None
    class_name: str | None
    functions: tuple[Function, ...]
    line_count: int


@dataclass(frozen=True)
class ChainSpec:
    name: str
    facade: str
    module_directory: str
    forward_api: str
    terminal_base: str
    facade_class_name: str | None


CHAIN_SPECS = (
    ChainSpec(
        name="ui_screens",
        facade="scripts/ui_screens.gd",
        module_directory="scripts/ui/screens",
        forward_api="scripts/ui/screens/ui_screens_shared_api.gd",
        terminal_base="RefCounted",
        facade_class_name=None,
    ),
    ChainSpec(
        name="class_weapon",
        facade="scripts/class_weapon.gd",
        module_directory="scripts/classes",
        forward_api="scripts/classes/class_weapon_shared_api.gd",
        terminal_base="Node2D",
        facade_class_name="ClassWeapon",
    ),
)


def _blank_comments_and_strings(source: str) -> str:
    """Keep line/column positions while hiding comments and string contents."""
    result = list(source)
    index = 0
    quote: str | None = None
    triple: str | None = None
    while index < len(source):
        if triple is not None:
            if source.startswith(triple, index):
                for offset in range(3):
                    result[index + offset] = " "
                index += 3
                triple = None
            else:
                if source[index] != "\n":
                    result[index] = " "
                index += 1
            continue

        char = source[index]
        if quote is not None:
            if char == "\\":
                result[index] = " "
                if index + 1 < len(source) and source[index + 1] != "\n":
                    result[index + 1] = " "
                index += 2
                continue
            if char != "\n" and char != quote:
                result[index] = " "
            if char == quote:
                quote = None
            index += 1
            continue

        if source.startswith('"""', index) or source.startswith("'''", index):
            triple = source[index:index + 3]
            result[index:index + 3] = [" ", " ", " "]
            index += 3
        elif char in ('"', "'"):
            quote = char
            index += 1
        elif char == "#":
            while index < len(source) and source[index] != "\n":
                result[index] = " "
                index += 1
        else:
            index += 1
    return "".join(result)


def _line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def _split_top_level(value: str, delimiter: str) -> list[str]:
    pieces: list[str] = []
    start = 0
    depths = {"(": 0, "[": 0, "{": 0}
    pairs = {")": "(", "]": "[", "}": "{"}
    for index, char in enumerate(value):
        if char in depths:
            depths[char] += 1
        elif char in pairs:
            opening = pairs[char]
            depths[opening] -= 1
            if depths[opening] < 0:
                raise GDScriptContractError("unbalanced delimiter in declaration")
        elif char == delimiter and not any(depths.values()):
            pieces.append(value[start:index])
            start = index + 1
    if any(depths.values()):
        raise GDScriptContractError("unbalanced delimiter in declaration")
    pieces.append(value[start:])
    return pieces


def _find_matching_parenthesis(source: str, opening: int) -> int:
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "(":
            depth += 1
        elif source[index] == ")":
            depth -= 1
            if depth == 0:
                return index
            if depth < 0:
                break
    raise GDScriptContractError("unterminated function parameter list")


def _find_header_colon(source: str, start: int) -> int:
    depths = {"(": 0, "[": 0, "{": 0}
    pairs = {")": "(", "]": "[", "}": "{"}
    for index in range(start, len(source)):
        char = source[index]
        if char in depths:
            depths[char] += 1
        elif char in pairs:
            depths[pairs[char]] -= 1
        elif char == ":" and not any(depths.values()):
            return index
        elif char == "\n" and not any(depths.values()):
            raise GDScriptContractError("function declaration is missing ':'")
    raise GDScriptContractError("function declaration is missing ':'")


def _normalise_type(value: str) -> str | None:
    value = re.sub(r"\s+", "", value)
    return value or None


def _parse_parameter(value: str) -> Parameter:
    value = value.strip()
    if not value:
        raise GDScriptContractError("empty function parameter")
    assignment_at = -1
    assignment_width = 0
    depths = {"(": 0, "[": 0, "{": 0}
    closing = {")": "(", "]": "[", "}": "{"}
    for index, char in enumerate(value):
        if char in depths:
            depths[char] += 1
        elif char in closing:
            depths[closing[char]] -= 1
        elif char == "=" and not any(depths.values()):
            assignment_at = index - 1 if index > 0 and value[index - 1] == ":" else index
            assignment_width = 2 if assignment_at != index else 1
            break
    if any(depths.values()):
        raise GDScriptContractError("unbalanced delimiter in parameter declaration")
    declaration = value[:assignment_at].strip() if assignment_at >= 0 else value
    default = value[assignment_at + assignment_width:].strip() if assignment_at >= 0 else ""
    if assignment_at >= 0 and not default:
        raise GDScriptContractError(f"empty default argument for {declaration!r}")
    typed = _split_top_level(declaration, ":")
    if len(typed) > 2:
        raise GDScriptContractError(f"unsupported parameter declaration {value!r}")
    name = typed[0].strip()
    if not IDENTIFIER_RE.fullmatch(name):
        raise GDScriptContractError(f"unsupported parameter name {name!r}")
    type_name = _normalise_type(typed[1]) if len(typed) == 2 else None
    if len(typed) == 2 and type_name is None:
        raise GDScriptContractError(f"missing type after ':' for parameter {name!r}")
    return Parameter(name=name, type_name=type_name, has_default=assignment_at >= 0)


def _annotations_before(source: str, start: int) -> tuple[str, ...]:
    lines = source[:start].splitlines()
    annotations: list[str] = []
    for line in reversed(lines):
        stripped = line.strip()
        if not stripped:
            continue
        match = ANNOTATION_RE.fullmatch(stripped) or ANNOTATION_RE.match(stripped)
        if match is None:
            break
        annotations.append(match.group(1))
    return tuple(reversed(annotations))


def _parse_function(source: str, masked: str, start: int) -> Function:
    match = FUNCTION_START_RE.match(masked, start)
    if match is None:
        raise GDScriptContractError("unsupported function declaration")
    index = match.end()
    while index < len(masked) and masked[index].isspace():
        index += 1
    name_match = re.match(r"[A-Za-z_][A-Za-z0-9_]*", masked[index:])
    if name_match is None:
        raise GDScriptContractError(
            f"line {_line_number(source, start)}: unsupported function name"
        )
    name = name_match.group(0)
    index += len(name)
    while index < len(masked) and masked[index].isspace():
        index += 1
    if index >= len(masked) or masked[index] != "(":
        raise GDScriptContractError(
            f"line {_line_number(source, start)}: unsupported function declaration for {name}"
        )
    closing = _find_matching_parenthesis(masked, index)
    colon = _find_header_colon(masked, closing + 1)
    tail = masked[closing + 1:colon].strip()
    return_type: str | None = None
    if tail:
        if not tail.startswith("->"):
            raise GDScriptContractError(
                f"line {_line_number(source, start)}: unsupported function suffix {tail!r}"
            )
        return_type = _normalise_type(tail[2:])
        if return_type is None:
            raise GDScriptContractError(
                f"line {_line_number(source, start)}: missing return type for {name}"
            )
    parameters_text = masked[index + 1:closing]
    parameters = tuple(
        _parse_parameter(parameter)
        for parameter in _split_top_level(parameters_text, ",")
        if parameter.strip()
    )
    return Function(
        name=name,
        is_static=match.group(1) is not None,
        parameters=parameters,
        return_type=return_type,
        annotations=_annotations_before(masked, start),
        line=_line_number(source, start),
    )


def _parse_extends(source: str, masked: str, path: str) -> str | None:
    matches = list(EXTENDS_RE.finditer(masked))
    if len(matches) > 1:
        raise GDScriptContractError(f"{path}: more than one extends declaration")
    if not matches:
        return None
    target = matches[0].group(1).strip()
    # The masked version intentionally hides string literals. Recover a quoted
    # res:// path from the original declaration line before examining identifiers.
    source_line = source.splitlines()[_line_number(source, matches[0].start()) - 1]
    literal = re.match(r"^extends\s+(['\"])(res://[^'\"]+)\1\s*(?:#.*)?$", source_line)
    if literal is not None:
        target = literal.group(2)
    if target.startswith("res://"):
        if not target.endswith(".gd") or ".." in Path(target.removeprefix("res://")).parts:
            raise GDScriptContractError(f"{path}: unsupported extends path {target!r}")
        return target
    if IDENTIFIER_RE.fullmatch(target):
        return target
    raise GDScriptContractError(f"{path}: unsupported extends target {target!r}")


def parse_script(path: Path, root: Path) -> Script:
    relative = path.resolve().relative_to(root.resolve()).as_posix()
    source = path.read_text(encoding="utf-8")
    masked = _blank_comments_and_strings(source)
    class_names = list(CLASS_NAME_RE.finditer(masked))
    if len(class_names) > 1:
        raise GDScriptContractError(f"{relative}: more than one class_name declaration")
    class_name: str | None = None
    if class_names:
        candidate = class_names[0].group(1).strip()
        if not IDENTIFIER_RE.fullmatch(candidate):
            raise GDScriptContractError(f"{relative}: unsupported class_name {candidate!r}")
        class_name = candidate
    functions = tuple(_parse_function(source, masked, match.start()) for match in FUNCTION_START_RE.finditer(masked))
    names = [function.name for function in functions]
    if len(names) != len(set(names)):
        raise GDScriptContractError(f"{relative}: duplicate function declaration in one script")
    return Script(
        path=relative,
        extends=_parse_extends(source, masked, relative),
        class_name=class_name,
        functions=functions,
        line_count=len(source.splitlines()),
    )


def _scripts_for_spec(root: Path, spec: ChainSpec) -> dict[str, Script]:
    paths = [root / spec.facade]
    module_directory = root / spec.module_directory
    paths.extend(sorted(module_directory.rglob("*.gd")))
    scripts: dict[str, Script] = {}
    for path in paths:
        if not path.is_file():
            relative = path.relative_to(root).as_posix()
            raise GDScriptContractError(f"{spec.name}: required script is missing: {relative}")
        script = parse_script(path, root)
        scripts[script.path] = script
    return scripts


def _resolve_chain(spec: ChainSpec, scripts: dict[str, Script]) -> list[str]:
    class_paths: dict[str, str] = {}
    for path, script in scripts.items():
        if script.class_name is None:
            continue
        previous = class_paths.setdefault(script.class_name, path)
        if previous != path:
            raise GDScriptContractError(
                f"{spec.name}: class_name {script.class_name!r} is declared by both {previous} and {path}"
            )
    chain: list[str] = []
    current = spec.facade
    while True:
        if current in chain:
            cycle = " -> ".join([*chain[chain.index(current):], current])
            raise GDScriptContractError(f"{spec.name}: inheritance cycle: {cycle}")
        script = scripts.get(current)
        if script is None:
            raise GDScriptContractError(f"{spec.name}: unresolved base {current!r}")
        chain.append(current)
        target = script.extends
        if target is None:
            raise GDScriptContractError(f"{current}: missing extends declaration")
        if target.startswith("res://"):
            current = target.removeprefix("res://")
            if current not in scripts:
                raise GDScriptContractError(f"{current}: unresolved base referenced by {script.path}")
            continue
        if target in class_paths:
            current = class_paths[target]
            continue
        if target in EXTERNAL_BASES:
            if target != spec.terminal_base:
                raise GDScriptContractError(
                    f"{spec.name}: expected terminal base {spec.terminal_base}, found {target}"
                )
            return chain
        raise GDScriptContractError(f"{script.path}: unresolved base {target!r}")


def signatures_compatible(base: Function, override: Function) -> bool:
    """Compare the GDScript override surface, ignoring parameter spelling only."""
    return (
        base.is_static == override.is_static
        and base.return_type == override.return_type
        and tuple((item.type_name, item.has_default) for item in base.parameters)
        == tuple((item.type_name, item.has_default) for item in override.parameters)
    )


def _contract_errors_for_spec(root: Path, spec: ChainSpec) -> list[str]:
    try:
        scripts = _scripts_for_spec(root, spec)
        chain = _resolve_chain(spec, scripts)
    except GDScriptContractError as error:
        return [str(error)]

    errors: list[str] = []
    facade = scripts[spec.facade]
    if facade.class_name != spec.facade_class_name:
        errors.append(
            f"{spec.name}: facade class_name must be {spec.facade_class_name!r}, "
            f"found {facade.class_name!r}"
        )
    expected_modules = set(scripts) - {spec.facade}
    actual_modules = set(chain) - {spec.facade}
    for path in sorted(expected_modules - actual_modules):
        errors.append(f"{spec.name}: {path} is an accidental sibling, not on the facade chain")
    for path in sorted(actual_modules - expected_modules):
        errors.append(f"{spec.name}: {path} is outside the controlled module directory")
    if spec.forward_api not in chain:
        errors.append(f"{spec.name}: forward API {spec.forward_api} is absent from the facade chain")
        return errors

    api_index = chain.index(spec.forward_api)
    api = scripts[spec.forward_api]
    api_functions = {function.name: function for function in api.functions}
    if len(api_functions) != len(api.functions):
        errors.append(f"{spec.name}: forward API has duplicate declarations")
        return errors
    function_paths: dict[str, list[tuple[str, Function]]] = {}
    for path in chain:
        for function in scripts[path].functions:
            function_paths.setdefault(function.name, []).append((path, function))

    for name, declaration in sorted(api_functions.items()):
        overrides = [
            (path, function)
            for path in chain[:api_index]
            for function in scripts[path].functions
            if function.name == name
        ]
        if not overrides:
            errors.append(
                f"{spec.name}: forward API method {name} has no required downstream override"
            )
            continue
        if len(overrides) != 1:
            paths = ", ".join(path for path, _ in overrides)
            errors.append(
                f"{spec.name}: forward API method {name} has {len(overrides)} downstream implementations: {paths}"
            )
            continue
        override_path, override = overrides[0]
        if not signatures_compatible(declaration, override):
            errors.append(
                f"{spec.name}: incompatible signature for {name}: "
                f"{spec.forward_api}:{declaration.line} vs {override_path}:{override.line}"
            )

    for name, definitions in sorted(function_paths.items()):
        if len(definitions) < 2:
            continue
        paths = [path for path, _ in definitions]
        if name not in api_functions:
            errors.append(
                f"{spec.name}: accidental duplicate implementation {name} in {', '.join(paths)}"
            )
            continue
        if len(definitions) != 2 or spec.forward_api not in paths:
            errors.append(
                f"{spec.name}: duplicate implementation of {name} is not the declared virtual override"
            )
    return errors


def contract_errors(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    for spec in CHAIN_SPECS:
        errors.extend(_contract_errors_for_spec(root, spec))
    return errors


def resolved_chains(root: Path) -> tuple[tuple[ChainSpec, tuple[Script, ...]], ...]:
    """Return facade-to-engine chains after the same fail-closed contract check."""
    errors = contract_errors(root)
    if errors:
        raise GDScriptContractError("; ".join(errors))
    chains: list[tuple[ChainSpec, tuple[Script, ...]]] = []
    for spec in CHAIN_SPECS:
        scripts = _scripts_for_spec(root, spec)
        chains.append((spec, tuple(scripts[path] for path in _resolve_chain(spec, scripts))))
    return tuple(chains)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = contract_errors(args.root)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        print(f"GDScript facade contract check failed: {len(errors)} error(s).", file=sys.stderr)
        return 1
    print("GDScript facade contracts passed (UI and ClassWeapon chains).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
