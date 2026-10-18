"""Draws a quick placeholder picture for every aura (512x512 PNG).

Run:  python3 tools/make_aura_images.py          (all auras)
      python3 tools/make_aura_images.py --new    (only the 7 newest auras)
Output: AuraImages/<Aura Name>.png and AuraImages/_overview.png
        (with --new: AuraImages/_overview_new.png)
Colors match AuraData.lua so the pictures fit the in-game effects.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 512
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AuraImages")

TIERS = {
    "Common": (200, 205, 220),
    "Uncommon": (110, 230, 140),
    "Rare": (90, 170, 255),
    "Epic": (190, 110, 255),
    "Legendary": (255, 200, 70),
    "Mythic": (255, 80, 140),
    "Secret": (255, 255, 255),
    "Divine": (255, 236, 150),
    "Transcendent": (140, 255, 235),
}

AURAS = [
    ("Stardust", 2, "Common", (235, 235, 255), (170, 180, 255)),
    ("Moonbeam", 4, "Common", (210, 230, 255), (140, 170, 230)),
    ("Twilight", 8, "Common", (255, 150, 120), (120, 80, 170)),
    ("Comet", 16, "Uncommon", (120, 220, 255), (255, 255, 255)),
    ("Aurora", 32, "Uncommon", (90, 255, 170), (150, 110, 255)),
    ("Meteor", 64, "Uncommon", (255, 130, 50), (120, 60, 40)),
    ("Nebula", 128, "Rare", (255, 90, 200), (90, 120, 255)),
    ("Pulsar", 256, "Rare", (80, 200, 255), (30, 60, 200)),
    ("Frostmoon", 512, "Rare", (200, 240, 255), (90, 170, 255)),
    ("Solar Flare", 1000, "Epic", (255, 210, 60), (255, 90, 20)),
    ("Eclipse", 2500, "Epic", (30, 20, 40), (255, 170, 60)),
    ("Starfall", 5000, "Epic", (255, 240, 150), (120, 140, 255)),
    ("Supernova", 10000, "Legendary", (255, 250, 200), (255, 120, 40)),
    ("Quasar", 25000, "Legendary", (120, 255, 255), (200, 80, 255)),
    ("Celestial", 50000, "Legendary", (255, 245, 210), (255, 215, 120)),
    ("Black Hole", 100000, "Mythic", (10, 0, 20), (170, 60, 255)),
    ("Galaxy", 250000, "Mythic", (255, 100, 220), (80, 200, 255)),
    ("Cosmic Rift", 500000, "Mythic", (255, 40, 120), (40, 255, 220)),
    ("Big Bang", 1000000, "Secret", (255, 255, 255), (255, 200, 80)),
    ("Void Sovereign", 5000000, "Secret", (0, 0, 0), (255, 0, 80)),
    ("Stellar Phoenix", 10000000, "Divine", (255, 150, 40), (255, 240, 160)),
    ("Chronos", 25000000, "Divine", (255, 225, 120), (120, 200, 255)),
    ("Nebula Leviathan", 50000000, "Divine", (60, 220, 200), (140, 60, 255)),
    ("Astral Dragon", 100000000, "Transcendent", (255, 80, 160), (120, 230, 255)),
    ("Singularity", 250000000, "Transcendent", (10, 0, 20), (200, 120, 255)),
    ("Omniverse", 500000000, "Transcendent", (255, 255, 255), (150, 100, 255)),
    ("Genesis", 1000000000, "Transcendent", (255, 250, 220), (255, 200, 80)),
]
NEW_AURAS = {"Stellar Phoenix", "Chronos", "Nebula Leviathan", "Astral Dragon", "Singularity", "Omniverse", "Genesis"}

YY, XX = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
C = SIZE / 2


def col(rgb):
    return np.array(rgb, dtype=np.float32) / 255.0


def bright(rgb, minimum=0.55):
    """Very dark aura colors can't glow; use a brighter version for light."""
    c = col(rgb)
    m = c.max()
    if m < minimum:
        c = c / max(m, 1e-3) * minimum if m > 0 else np.array([minimum] * 3, np.float32)
    return c


class Canvas:
    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)
        self.light = np.zeros((SIZE, SIZE, 3), np.float32)  # additive glow
        self.base = np.zeros((SIZE, SIZE, 3), np.float32)

    # --- additive light -------------------------------------------------
    def glow(self, x, y, r, color, k=1.0):
        d2 = (XX - x) ** 2 + (YY - y) ** 2
        self.light += color * k * np.exp(-d2 / (r * r))[..., None]

    def ring(self, x, y, r, width, color, k=1.0, squash=1.0, angle=0.0):
        dx, dy = XX - x, YY - y
        ca, sa = math.cos(angle), math.sin(angle)
        rx, ry = dx * ca + dy * sa, (-dx * sa + dy * ca) / squash
        d = np.sqrt(rx * rx + ry * ry)
        self.light += color * k * np.exp(-((d - r) / width) ** 2)[..., None]

    def segment(self, x0, y0, x1, y1, width, color, k=1.0, taper=False):
        px, py = XX - x0, YY - y0
        vx, vy = x1 - x0, y1 - y0
        length2 = vx * vx + vy * vy
        t = np.clip((px * vx + py * vy) / length2, 0, 1)
        dx, dy = px - t * vx, py - t * vy
        if taper:  # thick + bright at the start, thin + faded at the end
            w = width * (1 - t * 0.85)
            fade = 1 - t
        else:
            w = width
            fade = 1.0
        self.light += color * k * (np.exp(-(dx * dx + dy * dy) / (w * w)) * fade)[..., None]

    def stars(self, count, color=(1, 1, 1), size=(0.6, 1.8), k=(0.4, 1.2), area=None):
        for _ in range(count):
            if area:
                x = self.rng.uniform(area[0], area[2])
                y = self.rng.uniform(area[1], area[3])
            else:
                x, y = self.rng.uniform(0, SIZE, 2)
            self.glow(x, y, self.rng.uniform(*size), np.array(color, np.float32), self.rng.uniform(*k))

    def clouds(self, color, scale=6, k=1.0, center_falloff=200, seed_offset=0):
        rng = np.random.default_rng(self.rng.integers(1 << 30) + seed_offset)
        total = np.zeros((SIZE, SIZE), np.float32)
        amp = 1.0
        for octave in range(5):
            n = scale * (2 ** octave)
            small = rng.random((n, n)).astype(np.float32)
            img = Image.fromarray((small * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.BICUBIC)
            total += np.asarray(img, np.float32) / 255.0 * amp
            amp *= 0.5
        total /= total.max()
        total = np.clip((total - 0.35) / 0.65, 0, 1) ** 1.6
        d2 = (XX - C) ** 2 + (YY - C) ** 2
        total *= np.exp(-d2 / (center_falloff ** 2))
        self.light += color * k * total[..., None]

    # --- solid shapes (painted over everything at the end) --------------
    def disk_mask(self, x, y, r, soft=1.0):
        d = np.sqrt((XX - x) ** 2 + (YY - y) ** 2)
        return np.clip((r - d) / soft + 0.5, 0, 1)

    def finish(self, tier_rgb, solids=()):
        img = self.base + self.light
        img = 1 - np.exp(-img * 1.6)  # soft tone mapping = nice glow
        for mask, color in solids:
            img = img * (1 - mask[..., None]) + color * mask[..., None]
        # tier-colored frame + vignette
        d = np.sqrt((XX - C) ** 2 + (YY - C) ** 2) / C
        img *= (1 - 0.35 * np.clip(d - 0.75, 0, 1))[..., None]
        edge = np.minimum.reduce([XX, YY, SIZE - 1 - XX, SIZE - 1 - YY])
        frame = np.exp(-(edge / 7.0) ** 2)
        img = img + col(tier_rgb) * 0.9 * frame[..., None]
        img = np.clip(img, 0, 1)
        return Image.fromarray((img * 255).astype(np.uint8))


def background(cv, c1, c2, tier):
    cv.base += (col(c2) * 0.10 + np.array([0.02, 0.01, 0.05], np.float32))
    d2 = (XX - C) ** 2 + (YY - C) ** 2
    cv.base += bright(c2) * 0.18 * np.exp(-d2 / (300 ** 2))[..., None]
    cv.stars(110, size=(0.5, 1.4), k=(0.25, 0.9))


# ----------------------------------------------------------------------
# One drawing per aura
# ----------------------------------------------------------------------
def draw(name, c1, c2, cv):
    a, b = bright(c1), bright(c2)
    solids = []
    if name == "Stardust":
        cv.glow(C, C, 90, b, 0.35)
        for _ in range(140):
            r = abs(cv.rng.normal(0, 85))
            t = cv.rng.uniform(0, 2 * math.pi)
            cv.glow(C + math.cos(t) * r, C + math.sin(t) * r, cv.rng.uniform(1, 3.2), a, cv.rng.uniform(0.6, 1.6))
    elif name == "Moonbeam":
        for i in range(7):
            ang = -math.pi / 2 + (i - 3) * 0.22
            cv.segment(C, C, C + math.cos(ang) * 260, C + math.sin(ang) * 260, 10, b, 0.2)
        cv.glow(C - 35, C + 25, 120, a, 0.7)
        # crescent: the moon minus a shifted disk
        crescent = cv.disk_mask(C, C, 105) * (1 - cv.disk_mask(C + 52, C - 38, 96))
        solids.append((crescent, col((228, 240, 255))))
    elif name == "Twilight":
        sky = np.clip((YY - 120) / 260, 0, 1)[..., None]
        cv.base += a * 0.55 * sky + b * 0.5 * (1 - sky)
        cv.glow(C, 340, 80, a, 1.6)
        cv.glow(C, 340, 200, a, 0.5)
        solids.append((np.clip((YY - 360) / 2, 0, 1), col((25, 15, 45))))
        cv.stars(40, area=(0, 0, SIZE, 200))
    elif name == "Comet":
        cv.segment(150, 360, 470, 60, 28, b, 0.5, taper=True)
        cv.segment(150, 360, 470, 60, 10, a, 1.2, taper=True)
        cv.segment(150, 360, 420, 160, 6, a, 0.6, taper=True)
        cv.glow(150, 360, 30, np.ones(3, np.float32), 2.5)
        cv.glow(150, 360, 90, a, 0.8)
    elif name == "Aurora":
        for j in range(4):
            for x in range(0, SIZE, 3):
                y = 230 + j * 35 + 45 * math.sin(x / 70 + j * 1.3)
                color = a * (1 - j / 4) + b * (j / 4)
                cv.light += color * 0.06 * np.exp(-((XX - x) ** 2) / 20 - ((YY - y) / 40) ** 2 * (YY < y + 10) - ((YY - y) / 6) ** 2 * (YY >= y + 10))[..., None]
        solids.append((np.clip((YY - 455) / 2, 0, 1), col((10, 10, 25))))
    elif name == "Meteor":
        cv.segment(230, 290, 470, 50, 45, col((255, 90, 30)), 0.7, taper=True)
        cv.segment(230, 290, 470, 50, 18, col((255, 210, 120)), 0.9, taper=True)
        cv.glow(230, 290, 110, a, 0.9)
        solids.append((cv.disk_mask(225, 295, 62), col(c2) * 0.9))
        for ang in (0.3, 1.5, 2.6, 4.0, 5.2):
            cv.segment(225, 295, 225 + math.cos(ang) * 52, 295 + math.sin(ang) * 52, 3, col((255, 140, 40)), 1.0)
    elif name == "Nebula":
        cv.clouds(a, scale=4, k=1.5, center_falloff=230)
        cv.clouds(b, scale=5, k=1.4, center_falloff=230, seed_offset=7)
        cv.stars(60, size=(0.8, 2.2), k=(0.6, 1.4), area=(80, 80, 430, 430))
        cv.glow(C, C, 25, np.ones(3, np.float32), 1.0)
    elif name == "Pulsar":
        for r in (70, 120, 170, 220):
            cv.ring(C, C, r, 4, a, 0.7 * (1 - r / 300))
        cv.segment(C - 40, C + 250, C + 40, C - 250, 14, a, 1.2)
        cv.segment(C - 40, C + 250, C + 40, C - 250, 40, b, 0.5)
        cv.glow(C, C, 35, np.ones(3, np.float32), 2.5)
        cv.glow(C, C, 90, a, 0.9)
    elif name == "Frostmoon":
        cv.glow(C, C - 20, 160, b, 0.5)
        solids.append((cv.disk_mask(C, C - 20, 105), col((215, 240, 255))))
        for _ in range(26):
            x, y = cv.rng.uniform(30, 480, 2)
            s = cv.rng.uniform(6, 14)
            for k in range(3):
                ang = k * math.pi / 3
                cv.segment(x - math.cos(ang) * s, y - math.sin(ang) * s, x + math.cos(ang) * s, y + math.sin(ang) * s, 1.4, a, 1.0)
    elif name == "Solar Flare":
        cv.glow(C, C, 210, b, 0.7)
        for i in range(9):
            ang = i / 9 * 2 * math.pi + 0.2
            r0, r1 = 95, cv.rng.uniform(170, 240)
            mid = ang + 0.25
            cv.segment(C + math.cos(ang) * r0, C + math.sin(ang) * r0, C + math.cos(mid) * r1, C + math.sin(mid) * r1, 14, b, 0.9, taper=True)
        cv.glow(C, C, 100, a, 2.2)
        solids.append((cv.disk_mask(C, C, 95), col((255, 230, 120))))
    elif name == "Eclipse":
        cv.ring(C, C, 112, 14, b, 2.2)
        cv.glow(C, C, 190, b, 0.6)
        for i in range(16):
            ang = i / 16 * 2 * math.pi
            cv.segment(C + math.cos(ang) * 115, C + math.sin(ang) * 115, C + math.cos(ang) * 230, C + math.sin(ang) * 230, 6, b, 0.35, taper=True)
        solids.append((cv.disk_mask(C, C, 108), col((8, 5, 12))))
    elif name == "Starfall":
        for _ in range(16):
            x, y = cv.rng.uniform(80, 520), cv.rng.uniform(-40, 330)
            length = cv.rng.uniform(90, 180)
            cv.segment(x - length * 0.7, y + length * 0.7, x, y, 3, a, 1.3, taper=True)
            cv.glow(x - length * 0.7, y + length * 0.7, 6, np.ones(3, np.float32), 1.5)
        cv.glow(C, 420, 200, b, 0.4)
    elif name == "Supernova":
        for i in range(24):
            ang = i / 24 * 2 * math.pi
            cv.segment(C, C, C + math.cos(ang) * 260, C + math.sin(ang) * 260, 7, b, 0.5, taper=True)
        cv.ring(C, C, 150, 10, b, 1.0)
        cv.ring(C, C, 205, 6, a, 0.6)
        cv.glow(C, C, 70, np.ones(3, np.float32), 3.5)
        cv.glow(C, C, 150, a, 1.0)
    elif name == "Quasar":
        cv.ring(C, C, 120, 18, b, 1.4, squash=0.28, angle=-0.25)
        cv.ring(C, C, 80, 12, a, 1.0, squash=0.28, angle=-0.25)
        cv.segment(C - 60, C + 250, C + 60, C - 250, 12, a, 1.6)
        cv.segment(C - 60, C + 250, C + 60, C - 250, 35, b, 0.6)
        cv.glow(C, C, 30, np.ones(3, np.float32), 3.0)
    elif name == "Celestial":
        for i in range(18):
            ang = i / 18 * 2 * math.pi
            cv.segment(C, C, C + math.cos(ang) * 260, C + math.sin(ang) * 260, 12, a, 0.25)
        for side in (-1, 1):  # wings: feathers fanning up and out
            bx, by = C + side * 40, C + 20
            for f in range(6):
                ang = 0.9 - f * 0.28
                length = 190 - f * 18
                cv.segment(bx, by, bx + side * math.cos(ang) * length, by - math.sin(ang) * length, 9, b, 0.8, taper=True)
        cv.ring(C, C - 115, 55, 6, b, 1.8, squash=0.3)
        cv.glow(C, C, 70, a, 2.0)
    elif name == "Black Hole":
        cv.ring(C, C, 170, 22, b, 1.6, squash=0.32, angle=0.18)
        cv.ring(C, C, 100, 10, b, 1.4)
        cv.glow(C, C, 200, b, 0.5)
        cv.stars(30, size=(0.6, 1.4), area=(150, 150, 360, 360))
        solids.append((cv.disk_mask(C, C, 92), col((0, 0, 0))))
        # the front half of the disk passes in front of the hole
        mask = np.exp(-((np.sqrt(((XX - C) * math.cos(0.18) + (YY - C) * math.sin(0.18)) ** 2 + ((-(XX - C) * math.sin(0.18) + (YY - C) * math.cos(0.18)) / 0.32) ** 2) - 170) / 22) ** 2)
        mask *= ((YY - C) > ((XX - C) * math.tan(0.18)))
        solids.append((np.clip(mask * 1.2, 0, 1), np.clip(b * 1.4, 0, 1)))
    elif name == "Galaxy":
        for arm in range(3):
            for k in range(420):
                t = k / 420
                r = 10 + t * 210
                ang = arm * 2 * math.pi / 3 + t * 4.2 + cv.rng.normal(0, 0.12)
                color = a * (1 - t) + b * t
                cv.glow(C + math.cos(ang) * r + cv.rng.normal(0, 6), C + math.sin(ang) * r * 0.8 + cv.rng.normal(0, 6), cv.rng.uniform(1.2, 3), color, cv.rng.uniform(0.3, 0.9))
        cv.glow(C, C, 60, np.ones(3, np.float32), 1.6)
        cv.glow(C, C, 150, a, 0.4)
    elif name == "Cosmic Rift":
        points = [(110, 40), (190, 150), (160, 220), (280, 280), (240, 350), (360, 470)]
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            cv.segment(x0, y0, x1, y1, 30, a, 0.7)
            cv.segment(x0, y0, x1, y1, 12, b, 1.0)
            cv.segment(x0, y0, x1, y1, 3, np.ones(3, np.float32), 2.0)
        for _ in range(10):
            x0, y0 = points[cv.rng.integers(1, 5)]
            ang = cv.rng.uniform(0, 2 * math.pi)
            ln = cv.rng.uniform(40, 90)
            cv.segment(x0, y0, x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln, 3, b, 0.9, taper=True)
        cv.clouds(a, scale=4, k=0.5, center_falloff=260)
    elif name == "Big Bang":
        rainbow = [(255, 80, 80), (255, 180, 60), (255, 255, 90), (90, 255, 140), (80, 180, 255), (190, 110, 255)]
        for i in range(36):
            ang = i / 36 * 2 * math.pi
            color = col(rainbow[i % len(rainbow)])
            cv.segment(C, C, C + math.cos(ang) * 300, C + math.sin(ang) * 300, 9, color, 0.8, taper=True)
        for r, colr in zip((90, 150, 210), rainbow[::2]):
            cv.ring(C, C, r, 6, col(colr), 0.8)
        cv.glow(C, C, 90, np.ones(3, np.float32), 5.0)
        cv.glow(C, C, 200, b, 0.8)
    elif name == "Void Sovereign":
        cv.base[:] = 0.0
        cv.stars(40, color=(1, 0.3, 0.4), size=(0.5, 1.2), k=(0.2, 0.6))
        cv.glow(C, C + 40, 230, b, 0.35)
        # red cracks
        for _ in range(14):
            ang = cv.rng.uniform(0, 2 * math.pi)
            x0, y0 = C + math.cos(ang) * 120, C + 40 + math.sin(ang) * 120
            x1, y1 = C + math.cos(ang) * 250, C + 40 + math.sin(ang) * 250
            cv.segment(x0, y0, x1, y1, 3, b, 1.2, taper=True)
        # crown
        img = Image.new("L", (SIZE, SIZE), 0)
        dr = ImageDraw.Draw(img)
        dr.polygon([(166, 190), (196, 110), (226, 170), (256, 80), (286, 170), (316, 110), (346, 190)], fill=255)
        crown = np.asarray(img, np.float32) / 255.0
        cv.glow(C, 140, 90, b, 0.8)
        # silhouette head/shoulders
        head = cv.disk_mask(C, 250, 62)
        shoulders = np.clip(((XX - C) / 170) ** 2 + ((YY - 470) / 160) ** 2 < 1, 0, 1).astype(np.float32)
        silhouette = np.clip(head + shoulders, 0, 1)
        cv.glow(C, 250, 120, b, 0.9)
        solids.append((silhouette, col((0, 0, 0))))
        solids.append((crown, col((25, 0, 8))))
        # glowing crown edge + eyes
        edges = img.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(3))
        crown_edge = np.clip(np.asarray(edges, np.float32) / 255.0 * 2, 0, 1)
        solids.append((crown_edge, col((255, 30, 90))))
        for ex in (C - 24, C + 24):
            eye = np.exp(-(((XX - ex) / 10) ** 2 + ((YY - 248) / 4) ** 2))
            solids.append((np.clip(eye * 2, 0, 1), col((255, 60, 100))))
    elif name == "Stellar Phoenix":
        fire = col((255, 120, 30))
        cv.clouds(fire, scale=4, k=0.6, center_falloff=240)
        cv.glow(C, C + 10, 200, a, 0.5)
        # two big wings: fans of fiery feathers
        for side in (-1, 1):
            bx, by = C + side * 28, C - 5
            for f in range(9):
                ang = 1.25 - f * 0.17
                length = 230 - f * 12
                ex, ey = bx + side * math.cos(ang) * length, by - math.sin(ang) * length * 0.95
                cv.segment(bx, by, ex, ey, 13, fire, 0.7, taper=True)
                cv.segment(bx, by, ex, ey, 5, b, 1.1, taper=True)
        # tail feathers curling down
        for t in (-0.45, -0.15, 0.15, 0.45):
            pts = [(C + math.sin(k / 6 * math.pi) * 40 * t * 3 + t * k * 14, C + 40 + k * 30) for k in range(7)]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                cv.segment(x0, y0, x1, y1, 7, fire, 0.6)
                cv.segment(x0, y0, x1, y1, 2.5, b, 1.0)
        # body and head with a crest
        cv.glow(C, C, 40, b, 2.0)
        cv.glow(C, C - 70, 22, np.ones(3, np.float32), 2.2)
        for k in range(3):
            cv.segment(C, C - 80, C - 10 + k * 10, C - 135 - k * 6, 4, b, 1.2, taper=True)
        cv.stars(50, color=(1, 0.8, 0.4), size=(0.8, 2.0), area=(60, 60, 450, 450))
    elif name == "Chronos":
        gold = col((255, 215, 110))
        cv.glow(C, C, 230, b, 0.35)
        # tilted icy time rings around the clock
        cv.ring(C, C, 215, 6, b, 1.0, squash=0.35, angle=0.5)
        cv.ring(C, C, 200, 5, b, 0.8, squash=0.35, angle=-0.6)
        # the clock face
        cv.ring(C, C, 150, 7, gold, 1.8)
        cv.ring(C, C, 128, 3, gold, 0.9)
        for i in range(12):
            ang = i / 12 * 2 * math.pi
            inner = 112 if i % 3 == 0 else 122
            cv.segment(C + math.cos(ang) * inner, C + math.sin(ang) * inner, C + math.cos(ang) * 140, C + math.sin(ang) * 140, 4 if i % 3 == 0 else 2.5, gold, 1.6)
        # hands
        cv.segment(C, C, C + 62, C - 70, 6, gold, 1.8)
        cv.segment(C, C, C - 20, C - 112, 4, gold, 1.8)
        cv.glow(C, C, 14, np.ones(3, np.float32), 2.5)
        # little floating gears
        for gx, gy, gr in ((95, 110, 30), (420, 400, 38), (410, 105, 22)):
            cv.ring(gx, gy, gr, 4, gold, 1.1)
            for t in range(10):
                ang = t / 10 * 2 * math.pi
                cv.segment(gx + math.cos(ang) * gr, gy + math.sin(ang) * gr, gx + math.cos(ang) * (gr + 9), gy + math.sin(ang) * (gr + 9), 3, gold, 1.0)
    elif name == "Nebula Leviathan":
        cv.clouds(b, scale=4, k=1.1, center_falloff=250)
        cv.clouds(a, scale=5, k=0.7, center_falloff=250, seed_offset=3)
        # a long sea serpent swimming in an S curve
        points = []
        for k in range(60):
            t = k / 59
            x = 70 + t * 370
            y = C + math.sin(t * 2.6 * math.pi) * 110
            points.append((x, y, t))
        for x, y, t in points:
            r = 34 * (1 - t * 0.8) + 4
            color = a * (1 - t) + b * t
            cv.glow(x, y, r, color, 0.55)
        for (x0, y0, t), (x1, y1, _) in zip(points[::5], points[5::5]):
            # glowing spikes along its back
            ang = math.atan2(y1 - y0, x1 - x0) - math.pi / 2
            length = 32 * (1 - t * 0.7)
            cv.segment(x0, y0, x0 + math.cos(ang) * length, y0 + math.sin(ang) * length, 4, np.ones(3, np.float32) * 0.8, 0.9, taper=True)
        hx, hy, _ = points[0]
        cv.glow(hx, hy, 50, a, 1.2)
        cv.glow(hx - 6, hy - 12, 6, np.ones(3, np.float32), 3.0)  # eye
        cv.stars(50, size=(0.8, 2.0), k=(0.6, 1.4))
    elif name == "Astral Dragon":
        cv.glow(C, C, 220, b, 0.3)
        # a constellation dragon: stars joined by thin lines
        body = [(400, 120), (340, 150), (300, 210), (330, 270), (280, 330), (200, 340), (150, 300), (170, 240), (230, 230), (250, 280)]
        for (x0, y0), (x1, y1) in zip(body, body[1:]):
            cv.segment(x0, y0, x1, y1, 16, a, 0.35)
            cv.segment(x0, y0, x1, y1, 2.5, b, 1.4)
        for i, (x, y) in enumerate(body):
            cv.glow(x, y, 11 if i else 18, np.ones(3, np.float32), 2.0)
            cv.glow(x, y, 28, a if i % 2 else b, 0.8)
        # head: horns and star-fire breath
        hx, hy = body[0]
        cv.segment(hx, hy, hx + 40, hy - 55, 4, b, 1.6, taper=True)
        cv.segment(hx, hy, hx + 10, hy - 65, 4, b, 1.6, taper=True)
        cv.segment(hx, hy, 60, 60, 30, a, 0.6, taper=True)
        cv.segment(hx, hy, 60, 60, 10, np.ones(3, np.float32), 1.0, taper=True)
        cv.stars(70, size=(0.6, 1.8), k=(0.5, 1.2))
    elif name == "Singularity":
        cv.base[:] = 0.01
        cv.stars(70, size=(0.5, 1.4), k=(0.3, 0.9))
        # everything streaks inward
        for i in range(40):
            ang = i / 40 * 2 * math.pi + cv.rng.uniform(-0.05, 0.05)
            r0 = cv.rng.uniform(170, 260)
            cv.segment(C + math.cos(ang) * 95, C + math.sin(ang) * 95, C + math.cos(ang + 0.25) * r0, C + math.sin(ang + 0.25) * r0, 2.5, b, 0.6, taper=False)
        cv.ring(C, C, 150, 16, b, 1.8, squash=0.25, angle=0.1)
        cv.ring(C, C, 150, 14, b, 1.2, squash=0.25, angle=0.1 + math.pi / 2)
        cv.ring(C, C, 92, 6, np.ones(3, np.float32), 2.0)
        cv.glow(C, C, 160, b, 0.7)
        solids.append((cv.disk_mask(C, C, 86), col((0, 0, 0))))
    elif name == "Omniverse":
        cv.glow(C, C, 60, np.ones(3, np.float32), 2.5)
        cv.glow(C, C, 170, b, 0.6)
        planets = [(255, 120, 120), (120, 220, 255), (255, 210, 90), (140, 255, 160), (220, 130, 255), (255, 160, 220), (160, 180, 255)]
        for i, pc in enumerate(planets):
            rx, ry = 70 + i * 26, 30 + i * 9
            angle = 0.35 + i * 0.12
            cv.ring(C, C, rx, 1.5, np.ones(3, np.float32), 0.35, squash=ry / rx, angle=angle)
            t = i * 1.7 + 0.6
            px = C + math.cos(t) * rx * math.cos(angle) - math.sin(t) * ry * math.sin(angle)
            py = C + math.cos(t) * rx * math.sin(angle) + math.sin(t) * ry * math.cos(angle)
            size = 10 + (i % 3) * 5
            cv.glow(px, py, size * 2.2, col(pc), 0.9)
            solids.append((cv.disk_mask(px, py, size), col(pc) * 0.85))
        cv.stars(80, size=(0.6, 1.6), k=(0.4, 1.0))
    elif name == "Genesis":
        cv.base += col((40, 30, 15)) * 0.4
        for i in range(48):
            ang = i / 48 * 2 * math.pi
            length = 300 if i % 2 == 0 else 200
            cv.segment(C, C, C + math.cos(ang) * length, C + math.sin(ang) * length, 7 if i % 2 == 0 else 4, b, 0.6, taper=True)
        for r, k in ((110, 1.0), (170, 0.7), (230, 0.45)):
            cv.ring(C, C, r, 5, a, k)
        cv.glow(C, C, 120, b, 1.4)
        cv.glow(C, C, 60, np.ones(3, np.float32), 5.0)
        # golden horizon
        cv.light += b * 0.5 * np.exp(-((YY - 400) / 10) ** 2)[..., None] * np.exp(-((XX - C) / 220) ** 2)[..., None]
        cv.stars(60, color=(1, 0.95, 0.8), size=(0.8, 2.0), k=(0.5, 1.3))
    return solids



def main():
    import sys
    only_new = "--new" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    images = []
    for i, (name, chance, tier, c1, c2) in enumerate(AURAS):
        if only_new and name not in NEW_AURAS:
            continue
        cv = Canvas(seed=1000 + i)
        background(cv, c1, c2, tier)
        solids = draw(name, c1, c2, cv)
        img = cv.finish(TIERS[tier], solids)
        img.save(os.path.join(OUT, f"{name}.png"))
        images.append((name, chance, tier, img))
        print("made", name)

    # overview sheet with names
    cols, thumb, pad, label_h = (4 if only_new else 5), 220, 14, 46
    rows = math.ceil(len(images) / cols)
    sheet = Image.new("RGB", (cols * (thumb + pad) + pad, rows * (thumb + label_h + pad) + pad), (14, 11, 28))
    draw_ctx = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 17)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    for idx, (name, chance, tier, img) in enumerate(images):
        r, c = divmod(idx, cols)
        x = pad + c * (thumb + pad)
        y = pad + r * (thumb + label_h + pad)
        sheet.paste(img.resize((thumb, thumb), Image.LANCZOS), (x, y))
        draw_ctx.text((x + thumb / 2, y + thumb + 6), name, fill=TIERS[tier], font=font, anchor="mt")
        draw_ctx.text((x + thumb / 2, y + thumb + 27), f"{tier} • 1 in {chance:,}", fill=(190, 180, 225), font=small, anchor="mt")
    sheet.save(os.path.join(OUT, "_overview_new.png" if only_new else "_overview.png"))
    print("made overview")


if __name__ == "__main__":
    main()
