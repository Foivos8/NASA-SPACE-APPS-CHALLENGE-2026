#!/usr/bin/env python3
"""Generates placeholder pixel art for the three mini-games into assets/minigames/.

  astronaut_base.png      48x72  astronaut in undergarment (suit-up base, medical patient)
  layer_*.png             48x72  overlays drawn on top of the base: suit, headset, helmet, gloves, connections
  doctor.png              48x72  flight surgeon
  icon_*.png              24x24  equipment and medical instrument icons
  gauge_<id>.png          40x40  dial faces; the green band is read from data/minigames.json
  saturn_v.png            16x96  the rocket, for the launch sequence view
  launch_tower.png        24x104 launch umbilical tower with swing arms
  flame.png               16x28  engine exhaust

Run:  python3 tools/gen_minigame_art.py   (needs Pillow)
"""
import json, math, os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "minigames")
os.makedirs(OUT, exist_ok=True)

SKIN, SKIN_D = (232, 190, 150), (200, 154, 116)
HAIR = (96, 72, 52)
UNDER, UNDER_D = (214, 220, 228), (176, 184, 196)
SUIT, SUIT_D = (238, 238, 234), (176, 178, 184)
RING = (120, 130, 150)
BLUE, RED = (60, 110, 220), (220, 60, 60)
DARK = (30, 32, 40)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def R(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def save(img, name):
    img.save(os.path.join(OUT, name))


# ---------------------------------------------------------------- figures --
def head(d, hair=HAIR):
    d.ellipse([16, 3, 31, 19], fill=SKIN)
    R(d, 21, 19, 26, 21, SKIN_D)                                   # neck
    d.pieslice([16, 3, 31, 17], 180, 360, fill=hair)               # hair
    R(d, 17, 9, 30, 10, SKIN)
    R(d, 20, 11, 21, 12, DARK); R(d, 26, 11, 27, 12, DARK)         # eyes
    R(d, 22, 15, 25, 15, (170, 100, 90))                           # mouth


def astronaut_base():
    i = new(48, 72); d = ImageDraw.Draw(i)
    d.ellipse([12, 66, 35, 71], fill=(0, 0, 0, 60))
    R(d, 15, 22, 32, 44, UNDER); R(d, 15, 43, 32, 44, UNDER_D)     # torso
    R(d, 10, 23, 14, 41, UNDER); R(d, 33, 23, 37, 41, UNDER)       # arms
    R(d, 10, 42, 14, 46, SKIN); R(d, 33, 42, 37, 46, SKIN)         # hands
    R(d, 16, 45, 23, 66, UNDER); R(d, 25, 45, 32, 66, UNDER)       # legs
    R(d, 15, 66, 23, 69, UNDER_D); R(d, 25, 66, 33, 69, UNDER_D)   # socks
    R(d, 23, 24, 24, 42, UNDER_D)                                  # zip
    for p in [(18, 27), (29, 27), (20, 34)]:                       # biomedical sensor patches
        R(d, p[0], p[1], p[0] + 1, p[1] + 1, (240, 150, 60))
    head(d)
    return i


def layer_suit():
    i = new(48, 72); d = ImageDraw.Draw(i)
    R(d, 14, 21, 33, 45, SUIT); R(d, 14, 44, 33, 45, SUIT_D)       # torso
    R(d, 8, 22, 14, 41, SUIT); R(d, 33, 22, 39, 41, SUIT)          # arms
    R(d, 8, 31, 14, 32, SUIT_D); R(d, 33, 31, 39, 32, SUIT_D)      # elbow seams
    R(d, 8, 40, 14, 41, RING); R(d, 33, 40, 39, 41, RING)          # wrist rings
    R(d, 15, 46, 23, 66, SUIT); R(d, 25, 46, 33, 66, SUIT)         # legs
    R(d, 15, 55, 23, 56, SUIT_D); R(d, 25, 55, 33, 56, SUIT_D)     # knee seams
    R(d, 13, 64, 23, 70, (140, 150, 170)); R(d, 25, 64, 35, 70, (140, 150, 170))   # boots
    R(d, 13, 69, 23, 70, (96, 104, 124)); R(d, 25, 69, 35, 70, (96, 104, 124))
    R(d, 18, 20, 29, 22, RING)                                     # neck ring
    R(d, 9, 24, 13, 27, (200, 40, 50)); R(d, 9, 24, 10, 25, (40, 60, 160))         # flag patch
    R(d, 17, 28, 20, 31, (150, 156, 168)); R(d, 27, 28, 30, 31, (150, 156, 168))   # empty hose sockets
    R(d, 22, 36, 25, 39, (150, 156, 168))
    return i


def layer_gloves():
    i = new(48, 72); d = ImageDraw.Draw(i)
    for x in (7, 33):
        R(d, x, 40, x + 7, 41, (226, 190, 60))                     # locking ring
        R(d, x, 42, x + 7, 48, (128, 138, 160)); R(d, x, 47, x + 7, 48, (92, 100, 122))
        R(d, x + 3, 44, x + 4, 46, (160, 170, 190))
    return i


def layer_headset():
    i = new(48, 72); d = ImageDraw.Draw(i)
    d.pieslice([15, 2, 32, 18], 180, 360, fill=(246, 246, 242))    # cap
    R(d, 15, 9, 17, 15, HAIR); R(d, 30, 9, 32, 15, HAIR)           # ear cups
    R(d, 22, 2, 25, 9, HAIR)                                       # centre stripe
    d.line([(17, 15), (21, 17)], fill=DARK); d.line([(30, 15), (26, 17)], fill=DARK)   # mic booms
    R(d, 21, 17, 22, 18, DARK); R(d, 25, 17, 26, 18, DARK)
    return i


def layer_helmet():
    i = new(48, 72); d = ImageDraw.Draw(i)
    d.ellipse([11, 0, 36, 23], fill=(190, 220, 245, 70), outline=(130, 160, 190, 255))
    d.arc([14, 2, 30, 16], 190, 260, fill=(255, 255, 255, 230))
    d.arc([15, 3, 31, 17], 200, 240, fill=(255, 255, 255, 160))
    R(d, 16, 20, 31, 23, (226, 190, 60)); R(d, 16, 22, 31, 23, (170, 138, 40))    # locked neck ring
    return i


def layer_connections():
    i = new(48, 72); d = ImageDraw.Draw(i)
    for (x, col, ex) in ((17, BLUE, 3), (27, RED, 44)):
        pts = [(x + 2, 32), (x + 2, 38), (ex, 46), (ex, 60)]
        d.line(pts, fill=(96, 104, 124), width=3); d.line(pts, fill=(196, 202, 212), width=1)
        R(d, x, 28, x + 3, 31, col); R(d, x, 28, x + 3, 28, (255, 255, 255))
        R(d, ex - 1, 58, ex + 1, 62, col)
    R(d, 22, 36, 25, 39, (70, 220, 110))                            # comm / bio plug
    return i


def doctor():
    i = new(48, 72); d = ImageDraw.Draw(i)
    d.ellipse([12, 66, 35, 71], fill=(0, 0, 0, 60))
    COAT, COAT_D = (248, 248, 250), (198, 204, 214)
    R(d, 14, 22, 33, 52, COAT); R(d, 14, 51, 33, 52, COAT_D)       # coat
    R(d, 9, 23, 14, 42, COAT); R(d, 33, 23, 38, 42, COAT)          # arms
    R(d, 9, 43, 13, 46, SKIN); R(d, 34, 43, 38, 46, SKIN)
    R(d, 21, 22, 26, 30, (120, 170, 220)); R(d, 23, 24, 24, 34, (40, 60, 120))     # shirt + tie
    R(d, 23, 30, 24, 52, COAT_D)
    R(d, 16, 53, 23, 66, (60, 66, 84)); R(d, 25, 53, 32, 66, (60, 66, 84))         # trousers
    R(d, 14, 66, 23, 69, DARK); R(d, 25, 66, 34, 69, DARK)
    d.arc([17, 20, 30, 36], 0, 180, fill=(60, 66, 84), width=1)    # stethoscope
    R(d, 23, 36, 25, 38, (170, 176, 190))
    R(d, 31, 36, 41, 50, (150, 110, 60)); R(d, 32, 38, 40, 49, (250, 250, 244))    # clipboard
    for y in (41, 44, 47):
        R(d, 34, y, 38, y, (120, 124, 132))
    head(d, hair=(70, 70, 76))
    R(d, 19, 10, 22, 13, (0, 0, 0, 0)); R(d, 25, 10, 28, 13, (0, 0, 0, 0))
    d.rectangle([19, 10, 22, 13], outline=DARK, fill=(220, 236, 250))               # glasses
    d.rectangle([25, 10, 28, 13], outline=DARK, fill=(220, 236, 250)); R(d, 23, 11, 24, 11, DARK)
    return i


# ------------------------------------------------------------------ icons --
def icon_heart_monitor():
    i = new(24, 24); d = ImageDraw.Draw(i)
    R(d, 1, 3, 22, 18, (60, 66, 84)); R(d, 3, 5, 20, 16, (14, 30, 20))
    d.line([(3, 11), (7, 11), (9, 7), (11, 15), (13, 9), (15, 11), (20, 11)], fill=(70, 240, 120))
    R(d, 9, 19, 14, 20, (120, 130, 150)); R(d, 6, 21, 17, 22, (120, 130, 150))
    return i


def icon_bp_monitor():
    i = new(24, 24); d = ImageDraw.Draw(i)
    R(d, 1, 8, 12, 19, (70, 110, 190)); R(d, 1, 8, 12, 9, (120, 160, 230)); R(d, 3, 12, 10, 15, (50, 84, 150))
    d.ellipse([12, 1, 23, 12], fill=(240, 242, 246), outline=DARK); d.line([(17, 7), (20, 4)], fill=RED)
    d.line([(12, 16), (16, 18), (18, 14), (18, 12)], fill=DARK)
    d.ellipse([15, 17, 21, 23], fill=(60, 66, 84))
    return i


def icon_thermometer():
    i = new(24, 24); d = ImageDraw.Draw(i)
    d.line([(6, 18), (18, 6)], fill=(240, 242, 246), width=5)
    d.line([(8, 16), (14, 10)], fill=RED, width=1)
    d.ellipse([2, 15, 9, 22], fill=RED, outline=(150, 30, 30))
    for k in range(3):
        d.point((13 + k * 2, 13 - k * 2), fill=DARK)
    d.point((19, 5), fill=(170, 176, 190))
    return i


def icon_suit():
    i = new(24, 24); d = ImageDraw.Draw(i)
    R(d, 8, 3, 15, 13, SUIT); R(d, 4, 4, 7, 12, SUIT); R(d, 16, 4, 19, 12, SUIT)
    R(d, 8, 14, 11, 21, SUIT); R(d, 12, 14, 15, 21, SUIT); R(d, 11, 15, 12, 21, SUIT_D)
    R(d, 9, 2, 14, 3, RING); R(d, 7, 21, 11, 22, (140, 150, 170)); R(d, 12, 21, 16, 22, (140, 150, 170))
    R(d, 4, 5, 6, 6, (200, 40, 50)); R(d, 4, 11, 7, 12, RING); R(d, 16, 11, 19, 12, RING)
    return i


def icon_helmet():
    i = new(24, 24); d = ImageDraw.Draw(i)
    d.ellipse([3, 2, 20, 19], fill=(190, 220, 245, 150), outline=(130, 160, 190))
    d.arc([6, 4, 16, 14], 190, 260, fill=(255, 255, 255))
    R(d, 6, 18, 17, 21, (226, 190, 60)); R(d, 6, 20, 17, 21, (170, 138, 40))
    return i


def icon_gloves():
    i = new(24, 24); d = ImageDraw.Draw(i)
    for x in (2, 13):
        R(d, x + 1, 6, x + 7, 17, (128, 138, 160)); R(d, x, 9, x + 1, 13, (128, 138, 160))
        for k in range(4):
            R(d, x + 1 + k * 2, 3, x + 1 + k * 2, 6, (128, 138, 160))
        R(d, x + 1, 18, x + 7, 20, (226, 190, 60))
    return i


def icon_headset():
    i = new(24, 24); d = ImageDraw.Draw(i)
    d.pieslice([3, 3, 20, 21], 180, 360, fill=(246, 246, 242)); R(d, 10, 3, 13, 12, HAIR)
    R(d, 2, 11, 5, 18, HAIR); R(d, 18, 11, 21, 18, HAIR)
    d.line([(5, 18), (9, 21)], fill=DARK); d.line([(18, 18), (14, 21)], fill=DARK)
    R(d, 9, 21, 10, 22, DARK); R(d, 13, 21, 14, 22, DARK)
    return i


def icon_connections():
    i = new(24, 24); d = ImageDraw.Draw(i)
    for (x, col) in ((4, BLUE), (14, RED)):
        pts = [(x + 2, 8), (x + 2, 14), (x + 4, 18), (x + 1, 22)]
        d.line(pts, fill=(96, 104, 124), width=3); d.line(pts, fill=(196, 202, 212), width=1)
        R(d, x, 2, x + 5, 7, col); R(d, x, 2, x + 5, 2, (255, 255, 255)); R(d, x + 2, 4, x + 3, 5, DARK)
    return i


# ----------------------------------------------------------------- gauges --
SWEEP = 240.0     # needle travel in degrees, centred on 12 o'clock (must match gauge code in Godot)


def gauge_face(g):
    i = new(40, 40); d = ImageDraw.Draw(i)
    d.ellipse([0, 0, 39, 39], fill=(150, 156, 168), outline=(16, 16, 20))
    d.ellipse([2, 2, 37, 37], fill=(20, 22, 30))

    def ang(v):   # PIL angle (clockwise from 3 o'clock) for a value
        return -90 - SWEEP / 2 + SWEEP * (v - g["min"]) / (g["max"] - g["min"])

    d.arc([4, 4, 35, 35], ang(g["min"]), ang(g["max"]), fill=(200, 70, 60), width=3)
    d.arc([4, 4, 35, 35], ang(g["normal_min"]), ang(g["normal_max"]), fill=(70, 210, 110), width=3)
    for k in range(9):                                   # tick marks
        a = math.radians(-90 - SWEEP / 2 + SWEEP * k / 8)
        x, y = 19.5 + 12 * math.cos(a), 19.5 + 12 * math.sin(a)
        d.point((round(x), round(y)), fill=(236, 238, 242))
    R(d, 14, 29, 25, 33, (36, 40, 50))
    return i


# ----------------------------------------------------------------- launch --
def saturn_v():
    i = new(16, 96); d = ImageDraw.Draw(i)
    W_, K = (240, 240, 236), (28, 30, 38)
    R(d, 7, 0, 8, 8, (200, 204, 212)); R(d, 7, 2, 8, 3, (150, 156, 168))           # escape tower
    R(d, 7, 9, 8, 9, W_); R(d, 6, 10, 9, 12, (206, 210, 216))                      # command module
    R(d, 6, 13, 9, 18, W_); R(d, 6, 16, 9, 16, K)                                  # service module
    for k in range(5):                                                             # adapter (holds the lunar module)
        R(d, 6 - (k // 3), 19 + k, 9 + (k // 3), 19 + k, W_)
    R(d, 5, 24, 10, 38, W_); R(d, 5, 24, 10, 25, K); R(d, 5, 31, 7, 38, K)         # S-IVB third stage
    for k in range(4):
        R(d, 5 - (k // 2), 39 + k, 10 + (k // 2), 39 + k, K if k < 2 else W_)
    R(d, 4, 43, 11, 62, W_); R(d, 4, 43, 11, 44, K); R(d, 4, 60, 11, 62, K)        # S-II second stage
    R(d, 7, 47, 8, 57, (200, 40, 50))
    R(d, 4, 63, 11, 90, W_); R(d, 4, 63, 11, 66, K)                                # S-IC first stage
    R(d, 4, 74, 7, 82, K); R(d, 8, 67, 11, 73, K); R(d, 8, 83, 11, 88, K)
    R(d, 7, 76, 8, 86, (200, 40, 50))
    R(d, 2, 86, 3, 91, (120, 126, 140)); R(d, 12, 86, 13, 91, (120, 126, 140))     # fins
    for x in (4, 7, 10):
        R(d, x, 91, x + 1, 94, (60, 64, 76))                                       # engine bells
    return i


def launch_tower():
    i = new(24, 104); d = ImageDraw.Draw(i)
    RD, RD_D = (190, 64, 48), (128, 44, 34)
    R(d, 14, 0, 15, 8, (120, 126, 140))                                            # lightning mast
    R(d, 10, 8, 19, 103, RD_D); R(d, 11, 9, 18, 103, (40, 30, 34))
    R(d, 10, 8, 10, 103, RD); R(d, 19, 8, 19, 103, RD)
    for y in range(8, 104, 8):
        R(d, 10, y, 19, y, RD)
        d.line([(11, y + 1), (18, y + 7)], fill=RD_D)
    for y in (22, 40, 58, 78):                                                     # swing arms
        R(d, 0, y, 10, y + 1, RD); R(d, 0, y + 2, 10, y + 2, RD_D)
    R(d, 20, 96, 23, 103, RD_D)
    return i


def flame():
    i = new(16, 28); d = ImageDraw.Draw(i)
    d.polygon([(3, 0), (12, 0), (14, 12), (8, 27), (1, 12)], fill=(250, 150, 40))
    d.polygon([(5, 0), (10, 0), (11, 10), (8, 20), (4, 10)], fill=(255, 220, 90))
    d.polygon([(6, 0), (9, 0), (9, 7), (8, 12), (6, 7)], fill=(255, 250, 220))
    return i


if __name__ == "__main__":
    save(saturn_v(), "saturn_v.png")
    save(launch_tower(), "launch_tower.png")
    save(flame(), "flame.png")
    save(astronaut_base(), "astronaut_base.png")
    save(layer_suit(), "layer_suit.png")
    save(layer_gloves(), "layer_gloves.png")
    save(layer_headset(), "layer_headset.png")
    save(layer_helmet(), "layer_helmet.png")
    save(layer_connections(), "layer_connections.png")
    save(doctor(), "doctor.png")
    for fn in (icon_heart_monitor, icon_bp_monitor, icon_thermometer, icon_suit, icon_helmet, icon_gloves,
               icon_headset, icon_connections):
        save(fn(), fn.__name__ + ".png")
    with open(os.path.join(ROOT, "data", "minigames.json")) as f:
        cfg = json.load(f)
    for g in cfg["instrument_inspection"]["gauges"]:
        save(gauge_face(g), f"gauge_{g['id']}.png")
    # contact sheet for a quick look (not used by the game)
    names = sorted(n for n in os.listdir(OUT) if n.endswith(".png") and not n.startswith("_"))
    sheet = Image.new("RGBA", (len(names) * 52, 76), (40, 44, 56, 255))
    for k, n in enumerate(names):
        sheet.alpha_composite(Image.open(os.path.join(OUT, n)).convert("RGBA"), (k * 52 + 2, 2))
    full = Image.new("RGBA", (48, 72), (40, 44, 56, 255))
    for n in ("astronaut_base", "layer_suit", "layer_connections", "layer_gloves", "layer_headset", "layer_helmet"):
        full.alpha_composite(Image.open(os.path.join(OUT, n + ".png")))
    out = Image.new("RGBA", (sheet.width + 52, 76), (40, 44, 56, 255))
    out.alpha_composite(sheet); out.alpha_composite(full, (sheet.width + 2, 2))
    out.resize((out.width * 3, out.height * 3), Image.NEAREST).save("/tmp/minigame_art_preview.png")
    print("wrote", len(names), "images to", OUT)
