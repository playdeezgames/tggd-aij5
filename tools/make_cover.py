#!/usr/bin/env python3
"""Draws the itch.io cover (630 by 500) from the game's own art: assets/cover.png. Needs Pillow.

Faces come from the Urizen sheet in assets/urizen.png (tile columns and rows are HEIR_TILES in src/game/content.odin),
the torch is drawn the way web/index.html draws it (with a fixed flicker), and the lettering is Public Pixel
(tools/cover/, CC0, GGBotNet)."""
import math
import os
from PIL import Image, ImageDraw, ImageFont

HEIRS = [(109, 4), (106, 5), (118, 11), (117, 17), (108, 8), (120, 6), (124, 10), (104, 7), (113, 15), (111, 14), (122, 2), (126, 18)]
FOUNDER = (105, 0)
ORANGE = (255, 170, 0)

def noise(n):
    s = math.sin(n * 12.9898) * 43758.5453
    return s - math.floor(s)

def torch(level, frame):
    """The page's torch as a small image: 40 by 80 logical pixels, centre column 20."""
    img = Image.new("RGBA", (40, 80), (0, 0, 0, 0))
    px = img.load()
    cx, base = 20, 52
    def rect(x, y, w, h, rgb):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if 0 <= xx < 40 and 0 <= yy < 80:
                    px[xx, yy] = rgb + (255,)
    rect(cx - 2, base, 4, 26, (0x6B, 0x44, 0x23))
    rect(cx - 3, base - 2, 6, 3, (0x3A, 0x24, 0x10))
    h = 6 + level * 4
    w = 4 + round(level / 2)
    for x in range(-w, w + 1):
        shape = 1 - (abs(x) / (w + 1)) ** 1.6
        wob = noise(frame * 7 + x * 3.1) * 0.35 + 0.65
        col_h = max(1, round(h * shape * wob))
        rect(cx + x, base - col_h, 1, col_h, (0xE8, 0x60, 0x1A))
        inner = round(col_h * 0.6)
        if abs(x) <= w / 2 and inner > 1:
            rect(cx + x, base - inner, 1, inner, (0xFF, 0xCC, 0x33))
    return img

def lettering(font_path, s, size, rgb):
    font = ImageFont.truetype(font_path, size)
    font.fontmode = "1"  # no anti-aliasing: the font is a pixel font
    img = Image.new("RGBA", (int(font.getlength(s)) + 2, size + 2), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((0, 0), s, font=font, fill=rgb + (255,))
    return img

def main():
    root = os.path.join(os.path.dirname(__file__), "..")
    os.chdir(root)
    sheet = Image.open("assets/urizen.png").convert("RGBA")
    face = lambda c, r: sheet.crop((13 * c + 1, 13 * r + 1, 13 * c + 13, 13 * r + 13))
    font = "tools/cover/PublicPixel.ttf"
    cover = Image.new("RGBA", (630, 500), (0, 0, 0, 255))

    def centered(img, y, dx=0):
        cover.alpha_composite(img, ((630 - img.width) // 2 + dx, y))

    # a soft glow behind the flame, then the torch at 4x
    glow = Image.new("RGBA", (630, 500), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, a in ((190, 14), (150, 20), (110, 28), (70, 40)):
        gd.ellipse((315 - r, 255 - r, 315 + r, 255 + r), fill=(255, 120, 20, a))
    cover.alpha_composite(glow)
    t = torch(8, 5).resize((160, 320), Image.NEAREST)
    centered(t, 98)

    shadow = lettering(font, "TORCH PASSERS", 40, (0, 0, 0))
    main_text = lettering(font, "TORCH PASSERS", 40, (255, 255, 255))
    x = (630 - main_text.width) // 2
    cover.alpha_composite(shadow, (x + 4, 24 + 4))
    cover.alpha_composite(main_text, (x, 24))
    sub = lettering(font, "of SPLORR!!", 24, ORANGE)
    sub_shadow = lettering(font, "of SPLORR!!", 24, (0, 0, 0))
    sx = (630 - sub.width) // 2
    cover.alpha_composite(sub_shadow, (sx + 3, 72 + 3))
    cover.alpha_composite(sub, (sx, 72))

    # the family, in a row, each one a little worse for wear
    faces = [FOUNDER] + HEIRS[:11]
    scale, gap = 4, 3
    total = len(faces) * 12 * scale + (len(faces) - 1) * gap
    x0 = (630 - total) // 2
    for i, (c, r) in enumerate(faces):
        cover.alpha_composite(face(c, r).resize((12 * scale, 12 * scale), Image.NEAREST), (x0 + i * (12 * scale + gap), 428))
    os.makedirs("assets", exist_ok=True)
    cover.convert("RGB").save("assets/cover.png")
    print("assets/cover.png", cover.size)

main()
