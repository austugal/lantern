"""Render the original Lantern README animation. Requires Pillow (artwork only)."""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
W, H, SCALE = 760, 260, 2
BG = "#070e13"
TEAL = "#78fff0"
GOLD = "#e8b959"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REGULAR = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def frame(t):
    im = Image.new("RGB", (W * SCALE, H * SCALE), BG)
    d = ImageDraw.Draw(im)

    def line(points, fill, width=1):
        d.line(
            [(int(x * SCALE), int(y * SCALE)) for x, y in points], fill=fill, width=width * SCALE
        )

    def box(bounds, fill, radius=0, outline=None):
        d.rounded_rectangle(
            tuple(int(v * SCALE) for v in bounds),
            radius=radius * SCALE,
            fill=fill,
            outline=outline,
            width=SCALE,
        )

    def circle(x, y, r, fill):
        d.ellipse(((x - r) * SCALE, (y - r) * SCALE, (x + r) * SCALE, (y + r) * SCALE), fill=fill)

    for x in range(26, W, 28):
        for y in range(22, H, 28):
            circle(x, y, 0.6, "#10212a")
    # Small lantern emblem remains legible in the static first frame.
    box((48, 94, 100, 153), "#152b32", 9, "#35545b")
    line([(59, 94), (59, 78), (89, 78), (89, 94)], GOLD, 3)
    box((58, 105, 90, 143), GOLD, 5)
    line([(74, 111), (74, 137)], "#fff1c5", 3)
    circle(74, 124, 5, "#fff1c5")

    name = "lantern"
    title_font = ImageFont.truetype(FONT, 78 * SCALE)
    sub_font = ImageFont.truetype(REGULAR, 21 * SCALE)
    small_font = ImageFont.truetype(REGULAR, 11 * SCALE)
    title = Image.new("RGBA", im.size)
    td = ImageDraw.Draw(title)
    td.text((163 * SCALE, 53 * SCALE), name, font=title_font, fill=TEAL, stroke_width=0)
    width = td.textlength(name, font=title_font) / SCALE
    progress = min(1, max(0, (t - 0.35) / 2.8))
    reveal = 163 + width * progress
    if progress:
        crop = title.crop((0, 0, int(reveal * SCALE), H * SCALE))
        im.paste(crop, (0, 0), crop)
    line([(166, 146), (max(166, reveal), 146)], "#1d585e", 2)
    if progress > 0:
        line([(166, 145), (max(166, reveal), 145)], TEAL, 1)
    tagline = "Stay connected. Even offline."
    sub_progress = min(1, max(0, (t - 3.35) / 1.75))
    if sub_progress:
        count = int(len(tagline) * sub_progress)
        d.text((166 * SCALE, 166 * SCALE), tagline[:count], font=sub_font, fill="#c5dcd9")
    d.text(
        (166 * SCALE, 216 * SCALE),
        "DESKTOP  /  ANDROID  /  iPHONE",
        font=small_font,
        fill="#68868a",
    )
    # A small robot moves its pen along the baseline as the name is revealed.
    rx = min(669, max(170, reveal + 18))
    ry = 116 + math.sin(t * 9) * 1.8 if t < 3.2 else 116
    if t > 3.2:
        rx = reveal + 18 + min(1, (t - 3.2) / 0.5) * 36
    box((rx - 19, ry - 42, rx + 19, ry - 12), "#17333d", 7, "#4b858d")
    line([(rx, ry - 42), (rx, ry - 51)], "#4b858d", 2)
    circle(rx, ry - 52, 3, GOLD)
    blink = 5.8 < t < 5.94
    for eye in [-8, 8]:
        if blink:
            line([(rx + eye - 3, ry - 28), (rx + eye + 3, ry - 28)], TEAL, 2)
        else:
            box((rx + eye - 3, ry - 32, rx + eye + 3, ry - 26), TEAL, 2)
    box((rx - 12, ry - 10, rx + 12, ry + 9), "#17333d", 4, "#4b858d")
    circle(rx, ry - 1, 3, GOLD)
    line([(rx - 7, ry + 10), (rx - 10, ry + 17)], "#4b858d", 3)
    line([(rx + 7, ry + 10), (rx + 10, ry + 17)], "#4b858d", 3)
    px = reveal if t <= 3.2 else rx + 18
    py = 145 if t <= 3.2 else ry + 9
    line([(rx - 13, ry - 4), (rx - 24, ry + 7), (px, py - 5)], "#70a5aa", 3)
    line([(px + 3, py - 17), (px, py)], "#e4fdf8", 2)
    circle(px, py, 2, GOLD)
    if t > 5.1:
        for j in range(3):
            circle(602 + j * 13, 182, 2, TEAL if int(t * 3) % 3 == j else "#245052")
    return im.resize((W, H), Image.Resampling.LANCZOS)


def main():
    out = ROOT / "assets"
    out.mkdir(exist_ok=True)
    frames = [frame(i / 16) for i in range(112)]
    # End hold makes the finished title easy to read before the loop restarts.
    palette = frames[-1].quantize(colors=96)
    frames = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    durations = [62] * len(frames)
    durations[-1] = 1400
    frames[0].save(
        out / "lantern-robot.gif",
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=1,
    )
    frames[-1].save(out / "lantern-banner.png", optimize=True)
    print(f"Wrote {len(frames)} frames to {out / 'lantern-robot.gif'}")


if __name__ == "__main__":
    main()
