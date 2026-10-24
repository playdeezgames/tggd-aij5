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
    from PIL import ImageFilter, ImageEnhance
    cover = Image.new("RGBA", (630, 500), (6, 4, 4, 255))

    # a smooth glow behind the flame
    glow = Image.new("RGBA", (630, 500), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((315 - 230, 270 - 230, 315 + 230, 270 + 230), fill=(255, 110, 20, 110))
    gd.ellipse((315 - 120, 250 - 120, 315 + 120, 250 + 120), fill=(255, 170, 40, 120))
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    cover.alpha_composite(glow)

    # sparks drifting up from the flame
    sp = Image.new("RGBA", (630, 500), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sp)
    for i in range(46):
        ang = noise(i * 3.7)
        x = 315 + int((noise(i * 5.1) - 0.5) * 150 * (0.4 + ang))
        y = 270 - int(noise(i * 9.3) * 190)
        sz = 3 if noise(i * 1.9) > 0.6 else 2
        col = (255, 220, 90) if noise(i * 2.3) > 0.5 else (255, 140, 30)
        sd.rectangle((x, y, x + sz - 1, y + sz - 1), fill=col + (255,))
    cover.alpha_composite(sp)

    # the family queues up either side, lit less the further from the flame
    faces = [FOUNDER] + HEIRS[:11]
    scale = 6
    slots = []
    for side in (-1, 1):
        for col in range(2):
            for row in range(3):
                x = 315 + side * (150 + col * 82) - (72 if side < 0 else 0) + (0 if side < 0 else 0)
                y = 130 + row * 108 + col * 40
                slots.append((x, y, col))
    for i, (x, y, col) in enumerate(slots):
        c, r = faces[i % len(faces)]
        f = face(c, r).resize((12 * scale, 12 * scale), Image.NEAREST)
        f = ImageEnhance.Brightness(f).enhance(1.0 if col == 0 else 0.55)
        back = Image.new("RGBA", f.size, (30, 18, 14, 255))
        cover.alpha_composite(back, (x, y))
        cover.alpha_composite(f, (x, y))

    # vignette
    v = Image.new("L", (630, 500), 0)
    ImageDraw.Draw(v).ellipse((-120, -80, 750, 580), fill=255)
    v = v.filter(ImageFilter.GaussianBlur(70))
    black = Image.new("RGBA", (630, 500), (0, 0, 0, 255))
    black.putalpha(Image.eval(v, lambda p: 255 - p))
    cover.alpha_composite(black)

    t = torch(8, 5).resize((200, 400), Image.NEAREST)
    cover.alpha_composite(t, (215, 88))

    def centered(img, y):
        cover.alpha_composite(img, ((630 - img.width) // 2, y))
    def outlined(txt, size, rgb, y):
        main_t = lettering(font, txt, size, rgb)
        dark = lettering(font, txt, size, (0, 0, 0))
        x = (630 - main_t.width) // 2
        for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3), (3, 3), (-3, 3), (3, -3), (-3, -3), (5, 5)):
            cover.alpha_composite(dark, (x + dx, y + dy))
        cover.alpha_composite(main_t, (x, y))
    outlined("TORCH PASSERS", 40, (255, 255, 255), 20)
    outlined("of SPLORR!!", 24, ORANGE, 70)
    outlined("Hand it on. Forget why.", 14, (255, 225, 170), 462)
    os.makedirs("assets", exist_ok=True)
    cover.convert("RGB").save("assets/cover.png")
    print("assets/cover.png", cover.size)

main()
