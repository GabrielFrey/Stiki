#!/usr/bin/env python3
"""Generate opaque placeholder App Store and iMessage icons.

Run from the repo root. No third-party packages — stdlib only.
Replace these PNGs with a final Icon Composer design before submission.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_ICON_DIR = ROOT / "App/Resources/Assets.xcassets/AppIcon.appiconset"
MSG_ICON_DIR = ROOT / "MessagesExtension/Resources/Assets.xcassets/iMessage App Icon.stickersiconset"

# Brand colors from AccentColor / LaunchBackground (sRGB 0–255).
NAVY = (26, 39, 68)
BLUE = (63, 107, 249)
WHITE = (255, 255, 255)
CREAM = (245, 247, 250)


def _png(width: int, height: int, rgb: bytes) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + rgb[y * width * 3 : (y + 1) * width * 3] for y in range(height))
    return b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)),
            chunk(b"IDAT", zlib.compress(raw, 9)),
            chunk(b"IEND", b""),
        ]
    )


def _blend(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))  # type: ignore[return-value]


def _fill(pixels: list[list[tuple[int, int, int]]], color: tuple[int, int, int]) -> None:
    for row in pixels:
        for x in range(len(row)):
            row[x] = color


def _circle(
    pixels: list[list[tuple[int, int, int]]],
    cx: float,
    cy: float,
    radius: float,
    color: tuple[int, int, int],
    feather: float = 1.4,
) -> None:
    h = len(pixels)
    w = len(pixels[0])
    r2 = radius * radius
    outer = (radius + feather) * (radius + feather)
    y0 = max(0, int(cy - radius - feather - 1))
    y1 = min(h, int(cy + radius + feather + 2))
    x0 = max(0, int(cx - radius - feather - 1))
    x1 = min(w, int(cx + radius + feather + 2))
    for y in range(y0, y1):
        dy = (y + 0.5) - cy
        for x in range(x0, x1):
            dx = (x + 0.5) - cx
            d2 = dx * dx + dy * dy
            if d2 <= r2:
                pixels[y][x] = color
            elif d2 < outer:
                t = 1.0 - (d2**0.5 - radius) / feather
                pixels[y][x] = _blend(pixels[y][x], color, t)


def _rounded_rect(
    pixels: list[list[tuple[int, int, int]]],
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    radius: float,
    color: tuple[int, int, int],
    feather: float = 1.4,
) -> None:
    h = len(pixels)
    w = len(pixels[0])
    for y in range(max(0, int(y0 - feather - 1)), min(h, int(y1 + feather + 2))):
        py = y + 0.5
        for x in range(max(0, int(x0 - feather - 1)), min(w, int(x1 + feather + 2))):
            px = x + 0.5
            cx = min(max(px, x0 + radius), x1 - radius)
            cy = min(max(py, y0 + radius), y1 - radius)
            dx = px - cx
            dy = py - cy
            d = (dx * dx + dy * dy) ** 0.5
            if d <= radius:
                pixels[y][x] = color
            elif d < radius + feather:
                t = 1.0 - (d - radius) / feather
                pixels[y][x] = _blend(pixels[y][x], color, t)


def _stroke_arc(
    pixels: list[list[tuple[int, int, int]]],
    cx: float,
    cy: float,
    radius: float,
    width: float,
    color: tuple[int, int, int],
    start_deg: float,
    end_deg: float,
) -> None:
    import math

    h = len(pixels)
    w = len(pixels[0])
    start = math.radians(start_deg)
    end = math.radians(end_deg)
    outer = radius + width / 2
    inner = max(0.0, radius - width / 2)
    y0 = max(0, int(cy - outer - 2))
    y1 = min(h, int(cy + outer + 2))
    x0 = max(0, int(cx - outer - 2))
    x1 = min(w, int(cx + outer + 2))
    for y in range(y0, y1):
        for x in range(x0, x1):
            dx = (x + 0.5) - cx
            dy = (y + 0.5) - cy
            ang = math.atan2(-dy, dx)
            if ang < 0:
                ang += 2 * math.pi
            if start <= ang <= end:
                d = (dx * dx + dy * dy) ** 0.5
                if inner <= d <= outer:
                    pixels[y][x] = color


def render_master(size: int = 1024) -> list[list[tuple[int, int, int]]]:
    pixels = [[NAVY for _ in range(size)] for _ in range(size)]
    _circle(pixels, size * 0.50, size * 0.48, size * 0.36, BLUE, feather=size * 0.01)
    _circle(pixels, size * 0.50, size * 0.48, size * 0.30, CREAM, feather=size * 0.008)
    # Sticker "face"
    _circle(pixels, size * 0.40, size * 0.42, size * 0.035, NAVY, feather=size * 0.004)
    _circle(pixels, size * 0.60, size * 0.42, size * 0.035, NAVY, feather=size * 0.004)
    _stroke_arc(
        pixels,
        size * 0.50,
        size * 0.50,
        size * 0.12,
        size * 0.028,
        NAVY,
        start_deg=200,
        end_deg=340,
    )
    # Small sparkle
    _circle(pixels, size * 0.78, size * 0.22, size * 0.035, WHITE, feather=size * 0.006)
    return pixels


def crop_center(pixels: list[list[tuple[int, int, int]]], width: int, height: int) -> list[list[tuple[int, int, int]]]:
    src_h = len(pixels)
    src_w = len(pixels[0])
    # Scale master so the short side fills, then crop.
    scale = max(width / src_w, height / src_h)
    tmp_w = max(1, int(round(src_w * scale)))
    tmp_h = max(1, int(round(src_h * scale)))
    scaled = scale_nearest(pixels, tmp_w, tmp_h)
    x0 = max(0, (tmp_w - width) // 2)
    y0 = max(0, (tmp_h - height) // 2)
    return [row[x0 : x0 + width] for row in scaled[y0 : y0 + height]]


def scale_nearest(pixels: list[list[tuple[int, int, int]]], width: int, height: int) -> list[list[tuple[int, int, int]]]:
    src_h = len(pixels)
    src_w = len(pixels[0])
    out: list[list[tuple[int, int, int]]] = []
    for y in range(height):
        sy = min(src_h - 1, int(y * src_h / height))
        row = []
        for x in range(width):
            sx = min(src_w - 1, int(x * src_w / width))
            row.append(pixels[sy][sx])
        out.append(row)
    return out


def write_rgb(path: Path, pixels: list[list[tuple[int, int, int]]]) -> None:
    height = len(pixels)
    width = len(pixels[0])
    rgb = bytes(c for row in pixels for px in row for c in px)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_png(width, height, rgb))
    print(f"wrote {path.relative_to(ROOT)} ({width}x{height})")


def main() -> None:
    master = render_master(1024)
    write_rgb(APP_ICON_DIR / "AppIcon.png", master)

    messages = {
        "MessagesIcon-20x15@2x.png": (40, 30),
        "MessagesIcon-20x15@3x.png": (60, 45),
        "MessagesIcon-27x20@2x.png": (54, 40),
        "MessagesIcon-27x20@3x.png": (81, 60),
        "MessagesIcon-32x24@2x.png": (64, 48),
        "MessagesIcon-32x24@3x.png": (96, 72),
        "MessagesIcon-60x45@2x.png": (120, 90),
        "MessagesIcon-60x45@3x.png": (180, 135),
        "MessagesIcon-29x22@2x.png": (58, 44),
        "MessagesIcon-67x50@2x.png": (134, 100),
        "MessagesIcon-74x55@2x.png": (148, 110),
        "MessagesIcon-1024x768.png": (1024, 768),
    }
    MSG_ICON_DIR.mkdir(parents=True, exist_ok=True)
    for name, (w, h) in messages.items():
        write_rgb(MSG_ICON_DIR / name, crop_center(master, w, h))


if __name__ == "__main__":
    main()
