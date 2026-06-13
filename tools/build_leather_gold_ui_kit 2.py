#!/usr/bin/env python3
"""Build leather+gold panel/window UI frames from user-provided references."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
REF_DIR = ROOT / "docs/design/references/interface"
OUT_DIR = ROOT / "assets/sprites/ui/frames/leather_gold"
DF_DIR = ROOT / "assets/sprites/ui/frames/dark_fantasy"
GLOBAL_DIR = ROOT / "assets/sprites/ui/frames/global"
ESCAPE_DIR = ROOT / "assets/sprites/ui/frames/escape"
SHOP_DIR = ROOT / "assets/sprites/ui/shop"
SYSTEM_DIR = ROOT / "assets/sprites/ui/icons/system"
PREVIEW_PATH = ROOT / "docs/design/previews/interface_leather_gold_panel_kit_contact.png"

REFS = {
	"square": "ChatGPT Image Jun 13, 2026, 08_12_22 PM (1).png",
	"wide": "ChatGPT Image Jun 13, 2026, 08_12_23 PM (2).png",
	"check": "ChatGPT Image Jun 13, 2026, 08_12_23 PM (3).png",
	"bar": "ChatGPT Image Jun 13, 2026, 08_12_23 PM (4).png",
	"window": "ChatGPT Image Jun 13, 2026, 08_12_24 PM (5).png",
}

CANONICAL = {
	"ui_panel_leather_gold_square.png": ("square", (512, 512)),
	"ui_panel_leather_gold_wide.png": ("wide", (768, 384)),
	"ui_bar_leather_gold_thin.png": ("bar", (640, 96)),
	"ui_window_leather_gold_main.png": ("window", (768, 512)),
	"ui_check_leather_gold.png": ("check", (256, 256)),
}

LIVE_REPLACEMENTS = {
	DF_DIR / "ui_df_panel_frame.png": ("window", (768, 512)),
	DF_DIR / "ui_df_card_frame.png": ("square", (384, 256)),
	DF_DIR / "ui_df_hud_card_frame.png": ("wide", (256, 96)),
	DF_DIR / "ui_df_hud_panel_frame.png": ("bar", (512, 128)),
	DF_DIR / "ui_df_level_panel_frame.png": ("window", (640, 384)),
	DF_DIR / "ui_df_tooltip_frame.png": ("wide", (512, 256)),
	DF_DIR / "ui_df_stat_row_frame.png": ("bar", (512, 80)),
	DF_DIR / "ui_df_stat_chip_frame.png": ("bar", (384, 80)),
	DF_DIR / "ui_df_shop_frame.png": ("wide", (640, 320)),
	DF_DIR / "ui_df_section_divider.png": ("bar", (640, 24)),
	DF_DIR / "ui_df_stat_value_state_swatches.png": ("wide", (640, 144)),
	GLOBAL_DIR / "ui_panel_frame.png": ("square", (128, 128)),
	GLOBAL_DIR / "ui_card_frame.png": ("square", (128, 128)),
	GLOBAL_DIR / "ui_hud_card_frame.png": ("wide", (96, 72)),
	GLOBAL_DIR / "ui_hud_panel_frame.png": ("wide", (128, 96)),
	GLOBAL_DIR / "ui_level_panel_frame.png": ("window", (160, 160)),
	GLOBAL_DIR / "ui_tooltip_frame.png": ("wide", (128, 96)),
	ESCAPE_DIR / "ui_escape_panel_frame.png": ("window", (512, 512)),
	ESCAPE_DIR / "ui_stat_basic_row_frame.png": ("bar", (512, 80)),
	ESCAPE_DIR / "ui_stat_group_frame.png": ("wide", (640, 320)),
	ESCAPE_DIR / "ui_stat_chip_frame.png": ("bar", (384, 80)),
	ESCAPE_DIR / "ui_stat_section_divider.png": ("bar", (640, 24)),
	ESCAPE_DIR / "ui_stat_tooltip_frame.png": ("wide", (640, 320)),
	ESCAPE_DIR / "ui_stat_value_state_swatches.png": ("wide", (640, 144)),
	SHOP_DIR / "ui_shop_artifact_slot_frame.png": ("square", (256, 256)),
	SHOP_DIR / "ui_shop_artifact_slot_hover.png": ("square", (256, 256)),
	SHOP_DIR / "ui_shop_price_badge.png": ("bar", (256, 96)),
	SHOP_DIR / "ui_shop_purchased_overlay.png": ("check", (256, 256)),
	SHOP_DIR / "ui_shop_tooltip_frame.png": ("wide", (640, 320)),
	SYSTEM_DIR / "ui_checkbox_unchecked.png": ("square", (64, 64)),
	SYSTEM_DIR / "ui_checkbox_checked.png": ("check", (64, 64)),
}


def is_checker_background_pixel(pixel: tuple[int, int, int, int]) -> bool:
	r, g, b, a = pixel
	if a < 8:
		return True
	return r > 202 and g > 202 and b > 202 and max(r, g, b) - min(r, g, b) < 26


def remove_edge_checker(path: Path) -> Image.Image:
	image = Image.open(path).convert("RGBA")
	pixels = image.load()
	width, height = image.size
	seen = set()
	queue: deque[tuple[int, int]] = deque()
	for x in range(width):
		queue.append((x, 0))
		queue.append((x, height - 1))
	for y in range(height):
		queue.append((0, y))
		queue.append((width - 1, y))
	while queue:
		x, y = queue.popleft()
		if (x, y) in seen or x < 0 or y < 0 or x >= width or y >= height:
			continue
		seen.add((x, y))
		if not is_checker_background_pixel(pixels[x, y]):
			continue
		pixels[x, y] = (0, 0, 0, 0)
		queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
	bbox = image.getchannel("A").getbbox()
	if bbox is None:
		raise RuntimeError(f"No non-transparent pixels after cleanup: {path}")
	# Preserve antialiasing around the cleaned frame.
	pad = 6
	bbox = (
		max(0, bbox[0] - pad),
		max(0, bbox[1] - pad),
		min(width, bbox[2] + pad),
		min(height, bbox[3] + pad),
	)
	return image.crop(bbox)


def fit_asset(source: Image.Image, size: tuple[int, int], *, boost: bool = True) -> Image.Image:
	image = source.resize(size, Image.Resampling.LANCZOS)
	if boost:
		alpha = image.getchannel("A")
		rgb = Image.merge("RGB", image.split()[:3])
		rgb = ImageEnhance.Contrast(rgb).enhance(1.08)
		rgb = ImageEnhance.Sharpness(rgb).enhance(1.10)
		image = Image.merge("RGBA", (*rgb.split(), alpha))
	return image


def add_hover_glow(image: Image.Image) -> Image.Image:
	alpha = image.getchannel("A")
	glow_alpha = ImageEnhance.Brightness(alpha.filter(ImageFilter.GaussianBlur(3))).enhance(0.42)
	glow = Image.new("RGBA", image.size, (255, 184, 74, 255))
	glow.putalpha(glow_alpha)
	return Image.alpha_composite(glow, image)


def validate_png(path: Path, size: tuple[int, int]) -> None:
	image = Image.open(path).convert("RGBA")
	if image.size != size:
		raise AssertionError(f"{path} has size {image.size}, expected {size}")
	if image.getchannel("A").getbbox() is None:
		raise AssertionError(f"{path} has empty alpha")


def checker(size: tuple[int, int], tile: int = 12) -> Image.Image:
	width, height = size
	bg = Image.new("RGBA", size, (31, 28, 25, 255))
	pixels = bg.load()
	for y in range(height):
		for x in range(width):
			if ((x // tile) + (y // tile)) % 2:
				pixels[x, y] = (48, 42, 36, 255)
	return bg


def make_preview(samples: dict[str, Image.Image]) -> None:
	PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
	items = [
		("window", samples["window"], (260, 190)),
		("square", samples["square"], (190, 190)),
		("wide", samples["wide"], (300, 150)),
		("bar", samples["bar"], (320, 64)),
		("check", samples["check"], (140, 140)),
		("panel", Image.open(DF_DIR / "ui_df_panel_frame.png").convert("RGBA"), (300, 200)),
		("row", Image.open(DF_DIR / "ui_df_stat_row_frame.png").convert("RGBA"), (300, 54)),
		("shop", Image.open(SHOP_DIR / "ui_shop_artifact_slot_hover.png").convert("RGBA"), (150, 150)),
	]
	sheet = Image.new("RGBA", (980, 640), (18, 15, 13, 255))
	for index, (_name, image, box_size) in enumerate(items):
		x = 26 + (index % 3) * 315
		y = 24 + (index // 3) * 205
		panel = checker((285, 175), 10)
		thumb = image.copy()
		thumb.thumbnail(box_size, Image.Resampling.LANCZOS)
		panel.alpha_composite(thumb, ((panel.width - thumb.width) // 2, (panel.height - thumb.height) // 2))
		sheet.alpha_composite(panel, (x, y))
	sheet.save(PREVIEW_PATH)


def main() -> None:
	for directory in (OUT_DIR, DF_DIR, GLOBAL_DIR, ESCAPE_DIR, SHOP_DIR, SYSTEM_DIR):
		directory.mkdir(parents=True, exist_ok=True)
	cleaned = {key: remove_edge_checker(REF_DIR / filename) for key, filename in REFS.items()}
	for filename, (source_key, size) in CANONICAL.items():
		output = OUT_DIR / filename
		fit_asset(cleaned[source_key], size).save(output)
		validate_png(output, size)
	for output, (source_key, size) in LIVE_REPLACEMENTS.items():
		image = fit_asset(cleaned[source_key], size)
		if output.name in {"ui_shop_artifact_slot_hover.png"}:
			image = add_hover_glow(image)
		output.parent.mkdir(parents=True, exist_ok=True)
		image.save(output)
		validate_png(output, size)
	make_preview(cleaned)
	print(f"Built leather+gold UI kit: {len(CANONICAL) + len(LIVE_REPLACEMENTS)} PNGs")
	print(f"Preview: {PREVIEW_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
	main()
