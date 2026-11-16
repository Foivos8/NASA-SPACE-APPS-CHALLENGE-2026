#!/usr/bin/env python3
"""Generates placeholder pixel art for the main menu and Levels 1-2 into assets/levels/.

  cloud_1..3.png        clouds for the sky background
  earth.png   48x48     Earth for the trajectory map (also scaled up for the orbit view)
  moon.png    20x20     Moon for the trajectory map
  csm.png     34x14     Command and Service Module, side view, nose to the right
  csm_damaged.png       the same with the blown-out Service Module panel
  lm.png      18x14     Lunar Module, docking port to the left
  sivb.png    46x16     Saturn V third stage with the open adapter, engine to the left
  ship.png    7x5       map marker
  check_done.png, check_now.png, check_todo.png   9x9 checklist marks

Run:  python3 tools/gen_level_art.py   (needs Pillow)
"""
import os, random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "levels")
os.makedirs(OUT, exist_ok=True)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def R(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def save(img, name):
    img.save(os.path.join(OUT, name))


def cloud(w, h, seed):
    rnd = random.Random(seed)
    i = new(w, h); d = ImageDraw.Draw(i)
    WHITE, SHADE = (250, 252, 255), (208, 226, 244)
    base = h - 3
    R(d, 2, base - 3, w - 3, base, SHADE)
    x = 3
    while x < w - 8:
        bw = rnd.randint(7, 12); bh = rnd.randint(4, h - 5)
        R(d, x, base - 2 - bh, min(x + bw, w - 4), base - 2, WHITE)
        x += bw - 3
    R(d, 2, base - 5, w - 3, base - 2, WHITE)
    R(d, 4, base + 1, w - 5, base + 1, SHADE)
    return i


def earth():
    i = new(48, 48); d = ImageDraw.Draw(i)
    d.ellipse([0, 0, 47, 47], fill=(22, 60, 130))
    d.ellipse([1, 1, 44, 44], fill=(44, 110, 200))
    d.ellipse([3, 3, 36, 36], fill=(60, 136, 224))
    LAND, LAND_D = (70, 160, 84), (52, 128, 70)
    for (x0, y0, x1, y1) in [(10, 9, 20, 14), (12, 14, 18, 22), (8, 12, 12, 17), (14, 22, 17, 27),      # Americas
                             (27, 12, 36, 17), (29, 17, 35, 26), (31, 26, 34, 31), (36, 14, 41, 19)]:   # Africa / Europe
        R(d, x0, y0, x1, y1, LAND)
    for (x0, y0, x1, y1) in [(15, 16, 18, 20), (31, 20, 34, 25), (37, 15, 40, 17)]:
        R(d, x0, y0, x1, y1, LAND_D)
    for (x0, y0, x1, y1) in [(5, 22, 13, 23), (20, 8, 28, 9), (22, 30, 30, 31), (9, 33, 16, 34), (33, 34, 39, 35),
                             (18, 38, 27, 39), (24, 5, 29, 5)]:
        R(d, x0, y0, x1, y1, (240, 246, 252))                                                            # clouds
    R(d, 16, 1, 30, 2, (240, 246, 252)); R(d, 17, 45, 30, 46, (240, 246, 252))                            # ice caps
    mask = new(48, 48); ImageDraw.Draw(mask).ellipse([0, 0, 47, 47], fill=(255, 255, 255, 255))
    out = new(48, 48); out.paste(i, (0, 0), mask)
    sh = new(48, 48); ds = ImageDraw.Draw(sh)                                                            # night-side shading
    ds.ellipse([0, 0, 47, 47], fill=(0, 0, 20, 110)); ds.ellipse([-8, -8, 40, 40], fill=(0, 0, 0, 0))
    out.alpha_composite(Image.composite(sh, new(48, 48), mask))
    return out


def moon():
    i = new(20, 20); d = ImageDraw.Draw(i)
    d.ellipse([0, 0, 19, 19], fill=(150, 152, 160))
    d.ellipse([0, 0, 17, 17], fill=(196, 198, 204))
    for (x, y, r) in [(5, 5, 2), (11, 8, 1), (7, 12, 2), (13, 13, 1), (12, 3, 1)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=(160, 162, 170))
        d.point((x - r, y - r), fill=(220, 222, 228))
    return i


SILVER, SILVER_D, DARK = (214, 218, 226), (150, 156, 170), (40, 44, 56)


def csm(damaged=False):
    i = new(34, 14); d = ImageDraw.Draw(i)
    d.polygon([(0, 2), (5, 5), (5, 8), (0, 11)], fill=(84, 90, 104))                 # engine bell
    R(d, 5, 5, 6, 8, DARK)
    R(d, 7, 1, 23, 12, SILVER); R(d, 7, 11, 23, 12, SILVER_D); R(d, 7, 1, 23, 1, (240, 242, 246))   # service module
    for x in (11, 15, 19):
        R(d, x, 2, x, 11, SILVER_D)
    R(d, 21, 5, 22, 8, (250, 250, 250)); d.point((21, 4), fill=DARK); d.point((21, 9), fill=DARK)    # thruster quad
    d.polygon([(24, 1), (32, 5), (32, 8), (24, 12)], fill=(190, 196, 208))           # command module
    d.line([(24, 1), (32, 5)], fill=(236, 240, 246)); R(d, 27, 5, 28, 6, (60, 90, 150))
    R(d, 32, 6, 33, 7, SILVER_D)                                                     # docking probe
    if damaged:
        d.polygon([(11, 2), (19, 2), (20, 6), (18, 10), (12, 10), (10, 6)], fill=(26, 26, 34))
        R(d, 12, 4, 14, 7, (120, 126, 140)); R(d, 16, 5, 17, 8, (96, 104, 124))      # exposed tanks
        d.point((13, 5), fill=(240, 150, 60)); d.point((18, 3), fill=(240, 150, 60))
        d.line([(10, 2), (11, 0)], fill=SILVER_D); d.line([(20, 10), (21, 12)], fill=SILVER_D)
    return i


def lm():
    i = new(18, 14); d = ImageDraw.Draw(i)
    GOLD, GOLD_D = (214, 170, 60), (150, 112, 36)
    R(d, 0, 6, 1, 7, SILVER_D)                                                       # docking port
    d.polygon([(2, 3), (8, 2), (9, 11), (2, 10)], fill=(176, 182, 196))              # ascent stage
    R(d, 4, 5, 5, 6, (60, 90, 150)); R(d, 2, 3, 8, 3, (220, 224, 232))
    R(d, 9, 2, 14, 11, GOLD); R(d, 9, 10, 14, 11, GOLD_D); R(d, 11, 2, 11, 11, GOLD_D)   # descent stage
    R(d, 15, 5, 17, 8, (84, 90, 104))                                                # descent engine
    d.line([(12, 1), (16, 0)], fill=SILVER_D); d.line([(12, 12), (16, 13)], fill=SILVER_D)   # folded legs
    return i


def sivb():
    i = new(46, 16); d = ImageDraw.Draw(i)
    d.polygon([(0, 4), (6, 6), (6, 9), (0, 11)], fill=(84, 90, 104))                 # J-2 engine
    R(d, 7, 1, 36, 14, (240, 240, 236)); R(d, 7, 13, 36, 14, (176, 178, 184))
    R(d, 7, 1, 10, 14, (30, 32, 40)); R(d, 22, 1, 25, 7, (30, 32, 40))
    R(d, 36, 0, 38, 15, (176, 178, 184))                                             # adapter ring
    R(d, 39, 1, 45, 1, (176, 178, 184)); R(d, 39, 14, 45, 14, (176, 178, 184))       # open adapter
    R(d, 39, 2, 45, 13, (24, 26, 34))
    return i


def ship():
    i = new(7, 5); d = ImageDraw.Draw(i)
    R(d, 0, 1, 4, 3, (250, 250, 250)); R(d, 5, 2, 6, 2, (250, 250, 250)); R(d, 0, 2, 0, 2, (240, 170, 60))
    return i


def check(kind):
    i = new(9, 9); d = ImageDraw.Draw(i)
    if kind == "done":
        R(d, 0, 0, 8, 8, (30, 90, 50)); d.rectangle([0, 0, 8, 8], outline=(110, 240, 150))
        d.line([(2, 4), (3, 6), (6, 2)], fill=(200, 255, 220)); d.line([(2, 5), (3, 7), (7, 2)], fill=(110, 240, 150))
    elif kind == "now":
        R(d, 0, 0, 8, 8, (90, 70, 14)); d.rectangle([0, 0, 8, 8], outline=(255, 220, 76))
        d.polygon([(3, 2), (6, 4), (3, 6)], fill=(255, 220, 76))
    else:
        R(d, 0, 0, 8, 8, (26, 30, 42)); d.rectangle([0, 0, 8, 8], outline=(130, 140, 160))
    return i


if __name__ == "__main__":
    save(cloud(44, 16, 1), "cloud_1.png")
    save(cloud(60, 20, 2), "cloud_2.png")
    save(cloud(30, 13, 3), "cloud_3.png")
    save(earth(), "earth.png")
    save(moon(), "moon.png")
    save(csm(), "csm.png")
    save(csm(True), "csm_damaged.png")
    save(lm(), "lm.png")
    save(sivb(), "sivb.png")
    save(ship(), "ship.png")
    for k in ("done", "now", "todo"):
        save(check(k), f"check_{k}.png")
    names = sorted(n for n in os.listdir(OUT) if n.endswith(".png"))
    sheet = Image.new("RGBA", (sum(Image.open(os.path.join(OUT, n)).width + 4 for n in names), 52), (20, 24, 40, 255))
    x = 2
    for n in names:
        im = Image.open(os.path.join(OUT, n)).convert("RGBA"); sheet.alpha_composite(im, (x, 2)); x += im.width + 4
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save("/tmp/level_art_preview.png")
    print("wrote", len(names), "images to", OUT)
