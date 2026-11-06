"""tools/make-luck-icons.py - run: python tools/make-luck-icons.py
Placeholder art for the new luck items, in the style of the existing ones:
rounded dark tile, rarity-coloured border, label on top, flat icon, effect below."""
import math, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "luck")
FONT = os.path.join(ROOT, "assets", "fonts", "Bungee-Regular.ttf")
S = 512                     # draw big, then shrink to 128 for smooth edges

RARITY = {
    "common":   ((150, 150, 158), (190, 190, 198)),
    "uncommon": ((60, 200, 80), (110, 235, 120)),
    "rare":     ((70, 140, 255), (120, 175, 255)),
    "epic":     ((175, 90, 255), (205, 140, 255)),
}
BG = (22, 30, 48)
WHITE, CREAM, GOLD, ORANGE, RED = (255, 255, 255), (245, 238, 220), (255, 205, 50), (255, 140, 40), (230, 50, 50)


def font(size):
    return ImageFont.truetype(FONT, size)


def text_c(d, xy, txt, size, fill, stroke=0):
    f = font(size)
    while f.getlength(txt) > S * 0.84 and size > 20:
        size -= 4
        f = font(size)
    d.text(xy, txt, font=f, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=(10, 10, 20))


def tile(rarity, label, bottom):
    border, labelc = RARITY[rarity]
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((8, 8, S - 8, S - 8), radius=70, fill=BG, outline=border, width=30)
    d.rounded_rectangle((44, 44, S - 44, S - 44), radius=48, outline=(255, 255, 255, 30), width=4)
    text_c(d, (S / 2, 92), label, 64, labelc)
    if bottom:
        text_c(d, (S / 2, S - 92), bottom, 64, WHITE, 3)
    return im, d


def die(d, cx, cy, size, face, fill=CREAM, pip=(30, 30, 40), angle=0):
    h = size / 2
    corners = [(-h, -h), (h, -h), (h, h), (-h, h)]
    ca, sa = math.cos(angle), math.sin(angle)
    pts = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in corners]
    if angle == 0:
        d.rounded_rectangle((cx - h, cy - h, cx + h, cy + h), radius=size * 0.18, fill=fill, outline=(60, 60, 70), width=6)
    else:
        d.polygon(pts, fill=fill, outline=(60, 60, 70))
    spots = {1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)],
             4: [(-1, -1), (1, -1), (-1, 1), (1, 1)], 5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
             6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]}[face]
    r = size * 0.09
    for sx, sy in spots:
        x, y = sx * size * 0.27, sy * size * 0.27
        px, py = cx + x * ca - y * sa, cy + x * sa + y * ca
        d.ellipse((px - r, py - r, px + r, py + r), fill=pip)


def coin(d, cx, cy, r, label=""):
    d.ellipse((cx - r, cy - r * 0.5 + 6, cx + r, cy + r * 0.5 + 6), fill=(190, 130, 20))
    d.ellipse((cx - r, cy - r * 0.5, cx + r, cy + r * 0.5), fill=GOLD, outline=(200, 140, 20), width=5)


def coin_stack(d, cx, base, r, n):
    for k in range(n):
        coin(d, cx, base - k * r * 0.32, r)


def arrow(d, x1, y1, x2, y2, color, w=22):
    d.line((x1, y1, x2, y2), fill=color, width=w)
    ang = math.atan2(y2 - y1, x2 - x1)
    hl = w * 2.2
    p1 = (x2 + math.cos(ang) * hl * 0.5, y2 + math.sin(ang) * hl * 0.5)
    p2 = (x2 - math.cos(ang - 0.6) * hl, y2 - math.sin(ang - 0.6) * hl)
    p3 = (x2 - math.cos(ang + 0.6) * hl, y2 - math.sin(ang + 0.6) * hl)
    d.polygon([p1, p2, p3], fill=color)


def flame(d, cx, cy, h):
    # Three licks of fire side by side (like the Hot Streak art), then a hot core.
    for dx, hh in ((-0.32, 0.75), (0.32, 0.8), (0, 1.0)):
        x = cx + dx * h
        d.polygon([(x, cy - h * hh), (x + h * 0.3, cy - h * 0.05), (x + h * 0.22, cy + h * 0.3),
                   (x - h * 0.22, cy + h * 0.3), (x - h * 0.3, cy - h * 0.05)], fill=ORANGE)
    d.polygon([(cx, cy - h * 0.6), (cx + h * 0.26, cy + h * 0.05), (cx, cy + h * 0.3), (cx - h * 0.26, cy + h * 0.05)], fill=GOLD)


icons = {}

def make(name):
    def deco(fn):
        icons[name] = fn
        return fn
    return deco


@make("middleRoad")
def _():
    im, d = tile("common", "15-20", "+20")
    d.polygon([(200, 160), (312, 160), (420, 360), (92, 360)], fill=(70, 75, 85))
    for k in range(4):
        y0 = 175 + k * 48
        w = 6 + k * 3
        d.rectangle((256 - w, y0, 256 + w, y0 + 26), fill=GOLD)
    return im


@make("hotDice")
def _():
    im, d = tile("uncommon", "HOT DICE", "+8 EACH")
    flame(d, 175, 250, 120)
    flame(d, 340, 250, 120)
    die(d, 175, 310, 115, 5)
    die(d, 340, 310, 115, 6)
    return im


@make("underdog")
def _():
    im, d = tile("uncommon", "UNDERDOG", "X1.6")
    d.rounded_rectangle((120, 175, 300, 355), radius=16, outline=CREAM, width=10)
    text_c(d, (210, 268), "60", 92, CREAM)
    arrow(d, 370, 355, 370, 180, (110, 235, 120), 26)
    return im


@make("tipJar")
def _():
    im, d = tile("uncommon", "TIP JAR", "+3 A ROUND")
    d.rounded_rectangle((165, 165, 347, 370), radius=40, fill=(160, 200, 230, 90), outline=(200, 230, 255), width=10)
    d.rectangle((185, 150, 327, 180), fill=(150, 110, 70))
    for k, (x, y) in enumerate([(220, 330), (290, 330), (255, 290), (220, 250)]):
        coin(d, x, y, 38)
    return im


@make("piggyBank")
def _():
    im, d = tile("uncommon", "PIGGY", "1 = +2")
    pink, dark = (250, 150, 180), (200, 90, 130)
    d.ellipse((130, 190, 380, 370), fill=pink)
    d.ellipse((345, 245, 420, 315), fill=pink)
    d.ellipse((365, 268, 380, 284), fill=dark); d.ellipse((392, 268, 407, 284), fill=dark)
    d.polygon([(170, 205), (205, 150), (235, 200)], fill=pink)
    d.ellipse((300, 235, 322, 257), fill=(40, 30, 40))
    for x in (170, 220, 290, 340):
        d.rectangle((x, 350, x + 26, 395), fill=pink)
    d.rectangle((220, 200, 290, 212), fill=dark)
    coin(d, 255, 165, 40)
    return im


@make("doubleDown")
def _():
    im, d = tile("rare", "DOUBLE DOWN", "X1.5")
    die(d, 190, 270, 130, 3, angle=-0.3)
    die(d, 330, 270, 130, 3, angle=0.3)
    d.arc((130, 160, 390, 400), start=200, end=340, fill=(120, 175, 255), width=18)
    arrow(d, 360, 188, 380, 215, (120, 175, 255), 18)
    return im


@make("firstImpression")
def _():
    im, d = tile("rare", "1ST THROW", "X1.4")
    die(d, 230, 275, 170, 6)
    cx, cy, r = 360, 200, 62
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=GOLD, outline=(200, 140, 20))
    return im


@make("collector")
def _():
    im, d = tile("rare", "COLLECTOR", "X1.5 HANDS")
    for k, ang in enumerate((-0.35, 0, 0.35)):
        cx, cy = 256 + math.sin(ang) * 120, 290 - math.cos(ang) * 40
        w, h = 110, 150
        ca, sa = math.cos(ang), math.sin(ang)
        pts = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in ((-w/2, -h/2), (w/2, -h/2), (w/2, h/2), (-w/2, h/2))]
        d.polygon(pts, fill=CREAM, outline=(60, 60, 70))
        d.ellipse((cx - 18, cy - 18, cx + 18, cy + 18), fill=RED)
    coin_stack(d, 380, 370, 48, 3)
    return im


@make("interest")
def _():
    im, d = tile("rare", "INTEREST", "MAX 30")
    for k, n in enumerate((2, 3, 5)):
        coin_stack(d, 150 + k * 105, 370, 44, n)
    arrow(d, 120, 225, 330, 160, (110, 235, 120), 20)
    text_c(d, (390, 235), "+10%", 50, (110, 235, 120), 3)
    return im


@make("copycat")
def _():
    im, d = tile("epic", "COPYCAT", "COPIES LEFT")
    fur, dark = (255, 175, 70), (120, 70, 20)
    d.polygon([(250, 200), (275, 120), (310, 190)], fill=fur)
    d.polygon([(360, 190), (395, 120), (420, 200)], fill=fur)
    d.ellipse((235, 165, 435, 360), fill=fur)
    d.ellipse((285, 230, 315, 260), fill=(40, 40, 40)); d.ellipse((355, 230, 385, 260), fill=(40, 40, 40))
    d.polygon([(322, 280), (348, 280), (335, 296)], fill=(230, 90, 120))
    for y in (290, 305):
        d.line((240, y, 300, y + 5), fill=dark, width=5); d.line((370, y + 5, 430, y), fill=dark, width=5)
    arrow(d, 205, 260, 85, 260, (205, 140, 255), 26)
    return im


@make("hatTrick")
def _():
    im, d = tile("epic", "HAT TRICK", "X1.8")
    d.rectangle((185, 140, 325, 265), fill=(25, 25, 30), outline=(90, 90, 100), width=6)
    d.rectangle((185, 225, 325, 252), fill=(175, 90, 255))
    d.rounded_rectangle((140, 260, 370, 288), radius=14, fill=(25, 25, 30), outline=(90, 90, 100), width=6)
    for k in range(3):
        die(d, 180 + k * 76, 340, 62, 3)
    return im


os.makedirs(OUT, exist_ok=True)
for name, fn in icons.items():
    fn().resize((128, 128), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
print("made", len(icons), "icons")
