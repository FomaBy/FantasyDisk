#!/usr/bin/env python3
"""FAN-3977: deterministic lossless trim atlases for every full-frame actor pack.

Every full-frame SpriteFrames pack (the 41 registry shards in
`data/animation/**` plus the secret-boss pack referenced by scene metadata)
ships its frames as standalone 512x512 (allies: 256x256) RGBA textures while
the actor occupies only 16-43 % of that canvas. Rendered at the registry
`scale` with linear filtering, the transparent canvas around the actor still
costs texture memory (1 MiB per 512x512 frame, ~8.2 GiB for the catalog) and
main-thread upload time on the GL Compatibility renderer.

This tool rewrites each pack losslessly:

* every frame is trimmed to its alpha bounding box plus `PAD` transparent
  source pixels on each side (clamped to the canvas), so bilinear sampling at
  the visible edge sees exactly the same neighbouring texels as before;
* identical frames (same pixels) share one atlas entry;
* the trims are packed (max-rects, bottom-left rule, deterministic) into
  lossless RGBA pages of at most `PAGE_SIZE` x `PAGE_SIZE` with a `GUTTER`
  of transparent pixels between entries;
* the SpriteFrames `.tres` keeps every animation name, order, loop flag,
  speed and per-frame duration; every frame references the pack's single
  `FullFrameCanvasTexture` (reports the canvas size, draws nothing) and the
  resource carries a `FullFrameTrimAtlas` table (`metadata/
  full_frame_trim_atlas`): one entry per unique frame (page, region on the
  page, canvas offset of the trim) and the entry index of every frame per
  animation. `FullFrameTrimAtlas.attach` draws the current frame's region
  at the canvas offset from the sprite's `draw` signal, so `AnimatedSprite2D`
  places every frame at the same on-screen position and size, `flip_h`
  mirrors around the same axis, and consumers that measure the frame
  texture see the unchanged canvas. FAN-3977 shipped one `AtlasTexture`
  per unique frame with the same region/margin; FAN-3981 replaced it with
  this table because every resident pack cost ~230 engine objects
  (perf checklist M3 red on the fixed 0.3.1 Windows review);
* a manifest binds the source frames (path + SHA-256), the packing layout
  and the animation model, so `--check` can prove the committed pages and
  `.tres` are exactly what the retained sources produce.

The original per-frame PNGs stay in place as the art sources (provenance);
they are excluded from the export presets so the package ships only the
pages.

Usage:
    python3 tools/build_full_frame_trim_atlases.py            # build/rewrite all packs
    python3 tools/build_full_frame_trim_atlases.py --check    # verify committed output
    python3 tools/build_full_frame_trim_atlases.py --report   # before/after table
    python3 tools/build_full_frame_trim_atlases.py --only mini_void_phantom [...]

Requires Pillow (used for PNG decode/encode only; packing is pure Python).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ANIMATION_DATA_ROOT = ROOT / "data" / "animation"
# Full-frame packs that are not registry shards but go through the same
# runtime (`metadata/full_frame_spriteframes_path`).
EXTRA_PACKS = (
    "res://assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres",
)
# FAN-3934 packed the Small Biter frames into 4096x4096 slot pages; its
# manifest maps every slot back to the retained per-frame source PNG.
LEGACY_SLOT_ATLAS_MANIFESTS = {
    "res://assets/sprites/enemies/full_frame/small_biter_spriteframes.tres":
        "assets/sprites/enemies/full_frame/small_biter_atlas_manifest.json",
}

MANIFEST_VERSION = 1
PACKER = "tools/build_full_frame_trim_atlases.py"
PAD = 1  # transparent source pixels kept around the alpha bbox (bilinear reaches one texel)
GUTTER = 2  # transparent pixels between atlas entries (the importer's alpha-border fix stays per sprite)
PAGE_SIZE = 2048
SMALL_PAGE_SIZE = 1024
PAGE_SUFFIX = "_trim_"
MANIFEST_SUFFIX = "_trim_manifest.json"
IMPORT_PARAMS_REQUIRED = {"compress/mode": "0", "mipmaps/generate": "false"}
# FAN-3981 runtime representation (see the module docstring).
CANVAS_TEXTURE_SCRIPT = "res://scripts/full_frame_canvas_texture.gd"
TRIM_ATLAS_SCRIPT = "res://scripts/full_frame_trim_atlas.gd"
TRIM_ATLAS_META = "full_frame_trim_atlas"
CANVAS_SUB_ID = "Canvas"
TRIM_ATLAS_SUB_ID = "TrimAtlas"


# --- Godot text-resource subset parser ---------------------------------------


class TresParseError(ValueError):
    pass


class _Tokenizer:
    _NUMBER = re.compile(r"-?\d+(?:\.\d+)?(?:e-?\d+)?")
    _IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

    def __init__(self, text: str) -> None:
        self.text = text
        self.pos = 0

    def skip_ws(self) -> None:
        while self.pos < len(self.text) and self.text[self.pos] in " \t\r\n":
            self.pos += 1

    def peek(self) -> str:
        self.skip_ws()
        return self.text[self.pos] if self.pos < len(self.text) else ""

    def expect(self, char: str) -> None:
        if self.peek() != char:
            raise TresParseError(f"expected {char!r} at {self.pos}: {self.text[self.pos:self.pos + 40]!r}")
        self.pos += 1

    def string(self) -> str:
        self.expect('"')
        out = []
        while self.pos < len(self.text) and self.text[self.pos] != '"':
            if self.text[self.pos] == "\\":
                self.pos += 1
            out.append(self.text[self.pos])
            self.pos += 1
        self.expect('"')
        return "".join(out)

    def value(self):
        char = self.peek()
        if char == "{":
            self.pos += 1
            result = {}
            while self.peek() != "}":
                key = self.string()
                self.expect(":")
                result[key] = self.value()
                if self.peek() == ",":
                    self.pos += 1
            self.pos += 1
            return result
        if char == "[":
            self.pos += 1
            items = []
            while self.peek() != "]":
                items.append(self.value())
                if self.peek() == ",":
                    self.pos += 1
            self.pos += 1
            return items
        if char == '"':
            return self.string()
        if char == "&":
            self.pos += 1
            return ("StringName", self.string())
        match = self._NUMBER.match(self.text, self.pos)
        if match:
            self.pos = match.end()
            raw = match.group(0)
            return float(raw) if any(c in raw for c in ".e") else int(raw)
        match = self._IDENT.match(self.text, self.pos)
        if not match:
            raise TresParseError(f"unexpected token at {self.pos}: {self.text[self.pos:self.pos + 40]!r}")
        ident = match.group(0)
        self.pos = match.end()
        if ident == "true":
            return True
        if ident == "false":
            return False
        if ident == "null":
            return None
        # Constructor call: ExtResource("id"), SubResource("id"), Rect2(...)
        self.expect("(")
        args = []
        while self.peek() != ")":
            args.append(self.value())
            if self.peek() == ",":
                self.pos += 1
        self.pos += 1
        return (ident, tuple(args))


_SECTION_RE = re.compile(r'^\[(\w+)((?:\s+\w+="[^"]*")*)\]\s*$', re.M)
_ATTR_RE = re.compile(r'(\w+)="([^"]*)"')


def parse_tres(text: str) -> dict:
    """Parse the subset of Godot text resources this tool reads."""
    sections = []
    matches = list(_SECTION_RE.finditer(text))
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        attrs = dict(_ATTR_RE.findall(match.group(2)))
        body = text[match.end():end]
        props = {}
        for prop in re.finditer(r"^(\w+) = ", body, re.M):
            tokenizer = _Tokenizer(body)
            tokenizer.pos = prop.end()
            props[prop.group(1)] = tokenizer.value()
        sections.append((match.group(1), attrs, props))
    return {"sections": sections}


# --- Pack model ---------------------------------------------------------------


@dataclass
class FrameRef:
    duration: float
    source: str  # res:// path of the retained source PNG
    region: tuple[int, int, int, int] | None = None  # source-region for slot atlases


@dataclass
class AnimationModel:
    name: str
    loop: bool
    speed: float
    frames: list[FrameRef] = field(default_factory=list)


@dataclass
class PackModel:
    pack_id: str
    tres_path: str  # res://
    animations: list[AnimationModel]
    resource_props: dict  # other [resource] props, preserved verbatim (text)


def res_to_path(res_path: str) -> Path:
    return ROOT / res_path.removeprefix("res://")


def discover_packs() -> list[str]:
    packs = []
    for shard in sorted(ANIMATION_DATA_ROOT.glob("*/*.json")):
        document = json.loads(shard.read_text(encoding="utf-8"))
        frames = document.get("frames")
        if isinstance(frames, str) and frames.startswith("res://"):
            packs.append(frames)
    for extra in EXTRA_PACKS:
        if extra not in packs:
            packs.append(extra)
    return packs


def pack_id_for(tres_res_path: str) -> str:
    name = Path(tres_res_path).name
    name = name.removesuffix(".tres").removesuffix("_spriteframes")
    return name.removeprefix("ally_") if "/allies/" in tres_res_path else name


def manifest_path_for(tres_res_path: str) -> Path:
    return res_to_path(tres_res_path).with_name(pack_id_for(tres_res_path) + MANIFEST_SUFFIX)


def page_res_path(tres_res_path: str, page_index: int) -> str:
    directory = tres_res_path.rsplit("/", 1)[0]
    return f"{directory}/{pack_id_for(tres_res_path)}{PAGE_SUFFIX}{page_index}.png"


def _sname(value) -> str:
    if isinstance(value, tuple) and value[0] == "StringName":
        return value[1]
    return str(value)


def load_model_from_original_tres(tres_res_path: str) -> PackModel:
    """Model from a not-yet-converted .tres (standalone textures or FAN-3934 slots)."""
    parsed = parse_tres(res_to_path(tres_res_path).read_text(encoding="utf-8"))
    ext_paths: dict[str, str] = {}
    sub_atlas: dict[str, tuple[str, tuple[int, int, int, int]]] = {}
    resource_props: dict = {}
    legacy_slots: dict[tuple[str, int, int], str] = {}
    legacy_manifest = LEGACY_SLOT_ATLAS_MANIFESTS.get(tres_res_path)
    if legacy_manifest is not None:
        legacy = json.loads((ROOT / legacy_manifest).read_text(encoding="utf-8"))
        page_paths = {entry["page"]: entry["path"] for entry in legacy["pages"]}
        for entry in legacy["frames"]:
            legacy_slots[(page_paths[entry["page"]], entry["x"], entry["y"])] = entry["path"]
    for name, attrs, props in parsed["sections"]:
        if name == "ext_resource" and attrs.get("type") == "Texture2D":
            ext_paths[attrs["id"]] = attrs["path"]
        elif name == "sub_resource" and attrs.get("type") == "AtlasTexture":
            atlas = props.get("atlas")
            region = props.get("region")
            if not (isinstance(atlas, tuple) and atlas[0] == "ExtResource"):
                raise TresParseError(f"{tres_res_path}: AtlasTexture {attrs['id']} without ExtResource atlas")
            rect = tuple(int(v) for v in region[1])
            if "margin" in props:
                raise TresParseError(f"{tres_res_path}: already converted (margin present); use the manifest")
            sub_atlas[attrs["id"]] = (ext_paths[atlas[1][0]], rect)
        elif name == "resource":
            resource_props = props
    animations = []
    for entry in resource_props.get("animations", []):
        model = AnimationModel(_sname(entry["name"]), bool(entry.get("loop", True)), float(entry.get("speed", 5.0)))
        for frame in entry.get("frames", []):
            texture = frame["texture"]
            duration = float(frame.get("duration", 1.0))
            if texture[0] == "ExtResource":
                model.frames.append(FrameRef(duration, ext_paths[texture[1][0]]))
            elif texture[0] == "SubResource":
                page, rect = sub_atlas[texture[1][0]]
                source = legacy_slots.get((page, rect[0], rect[1]))
                if source is None:
                    raise TresParseError(f"{tres_res_path}: no retained source for slot {page} {rect}")
                model.frames.append(FrameRef(duration, source))
            else:
                raise TresParseError(f"{tres_res_path}: unsupported frame texture {texture!r}")
        animations.append(model)
    other_props = {k: v for k, v in resource_props.items() if k != "animations"}
    return PackModel(pack_id_for(tres_res_path), tres_res_path, animations, other_props)


def load_model_from_manifest(manifest: dict) -> PackModel:
    animations = [
        AnimationModel(
            entry["name"], bool(entry["loop"]), float(entry["speed"]),
            [FrameRef(float(frame["duration"]), frame["source"]) for frame in entry["frames"]],
        )
        for entry in manifest["animations"]
    ]
    return PackModel(manifest["pack"], manifest["tres"], animations, manifest.get("resource_props", {}))


def load_model(tres_res_path: str) -> PackModel:
    manifest_path = manifest_path_for(tres_res_path)
    if manifest_path.exists():
        return load_model_from_manifest(json.loads(manifest_path.read_text(encoding="utf-8")))
    return load_model_from_original_tres(tres_res_path)


# --- Trimming and packing -----------------------------------------------------


@dataclass
class Trim:
    key: str  # sha256 of the source pixels (dedup key)
    canvas: tuple[int, int]
    box: tuple[int, int, int, int]  # crop box in canvas pixels (x0, y0, x1, y1)
    image: Image.Image
    sources: list[str] = field(default_factory=list)
    page: int = -1
    x: int = 0
    y: int = 0

    @property
    def width(self) -> int:
        return self.box[2] - self.box[0]

    @property
    def height(self) -> int:
        return self.box[3] - self.box[1]


def load_trims(model: PackModel) -> tuple[dict[str, Trim], dict[str, str], dict[str, str]]:
    """Return (trims by key, source path -> key, source path -> file sha256)."""
    trims: dict[str, Trim] = {}
    source_key: dict[str, str] = {}
    source_sha: dict[str, str] = {}
    for animation in model.animations:
        for frame in animation.frames:
            if frame.source in source_key:
                continue
            path = res_to_path(frame.source)
            data = path.read_bytes()
            source_sha[frame.source] = hashlib.sha256(data).hexdigest()
            image = Image.open(path).convert("RGBA")
            key = hashlib.sha256(image.tobytes()).hexdigest()
            source_key[frame.source] = key
            if key in trims:
                trims[key].sources.append(frame.source)
                continue
            width, height = image.size
            bbox = image.getchannel("A").getbbox()
            if bbox is None:
                bbox = (0, 0, 1, 1)  # fully transparent frame: keep one texel
            box = (
                max(0, bbox[0] - PAD),
                max(0, bbox[1] - PAD),
                min(width, bbox[2] + PAD),
                min(height, bbox[3] + PAD),
            )
            trims[key] = Trim(key, (width, height), box, image.crop(box), [frame.source])
    return trims, source_key, source_sha


class _MaxRectsPage:
    """Max-rects bin packing (bottom-left rule), deterministic."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.free: list[tuple[int, int, int, int]] = [(0, 0, width, height)]
        self.used_height = 0

    def insert(self, w: int, h: int) -> tuple[int, int] | None:
        best = None
        best_key = None
        for (fx, fy, fw, fh) in self.free:
            if w > fw or h > fh:
                continue
            # Bottom-left: lowest top edge first, then leftmost — pages fill
            # compactly from the top so their final height stays small.
            key = (fy + h, fx, min(fw - w, fh - h))
            if best_key is None or key < best_key:
                best_key = key
                best = (fx, fy)
        if best is None:
            return None
        x, y = best
        placed = (x, y, w, h)
        next_free: list[tuple[int, int, int, int]] = []
        for rect in self.free:
            next_free.extend(_split_free_rect(rect, placed))
        self.free = _prune_free_rects(next_free)
        self.used_height = max(self.used_height, y + h)
        return best


def _split_free_rect(free: tuple[int, int, int, int], used: tuple[int, int, int, int]) -> list[tuple[int, int, int, int]]:
    fx, fy, fw, fh = free
    ux, uy, uw, uh = used
    if ux >= fx + fw or ux + uw <= fx or uy >= fy + fh or uy + uh <= fy:
        return [free]
    out = []
    if ux > fx:
        out.append((fx, fy, ux - fx, fh))
    if ux + uw < fx + fw:
        out.append((ux + uw, fy, fx + fw - (ux + uw), fh))
    if uy > fy:
        out.append((fx, fy, fw, uy - fy))
    if uy + uh < fy + fh:
        out.append((fx, uy + uh, fw, fy + fh - (uy + uh)))
    return out


def _prune_free_rects(rects: list[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    rects = sorted(set(rects))
    kept = []
    for i, a in enumerate(rects):
        contained = False
        for j, b in enumerate(rects):
            if i != j and a[0] >= b[0] and a[1] >= b[1] and a[0] + a[2] <= b[0] + b[2] and a[1] + a[3] <= b[1] + b[3] and a != b:
                contained = True
                break
            if i > j and a == b:
                contained = True
                break
        if not contained:
            kept.append(a)
    return kept


def pack_trims(trims: list[Trim]) -> list[tuple[int, int]]:
    """Pack trims into pages (mutates page/x/y); returns [(width, height)] per page."""
    total_area = sum((t.width + GUTTER) * (t.height + GUTTER) for t in trims)
    page_width = SMALL_PAGE_SIZE if total_area <= SMALL_PAGE_SIZE * SMALL_PAGE_SIZE else PAGE_SIZE
    ordered = sorted(trims, key=lambda t: (-(t.height + GUTTER), -(t.width + GUTTER), t.key))
    pages: list[_MaxRectsPage] = []
    for trim in ordered:
        w = trim.width + GUTTER
        h = trim.height + GUTTER
        if w > page_width or h > page_width:
            raise SystemExit(f"trim {trim.sources[0]} ({trim.width}x{trim.height}) exceeds page size")
        placed = None
        for index, page in enumerate(pages):
            spot = page.insert(w, h)
            if spot is not None:
                placed = (index, spot)
                break
        if placed is None:
            pages.append(_MaxRectsPage(page_width, page_width))
            spot = pages[-1].insert(w, h)
            placed = (len(pages) - 1, spot)
        index, (x, y) = placed
        trim.page = index
        trim.x = x + GUTTER // 2
        trim.y = y + GUTTER // 2
    return [(page.width, page.used_height) for page in pages]


def render_pages(trims: list[Trim], pages: list[tuple[int, int]]) -> list[Image.Image]:
    images = [Image.new("RGBA", size, (0, 0, 0, 0)) for size in pages]
    for trim in trims:
        images[trim.page].paste(trim.image, (trim.x, trim.y))
    return images


# --- Output -------------------------------------------------------------------


def _fmt_number(value: float) -> str:
    if float(value).is_integer():
        return f"{value:.1f}"
    return repr(float(value))


def _fmt_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return _fmt_number(value)
    if isinstance(value, str):
        return '"' + value.replace('"', '\\"') + '"'
    if isinstance(value, tuple):
        if value[0] == "StringName":
            return '&"' + value[1] + '"'
        return f"{value[0]}({', '.join(_fmt_value(a) for a in value[1])})"
    if isinstance(value, list):
        return "[" + ", ".join(_fmt_value(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{\n" + ",\n".join(f'"{k}": {_fmt_value(v)}' for k, v in value.items()) + "\n}"
    raise TypeError(type(value))


def render_tres(model: PackModel, trims_by_source: dict[str, Trim], page_count: int) -> str:
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for page in range(page_count):
        lines.append(f'[ext_resource type="Texture2D" path="{page_res_path(model.tres_path, page)}" id="page_{page}"]')
    lines.append(f'[ext_resource type="Script" path="{CANVAS_TEXTURE_SCRIPT}" id="canvas_script"]')
    lines.append(f'[ext_resource type="Script" path="{TRIM_ATLAS_SCRIPT}" id="trim_atlas_script"]')
    lines.append("")
    ordered_trims: list[Trim] = []
    seen = set()
    for animation in model.animations:
        for frame in animation.frames:
            trim = trims_by_source[frame.source]
            if trim.key not in seen:
                seen.add(trim.key)
                ordered_trims.append(trim)
    if not ordered_trims:
        raise ValueError(f"{model.pack_id}: no frames")
    canvases = {trim.canvas for trim in ordered_trims}
    if len(canvases) != 1:
        raise ValueError(f"{model.pack_id}: frames of different canvas sizes {sorted(canvases)} cannot share one pack")
    canvas_w, canvas_h = ordered_trims[0].canvas
    entry_index = {trim.key: index for index, trim in enumerate(ordered_trims)}
    entries: list[int] = []
    for trim in ordered_trims:
        entries += [trim.page, trim.x, trim.y, trim.width, trim.height, trim.box[0], trim.box[1]]
    lines += [
        f'[sub_resource type="Texture2D" id="{CANVAS_SUB_ID}"]',
        'script = ExtResource("canvas_script")',
        f"size = Vector2i({canvas_w}, {canvas_h})",
        "",
        f'[sub_resource type="Resource" id="{TRIM_ATLAS_SUB_ID}"]',
        'script = ExtResource("trim_atlas_script")',
        f"canvas = Vector2i({canvas_w}, {canvas_h})",
        "pages = Array[Texture2D]([" + ", ".join(f'ExtResource("page_{page}")' for page in range(page_count)) + "])",
        "entries = PackedInt32Array(" + ", ".join(str(value) for value in entries) + ")",
        "animations = {",
    ]
    animation_lines = []
    for animation in model.animations:
        indices = ", ".join(str(entry_index[trims_by_source[frame.source].key]) for frame in animation.frames)
        animation_lines.append(f'"{animation.name}": PackedInt32Array({indices})')
    lines.append(",\n".join(animation_lines))
    lines += ["}", "", "[resource]"]
    for key, value in model.resource_props.items():
        lines.append(f"{key} = {_fmt_value(value)}")
    lines.append(f'metadata/{TRIM_ATLAS_META} = SubResource("{TRIM_ATLAS_SUB_ID}")')
    animation_entries = []
    for animation in model.animations:
        frames = [
            {"duration": frame.duration, "texture": ("SubResource", (CANVAS_SUB_ID,))}
            for frame in animation.frames
        ]
        animation_entries.append({
            "frames": frames,
            "loop": animation.loop,
            "name": ("StringName", animation.name),
            "speed": animation.speed,
        })
    lines.append("animations = " + _fmt_value(animation_entries))
    return "\n".join(lines) + "\n"


def import_params_from(source_res_path: str) -> str:
    """Return the [params] block of a retained source's .import sidecar."""
    sidecar = res_to_path(source_res_path + ".import")
    text = sidecar.read_text(encoding="utf-8")
    match = re.search(r"\[params\]\n(.*)", text, re.S)
    if not match:
        raise SystemExit(f"{sidecar}: no [params] block")
    params = match.group(1).strip() + "\n"
    for key, expected in IMPORT_PARAMS_REQUIRED.items():
        if f"{key}={expected}" not in params:
            raise SystemExit(f"{sidecar}: expected {key}={expected} (lossless, no mipmaps)")
    return params


def render_import_sidecar(page_res: str, params: str, uid: str | None) -> str:
    digest = hashlib.md5(page_res.encode("utf-8")).hexdigest()
    dest = f"res://.godot/imported/{Path(page_res).name}-{digest}.ctex"
    lines = ["[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"']
    if uid:
        lines.append(f'uid="{uid}"')
    lines += [
        f'path="{dest}"',
        "metadata={",
        '"vram_texture": false',
        "}",
        "",
        "[deps]",
        "",
        f'source_file="{page_res}"',
        f'dest_files=["{dest}"]',
        "",
        "[params]",
        "",
        params,
    ]
    return "\n".join(lines)


def existing_uid(sidecar: Path) -> str | None:
    if not sidecar.exists():
        return None
    match = re.search(r'^uid="(uid://[^"]+)"', sidecar.read_text(encoding="utf-8"), re.M)
    return match.group(1) if match else None


def build_pack(tres_res_path: str) -> dict:
    model = load_model(tres_res_path)
    trims, source_key, source_sha = load_trims(model)
    trim_list = list(trims.values())
    pages = pack_trims(trim_list)
    page_images = render_pages(trim_list, pages)
    trims_by_source = {source: trims[key] for source, key in source_key.items()}
    tres_text = render_tres(model, trims_by_source, len(pages))
    source_bytes = sum(t.canvas[0] * t.canvas[1] * 4 for t in trim_list for _ in t.sources)
    page_bytes = sum(w * h * 4 for w, h in pages)
    manifest = {
        "version": MANIFEST_VERSION,
        "packer": PACKER,
        "pack": model.pack_id,
        "tres": tres_res_path,
        "pad": PAD,
        "gutter": GUTTER,
        "frames_total": sum(len(a.frames) for a in model.animations),
        "unique_frames": len(trim_list),
        "source_rgba_bytes": source_bytes,
        "page_rgba_bytes": page_bytes,
        "pages": [
            {"path": page_res_path(tres_res_path, index), "width": w, "height": h}
            for index, (w, h) in enumerate(pages)
        ],
        "sources": [{"path": path, "sha256": source_sha[path]} for path in sorted(source_sha)],
        "entries": [
            {
                "sources": sorted(t.sources),
                "page": t.page,
                "region": [t.x, t.y, t.width, t.height],
                "margin": [t.box[0], t.box[1], t.canvas[0] - t.width, t.canvas[1] - t.height],
                "canvas": [t.canvas[0], t.canvas[1]],
            }
            for t in sorted(trim_list, key=lambda t: (t.page, t.y, t.x))
        ],
        "animations": [
            {
                "name": a.name,
                "loop": a.loop,
                "speed": a.speed,
                "frames": [{"duration": f.duration, "source": f.source} for f in a.frames],
            }
            for a in model.animations
        ],
        "resource_props": model.resource_props,
        "import_params_source": model.animations[0].frames[0].source,
    }
    return {
        "model": model,
        "pages": pages,
        "page_images": page_images,
        "tres_text": tres_text,
        "manifest": manifest,
    }


def write_pack(result: dict) -> None:
    model: PackModel = result["model"]
    manifest = result["manifest"]
    params = import_params_from(manifest["import_params_source"])
    for index, image in enumerate(result["page_images"]):
        page_res = page_res_path(model.tres_path, index)
        page_path = res_to_path(page_res)
        image.save(page_path, format="PNG", optimize=True)
        sidecar = page_path.with_name(page_path.name + ".import")
        sidecar.write_text(render_import_sidecar(page_res, params, existing_uid(sidecar)), encoding="utf-8")
    # Stale pages from a previous, larger layout.
    directory = res_to_path(model.tres_path).parent
    for stale in directory.glob(f"{model.pack_id}{PAGE_SUFFIX}*.png"):
        if stale.name not in {Path(p["path"]).name for p in manifest["pages"]}:
            stale.unlink()
            stale_sidecar = stale.with_name(stale.name + ".import")
            if stale_sidecar.exists():
                stale_sidecar.unlink()
    for index, page in enumerate(manifest["pages"]):
        page["sha256"] = hashlib.sha256(res_to_path(page["path"]).read_bytes()).hexdigest()
    res_to_path(model.tres_path).write_text(result["tres_text"], encoding="utf-8")
    manifest_path_for(model.tres_path).write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")


def check_pack(result: dict) -> list[str]:
    model: PackModel = result["model"]
    problems = []
    manifest_path = manifest_path_for(model.tres_path)
    if not manifest_path.exists():
        return [f"{model.pack_id}: manifest {manifest_path} missing (pack not converted)"]
    committed = json.loads(manifest_path.read_text(encoding="utf-8"))
    computed = result["manifest"]
    for key in ("pages", "entries", "animations", "sources", "pad", "gutter", "frames_total", "unique_frames"):
        committed_value = committed.get(key)
        computed_value = computed.get(key)
        if key == "pages":
            committed_value = [{k: v for k, v in p.items() if k != "sha256"} for p in committed_value or []]
        if committed_value != computed_value:
            problems.append(f"{model.pack_id}: manifest '{key}' differs from the packing computed from the sources")
    for index, image in enumerate(result["page_images"]):
        page_path = res_to_path(page_res_path(model.tres_path, index))
        if not page_path.exists():
            problems.append(f"{model.pack_id}: page {page_path.name} missing")
            continue
        on_disk = Image.open(page_path).convert("RGBA")
        if on_disk.size != image.size or on_disk.tobytes() != image.tobytes():
            problems.append(f"{model.pack_id}: page {page_path.name} pixels differ from the sources")
        recorded = next((p.get("sha256") for p in committed.get("pages", []) if p["path"] == page_res_path(model.tres_path, index)), None)
        if recorded != hashlib.sha256(page_path.read_bytes()).hexdigest():
            problems.append(f"{model.pack_id}: page {page_path.name} hash differs from the manifest")
        sidecar = page_path.with_name(page_path.name + ".import")
        if not sidecar.exists():
            problems.append(f"{model.pack_id}: {sidecar.name} missing")
        else:
            text = sidecar.read_text(encoding="utf-8")
            for key, expected in IMPORT_PARAMS_REQUIRED.items():
                if f"{key}={expected}" not in text:
                    problems.append(f"{model.pack_id}: {sidecar.name} must declare {key}={expected}")
    if res_to_path(model.tres_path).read_text(encoding="utf-8") != result["tres_text"]:
        problems.append(f"{model.pack_id}: committed .tres differs from the rendered form")
    return problems


def report_rows(results: list[dict]) -> list[str]:
    rows = ["| pack | frames | unique | pages | source RGBA MiB | page RGBA MiB | ratio |", "|---|---|---|---|---|---|---|"]
    total_source = total_page = 0
    for result in results:
        manifest = result["manifest"]
        src = manifest["source_rgba_bytes"]
        page = manifest["page_rgba_bytes"]
        total_source += src
        total_page += page
        rows.append(
            f"| {manifest['pack']} | {manifest['frames_total']} | {manifest['unique_frames']} | {len(manifest['pages'])} "
            f"| {src / 2**20:.1f} | {page / 2**20:.1f} | {src / max(page, 1):.1f}x |"
        )
    rows.append(f"| **total** | | | | {total_source / 2**20:.1f} | {total_page / 2**20:.1f} | {total_source / max(total_page, 1):.1f}x |")
    return rows


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="verify committed pages/manifests/tres instead of writing")
    parser.add_argument("--report", action="store_true", help="print the before/after texture-bytes table")
    parser.add_argument("--only", nargs="*", default=None, help="pack ids to process (default: all)")
    args = parser.parse_args(argv)
    packs = discover_packs()
    if args.only:
        packs = [p for p in packs if pack_id_for(p) in set(args.only)]
        missing = set(args.only) - {pack_id_for(p) for p in packs}
        if missing:
            parser.error(f"unknown pack ids: {sorted(missing)}")
    results = []
    problems: list[str] = []
    for tres_res_path in packs:
        result = build_pack(tres_res_path)
        results.append(result)
        if args.check:
            problems += check_pack(result)
        elif not args.report:
            write_pack(result)
            manifest = result["manifest"]
            print(f"{manifest['pack']}: {manifest['frames_total']} frames ({manifest['unique_frames']} unique) -> "
                  f"{len(manifest['pages'])} page(s), {manifest['source_rgba_bytes'] / 2**20:.0f} -> {manifest['page_rgba_bytes'] / 2**20:.0f} MiB RGBA")
    if args.report:
        print("\n".join(report_rows(results)))
    if args.check:
        for problem in problems:
            print("CHECK FAIL:", problem)
        print("TRIM ATLAS CHECK " + ("OK" if not problems else "FAILED") + f" ({len(results)} packs)")
        return 0 if not problems else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
