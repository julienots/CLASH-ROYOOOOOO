"""Moteur de peinture procédurale de CARDVERSE.

Rendu supersamplé (x2) puis réduit pour un anti-crénelage propre.
Chaque « partie » d'une créature est un masque peint avec un ombrage volumétrique
(lumière en haut à gauche), un contour encré, une lumière de bord colorée et des lueurs émissives.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 3  # facteur de supersampling interne
OUT = 1.5  # taille de sortie = unités logiques x OUT


def clamp01(a):
    return np.clip(a, 0.0, 1.0)


def col(c):
    return np.array(c[:3], dtype=np.float32) / 255.0


def mix(a, b, t):
    return a + (b - a) * t


def lighten(c, t):
    return tuple(int(v + (255 - v) * t) for v in c[:3])


def darken(c, t):
    return tuple(int(v * (1 - t)) for v in c[:3])


def smoothstep(e0, e1, x):
    t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


class Painter:
    def __init__(self, w, h, seed=0):
        self.W, self.H = w * SS, h * SS
        self.w, self.h = w, h
        self.img = np.zeros((self.H, self.W, 3), np.float32)
        self.glow = np.zeros((self.H, self.W, 3), np.float32)
        self.rng = random.Random(seed)
        self.light = (-0.55, -0.8)  # direction d'où vient la lumière
        self.rim = (255, 255, 255)
        self.ink = (18, 12, 28)
        self.fg = Image.new("L", (self.W, self.H), 0)

    # ------------------------------------------------------------------ masques
    def mask(self):
        return Image.new("L", (self.W, self.H), 0)

    def S(self, v):
        return v * SS

    def P(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def ellipse_mask(self, cx, cy, rx, ry, rot=0.0, m=None):
        m = m or self.mask()
        if rot == 0:
            ImageDraw.Draw(m).ellipse([self.S(cx - rx), self.S(cy - ry), self.S(cx + rx), self.S(cy + ry)], fill=255)
        else:
            pts = []
            for i in range(48):
                a = i / 48 * math.tau
                x, y = rx * math.cos(a), ry * math.sin(a)
                pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
            ImageDraw.Draw(m).polygon(self.P(pts), fill=255)
        return m

    def poly_mask(self, pts, m=None):
        m = m or self.mask()
        ImageDraw.Draw(m).polygon(self.P(pts), fill=255)
        return m

    def tube_mask(self, pts, radii, m=None, steps=None):
        """Tube le long d'une courbe de Catmull-Rom, rayon interpolé."""
        m = m or self.mask()
        d = ImageDraw.Draw(m)
        path = catmull(pts, steps or max(8, int(path_len(pts) / 2)))
        n = len(path)
        for i, (x, y) in enumerate(path):
            t = i / max(1, n - 1)
            r = interp(radii, t)
            if r <= 0.2:
                continue
            d.ellipse([self.S(x - r), self.S(y - r), self.S(x + r), self.S(y + r)], fill=255)
        return m

    # ------------------------------------------------------------------ peinture
    def fill(self, m, c, a=1.0):
        bb = m.getbbox()
        if not bb:
            return
        x0, y0, x1, y1 = bb
        al = np.asarray(m.crop(bb), np.float32)[..., None] / 255.0 * a
        self.img[y0:y1, x0:x1] = self.img[y0:y1, x0:x1] * (1 - al) + col(c) * al

    def fill_field(self, m, field, a=1.0):
        al = np.asarray(m, np.float32)[..., None] / 255.0 * a
        self.img = self.img * (1 - al) + field * al

    def part(self, m, base, dark=None, rim=None, outline=1.2, gloss=0.18, soft=None, a=1.0, ink=None, fg=True):
        """Peint une partie avec volume, contour et lumière de bord (calculs limités à sa zone)."""
        bbox = m.getbbox()
        if not bbox:
            return
        dark = dark or darken(base, 0.6)
        rim = rim or self.rim
        span = max(bbox[2] - bbox[0], bbox[3] - bbox[1])
        r = soft or max(4, span * 0.16)
        pad = int(r * 2 + outline * SS * 2 + 8)
        x0, y0 = max(0, bbox[0] - pad), max(0, bbox[1] - pad)
        x1, y1 = min(self.W, bbox[2] + pad), min(self.H, bbox[3] + pad)
        mc = m.crop((x0, y0, x1, y1))
        reg = self.img[y0:y1, x0:x1]
        if fg:
            self.fg.paste(255, (x0, y0), mc)
        if outline > 0:
            size = int(outline * SS) * 2 + 1
            om = mc.filter(ImageFilter.MaxFilter(min(size, 9) | 1))
            if size > 9:
                om = om.filter(ImageFilter.MaxFilter((size - 8) | 1))
            al = np.asarray(om, np.float32)[..., None] / 255.0 * a
            reg = reg * (1 - al) + col(ink or self.ink) * al
            if fg:
                self.fg.paste(255, (x0, y0), om)
        lx, ly = self.light
        sh = int(r * 0.9)
        lit = mc.transform(mc.size, Image.AFFINE, (1, 0, lx * sh, 0, 1, ly * sh)).filter(ImageFilter.GaussianBlur(r))
        b = np.asarray(lit, np.float32) / 255.0
        t = smoothstep(0.1, 0.95, b)[..., None]
        field = mix(col(dark), col(base), t)
        if gloss > 0:
            spec = smoothstep(0.93, 1.0, b)[..., None] * gloss
            field = field + (1 - field) * spec
        rm = mc.transform(mc.size, Image.AFFINE, (1, 0, -lx * r * 0.45, 0, 1, -ly * r * 0.45))
        rim_a = clamp01((np.asarray(mc, np.float32) - np.asarray(rm, np.float32)) / 255.0)
        rim_a = np.asarray(Image.fromarray((rim_a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(SS * 1.2)), np.float32) / 255.0
        field = mix(field, col(rim), (rim_a * 0.55)[..., None])
        al = np.asarray(mc, np.float32)[..., None] / 255.0 * a
        self.img[y0:y1, x0:x1] = reg * (1 - al) + field * al

    def flat(self, m, c, outline=0, a=1.0):
        if outline:
            om = m.filter(ImageFilter.MaxFilter(int(outline * SS) * 2 + 1))
            self.fill(om, self.ink, a)
        self.fill(m, c, a)

    def emit(self, m, c, strength=1.0, radius=10, core=True):
        """Partie lumineuse : coeur plein + halo dans la couche de lueur."""
        if core:
            self.fill(m, lighten(c, 0.55))
        self.add_glow_mask(m, c, strength, radius)

    def add_glow_mask(self, m, c, strength=1.0, radius=10):
        bb = m.getbbox()
        if not bb:
            return
        pad = int(radius * SS * 3)
        x0, y0, x1, y1 = max(0, bb[0] - pad), max(0, bb[1] - pad), min(self.W, bb[2] + pad), min(self.H, bb[3] + pad)
        g = m.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(radius * SS))
        self.glow[y0:y1, x0:x1] += np.asarray(g, np.float32)[..., None] / 255.0 * col(c) * strength

    def shadow(self, cx, cy, rx, ry, a=0.45):
        m = self.ellipse_mask(cx, cy, rx, ry).filter(ImageFilter.GaussianBlur(ry * SS * 0.6))
        self.fill(m, (0, 0, 0), a)

    # ------------------------------------------------------------------ fonds
    def vgrad(self, top, bottom, y0=0.0, y1=1.0):
        y = np.linspace(0, 1, self.H, dtype=np.float32)[:, None, None]
        t = clamp01((y - y0) / max(1e-4, y1 - y0))
        self.img = np.broadcast_to(mix(col(top), col(bottom), t), self.img.shape).copy()

    def radial(self, cx, cy, r, c, a=1.0, power=1.6):
        yy, xx = np.mgrid[0:self.H, 0:self.W].astype(np.float32)
        d = np.sqrt((xx - cx * SS) ** 2 + (yy - cy * SS) ** 2) / (r * SS)
        t = (clamp01(1 - d) ** power)[..., None] * a
        self.img = self.img + (col(c) - self.img) * t

    def radial_glow(self, cx, cy, r, c, a=1.0, power=2.0):
        yy, xx = np.mgrid[0:self.H, 0:self.W].astype(np.float32)
        d = np.sqrt((xx - cx * SS) ** 2 + (yy - cy * SS) ** 2) / (r * SS)
        self.glow += (clamp01(1 - d) ** power)[..., None] * col(c) * a

    def clouds(self, c, n, y0, y1, rmin, rmax, a=0.5, blur=18, seed_shift=0):
        m = self.mask()
        d = ImageDraw.Draw(m)
        rng = random.Random(self.rng.random() + seed_shift)
        for _ in range(n):
            x, y = rng.uniform(-40, self.w + 40), rng.uniform(y0, y1)
            r = rng.uniform(rmin, rmax)
            d.ellipse([self.S(x - r * 1.6), self.S(y - r * 0.7), self.S(x + r * 1.6), self.S(y + r * 0.7)], fill=255)
        self.fill(m.filter(ImageFilter.GaussianBlur(blur * SS)), c, a)

    def stars(self, n, y0=0, y1=None, c=(255, 255, 255), big=0.08):
        y1 = self.h if y1 is None else y1
        m = self.mask()
        d = ImageDraw.Draw(m)
        g = self.mask()
        dg = ImageDraw.Draw(g)
        for _ in range(n):
            x, y = self.rng.uniform(0, self.w), self.rng.uniform(y0, y1)
            r = self.rng.uniform(0.3, 1.2)
            v = int(self.rng.uniform(120, 255))
            d.ellipse([self.S(x - r), self.S(y - r), self.S(x + r), self.S(y + r)], fill=v)
            if self.rng.random() < big:
                L = self.rng.uniform(4, 10)
                dg.line([self.S(x - L), self.S(y), self.S(x + L), self.S(y)], fill=255, width=SS)
                dg.line([self.S(x), self.S(y - L), self.S(x), self.S(y + L)], fill=255, width=SS)
                dg.ellipse([self.S(x - 2), self.S(y - 2), self.S(x + 2), self.S(y + 2)], fill=255)
        self.fill(m, c)
        self.fill(g, c)
        self.add_glow_mask(g, c, 0.8, 3)

    def ridge(self, y, amp, c, rough=0.5, seed=0, peaks=6, a=1.0, blur=0):
        """Silhouette de montagnes / collines remplie jusqu'en bas."""
        rng = random.Random(seed)
        pts = [(-10, self.h + 10)]
        n = 60
        phase = [rng.uniform(0, 6.28) for _ in range(4)]
        for i in range(n + 1):
            x = -10 + (self.w + 20) * i / n
            v = (math.sin(x / self.w * peaks + phase[0]) * 0.6 + math.sin(x / self.w * peaks * 2.3 + phase[1]) * 0.3 * rough
                 + math.sin(x / self.w * peaks * 5.1 + phase[2]) * 0.15 * rough)
            pts.append((x, y - amp * (0.5 + 0.5 * v)))
        pts.append((self.w + 10, self.h + 10))
        m = self.poly_mask(pts)
        if blur:
            m = m.filter(ImageFilter.GaussianBlur(blur * SS))
        self.fill(m, c, a)
        return m

    def rays(self, cx, cy, n, c, a=0.25, spread=1.0, length=700, width=0.08, seed=0):
        rng = random.Random(seed)
        m = self.mask()
        d = ImageDraw.Draw(m)
        for i in range(n):
            ang = -math.pi / 2 + (rng.random() - 0.5) * math.pi * spread
            w = width * rng.uniform(0.4, 1.2)
            p = [(cx, cy), (cx + math.cos(ang - w) * length, cy + math.sin(ang - w) * length),
                 (cx + math.cos(ang + w) * length, cy + math.sin(ang + w) * length)]
            d.polygon(self.P(p), fill=int(255 * rng.uniform(0.3, 1)))
        self.add_glow_mask(m.filter(ImageFilter.GaussianBlur(6 * SS)), c, a, 4)

    def particles(self, n, c, x0, x1, y0, y1, rmin=0.8, rmax=2.5, strength=1.0, glow_r=4):
        m = self.mask()
        d = ImageDraw.Draw(m)
        for _ in range(n):
            x, y = self.rng.uniform(x0, x1), self.rng.uniform(y0, y1)
            r = self.rng.uniform(rmin, rmax)
            d.ellipse([self.S(x - r), self.S(y - r), self.S(x + r), self.S(y + r)], fill=int(self.rng.uniform(150, 255)))
        self.emit(m, c, strength, glow_r)

    def noise_tex(self, scale, octaves=3, seed=0):
        rng = np.random.default_rng(seed)
        acc = np.zeros((self.H, self.W), np.float32)
        amp = 1.0
        tot = 0
        for o in range(octaves):
            gw, gh = max(2, int(self.w / scale * 2 ** o)), max(2, int(self.h / scale * 2 ** o))
            g = (rng.random((gh, gw)) * 255).astype(np.uint8)
            up = np.asarray(Image.fromarray(g).resize((self.W, self.H), Image.BICUBIC), np.float32) / 255.0
            acc += up * amp
            tot += amp
            amp *= 0.5
        return acc / tot

    def nebula(self, c1, c2, a=0.7, scale=120, seed=0):
        n = self.noise_tex(scale, 4, seed)
        n2 = self.noise_tex(scale * 0.7, 3, seed + 7)
        t1 = smoothstep(0.45, 0.8, n)[..., None] * a
        t2 = smoothstep(0.5, 0.85, n2)[..., None] * a * 0.8
        self.img = self.img + (col(c1) - self.img) * t1
        self.glow += col(c2) * t2 * 0.35

    def grain(self, amount=0.025):
        rng = np.random.default_rng(1)
        self.img += (rng.random(self.img.shape[:2], np.float32)[..., None] - 0.5) * amount

    def vignette(self, a=0.55):
        yy, xx = np.mgrid[0:self.H, 0:self.W].astype(np.float32)
        d = np.sqrt(((xx / self.W) - 0.5) ** 2 * 1.4 + ((yy / self.H) - 0.42) ** 2)
        self.img *= (1 - smoothstep(0.3, 0.85, d) * a)[..., None]

    def pixel(self, gw, scale, colors=48, outline=(14, 8, 22), dither=0.06):
        """Conversion en pixel art : grille gw, tramage ordonné, palette limitée, contour 1 px."""
        out = self.img + self.glow
        out = 1 - np.exp(-out * 1.15)
        out = out / (1 - math.exp(-1.15))
        gh = int(round(gw * self.H / self.W))
        im = Image.fromarray((clamp01(out) * 255).astype(np.uint8), "RGB").resize((gw, gh), Image.BOX)
        fg = np.asarray(self.fg.resize((gw, gh), Image.BOX), np.float32) > 110
        a = np.asarray(im, np.float32) / 255.0
        bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 - 0.5
        tile = np.tile(bayer, (gh // 4 + 1, gw // 4 + 1))[:gh, :gw][..., None]
        a = clamp01(a + tile * dither * (~fg)[..., None] + tile * dither * 0.4 * fg[..., None])
        im = Image.fromarray((a * 255).astype(np.uint8), "RGB")
        q = im.quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        arr = np.asarray(q).copy()
        if outline is not None:
            edge = np.zeros_like(fg)
            edge[1:, :] |= fg[:-1, :]
            edge[:-1, :] |= fg[1:, :]
            edge[:, 1:] |= fg[:, :-1]
            edge[:, :-1] |= fg[:, 1:]
            edge &= ~fg
            arr[edge] = outline
        return Image.fromarray(arr).resize((gw * scale, gh * scale), Image.NEAREST)

    def result(self):
        out = self.img + self.glow
        # tonemapping doux pour éviter les blancs brûlés
        out = 1 - np.exp(-out * 1.15)
        out = out / (1 - math.exp(-1.15))
        im = Image.fromarray((clamp01(out) * 255).astype(np.uint8), "RGB")
        return im.resize((int(self.w * OUT), int(self.h * OUT)), Image.LANCZOS)


# ---------------------------------------------------------------------- géométrie
def catmull(pts, steps):
    if len(pts) < 2:
        return pts
    p = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    seg = len(pts) - 1
    per = max(2, steps // seg)
    for i in range(seg):
        p0, p1, p2, p3 = p[i], p[i + 1], p[i + 2], p[i + 3]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(pts[-1])
    return out


def path_len(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def interp(vals, t):
    if isinstance(vals, (int, float)):
        return vals
    if len(vals) == 1:
        return vals[0]
    f = t * (len(vals) - 1)
    i = min(int(f), len(vals) - 2)
    return vals[i] + (vals[i + 1] - vals[i]) * (f - i)


def rot(p, c, a):
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


def polar(cx, cy, r, a):
    return (cx + math.cos(a) * r, cy + math.sin(a) * r)
