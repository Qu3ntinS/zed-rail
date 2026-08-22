#!/usr/bin/env python3
"""Generate ZedRail app icons from official Zed brand assets (https://zed.dev/brand)."""

from __future__ import annotations

import io
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
BRAND_DIR = ROOT / "crates/zed/resources/brand"
OFFICIAL_DIR = BRAND_DIR / "zed-official"
OUTPUT_DIR = ROOT / "crates/zed/resources"

STABLE_APP_LOGO = OFFICIAL_DIR / "stable-app-logo.png"

# Zed brand blue — used only for the active activity-bar indicator.
BRAND_BLUE = (19, 72, 220, 255)

RAIL_WIDTH_RATIO = 0.125
ICON_SIZE_RATIO = 0.052
ACTIVE_SLOT = 0

ACTIVITY_ICON_SVGS = [
    # Files (active by default)
    """<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="5" y="3" width="14" height="18" rx="1.5" stroke="{stroke}" stroke-width="2"/>
  <path d="M9 3V7H13" stroke="{stroke}" stroke-width="2" stroke-linejoin="round"/>
</svg>""",
    # Search
    """<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="10" cy="10" r="5" stroke="{stroke}" stroke-width="2"/>
  <path d="M14 14L19 19" stroke="{stroke}" stroke-width="2" stroke-linecap="round"/>
</svg>""",
    # Git
    """<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="7" cy="6" r="2" fill="{stroke}"/>
  <circle cx="7" cy="18" r="2" fill="{stroke}"/>
  <circle cx="17" cy="12" r="2" fill="{stroke}"/>
  <path d="M7 8V16M7 12H15" stroke="{stroke}" stroke-width="2"/>
</svg>""",
    # Extensions
    """<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="4" y="4" width="7" height="7" rx="1" stroke="{stroke}" stroke-width="2"/>
  <rect x="13" y="4" width="7" height="7" rx="1" stroke="{stroke}" stroke-width="2"/>
  <rect x="4" y="13" width="7" height="7" rx="1" stroke="{stroke}" stroke-width="2"/>
  <rect x="13" y="13" width="7" height="7" rx="1" stroke="{stroke}" stroke-width="2"/>
</svg>""",
]


def render_svg(svg: str, size: int) -> Image.Image:
    with tempfile.NamedTemporaryFile(suffix=".svg", mode="w", encoding="utf-8") as handle:
        handle.write(svg)
        handle.flush()
        result = subprocess.run(
            ["rsvg-convert", "-w", str(size), "-h", str(size), handle.name],
            check=True,
            capture_output=True,
        )
    return Image.open(io.BytesIO(result.stdout)).convert("RGBA")


def darken_region(image: Image.Image, box: tuple[int, int, int, int], factor: float) -> None:
    region = image.crop(box)
    region = ImageEnhance.Brightness(region).enhance(factor)
    image.paste(region, box)


def generate_icon(size: int) -> Image.Image:
    if not STABLE_APP_LOGO.exists():
        raise FileNotFoundError(
            f"Missing official stable app logo at {STABLE_APP_LOGO}. "
            "Download from https://zed.dev/brand first."
        )

    base = Image.open(STABLE_APP_LOGO).convert("RGBA").resize((size, size), Image.LANCZOS)
    canvas = base.copy()

    rail_width = int(size * RAIL_WIDTH_RATIO)
    icon_size = max(16, int(size * ICON_SIZE_RATIO))
    divider_x = rail_width

    darken_region(canvas, (0, 0, rail_width, size), 0.72)

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.line(
        [(divider_x, int(size * 0.12)), (divider_x, int(size * 0.88))],
        fill=(255, 255, 255, 38),
        width=max(1, size // 512),
    )
    canvas = Image.alpha_composite(canvas, overlay)

    slot_count = len(ACTIVITY_ICON_SVGS)
    top_margin = int(size * 0.17)
    bottom_margin = int(size * 0.17)
    available_height = size - top_margin - bottom_margin
    slot_height = available_height / slot_count

    indicator_width = max(2, size // 128)
    active_stroke = "#FFFFFF"
    inactive_stroke = "#FFFFFF99"

    for index, template in enumerate(ACTIVITY_ICON_SVGS):
        center_y = top_margin + slot_height * (index + 0.5)
        center_x = rail_width // 2
        is_active = index == ACTIVE_SLOT

        if is_active:
            indicator_top = int(center_y - slot_height * 0.32)
            indicator_bottom = int(center_y + slot_height * 0.32)
            draw = ImageDraw.Draw(canvas)
            draw.rectangle(
                [
                    (0, indicator_top),
                    (indicator_width, indicator_bottom),
                ],
                fill=BRAND_BLUE,
            )

        stroke = active_stroke if is_active else inactive_stroke
        icon = render_svg(template.format(stroke=stroke), icon_size)
        paste_x = center_x - icon_size // 2
        paste_y = int(center_y - icon_size // 2)
        canvas.paste(icon, (paste_x, paste_y), icon)

    return canvas


def write_windows_ico(icon_512: Path, icon_1024: Path, output: Path) -> None:
    subprocess.run(
        [
            "magick",
            str(icon_512),
            str(icon_1024),
            "-define",
            "icon:auto-resize=256,128,64,48,32,16",
            str(output),
        ],
        check=True,
    )


def main() -> int:
    sizes = {
        OUTPUT_DIR / "app-icon.png": 512,
        OUTPUT_DIR / "app-icon@2x.png": 1024,
    }

    icons: dict[Path, Image.Image] = {}
    for path, size in sizes.items():
        icons[path] = generate_icon(size)
        icons[path].save(path, optimize=True)
        print(f"Wrote {path} ({size}×{size})")

    ico_path = OUTPUT_DIR / "windows" / "app-icon.ico"
    write_windows_ico(
        OUTPUT_DIR / "app-icon.png",
        OUTPUT_DIR / "app-icon@2x.png",
        ico_path,
    )
    print(f"Wrote {ico_path}")

    preview = generate_icon(256)
    preview_path = BRAND_DIR / "zedrail-app-icon-preview.png"
    preview.save(preview_path, optimize=True)
    print(f"Wrote {preview_path} (256×256 preview)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
