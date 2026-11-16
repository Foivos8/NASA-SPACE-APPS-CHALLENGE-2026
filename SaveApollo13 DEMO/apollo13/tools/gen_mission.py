#!/usr/bin/env python3
"""Generates the art and the two surface maps for the "Design Your Mission" mode.

  assets/mission/tileset_surface.png   32x32 ground tiles for the Moon and Mars (8 columns)
  assets/mission/*.png                 props, vehicles, structures, space objects
  data/mission_moon.json               Moon surface: tiles, props, things to interact with, objectives
  data/mission_mars.json               Mars surface

The surface files use the same format as data/level1.json, so the walk-around
level engine (scripts/level.gd) runs them unchanged. Text for the rest of the
mode lives in data/missions.json, which is written by hand.

Run:  python3 tools/gen_mission.py   (needs Pillow)
"""
import json, math, os, random
from collections import deque
from PIL import Image, ImageDraw

T = 32
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "mission")
os.makedirs(OUT, exist_ok=True)


def new(w=T, h=T, c=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), c)


def R(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def save(img, name):
    img.save(os.path.join(OUT, name))


# ------------------------------------------------------------------ tiles --
def ground(base, speck_dark, speck_light, seed, pebbles=5):
    rnd = random.Random(seed)
    i = new(c=base + (255,)); d = ImageDraw.Draw(i)
    for _ in range(26):
        x, y = rnd.randrange(32), rnd.randrange(32)
        d.point((x, y), fill=speck_dark if rnd.random() < 0.6 else speck_light)
    for _ in range(pebbles):
        x, y = rnd.randrange(2, 29), rnd.randrange(2, 29)
        R(d, x, y, x + 1, y, speck_dark); d.point((x, y - 1), fill=speck_light)
    return i


def crater_tile(base, dark, light, seed):
    i = ground(base, dark, light, seed, 2); d = ImageDraw.Draw(i)
    d.ellipse([5, 7, 26, 24], fill=dark); d.ellipse([7, 9, 26, 24], fill=tuple(int(c * 0.88) for c in base))
    d.arc([5, 7, 26, 24], 180, 330, fill=light)
    return i


def rock_tile(base, dark, light, seed, body, body_d, body_l):
    i = ground(base, dark, light, seed, 1); d = ImageDraw.Draw(i)
    d.ellipse([4, 22, 28, 30], fill=dark)
    d.polygon([(6, 24), (8, 12), (15, 6), (24, 9), (27, 20), (22, 27), (10, 27)], fill=body)
    d.polygon([(8, 12), (15, 6), (24, 9), (17, 13)], fill=body_l)
    d.polygon([(17, 13), (24, 9), (27, 20), (22, 27)], fill=body_d)
    return i


def dune_tile(base, dark, light, seed):
    i = ground(base, dark, light, seed, 1); d = ImageDraw.Draw(i)
    for y0 in (8, 18, 27):
        d.arc([-6, y0 - 6, 38, y0 + 6], 200, 340, fill=light)
        d.arc([-6, y0 - 5, 38, y0 + 7], 200, 340, fill=dark)
    return i


MOON, MOON_D, MOON_L = (150, 152, 160), (118, 120, 130), (184, 186, 194)
MARS, MARS_D, MARS_L = (178, 96, 62), (140, 70, 46), (212, 132, 92)

tiles, names, solid = [], {}, set()


def add(name, img, is_solid=False):
    names[name] = len(tiles); tiles.append(img)
    if is_solid:
        solid.add(names[name])


for k in range(3):
    add(f"moon_ground_{k}", ground(MOON, MOON_D, MOON_L, 10 + k))
add("moon_crater", crater_tile(MOON, MOON_D, MOON_L, 20))
add("moon_rock", rock_tile(MOON, MOON_D, MOON_L, 21, (128, 130, 140), (92, 94, 104), (176, 178, 188)), True)
for k in range(3):
    add(f"mars_ground_{k}", ground(MARS, MARS_D, MARS_L, 30 + k))
add("mars_dune", dune_tile(MARS, MARS_D, MARS_L, 40))
add("mars_rock", rock_tile(MARS, MARS_D, MARS_L, 41, (128, 74, 54), (92, 50, 38), (170, 108, 80)), True)
COLS = 8
atlas = new(COLS * T, ((len(tiles) + COLS - 1) // COLS) * T)
for k, im in enumerate(tiles):
    atlas.paste(im, ((k % COLS) * T, (k // COLS) * T))
save(atlas, "tileset_surface.png")

# ------------------------------------------------------------------ props --
SILVER, SILVER_D, GOLD, GOLD_D, DARK = (214, 218, 226), (150, 156, 170), (214, 170, 60), (150, 112, 36), (40, 44, 56)


def lander():
    i = new(64, 64); d = ImageDraw.Draw(i)
    d.ellipse([6, 50, 58, 62], fill=(0, 0, 0, 70))
    for x0, x1 in ((14, 4), (50, 60)):                                   # legs
        d.line([(x0, 40), (x1, 56)], fill=SILVER_D, width=2); R(d, x1 - 3, 56, x1 + 3, 58, SILVER)
    R(d, 14, 34, 50, 48, GOLD); R(d, 14, 46, 50, 48, GOLD_D)             # descent stage
    for x in (22, 32, 42):
        R(d, x, 34, x, 48, GOLD_D)
    d.polygon([(27, 48), (37, 48), (40, 55), (24, 55)], fill=(84, 90, 104))   # engine bell
    d.polygon([(20, 34), (22, 14), (42, 14), (44, 34)], fill=SILVER)     # cabin
    d.polygon([(22, 14), (42, 14), (38, 8), (26, 8)], fill=(236, 240, 246))
    R(d, 26, 18, 31, 24, (60, 90, 150)); R(d, 34, 18, 39, 24, (60, 90, 150))  # windows
    R(d, 28, 28, 36, 34, DARK)                                           # hatch
    R(d, 31, 2, 32, 8, SILVER_D); R(d, 28, 1, 35, 2, SILVER_D)           # antenna
    R(d, 21, 26, 25, 29, (200, 40, 50)); R(d, 21, 26, 22, 27, (40, 60, 160))
    return i


def sample():
    i = new(); d = ImageDraw.Draw(i)
    d.ellipse([8, 22, 24, 28], fill=(0, 0, 0, 60))
    d.polygon([(9, 23), (11, 15), (17, 12), (23, 16), (24, 23), (18, 26)], fill=(96, 110, 150))
    d.polygon([(11, 15), (17, 12), (23, 16), (17, 18)], fill=(150, 170, 220))
    for p in ((14, 10), (22, 12), (10, 18)):                             # glint
        d.point(p, fill=(255, 255, 255)); d.point((p[0] + 1, p[1]), fill=(255, 255, 200))
    return i


def flag_site():
    i = new(); d = ImageDraw.Draw(i)
    d.ellipse([4, 14, 27, 29], outline=(255, 220, 76), width=2)
    for a in range(0, 24, 6):
        R(d, 4 + a, 21, 5 + a, 22, (0, 0, 0, 0))
    R(d, 14, 19, 17, 24, (255, 220, 76))
    return i


def flag():
    i = new(32, 48); d = ImageDraw.Draw(i)
    d.ellipse([10, 42, 22, 47], fill=(0, 0, 0, 70))
    R(d, 15, 4, 16, 45, SILVER); R(d, 14, 3, 17, 4, SILVER_D)
    R(d, 17, 6, 31, 20, (36, 70, 160)); R(d, 17, 19, 31, 20, (24, 48, 120))     # blue field
    d.ellipse([20, 8, 28, 16], fill=(70, 150, 230))                             # the Earth
    R(d, 22, 10, 24, 12, (80, 180, 100)); R(d, 25, 12, 26, 14, (80, 180, 100)); R(d, 21, 13, 23, 13, (250, 250, 250))
    return i


def boulder():
    i = new(64, 64); d = ImageDraw.Draw(i)
    d.ellipse([4, 44, 60, 62], fill=(0, 0, 0, 70))
    d.polygon([(6, 50), (10, 24), (26, 8), (46, 10), (58, 30), (54, 52), (30, 58)], fill=(124, 126, 136))
    d.polygon([(10, 24), (26, 8), (46, 10), (30, 26)], fill=(176, 178, 188))
    d.polygon([(30, 26), (46, 10), (58, 30), (54, 52), (36, 44)], fill=(92, 94, 104))
    d.line([(22, 30), (28, 46)], fill=(70, 72, 82)); d.line([(40, 20), (44, 34)], fill=(70, 72, 82))
    return i


def crater_big():
    i = new(96, 96); d = ImageDraw.Draw(i)
    d.ellipse([4, 8, 92, 90], fill=(176, 178, 188)); d.ellipse([10, 14, 88, 86], fill=(104, 106, 116))
    d.ellipse([16, 22, 86, 84], fill=(126, 128, 138)); d.ellipse([34, 40, 70, 70], fill=(112, 114, 124))
    d.arc([10, 14, 88, 86], 190, 320, fill=(70, 72, 82), width=3)
    d.ellipse([44, 46, 56, 58], fill=(150, 152, 162))                          # central peak
    return i


def rille():
    i = new(128, 32); d = ImageDraw.Draw(i)
    pts = [(0, 14), (20, 9), (44, 17), (70, 10), (98, 18), (128, 12)]
    d.line(pts, fill=(86, 88, 98), width=9); d.line(pts, fill=(60, 62, 72), width=4)
    d.line([(x, y - 5) for x, y in pts], fill=(184, 186, 194), width=1)
    return i


def hover(fixed):
    i = new(64, 32); d = ImageDraw.Draw(i)
    d.ellipse([6, 24, 58, 31], fill=(0, 0, 0, 70))
    body = (226, 228, 234) if fixed else (170, 150, 140)
    R(d, 8, 12, 56, 22, body); R(d, 8, 21, 56, 22, (120, 126, 140)); d.polygon([(56, 12), (62, 17), (56, 22)], fill=body)
    d.polygon([(22, 12), (26, 4), (44, 4), (48, 12)], fill=(120, 190, 240) if fixed else (90, 110, 130))   # canopy
    R(d, 12, 15, 20, 18, (255, 220, 76) if fixed else (90, 80, 70))
    for x in (12, 30, 48):                                                     # lift pads
        R(d, x, 23, x + 8, 25, (60, 66, 84))
        if fixed:
            R(d, x + 1, 26, x + 7, 27, (120, 220, 255, 200))
    if not fixed:
        d.line([(34, 6), (40, 10)], fill=DARK); d.line([(38, 5), (36, 11)], fill=DARK)              # cracked canopy
        R(d, 50, 9, 54, 12, (40, 40, 44)); d.line([(52, 8), (55, 3)], fill=(90, 90, 96))             # smoke stub
        R(d, 24, 22, 27, 27, (60, 66, 84))                                                          # dropped panel
    return i


def hover_ride():
    """Player sprite while riding the hover vehicle: 4 frames (down, up, left, right)."""
    sheet = new(128, 32)
    for k, face in enumerate(("down", "up", "left", "right")):
        f = new(); d = ImageDraw.Draw(f)
        d.ellipse([4, 25, 27, 31], fill=(0, 0, 0, 70))
        R(d, 5, 13, 26, 23, (226, 228, 234)); R(d, 5, 22, 26, 23, (120, 126, 140))
        for x in (6, 20):
            R(d, x, 24, x + 5, 25, (120, 220, 255))
        d.ellipse([10, 3, 21, 14], fill=(214, 232, 246), outline=(120, 140, 160))                  # helmet
        if face == "down":
            d.ellipse([12, 5, 19, 12], fill=(232, 190, 150)); R(d, 8, 16, 12, 18, (255, 220, 76))
        elif face == "up":
            d.ellipse([12, 5, 19, 12], fill=(250, 250, 250))
        else:
            s = -1 if face == "left" else 1
            d.ellipse([13 + s * 2, 5, 18 + s * 2, 12], fill=(232, 190, 150))
            R(d, 15 + s * 9, 16, 16 + s * 9, 19, (255, 220, 76))
        sheet.paste(f, (k * 32, 0))
    return sheet


def pad():
    i = new(64, 64); d = ImageDraw.Draw(i)
    R(d, 4, 4, 59, 59, (0, 0, 0, 40))
    for k in range(4, 60, 8):                                                  # dashed outline
        for (x0, y0, x1, y1) in ((k, 4, k + 3, 5), (k, 58, k + 3, 59), (4, k, 5, k + 3), (58, k, 59, k + 3)):
            R(d, x0, y0, x1, y1, (255, 220, 76))
    R(d, 30, 26, 33, 37, (255, 220, 76)); R(d, 26, 30, 37, 33, (255, 220, 76))
    return i


def habitat():
    i = new(64, 64); d = ImageDraw.Draw(i)
    d.ellipse([4, 46, 60, 62], fill=(0, 0, 0, 70))
    d.pieslice([8, 10, 56, 90], 180, 360, fill=(232, 234, 240)); d.pieslice([8, 10, 40, 90], 180, 270, fill=(250, 252, 255))
    d.arc([8, 10, 56, 90], 180, 360, fill=SILVER_D)
    for x in (20, 32, 44):
        d.line([(x, 14 + abs(32 - x) // 2), (x, 50)], fill=SILVER_D)
    R(d, 8, 48, 56, 54, SILVER_D); R(d, 27, 36, 37, 50, DARK); R(d, 29, 38, 35, 43, (120, 190, 240))   # airlock
    R(d, 14, 30, 20, 35, (120, 190, 240)); R(d, 44, 30, 50, 35, (120, 190, 240))
    return i


def solar():
    i = new(64, 64); d = ImageDraw.Draw(i)
    d.ellipse([6, 50, 58, 60], fill=(0, 0, 0, 70))
    for x0 in (6, 36):
        d.polygon([(x0, 40), (x0 + 6, 14), (x0 + 22, 14), (x0 + 22, 40)], fill=(40, 70, 150))
        for k in range(1, 4):
            d.line([(x0 + 2 + k, 40 - k * 6.5), (x0 + 22, 40 - k * 6.5)], fill=(120, 160, 230))
        d.line([(x0 + 12, 14), (x0 + 10, 40)], fill=(120, 160, 230))
        R(d, x0 + 10, 40, x0 + 12, 54, SILVER_D)
    R(d, 28, 44, 35, 54, SILVER); R(d, 30, 46, 33, 48, (70, 220, 110))
    return i


def antenna():
    i = new(64, 64); d = ImageDraw.Draw(i)
    d.ellipse([14, 52, 50, 62], fill=(0, 0, 0, 70))
    d.polygon([(26, 56), (30, 24), (34, 24), (38, 56)], fill=SILVER_D)
    for y in (32, 40, 48):
        d.line([(27, y + 4), (37, y - 2)], fill=SILVER)
    d.pieslice([10, 2, 54, 40], 20, 160, fill=(232, 234, 240)); d.arc([10, 2, 54, 40], 20, 160, fill=SILVER_D)
    d.line([(32, 30), (32, 12)], fill=DARK); R(d, 30, 9, 34, 13, (200, 40, 50))
    R(d, 22, 54, 42, 58, (120, 126, 140))
    return i


def lab():
    i = new(64, 64); d = ImageDraw.Draw(i)
    d.ellipse([4, 50, 60, 62], fill=(0, 0, 0, 70))
    R(d, 8, 28, 50, 54, (226, 228, 234)); R(d, 8, 52, 50, 54, SILVER_D); R(d, 8, 28, 50, 30, (250, 252, 255))
    R(d, 12, 34, 22, 42, (120, 190, 240)); R(d, 26, 34, 36, 42, (120, 190, 240)); R(d, 40, 38, 47, 54, DARK)
    R(d, 54, 12, 55, 54, SILVER_D)                                             # weather mast
    R(d, 50, 12, 59, 13, SILVER); R(d, 51, 8, 53, 12, (200, 40, 50)); R(d, 56, 9, 58, 12, (255, 220, 76))
    R(d, 16, 20, 34, 28, (60, 66, 84)); R(d, 18, 22, 32, 26, (70, 220, 110))   # instrument box
    return i


def crate():
    i = new(); d = ImageDraw.Draw(i)
    d.ellipse([3, 24, 28, 30], fill=(0, 0, 0, 60))
    R(d, 5, 8, 26, 26, (196, 170, 110)); R(d, 5, 8, 26, 10, (226, 204, 150)); R(d, 5, 24, 26, 26, (140, 116, 70))
    R(d, 14, 8, 17, 26, (140, 116, 70)); R(d, 8, 14, 12, 17, (200, 40, 50))
    return i


# ------------------------------------------------------------------ space --
def mars_planet():
    i = new(48, 48); d = ImageDraw.Draw(i)
    d.ellipse([0, 0, 47, 47], fill=(120, 54, 36)); d.ellipse([1, 1, 44, 44], fill=(188, 96, 60)); d.ellipse([3, 3, 36, 36], fill=(214, 124, 80))
    for (x0, y0, x1, y1) in [(10, 14, 22, 18), (24, 22, 36, 27), (8, 28, 18, 31), (26, 10, 33, 13)]:
        R(d, x0, y0, x1, y1, (160, 80, 52))
    R(d, 17, 1, 30, 3, (245, 240, 236)); R(d, 18, 44, 29, 46, (245, 240, 236))
    m = new(48, 48); ImageDraw.Draw(m).ellipse([0, 0, 47, 47], fill=(255, 255, 255, 255))
    out = new(48, 48); out.paste(i, (0, 0), m)
    return out


def earth_big():
    """Earth as seen from orbit, 96x96, with three things worth photographing:
    a tropical storm (30, 60), the polar ice (48, 9) and a desert coast (62, 38)."""
    i = new(96, 96); d = ImageDraw.Draw(i)
    d.ellipse([0, 0, 95, 95], fill=(24, 60, 130)); d.ellipse([1, 1, 90, 90], fill=(40, 100, 190)); d.ellipse([4, 4, 76, 76], fill=(58, 126, 214))
    d.polygon([(50, 22), (62, 20), (76, 26), (82, 38), (76, 46), (66, 48), (56, 44), (48, 34)], fill=(214, 180, 110))      # desert
    d.polygon([(54, 26), (64, 24), (72, 30), (70, 38), (60, 40)], fill=(232, 204, 140))
    d.polygon([(56, 44), (66, 48), (76, 46), (78, 58), (72, 72), (64, 80), (58, 70), (54, 56)], fill=(50, 150, 80))       # forest
    d.polygon([(60, 52), (70, 54), (70, 66), (64, 72), (60, 62)], fill=(34, 118, 62))
    d.polygon([(40, 14), (52, 12), (58, 18), (50, 22), (42, 20)], fill=(90, 160, 90))                                    # northern land
    d.polygon([(10, 34), (20, 30), (26, 38), (22, 48), (12, 46)], fill=(90, 160, 90)); d.polygon([(14, 36), (20, 34), (22, 42), (16, 44)], fill=(60, 140, 80))
    d.line([(64, 30), (58, 42), (52, 44)], fill=(58, 126, 214))                                                           # river
    d.pieslice([24, 0, 72, 16], 0, 180, fill=(244, 248, 252)); R(d, 34, 2, 62, 6, (244, 248, 252)); R(d, 40, 8, 58, 10, (220, 232, 246))   # north ice
    d.pieslice([30, 82, 66, 104], 180, 360, fill=(244, 248, 252))                                                         # south ice
    for k in range(26):                                                                                                    # storm spiral
        a = k * 0.55; r = 2 + k * 0.42
        x, y = 30 + r * math.cos(a), 60 + r * math.sin(a) * 0.9
        R(d, x - 1, y - 1, x + 1, y + 1, (250, 250, 252))
    R(d, 29, 59, 31, 61, (40, 100, 190))
    for (x0, y0, x1, y1) in [(6, 22, 24, 24), (70, 14, 84, 15), (40, 46, 52, 47), (14, 70, 30, 71), (76, 62, 88, 63)]:      # cloud bands
        R(d, x0, y0, x1, y1, (236, 242, 250))
    sh = new(96, 96); ImageDraw.Draw(sh).ellipse([30, 30, 140, 140], fill=(0, 0, 20, 70)); i.alpha_composite(sh)
    m = Image.new("L", (96, 96), 0); ImageDraw.Draw(m).ellipse([0, 0, 95, 95], fill=255)
    out = new(96, 96); out.paste(i, (0, 0), m)
    return out


def satellite(fixed):
    i = new(72, 40); d = ImageDraw.Draw(i)
    R(d, 26, 12, 46, 28, SILVER); R(d, 26, 26, 46, 28, SILVER_D); R(d, 26, 12, 46, 13, (240, 242, 246))   # body
    R(d, 30, 16, 36, 22, (60, 90, 150)); R(d, 39, 17, 43, 21, (70, 220, 110) if fixed else (200, 50, 50))
    for side, x0 in (("l", 2), ("r", 48)):                                     # solar wings
        R(d, x0, 14, x0 + 22, 26, (40, 70, 150))
        for k in range(1, 4):
            R(d, x0 + k * 5 + 1, 14, x0 + k * 5 + 1, 26, (120, 160, 230))
        R(d, x0, 20, x0 + 22, 20, (120, 160, 230))
    if not fixed:
        d.polygon([(52, 14), (62, 14), (58, 21), (66, 26), (54, 26)], fill=(0, 0, 0, 0))                  # torn right wing
        d.line([(54, 13), (60, 22)], fill=(200, 50, 50)); d.line([(58, 22), (64, 27)], fill=(200, 50, 50))
    dish_tilt = 0 if fixed else 5
    d.line([(36, 12), (36 + dish_tilt, 5)], fill=SILVER_D)
    d.pieslice([28 + dish_tilt, -4, 44 + dish_tilt, 10], 20, 160, fill=(232, 234, 240))
    R(d, 33, 28, 39, 33, (84, 90, 104)); R(d, 35, 33, 37, 36, GOLD if fixed else (90, 80, 60))
    return i


def asteroid(size, seed):
    rnd = random.Random(seed)
    i = new(size, size); d = ImageDraw.Draw(i)
    c = size / 2
    pts = []
    for k in range(9):
        a = k / 9 * 6.283; r = c * rnd.uniform(0.72, 0.98)
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    d.polygon(pts, fill=(122, 108, 98)); d.polygon([(x * 0.8 + c * 0.1, y * 0.8 + c * 0.05) for x, y in pts], fill=(150, 134, 120))
    for _ in range(max(2, size // 8)):
        x, y = rnd.uniform(c * 0.5, c * 1.4), rnd.uniform(c * 0.5, c * 1.4)
        r = rnd.uniform(1, size / 9)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(96, 84, 76))
    return i


def debris(kind):
    if kind == 1:                                                               # torn solar panel
        i = new(22, 14); d = ImageDraw.Draw(i)
        d.polygon([(0, 2), (18, 0), (21, 9), (12, 13), (2, 11)], fill=(40, 70, 150))
        d.line([(6, 1), (7, 12)], fill=(120, 160, 230)); d.line([(13, 1), (14, 12)], fill=(120, 160, 230))
        d.line([(1, 6), (20, 5)], fill=(120, 160, 230)); d.line([(18, 0), (21, 9)], fill=(200, 60, 50))
    elif kind == 2:                                                             # girder
        i = new(22, 8); d = ImageDraw.Draw(i)
        R(d, 0, 2, 21, 5, SILVER_D); R(d, 0, 2, 21, 2, SILVER)
        for x in range(2, 20, 5):
            d.line([(x, 5), (x + 3, 2)], fill=DARK)
        R(d, 19, 0, 21, 7, (120, 126, 140))
    else:                                                                       # dead satellite body
        i = new(22, 18); d = ImageDraw.Draw(i)
        R(d, 5, 4, 16, 14, (176, 150, 80)); R(d, 5, 13, 16, 14, (120, 100, 50))
        R(d, 7, 6, 10, 9, (60, 66, 84)); d.line([(16, 6), (21, 1)], fill=SILVER_D); d.line([(5, 10), (0, 15)], fill=SILVER_D)
        R(d, 12, 8, 14, 10, (200, 50, 50))
    return i


def rocket_side():
    """The player's spacecraft seen from the side, nose to the right."""
    i = new(36, 16); d = ImageDraw.Draw(i)
    R(d, 6, 4, 26, 11, (232, 234, 240)); R(d, 6, 10, 26, 11, SILVER_D); R(d, 6, 4, 26, 4, (252, 252, 255))
    d.polygon([(26, 4), (35, 7), (35, 8), (26, 11)], fill=(206, 60, 56))
    d.polygon([(4, 0), (12, 4), (6, 4)], fill=(206, 60, 56)); d.polygon([(4, 15), (12, 11), (6, 11)], fill=(206, 60, 56))
    R(d, 2, 5, 5, 10, (84, 90, 104)); R(d, 0, 6, 1, 9, (60, 66, 84))
    R(d, 19, 6, 22, 8, (90, 170, 240)); R(d, 13, 6, 16, 8, (90, 170, 240)); R(d, 9, 4, 9, 11, SILVER_D)
    return i


def capsule():
    i = new(24, 20); d = ImageDraw.Draw(i)
    d.polygon([(9, 1), (14, 1), (22, 15), (1, 15)], fill=(190, 196, 208)); d.line([(9, 1), (1, 15)], fill=(236, 240, 246))
    R(d, 1, 15, 22, 18, (120, 90, 60)); R(d, 10, 7, 13, 10, (60, 90, 150))
    return i


def parachute():
    i = new(48, 30); d = ImageDraw.Draw(i)
    d.pieslice([2, 2, 45, 44], 180, 360, fill=(240, 240, 240))
    for k, x in enumerate(range(2, 46, 11)):
        d.pieslice([x, 2, x + 11, 44], 180, 360, fill=(230, 90, 50) if k % 2 == 0 else (245, 245, 245))
    d.arc([2, 2, 45, 44], 180, 360, fill=(150, 150, 156))
    for x in (4, 16, 31, 43):
        d.line([(x, 23), (24, 29)], fill=(200, 200, 206))
    return i


def warning_mark():
    i = new(12, 12); d = ImageDraw.Draw(i)
    d.polygon([(6, 0), (11, 11), (0, 11)], fill=(255, 200, 60)); R(d, 5, 4, 6, 7, (40, 30, 10)); R(d, 5, 9, 6, 9, (40, 30, 10))
    return i


for name, img in [
    ("lander.png", lander()), ("sample.png", sample()), ("flag_site.png", flag_site()), ("flag.png", flag()),
    ("boulder.png", boulder()), ("crater_big.png", crater_big()), ("rille.png", rille()),
    ("hover_broken.png", hover(False)), ("hover_fixed.png", hover(True)), ("hover_ride.png", hover_ride()),
    ("pad.png", pad()), ("habitat.png", habitat()), ("solar.png", solar()), ("antenna.png", antenna()), ("lab.png", lab()),
    ("crate.png", crate()), ("mars.png", mars_planet()), ("satellite_broken.png", satellite(False)),
    ("satellite_fixed.png", satellite(True)), ("asteroid_1.png", asteroid(26, 1)), ("asteroid_2.png", asteroid(18, 2)),
    ("debris_1.png", debris(1)), ("debris_2.png", debris(2)), ("debris_3.png", debris(3)),
    ("capsule.png", capsule()), ("rocket_side.png", rocket_side()), ("earth_big.png", earth_big()), ("parachute.png", parachute()), ("warning.png", warning_mark()),
]:
    save(img, name)

# ------------------------------------------------------------------- maps --
W, H = 30, 20


def cells(x, y, w=1, h=1):
    return [[x + dx, y + dy] for dy in range(h) for dx in range(w)]


def build_map(theme, props, interactables, objectives, checklist, start, seed, decor_tile, rock_tile_name, n_rocks, n_decor):
    rnd = random.Random(seed)
    g = [[names[f"{theme}_ground_{rnd.randrange(3)}"] for _ in range(W)] for _ in range(H)]
    blocked = set()
    for p in props:
        if p.get("solid", True):
            for c in cells(p["tile"][0], p["tile"][1], *p.get("size", [1, 1])):
                blocked.add(tuple(c))
    # keep a clear ring around everything the player has to reach
    keep_clear = set()
    for (bx, by) in list(blocked) + [tuple(start)]:
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                keep_clear.add((bx + dx, by + dy))
    for p in props:                                   # decals (not solid) also stay clear of rocks
        for c in cells(p["tile"][0], p["tile"][1], *p.get("size", [1, 1])):
            keep_clear.add(tuple(c))
    rocks = set()
    while len(rocks) < n_rocks:
        c = (rnd.randrange(W), rnd.randrange(H))
        if c not in keep_clear and c not in rocks:
            rocks.add(c)
    for (x, y) in rocks:
        g[y][x] = names[rock_tile_name]
    placed = 0
    while placed < n_decor:
        x, y = rnd.randrange(W), rnd.randrange(H)
        if (x, y) not in rocks and (x, y) not in keep_clear:
            g[y][x] = names[decor_tile]; placed += 1

    def is_solid(x, y):
        return not (0 <= x < W and 0 <= y < H) or (x, y) in blocked or (x, y) in rocks

    seen = {tuple(start)}; q = deque([tuple(start)])
    while q:
        x, y = q.popleft()
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            c = (x + dx, y + dy)
            if c not in seen and not is_solid(*c):
                seen.add(c); q.append(c)
    stand = {}
    for it in interactables:
        ts = {tuple(t) for t in it["tiles"]}
        spots = sorted(c for (x, y) in ts for c in ((x, y + 1), (x - 1, y), (x + 1, y), (x, y - 1)) if c in seen and c not in ts)
        assert spots, f"{theme}: cannot reach {it['id']}"
        below = [c for c in spots if any(c == (x, y + 1) for (x, y) in ts)]
        stand[it["id"]] = list((below or spots)[0])
        it["stand"] = [list(s) for s in spots[:4]]
    for o in objectives:
        o["markers"] = [stand[t] for t in o["targets"]]
    return {
        "name": f"Design Your Mission - {theme} surface", "tile_size": T, "width": W, "height": H,
        "atlas": {"image": "res://assets/mission/tileset_surface.png", "columns": COLS, "tile_names": names, "solid_ids": sorted(solid)},
        "layers": {"ground": g, "objects": [[-1] * W for _ in range(H)]},
        "player_start": start, "npcs": [], "zones": [], "hatch_tiles": [], "covered_window_tiles": [],
        "props": props, "interactables": interactables, "objectives": objectives, "checklist": checklist, "launch_events": [],
    }


def thing(id_, name, tiles, steps, required=True):
    return {"id": id_, "name": name, "tiles": tiles, "required": required, "appearance": "", "steps": steps}


# ---- Moon ----
SAMPLES = [
    ("sample_1", [5, 4], "Moon dust", "You scoop up a bag of grey lunar soil. It is called regolith: rock ground to powder by billions of years of meteorite impacts."),
    ("sample_2", [24, 3], "Dark basalt", "A dark, heavy rock: basalt. It is cooled lava from ancient eruptions that filled the Moon's dark 'seas'."),
    ("sample_3", [26, 15], "Pale highland rock", "A pale, light rock from the lunar highlands. Rocks like this are among the oldest on the Moon, over 4 billion years old."),
    ("sample_4", [8, 16], "Breccia", "A lumpy rock made of many fragments welded together by the heat of an impact. Geologists call it breccia."),
    ("sample_5", [17, 5], "Glass beads", "Tiny orange and green glass beads glint in the dust. They formed when droplets of lava cooled in fountains of fire long ago."),
]
moon_props = [{"id": "lander", "sprite": "lander.png", "tile": [14, 9], "size": [2, 2]},
              {"id": "boulder", "sprite": "boulder.png", "tile": [21, 9], "size": [2, 2]},
              {"id": "crater", "sprite": "crater_big.png", "tile": [5, 8], "size": [3, 3]},
              {"id": "rille", "sprite": "rille.png", "tile": [11, 16], "size": [4, 1]},
              {"id": "flag_site", "sprite": "flag_site.png", "tile": [18, 12], "size": [1, 1]}]
moon_things = [
    thing("lander", "Lander", cells(14, 9, 2, 2), {
        "default": {"title": "Lander", "pages": ["Your ride home. Finish the surface objectives before you climb back in: 5 samples, 3 landmarks and the flag."]},
        "return": {"title": "Lander", "pages": ["Samples stowed, flag planted. You climb the ladder and seal the hatch.", "Mission Control: 'Good work. You are GO for lunar liftoff.'"]}}),
    thing("boulder", "Giant boulder", cells(21, 9, 2, 2), {"default": {"title": "Landmark: giant boulder", "pages": [
        "A boulder as big as a house, thrown here when a meteorite struck nearby.",
        "With no wind or rain on the Moon, it has sat exactly like this for millions of years. Your bootprints will last just as long."]}}),
    thing("crater", "Impact crater", cells(5, 8, 3, 3), {"default": {"title": "Landmark: impact crater", "pages": [
        "You stand on the rim of an impact crater. The Moon has no atmosphere to burn up incoming rocks, so even small ones reach the ground.",
        "The little hill in the middle is a central peak: the ground rebounded after the impact, like a drop splashing in water."]}}),
    thing("rille", "Lava channel", cells(11, 16, 4, 1), {"default": {"title": "Landmark: lava channel", "pages": [
        "A winding trench called a rille. Rivers of lava carved channels like this more than 3 billion years ago.",
        "Gravity here is one sixth of Earth's. You could jump across with a running start."]}}),
    thing("flag_site", "Flag site", cells(18, 12), {"default": {"title": "Flag site", "pages": [
        "A flat patch of firm ground, marked for the flag.", "You twist the pole into the regolith and unfurl the Earth flag. A wire along the top holds it out, because there is no wind to make it fly."]}}),
]
for sid, tile, label, text in SAMPLES:
    moon_props.append({"id": sid, "sprite": "sample.png", "tile": tile, "size": [1, 1]})
    moon_things.append(thing(sid, "Sample: " + label, cells(*tile), {"default": {"title": "Sample collected: " + label, "pages": [text]}}))
moon_objectives = [
    {"id": "surface", "text": "Explore, collect samples, plant the flag", "hint": "Follow the yellow markers. Any order.",
     "type": "interact", "targets": [s[0] for s in SAMPLES] + ["boulder", "crater", "rille", "flag_site"]},
    {"id": "return", "text": "Return to the lander", "hint": "Climb back in for the trip home.", "type": "interact", "targets": ["lander"]},
]
moon_checklist = [
    {"id": "samples", "text": "Collect Moon samples", "targets": [s[0] for s in SAMPLES]},
    {"id": "landmarks", "text": "Explore the landmarks", "targets": ["boulder", "crater", "rille"]},
    {"id": "flag", "text": "Plant the Earth flag", "targets": ["flag_site"]},
    {"id": "return", "text": "Return to the lander", "targets": ["lander"]},
]
moon = build_map("moon", moon_props, moon_things, moon_objectives, moon_checklist, [14, 11], 7, "moon_crater", "moon_rock", 26, 34)

# ---- Mars ----
SITES = [("site_habitat", [18, 4], "habitat", "Habitat dome", "A pressurised dome to live in. Mars air is mostly carbon dioxide and a hundred times thinner than Earth's."),
         ("site_solar", [23, 4], "solar", "Solar array", "Sunlight on Mars is less than half as strong as on Earth, so the base needs wide panels."),
         ("site_antenna", [18, 9], "antenna", "Antenna", "A dish to talk to Earth. A radio signal takes between 3 and 22 minutes to cross the distance, depending on where the planets are."),
         ("site_lab", [23, 9], "lab", "Science lab", "A laboratory with a weather mast, to study the soil, the dust storms and the search for signs of ancient water.")]
mars_props = [{"id": "lander", "sprite": "lander.png", "tile": [3, 9], "size": [2, 2]},
              {"id": "hover", "sprite": "hover_broken.png", "tile": [9, 5], "size": [2, 1]},
              {"id": "crate_1", "sprite": "crate.png", "tile": [6, 9], "size": [1, 1]},
              {"id": "crate_2", "sprite": "crate.png", "tile": [6, 11], "size": [1, 1]}]
mars_things = [
    thing("lander", "Lander", cells(3, 9, 2, 2), {
        "default": {"title": "Lander", "pages": ["Your ride home. Repair the hover vehicle and finish the research base before you leave."]},
        "return": {"title": "Lander", "pages": ["The base is running and the hover vehicle is parked. You climb aboard and seal the hatch.", "Mission Control: 'Outstanding. You are GO for liftoff from Mars.'"]}}),
    thing("hover", "Hover vehicle", cells(9, 5, 2, 1), {
        "default": {"title": "Hover vehicle", "pages": ["The repaired hover vehicle hums quietly, floating a hand's width above the dust."]},
        "repair": {"title": "Broken hover vehicle", "minigame": "hover_repair", "pages": [
            "A hover vehicle left by an earlier supply drop. Its canopy is cracked, a lift pad hangs loose and the power cell is dead.",
            "The base parts are too heavy to carry by hand across this plain. You need this machine working."]}}),
    thing("crate_1", "Supply crate", cells(6, 9), {"default": {"title": "Supply crate", "pages": ["Parts for the research base, dropped ahead of you by a cargo flight. They will ride on the hover vehicle."]}}, False),
    thing("crate_2", "Supply crate", cells(6, 11), {"default": {"title": "Supply crate", "pages": ["Food, water and air for the first weeks. On Mars a day lasts 24 hours and 37 minutes, almost like home."]}}, False),
]
for sid, tile, key, label, text in SITES:
    mars_props.append({"id": sid, "sprite": "pad.png", "tile": tile, "size": [2, 2], "built": key + ".png"})
    mars_things.append(thing(sid, "Build site: " + label, cells(tile[0], tile[1], 2, 2), {
        "default": {"title": "Build site: " + label, "pages": ["A marked pad for the " + label.lower() + ". Repair the hover vehicle first: it carries the parts."]},
        "base": {"title": "Build site: " + label, "minigame": "build_" + key, "pages": [text]},
        "built": {"title": label, "pages": ["The " + label.lower() + " is assembled and working."]}}))
mars_objectives = [
    {"id": "repair", "text": "Repair the broken hover vehicle", "hint": "It lies north-east of the lander.", "type": "interact", "targets": ["hover"]},
    {"id": "base", "text": "Build the scientific research base", "hint": "Four marked pads to the east. Any order.", "type": "interact", "targets": [s[0] for s in SITES]},
    {"id": "return", "text": "Return to the lander", "hint": "Head back west for the trip home.", "type": "interact", "targets": ["lander"]},
]
mars_checklist = [
    {"id": "repair", "text": "Repair the hover vehicle", "targets": ["hover"]},
    {"id": "base", "text": "Build the research base", "targets": [s[0] for s in SITES]},
    {"id": "return", "text": "Return to the lander", "targets": ["lander"]},
]
mars = build_map("mars", mars_props, mars_things, mars_objectives, mars_checklist, [3, 11], 11, "mars_dune", "mars_rock", 30, 40)

for name, level in (("mission_moon.json", moon), ("mission_mars.json", mars)):
    with open(os.path.join(ROOT, "data", name), "w") as f:
        json.dump(level, f, indent=1)

# preview (not used by the game)
def preview(level, out):
    m = new(W * T, H * T, (0, 0, 0, 255))
    for y in range(H):
        for x in range(W):
            m.alpha_composite(tiles[level["layers"]["ground"][y][x]], (x * T, y * T))
    for p in level["props"]:
        m.alpha_composite(Image.open(os.path.join(OUT, p["sprite"])).convert("RGBA"), (p["tile"][0] * T, p["tile"][1] * T))
    m.save(out)

preview(moon, "/tmp/mission_moon.png"); preview(mars, "/tmp/mission_mars.png")
print("tiles:", len(tiles), "| images:", len(os.listdir(OUT)), "| maps written")
