#!/usr/bin/env python3
"""Build the FAN-1903 geometry-evidence SVG/PNG matrix."""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from html import escape
from math import ceil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
REFERENCE_DIR = Path(__file__).resolve().parent
PREVIEW_DIR = ROOT / "docs/design/previews/fan1883_attribute_clarity"
FONT_REGULAR = Path("/System/Library/Fonts/Supplemental/Arial.ttf")
FONT_BOLD = Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf")

COLORS = {
    "bg": "#0a0b12",
    "surface": "#17141a",
    "zone": "#253543",
    "card": "#211e26",
    "cap": "#412826",
    "ok": "#214334",
    "muted": "#25262c",
    "gold": "#bd9149",
    "blue": "#65bde7",
    "green": "#70d99a",
    "base": "#f3e4b2",
    "s": "#c6d5df",
    "note": "#87cdf3",
    "warn": "#f0b270",
}
VIEWPORTS = ((1280, 720), (1920, 1080), (2560, 1440))
SURFACES = ("level_up", "attribute_shop", "pause_codex", "hero_select")
POLICIES = {
    "level_up": "uniform authored stage (0.667 / 1.0 / 1.333)",
    "attribute_shop": "live compact / authored / live large tiers",
    "pause_codex": "uniform authored stage (0.667 / 1.0 / 1.333)",
    "hero_select": "live compact / authored / live large; stats 2×4 / 1×8 / 1×8",
}


@dataclass(frozen=True)
class Rect:
    x: int
    y: int
    w: int
    h: int

    @property
    def right(self) -> int:
        return self.x + self.w

    @property
    def bottom(self) -> int:
        return self.y + self.h


def scaled(rect: Rect, factor: float) -> Rect:
    return Rect(
        round(rect.x * factor),
        round(rect.y * factor),
        round(rect.w * factor),
        round(rect.h * factor),
    )


class Canvas:
    def __init__(self, surface: str, width: int, height: int) -> None:
        self.surface = surface
        self.width = width
        self.height = height
        self.image = Image.new("RGBA", (width, height), COLORS["bg"])
        self.draw = ImageDraw.Draw(self.image)
        self.svg = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
            f'height="{height}" viewBox="0 0 {width} {height}">',
            f'<style>.s{{fill:{COLORS["s"]}}}.note{{fill:{COLORS["note"]}}}'
            f'.warn{{fill:{COLORS["warn"]}}}</style>',
            f'<rect x="0" y="0" width="{width}" height="{height}" fill="{COLORS["bg"]}"/>',
        ]
        self.gaps: dict[str, tuple[float, float]] = {}

    @staticmethod
    def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
        return ImageFont.truetype(str(FONT_BOLD if bold else FONT_REGULAR), max(8, size))

    def rect(
        self,
        rect: Rect,
        *,
        fill: str,
        stroke: str = "",
        stroke_width: int = 0,
        radius: int = 0,
        dashed: bool = False,
    ) -> None:
        xy = (rect.x, rect.y, rect.right, rect.bottom)
        self.draw.rounded_rectangle(
            xy,
            radius=radius,
            fill=fill,
            outline=stroke or None,
            width=max(1, stroke_width) if stroke else 1,
        )
        dash = ' stroke-dasharray="8 6"' if dashed else ""
        self.svg.append(
            f'<rect x="{rect.x}" y="{rect.y}" width="{rect.w}" height="{rect.h}" '
            f'rx="{radius}" fill="{fill}" stroke="{stroke or "none"}" '
            f'stroke-width="{stroke_width}"{dash}/>'
        )

    def ellipse(
        self,
        rect: Rect,
        *,
        fill: str,
        stroke: str = "",
        stroke_width: int = 0,
    ) -> None:
        xy = (rect.x, rect.y, rect.right, rect.bottom)
        self.draw.ellipse(xy, fill=fill, outline=stroke or None, width=max(1, stroke_width))
        self.svg.append(
            f'<ellipse cx="{rect.x + rect.w / 2:g}" cy="{rect.y + rect.h / 2:g}" '
            f'rx="{rect.w / 2:g}" ry="{rect.h / 2:g}" fill="{fill}" '
            f'stroke="{stroke or "none"}" stroke-width="{stroke_width}"/>'
        )

    def line(self, points: tuple[tuple[int, int], ...], *, fill: str, width: int = 1) -> None:
        self.draw.line(points, fill=fill, width=width)
        values = " ".join(f"{x},{y}" for x, y in points)
        self.svg.append(
            f'<polyline points="{values}" fill="none" stroke="{fill}" stroke-width="{width}"/>'
        )

    def text(
        self,
        x: int,
        y: int,
        value: str,
        *,
        size: int,
        role: str = "base",
        bold: bool = False,
        track: tuple[str, Rect, float] | None = None,
    ) -> tuple[int, int, int, int]:
        font = self._font(size, bold)
        fill = COLORS[role]
        self.draw.text((x, y), value, font=font, fill=fill)
        bbox = self.draw.textbbox((x, y), value, font=font)
        self.svg.append(
            f'<text class="{role}" x="{x}" y="{y + size}" font-family="Arial, sans-serif" '
            f'font-size="{size}" font-weight="{"bold" if bold else "normal"}" '
            f'fill="{fill}">{escape(value)}</text>'
        )
        if track is not None:
            label, container, required = track
            gap = min(bbox[0] - container.x, container.right - bbox[2])
            old_gap = self.gaps.get(label, (float("inf"), required))[0]
            self.gaps[label] = (min(old_gap, float(gap)), required)
        return bbox

    def wrap(self, value: str, *, size: int, max_width: int, bold: bool = False) -> list[str]:
        font = self._font(size, bold)
        lines: list[str] = []
        current = ""
        for word in value.split():
            candidate = word if not current else f"{current} {word}"
            width = self.draw.textbbox((0, 0), candidate, font=font)[2]
            if current and width > max_width:
                lines.append(current)
                current = word
            else:
                current = candidate
        if current:
            lines.append(current)
        return lines

    def wrapped_text(
        self,
        x: int,
        y: int,
        value: str,
        *,
        size: int,
        max_width: int,
        line_height: int,
        role: str = "s",
        bold: bool = False,
        track: tuple[str, Rect, float] | None = None,
    ) -> int:
        lines = self.wrap(value, size=size, max_width=max_width, bold=bold)
        for index, line in enumerate(lines):
            self.text(
                x,
                y + index * line_height,
                line,
                size=size,
                role=role,
                bold=bold,
                track=track,
            )
        return len(lines) * line_height

    def save(self, stem: str) -> tuple[Path, Path]:
        PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
        svg_path = REFERENCE_DIR / f"{stem}.svg"
        png_path = PREVIEW_DIR / f"{stem}.png"
        svg_path.write_text("\n".join((*self.svg, "</svg>\n")), encoding="utf-8")
        self.image.save(png_path, "PNG", optimize=True)
        return svg_path, png_path


def frame(canvas: Canvas, rect: Rect, *, fill: str = "surface", stroke: str = "gold") -> None:
    canvas.rect(
        rect,
        fill=COLORS[fill],
        stroke=COLORS[stroke],
        stroke_width=max(2, round(canvas.height / 540)),
        radius=max(6, round(canvas.height / 90)),
    )


def draw_scrollbar(canvas: Canvas, rect: Rect, reserve: int) -> None:
    track = Rect(rect.right - reserve, rect.y + 6, max(4, reserve // 3), max(16, rect.h - 12))
    canvas.rect(track, fill="#111820", stroke=COLORS["blue"], stroke_width=1, radius=2)
    thumb = Rect(track.x, track.y + max(2, track.h // 5), track.w, max(12, track.h // 3))
    canvas.rect(thumb, fill=COLORS["note"], radius=2)


def level_up(viewport: tuple[int, int]) -> Canvas:
    width, height = viewport
    scale = width / 1920.0
    canvas = Canvas("level_up", width, height)
    title = scaled(Rect(560, 92, 800, 64), scale)
    banner = scaled(Rect(270, 194, 1380, 44), scale)
    offer = scaled(Rect(270, 254, 1380, 490), scale)
    drawer = scaled(Rect(510, 770, 900, 190), scale)
    cont = scaled(Rect(760, 978, 400, 64), scale)
    card_rects = [scaled(Rect(270 + index * 472, 254, 436, 490), scale) for index in range(3)]
    margin = ceil(32 * scale)
    card_font = max(11, round(20 * scale))
    small_font = max(9, round(17 * scale))
    title_font = max(15, round(31 * scale))

    canvas.text(
        title.x + round(22 * scale),
        title.y + round(10 * scale),
        f"LEVEL UP · {width}×{height}",
        size=title_font,
        role="base",
        bold=True,
    )
    canvas.text(
        title.x + round(22 * scale),
        title.y + round(43 * scale),
        "authored cards · normal + filtered + capped + long-copy",
        size=max(8, round(14 * scale)),
        role="note",
    )
    canvas.rect(
        banner,
        fill=COLORS["muted"],
        stroke="#737984",
        stroke_width=max(1, round(2 * scale)),
        radius=max(3, round(8 * scale)),
        dashed=True,
    )
    canvas.text(
        banner.x + margin,
        banner.y + max(3, round(9 * scale)),
        "class_ineligible / zero_effective_delta: отфильтровано до раскладки; пустого слота нет",
        size=max(8, round(15 * scale)),
        role="s",
        track=("LU.FilteredBanner", banner, margin),
    )
    canvas.rect(
        offer,
        fill=COLORS["surface"],
        stroke=COLORS["blue"],
        stroke_width=max(1, round(2 * scale)),
        radius=max(4, round(12 * scale)),
    )

    cards = (
        (
            "Добавление урона",
            "Магический урон",
            "84 → 92",
            "реально: +8 урона",
            "",
        ),
        (
            "Шанс крита",
            "Критический удар срабатывает чаще",
            "34% → 39%",
            "реально: +5 п.п.",
            "сейчас 34% · максимум 62%",
        ),
        (
            "Регенерация",
            "Восстанавливаете HP со временем",
            "1.6 → 2.9 HP/с",
            "реально: +1.3 HP/с",
            "",
        ),
    )
    for index, (name, effect, before_after, delta, cap) in enumerate(cards):
        card = card_rects[index]
        canvas.rect(
            card,
            fill=COLORS["card"],
            stroke=COLORS["gold"],
            stroke_width=max(2, round(3 * scale)),
            radius=max(5, round(12 * scale)),
        )
        icon_side = max(24, round(48 * scale))
        canvas.ellipse(
            Rect(card.x + margin, card.y + margin, icon_side, icon_side),
            fill="#5a4934",
            stroke=COLORS["gold"],
            stroke_width=max(1, round(2 * scale)),
        )
        text_x = card.x + margin
        canvas.text(
            text_x,
            card.y + round(96 * scale),
            name,
            size=max(12, round(26 * scale)),
            role="base",
            bold=True,
        )
        canvas.wrapped_text(
            text_x,
            card.y + round(143 * scale),
            effect,
            size=small_font,
            max_width=card.w - margin * 2,
            line_height=max(12, round(24 * scale)),
            role="s",
        )
        canvas.text(
            text_x,
            card.y + round(239 * scale),
            before_after,
            size=card_font,
            role="base",
        )
        badge = scaled(Rect(318 + index * 472, 538, 340, 34), scale)
        canvas.rect(
            badge,
            fill=COLORS["ok"],
            stroke=COLORS["green"],
            stroke_width=max(1, round(scale)),
            radius=max(3, round(7 * scale)),
        )
        canvas.text(
            badge.x + max(5, round(10 * scale)),
            badge.y + max(2, round(5 * scale)),
            delta,
            size=small_font,
            role="s",
            track=("LU.Card.delta_badge", card, margin),
        )
        if cap:
            cap_slot = scaled(Rect(318 + index * 472, 600, 340, 28), scale)
            canvas.rect(cap_slot, fill=COLORS["cap"], radius=max(2, round(5 * scale)))
            canvas.text(
                cap_slot.x + max(5, round(8 * scale)),
                cap_slot.y + max(1, round(4 * scale)),
                cap,
                size=max(9, round(16 * scale)),
                role="warn",
                track=("LU.Card.cap_line", card, margin),
            )
    canvas.rect(
        drawer,
        fill=COLORS["zone"],
        stroke=COLORS["blue"],
        stroke_width=max(1, round(2 * scale)),
        radius=max(4, round(10 * scale)),
    )
    drawer_margin = ceil(32 * scale)
    reserve = ceil(16 * scale)
    copy = (
        "Длинное объяснение: увеличение области атаки расширяет радиусы аур, ширину лучей, "
        "секторные атаки и взрывы; весь русский текст переносится и остаётся доступен в "
        "прокрутке без многоточия."
    )
    canvas.wrapped_text(
        drawer.x + drawer_margin,
        drawer.y + ceil(24 * scale),
        copy,
        size=max(9, round(17 * scale)),
        max_width=drawer.w - drawer_margin * 2 - reserve - max(4, round(8 * scale)),
        line_height=max(12, round(25 * scale)),
        role="note",
        track=("LU.DetailDrawer.long_copy", drawer, drawer_margin),
    )
    draw_scrollbar(canvas, drawer, reserve)
    canvas.rect(
        cont,
        fill=COLORS["card"],
        stroke=COLORS["gold"],
        stroke_width=max(1, round(2 * scale)),
        radius=max(4, round(10 * scale)),
    )
    canvas.text(
        cont.x + round(100 * scale),
        cont.y + round(17 * scale),
        "Продолжить",
        size=max(11, round(22 * scale)),
        bold=True,
    )
    return canvas


SHOP_LAYOUTS = {
    (1280, 720): {
        "inner": Rect(133, 113, 1014, 494),
        "title": Rect(451, 119, 378, 50),
        "money": Rect(157, 123, 240, 42),
        "offer": Rect(204, 194, 872, 258),
        "card": (276, 258, 22),
        "drawer": Rect(204, 462, 872, 52),
        "actions": Rect(300, 524, 680, 64),
        "margin": 28,
        "font": 16,
    },
    (1920, 1080): {
        "inner": Rect(200, 169, 1520, 742),
        "title": Rect(710, 126, 500, 60),
        "money": Rect(140, 138, 380, 50),
        "offer": Rect(350, 286, 1220, 410),
        "card": (360, 410, 70),
        "drawer": Rect(470, 704, 980, 132),
        "actions": Rect(590, 866, 740, 72),
        "margin": 28,
        "font": 20,
    },
    (2560, 1440): {
        "inner": Rect(267, 225, 2026, 990),
        "title": Rect(930, 235, 700, 64),
        "money": Rect(291, 245, 480, 64),
        "offer": Rect(470, 398, 1620, 540),
        "card": (460, 540, 120),
        "drawer": Rect(600, 950, 1360, 120),
        "actions": Rect(650, 1092, 1260, 88),
        "margin": 36,
        "font": 25,
    },
}


def attribute_shop(viewport: tuple[int, int]) -> Canvas:
    width, height = viewport
    layout = SHOP_LAYOUTS[viewport]
    canvas = Canvas("attribute_shop", width, height)
    inner: Rect = layout["inner"]
    title: Rect = layout["title"]
    money: Rect = layout["money"]
    offer: Rect = layout["offer"]
    drawer: Rect = layout["drawer"]
    actions: Rect = layout["actions"]
    card_w, card_h, gap = layout["card"]
    margin = layout["margin"]
    font = layout["font"]

    shell = Rect(
        max(12, inner.x - round(width * 0.06)),
        max(10, inner.y - round(height * 0.07)),
        min(width - 24, inner.w + round(width * 0.12)),
        min(height - 20, inner.h + round(height * 0.14)),
    )
    frame(canvas, shell)
    canvas.rect(inner, fill="#11131a", stroke=COLORS["gold"], stroke_width=2, radius=10)
    canvas.text(
        title.x + max(8, title.w // 8),
        title.y + max(4, title.h // 8),
        f"ДОКАЧКА · {width}×{height}",
        size=max(16, round(font * 1.25)),
        role="base",
        bold=True,
    )
    canvas.text(
        money.x,
        money.y + 6,
        "Золото: 480",
        size=max(13, font - 2),
        role="note",
    )
    canvas.rect(offer, fill=COLORS["surface"], stroke=COLORS["blue"], stroke_width=2, radius=10)
    card_data = (
        ("Сила +1", "Физический урон", "84 → 92", "реально: +8 урона"),
        ("Ловкость +1", "Критический шанс", "36% → 36.5%", "реально: +0.5 п.п."),
        ("Выносливость +1", "Максимальное здоровье", "102 → 110 HP", "реально: +8 HP"),
    )
    for index, (name, effect, before_after, delta) in enumerate(card_data):
        card = Rect(offer.x + index * (card_w + gap), offer.y, card_w, card_h)
        canvas.rect(card, fill=COLORS["card"], stroke=COLORS["gold"], stroke_width=3, radius=10)
        text_x = card.x + margin
        y = card.y + margin
        canvas.text(text_x, y, name, size=max(15, font + 2), bold=True)
        y += round(font * 2.1)
        used = canvas.wrapped_text(
            text_x,
            y,
            effect,
            size=max(12, font - 2),
            max_width=card.w - margin * 2,
            line_height=max(16, round(font * 1.25)),
            role="s",
            track=("AS.Card.longest_line", card, margin),
        )
        y += used + round(font * 0.8)
        canvas.text(text_x, y, before_after, size=font, role="base")
        y += round(font * 2.0)
        badge = Rect(text_x, y, card.w - margin * 2, max(28, round(font * 1.7)))
        canvas.rect(badge, fill=COLORS["ok"], stroke=COLORS["green"], stroke_width=1, radius=6)
        canvas.text(
            badge.x + 8,
            badge.y + max(2, round(font * 0.18)),
            delta,
            size=max(11, font - 3),
            role="s",
            track=("AS.Card.delta_badge", card, margin),
        )
    canvas.rect(drawer, fill=COLORS["zone"], stroke=COLORS["blue"], stroke_width=2, radius=8)
    drawer_margin = margin
    canvas.text(
        drawer.x + drawer_margin,
        drawer.y + max(2, round(font * 0.18)),
        "cap_reached / zero delta: удалено до CTA",
        size=max(9, font - 6),
        role="warn",
    )
    note = (
        "После eligibility-filter остаются только полезные предложения; ряд центрируется заново, "
        "а длинное пояснение открывается в прокрутке без обрезки."
    )
    canvas.wrapped_text(
        drawer.x + drawer_margin,
        drawer.y + max(15, round(font * 0.95)),
        note,
        size=max(11, font - 4),
        max_width=drawer.w - drawer_margin * 2 - 18,
        line_height=max(14, round(font * 1.15)),
        role="note",
        track=("AS.DetailDrawer.copy", drawer, drawer_margin),
    )
    draw_scrollbar(canvas, drawer, 14)
    canvas.rect(actions, fill=COLORS["muted"], stroke=COLORS["gold"], stroke_width=2, radius=8)
    canvas.text(
        actions.x + max(20, actions.w // 6),
        actions.y + max(8, actions.h // 4),
        "Обновить предложения",
        size=max(13, font - 2),
        role="base",
        bold=True,
    )
    canvas.text(
        actions.x + actions.w * 2 // 3,
        actions.y + max(8, actions.h // 4),
        "Пропустить",
        size=max(13, font - 2),
        role="s",
        bold=True,
    )
    return canvas


def pause_codex(viewport: tuple[int, int]) -> Canvas:
    width, height = viewport
    scale = width / 1920.0
    canvas = Canvas("pause_codex", width, height)
    nav = scaled(Rect(72, 172, 324, 840), scale)
    filtered_banner = scaled(Rect(452, 218, 556, 44), scale)
    axis_list = scaled(Rect(452, 278, 556, 690), scale)
    detail = scaled(Rect(1064, 172, 784, 840), scale)
    cap_chip = scaled(Rect(1432, 396, 330, 70), scale)
    row_margin = ceil(18 * scale)
    detail_margin = ceil(32 * scale)
    body_font = max(10, round(18 * scale))
    small_font = max(9, round(15 * scale))

    canvas.text(
        round(72 * scale),
        round(44 * scale),
        f"PAUSE / CODEX · ХАРАКТЕРИСТИКИ · {width}×{height}",
        size=max(15, round(31 * scale)),
        role="base",
        bold=True,
    )
    frame(canvas, nav, fill="surface", stroke="gold")
    canvas.text(nav.x + row_margin, nav.y + row_margin, "Навигация", size=max(12, round(22 * scale)), bold=True)
    for index, item in enumerate(("Герои", "Артефакты", "Характеристики", "Хроника")):
        canvas.text(
            nav.x + row_margin,
            nav.y + round((92 + index * 58) * scale),
            item,
            size=body_font,
            role="note" if item == "Характеристики" else "s",
        )
    canvas.rect(
        filtered_banner,
        fill=COLORS["muted"],
        stroke="#737984",
        stroke_width=max(1, round(2 * scale)),
        radius=max(3, round(7 * scale)),
        dashed=True,
    )
    canvas.text(
        filtered_banner.x + row_margin,
        filtered_banner.y + max(2, round(8 * scale)),
        "class_ineligible: ось отсутствует; capped — без CTA",
        size=max(8, round(14 * scale)),
        role="note",
        track=("CX.FilteredBanner", filtered_banner, row_margin),
    )
    canvas.rect(axis_list, fill=COLORS["zone"], stroke=COLORS["blue"], stroke_width=max(1, round(2 * scale)), radius=8)
    rows = (
        ("Увеличение урона · 18%", "Все подходящие удары сильнее"),
        ("Вампиризм · 3 HP при срабатывании", "шанс: сейчас 20% · максимум 20%"),
        ("Шанс крита · 34%", "сейчас 34% · максимум 62%"),
        ("Регенерация · 1.6 HP/с", "Восстанавливаете HP со временем"),
    )
    for index, (line, subline) in enumerate(rows):
        row = scaled(Rect(460, 290 + index * 170, 516, 154), scale)
        canvas.rect(
            row,
            fill=COLORS["card"] if index != 1 else COLORS["cap"],
            stroke=COLORS["green"] if index != 1 else COLORS["gold"],
            stroke_width=max(1, round(2 * scale)),
            radius=max(4, round(8 * scale)),
        )
        canvas.text(
            row.x + row_margin,
            row.y + round(24 * scale),
            line,
            size=body_font,
            role="base",
            bold=True,
            track=("CX.AxisRow.longest_line", row, row_margin),
        )
        canvas.text(
            row.x + row_margin,
            row.y + round(70 * scale),
            subline,
            size=small_font,
            role="warn" if index in (1, 2) else "s",
            track=("CX.AxisRow.supporting_line", row, row_margin),
        )
    frame(canvas, detail, fill="surface", stroke="gold")
    canvas.text(
        detail.x + detail_margin,
        detail.y + detail_margin,
        "Понятно и полностью",
        size=max(13, round(24 * scale)),
        bold=True,
    )
    canvas.text(
        detail.x + detail_margin,
        detail.y + round(100 * scale),
        "Вампиризм",
        size=max(12, round(22 * scale)),
        role="base",
        bold=True,
    )
    canvas.text(
        detail.x + detail_margin,
        detail.y + round(150 * scale),
        "Ось: 3 HP при срабатывании",
        size=body_font,
        role="s",
        track=("CX.Detail.axis_unit", detail, detail_margin),
    )
    long_copy = (
        "При успешном срабатывании удар восстанавливает указанное количество HP. "
        "Шанс срабатывания — отдельное условие карточки: он показан ниже вместе с пределом "
        "и не меняет единицу оси. Объяснение полностью доступно в прокрутке без многоточия."
    )
    canvas.wrapped_text(
        detail.x + detail_margin,
        detail.y + round(350 * scale),
        long_copy,
        size=small_font,
        max_width=detail.w - detail_margin * 2 - ceil(20 * scale),
        line_height=max(12, round(24 * scale)),
        role="note",
        track=("CX.Detail.long_copy", detail, detail_margin),
    )
    canvas.rect(
        cap_chip,
        fill=COLORS["cap"],
        stroke=COLORS["gold"],
        stroke_width=max(1, round(2 * scale)),
        radius=max(4, round(8 * scale)),
    )
    chip_margin = ceil(18 * scale)
    canvas.text(
        cap_chip.x + chip_margin,
        cap_chip.y + round(19 * scale),
        "шанс: 20% · максимум 20%",
        size=small_font,
        role="warn",
        track=("CX.CapChip.chance", cap_chip, chip_margin),
    )
    draw_scrollbar(canvas, detail, ceil(16 * scale))
    return canvas


HERO_LAYOUTS = {
    (1280, 720): {
        "shell": Rect(53, 50, 1174, 620),
        "portrait": Rect(96, 180, 300, 300),
        "dossier": Rect(420, 180, 760, 310),
        "axes": Rect(444, 205, 426, 260),
        "stats": Rect(890, 205, 264, 260),
        "columns": 2,
        "margin": 16,
        "font": 14,
    },
    (1920, 1080): {
        "shell": Rect(160, 120, 1600, 830),
        "portrait": Rect(250, 280, 400, 520),
        "dossier": Rect(706, 280, 1012, 286),
        "axes": Rect(742, 309, 590, 231),
        "stats": Rect(1362, 309, 320, 231),
        "columns": 1,
        "margin": 16,
        "font": 16,
    },
    (2560, 1440): {
        "shell": Rect(267, 160, 2026, 1107),
        "portrait": Rect(300, 250, 520, 680),
        "dossier": Rect(880, 250, 1380, 520),
        "axes": Rect(920, 292, 800, 440),
        "stats": Rect(1760, 292, 460, 440),
        "columns": 1,
        "margin": 20,
        "font": 22,
    },
}


def hero_select(viewport: tuple[int, int]) -> Canvas:
    width, height = viewport
    layout = HERO_LAYOUTS[viewport]
    canvas = Canvas("hero_select", width, height)
    shell: Rect = layout["shell"]
    portrait: Rect = layout["portrait"]
    dossier: Rect = layout["dossier"]
    axes: Rect = layout["axes"]
    stats: Rect = layout["stats"]
    columns = layout["columns"]
    margin = layout["margin"]
    font = layout["font"]

    frame(canvas, shell)
    canvas.text(
        shell.x + margin,
        shell.y + margin,
        f"HERO SELECT · ДОСЬЕ · {width}×{height}",
        size=max(18, round(font * 1.45)),
        role="base",
        bold=True,
    )
    canvas.text(
        shell.x + margin,
        shell.y + margin + round(font * 2.0),
        f"responsive stats: {'2×4 compact' if columns == 2 else '1×8'} · scrollbar reserve 16 px",
        size=max(11, font - 2),
        role="note",
    )
    canvas.rect(portrait, fill=COLORS["zone"], stroke=COLORS["gold"], stroke_width=3, radius=12)
    hero_side = min(portrait.w - margin * 2, portrait.h - margin * 3)
    canvas.ellipse(
        Rect(
            portrait.x + (portrait.w - hero_side) // 2,
            portrait.y + margin,
            hero_side,
            hero_side,
        ),
        fill="#5a4934",
        stroke=COLORS["gold"],
        stroke_width=3,
    )
    canvas.text(
        portrait.x + margin,
        portrait.bottom - margin - round(font * 1.4),
        "Ассасин · потенциал крита",
        size=max(11, font),
        role="s",
        bold=True,
    )
    canvas.rect(dossier, fill=COLORS["surface"], stroke=COLORS["gold"], stroke_width=3, radius=12)
    canvas.rect(axes, fill=COLORS["zone"], stroke=COLORS["blue"], stroke_width=2, radius=8)
    canvas.rect(stats, fill=COLORS["card"], stroke=COLORS["gold"], stroke_width=2, radius=8)
    reserve = 16
    text_x = axes.x + margin
    y = axes.y + margin
    canvas.text(text_x, y, "Что получит этот герой", size=max(13, font + 2), bold=True)
    y += round(font * 2.0)
    canvas.text(
        text_x,
        y,
        "Вампиризм: 3 HP при срабатывании",
        size=max(11, font),
        role="s",
        track=("HS.Dossier.axis_unit", dossier, reserve),
    )
    y += round(font * 1.65)
    canvas.text(
        text_x,
        y,
        "Шанс срабатывания: 20% / максимум 20%",
        size=max(10, font - 1),
        role="warn",
        track=("HS.Dossier.chance_field", dossier, reserve),
    )
    y += round(font * 1.8)
    copy = (
        "Для этого героя увеличение области атаки расширяет радиусы аур, ширину лучей, "
        "секторные атаки и взрывы, поэтому описание целиком переносится в scroll-lane "
        "и никогда не обрезается многоточием."
    )
    canvas.wrapped_text(
        text_x,
        y,
        copy,
        size=max(10, font - 2),
        max_width=axes.w - margin * 2 - reserve - 6,
        line_height=max(13, round(font * 1.25)),
        role="note",
        track=("HS.Dossier.long_copy", dossier, reserve),
    )
    draw_scrollbar(canvas, axes, reserve)

    canvas.text(
        stats.x + margin,
        stats.y + max(4, margin // 2),
        "Базовые характеристики",
        size=max(11, font - 1),
        role="base",
        bold=True,
    )
    stat_names = ("Сила 12", "Ловкость 28", "Интеллект 10", "Восприятие 22", "Энергия 14", "Знание 16", "Выносливость 18", "Лидерство 8")
    header_h = round(font * 2.0)
    rows = 4 if columns == 2 else 8
    gap = max(2, round(font * 0.2))
    cell_w = (stats.w - margin * 2 - gap * (columns - 1)) // columns
    cell_h = max(16, (stats.h - margin * 2 - header_h - gap * (rows - 1)) // rows)
    for index, stat in enumerate(stat_names):
        column = index % columns
        row = index // columns
        cell = Rect(
            stats.x + margin + column * (cell_w + gap),
            stats.y + margin + header_h + row * (cell_h + gap),
            cell_w,
            cell_h,
        )
        canvas.rect(cell, fill=COLORS["muted"], stroke="#737984", stroke_width=1, radius=3)
        canvas.text(
            cell.x + max(4, round(font * 0.35)),
            cell.y + max(1, round((cell.h - font) * 0.35)),
            stat,
            size=max(9, font - 3),
            role="s",
        )
    return canvas


BUILDERS = {
    "level_up": level_up,
    "attribute_shop": attribute_shop,
    "pause_codex": pause_codex,
    "hero_select": hero_select,
}


def exact_color_count(image: Image.Image, color: str) -> int:
    target = tuple(bytes.fromhex(color.lstrip("#")))
    return sum(1 for pixel in image.convert("RGB").getdata() if pixel == target)


def write_report(
    files: list[tuple[str, tuple[int, int], Path, Path, Canvas]],
    rescale_diffs: dict[tuple[str, tuple[int, int]], int],
) -> None:
    lines = [
        "# FAN-1903 preview geometry report",
        "",
        "Generated by `build_previews.py`; one render contains one surface at one viewport.",
        "",
        "## File matrix",
        "",
        "| Surface | Viewport | PNG pixels | Policy | SVG | PNG |",
        "| --- | --- | ---: | --- | --- | --- |",
    ]
    for surface, viewport, svg_path, png_path, _canvas in files:
        width, height = viewport
        lines.append(
            f"| `{surface}` | `{width}×{height}` | `{width}×{height}` | "
            f"{POLICIES[surface]} | `{svg_path.name}` | `{png_path.name}` |"
        )
    lines.extend(
        [
            "",
            "## Measured horizontal text clearances",
            "",
            "Clearance is the smaller pixel distance from the tracked line bbox to the left/right frame stroke.",
            "",
            "| Surface | Viewport | Container / longest required line | Measured px | Required px | Result |",
            "| --- | --- | --- | ---: | ---: | --- |",
        ]
    )
    for surface, viewport, _svg_path, _png_path, canvas in files:
        for label, (gap, required) in sorted(canvas.gaps.items()):
            result = "PASS" if gap + 0.01 >= required else "FAIL"
            lines.append(
                f"| `{surface}` | `{viewport[0]}×{viewport[1]}` | `{label}` | "
                f"{gap:.1f} | {required:.1f} | {result} |"
            )
            if result != "PASS":
                raise AssertionError(f"{surface} {viewport} {label}: gap {gap} < {required}")
    lines.extend(
        [
            "",
            "## Raster color and independent-render checks",
            "",
            "| Surface | Viewport | `#c6d5df` (`.s`) | `#87cdf3` (`.note`) | `#f0b270` (`.warn`) | Pixels different from resized 1920 |",
            "| --- | --- | ---: | ---: | ---: | ---: |",
        ]
    )
    for surface, viewport, _svg_path, png_path, canvas in files:
        counts = [exact_color_count(canvas.image, COLORS[role]) for role in ("s", "note", "warn")]
        if any(count == 0 for count in counts):
            raise AssertionError(f"{surface} {viewport}: missing semantic raster color {counts}")
        diff = rescale_diffs.get((surface, viewport), 0)
        lines.append(
            f"| `{surface}` | `{viewport[0]}×{viewport[1]}` | {counts[0]} | {counts[1]} | "
            f"{counts[2]} | {'authored base' if viewport == (1920, 1080) else diff} |"
        )
        if viewport != (1920, 1080) and diff == 0:
            raise AssertionError(f"{surface} {viewport}: exact resized-1920 duplicate")
        if Image.open(png_path).size != viewport:
            raise AssertionError(f"{png_path}: wrong dimensions")
    lines.extend(
        [
            "",
            "All 12 PNGs contain the three exact semantic colors. Non-base renders differ from a resized 1920 render; "
            "Level Up/Codex retain their specified uniform stage geometry while their viewport labels are independently rendered, "
            "and Shop/Hero use distinct compact/large geometry.",
            "",
        ]
    )
    (REFERENCE_DIR / "geometry_report.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    if not FONT_REGULAR.exists() or not FONT_BOLD.exists():
        raise SystemExit("Arial fonts required for deterministic Russian text metrics")
    files: list[tuple[str, tuple[int, int], Path, Path, Canvas]] = []
    rendered: dict[tuple[str, tuple[int, int]], Image.Image] = {}
    for surface in SURFACES:
        for viewport in VIEWPORTS:
            canvas = BUILDERS[surface](viewport)
            stem = f"{surface}_{viewport[0]}x{viewport[1]}"
            svg_path, png_path = canvas.save(stem)
            files.append((surface, viewport, svg_path, png_path, canvas))
            rendered[(surface, viewport)] = canvas.image.copy()

    rescale_diffs: dict[tuple[str, tuple[int, int]], int] = {}
    for surface in SURFACES:
        base = rendered[(surface, (1920, 1080))]
        for viewport in ((1280, 720), (2560, 1440)):
            resized = base.resize(viewport, Image.Resampling.LANCZOS)
            diff = ImageChops.difference(rendered[(surface, viewport)], resized).convert("RGB")
            rescale_diffs[(surface, viewport)] = sum(pixel != (0, 0, 0) for pixel in diff.getdata())

    write_report(files, rescale_diffs)
    digest = sha256()
    for _surface, _viewport, svg_path, png_path, _canvas in files:
        digest.update(svg_path.read_bytes())
        digest.update(png_path.read_bytes())
    print(f"Generated {len(files)} SVG/PNG pairs; matrix sha256={digest.hexdigest()}")


if __name__ == "__main__":
    main()
