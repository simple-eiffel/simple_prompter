#!/usr/bin/env python3
"""Generate the simple_prompter icon set.

The mark is the app's own pill in miniature: the near-black slab with three
script lines - the line already read in dim ink, the line being read in
bright ink with the blue follow caret at its left, the next line in grey -
and the red record dot of the Take Studio in the top corner. Colors are the
pill renderer's own (app/pt_pill_renderer.e).

Lines are drawn as rounded bars, not letters, so the mark holds at 16 px;
16 and 24 drop the dim line to keep the bars apart.

Outputs:
  app/resources/simple_prompter.ico   (256/128/64/48/32/24/16, per-size rendered)
  app/resources/icon-256.png          (README/docs raster)
Run from the repo root:  python scripts/make_icon.py
"""

import os
from PIL import Image, ImageDraw

SLAB = (0x0F, 0x11, 0x15, 255)        # Slab
EDGE = (0x2A, 0x2E, 0x37, 255)        # faint rim for dark taskbars
READ = (0x5B, 0x61, 0x70, 255)        # Read_ink
READING = (0xF5, 0xF6, 0xF8, 255)     # Reading_ink
UPCOMING = (0xC9, 0xCD, 0xD4, 255)    # Upcoming_ink
ACCENT = (0x3B, 0x82, 0xF6, 255)      # Accent (follow caret)
RED = (0xEF, 0x44, 0x44, 255)         # Record_red

SS = 4  # supersample factor for crisp small sizes


def bar(d, x0, y, x1, h, fill):
    d.rounded_rectangle([x0, y - h / 2, x1, y + h / 2], radius=h / 2, fill=fill)


def render(size):
    """One square icon layer at `size`, drawn at SSx and downsampled."""
    w = size * SS
    img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, w - 1], radius=int(w * 0.20), fill=SLAB,
                        outline=EDGE, width=max(SS, w // 96))

    small = size <= 24
    left = w * 0.16
    right = w * 0.84
    caret_w = w * (0.07 if small else 0.05)
    text_left = left + caret_w + w * (0.07 if small else 0.06)

    if small:
        # two lines: the one being read, the next one
        h = w * 0.13
        rows = [(w * 0.50, READING, right, True),
                (w * 0.76, UPCOMING, w * 0.66, False)]
    else:
        h = w * 0.085
        rows = [(w * 0.40, READ, w * 0.70, False),
                (w * 0.57, READING, right, True),
                (w * 0.74, UPCOMING, w * 0.62, False)]

    for y, ink, x1, current in rows:
        bar(d, text_left, y, x1, h, ink)
        if current:
            d.rounded_rectangle([left, y - h * 0.95, left + caret_w, y + h * 0.95],
                                radius=caret_w / 2, fill=ACCENT)

    # record dot, top right (where the pill shows its REC badge)
    r = w * (0.11 if small else 0.085)
    cx, cy = w * 0.76, w * (0.23 if small else 0.21)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=RED)

    return img.resize((size, size), Image.LANCZOS)


def main():
    sizes = [256, 128, 64, 48, 32, 24, 16]
    layers = {s: render(s) for s in sizes}

    os.makedirs("app/resources", exist_ok=True)
    layers[256].save("app/resources/icon-256.png")
    layers[256].save("app/resources/simple_prompter.ico", format="ICO",
                     append_images=[layers[s] for s in sizes[1:]],
                     sizes=[(s, s) for s in sizes])

    ico = Image.open("app/resources/simple_prompter.ico")
    print("ICO embedded sizes:", sorted(ico.info.get("sizes", []), reverse=True))
    print("Wrote app/resources/simple_prompter.ico and app/resources/icon-256.png")


if __name__ == "__main__":
    main()
