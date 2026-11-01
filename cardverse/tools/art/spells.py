"""Illustrations des cartes de sort et de soutien : compositions d'effets."""
import math

from PIL import ImageDraw, ImageFilter

from paint import darken, lighten


def _bolt(p, x0, y0, x1, y1, w=2.0, jag=14, branches=2):
    m = p.mask()
    d = ImageDraw.Draw(m)

    def seg(a, b, w, depth):
        pts = [a]
        n = 9
        for i in range(1, n):
            t = i / n
            pts.append((a[0] + (b[0] - a[0]) * t + p.rng.uniform(-jag, jag), a[1] + (b[1] - a[1]) * t + p.rng.uniform(-jag * 0.3, jag * 0.3)))
        pts.append(b)
        d.line(p.P(pts), fill=255, width=max(1, int(p.S(w))))
        if depth > 0:
            for _ in range(branches):
                s = pts[p.rng.randint(2, n - 2)]
                e = (s[0] + p.rng.uniform(-60, 60), s[1] + p.rng.uniform(20, 80))
                seg(s, e, w * 0.55, depth - 1)

    seg((x0, y0), (x1, y1), w, 2)
    return m


def spell(p, kind, pal):
    g, c1 = pal["glow"], pal["c1"]
    if kind == "firebolt":
        m = p.tube_mask([(40, 260), (110, 200), (180, 140), (230, 100)], [2, 10, 20, 26])
        p.emit(m.filter(ImageFilter.GaussianBlur(6)), (255, 120, 30), 1.0, 12)
        p.fill(p.ellipse_mask(232, 98, 26, 26), (255, 240, 180))
        p.add_glow_mask(p.ellipse_mask(232, 98, 26, 26), (255, 160, 40), 1.4, 20)
        p.particles(60, (255, 190, 80), 30, 260, 60, 280, 0.6, 2.2, 1.0, 4)
    elif kind == "meteor":
        m = p.tube_mask([(20, 0), (120, 70), (190, 130)], [6, 30, 40])
        p.emit(m.filter(ImageFilter.GaussianBlur(10)), (255, 90, 30), 1.0, 18)
        rock = p.ellipse_mask(196, 136, 36, 32, 0.4)
        p.part(rock, (120, 50, 40), (40, 10, 10), rim=(255, 180, 60))
        cr = p.mask()
        ImageDraw.Draw(cr).line(p.P([(180, 120), (200, 140), (190, 160)]), fill=255, width=int(p.S(2)))
        p.emit(cr, (255, 160, 40), 1.4, 4)
        p.particles(80, (255, 160, 60), 60, 280, 60, 260, 0.6, 2.0, 1.0, 3)
    elif kind == "lightning":
        for x in (90, 150, 210):
            p.emit(_bolt(p, x + p.rng.uniform(-20, 20), 0, x + p.rng.uniform(-30, 30), 240, 3, 18), g, 1.6, 10)
        p.radial_glow(150, 240, 90, g, 0.8)
    elif kind == "wave":
        # une vague déferlante en volute
        crest = [(-20, 330), (40, 300), (110, 240), (170, 150), (220, 110), (262, 112), (280, 140), (262, 168), (238, 160), (236, 140)]
        body = crest + [(250, 200), (300, 260), (330, 430), (-20, 430)]
        m = p.poly_mask(body)
        p.part(m, (40, 140, 210), (8, 40, 90), rim=(200, 245, 255), outline=1.2, gloss=0.2)
        inner = p.poly_mask([(10, 360), (70, 320), (130, 260), (180, 190), (215, 160), (230, 200), (250, 260), (300, 330), (320, 430), (0, 430)])
        p.part(inner, (70, 175, 230), (20, 70, 130), rim=(220, 250, 255), outline=0, gloss=0.3)
        foam = p.tube_mask(crest, [6, 7, 8, 9, 10, 9, 7, 5, 3, 2])
        p.part(foam, (240, 250, 255), (160, 210, 235), rim=(255, 255, 255), outline=0.8, gloss=0.5)
        p.particles(70, (230, 250, 255), 140, 300, 60, 200, 0.6, 2.0, 0.8, 3)
    elif kind == "ice_prison":
        for k in range(9):
            x = 80 + k * 18 + p.rng.uniform(-6, 6)
            h = p.rng.uniform(80, 160)
            m = p.poly_mask([(x - 14, 250), (x, 250 - h), (x + 14, 250)])
            p.part(m, (190, 235, 255), (60, 120, 190), rim=(255, 255, 255), outline=1.2, gloss=0.8)
        p.radial_glow(150, 200, 90, (180, 240, 255), 0.6)
        p.particles(50, (240, 250, 255), 40, 260, 60, 260, 0.5, 1.6, 0.8, 3)
    elif kind == "quake":
        m = p.mask()
        d = ImageDraw.Draw(m)
        x = 150
        pts = []
        for y in range(120, 420, 16):
            x += p.rng.uniform(-16, 16)
            pts.append((x, y))
        d.line(p.P(pts), fill=255, width=int(p.S(6)))
        p.emit(m, (255, 150, 60), 1.2, 10)
        for k in range(14):
            cx, cy = p.rng.uniform(40, 260), p.rng.uniform(60, 220)
            r = p.rng.uniform(6, 16)
            p.part(p.poly_mask([(cx - r, cy), (cx - r * 0.3, cy - r), (cx + r, cy - r * 0.4), (cx + r * 0.6, cy + r)]), (150, 110, 80), (60, 40, 30))
    elif kind == "blackhole":
        p.radial_glow(150, 150, 120, (180, 90, 255), 0.6)
        disk = p.ellipse_mask(150, 150, 120, 34, -0.2)
        p.emit(disk.filter(ImageFilter.GaussianBlur(8)), (255, 160, 80), 0.9, 10, core=False)
        p.fill(p.ellipse_mask(150, 150, 44, 44), (0, 0, 0))
        ring = p.ellipse_mask(150, 150, 50, 50)
        ring.paste(0, mask=p.ellipse_mask(150, 150, 45, 45))
        p.emit(ring, (255, 220, 160), 1.4, 6)
        front = p.ellipse_mask(150, 160, 120, 22, -0.2)
        front.paste(0, mask=p.poly_mask([(0, 0), (300, 0), (300, 150), (0, 172)]))
        p.emit(front.filter(ImageFilter.GaussianBlur(4)), (255, 200, 120), 0.9, 8, core=False)
    elif kind == "holy":
        p.rays(150, -20, 10, (255, 245, 200), 0.35, spread=0.4, length=500, seed=3)
        p.radial_glow(150, 200, 80, (255, 240, 190), 0.5)
        for k in range(3):
            m = p.ellipse_mask(150, 260 + k * 8, 70 - k * 18, 12 - k * 3)
            p.emit(m, (255, 230, 150), 0.5, 6)
        m = p.mask()
        d = ImageDraw.Draw(m)
        d.line(p.P([(150, 140), (150, 260)]), fill=255, width=int(p.S(6)))
        d.line(p.P([(115, 180), (185, 180)]), fill=255, width=int(p.S(6)))
        p.emit(m, (255, 240, 180), 1.4, 12)
    elif kind == "blessing":
        for k in range(26):
            a = k / 26 * math.tau
            r = 40 + (k % 5) * 18
            cx, cy = 150 + math.cos(a) * r, 170 + math.sin(a) * r * 0.8
            m = p.ellipse_mask(cx, cy, 9, 4, a)
            p.part(m, (120, 210, 90), (40, 100, 40), rim=(240, 255, 180), outline=0.8)
        p.radial_glow(150, 170, 90, (220, 255, 150), 0.9)
        p.particles(50, (240, 255, 180), 50, 250, 70, 270, 0.6, 1.8, 1.0, 4)
    elif kind == "dark_pact":
        m = p.mask()
        d = ImageDraw.Draw(m)
        d.ellipse(p.P([(70, 90), (230, 250)]), outline=255, width=int(p.S(3)))
        d.ellipse(p.P([(86, 106), (214, 234)]), outline=255, width=int(p.S(1.5)))
        pts = [(150 + math.cos(-math.pi / 2 + k * 4 * math.pi / 5) * 64, 170 + math.sin(-math.pi / 2 + k * 4 * math.pi / 5) * 64) for k in range(6)]
        d.line(p.P(pts), fill=255, width=int(p.S(2)))
        p.emit(m, (230, 60, 140), 1.3, 8)
        heart = p.ellipse_mask(150, 170, 16, 18)
        p.part(heart, (200, 20, 50), (80, 0, 20), rim=(255, 120, 160))
        p.add_glow_mask(heart, (255, 40, 90), 1.0, 12)
    elif kind == "solar":
        p.radial_glow(150, 160, 140, (255, 230, 140), 1.2)
        p.rays(150, 160, 24, (255, 240, 180), 0.8, spread=2.0, length=300, seed=11)
        p.emit(p.ellipse_mask(150, 160, 40, 40), (255, 250, 220), 1.2, 16)


SPELLS = {"firebolt", "meteor", "lightning", "wave", "ice_prison", "quake", "blackhole", "holy", "blessing", "dark_pact", "solar"}
