#!/usr/bin/env python3
"""Generates the Apollo 13 Level 1 placeholder art and level data.

Outputs (relative to project root):
  assets/tileset.png            32x32 tile atlas (8 columns)
  assets/player.png             4 frames: down, up, left, right
  assets/npc_pad_leader.png     1 frame
  assets/astronaut_seated.png   64x96 overlay for an occupied couch
  assets/marker.png             16x16 objective marker
  data/level1.json              tiles, zones, interactables, objectives, launch events
  data/level1_ground.txt        ground layer tile ids
  data/level1_objects.txt      object layer tile ids (-1 = empty)
  docs/level1_map.png           rendered map (1:1)
  docs/level1_map_labelled.png  labelled map (2x, with legend)

Edit BASE / placements / CONTENT below and re-run:  python3 tools/gen_level.py
"""
import json, os
from PIL import Image, ImageDraw, ImageFont

T = 32
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ----------------------------------------------------------------------------
# 1. GRID  (24 x 21 tiles)
# ----------------------------------------------------------------------------
BASE = [
    "        wwwwwwww        ",  # 0
    "        w,,,,,,w--------",  # 1  White Room
    "        w,,,,,,=========",  # 2  ... access arm leads east
    "        w,,,,,,w--------",  # 3
    "      #####HH#####      ",  # 4  hull + side hatch
    "      #..........#      ",  # 5  hatch / access area
    "     O............C     ",  # 6  O = open window, C = window under boost cover
    "    C..............C    ",  # 7  main display console row
    "   #................#   ",  # 8
    "  #..................#  ",  # 9
    "  #..................#  ",  # 10 couches 10-12
    "  #..................#  ",  # 11
    "  #..................#  ",  # 12
    "  #..................#  ",  # 13
    "  #..................#  ",  # 14
    "  #..................#  ",  # 15
    "   #................#   ",  # 16
    "    #..............#    ",  # 17
    "     #............#     ",  # 18
    "      #..........#      ",  # 19 lower equipment bay row
    "      ############      ",  # 20
]
W, H = len(BASE[0]), len(BASE)
assert all(len(r) == W for r in BASE), [len(r) for r in BASE]

# ----------------------------------------------------------------------------
# 2. PIXEL ART (procedural placeholders)
# ----------------------------------------------------------------------------
def new(w=T, h=T, c=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), c)

def R(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)

VOID = (13, 17, 28)
FLOOR = (106, 114, 124)
HULL = (66, 74, 90)

def t_void():
    i = new(c=VOID + (255,)); d = ImageDraw.Draw(i)
    for p in [(5, 7), (21, 13), (12, 26), (27, 29)]:
        d.point(p, fill=(26, 32, 48))
    return i

def t_floor():
    i = new(c=FLOOR + (255,)); d = ImageDraw.Draw(i)
    R(d, 0, 0, 31, 0, (124, 132, 142)); R(d, 0, 0, 0, 31, (124, 132, 142))
    R(d, 0, 31, 31, 31, (86, 94, 104)); R(d, 31, 0, 31, 31, (86, 94, 104))
    for p in [(3, 3), (28, 3), (3, 28), (28, 28)]:
        d.point(p, fill=(74, 82, 92))
    for x in range(8, 24, 4):
        d.point((x, 16), fill=(98, 106, 116))
    return i

def t_hull():
    i = new(c=HULL + (255,)); d = ImageDraw.Draw(i)
    R(d, 0, 0, 31, 2, (128, 138, 152)); R(d, 0, 0, 2, 31, (104, 114, 130))
    R(d, 0, 29, 31, 31, (38, 44, 56)); R(d, 29, 0, 31, 31, (46, 52, 66))
    for p in [(6, 6), (25, 6), (6, 25), (25, 25)]:
        R(d, p[0], p[1], p[0] + 1, p[1] + 1, (150, 160, 172))
    R(d, 10, 14, 21, 17, (56, 63, 78))
    return i

def t_window(covered):
    i = t_hull(); d = ImageDraw.Draw(i)
    R(d, 5, 5, 26, 26, (196, 202, 210))
    if covered:
        R(d, 7, 7, 24, 24, (172, 164, 146))
        for k in range(-18, 18, 5):
            d.line([(7, 16 + k), (24, 33 + k)], fill=(146, 138, 120))
        R(d, 5, 5, 26, 6, (196, 202, 210)); R(d, 5, 25, 26, 26, (196, 202, 210))
        R(d, 5, 5, 6, 26, (196, 202, 210)); R(d, 25, 5, 26, 26, (196, 202, 210))
    else:
        R(d, 7, 7, 24, 24, (112, 186, 236))
        R(d, 7, 19, 24, 24, (74, 150, 214))
        d.line([(9, 15), (15, 9)], fill=(236, 248, 255)); d.line([(11, 17), (19, 9)], fill=(206, 234, 252))
    return i

def t_hatch(closed):
    if closed:
        i = new(c=(128, 136, 148, 255)); d = ImageDraw.Draw(i)
        R(d, 0, 0, 31, 2, (176, 184, 194)); R(d, 0, 29, 31, 31, (78, 86, 98))
        R(d, 3, 5, 28, 26, (146, 154, 166))
        d.ellipse([10, 9, 21, 20], fill=(60, 68, 82)); d.ellipse([12, 11, 19, 18], fill=(112, 186, 236))
        R(d, 6, 22, 25, 24, (226, 190, 60))
    else:
        i = t_floor(); d = ImageDraw.Draw(i)
        for y0 in (0, 27):
            for x in range(0, 32, 8):
                R(d, x, y0, x + 3, y0 + 4, (226, 190, 60)); R(d, x + 4, y0, x + 7, y0 + 4, (36, 36, 40))
    return i

def t_wfloor():
    i = new(c=(214, 220, 226, 255)); d = ImageDraw.Draw(i)
    R(d, 0, 31, 31, 31, (186, 194, 204)); R(d, 31, 0, 31, 31, (186, 194, 204))
    R(d, 15, 0, 15, 31, (198, 206, 214)); R(d, 0, 15, 31, 15, (198, 206, 214))
    return i

def t_wwall():
    i = new(c=(236, 239, 243, 255)); d = ImageDraw.Draw(i)
    R(d, 0, 0, 31, 3, (255, 255, 255)); R(d, 0, 28, 31, 31, (156, 166, 178))
    R(d, 0, 0, 0, 31, (200, 208, 216)); R(d, 31, 0, 31, 31, (176, 186, 196))
    R(d, 6, 12, 25, 13, (206, 213, 221)); R(d, 6, 19, 25, 20, (206, 213, 221))
    return i

def t_arm():
    i = new(c=(170, 78, 54, 255)); d = ImageDraw.Draw(i)
    for k in range(0, 32, 8):
        R(d, k, 0, k, 31, (126, 54, 38)); R(d, 0, k, 31, k, (126, 54, 38))
    R(d, 0, 0, 31, 1, (206, 108, 78)); R(d, 0, 30, 31, 31, (106, 44, 32))
    return i

def t_rail():
    i = new(); d = ImageDraw.Draw(i)          # transparent: the sky shows through the railing
    R(d, 0, 13, 31, 16, (206, 96, 64)); R(d, 0, 17, 31, 18, (126, 54, 38))
    for x in (4, 20):
        R(d, x, 6, x + 2, 26, (170, 78, 54))
    for k in range(0, 32, 8):
        d.line([(k, 26), (k + 8, 6)], fill=(96, 44, 34))
    return i

PANEL = (36, 40, 50)

def panel_body(w, h, flip=False):
    i = new(w, h, PANEL + (255,)); d = ImageDraw.Draw(i)
    hi, lo = (104, 112, 126), (18, 20, 28)
    if flip:
        R(d, 0, h - 3, w - 1, h - 1, hi); R(d, 0, 0, w - 1, 1, lo)
    else:
        R(d, 0, 0, w - 1, 2, hi); R(d, 0, h - 2, w - 1, h - 1, lo)
    return i, d

def gauge(d, x, y, c=(232, 236, 240)):
    d.ellipse([x, y, x + 10, y + 10], fill=c, outline=(12, 12, 16))
    d.line([(x + 5, y + 5), (x + 8, y + 2)], fill=(200, 40, 40))

def switches(d, x0, y, n, step=5):
    for k in range(n):
        x = x0 + k * step
        R(d, x, y, x + 2, y + 4, (150, 156, 166)); R(d, x, y, x + 2, y + 1, (240, 242, 246))

def big_mdc():
    """Main display console, 10 tiles wide: Panel 1 | Panel 2 | Panel 3."""
    i, d = panel_body(320, 32)
    for x in (96, 224):
        R(d, x - 1, 3, x, 29, (84, 92, 106))
    # Panel 1: flight instruments (commander)
    for cx in (20, 50):
        d.ellipse([cx - 10, 6, cx + 10, 26], fill=(20, 22, 28), outline=(170, 176, 186))
        d.pieslice([cx - 8, 8, cx + 8, 24], 180, 360, fill=(200, 204, 210))
        d.pieslice([cx - 8, 8, cx + 8, 24], 0, 180, fill=(58, 62, 72))
        R(d, cx - 6, 15, cx + 6, 16, (240, 150, 40)); R(d, cx, 11, cx, 20, (240, 150, 40))
    for p in [(70, 8), (80, 8), (75, 13), (70, 18), (80, 18)]:   # 5 launch vehicle engine lights
        R(d, p[0], p[1], p[0] + 3, p[1] + 3, (250, 210, 70))
    R(d, 68, 24, 86, 27, (60, 200, 110))
    switches(d, 6, 27, 4); R(d, 88, 6, 92, 26, (200, 50, 50))    # abort light strip
    # Panel 2: caution & warning matrix, DSKY, main switches
    for r in range(3):
        for c in range(8):
            col = [(70, 74, 84), (70, 74, 84), (240, 180, 60), (70, 74, 84)][(r * 3 + c) % 4]
            R(d, 102 + c * 6, 6 + r * 5, 106 + c * 6, 9 + r * 5, col)
    R(d, 156, 6, 186, 20, (14, 30, 20));
    for r in range(3):
        for c in range(5):
            R(d, 159 + c * 5, 8 + r * 4, 161 + c * 5, 10 + r * 4, (70, 240, 120))
    for r in range(2):
        for c in range(5):
            R(d, 192 + c * 6, 7 + r * 7, 196 + c * 6, 11 + r * 7, (190, 194, 202))
    switches(d, 102, 23, 10); switches(d, 158, 23, 12)
    # Panel 3: electrical power
    for k in range(4):
        gauge(d, 230 + k * 14, 6)
    for k in range(3):                                           # fuel cell talkbacks
        R(d, 292 + k * 8, 7, 297 + k * 8, 12, (70, 220, 110))
    R(d, 290, 15, 314, 20, (14, 30, 20)); R(d, 292, 17, 304, 18, (70, 240, 120))
    switches(d, 230, 22, 16)
    return i

def locker(d, x0, x1, y0=4, y1=27):
    R(d, x0, y0, x1, y1, (176, 170, 150)); R(d, x0, y0, x1, y0 + 1, (214, 208, 188))
    R(d, x0, y1 - 1, x1, y1, (120, 114, 98))
    mid = (x0 + x1) // 2
    R(d, mid, y0 + 2, mid, y1 - 2, (128, 122, 104))
    for x in (mid - 5, mid + 3):
        R(d, x, (y0 + y1) // 2 - 1, x + 2, (y0 + y1) // 2 + 1, (70, 70, 74))

def big_leb():
    """Lower equipment bay, 10 tiles wide: stowage | DSKY+AGC | optics | stowage | comm | stowage."""
    i, d = panel_body(320, 32, flip=True)
    locker(d, 3, 30); locker(d, 34, 60)
    # guidance computer + DSKY (cols 2-3 of this strip)
    R(d, 68, 5, 92, 18, (14, 30, 20))
    for r in range(3):
        for c in range(6):
            R(d, 70 + c * 4, 7 + r * 4, 71 + c * 4, 9 + r * 4, (70, 240, 120))
    for r in range(2):
        for c in range(5):
            R(d, 68 + c * 5, 20 + r * 4, 71 + c * 5, 22 + r * 4, (196, 200, 208))
    R(d, 98, 5, 124, 26, (58, 62, 74)); R(d, 100, 7, 122, 11, (240, 180, 60))
    for k in range(5):
        R(d, 100 + k * 5, 15, 102 + k * 5, 17, (70, 220, 110) if k % 2 else (240, 242, 246))
    switches(d, 100, 21, 5)
    # optics: sextant + scanning telescope eyepieces
    for cx in (144, 174):
        d.ellipse([cx - 11, 5, cx + 11, 27], fill=(150, 156, 168), outline=(16, 16, 20))
        d.ellipse([cx - 7, 9, cx + 7, 23], fill=(12, 14, 22))
        d.ellipse([cx - 3, 11, cx + 1, 15], fill=(90, 130, 200))
    R(d, 157, 12, 161, 20, (226, 190, 60))
    locker(d, 194, 221)
    # communication console
    R(d, 228, 5, 252, 26, (58, 62, 74))
    for y in range(8, 24, 3):
        R(d, 231, y, 249, y, (20, 22, 28))
    d.ellipse([258, 6, 270, 18], fill=(196, 200, 208), outline=(16, 16, 20)); d.line([(264, 12), (268, 8)], fill=(200, 40, 40))
    R(d, 274, 7, 277, 10, (70, 220, 110)); R(d, 280, 7, 283, 10, (240, 180, 60))
    switches(d, 258, 22, 6)
    d.arc([272, 12, 286, 26], 200, 520, fill=(230, 230, 236))   # headset cable
    R(d, 276, 16, 281, 21, (30, 30, 36))
    locker(d, 290, 316)
    return i

def big_lheb():
    """Left-hand equipment bay, 5 tiles tall: oxygen panel (2) + environmental control unit (3)."""
    i = new(32, 160, PANEL + (255,)); d = ImageDraw.Draw(i)
    R(d, 29, 0, 31, 159, (104, 112, 126)); R(d, 0, 0, 1, 159, (18, 20, 28))
    # oxygen panel
    for k, y in enumerate((6, 34)):
        R(d, 5, y, 25, y + 22, (58, 62, 74))
        R(d, 8, y + 3, 12, y + 19, (14, 20, 30)); R(d, 8, y + 8, 12, y + 19, (80, 170, 240))
        R(d, 16, y + 3, 20, y + 19, (14, 20, 30)); R(d, 16, y + 6 + 3 * k, 20, y + 19, (80, 170, 240))
        R(d, 22, y + 3, 24, y + 5, (70, 220, 110))
    # environmental control unit: LiOH canisters, pipes, suit hoses
    for y in (70, 96):
        R(d, 5, y, 25, y + 20, (182, 186, 176)); R(d, 5, y, 25, y + 1, (224, 228, 218))
        d.ellipse([9, y + 4, 21, y + 16], fill=(120, 124, 116), outline=(60, 62, 58))
    R(d, 14, 90, 16, 96, (80, 170, 240)); R(d, 14, 116, 16, 124, (80, 170, 240))
    for cy in (134, 148):
        d.ellipse([7, cy - 7, 23, cy + 7], outline=(210, 214, 222), width=2)
        d.ellipse([12, cy - 2, 18, cy + 4], fill=(70, 120, 220) if cy < 140 else (220, 70, 70))
    return i

def big_rheb():
    """Right-hand equipment bay, 5 tiles tall: circuit breakers (3) + emergency equipment (2)."""
    i = new(32, 160, PANEL + (255,)); d = ImageDraw.Draw(i)
    R(d, 0, 0, 2, 159, (104, 112, 126)); R(d, 30, 0, 31, 159, (18, 20, 28))
    R(d, 6, 5, 27, 90, (120, 126, 136))
    for r in range(14):
        for c in range(4):
            x, y = 8 + c * 5, 8 + r * 6
            R(d, x, y, x + 2, y + 2, (236, 238, 242)); d.point((x + 1, y + 1), fill=(16, 16, 20))
    R(d, 6, 100, 27, 154, (200, 48, 44)); R(d, 6, 100, 27, 101, (240, 96, 88))
    R(d, 15, 106, 18, 120, (250, 250, 250)); R(d, 10, 111, 23, 114, (250, 250, 250))
    R(d, 12, 128, 21, 150, (228, 60, 52)); R(d, 14, 124, 19, 128, (40, 40, 46)); R(d, 13, 134, 20, 138, (250, 230, 120))
    return i

def big_couch():
    i = new(64, 96); d = ImageDraw.Draw(i)
    R(d, 6, 2, 57, 93, (70, 64, 58))                       # frame
    R(d, 9, 5, 54, 90, (176, 168, 150))
    R(d, 18, 6, 45, 24, (150, 142, 124)); R(d, 20, 8, 43, 22, (196, 188, 170))   # headrest
    R(d, 12, 28, 51, 58, (190, 182, 164)); R(d, 12, 57, 51, 58, (140, 132, 116))  # back pan
    R(d, 12, 61, 51, 76, (182, 174, 156))                                         # seat pan
    R(d, 16, 79, 47, 89, (166, 158, 140))                                         # foot pan
    for x in (9, 51):
        R(d, x, 40, x + 3, 70, (110, 104, 94))                                    # armrests
    R(d, 4, 46, 8, 52, (30, 30, 34)); R(d, 55, 46, 59, 52, (30, 30, 34))          # hand controllers
    for x in (24, 38):
        R(d, x, 28, x + 1, 76, (84, 88, 100))                                     # harness
    return i

SUIT, SUIT_D = (238, 238, 234), (170, 172, 176)
SKIN = (232, 190, 150)

def seated_astronaut():
    i = new(64, 96); d = ImageDraw.Draw(i)
    R(d, 22, 28, 41, 60, SUIT); R(d, 22, 59, 41, 60, SUIT_D)
    R(d, 14, 30, 21, 52, SUIT); R(d, 42, 30, 49, 52, SUIT)             # arms
    R(d, 13, 50, 20, 55, (120, 126, 140)); R(d, 43, 50, 50, 55, (120, 126, 140))   # gloves
    R(d, 23, 61, 30, 84, SUIT); R(d, 33, 61, 40, 84, SUIT)             # legs
    R(d, 22, 83, 31, 90, (140, 150, 170)); R(d, 32, 83, 41, 90, (140, 150, 170))   # boots
    R(d, 25, 36, 28, 39, (60, 110, 220)); R(d, 35, 36, 38, 39, (220, 60, 60))      # hose connectors
    R(d, 15, 31, 19, 34, (200, 40, 50)); R(d, 15, 31, 16, 32, (40, 60, 160))       # flag patch
    d.ellipse([20, 3, 43, 26], fill=(214, 232, 246), outline=(120, 140, 160))      # bubble helmet
    d.ellipse([25, 8, 38, 21], fill=SKIN)
    R(d, 25, 8, 38, 11, (250, 250, 250)); R(d, 28, 14, 29, 15, (40, 30, 30)); R(d, 34, 14, 35, 15, (40, 30, 30))
    return i

def walker(facing):
    i = new(); d = ImageDraw.Draw(i)
    d.ellipse([9, 26, 22, 30], fill=(0, 0, 0, 70))
    R(d, 10, 16, 21, 26, SUIT); R(d, 10, 25, 21, 26, SUIT_D)
    R(d, 11, 27, 14, 30, (140, 150, 170)); R(d, 17, 27, 20, 30, (140, 150, 170))
    d.ellipse([8, 1, 23, 16], fill=(214, 232, 246), outline=(120, 140, 160))
    if facing == "down":
        d.ellipse([11, 4, 20, 13], fill=SKIN); R(d, 11, 4, 20, 6, (250, 250, 250))
        d.point((13, 9), fill=(40, 30, 30)); d.point((18, 9), fill=(40, 30, 30))
        R(d, 7, 17, 9, 24, SUIT); R(d, 22, 17, 24, 24, SUIT)
        R(d, 12, 19, 14, 21, (60, 110, 220)); R(d, 17, 19, 19, 21, (220, 60, 60))
    elif facing == "up":
        d.ellipse([11, 4, 20, 13], fill=(250, 250, 250)); R(d, 11, 9, 20, 13, (96, 72, 52))
        R(d, 7, 17, 9, 24, SUIT); R(d, 22, 17, 24, 24, SUIT)
        R(d, 12, 17, 19, 22, (206, 208, 206))
    else:
        s = -1 if facing == "left" else 1
        cx = 15 + s * 2
        d.ellipse([cx - 4, 4, cx + 5, 13], fill=SKIN)
        R(d, cx - 4 if s > 0 else cx + 1, 4, cx if s > 0 else cx + 5, 13, (250, 250, 250))
        d.point((cx + 3 * s + (0 if s < 0 else 0), 9), fill=(40, 30, 30))
        R(d, 14, 17, 17, 24, SUIT_D)
        R(d, 15 + s * 6 - 1, 19, 15 + s * 6 + 1, 21, (200, 40, 50))
    return i

def pad_leader():
    i = new(); d = ImageDraw.Draw(i)
    d.ellipse([9, 26, 22, 30], fill=(0, 0, 0, 70))
    R(d, 10, 15, 21, 27, (246, 246, 246)); R(d, 10, 26, 21, 27, (190, 192, 196))
    R(d, 7, 16, 9, 24, (246, 246, 246)); R(d, 22, 16, 24, 24, (246, 246, 246))
    R(d, 11, 28, 14, 30, (40, 40, 46)); R(d, 17, 28, 20, 30, (40, 40, 46))
    d.ellipse([10, 3, 21, 14], fill=SKIN)
    R(d, 10, 2, 21, 6, (252, 252, 252)); R(d, 9, 6, 22, 6, (150, 154, 160))        # cap
    R(d, 11, 8, 14, 10, (30, 30, 34)); R(d, 17, 8, 20, 10, (30, 30, 34)); R(d, 15, 9, 16, 9, (30, 30, 34))  # glasses
    R(d, 14, 15, 17, 16, (20, 20, 24))                                              # bow tie
    R(d, 18, 19, 20, 21, (200, 40, 50))
    return i

def t_checklist():
    i = new(); d = ImageDraw.Draw(i)
    R(d, 14, 22, 17, 30, (90, 96, 108)); R(d, 10, 29, 21, 31, (60, 66, 78))
    R(d, 7, 3, 24, 24, (120, 86, 48)); R(d, 8, 4, 23, 23, (204, 170, 110))
    R(d, 10, 6, 21, 21, (250, 250, 244))
    for y in range(9, 21, 3):
        R(d, 14, y, 20, y, (120, 124, 132)); R(d, 11, y - 1, 12, y, (60, 180, 100))
    R(d, 12, 2, 19, 5, (150, 156, 166))
    return i

def t_gate():
    i = new(); d = ImageDraw.Draw(i)
    R(d, 13, 2, 18, 29, (36, 36, 40))
    for y in range(2, 30, 8):
        R(d, 13, y, 18, y + 3, (236, 196, 56))
    R(d, 11, 0, 20, 2, (160, 164, 172)); R(d, 11, 29, 20, 31, (160, 164, 172))
    return i

def marker():
    i = new(16, 16); d = ImageDraw.Draw(i)
    d.polygon([(2, 3), (13, 3), (8, 13)], fill=(250, 214, 60), outline=(60, 44, 10))
    return i

# ----------------------------------------------------------------------------
# 3. ATLAS
# ----------------------------------------------------------------------------
tiles, names, solid = [], {}, set()

def add(name, img, is_solid):
    names[name] = len(tiles); tiles.append(img)
    if is_solid:
        solid.add(names[name])
    return names[name]

def add_sliced(prefix, img, is_solid=True):
    ids = []
    for ty in range(img.height // T):
        row = []
        for tx in range(img.width // T):
            row.append(add(f"{prefix}_{tx}_{ty}", img.crop((tx * T, ty * T, tx * T + T, ty * T + T)), is_solid))
        ids.append(row)
    return ids

add("void", t_void(), True)
add("floor", t_floor(), False)
add("hull", t_hull(), True)
add("window_open", t_window(False), True)
add("window_covered", t_window(True), True)
add("hatch_open", t_hatch(False), False)
add("hatch_closed", t_hatch(True), True)
add("whiteroom_floor", t_wfloor(), False)
add("whiteroom_wall", t_wwall(), True)
add("arm_walkway", t_arm(), False)
add("arm_rail", t_rail(), True)
add("checklist", t_checklist(), True)
add("gate", t_gate(), True)
MDC = add_sliced("mdc", big_mdc())
LEB = add_sliced("leb", big_leb())
LHEB = add_sliced("lheb", big_lheb())
RHEB = add_sliced("rheb", big_rheb())
COUCH = add_sliced("couch", big_couch())

COLS = 8
rows = (len(tiles) + COLS - 1) // COLS
atlas = new(COLS * T, rows * T)
for k, im in enumerate(tiles):
    atlas.paste(im, ((k % COLS) * T, (k // COLS) * T))

# ----------------------------------------------------------------------------
# 4. LAYERS
# ----------------------------------------------------------------------------
CH = {" ": "void", ".": "floor", "#": "hull", "O": "window_open", "C": "window_covered", "H": "hatch_open",
      ",": "whiteroom_floor", "w": "whiteroom_wall", "=": "arm_walkway", "-": "arm_rail"}
ground = [[names[CH[c]] for c in row] for row in BASE]
objects = [[-1] * W for _ in range(H)]

def place(ids, x, y):
    for dy, row in enumerate(ids):
        for dx, tid in enumerate(row):
            assert ground[y + dy][x + dx] == names["floor"], (x + dx, y + dy)
            objects[y + dy][x + dx] = tid

place(MDC, 7, 7)
place(LEB, 7, 19)
place(LHEB, 3, 10)
place(RHEB, 20, 10)
for cx in (6, 11, 16):
    place(COUCH, cx, 10)
objects[11][13] = names["checklist"]
objects[2][17] = names["gate"]

NPCS = [
    {"id": "pad_leader", "sprite": "npc_pad_leader.png", "tile": [13, 2]},
    {"id": "lovell", "sprite": "astronaut_seated.png", "tile": [6, 10], "size": [2, 3]},
    {"id": "haise", "sprite": "astronaut_seated.png", "tile": [16, 10], "size": [2, 3]},
]
PLAYER_START = [11, 2]

def is_solid(x, y):
    if not (0 <= x < W and 0 <= y < H):
        return True
    if objects[y][x] != -1 and objects[y][x] in solid:
        return True
    if [x, y] == NPCS[0]["tile"]:
        return True
    return ground[y][x] in solid

# ----------------------------------------------------------------------------
# 5. CONTENT
# ----------------------------------------------------------------------------
def span(x0, y0, x1, y1):
    return [[x, y] for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]

ZONES = [
    {"id": "white_room", "name": "White Room - Launch Tower, 320 ft level", "rect": [9, 1, 14, 3]},
    {"id": "hatch_area", "name": "Hatch and Access Area", "rect": [6, 5, 17, 6]},
    {"id": "mdc", "name": "Main Display Console", "rect": [7, 8, 16, 8]},
    {"id": "couches", "name": "Crew Couches", "rect": [5, 9, 18, 14]},
    {"id": "lheb", "name": "Left-Hand Equipment Bay - Life Support", "rect": [3, 9, 4, 15]},
    {"id": "rheb", "name": "Right-Hand Equipment Bay - Breakers and Safety", "rect": [19, 9, 20, 15]},
    {"id": "leb", "name": "Lower Equipment Bay - Navigation and Communications", "rect": [5, 16, 18, 18]},
]

INTERACTABLES = [
    {"id": "pad_leader", "n": 1, "name": "Pad Leader (Guenter Wendt)", "tiles": [[13, 2]], "required": False,
     "appearance": "Technician in white coveralls and cap, glasses, bow tie.",
     "steps": {"default": {"title": "Guenter Wendt - Pad Leader", "pages": [
         "Welcome to the White Room. We are 320 feet up the launch tower, at the end of the access arm. Below your boots is a 363-foot Saturn V rocket.",
         "Commander Lovell and Fred Haise are already strapped in. Your couch is the centre one, right under the hatch.",
         "Go on through the hatch. Once you are aboard, my closeout crew seals it and the arm swings away."]}}},
    {"id": "hatch", "n": 2, "name": "Side hatch", "tiles": [[11, 4], [12, 4]], "required": False,
     "appearance": "Two-tile opening with hazard stripes; a heavy grey door with a round window once closed.",
     "steps": {"default": {"title": "Side Hatch (sealed)", "pages": [
         "The closeout crew has sealed the hatch. This is the only way in or out on the pad.",
         "After the Apollo 1 fire in 1967 the hatch was redesigned as a single unit that opens outward in a few seconds.",
         "The tunnel at the top of the capsule is a different door. It will lead to the Lunar Module, but only after docking in space."]}}},
    {"id": "window_left", "n": 3, "name": "Window (commander's forward window)", "tiles": [[5, 6]], "required": False,
     "appearance": "Bright blue pane in a metal frame in the north-west hull.",
     "steps": {"default": {"title": "Window", "pages": [
         "Through the glass: the red steel of the launch tower, the access arm, and beyond it the Florida coast and the Atlantic.",
         "A boost protective cover wraps the capsule for launch. It leaves only this window and the hatch window clear."]},
         "orbit": {"title": "Window - Earth orbit", "pages": [
         "The curve of the Earth fills the window: blue ocean, white cloud, a thin bright line of atmosphere.",
         "Odyssey is circling the Earth about 185 km up, at nearly 28,000 km/h. One lap takes about 88 minutes."]}}},
    {"id": "window_right", "n": 4, "name": "Covered windows", "tiles": [[18, 6], [4, 7], [19, 7]], "required": False,
     "appearance": "Beige hatched panes: the boost protective cover blocks the view.",
     "steps": {"default": {"title": "Window (covered)", "pages": [
         "Nothing to see. The boost protective cover shields this window from the airstream during launch.",
         "The cover is attached to the launch escape tower. Both are thrown clear about 3 minutes 20 seconds into the flight."]},
         "orbit": {"title": "Window - Earth orbit", "pages": [
         "The cover is gone. Sunlight and the blue of the Pacific pour in."]}}},
    {"id": "flight_panel", "n": 5, "name": "Flight control panel (Panel 1)", "tiles": span(7, 7, 9, 7), "required": True,
     "appearance": "Left third of the console: two attitude balls, five engine lights, red abort light.",
     "steps": {"default": {"title": "Flight Control Panel", "pages": [
         "This is the commander's side of the main display console. The two round 'eight-ball' indicators show which way the spacecraft is pointing.",
         "The five lights in the middle stand for the five engines of the rocket stage that is burning. A light that comes ON means that engine is not making thrust.",
         "During launch the crew does not steer. The Saturn V's own computer, in the Instrument Unit ring near the top of the rocket, flies it. The crew watches these instruments and is ready to abort.",
         "FLIGHT DATA\nVehicle: Saturn V  SA-508\nSpacecraft: CSM-109 'Odyssey' + LM-7 'Aquarius'\nPad: Launch Complex 39A, Kennedy Space Center\nLiftoff: 11 April 1970, 2:13 p.m. local (19:13 UTC)\nDestination: Fra Mauro highlands, the Moon"]}}},
    {"id": "main_switches", "n": 6, "name": "Main switches + caution and warning (Panel 2)", "tiles": span(10, 7, 13, 7), "required": True,
     "appearance": "Centre of the console: amber warning matrix, green computer display, rows of toggle switches.",
     "steps": {"default": {"title": "Main Switches", "pages": [
         "The centre of the console holds the caution and warning lights, a computer keyboard, and hundreds of switches. Each has a metal guard so a floating elbow cannot flip it.",
         "The pre-launch checklist will tell you when to set these."]},
         "prelaunch": {"title": "Main Switches - Launch Configuration", "pages": [
         "Checklist step: set the Emergency Detection System (EDS) for launch.",
         "The EDS watches the rocket. Early in the flight a break-up could happen faster than a human can react."],
         "choice": {"prompt": "Set EDS automatic abort to:", "options": [
             {"label": "AUTO", "ok": True, "reply": "EDS to AUTO. If two first-stage engines fail or the rocket tumbles, the escape tower will pull the Command Module clear by itself. Master alarm test: lights and tone OK."},
             {"label": "OFF", "ok": False, "reply": "Lovell: 'Not yet, Jack. We want automatic abort armed for the first two minutes. Set it to AUTO.'"}]}}}},
    {"id": "electrical_panel", "n": 7, "name": "Electrical monitoring panel (Panel 3)", "tiles": span(14, 7, 16, 7), "required": True,
     "appearance": "Right third of the console: four round meters, three green fuel-cell indicators.",
     "steps": {"default": {"title": "Electrical Power", "pages": [
         "Odyssey makes its own electricity. Three fuel cells in the Service Module combine hydrogen and oxygen. The by-product is the crew's drinking water.",
         "The Command Module itself carries only three small batteries. They are saved for re-entry, after the Service Module has been thrown away.",
         "ELECTRICAL STATUS\nFuel cell 1: ON LINE\nFuel cell 2: ON LINE\nFuel cell 3: ON LINE\nMain bus A: 28 V DC   Main bus B: 28 V DC\nEntry batteries A, B, C: CHARGED\nAll indications normal."]},
         "systems": {"title": "Electrical Power - Instrument Inspection", "minigame": "instrument_inspection", "pages": [
         "Odyssey makes its own electricity. Three fuel cells in the Service Module combine hydrogen and oxygen. The by-product is the crew's drinking water.",
         "The Command Module itself carries only three small batteries. They are saved for re-entry, after the Service Module has been thrown away.",
         "Lovell: 'Time for a panel drill, Jack. Five gauges. Tell me which ones are out of limits, then call it in to Mission Control.'\n(Practice values, not real mission data.)"]}}},
    {"id": "lovell", "n": 8, "name": "Left couch - Jim Lovell (Commander)", "tiles": span(6, 10, 7, 12), "required": False,
     "appearance": "Beige couch with a suited astronaut strapped in.",
     "steps": {"default": {"title": "Jim Lovell - Commander", "pages": [
         "Welcome aboard, Jack. Short notice, I know. You have trained for this seat as backup, and you know Odyssey as well as anyone.",
         "This is my fourth trip: Gemini 7, Gemini 12, Apollo 8, and now this one. On Apollo 8 we only circled the Moon. This time Fred and I plan to walk on it.",
         "Find the checklist by your couch and work through it. When everything is green, strap in."]}}},
    {"id": "couch_cmp", "n": 9, "name": "Centre couch (player's seat)", "tiles": span(11, 10, 12, 12), "required": True,
     "appearance": "Empty beige couch with harness straps.",
     "steps": {"default": {"title": "Centre Couch", "pages": [
         "Your couch. The Command Module Pilot rides in the middle for launch.",
         "The couches hang on shock-absorbing struts, and the crew lies on their backs so the push of the rocket presses them into the seat instead of pulling blood from the head.",
         "Finish the pre-launch checklist before you strap in."]},
         "prelaunch": {"title": "Centre Couch", "minigame": "launch_sequence", "pages": [
         "Checklist complete. You climb into the couch and pull the harness tight.",
         "Lovell: 'Launch Control, Apollo 13. All three of us are strapped in and ready.'"]}}},
    {"id": "haise", "n": 10, "name": "Right couch - Fred Haise (Lunar Module Pilot)", "tiles": span(16, 10, 17, 12), "required": False,
     "appearance": "Beige couch with a suited astronaut strapped in.",
     "steps": {"default": {"title": "Fred Haise - Lunar Module Pilot", "pages": [
         "First spaceflight for me, same as you. My spacecraft is not this one. I fly the Lunar Module, Aquarius.",
         "You cannot reach Aquarius from here. It is folded up below us, inside a metal adapter between the Service Module and the rocket's third stage.",
         "So there are three machines stacked on this pad: the Saturn V rocket that lifts us, the Command and Service Module we live in, and the Lunar Module that lands. Once we are on the way to the Moon you will turn Odyssey around, dock with Aquarius and pull it out."]}}},
    {"id": "checklist", "n": 11, "name": "Mission checklist", "tiles": [[13, 11]], "required": True,
     "appearance": "Clipboard with a paper checklist on a short stand beside the centre couch.",
     "steps": {"default": {"title": "Pre-Launch Checklist", "pages": [
         "Apollo crews flew by checklist. Every switch position for every phase of the mission was written down and read aloud.",
         "{CHECKLIST}"]},
         "prelaunch": {"title": "Pre-Launch Checklist - Sign-off", "pages": [
         "{CHECKLIST}",
         "Every system has been inspected and Mission Control has given its GO. You sign off the checklist. One step left: strap into the centre couch."]}}},
    {"id": "o2_panel", "n": 12, "name": "Oxygen monitoring panel", "tiles": span(3, 10, 3, 11), "required": True,
     "appearance": "Two panels on the west wall with blue vertical bar gauges and green status lights.",
     "steps": {"default": {"title": "Oxygen and Cabin Conditions", "pages": [
         "The oxygen you breathe is stored as a super-cold liquid in two tanks in the Service Module. The same tanks feed the fuel cells.",
         "On the pad the cabin holds a mix of 60% oxygen and 40% nitrogen, a fire-safety rule introduced after Apollo 1. Your suit is fed pure oxygen.",
         "In space the cabin becomes pure oxygen at about one third of sea-level pressure. That keeps the hull light and still gives your lungs all the oxygen they need.",
         "CABIN STATUS\nOxygen tank 1: FULL   Oxygen tank 2: FULL\nSuit oxygen flow: NORMAL\nCabin pressure: slightly above outside air\nCarbon dioxide: LOW\nCabin temperature: 21 C\nAll indications normal."]}}},
    {"id": "ecs_unit", "n": 13, "name": "Environmental control unit", "tiles": span(3, 12, 3, 14), "required": False,
     "appearance": "Grey canister housings, blue pipes and two coiled suit hoses (blue and red connectors).",
     "steps": {"default": {"title": "Environmental Control Unit", "pages": [
         "This machine keeps three people alive in a sealed can. Fans pull cabin and suit air through canisters of lithium hydroxide, a chemical that absorbs the carbon dioxide you breathe out.",
         "It also removes moisture and controls temperature. The blue and red hoses carry oxygen to and from your suit."]}}},
    {"id": "breakers", "n": 14, "name": "Circuit breaker panel", "tiles": span(20, 10, 20, 12), "required": False,
     "appearance": "Grey panel on the east wall covered in rows of small white push-pull breakers.",
     "steps": {"default": {"title": "Circuit Breakers", "pages": [
         "Every circuit in the spacecraft runs through a breaker. If a wire shorts, the breaker pops out and cuts the power before anything overheats.",
         "A switch on the main console does nothing unless its breaker is pushed in. Checking breakers is part of every checklist."]}}},
    {"id": "emergency", "n": 15, "name": "Emergency equipment", "tiles": span(20, 13, 20, 14), "required": False,
     "appearance": "Red locker with a white cross and a red fire extinguisher.",
     "steps": {"default": {"title": "Emergency Equipment", "pages": [
         "Inside: a fire extinguisher, oxygen masks, a medical kit, and survival kits with a life raft and radio for after splashdown.",
         "The biggest safety system is outside the cabin. The launch escape tower on the capsule's nose is a solid rocket that can drag the Command Module away from a failing Saturn V in seconds.",
         "The commander can trigger it by twisting a handle by his left hand. The tower is thrown away once the rocket is high enough that it is no longer needed."]}}},
    {"id": "stowage", "n": 16, "name": "Stowage lockers", "tiles": [[7, 19], [8, 19], [13, 19], [16, 19]], "required": False,
     "appearance": "Beige locker doors with small latches.",
     "steps": {"default": {"title": "Stowage Lockers", "pages": [
         "Food for the trip: freeze-dried meals in plastic bags. You add water from a hand-held water gun and knead the bag.",
         "The water comes from the fuel cells, so making electricity also makes dinner possible."]}}},
    {"id": "guidance_computer", "n": 17, "name": "Guidance computer (AGC + DSKY)", "tiles": span(9, 19, 10, 19), "required": False,
     "appearance": "Green numeric display over a small keypad, beside a box with status lights.",
     "steps": {"default": {"title": "Apollo Guidance Computer", "pages": [
         "The Apollo Guidance Computer weighs about 32 kg and has less memory than a pocket calculator, yet it can navigate to the Moon.",
         "You talk to it through this display and keyboard, the DSKY, by typing two-digit VERB and NOUN codes. There is a second DSKY on the main console.",
         "NAVIGATION\nProgram: 02 (pre-launch: holding the gyro platform steady as the Earth turns)\nAt liftoff: switches to Program 11 (monitor the climb)\nLaunch direction: 72 degrees east of north, out over the Atlantic\nTarget: parking orbit about 185 km high\nThen: engine burn toward the Moon about 2.5 hours after liftoff"]}}},
    {"id": "optics", "n": 18, "name": "Sextant and telescope", "tiles": span(11, 19, 12, 19), "required": False,
     "appearance": "Two round eyepieces with silver rims.",
     "steps": {"default": {"title": "Navigation Optics", "pages": [
         "A sextant and a telescope look out through the hull. The Command Module Pilot sights on known stars, and the computer uses the angles to work out which way the spacecraft is pointing.",
         "It is the same idea sailors used for centuries, and it is your job on this flight."]}}},
    {"id": "comm_console", "n": 19, "name": "Communication console", "tiles": span(14, 19, 15, 19), "required": True,
     "appearance": "Speaker grille, tuning dial, green and amber lights, a headset on a coiled cable.",
     "steps": {"default": {"title": "Communications", "pages": [
         "Voice, spacecraft data and television all travel on one radio system called Unified S-band. Giant dish antennas around the world keep the link as the Earth turns.",
         "Before liftoff you talk to Launch Control at Kennedy Space Center in Florida. The moment the rocket clears the tower, Mission Control in Houston, Texas takes over.",
         "In Houston only one person speaks to the crew: the CAPCOM, who is always a fellow astronaut."]},
         "comm_check": {"title": "Communications - Radio Check", "pages": [
         "Voice, spacecraft data and television all travel on one radio system called Unified S-band.",
         "Before liftoff you talk to Launch Control in Florida. Once the rocket clears the tower, Mission Control in Houston takes over, and only the CAPCOM, a fellow astronaut, speaks to the crew."],
         "choice": {"prompt": "Put on the headset and:", "options": [
             {"label": "Call for a radio check", "ok": True, "reply": "You: 'Launch Control, Apollo 13, radio check.'\nLaunch Control: 'Thirteen, we read you loud and clear.'\nCommunication system: GO."},
             {"label": "Stay silent", "ok": False, "reply": "Nobody knows your radio works until you use it. Try again."}]}},
         "mission_control": {"title": "Communications - Go / No-Go", "minigame": "comm_houston", "minigame_first": True, "pages": [
         "In Houston the Flight Director polls his controllers one by one. Each watches a single system.",
         "BOOSTER: Go.  RETRO: Go.  FIDO: Go.  GUIDANCE: Go.\nEECOM: Go.  GNC: Go.  TELMU: Go.  CONTROL: Go.\nSURGEON: Go.  CAPCOM: Go.",
         "CAPCOM: 'Apollo 13, Houston. You are GO for launch.'"],
         "choice": {"prompt": "You inspected flight, electrical and life support. Report for the crew:", "options": [
             {"label": "'Apollo 13 is GO.'", "ok": True, "reply": "CAPCOM: 'Roger, Thirteen. Good luck and Godspeed.'\nA 'Go / No-Go' poll means everyone must agree. A single No-Go stops the countdown."},
             {"label": "'Stand by, Houston.'", "ok": False, "reply": "The countdown holds. Your systems all read normal, so there is no reason to wait. Report again."}]}}}},
]

OBJECTIVES = [
    {"id": "explore", "text": "Explore the Command Module", "hint": "Walk to all four sides of the cabin.",
     "type": "zones", "targets": ["mdc", "lheb", "rheb", "leb"], "markers": [[11, 8], [4, 12], [19, 12], [11, 18]]},
    {"id": "checklist", "text": "Inspect the mission checklist", "hint": "The clipboard beside the centre couch.",
     "type": "interact", "targets": ["checklist"], "markers": [[14, 11]]},
    {"id": "flight", "text": "Visit the flight control panel", "hint": "Left side of the main console.",
     "type": "interact", "targets": ["flight_panel"], "markers": [[8, 8]]},
    {"id": "comm_check", "text": "Check the communication system", "hint": "Lower equipment bay, right of the telescope.",
     "type": "interact", "targets": ["comm_console"], "markers": [[14, 18]]},
    {"id": "systems", "text": "Inspect electrical and life support indicators", "hint": "Right side of the main console, and the west wall.",
     "type": "interact", "targets": ["electrical_panel", "o2_panel"], "markers": [[15, 8], [4, 10]]},
    {"id": "mission_control", "text": "Communicate with Mission Control", "hint": "Back to the communication console.",
     "type": "interact", "targets": ["comm_console"], "markers": [[14, 18]]},
    {"id": "prelaunch", "text": "Complete the pre-launch checklist", "hint": "Main switches, then sign the checklist, then strap in.",
     "type": "interact", "ordered": True, "targets": ["main_switches", "checklist", "couch_cmp"],
     "markers": [[11, 8], [14, 11], [11, 13]]},
    {"id": "launch", "text": "Witness the launch", "hint": "", "type": "cutscene", "targets": [], "markers": []},
]

LAUNCH_EVENTS = [
    {"clock": "T-00:50", "skip_if_played": "launch_sequence", "shake": 0, "text": "Launch Control: 'Transfer to internal power.' The rocket now runs on its own batteries."},
    {"clock": "T-00:09", "skip_if_played": "launch_sequence", "shake": 2, "text": "'Ignition sequence start.' Far below, the five F-1 engines of the first stage light one after another."},
    {"clock": "T+00:00", "skip_if_played": "launch_sequence", "shake": 5, "text": "LIFTOFF. 2:13 p.m., 11 April 1970. The hold-down arms release 2,900 tonnes of rocket. The computer flips to Program 11."},
    {"clock": "T+00:12", "shake": 5, "text": "'Tower cleared.' Control of the mission passes from Florida to Mission Control in Houston."},
    {"clock": "T+01:20", "shake": 6, "text": "Maximum dynamic pressure: the air pushes hardest on the rocket now. The cabin shakes."},
    {"clock": "T+02:44", "shake": 1, "text": "First stage empty after pushing you to almost 4 g. It drops away, and the five J-2 engines of the second stage ignite."},
    {"clock": "T+03:21", "shake": 2, "text": "Launch escape tower jettisoned. It takes the protective cover with it, and daylight floods in through every window.", "action": "uncover_windows"},
    {"clock": "T+05:30", "shake": 4, "text": "A shudder. The centre engine light comes ON: the second stage's middle engine has shut down two minutes early. You call it: 'Inboard.'"},
    {"clock": "T+05:50", "shake": 2, "text": "Houston: the other four engines are GO. They will burn about 34 seconds longer to make up the difference. The climb continues."},
    {"clock": "T+09:53", "shake": 2, "text": "Second stage shut down and gone. The single engine of the third stage, the S-IVB, lights to finish the job."},
    {"clock": "T+12:40", "shake": 0, "text": "Engine cutoff. Earth orbit. Everything loose begins to float. Lovell: 'There's nothing like an interesting launch.'", "action": "orbit"},
    {"clock": "ORBIT", "shake": 0, "text": "LEVEL COMPLETE. Odyssey, with Aquarius still packed in the rocket behind it, is circling the Earth. Next stop: the Moon."},
]

# ----------------------------------------------------------------------------
# 6. VALIDATION
# ----------------------------------------------------------------------------
def stand_tiles(it):
    out = []
    ts = {tuple(t) for t in it["tiles"]}
    for (x, y) in ts:
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            p = (x + dx, y + dy)
            if p not in ts and not is_solid(*p) and BASE[p[1]][p[0]] in ".,H":
                out.append(list(p))
    return sorted(map(list, {tuple(p) for p in out}))

from collections import deque
seen = {tuple(PLAYER_START)}; q = deque([tuple(PLAYER_START)])
while q:
    x, y = q.popleft()
    for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        p = (x + dx, y + dy)
        if p not in seen and not is_solid(*p):
            seen.add(p); q.append(p)
ids = {i["id"] for i in INTERACTABLES}
for it in INTERACTABLES:
    it["stand"] = stand_tiles(it)
    assert any(tuple(s) in seen for s in it["stand"]), f"unreachable: {it['id']}"
for z in ZONES:
    x0, y0, x1, y1 = z["rect"]
    assert any((x, y) in seen for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)), f"zone unreachable {z['id']}"
zids = {z["id"] for z in ZONES}
for o in OBJECTIVES:
    for t in o["targets"]:
        assert t in (zids if o["type"] == "zones" else ids), t
    for m in o["markers"]:
        assert tuple(m) in seen, (o["id"], m)

# ----------------------------------------------------------------------------
# 7. WRITE FILES
# ----------------------------------------------------------------------------
for d_ in ("assets", "data", "docs"):
    os.makedirs(os.path.join(ROOT, d_), exist_ok=True)
atlas.save(os.path.join(ROOT, "assets/tileset.png"))
sheet = new(4 * T, T)
for k, f in enumerate(("down", "up", "left", "right")):
    sheet.paste(walker(f), (k * T, 0))
sheet.save(os.path.join(ROOT, "assets/player.png"))
pad_leader().save(os.path.join(ROOT, "assets/npc_pad_leader.png"))
seated_astronaut().save(os.path.join(ROOT, "assets/astronaut_seated.png"))
marker().save(os.path.join(ROOT, "assets/marker.png"))

level = {
    "name": "Apollo 13 - Level 1: Launch Sequence", "tile_size": T, "width": W, "height": H,
    "atlas": {"image": "res://assets/tileset.png", "columns": COLS, "tile_names": names, "solid_ids": sorted(solid)},
    "layers": {"ground": ground, "objects": objects},
    "prologue_minigames": ["medical_exam", "suit_up"],
    "player_start": PLAYER_START, "npcs": NPCS, "zones": ZONES,
    "hatch_tiles": [[11, 4], [12, 4]],
    "covered_window_tiles": [[18, 6], [4, 7], [19, 7]],
    "interactables": INTERACTABLES, "objectives": OBJECTIVES, "launch_events": LAUNCH_EVENTS,
}
with open(os.path.join(ROOT, "data/level1.json"), "w") as f:
    json.dump(level, f, indent=1)
for nm, layer in (("ground", ground), ("objects", objects)):
    with open(os.path.join(ROOT, f"data/level1_{nm}.txt"), "w") as f:
        f.write("\n".join(",".join(str(v) for v in row) for row in layer) + "\n")

# ---- rendered map
def render():
    m = new(W * T, H * T, VOID + (255,))
    for y in range(H):
        for x in range(W):
            m.alpha_composite(tiles[ground[y][x]], (x * T, y * T))
            if objects[y][x] != -1:
                m.alpha_composite(tiles[objects[y][x]], (x * T, y * T))
    seat = seated_astronaut()
    for n in NPCS:
        im = seat if n["sprite"] == "astronaut_seated.png" else pad_leader()
        m.alpha_composite(im, (n["tile"][0] * T, n["tile"][1] * T))
    m.alpha_composite(walker("down"), (PLAYER_START[0] * T, PLAYER_START[1] * T))
    return m

m = render()
m.save(os.path.join(ROOT, "docs/level1_map.png"))

# ---- labelled map
S = 2
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FR = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
f_b, f_s, f_t, f_n = ImageFont.truetype(FB, 15), ImageFont.truetype(FR, 14), ImageFont.truetype(FB, 20), ImageFont.truetype(FB, 13)
MX, MY, LEG = 44, 44, 600
big = m.resize((W * T * S, H * T * S), Image.NEAREST)
out = Image.new("RGBA", (MX + big.width + LEG, MY + big.height + 16), (20, 24, 34, 255))
out.paste(big, (MX, MY)); d = ImageDraw.Draw(out, "RGBA")
ts = T * S
for x in range(W):
    d.text((MX + x * ts + ts / 2, MY - 14), str(x), font=f_n, fill=(150, 160, 176), anchor="mm")
for y in range(H):
    d.text((MX - 16, MY + y * ts + ts / 2), str(y), font=f_n, fill=(150, 160, 176), anchor="mm")
for x in range(W + 1):
    d.line([(MX + x * ts, MY), (MX + x * ts, MY + H * ts)], fill=(255, 255, 255, 22))
for y in range(H + 1):
    d.line([(MX, MY + y * ts), (MX + W * ts, MY + y * ts)], fill=(255, 255, 255, 22))

def tag(txt, tx, ty, col=(20, 24, 34, 215), fg=(255, 255, 255)):
    cx, cy = MX + tx * ts, MY + ty * ts
    w = d.textlength(txt, font=f_b)
    d.rounded_rectangle([cx - w / 2 - 7, cy - 12, cx + w / 2 + 7, cy + 12], 5, fill=col)
    d.text((cx, cy), txt, font=f_b, fill=fg, anchor="mm")

tag("WHITE ROOM", 12, 0.5)
tag("ACCESS ARM  (to launch tower)", 20, 0.5)
tag("HATCH + ACCESS AREA", 12, 5.5)
tag("MAIN DISPLAY CONSOLE", 12, 8.95)
tag("COMMAND MODULE - CREW COUCHES", 12, 14.5)
tag("LIFE SUPPORT", 5.6, 15.5)
tag("BREAKERS + SAFETY", 17.9, 15.5)
tag("LOWER EQUIPMENT BAY: NAVIGATION + COMMUNICATIONS", 12, 20.5)

def badge(n, tx, ty, req):
    cx, cy = MX + tx * ts, MY + ty * ts
    col = (232, 72, 60) if req else (46, 120, 220)
    d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=col, outline=(255, 255, 255), width=2)
    d.text((cx, cy), str(n), font=f_b, fill=(255, 255, 255), anchor="mm")

for it in INTERACTABLES:
    xs = [t[0] for t in it["tiles"]]; ys = [t[1] for t in it["tiles"]]
    if it["id"] in ("stowage", "window_right"):
        for t in it["tiles"]:
            badge(it["n"], t[0] + .5, t[1] + .5, it["required"])
    else:
        badge(it["n"], (min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2, it["required"])
# start marker
sx, sy = MX + (PLAYER_START[0] + .5) * ts, MY + (PLAYER_START[1] + .5) * ts
d.rounded_rectangle([sx - 74, sy + 22, sx - 8, sy + 44], 5, fill=(250, 214, 60))
d.text((sx - 41, sy + 33), "START", font=f_b, fill=(30, 24, 6), anchor="mm")

lx, ly = MX + big.width + 22, MY
d.text((lx, ly), "APOLLO 13  /  LEVEL 1: LAUNCH SEQUENCE", font=f_t, fill=(255, 255, 255)); ly += 30
d.text((lx, ly), f"{W} x {H} tiles, 32 px each. Numbers on the edges are tile x / y.", font=f_s, fill=(170, 180, 196)); ly += 30
d.ellipse([lx, ly, lx + 18, ly + 18], fill=(232, 72, 60)); d.text((lx + 26, ly + 1), "needed to finish the level", font=f_s, fill=(230, 234, 240))
d.ellipse([lx + 250, ly, lx + 268, ly + 18], fill=(46, 120, 220)); d.text((lx + 276, ly + 1), "optional", font=f_s, fill=(230, 234, 240)); ly += 34
for it in INTERACTABLES:
    col = (232, 72, 60) if it["required"] else (46, 120, 220)
    d.ellipse([lx, ly, lx + 24, ly + 24], fill=col)
    d.text((lx + 12, ly + 12), str(it["n"]), font=f_n, fill=(255, 255, 255), anchor="mm")
    t0 = it["tiles"][0]
    d.text((lx + 34, ly + 3), it["name"], font=f_b, fill=(240, 242, 246))
    d.text((lx + LEG - 44, ly + 4), f"({t0[0]},{t0[1]})", font=f_s, fill=(150, 160, 176), anchor="ra")
    ly += 31
ly += 12
d.text((lx, ly), "OBJECTIVE ORDER", font=f_t, fill=(255, 255, 255)); ly += 30
ROUTE = ["Explore: reach all four sides of the cabin", "11  Mission checklist", "5  Flight control panel",
         "19  Communication console (radio check)", "7 + 12  Electrical and oxygen panels",
         "19  Communication console (Go / No-Go)", "6 > 11 > 9  Switches, sign-off, strap in", "Launch cutscene to Earth orbit"]
for k, r in enumerate(ROUTE):
    d.text((lx, ly), f"{k + 1}.  {r}", font=f_s, fill=(230, 234, 240)); ly += 24
out.convert("RGB").save(os.path.join(ROOT, "docs/level1_map_labelled.png"))
print("tiles:", len(tiles), "atlas:", atlas.size, "map:", m.size, "labelled:", out.size)
print("reachable floor tiles:", len(seen))
