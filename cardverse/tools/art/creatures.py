"""Archétypes de créatures paramétriques.

Chaque fonction dessine en coordonnées locales (0,0 = centre de la créature, ~1 unité = 1 px à l'échelle 1)
transformées vers la toile par la classe Rig (position, échelle, miroir).
Les paramètres de chaque carte (data/cards/*.json -> "art") sculptent une silhouette unique.
"""
import math

from PIL import ImageDraw, ImageFilter

from paint import catmull, darken, lighten, mix


class Rig:
    def __init__(self, p, cx, cy, s, flip=False, pal=None, o=None):
        self.p, self.cx, self.cy, self.s, self.flip = p, cx, cy, s, flip
        self.pal = pal
        self.o = o or {}

    def T(self, x, y):
        if self.flip:
            x = -x
        return (self.cx + x * self.s, self.cy + y * self.s)

    def pts(self, pts):
        return [self.T(x, y) for x, y in pts]

    def r(self, v):
        return v * self.s

    # primitives en coordonnées locales -------------------------------------------------
    def ell(self, x, y, rx, ry, rot=0.0):
        cx, cy = self.T(x, y)
        return self.p.ellipse_mask(cx, cy, rx * self.s, ry * self.s, -rot if self.flip else rot)

    def poly(self, pts):
        return self.p.poly_mask(self.pts(pts))

    def tube(self, pts, radii):
        rr = [v * self.s for v in radii] if isinstance(radii, (list, tuple)) else radii * self.s
        return self.p.tube_mask(self.pts(pts), rr)

    def paint(self, m, c, dark=None, **kw):
        self.p.part(m, c, dark, rim=kw.pop("rim", self.pal["rim"]), **kw)

    def eye(self, x, y, r, color=None, pupil=True, slit=False, cute=False):
        color = color or self.pal["eye"]
        if cute:
            m = self.ell(x, y, r, r * 1.15)
            self.p.part(m, (25, 18, 40), (5, 5, 10), outline=1.2, gloss=0)
            self.p.fill(self.ell(x - r * 0.3, y - r * 0.4, r * 0.38, r * 0.38), (255, 255, 255))
            self.p.fill(self.ell(x + r * 0.35, y + r * 0.35, r * 0.18, r * 0.18), lighten(color, 0.5))
            self.p.add_glow_mask(m, color, 0.25, 3)
            return
        m = self.ell(x, y, r, r * 0.8)
        self.p.fill(m.filter(ImageFilter.MaxFilter(5)), (10, 6, 14))
        self.p.emit(m, color, 0.9, 4 * self.s)
        if pupil:
            pm = self.ell(x, y, r * 0.22, r * 0.7) if slit else self.ell(x, y, r * 0.35, r * 0.35)
            self.p.fill(pm, (10, 4, 10))


def default_pal(element, o):
    from scenes import ELEMENTS
    e = ELEMENTS[element]
    pal = {
        "c1": tuple(o.get("c1", e["main"])),
        "c2": tuple(o.get("c2", lighten(e["main"], 0.45))),
        "c3": tuple(o.get("c3", (235, 225, 200))),
        "eye": tuple(o.get("eye", e["glow"])),
        "glow": tuple(o.get("glow", e["glow"])),
        "rim": tuple(o.get("rim", lighten(e["glow"], 0.3))),
    }
    return pal


# ============================================================================ QUADRUPÈDE / DRAGON
def quadruped(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    far = darken(c1, 0.35)
    bulk = o.get("bulk", 1.0)
    bx, by, brx, bry = 0, 8, 56 * bulk, 32 * bulk
    leg_len = o.get("leg_len", 1.0)
    o.setdefault("head", 1.3)
    o.setdefault("tilt", -0.14)
    neck = o.get("neck", 1.0)
    heads = o.get("heads", 1)
    wings = o.get("wings")
    tail = o.get("tail", 1.0)

    def wing(near):
        sx, sy = -6, by - bry * 0.6
        span = o.get("wing_span", 1.0)
        tipx, tipy = 30 * span, -120 * span
        fingers = [(tipx, tipy), (70 * span, -95 * span), (95 * span, -50 * span), (85 * span, -10 * span)]
        mem = [(sx, sy)] + fingers + [(30, by - bry * 0.2)]
        shade = c1 if near else far
        memc = o.get("membrane", mix_c(c1, c2, 0.4))
        if not near:
            memc = darken(memc, 0.35)
        m = R.poly(mem)
        R.paint(m, memc, darken(memc, 0.55), outline=2, gloss=0.1)
        if o.get("wing_glow"):
            p.add_glow_mask(m, pal["glow"], 0.25, 8)
        for fx, fy in fingers:
            R.paint(R.tube([(sx, sy), ((sx + fx) / 2, (sy + fy) / 2 - 8), (fx, fy)], [5, 3.5, 1.5]), shade, outline=1.5)
        R.paint(R.tube([(sx, sy), (tipx * 0.5, tipy * 0.7), (tipx, tipy)], [7, 5, 2]), shade, outline=2)

    def leg(x, near):
        c = c1 if near else far
        L = leg_len
        if x > 0:  # patte arrière digitigrade
            pts = [(x, by + 2), (x + 12 * bulk, by + bry * 0.5 + 12 * L), (x - 2, by + bry * 0.5 + 30 * L), (x + 4, by + bry * 0.5 + 46 * L)]
            rad = [17 * bulk, 11 * bulk, 7.5 * bulk, 7 * bulk]
        else:
            pts = [(x, by), (x - 4, by + bry * 0.5 + 18 * L), (x + 2, by + bry * 0.5 + 46 * L)]
            rad = [15 * bulk, 9.5 * bulk, 8 * bulk]
        R.paint(R.tube(pts, rad), c)
        foot = pts[-1]
        R.paint(R.ell(foot[0] - 5, foot[1] + 3, 11 * bulk, 6 * bulk), c)
        for k in range(3):
            cx = foot[0] - 13 * bulk + k * 6 * bulk
            R.paint(R.poly([(cx, foot[1] + 5), (cx - 5, foot[1] + 12), (cx + 3, foot[1] + 6)]), c3, outline=0.8)
        if near:  # masse musculaire (hanche / épaule)
            if x > 0:
                R.paint(R.ell(x + 2, by + 2, 24 * bulk, 26 * bulk, 0.2), c1)
            else:
                R.paint(R.ell(x + 2, by - 2, 20 * bulk, 24 * bulk, -0.2), c1)

    # ombre au sol
    gx, gy = R.T(0, by + bry * 0.3 + 52 * leg_len)
    p.shadow(gx, gy + 4, R.r(90 * bulk), R.r(10), 0.45)

    if wings:
        wing(False)
    leg(38 * bulk, False)
    leg(-34 * bulk, False)
    # queue
    if tail > 0:
        tl = tail
        tpts = [(brx * 0.8, by - 6), (brx + 30 * tl, by - 20 * tl), (brx + 55 * tl, by + 5), (brx + 75 * tl, by - 25 * tl)]
        R.paint(R.tube(tpts, [16 * bulk, 10 * bulk, 6, 2]), c1, outline=2.2)
        if o.get("tail_tip") == "flame":
            tx, ty = R.T(*tpts[-1])
            fm = R.ell(tpts[-1][0], tpts[-1][1] - 8, 7, 12)
            p.emit(fm, pal["glow"], 1.2, 10)
        elif o.get("tail_tip") == "spike":
            x, y = tpts[-1]
            R.paint(R.poly([(x - 6, y + 2), (x + 14, y - 10), (x + 2, y + 8)]), c3, outline=1.5)
    # corps
    body = R.ell(bx, by, brx, bry, o.get("tilt", -0.08))
    R.paint(body, c1, outline=2.6)
    if o.get("belly", True):
        bm = R.ell(bx - 4, by + bry * 0.45, brx * 0.78, bry * 0.5)
        bm.paste(0, mask=_inv(body))
        R.paint(bm, c2, outline=0, gloss=0.2)
        # écailles du ventre
        d = ImageDraw.Draw(bm)
        for k in range(6):
            x0 = bx - brx * 0.6 + k * brx * 0.22
            a, b = R.T(x0, by + bry * 0.1), R.T(x0 - 3, by + bry * 0.95)
            p.fill(_line(p, a, b, 1.2 * R.s), darken(c2, 0.3), 0.6)
    # piques dorsales
    if o.get("spikes", True):
        n = 6
        for k in range(n):
            t = k / (n - 1)
            x = -brx * 0.55 + t * brx * 1.2
            y = by - bry * (0.95 - 0.25 * (2 * t - 1) ** 2)
            h = 14 * (1 - abs(t - 0.4)) * o.get("spike_size", 1.0)
            R.paint(R.poly([(x - 6, y + 4), (x + 3, y - h), (x + 7, y + 4)]), c3, outline=1.5, gloss=0.4)
    leg(30 * bulk, True)
    leg(-38 * bulk, True)
    if wings:
        _near_wing = True
    # cou(s) et tête(s)
    for hi in range(heads):
        off = (hi - (heads - 1) / 2) * 34
        hx = -brx * 0.75 - 30 * neck + off * 0.4
        hy = by - bry * 0.6 - 40 * neck + off
        npts = [(-brx * 0.55, by - bry * 0.3), (-brx * 0.75 - 12 * neck + off * 0.2, by - bry * 0.8 - 18 * neck + off * 0.5), (hx, hy)]
        R.paint(R.tube(npts, [22 * bulk, 15 * min(bulk, 1.2), 12]), c1, outline=2.4)
        if o.get("mane"):
            for k in range(7):
                t = k / 6
                x, y = catmull(npts, 14)[int(t * 13)]
                R.paint(R.poly([(x + 6, y - 6), (x + 22, y - 14 + k), (x + 8, y + 4)]), o.get("mane_c", c3), outline=1.2)
        head(R, hx, hy, o, pal, scale=o.get("head", 1.0))


def head(R, hx, hy, o, pal, scale=1.0):
    p = R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    s = scale
    kind = o.get("snout", "reptile")
    # cornes arrière
    horns = o.get("horns", "back")
    if horns == "back":
        for k, dy in enumerate((-4, 4)):
            R.paint(R.tube([(hx + 6 * s, hy - 12 * s + dy), (hx + 24 * s, hy - 26 * s + dy), (hx + 40 * s, hy - 24 * s + dy * 2)], [6 * s, 4 * s, 1]), c3 if k else darken(c3, 0.3), outline=1.6)
    elif horns == "ram":
        R.paint(R.tube([(hx + 4 * s, hy - 14 * s), (hx + 20 * s, hy - 26 * s), (hx + 28 * s, hy - 8 * s), (hx + 16 * s, hy + 2 * s)], [7 * s, 6 * s, 4 * s, 2 * s]), c3, outline=1.6)
    elif horns == "unicorn":
        R.paint(R.poly([(hx - 8 * s, hy - 14 * s), (hx - 26 * s, hy - 52 * s), (hx - 2 * s, hy - 16 * s)]), c3, outline=1.6, gloss=0.6)
        p.add_glow_mask(R.poly([(hx - 8 * s, hy - 14 * s), (hx - 26 * s, hy - 52 * s), (hx - 2 * s, hy - 16 * s)]), pal["glow"], 0.6, 6)
    elif horns == "crown":
        for k in range(5):
            a = -2.6 + k * 0.32
            x, y = hx + math.cos(a) * 18 * s, hy + math.sin(a) * 18 * s
            R.paint(R.poly([(x - 4, y), (x + math.cos(a) * 18 * s, y + math.sin(a) * 18 * s), (x + 4, y)]), c3, outline=1.4)
    if o.get("ears"):
        R.paint(R.poly([(hx + 2 * s, hy - 14 * s), (hx + 12 * s, hy - 38 * s), (hx + 14 * s, hy - 10 * s)]), c1, outline=1.8)
    # crâne
    R.paint(R.ell(hx, hy, 22 * s, 18 * s), c1, outline=2.4)
    if kind == "reptile":
        sn = R.ell(hx - 24 * s, hy + 5 * s, 18 * s, 10 * s, 0.12)
        R.paint(sn, c1, outline=2.2)
        jaw = R.ell(hx - 18 * s, hy + 14 * s, 16 * s, 6 * s, 0.2)
        R.paint(jaw, c2, outline=2)
        for k in range(4):
            x = hx - 34 * s + k * 6 * s
            R.paint(R.poly([(x, hy + 10 * s), (x + 2.5 * s, hy + 17 * s), (x + 5 * s, hy + 10 * s)]), (250, 245, 230), outline=0.8)
        p.fill(R.ell(hx - 38 * s, hy + 1 * s, 2 * s, 1.5 * s), (20, 10, 10))
    elif kind == "beast":
        sn = R.ell(hx - 20 * s, hy + 6 * s, 15 * s, 11 * s)
        R.paint(sn, c2, outline=2)
        R.paint(R.ell(hx - 32 * s, hy + 1 * s, 5 * s, 4 * s), (30, 20, 25), outline=0, gloss=0.6)
        if o.get("tusks"):
            R.paint(R.tube([(hx - 22 * s, hy + 12 * s), (hx - 30 * s, hy + 4 * s), (hx - 34 * s, hy - 8 * s)], [3.5 * s, 2.5 * s, 1]), (250, 240, 220), outline=1.2)
    elif kind == "beak":
        R.paint(R.poly([(hx - 14 * s, hy - 6 * s), (hx - 44 * s, hy + 6 * s), (hx - 12 * s, hy + 12 * s)]), c3, outline=2, gloss=0.5)
    elif kind == "cute":
        R.paint(R.ell(hx - 6 * s, hy + 8 * s, 10 * s, 6 * s), c2, outline=1.4)
        p.fill(R.ell(hx + 10 * s, hy + 6 * s, 5 * s, 3 * s), (255, 120, 140), 0.55)
    # yeux
    if o.get("eyes_style") == "cute":
        R.eye(hx - 6 * s, hy - 4 * s, 6 * s, cute=True)
    else:
        R.eye(hx - 10 * s, hy - 5 * s, 4.5 * s, slit=kind == "reptile")
    if o.get("breath"):
        bx, by = hx - 50 * s, hy + 10 * s
        m = R.poly([(hx - 38 * s, hy + 8 * s), (bx - 60, by - 22), (bx - 80, by + 10), (bx - 50, by + 32)])
        p.emit(m.filter(ImageFilter.GaussianBlur(4 * 3)), pal["glow"], 1.0, 14, core=False)
        p.fill(m.filter(ImageFilter.GaussianBlur(6)), lighten(pal["glow"], 0.4), 0.7)


# ============================================================================ SERPENT / WYRM
def serpent(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    th = o.get("thick", 1.0)
    pts = o.get("path", [(110, 110), (60, 70), (90, 20), (40, -20), (-20, 10), (-60, -40), (-70, -80)])
    rad = [10 * th, 18 * th, 24 * th, 26 * th, 24 * th, 20 * th, 16 * th]
    if o.get("water"):
        gx, gy = R.T(0, 95)
        m = p.ellipse_mask(gx, gy, R.r(150), R.r(18))
        p.part(m, lighten(pal["c1"], 0.2), outline=0, gloss=0)
    body = R.tube(pts, rad)
    R.paint(body, c1, outline=2.6)
    # ventre : tube fin décalé
    bel = R.tube([(x - 4, y + 7) for x, y in pts], [r * 0.45 for r in rad])
    bel.paste(0, mask=_inv(body))
    R.paint(bel, c2, outline=0, gloss=0.25)
    # nageoires dorsales
    if o.get("fins", True):
        path = catmull(pts, 40)
        for k in range(4, len(path) - 6, 5):
            x, y = path[k]
            r = interp_rad(rad, k / len(path))
            R.paint(R.poly([(x - 8, y - r * 0.7), (x + 4, y - r - 14), (x + 8, y - r * 0.6)]), o.get("fin_c", c3), outline=1.4, gloss=0.3)
    hx, hy = pts[-1]
    head(R, hx - 6, hy - 6, dict(o, horns=o.get("horns", "back")), pal, scale=o.get("head", 1.3) * th)
    if o.get("whiskers"):
        for d in (-1, 1):
            R.paint(R.tube([(hx - 30, hy + 4), (hx - 50, hy + 10 + d * 8), (hx - 70, hy - 6 + d * 18)], [2, 1.5, 0.6]), lighten(c3, 0.3), outline=0.8)


def interp_rad(rad, t):
    f = t * (len(rad) - 1)
    i = min(int(f), len(rad) - 2)
    return rad[i] + (rad[i + 1] - rad[i]) * (f - i)


# ============================================================================ helpers
def _inv(m):
    from PIL import ImageOps
    return ImageOps.invert(m)


def _line(p, a, b, w):
    m = p.mask()
    ImageDraw.Draw(m).line([p.S(a[0]), p.S(a[1]), p.S(b[0]), p.S(b[1])], fill=255, width=max(1, int(p.S(w))))
    return m


def mix_c(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
