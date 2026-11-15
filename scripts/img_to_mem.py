"""
Convert an input image (e.g. pigeon.jpg / pigeon.png) into two 48x48 12-bit RGB444
Verilog .mem files (pigeon_down.mem and pigeon_up.mem) for Nexys A7-100T VGA.

Usage:
    pip install pillow numpy
    python scripts/img_to_mem.py pigeon.jpg

Transparency key: 12'hF0F (pure magenta) is treated as transparent by vga_renderer.v.
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError:
    print("Please install Pillow first: pip install pillow")
    sys.exit(1)


SIZE = 48
TRANSPARENT_HEX = "F0F"


def to_rgb444_lines(img_rgba: Image.Image) -> list[str]:
    lines = []
    px = img_rgba.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            # Treat transparent pixels or near-white/solid background edges if alpha exists
            if a < 128:
                lines.append(TRANSPARENT_HEX)
            else:
                r4 = r >> 4
                g4 = g >> 4
                b4 = b >> 4
                # Avoid accidental collision with transparency key F0F
                if r4 == 0xF and g4 == 0x0 and b4 == 0xF:
                    g4 = 0x1
                lines.append(f"{r4:X}{g4:X}{b4:X}")
    return lines


def remove_flat_background(img: Image.Image, tolerance: int = 36) -> Image.Image:
    """Flood-fill remove uniform border background (common in meme/AI images)."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    corners = [px[0, 0][:3], px[w - 1, 0][:3], px[0, h - 1][:3], px[w - 1, h - 1][:3]]
    bg = max(set(corners), key=corners.count)

    visited = set()
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in visited or not (0 <= x < w and 0 <= y < h):
            continue
        visited.add((x, y))
        r, g, b, a = px[x, y]
        if abs(r - bg[0]) <= tolerance and abs(g - bg[1]) <= tolerance and abs(b - bg[2]) <= tolerance:
            px[x, y] = (r, g, b, 0)
            stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return img


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/img_to_mem.py <image_path>")
        sys.exit(1)

    src = Path(sys.argv[1])
    if not src.exists():
        print(f"File not found: {src}")
        sys.exit(1)

    out_dir = Path(__file__).resolve().parent.parent / "mem"
    out_dir.mkdir(parents=True, exist_ok=True)

    img = Image.open(src).convert("RGBA")
    img = remove_flat_background(img)

    # Trim transparent margins and fit cleanly into 48x48
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img = ImageOps.contain(img, (SIZE, SIZE), method=Image.Resampling.NEAREST)

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ox = (SIZE - img.width) // 2
    oy = (SIZE - img.height) // 2
    canvas.paste(img, (ox, oy))

    # Frame 0: slight nose-down dive pose (-8 deg)
    dive = canvas.rotate(-8, resample=Image.Resampling.NEAREST, fillcolor=(0, 0, 0, 0))
    # Frame 1: nose-up flap pose (+12 deg)
    flap = canvas.rotate(12, resample=Image.Resampling.NEAREST, fillcolor=(0, 0, 0, 0))

    (out_dir / "pigeon_down.mem").write_text("\n".join(to_rgb444_lines(dive)) + "\n", encoding="utf-8")
    (out_dir / "pigeon_up.mem").write_text("\n".join(to_rgb444_lines(flap)) + "\n", encoding="utf-8")
    print(f"Generated {out_dir / 'pigeon_down.mem'} and {out_dir / 'pigeon_up.mem'} ({SIZE}x{SIZE} RGB444)")


if __name__ == "__main__":
    main()
