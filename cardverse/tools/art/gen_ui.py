#!/usr/bin/env python3
"""Génère les cadres de rareté, le dos de carte, les boosters et les icônes (pixel art)."""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

GW, GH, SC = 150, 210, 3  # grille pixel d'une carte, agrandie x3 => 450x630

# Matériaux des cadres : base, clair, sombre, gemme, motif
FRAMES = {
    "C":  ((128, 124, 130), (190, 186, 190), (60, 58, 66), (200, 200, 210), "stone"),
    "U":  ((70, 140, 90), (150, 220, 150), (24, 60, 36), (120, 255, 150), "bronze"),
    "R":  ((60, 110, 190), (140, 200, 255), (20, 40, 90), (110, 200, 255), "steel"),
    "SR": ((170, 180, 200), (245, 250, 255), (80, 86, 110), (220, 240, 255), "silver"),
    "E":  ((130, 60, 190), (210, 140, 255), (50, 16, 80), (230, 120, 255), "amethyst"),
    "L":  ((220, 160, 50), (255, 235, 140), (110, 64, 10), (255, 220, 90), "gold"),
    "M":  ((190, 40, 60), (255, 140, 120), (80, 10, 24), (255, 80, 90), "crimson"),
    "A":  ((60, 130, 120), (170, 230, 200), (20, 50, 46), (140, 255, 220), "jade"),
    "P":  ((150, 110, 70), (255, 200, 120), (60, 36, 20), (255, 150, 40), "primal"),
    "D":  ((240, 225, 190), (255, 255, 245), (170, 130, 70), (255, 240, 170), "divine"),
    "CE": ((140, 190, 250), (240, 250, 255), (40, 70, 140), (180, 230, 255), "celestial"),
    "CO": ((70, 40, 150), (220, 140, 255), (16, 6, 50), (255, 130, 230), "cosmic"),
    "T":  ((220, 210, 240), (255, 255, 255), (120, 110, 160), (255, 200, 255), "pearl"),
    "AB": ((30, 26, 36), (230, 190, 90), (6, 4, 10), (255, 210, 100), "obsidian"),
    "O":  ((255, 240, 220), (255, 255, 255), (200, 160, 110), (255, 255, 255), "origin"),
    "X":  ((20, 20, 24), (240, 240, 240), (0, 0, 0), (255, 255, 255), "glitch"),
    "NE": ((20, 20, 40), (60, 255, 255), (5, 5, 15), (255, 60, 220), "neon"),
    "IN": ((120, 20, 10), (255, 160, 40), (30, 5, 5), (255, 90, 20), "infernal"),
    "MI": ((180, 150, 230), (255, 240, 255), (90, 70, 150), (220, 180, 255), "mirage"),
    "G":  ((230, 170, 40), (255, 250, 200), (110, 60, 5), (255, 255, 230), "god"),
    "SW": ((30, 60, 80), (120, 255, 240), (8, 16, 30), (80, 255, 230), "swap"),
}

# Gabarit (en pixels de grille 150x210)
WIN = (7, 25, 143, 118)      # fenêtre d'illustration
NAME = (24, 6, 145, 22)      # bandeau du nom
TYPE = (10, 119, 140, 129)   # ligne de type
TEXT = (9, 131, 141, 191)    # zone de texte
COST = (15, 15, 11)          # gemme de coût (cx, cy, r)
ATK = (17, 196, 11)
HP = (133, 196, 11)


def metal(base, light, dark, w, h, pattern, seed=0):
    """Texture de matériau (float 0..1, HxWx3)."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    b, l, d = (np.array(c, np.float32) / 255 for c in (base, light, dark))
    t = 0.5 + 0.5 * np.sin((x * 0.6 + y * 1.0) * 0.08)  # bandes de reflets
    if pattern == "neon":
        t = 0.2 + 0.1 * np.sin(y * 0.6)
    if pattern == "infernal":
        n = rng.random((h // 2 + 1, w // 2 + 1)).repeat(2, 0).repeat(2, 1)[:h, :w]
        t = 0.25 + 0.6 * n * (y / h)
    if pattern == "mirage":
        t = 0.5 + 0.5 * np.sin(x * 0.2 + np.sin(y * 0.15) * 3.0)
    if pattern == "god":
        t = 0.45 + 0.55 * np.abs(np.sin(x * 0.11 + y * 0.07)) ** 3
    if pattern == "primal":
        n = rng.random((h // 2 + 1, w // 2 + 1)).repeat(2, 0).repeat(2, 1)[:h, :w]
        t = 0.3 + 0.35 * n + 0.25 * (np.sin(y * 0.5) > 0.7)
    if pattern == "swap":
        t = 0.5 + 0.5 * np.sin((x + y) * 0.15)
    if pattern in ("stone", "jade", "obsidian"):
        n = rng.random((h // 3 + 1, w // 3 + 1)).repeat(3, 0).repeat(3, 1)[:h, :w]
        t = 0.35 + 0.4 * n
    if pattern in ("cosmic", "celestial", "pearl", "origin", "glitch"):
        t = 0.5 + 0.5 * np.sin(x * 0.12 + np.sin(y * 0.09) * 2.0)
    col = d + (b - d) * np.clip(t * 1.6, 0, 1)[..., None]
    col = col + (l - col) * np.clip((t - 0.7) * 3, 0, 1)[..., None]
    return col


def bevel_rect(arr, mask, light, dark, w=1):
    """Liseré clair en haut/gauche, sombre en bas/droite autour d'un masque booléen."""
    m = mask
    up = np.zeros_like(m)
    up[1:, :] = m[1:, :] & ~m[:-1, :]
    lf = np.zeros_like(m)
    lf[:, 1:] = m[:, 1:] & ~m[:, :-1]
    dn = np.zeros_like(m)
    dn[:-1, :] = m[:-1, :] & ~m[1:, :]
    rt = np.zeros_like(m)
    rt[:, :-1] = m[:, :-1] & ~m[:, 1:]
    arr[up | lf] = np.array(light, np.float32) / 255
    arr[dn | rt] = np.array(dark, np.float32) / 255


def rect_mask(w, h, r):
    m = np.zeros((h, w), bool)
    x0, y0, x1, y1 = r
    m[y0:y1, x0:x1] = True
    return m


def circle_mask(w, h, cx, cy, r):
    y, x = np.mgrid[0:h, 0:w]
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def gem(arr, alpha, cx, cy, r, colr, dark=(20, 14, 30)):
    w, h = arr.shape[1], arr.shape[0]
    outer = circle_mask(w, h, cx, cy, r + 1)
    arr[outer] = np.array(dark, np.float32) / 255
    alpha[outer] = 1
    y, x = np.mgrid[0:h, 0:w]
    inner = circle_mask(w, h, cx, cy, r)
    d = np.sqrt((x - cx + r * 0.35) ** 2 + (y - cy + r * 0.35) ** 2) / (r * 1.6)
    c = np.array(colr, np.float32) / 255
    shade = np.clip(1.1 - d, 0.25, 1.2)[..., None]
    arr[inner] = np.clip((c * shade)[inner], 0, 1)
    hl = circle_mask(w, h, cx - r * 0.35, cy - r * 0.4, max(1, r * 0.22))
    arr[hl & inner] = 1.0


def frame(rar):
    base, light, dark, gemc, pattern = FRAMES[rar]
    W, H = GW, GH
    arr = metal(base, light, dark, W, H, pattern, seed=hash(rar) % 1000)
    alpha = np.ones((H, W), np.float32)
    ink = np.array((14, 10, 22), np.float32) / 255
    # contour extérieur arrondi
    y, x = np.mgrid[0:H, 0:W]
    R = 7
    corner = np.zeros((H, W), bool)
    for cx, cy in ((R, R), (W - 1 - R, R), (R, H - 1 - R), (W - 1 - R, H - 1 - R)):
        q = ((x < R) if cx == R else (x > W - 1 - R)) & ((y < R) if cy == R else (y > H - 1 - R))
        corner |= q & ((x - cx) ** 2 + (y - cy) ** 2 > R * R)
    alpha[corner] = 0
    edge = np.zeros((H, W), bool)
    inside = alpha > 0
    edge[1:-1, 1:-1] = inside[1:-1, 1:-1] & ~(inside[:-2, 1:-1] & inside[2:, 1:-1] & inside[1:-1, :-2] & inside[1:-1, 2:])
    edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
    edge &= inside
    arr[edge] = ink
    inner_border = rect_mask(W, H, (2, 2, W - 2, H - 2)) & ~rect_mask(W, H, (3, 3, W - 3, H - 3))
    arr[inner_border & inside] = np.array(light, np.float32) / 255
    # fenêtre d'illustration (transparente) avec liseré
    win = rect_mask(W, H, WIN)
    ring = rect_mask(W, H, (WIN[0] - 2, WIN[1] - 2, WIN[2] + 2, WIN[3] + 2)) & ~win
    arr[ring] = ink
    bevel_rect(arr, rect_mask(W, H, (WIN[0] - 3, WIN[1] - 3, WIN[2] + 3, WIN[3] + 3)), dark, light)
    alpha[win] = 0
    # bandeau du nom
    nm = rect_mask(W, H, NAME)
    arr[nm] = np.array((18, 14, 30), np.float32) / 255 * 0.6 + arr[nm] * 0.4
    bevel_rect(arr, nm, dark, light)
    # ligne de type
    tm = rect_mask(W, H, TYPE)
    arr[tm] = np.array(dark, np.float32) / 255 * 0.7
    bevel_rect(arr, tm, light, ink * 255)
    # zone de texte : verre sombre semi-transparent
    tx = rect_mask(W, H, TEXT)
    arr[tx] = np.array((16, 12, 26), np.float32) / 255
    alpha[tx] = 0.88
    bevel_rect(arr, tx, dark, light)
    # motifs décoratifs par rareté
    rng = random.Random(rar)
    if pattern in ("gold", "crimson", "divine", "origin", "obsidian", "jade", "swap"):
        for k in range(12, W - 12, 6):  # filigrane le long du bas
            arr[H - 5, k] = np.array(light, np.float32) / 255
            arr[3, k] = np.array(light, np.float32) / 255
    if pattern in ("cosmic", "celestial", "pearl", "origin", "glitch", "swap"):
        for _ in range(40):
            px, py = rng.randrange(3, W - 3), rng.randrange(3, H - 3)
            if inside[py, px] and not win[py, px] and not tx[py, px]:
                arr[py, px] = 1.0
    if pattern == "primal":  # gravures en zigzag et runes d'ambre
        amber = np.array((255, 160, 50), np.float32) / 255
        for yy in range(6, H - 6, 9):
            for xx in (2, 3, W - 4, W - 3):
                if inside[yy, xx]:
                    arr[yy, xx] = amber
        for k in range(10, W - 10, 8):
            for dy, yy in enumerate((2, 3, 4)):
                xx = k + (dy if (k // 8) % 2 else 2 - dy)
                arr[yy, xx] = np.array(dark, np.float32) / 255
                arr[H - 1 - yy, xx] = np.array(dark, np.float32) / 255
    if pattern == "neon":  # double tube néon cyan / magenta
        cyan = np.array((60, 255, 255), np.float32) / 255
        mag = np.array((255, 60, 220), np.float32) / 255
        for k in range(3, W - 3):
            arr[3, k] = cyan
            arr[H - 4, k] = mag
        for k in range(3, H - 3):
            arr[k, 3] = mag
            arr[k, W - 4] = cyan
    if pattern == "infernal":  # braises sur le cadre
        for _ in range(80):
            px, py = rng.randrange(2, W - 2), rng.randrange(2, H - 2)
            if inside[py, px] and not win[py, px] and not tx[py, px]:
                arr[py, px] = np.array(rng.choice([(255, 200, 60), (255, 110, 30), (255, 240, 150)]), np.float32) / 255
    if pattern == "god":  # filigrane gravé, double liseré, couronne solaire et gemmes
        gold_l = np.array((255, 248, 200), np.float32) / 255
        gold_d = np.array((120, 70, 10), np.float32) / 255
        for k in range(10, W - 10, 5):
            for yy in (2, H - 3):
                arr[yy, k] = gold_l if (k // 5) % 2 else gold_d
        for k in range(10, H - 10, 5):
            for xx in (2, W - 3):
                arr[k, xx] = gold_l if (k // 5) % 2 else gold_d
        cxs, cys = W // 2, 4
        for a in range(-60, 61, 15):
            import math as _m
            for r in range(3, 9):
                px, py = int(cxs + _m.sin(_m.radians(a)) * r), int(cys + _m.cos(_m.radians(a)) * r * 0.6)
                if 0 <= px < W and 0 <= py < H and not win[py, px]:
                    arr[py, px] = gold_l
    if pattern == "swap":  # coutures de puzzle irisées
        for gx in (W // 3, 2 * W // 3):
            for yy in range(2, H - 2):
                if inside[yy, gx] and not win[yy, gx] and not tx[yy, gx]:
                    c = 0.5 + 0.5 * np.cos(yy * 0.2 + np.array([0, 2, 4]))
                    arr[yy, gx] = c
        for gy in (H // 3, 2 * H // 3):
            for xx in range(2, W - 2):
                if inside[gy, xx] and not win[gy, xx] and not tx[gy, xx]:
                    c = 0.5 + 0.5 * np.cos(xx * 0.2 + np.array([0, 2, 4]))
                    arr[gy, xx] = c
    if pattern == "glitch":
        for _ in range(14):
            yy = rng.randrange(4, H - 4)
            x0 = rng.randrange(2, W - 30)
            arr[yy, x0:x0 + rng.randrange(6, 26)] = np.array(rng.choice([(255, 0, 80), (0, 255, 220), (255, 255, 255)]), np.float32) / 255
    # coins décoratifs (gemmes)
    for cx, cy in ((5, H - 5), (W - 5, H - 5)) if rar not in ("C", "U") else ():
        gem(arr, alpha, cx, cy, 2, gemc)
    if pattern == "god":
        for cx, cy in ((5, 5), (W - 5, 5), (5, H - 5), (W - 5, H - 5)):
            gem(arr, alpha, cx, cy, 3, (255, 90, 90) if cx < W // 2 else (90, 200, 255))
    # gemme de coût, badges ATK/PV, gemme de rareté
    gem(arr, alpha, COST[0], COST[1], COST[2], (70, 150, 255) if rar != "X" else (255, 255, 255))
    gem(arr, alpha, ATK[0], ATK[1], ATK[2], (230, 90, 60))
    gem(arr, alpha, HP[0], HP[1], HP[2], (80, 200, 110))
    gem(arr, alpha, 75, 193, 5, gemc)
    out = np.dstack([np.clip(arr, 0, 1), alpha])
    im = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    return im.resize((GW * SC, GH * SC), Image.NEAREST)


def card_back():
    W, H = GW, GH
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = W / 2, H / 2
    a = np.arctan2(y - cy, x - cx)
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    sw = 0.5 + 0.5 * np.sin(a * 3 + r * 0.12)
    c1 = np.array((22, 10, 50), np.float32) / 255
    c2 = np.array((90, 50, 190), np.float32) / 255
    c3 = np.array((255, 140, 230), np.float32) / 255
    arr = c1 + (c2 - c1) * sw[..., None]
    arr += (c3 - arr) * np.clip(1 - r / 30, 0, 1)[..., None] * 0.8
    rng = random.Random(7)
    for _ in range(120):
        px, py = rng.randrange(W), rng.randrange(H)
        arr[py, px] = np.minimum(1, arr[py, px] + 0.6)
    # bordures
    m = np.ones((H, W), bool)
    for k, colr in ((0, (10, 6, 20)), (1, (230, 190, 100)), (2, (120, 80, 40)), (5, (230, 190, 100))):
        ring = rect_mask(W, H, (k, k, W - k, H - k)) & ~rect_mask(W, H, (k + 1, k + 1, W - k - 1, H - k - 1))
        arr[ring] = np.array(colr, np.float32) / 255
    # emblème : losange + étoile
    em = (np.abs(x - cx) / 26 + np.abs(y - cy) / 36) <= 1
    emi = (np.abs(x - cx) / 23 + np.abs(y - cy) / 33) <= 1
    arr[em & ~emi] = np.array((240, 200, 110), np.float32) / 255
    star = (np.abs(x - cx) * np.abs(y - cy) < 14) & (r < 16)
    arr[star] = np.array((255, 245, 220), np.float32) / 255
    alpha = np.ones((H, W), np.float32)
    Rr = 7
    for ccx, ccy in ((Rr, Rr), (W - 1 - Rr, Rr), (Rr, H - 1 - Rr), (W - 1 - Rr, H - 1 - Rr)):
        q = ((x < Rr) if ccx == Rr else (x > W - 1 - Rr)) & ((y < Rr) if ccy == Rr else (y > H - 1 - Rr))
        alpha[q & ((x - ccx) ** 2 + (y - ccy) ** 2 > Rr * Rr)] = 0
    out = np.dstack([np.clip(arr, 0, 1), alpha])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA").resize((W * SC, H * SC), Image.NEAREST)


PACKS = {
    "classic": ((50, 90, 200), (140, 200, 255), "f004"),
    "dragons": ((170, 40, 30), (255, 170, 80), "i003"),
    "abyss": ((10, 50, 90), (60, 230, 220), "w003"),
    "cosmic": ((60, 20, 130), (255, 120, 230), "c002"),
    "divine": ((210, 160, 60), (255, 245, 200), "h003"),
    "event": ((160, 30, 90), (255, 200, 90), "f006"),
    "secret": ((10, 10, 14), (120, 255, 210), "v003"),
    "eclipse": ((30, 18, 50), (255, 190, 90), "ec37"),
    "primal": ((90, 50, 20), (255, 170, 70), "pr45"),
    "multiverse": ((50, 40, 140), (160, 200, 255), "c004"),
    "mecanica": ((40, 70, 90), (120, 220, 255), "mc41"),
    "songes": ((60, 40, 110), (255, 190, 250), "sg40"),
    "pantheon": ((150, 100, 20), (255, 240, 170), "pg01"),
    "corsaires": ((10, 40, 90), (80, 240, 255), "cx42"),
    "jungle": ((20, 70, 25), (190, 255, 110), "jg34"),
    "prestige": ((25, 18, 8), (255, 215, 110), "cx45"),
    "mini": ((120, 30, 80), (255, 170, 220), "jg17"),
    "ultime": ((50, 15, 90), (230, 170, 255), "ty12"),
}


def _hex(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def type_packs():
    bs = json.load(open(os.path.join(ROOT, "data", "boosters.json"), encoding="utf-8"))["boosters"]
    for b in bs:
        if b.get("group") == "type":
            c = _hex(b["color"])
            PACKS[b["id"]] = (tuple(int(v * 0.55) for v in c), tuple(min(255, int(v * 1.3) + 40) for v in c), b["mascot"])


def pack(key):
    W, H = 110, 170
    c1, c2, mascot = PACKS[key]
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    t = 0.5 + 0.5 * np.sin(x * 0.09 + y * 0.05)
    a = np.array(c1, np.float32) / 255
    b = np.array(c2, np.float32) / 255
    arr = a * 0.6 + (b - a * 0.6) * (t ** 3)[..., None] * 0.7
    # bandes diagonales du foil
    stripe = ((x + y) % 18) < 2
    arr[stripe] = np.minimum(1, arr[stripe] + 0.12)
    alpha = np.ones((H, W), np.float32)
    # bords sertis (dents en haut et en bas)
    for xx in range(W):
        if xx % 4 < 2:
            alpha[0:3, xx] = 0
            alpha[H - 3:H, xx] = 0
    for yy in (8, 9, H - 10, H - 9):
        arr[yy, :] = np.array((20, 14, 30), np.float32) / 255
    arr[10, :] = b
    arr[H - 11, :] = b
    out = Image.fromarray((np.dstack([np.clip(arr, 0, 1), alpha]) * 255).astype(np.uint8), "RGBA")
    # médaillon avec la créature emblème
    art_p = os.path.join(ROOT, "assets", "cards", mascot + ".png")
    if os.path.exists(art_p):
        art = Image.open(art_p).convert("RGB")
        crop = art.crop((60, 80, 390, 380)).resize((76, 70), Image.NEAREST)
        m = Image.new("L", (76, 70), 0)
        ImageDraw.Draw(m).ellipse([0, 0, 75, 69], fill=255)
        ring = Image.new("RGBA", (82, 76), (0, 0, 0, 0))
        ImageDraw.Draw(ring).ellipse([0, 0, 81, 75], fill=(20, 14, 30, 255))
        ImageDraw.Draw(ring).ellipse([1, 1, 80, 74], fill=tuple(c2) + (255,))
        out.alpha_composite(ring, ((W - 82) // 2, 52))
        out.paste(crop, ((W - 76) // 2, 55), m)
    return out.resize((W * 3, H * 3), Image.NEAREST)


def icons():
    """Icônes d'éléments et de monnaies (32x32 pixels, agrandies x3)."""
    from scenes import ELEMENTS
    S = 32
    res = {}

    def base(colr, glow):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.ellipse([1, 1, S - 2, S - 2], fill=(14, 10, 22, 255))
        d.ellipse([2, 2, S - 3, S - 3], fill=tuple(colr) + (255,))
        d.ellipse([4, 4, S - 5, S - 5], fill=tuple(int(c * 0.55) for c in colr) + (255,))
        return im, d

    W_ = (255, 255, 255, 255)
    for el, e in ELEMENTS.items():
        im, d = base(e["main"], e["glow"])
        g = tuple(e["glow"]) + (255,)
        if el == "feu":
            d.polygon([(16, 6), (23, 17), (21, 24), (16, 27), (11, 24), (9, 17), (13, 13), (14, 17)], fill=g)
            d.polygon([(16, 15), (19, 21), (16, 25), (13, 21)], fill=W_)
        elif el == "eau":
            d.polygon([(16, 6), (22, 17), (21, 23), (16, 26), (11, 23), (10, 17)], fill=g)
            d.ellipse([12, 17, 15, 21], fill=W_)
        elif el == "terre":
            d.polygon([(6, 25), (13, 11), (17, 17), (20, 13), (26, 25)], fill=g)
            d.polygon([(13, 11), (15, 15), (11, 15)], fill=W_)
        elif el == "foudre":
            d.polygon([(18, 5), (10, 18), (15, 18), (13, 27), (22, 13), (17, 13)], fill=g)
        elif el == "glace":
            for a in range(3):
                ang = a * math.pi / 3
                d.line([(16 - 10 * math.cos(ang), 16 - 10 * math.sin(ang)), (16 + 10 * math.cos(ang), 16 + 10 * math.sin(ang))], fill=g, width=2)
            d.ellipse([14, 14, 18, 18], fill=W_)
        elif el == "nature":
            d.ellipse([9, 8, 23, 24], fill=g)
            d.line([(10, 25), (22, 9)], fill=(20, 60, 30, 255), width=1)
        elif el == "ombre":
            d.ellipse([8, 7, 24, 25], fill=g)
            d.ellipse([12, 5, 27, 22], fill=tuple(int(c * 0.55) for c in e["main"]) + (255,))
        elif el == "lumiere":
            for a in range(8):
                ang = a * math.pi / 4
                d.line([(16, 16), (16 + 11 * math.cos(ang), 16 + 11 * math.sin(ang))], fill=g, width=2)
            d.ellipse([11, 11, 21, 21], fill=W_)
        elif el == "cosmique":
            d.polygon([(16, 5), (18, 14), (27, 16), (18, 18), (16, 27), (14, 18), (5, 16), (14, 14)], fill=g)
            d.ellipse([14, 14, 18, 18], fill=W_)
        elif el == "neant":
            d.ellipse([8, 8, 24, 24], fill=g)
            d.ellipse([11, 11, 21, 21], fill=(0, 0, 0, 255))
            d.ellipse([14, 14, 18, 18], fill=g)
        res["el_" + el] = im
    # monnaies
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 28, 28], fill=(90, 50, 10, 255))
    d.ellipse([4, 4, 27, 27], fill=(255, 200, 60, 255))
    d.ellipse([7, 7, 24, 24], fill=(230, 160, 30, 255))
    d.rectangle([14, 10, 17, 21], fill=(255, 240, 160, 255))
    d.ellipse([7, 6, 12, 10], fill=(255, 255, 220, 255))
    res["coin"] = im
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(16, 2), (27, 12), (16, 30), (5, 12)], fill=(20, 20, 60, 255))
    d.polygon([(16, 4), (25, 12), (16, 27), (7, 12)], fill=(120, 200, 255, 255))
    d.polygon([(16, 4), (25, 12), (16, 12)], fill=(210, 240, 255, 255))
    d.polygon([(7, 12), (16, 12), (16, 27)], fill=(60, 120, 230, 255))
    res["crystal"] = im
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.regular_polygon((16, 16, 13), 6, fill=(40, 10, 50, 255))
    d.regular_polygon((16, 16, 11), 6, fill=(220, 90, 255, 255))
    d.regular_polygon((16, 16, 6), 6, fill=(255, 210, 255, 255))
    res["token"] = im
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(16 + math.cos(-math.pi / 2 + k * math.pi / 5) * (13 if k % 2 == 0 else 6), 16 + math.sin(-math.pi / 2 + k * math.pi / 5) * (13 if k % 2 == 0 else 6)) for k in range(10)]
    d.polygon(pts, fill=(255, 120, 80, 255), outline=(60, 10, 20, 255))
    res["event"] = im
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(16, 3), (26, 16), (16, 29), (6, 16)], fill=(30, 10, 40, 255))
    d.polygon([(16, 6), (23, 16), (16, 26), (9, 16)], fill=(180, 120, 255, 255))
    d.ellipse([13, 13, 19, 19], fill=(255, 255, 255, 255))
    res["dust"] = im
    return {k: v.resize((S * 3, S * 3), Image.NEAREST) for k, v in res.items()}


# ---------------------------------------------------------------- forme TITAN : illustration grand format
# L'illustration occupe toute la carte ; le cadre n'est qu'un liseré, un bandeau de nom
# et une zone de texte vitrée plus basse et plus petite.
T_TYPE = (10, 135, 140, 144)
T_TEXT = (8, 145, 142, 193)


def titan_frame(rar):
    base, light, dark, gemc, pattern = FRAMES[rar]
    W, H = GW, GH
    arr = metal(base, light, dark, W, H, pattern, seed=hash(rar) % 1000 + 7)
    alpha = np.zeros((H, W), np.float32)
    ink = np.array((14, 10, 22), np.float32) / 255
    y, x = np.mgrid[0:H, 0:W]
    # coins biseautés (style anguleux, différent des cadres classiques arrondis)
    cut = 6
    outside = (x + y < cut) | ((W - 1 - x) + y < cut) | (x + (H - 1 - y) < cut) | ((W - 1 - x) + (H - 1 - y) < cut)
    border = ((x < 4) | (x > W - 5) | (y < 4) | (y > H - 5)) & ~outside
    # biseaux intérieurs aux coins
    inner_cut = ((x + y < cut + 8) | ((W - 1 - x) + y < cut + 8) | (x + (H - 1 - y) < cut + 8) | ((W - 1 - x) + (H - 1 - y) < cut + 8)) & ~outside
    border |= inner_cut
    alpha[border] = 1
    edge = np.zeros((H, W), bool)
    edge[1:-1, 1:-1] = border[1:-1, 1:-1] & ~(border[:-2, 1:-1] & border[2:, 1:-1] & border[1:-1, :-2] & border[1:-1, 2:])
    arr[edge] = ink
    # liseré lumineux intérieur
    lit = (((x == 4) | (x == W - 5)) & (y > 4) & (y < H - 5)) | (((y == 4) | (y == H - 5)) & (x > 4) & (x < W - 5))
    lit &= ~inner_cut
    arr[lit] = np.array(light, np.float32) / 255
    alpha[lit] = 1
    # stries d'énergie diagonales sur le liseré
    stripe = (((x + y) % 11) < 2) & border & ~edge
    arr[stripe] = np.minimum(1, arr[stripe] + 0.25)
    # bandeau du nom : verre sombre avec une pointe à droite
    nm = (y >= NAME[1]) & (y < NAME[3]) & (x >= NAME[0] - 2) & (x < NAME[2] - (y - NAME[1]) // 2)
    arr[nm] = np.array((12, 8, 24), np.float32) / 255
    alpha[nm] = 0.78
    arr[nm & (y == NAME[3] - 1)] = np.array(light, np.float32) / 255
    alpha[nm & (y == NAME[3] - 1)] = 1
    # ligne de type et zone de texte vitrées
    tm = rect_mask(W, H, T_TYPE)
    arr[tm] = np.array(dark, np.float32) / 255 * 0.8
    alpha[tm] = 0.9
    bevel_rect(arr, tm, light, ink * 255)
    tx = rect_mask(W, H, T_TEXT)
    hexa = ((x // 3 + (y // 3) % 2) % 3 == 0) & tx
    arr[tx] = np.array((14, 10, 26), np.float32) / 255
    arr[hexa] = np.array((24, 18, 44), np.float32) / 255
    alpha[tx] = 0.8
    bevel_rect(arr, tx, dark, light)
    # gemmes
    gem(arr, alpha, COST[0], COST[1], COST[2], (70, 150, 255))
    gem(arr, alpha, ATK[0], ATK[1], ATK[2], (230, 90, 60))
    gem(arr, alpha, HP[0], HP[1], HP[2], (80, 200, 110))
    gem(arr, alpha, 75, 196, 5, gemc)
    out = np.dstack([np.clip(arr, 0, 1), alpha])
    im = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    return im.resize((GW * SC, GH * SC), Image.NEAREST)


def badge(kind):
    """Logos de forme placés à côté du nom : Ω (Oméga) et TITAN. Pixel art, agrandi x3."""
    from PIL import ImageFont
    if kind == "omega":
        w, h = 30, 22
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        hexa = [(6, 0), (w - 7, 0), (w - 1, h // 2), (w - 7, h - 1), (6, h - 1), (0, h // 2)]
        d.polygon(hexa, fill=(20, 10, 40, 255))
        arr = np.array(im).astype(np.float32) / 255
        yy, xx = np.mgrid[0:h, 0:w]
        grad = np.stack([0.55 + 0.45 * np.cos(xx * 0.25 + 0), 0.55 + 0.45 * np.cos(xx * 0.25 + 2.1), 0.75 + 0.25 * np.cos(xx * 0.25 + 4.2)], -1)
        inner = Image.new("L", (w, h), 0)
        ImageDraw.Draw(inner).polygon([(7, 2), (w - 8, 2), (w - 3, h // 2), (w - 8, h - 3), (7, h - 3), (2, h // 2)], fill=255)
        m = np.array(inner) > 0
        shade = (0.35 + 0.35 * (1 - yy / h))[..., None]
        arr[..., :3][m] = (grad * shade)[m]
        im = Image.fromarray((arr * 255).astype(np.uint8), "RGBA")
        d = ImageDraw.Draw(im)
        d.fontmode = "1"
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", 19)
        for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
            d.text((w // 2 + ox, h // 2 + oy), "Ω", font=f, fill=(20, 8, 30, 255), anchor="mm")
        d.text((w // 2, h // 2), "Ω", font=f, fill=(255, 245, 200, 255), anchor="mm")
        d.point([(w // 2 - 4, 6), (w // 2 - 5, 7)], fill=(255, 255, 255, 255))
    else:
        w, h = 52, 18
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.polygon([(5, 0), (w - 1, 0), (w - 6, h - 1), (0, h - 1)], fill=(30, 12, 6, 255))
        arr = np.array(im).astype(np.float32) / 255
        yy, xx = np.mgrid[0:h, 0:w]
        inner = Image.new("L", (w, h), 0)
        ImageDraw.Draw(inner).polygon([(6, 2), (w - 4, 2), (w - 7, h - 3), (3, h - 3)], fill=255)
        m = np.array(inner) > 0
        top = np.array((255, 220, 90), np.float32) / 255
        bot = np.array((200, 50, 20), np.float32) / 255
        t = (yy / h)[..., None]
        arr[..., :3][m] = (top * (1 - t) + bot * t)[m]
        im = Image.fromarray((arr * 255).astype(np.uint8), "RGBA")
        d = ImageDraw.Draw(im)
        d.fontmode = "1"
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 12)
        for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
            d.text((w // 2 + ox, h // 2 + oy), "TITAN", font=f, fill=(40, 10, 0, 255), anchor="mm")
        d.text((w // 2, h // 2), "TITAN", font=f, fill=(255, 255, 235, 255), anchor="mm")
    return im.resize((im.width * SC, im.height * SC), Image.NEAREST)


def main():
    out = os.path.join(ROOT, "assets", "ui")
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    os.makedirs(os.path.join(out, "packs"), exist_ok=True)
    os.makedirs(os.path.join(out, "icons"), exist_ok=True)
    for r in FRAMES:
        frame(r).save(os.path.join(out, "frames", r + ".png"), optimize=True)
    for r in FRAMES:
        titan_frame(r).save(os.path.join(out, "frames", "titan_" + r + ".png"), optimize=True)
    os.makedirs(os.path.join(out, "badges"), exist_ok=True)
    for k in ("omega", "titan"):
        badge(k).save(os.path.join(out, "badges", k + ".png"), optimize=True)
    card_back().save(os.path.join(out, "card_back.png"), optimize=True)
    type_packs()
    for k in PACKS:
        pack(k).save(os.path.join(out, "packs", k + ".png"), optimize=True)
    for k, im in icons().items():
        im.save(os.path.join(out, "icons", k + ".png"), optimize=True)
    layout = {"grid": [GW, GH], "scale": SC, "win": WIN, "name": NAME, "type": TYPE, "text": TEXT, "titan_type": T_TYPE, "titan_text": T_TEXT, "cost": COST, "atk": ATK, "hp": HP}
    json.dump(layout, open(os.path.join(ROOT, "data", "card_layout.json"), "w"), indent=1)
    print("UI générée")


if __name__ == "__main__":
    main()


def ui_icons():
    """Icônes d'interface monochromes (blanches, contour sombre) 24x24 agrandies x4 ; teintables dans Godot."""
    S = 24
    W = (255, 255, 255, 255)
    out = {}

    def new():
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        return im, ImageDraw.Draw(im)

    im, d = new(); d.polygon([(12, 3), (21, 11), (18, 11), (18, 20), (14, 20), (14, 14), (10, 14), (10, 20), (6, 20), (6, 11), (3, 11)], fill=W); out["home"] = im
    im, d = new(); d.rectangle([4, 4, 11, 20], fill=W); d.rectangle([13, 4, 20, 20], fill=W); d.line([(12, 4), (12, 20)], fill=(0, 0, 0, 0)); out["album"] = im
    im, d = new(); d.polygon([(5, 9), (19, 9), (21, 21), (3, 21)], fill=W); d.arc([8, 3, 16, 13], 180, 360, fill=W, width=2); out["shop"] = im
    im, d = new(); d.line([(4, 4), (18, 18)], fill=W, width=3); d.line([(20, 4), (6, 18)], fill=W, width=3); d.line([(3, 15), (9, 21)], fill=W, width=2); d.line([(21, 15), (15, 21)], fill=W, width=2); out["battle"] = im
    im, d = new(); d.rectangle([7, 3, 19, 19], fill=W); d.rectangle([4, 6, 16, 22], fill=(0, 0, 0, 255)); d.rectangle([5, 7, 15, 21], fill=W); out["deck"] = im
    im, d = new()
    for a in range(8):
        ang = a * math.pi / 4
        d.line([(12, 12), (12 + 10 * math.cos(ang), 12 + 10 * math.sin(ang))], fill=W, width=4)
    d.ellipse([5, 5, 19, 19], fill=W); d.ellipse([9, 9, 15, 15], fill=(0, 0, 0, 0)); out["gear"] = im
    im, d = new(); d.rectangle([6, 3, 18, 21], fill=W); [d.line([(9, y), (16, y)], fill=(0, 0, 0, 0), width=1) for y in (8, 12, 16)]; out["missions"] = im
    im, d = new(); d.polygon([(6, 3), (18, 3), (17, 11), (12, 15), (7, 11)], fill=W); d.rectangle([11, 14, 13, 18], fill=W); d.rectangle([7, 18, 17, 21], fill=W); d.arc([2, 4, 9, 11], 90, 270, fill=W, width=2); d.arc([15, 4, 22, 11], 270, 90, fill=W, width=2); out["trophy"] = im
    im, d = new(); d.ellipse([8, 3, 16, 11], fill=W); d.pieslice([4, 12, 20, 28], 180, 360, fill=W); out["user"] = im
    im, d = new(); d.polygon([(4, 12), (12, 4), (12, 9), (20, 9), (20, 15), (12, 15), (12, 20)], fill=W); out["back"] = im
    im, d = new(); d.ellipse([3, 3, 21, 21], fill=W); d.rectangle([11, 10, 13, 17], fill=(0, 0, 0, 0)); d.rectangle([11, 6, 13, 8], fill=(0, 0, 0, 0)); out["info"] = im
    pts = [(12 + math.cos(-math.pi / 2 + k * math.pi / 5) * (10 if k % 2 == 0 else 4.5), 12 + math.sin(-math.pi / 2 + k * math.pi / 5) * (10 if k % 2 == 0 else 4.5)) for k in range(10)]
    im, d = new(); d.polygon(pts, fill=W); out["star"] = im
    im, d = new(); d.rectangle([5, 11, 19, 21], fill=W); d.arc([7, 3, 17, 15], 180, 360, fill=W, width=3); d.line([(7, 9), (7, 11)], fill=W, width=3); d.line([(17, 9), (17, 11)], fill=W, width=3); out["lock"] = im
    im, d = new(); d.ellipse([3, 5, 12, 14], fill=W); d.ellipse([12, 5, 21, 14], fill=W); d.polygon([(4, 11), (20, 11), (12, 21)], fill=W); out["heart"] = im
    im, d = new(); d.rectangle([3, 6, 10, 18], fill=W); d.rectangle([14, 6, 21, 18], fill=W); d.polygon([(11, 9), (13, 12), (11, 15)], fill=W); out["compare"] = im
    im, d = new(); d.arc([4, 4, 20, 20], 30, 300, fill=W, width=3); d.polygon([(20, 6), (20, 13), (14, 9)], fill=W); out["recycle"] = im
    im, d = new(); d.rectangle([4, 10, 20, 21], fill=W); d.rectangle([3, 7, 21, 10], fill=W); d.line([(12, 7), (12, 21)], fill=(0, 0, 0, 0), width=2); d.ellipse([7, 2, 12, 8], outline=W, width=2); d.ellipse([12, 2, 17, 8], outline=W, width=2); out["gift"] = im
    im, d = new(); d.polygon([(12, 2), (17, 10), (16, 16), (12, 21), (8, 16), (7, 10), (10, 7), (11, 11)], fill=W); out["flame"] = im
    im, d = new(); d.rectangle([3, 5, 21, 21], fill=W); d.rectangle([3, 5, 21, 9], fill=W); [d.rectangle([x, y, x + 2, y + 2], fill=(0, 0, 0, 0)) for x in (6, 11, 16) for y in (12, 17)]; out["calendar"] = im
    im, d = new(); d.ellipse([3, 3, 15, 15], outline=W, width=3); d.line([(14, 14), (21, 21)], fill=W, width=4); out["search"] = im
    im, d = new(); d.polygon([(4, 12), (10, 18), (20, 6), (17, 4), (10, 13), (7, 9)], fill=W); out["check"] = im
    im, d = new(); d.line([(5, 5), (19, 19)], fill=W, width=4); d.line([(19, 5), (5, 19)], fill=W, width=4); out["close"] = im
    im, d = new(); d.polygon([(6, 4), (18, 12), (6, 20)], fill=W); out["play"] = im
    im, d = new(); d.ellipse([2, 6, 22, 18], fill=W); d.ellipse([8, 8, 16, 16], fill=(0, 0, 0, 0)); d.ellipse([10, 10, 14, 14], fill=W); out["eye"] = im
    im, d = new(); d.polygon([(2, 14), (8, 6), (14, 4), (22, 3), (18, 8), (21, 9), (16, 13), (18, 15), (10, 17), (4, 20)], fill=W); out["wing"] = im
    im, d = new(); d.ellipse([3, 3, 21, 21], outline=W, width=3); d.line([(6, 18), (18, 6)], fill=W, width=3); out["mute"] = im
    im, d = new(); d.rectangle([4, 8, 16, 20], fill=W); d.ellipse([7, 3, 13, 9], fill=W); d.ellipse([15, 11, 21, 17], fill=W); d.ellipse([7, 17, 13, 23], fill=(0, 0, 0, 0)); out["puzzle"] = im
    im, d = new(); d.polygon([(2, 20), (8, 10), (12, 14), (18, 4), (22, 20)], fill=W); out["trample"] = im
    im, d = new(); d.polygon([(12, 2), (21, 6), (20, 14), (12, 22), (4, 14), (3, 6)], fill=W); d.polygon([(12, 5), (18, 8), (17, 13), (12, 19)], fill=(0, 0, 0, 0)); out["shield"] = im
    im, d = new(); d.polygon([(13, 2), (5, 13), (11, 13), (9, 22), (19, 9), (13, 9)], fill=W); out["energy"] = im
    im, d = new(); d.ellipse([3, 3, 21, 21], fill=W); d.polygon([(12, 6), (14, 11), (19, 12), (14, 13), (12, 18), (10, 13), (5, 12), (10, 11)], fill=(0, 0, 0, 0)); out["globe"] = im

    res = {}
    for k, im in out.items():
        a = np.asarray(im).copy()
        mask = a[..., 3] > 0
        edge = np.zeros_like(mask)
        edge[1:, :] |= mask[:-1, :]; edge[:-1, :] |= mask[1:, :]; edge[:, 1:] |= mask[:, :-1]; edge[:, :-1] |= mask[:, 1:]
        edge &= ~mask
        a[edge] = (10, 6, 20, 200)
        res["ui_" + k] = Image.fromarray(a).resize((S * 4, S * 4), Image.NEAREST)
    return res


if __name__ == "__main__":
    out = os.path.join(ROOT, "assets", "ui", "icons")
    for k, im in ui_icons().items():
        im.save(os.path.join(out, k + ".png"), optimize=True)
