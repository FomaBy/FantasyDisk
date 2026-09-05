#!/usr/bin/env python3
"""Fast, deterministic repository invariants for CI and Windows releases."""
from __future__ import annotations

import argparse
import functools
import re
import subprocess
import sys
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from release_version_contract import RELEASE_VERSION_RE, is_valid_release_version
from release_version_mapping import platform_version_mapping, release_assignment_errors
from check_gdscript_contracts import contract_errors as gdscript_contract_errors


RUNTIME_SUFFIXES = {".gd", ".godot", ".tscn", ".tres", ".cfg"}
RESOURCE_RE = re.compile(r"res://[A-Za-z0-9_./@+\-]+")
FANTASYDISK_PROJECT_NAME = "FantasyDisk"
FANTASYDISK_PLAYER_IDENTITY = ("scenes/Player.tscn", "scripts/player.gd")
PLAYER_IMPORT_PROBE = "tests/import_cache_player_load_test.gd"
PLAYER_IMPORT_PROBE_CONTRACT = (
    "extends SceneTree",
    'preload("res://scenes/Player.tscn")',
    "PlayerScene.instantiate()",
    "player.free()",
)
LEGACY_LINE_CEILINGS = {
    # FAN-3824: монолит разрезан на scripts/ui/screens/**; фасад — не более 500
    # строк. Потолки только ужимаются (tests/test_quality_static_guard.py).
    "scripts/ui_screens.gd": 500,
    # FAN-3840: монолит разрезан на scripts/classes/**; фасад — не более 500 строк.
    "scripts/class_weapon.gd": 500,
    "scripts/player.gd": 4300,
    "scripts/progression_data.gd": 2500,
    "scripts/pause_stats_menu.gd": 2250,
    "scripts/enemy.gd": 1950,
    "scripts/cutout_rig_2d.gd": 1950,
    "scripts/main.gd": 1850,
    "scripts/route_map_screen.gd": 1600,
    "scripts/combat_director.gd": 1500,
    "scripts/meta_progression.gd": 1500,
    "scripts/progression_data_weapons.gd": 1280,
    "scripts/progression_data_characters.gd": 1250,
}
NEW_SCRIPT_LINE_LIMIT = 1200

# FAN-3845: домены и бюджет общих файлов из docs/process/ownership_map.md.
# Обычная задача — ровно один домен и не более одного бюджетного общего файла;
# намеренная кросс-доменная работа объявляется трейлером в сообщении коммита.
BUDGETED_SHARED_FILES = frozenset({
    # ограниченная общая поверхность ClassWeapon
    "scripts/class_weapon.gd",
    "scripts/classes/class_weapon_state.gd",
    "scripts/classes/class_weapon_shared_api.gd",
    "scripts/classes/class_weapon_core.gd",
    "scripts/classes/class_weapon_combat.gd",
    # legacy-семейства, которыми классы владеют совместно и не эксклюзивно
    "scripts/summoner_weapon.gd",  # druid + chemist
    "scripts/berserk_weapon.gd",  # berserk + knight
    "scripts/holy_flail_weapon.gd",
    "scripts/two_handed_axe_weapon.gd",
    "scripts/two_handed_hammer_weapon.gd",
    # ограниченная общая поверхность UI
    "scripts/ui_screens.gd",
    "scripts/ui/screens/ui_screens_state.gd",
    "scripts/ui/screens/ui_screens_shared_api.gd",
    "scripts/ui/screens/ui_style_kit.gd",
    "scripts/ui/screens/shared_shell_kit.gd",
    "scripts/ui/screens/menu_shell_kit.gd",
    # бюджет общих файлов вне доменов
    "CHANGELOG.md",
    "docs/design/content_registry.md",
    "docs/design/systems/animation.md",
})
CORE_FILES = frozenset({
    "scripts/player.gd",
    "scripts/enemy.gd",
    "scripts/main.gd",
    "scripts/combat_director.gd",
    "scripts/progression_data.gd",
    "scripts/full_frame_animation_registry.gd",
    "project.godot",
    "export_presets.cfg",
})
CORE_PREFIXES = (
    "tools/",
    ".github/workflows/",
    "scripts/ultimates/registry/",
    "scripts/ultimates/schema/",
    "scripts/ultimates/controller/",
    "scripts/ultimates/executors/",
    "scripts/ultimates/presentation/",
)
CLASS_LOCAL_FILES = {"scripts/robot_hydraulic_press_weapon.gd": "robot"}
CLASS_DIRECTORY_PREFIXES = (
    "scripts/ultimates/classes/",
    "data/ultimates/classes/",
    "tests/balance/",
)
CROSS_DOMAIN_MARKER_RE = re.compile(r"(?mi)^[ \t]*cross-domain[ \t]*:.*$")
CROSS_DOMAIN_RE = re.compile(r"(?m)^cross-domain: (FAN-\d+) (\S.{11,})$")

# FAN-3856: поверхности, где id владельца встроен в имя файла или папки, а не
# лежит отдельным сегментом пути. Реестры канонических id — единственный
# источник совпадений: произвольный поиск подстроки запрещён.
CANONICAL_ID_RE = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*")
ID_BOUNDARY_RE = re.compile(r"[A-Za-z0-9]")


class AmbiguousOwnershipError(RuntimeError):
    """Two equally valid canonical ids claim one path; the guard never guesses."""


def _id_registry(kind: str, ids: tuple[str, ...]) -> frozenset[str]:
    """Validate a canonical id registry; a broken registry fails closed at import."""
    registry: set[str] = set()
    for identifier in ids:
        if not CANONICAL_ID_RE.fullmatch(identifier):
            raise ValueError(f"{kind} id registry: invalid id {identifier!r}")
        if identifier in registry:
            raise ValueError(f"{kind} id registry: duplicate id {identifier!r}")
        registry.add(identifier)
    return frozenset(registry)


# Канонические актёры: `data/animation/<kind>/<actor_id>.json` плюс
# `tests/actors/<actor_id>_smoke_test.gd` (соответствие проверяет тест гарда).
ACTOR_IDS = _id_registry("actor", (
    "ash_marksman",
    "ashen_colossus",
    "bloodthorn_lion",
    "bone_archon",
    "bone_caller",
    "bone_shaman",
    "brood_mother",
    "disk_devourer",
    "druid_beast",
    "druid_ghost_bear",
    "druid_ghost_lion",
    "druid_ghost_panther",
    "druid_ghost_stag",
    "druid_ghost_wolf",
    "druid_pack_spirit",
    "homunculus",
    "homunculus_tank",
    "iron_bastion",
    "leadership_echo",
    "mini_bone_warden",
    "mini_plague_bellringer",
    "mini_plague_berserker",
    "mini_rot_hound",
    "mini_scavenger_reaper",
    "mini_shadow_devourer",
    "mini_siege_rammer",
    "mini_spark_wight",
    "mini_swarm_sniper",
    "mini_void_phantom",
    "night_stalker",
    "plague_prophet",
    "rift_cutter",
    "rift_shieldbearer",
    "rift_warden",
    "shard_marshal",
    "small_biter",
    "spark_runner",
    "stone_bruiser",
    "venom_spitter",
    "void_mage",
    "winged_spark",
))
# Канонические классы: `data/ultimates/classes/<class_id>/` (проверяет тест гарда).
CLASS_IDS = _id_registry("class", (
    "assassin",
    "berserk",
    "biologist",
    "chemist",
    "dark_mage",
    "doctor",
    "druid",
    "elementalist",
    "engineer",
    "guitarist",
    "knight",
    "priest",
    "ranger",
    "robot",
    "sniper",
    "soldier",
    "thief",
))


def _budgeted_shared(relative: str) -> bool:
    return relative in BUDGETED_SHARED_FILES or (
        relative.startswith("scripts/progression_data_") and relative.endswith(".gd")
    )


def _embedded_surface(relative: str) -> tuple[str, str, frozenset[str]] | None:
    """(domain kind, searched region, registry) for id-in-name ownership surfaces."""
    if relative.startswith("assets/") and "/ultimates/" in relative:
        return "class", relative.split("/ultimates/", 1)[1], CLASS_IDS
    if relative.startswith("assets/sprites/"):
        return "actor", relative.removeprefix("assets/sprites/"), ACTOR_IDS
    if relative.startswith("tests/ultimates/"):
        return "class", relative.removeprefix("tests/ultimates/"), CLASS_IDS
    if relative.startswith("scenes/") and "/ultimates/" in relative:
        return "class", relative.split("/ultimates/", 1)[1], CLASS_IDS
    return None


def _embedded_id(kind: str, region: str, registry: frozenset[str]) -> str | None:
    """Registered id embedded in `region` on identifier boundaries, or None."""
    spans: list[tuple[int, int, str]] = []
    for identifier in registry:
        start = 0
        while (at := region.find(identifier, start)) >= 0:
            end = at + len(identifier)
            before = region[at - 1] if at else ""
            after = region[end:end + 1]
            if not ID_BOUNDARY_RE.match(before) and not ID_BOUNDARY_RE.match(after):
                spans.append((at, end, identifier))
            start = at + 1
    # Внутри одного вхождения побеждает самый длинный зарегистрированный id
    # (`homunculus_tank` над `homunculus`). Два непересекающихся разных id — это
    # не выбор, а неоднозначность, и она обязана падать, а не угадываться.
    owners = {
        identifier
        for at, end, identifier in spans
        if not any(
            other_at <= at and end <= other_end and (other_at, other_end) != (at, end)
            for other_at, other_end, _ in spans
        )
    }
    if len(owners) > 1:
        raise AmbiguousOwnershipError(
            f"ambiguous {kind} ids " + ", ".join(sorted(owners)) + "; name exactly one owner"
        )
    return next(iter(owners), None)


def ownership_domain(relative: str) -> str | None:
    """Domain that owns a changed path, or None for shared/unowned surfaces.

    Raises AmbiguousOwnershipError when an id-in-name surface matches two
    equally valid canonical ids.
    """
    relative = relative.removesuffix(".uid")
    if _budgeted_shared(relative):
        return None
    if relative in CLASS_LOCAL_FILES:
        return f"class/{CLASS_LOCAL_FILES[relative]}"
    parts = Path(relative).parts
    name = Path(relative).name
    if relative.startswith("scripts/classes/") and name.endswith("_weapon.gd") and len(parts) == 3:
        return f"class/{name.removesuffix('_weapon.gd')}"
    for prefix in CLASS_DIRECTORY_PREFIXES:
        if relative.startswith(prefix) and len(parts) > len(Path(prefix).parts):
            return f"class/{parts[len(Path(prefix).parts)]}"
    if relative.startswith("docs/design/ultimates/") and name.endswith(".md"):
        return f"class/{name.removesuffix('.md')}"
    if relative.startswith("data/animation/") and name.endswith(".json") and len(parts) == 4:
        return f"actor/{name.removesuffix('.json')}"
    if relative.startswith("tests/actors/") and name.endswith("_smoke_test.gd"):
        return f"actor/{name.removesuffix('_smoke_test.gd')}"
    if relative.startswith("scripts/ui/screens/") and name.endswith(".gd") and len(parts) == 4:
        return f"ui/{name.removesuffix('.gd')}"
    surface = _embedded_surface(relative)
    if surface is not None:
        kind, region, registry = surface
        identifier = _embedded_id(kind, region, registry)
        return f"{kind}/{identifier}" if identifier else None
    if relative in CORE_FILES or relative.startswith(CORE_PREFIXES):
        return "core"
    if relative.startswith(("docs/process/", "docs/design/")):
        return "process/docs"
    return None


def _git_output(root: Path, args: list[str]) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or "no error output"
        raise RuntimeError(f"git {' '.join(args)} failed: {detail}")
    return result.stdout


def _integration_base_sha(root: Path, changed_ref: str) -> str:
    """Resolve the declared integration base; fail closed when it is unusable."""
    if not changed_ref or not changed_ref.strip():
        raise RuntimeError("integration base is absent")
    try:
        _git_output(root, ["rev-parse", "--verify", f"{changed_ref}^{{commit}}"])
        return _git_output(root, ["merge-base", changed_ref, "HEAD"]).strip()
    except RuntimeError as error:
        raise RuntimeError(
            f"integration base {changed_ref!r} cannot be resolved: {error}"
        ) from error


def _candidate_paths(root: Path, base_sha: str) -> list[str]:
    fields = _git_output(
        root, ["diff", "--name-status", "-M", "-z", base_sha, "--"]
    ).split("\0")
    paths: list[str] = []
    index = 0
    while index < len(fields) and fields[index]:
        status = fields[index]
        index += 1
        # Renames and copies carry both the old and the new path: a rename that
        # crosses domains is a two-domain change, not a free move.
        take = 2 if status[0] in ("R", "C") else 1
        paths.extend(fields[index:index + take])
        index += take
    untracked = _git_output(root, ["ls-files", "--others", "--exclude-standard", "-z"])
    paths.extend(item for item in untracked.split("\0") if item)
    return [path for path in paths if path]


def _cross_domain_errors(root: Path, base_sha: str) -> tuple[bool, list[str]]:
    messages = _git_output(root, ["log", "--format=%B", f"{base_sha}..HEAD"])
    markers = CROSS_DOMAIN_MARKER_RE.findall(messages)
    if not markers:
        return False, []
    if CROSS_DOMAIN_RE.search(messages):
        return True, []
    # A marker that fails the schema never buys a bypass; it fails closed.
    return False, [
        "ownership guard: malformed cross-domain declaration "
        f"{markers[0].strip()!r}; expected 'cross-domain: FAN-<id> <rationale>'"
    ]


def ownership_domain_errors(root: Path, changed_ref: str) -> list[str]:
    try:
        base_sha = _integration_base_sha(root, changed_ref)
    except RuntimeError as error:
        return [f"ownership guard: {error}"]

    declared, errors = _cross_domain_errors(root, base_sha)
    paths = _candidate_paths(root, base_sha)
    domains: set[str] = set()
    for path in paths:
        try:
            domain = ownership_domain(path)
        except AmbiguousOwnershipError as error:
            errors.append(f"ownership guard: {path}: {error}")
            continue
        if domain:
            domains.add(domain)
    shared = sorted({path for path in paths if _budgeted_shared(path.removesuffix(".uid"))})
    if not declared and len(domains) > 1:
        errors.append(
            "ownership guard: candidate spans ownership domains "
            + ", ".join(sorted(domains))
            + "; split the task or declare 'cross-domain: FAN-<id> <rationale>'"
        )
    if not declared and len(shared) > 1:
        errors.append(
            "ownership guard: candidate touches "
            f"{len(shared)} budgeted shared files (" + ", ".join(shared) + "); "
            "an ordinary task may touch at most one"
        )
    return errors


def tracked_files(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return [item.decode("utf-8") for item in result.stdout.split(b"\0") if item]


@functools.cache
def _head_blob(root: Path, relative: str) -> bytes:
    result = subprocess.run(
        ["git", "show", f"HEAD:{relative}"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"git show HEAD:{relative} failed: {detail or 'no error output'}"
        )
    return result.stdout


def _tracked_text(root: Path, relative: str, *, errors: str = "strict") -> str:
    path = root / relative
    if path.is_file():
        return path.read_text(encoding="utf-8", errors=errors)
    return _head_blob(root.resolve(), relative).decode("utf-8", errors=errors)


def _index_has_path(root: Path, relative: str) -> bool:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--error-unmatch", "--", relative],
        cwd=root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def _quoted_value(text: str, key: str) -> str:
    match = re.search(rf"(?m)^{re.escape(key)}=\"([^\"]*)\"$", text)
    return match.group(1) if match else ""


def _windows_block(export_text: str) -> str:
    marker = 'name="Windows Desktop"'
    marker_at = export_text.find(marker)
    if marker_at < 0:
        return ""
    start = export_text.rfind("\n[preset.", 0, marker_at)
    start = 0 if start < 0 else start + 1
    next_match = re.search(r"(?m)^\[preset\.\d+\]$", export_text[marker_at + len(marker):])
    if next_match is None:
        return export_text[start:]
    end = marker_at + len(marker) + next_match.start()
    return export_text[start:end]


def case_and_resource_errors(root: Path, tracked: list[str]) -> list[str]:
    errors: list[str] = []
    exact = set(tracked)
    folded: dict[str, list[str]] = {}
    for path in tracked:
        folded.setdefault(path.casefold(), []).append(path)
    for variants in folded.values():
        if len(variants) > 1:
            errors.append("case-insensitive tracked-path collision: " + ", ".join(variants))

    for source in tracked:
        path = root / source
        if path.suffix not in RUNTIME_SUFFIXES:
            continue
        try:
            text = _tracked_text(root, source)
        except UnicodeDecodeError:
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
            for match in RESOURCE_RE.finditer(line):
                resource = match.group(0).rstrip(".,;:)]}\"'")
                relative = resource.removeprefix("res://")
                if relative in exact or relative.startswith(".godot/"):
                    continue
                variants = folded.get(relative.casefold(), [])
                if variants:
                    errors.append(
                        f"{source}:{line_number}: resource case mismatch: "
                        f"{resource} (tracked as {variants[0]})"
                    )
    return errors


def version_and_windows_errors(root: Path) -> list[str]:
    errors: list[str] = []
    project = (root / "project.godot").read_text(encoding="utf-8")
    exports = (root / "export_presets.cfg").read_text(encoding="utf-8")
    windows = _windows_block(exports)
    version = _quoted_value(project, "config/version")
    if not version:
        errors.append("project.godot: config/version is missing")
    elif not is_valid_release_version(version):
        errors.append("project.godot: config/version must use the canonical bounded X.Y.Z or X.Y.Z.R contract")
    mapping = None
    if is_valid_release_version(version):
        try:
            mapping = platform_version_mapping(version)
        except ValueError as error:
            errors.append(f"project.godot: config/version {error}")
    if mapping is not None:
        errors.extend(release_assignment_errors(project, exports, version, mapping))

    required_project = [
        'config/features=PackedStringArray("4.7")',
        'renderer/rendering_method="gl_compatibility"',
        'renderer/rendering_method.mobile="gl_compatibility"',
    ]
    for line in required_project:
        if line not in project:
            errors.append(f"project.godot: required Windows-safe setting missing: {line}")

    required_windows = [
        'platform="Windows Desktop"',
        'binary_format/embed_pck=true',
        'binary_format/architecture="x86_64"',
        'texture_format/s3tc_bptc=true',
        'texture_format/etc2_astc=false',
        'application/export_angle=0',
        'application/export_d3d12=0',
    ]
    if not windows:
        errors.append("export_presets.cfg: Windows Desktop preset is missing")
    else:
        for line in required_windows:
            if line not in windows:
                errors.append(f"Windows Desktop preset: required setting missing: {line}")
        exclude = _quoted_value(windows, "exclude_filter")
        for fragment in (".godot/*", "feedback_webhook.cfg", "docs/*", "tools/*", "tests/*"):
            if fragment not in exclude:
                errors.append(f"Windows Desktop preset: exclude_filter must contain {fragment}")
    return errors


def architecture_errors(root: Path, tracked: list[str]) -> list[str]:
    errors: list[str] = []
    for relative in tracked:
        if not relative.startswith("scripts/") or not relative.endswith(".gd"):
            continue
        line_count = len(_tracked_text(root, relative).splitlines())
        ceiling = LEGACY_LINE_CEILINGS.get(relative, NEW_SCRIPT_LINE_LIMIT)
        if line_count > ceiling:
            errors.append(
                f"{relative}: {line_count} lines exceeds ratchet {ceiling}; "
                "extract a focused module instead of growing the monolith"
            )
    return errors


def script_uid_errors(root: Path, tracked: list[str]) -> list[str]:
    errors: list[str] = []
    tracked_paths = {Path(relative) for relative in tracked}
    ignored_directories = {
        path.parent for path in tracked_paths if path.name == ".gdignore"
    }
    for relative in tracked:
        path = Path(relative)
        is_ignored = any(parent in ignored_directories for parent in path.parents)
        if path.suffix != ".gd" or is_ignored:
            continue
        sidecar = Path(f"{path}.uid")
        if sidecar not in tracked_paths:
            errors.append(f"{path}: missing committed .uid sidecar")
    return errors


def player_import_probe_errors(root: Path, tracked: list[str]) -> list[str]:
    """Require the real Player import probe only in the full FantasyDisk tree."""
    if "project.godot" not in tracked:
        return []
    try:
        project = _tracked_text(root, "project.godot")
    except (OSError, RuntimeError, UnicodeDecodeError):
        return []
    if _quoted_value(project, "config/name") != FANTASYDISK_PROJECT_NAME:
        return []
    if not all(path in tracked for path in FANTASYDISK_PLAYER_IDENTITY):
        return []

    errors: list[str] = []
    if not _index_has_path(root, PLAYER_IMPORT_PROBE):
        errors.append(
            f"{PLAYER_IMPORT_PROBE}: required FantasyDisk Player import probe must be tracked"
        )
    probe = root / PLAYER_IMPORT_PROBE
    if not probe.is_file() or probe.is_symlink():
        errors.append(
            f"{PLAYER_IMPORT_PROBE}: required FantasyDisk Player import probe is missing"
        )
        return errors
    try:
        source = probe.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        errors.append(
            f"{PLAYER_IMPORT_PROBE}: required Player import probe contract is unreadable"
        )
        return errors
    missing = [fragment for fragment in PLAYER_IMPORT_PROBE_CONTRACT if fragment not in source]
    if missing:
        errors.append(
            f"{PLAYER_IMPORT_PROBE}: required Player import probe contract is incomplete: "
            + ", ".join(missing)
        )
    return errors


def credential_errors(root: Path, tracked: list[str]) -> list[str]:
    errors: list[str] = []
    forbidden_marker = "BUILTIN_WEBHOOK_" + "B64"
    for relative in tracked:
        if not relative.endswith((".gd", ".py", ".sh")):
            continue
        text = _tracked_text(root, relative, errors="ignore")
        if forbidden_marker in text:
            errors.append(f"{relative}: reversible built-in webhook credential is forbidden")
    return errors


def collect_errors(root: Path, changed_ref: str | None = None) -> list[str]:
    tracked = tracked_files(root)
    errors = (
        case_and_resource_errors(root, tracked)
        + version_and_windows_errors(root)
        + architecture_errors(root, tracked)
        + script_uid_errors(root, tracked)
        + player_import_probe_errors(root, tracked)
        + credential_errors(root, tracked)
        + gdscript_contract_errors(root)
    )
    # The ownership policy needs a diff base; it runs only when the caller
    # (tools/quality_gate.py) hands one over, and then fails closed.
    if changed_ref is not None:
        errors += ownership_domain_errors(root, changed_ref)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--changed-ref",
        default=None,
        help="integration diff base for the ownership-domain and shared-file policy",
    )
    args = parser.parse_args()
    root = args.root.resolve()
    errors = collect_errors(root, args.changed_ref)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        print(f"Static quality guard failed: {len(errors)} error(s).", file=sys.stderr)
        return 1
    print(
        "Static quality guard passed "
        "(case/version/Windows/architecture/sidecars/credentials/ownership)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
