"""Archétypes complémentaires : bipèdes, volants, aquatiques, végétaux, entités, esprits, sorts."""
import math

from PIL import ImageDraw, ImageFilter

from creatures import _inv, head, mix_c
from paint import catmull, darken, lighten


# ============================================================================ BIPÈDE (humanoïde, démon, golem, mécha, diablotin)
def biped(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    kind = o.get("kind", "humanoid")
    bulk = o.get("bulk", 1.0)
    H = o.get("height", 1.0)
    chibi = kind == "imp"
    hr = (26 if chibi else 23) * o.get("head", 1.0)
    hy = (-40 if chibi else -80) * H
    sh = (-8 if chibi else -50) * H  # épaules
    hip = (22 if chibi else 12) * H
    foot = (60 if chibi else 78) * H
    skin = tuple(o.get("skin", c1))

    gx, gy = R.T(0, foot + 6)
    if not o.get("floating"):
        p.shadow(gx, gy, R.r(60 * bulk), R.r(8), 0.45)
    else:
        p.shadow(gx, gy + R.r(20), R.r(40), R.r(6), 0.3)

    # aura / halo derrière
    if o.get("halo"):
        hm = R.ell(0, hy - 6, hr * 2.0, hr * 2.0)
        inner = R.ell(0, hy - 6, hr * 1.7, hr * 1.7)
        hm.paste(0, mask=inner)
        p.emit(hm, o.get("halo_c", pal["glow"]), 0.6, 6)
    if o.get("aura"):
        p.radial_glow(*R.T(0, (hy + foot) / 2), R.r(120), pal["glow"], 0.28)
    # ailes
    wings = o.get("wings")
    if wings:
        for side in (-1, 1):
            if wings == "feather":
                feather_wing(R, side, (side * 12 * bulk, sh + 8), o.get("wing_span", 1.0), tuple(o.get("wing_c", (255, 255, 255))), o.get("wing_glow"))
            else:  # chauve-souris
                span = o.get("wing_span", 1.0)
                b = (side * 14 * bulk, sh + 4)
                tips = [(side * 60 * span, sh - 70 * span), (side * 100 * span, sh - 40 * span), (side * 110 * span, sh + 10 * span), (side * 80 * span, sh + 40 * span)]
                memc = o.get("membrane", darken(c1, 0.15))
                R.paint(R.poly([b] + tips + [(side * 20, sh + 40)]), memc, darken(memc, 0.6), gloss=0)
                for t in tips:
                    R.paint(R.tube([b, t], [5, 1.5]), darken(c1, 0.3))
    # queue (démon)
    if o.get("tail"):
        R.paint(R.tube([(8, hip), (40, hip + 30), (60, hip - 4), (48, hip - 30)], [7, 5, 3, 1.5]), skin)
        R.paint(R.poly([(44, hip - 30), (56, hip - 44), (54, hip - 24)]), c3)
    # jambes
    if kind in ("humanoid", "deity") and o.get("robe", True):
        pass
    else:
        for side in (-1, 1):
            lx = side * 14 * bulk
            if kind == "golem" or kind == "mech":
                R.paint(R.poly([(lx - 11 * bulk, hip), (lx + 11 * bulk, hip), (lx + 13 * bulk, foot), (lx - 13 * bulk, foot)]), c1 if side < 0 else darken(c1, 0.15))
                R.paint(R.poly([(lx - 16 * bulk, foot - 6), (lx + 16 * bulk, foot - 6), (lx + 18 * bulk, foot + 6), (lx - 18 * bulk, foot + 6)]), darken(c1, 0.3))
            else:
                R.paint(R.tube([(lx, hip), (lx + side * 4, (hip + foot) / 2), (lx + side * 2, foot)], [11 * bulk, 8 * bulk, 7 * bulk]), skin)
                R.paint(R.ell(lx + side * 4, foot + 2, 10 * bulk, 5 * bulk), darken(skin, 0.3))
    # torse
    if kind == "golem":
        R.paint(R.poly([(-36 * bulk, sh), (36 * bulk, sh - 4), (26 * bulk, hip + 4), (-26 * bulk, hip + 6)]), c1)
        # cristaux
        for (x, y, h) in o.get("crystals", [(-10, sh + 18, 22), (12, sh + 26, 16)]):
            m = R.poly([(x - 6, y), (x, y - h), (x + 6, y), (x, y + 6)])
            R.paint(m, pal["glow"], gloss=0.6)
            p.add_glow_mask(m, pal["glow"], 0.5, 5)
    elif kind == "mech":
        R.paint(R.poly([(-34 * bulk, sh), (34 * bulk, sh), (24 * bulk, hip), (-24 * bulk, hip)]), c1, gloss=0.5)
        core = R.ell(0, (sh + hip) / 2, 10, 10)
        p.emit(core, pal["glow"], 1.2, 8)
        for side in (-1, 1):
            R.paint(R.poly([(side * 30 * bulk, sh - 10), (side * 52 * bulk, sh - 6), (side * 50 * bulk, sh + 18), (side * 30 * bulk, sh + 16)]), c3, gloss=0.5)
    elif kind in ("humanoid", "deity") and o.get("robe", True):
        robe = o.get("robe_c", c2)
        R.paint(R.poly([(-16 * bulk, sh), (16 * bulk, sh), (40 * bulk, foot + 4), (-40 * bulk, foot + 4)]), robe)
        R.paint(R.poly([(-6, sh + 4), (6, sh + 4), (14, foot + 4), (-14, foot + 4)]), lighten(robe, 0.25))
        if o.get("trim"):
            R.paint(R.poly([(-40 * bulk, foot - 4), (40 * bulk, foot - 4), (40 * bulk, foot + 4), (-40 * bulk, foot + 4)]), o["trim"], gloss=0.6)
        R.paint(R.ell(0, sh + 10, 20 * bulk, 16), o.get("armor", c1))
    else:
        R.paint(R.ell(0, (sh + hip) / 2, 24 * bulk, (hip - sh) / 2 + 6), skin)
        if kind == "demon":
            R.paint(R.ell(-8 * bulk, sh + 14, 9 * bulk, 8), lighten(skin, 0.1), gloss=0.1)
            R.paint(R.ell(8 * bulk, sh + 14, 9 * bulk, 8), lighten(skin, 0.1), gloss=0.1)
    # bras
    weapon = o.get("weapon")
    for side in (-1, 1):
        ax = side * 26 * bulk
        if kind in ("golem", "mech"):
            R.paint(R.tube([(ax, sh + 2), (ax + side * 16, sh + 30), (ax + side * 14, sh + 56)], [13 * bulk, 11 * bulk, 10 * bulk]), c1 if side > 0 else darken(c1, 0.1))
            R.paint(R.ell(ax + side * 14, sh + 62, 15 * bulk, 13 * bulk), c3 if kind == "mech" else darken(c1, 0.2))
        else:
            arm = o.get("arm_c", skin if kind not in ("humanoid", "deity") else o.get("robe_c", c2))
            pose = o.get("pose", "idle")
            if pose == "raise" and side == 1:
                pts = [(ax, sh + 4), (ax + 16, sh - 14), (ax + 18, sh - 44)]
            else:
                pts = [(ax, sh + 4), (ax + side * 10, sh + 26), (ax + side * 6, sh + 50)]
            R.paint(R.tube(pts, [9 * bulk, 7 * bulk, 6 * bulk]), arm)
            hand = pts[-1]
            R.paint(R.ell(hand[0], hand[1], 6, 6), skin if kind not in ("humanoid", "deity") else o.get("skin_h", (240, 205, 180)))
            if side == 1 and weapon:
                _weapon(R, weapon, hand)
            if side == -1 and o.get("orb_hand"):
                m = R.ell(hand[0] - 4, hand[1] - 10, 9, 9)
                p.emit(m, pal["glow"], 1.3, 10)
    # tête
    hc = tuple(o.get("head_c", skin if kind not in ("humanoid", "deity") else o.get("skin_h", (240, 205, 180))))
    if kind == "mech":
        R.paint(R.poly([(-22, hy - 16), (22, hy - 16), (19, hy + 18), (-19, hy + 18)]), c1, gloss=0.6)
        visor = R.poly([(-17, hy - 3), (17, hy - 3), (14, hy + 7), (-14, hy + 7)])
        p.emit(visor, pal["eye"], 1.2, 6)
        R.paint(R.tube([(10, hy - 12), (16, hy - 30)], [2, 1]), c3)
        p.emit(R.ell(16, hy - 31, 3, 3), pal["eye"], 1, 4)
    elif kind == "golem":
        R.paint(R.poly([(-20, hy - 12), (16, hy - 18), (22, hy + 12), (-16, hy + 18)]), darken(c1, 0.05))
        R.paint(R.poly([(-22, hy - 4), (24, hy - 8), (22, hy - 2), (-22, hy + 2)]), darken(c1, 0.25), outline=0.6)
        p.emit(R.ell(-8, hy + 4, 4, 3), pal["eye"], 1.3, 5)
        p.emit(R.ell(9, hy + 3, 4, 3), pal["eye"], 1.3, 5)
    else:
        if o.get("hair"):
            hair = tuple(o["hair"])
            R.paint(R.poly([(-hr * 1.05, hy - hr * 0.2), (hr * 1.05, hy - hr * 0.2), (hr * 1.35, hy + hr * 2.4), (0, hy + hr * 2.0), (-hr * 1.35, hy + hr * 2.4)]), hair)
            R.paint(R.ell(0, hy - hr * 0.15, hr * 1.12, hr * 1.1), hair)
        if o.get("hood"):
            R.paint(R.poly([(-hr * 1.4, hy + hr), (0, hy - hr * 1.8), (hr * 1.4, hy + hr), (hr, hy + hr * 1.6), (-hr, hy + hr * 1.6)]), tuple(o["hood"]))
        R.paint(R.ell(0, hy + hr * 0.1, hr * 0.92, hr * 0.98), hc)
        if o.get("hair"):
            bang = R.ell(0, hy - hr * 0.62, hr * 1.0, hr * 0.5)
            R.paint(bang, tuple(o["hair"]), outline=0.8)
        if o.get("hood"):
            R.p.fill(R.ell(0, hy + 2, hr * 0.8, hr * 0.85), (10, 6, 16), 0.85)
            p.emit(R.ell(-5, hy + 1, 2.5, 1.6), pal["eye"], 1.4, 4)
            p.emit(R.ell(5, hy + 1, 2.5, 1.6), pal["eye"], 1.4, 4)
        elif chibi or o.get("eyes_style") == "cute":
            R.eye(-hr * 0.38, hy + 2, hr * 0.26, cute=True)
            R.eye(hr * 0.38, hy + 2, hr * 0.26, cute=True)
            R.p.fill(R.ell(0, hy + hr * 0.5, hr * 0.22, hr * 0.12), (60, 20, 30))
        elif kind in ("humanoid", "deity"):
            for side in (-1, 1):
                ex, ey = side * hr * 0.36, hy + hr * 0.12
                R.p.fill(R.ell(ex, ey, hr * 0.22, hr * 0.17), (250, 250, 255))
                iris = R.ell(ex, ey + hr * 0.02, hr * 0.13, hr * 0.15)
                R.p.fill(iris, pal["eye"])
                R.p.add_glow_mask(iris, pal["eye"], 0.5, 3)
                R.p.fill(R.ell(ex - hr * 0.04, ey - hr * 0.04, hr * 0.05, hr * 0.05), (255, 255, 255))
                R.p.fill(R.poly([(ex - side * hr * 0.24, ey - hr * 0.22), (ex + side * hr * 0.22, ey - hr * 0.26), (ex + side * hr * 0.2, ey - hr * 0.2)]), (40, 25, 30))
            R.p.fill(R.ell(0, hy + hr * 0.62, hr * 0.14, hr * 0.06), (170, 80, 90))
        else:
            R.eye(-hr * 0.38, hy, hr * 0.24)
            R.eye(hr * 0.38, hy, hr * 0.24)
        if o.get("horns"):
            for side in (-1, 1):
                R.paint(R.tube([(side * hr * 0.6, hy - hr * 0.7), (side * hr * 1.3, hy - hr * 1.5), (side * hr * 1.1, hy - hr * 2.4)], [5, 3.5, 1]), c3)
        if o.get("crown"):
            pts = [(-hr * 0.9, hy - hr * 0.8)]
            for k in range(5):
                x = -hr * 0.9 + k * hr * 0.45
                pts += [(x + hr * 0.22, hy - hr * (1.6 if k % 2 == 0 else 1.3)), (x + hr * 0.45, hy - hr * 0.9)]
            m = R.poly(pts + [(hr * 0.9, hy - hr * 0.6), (-hr * 0.9, hy - hr * 0.6)])
            R.paint(m, tuple(o["crown"]), gloss=0.7)
            p.add_glow_mask(m, tuple(o["crown"]), 0.4, 4)


def feather_wing(R, side, base, span=1.0, c=(255, 255, 255), glow=False, raise_=1.0):
    """Aile d'oiseau / d'ange : silhouette, rangées de couvertures et rémiges festonnées."""
    p = R.p
    bx, by = base
    sx = side
    tip = (bx + sx * 118 * span, by - 92 * span * raise_)
    elbow = (bx + sx * 52 * span, by - 62 * span * raise_)
    dark = darken(c, 0.4)
    # rémiges (grandes plumes) le long du bord de fuite
    n = 9
    for k in range(n):
        t = k / (n - 1)
        ax = elbow[0] + (tip[0] - elbow[0]) * (1 - t) * 0.9 + (bx - elbow[0]) * t * 0.6
        ay = elbow[1] + (tip[1] - elbow[1]) * (1 - t) * 0.9 + (by + 10 - elbow[1]) * t * 0.6
        L = (70 - 40 * t) * span
        ang = math.atan2(1.0, sx * (1.2 - t * 1.0))
        ex, ey = ax + math.cos(ang) * L * 0.35 * sx * 0 + sx * L * (0.5 - 0.4 * t), ay + L * (0.55 + 0.4 * t)
        m = R.tube([(ax, ay), ((ax + ex) / 2, (ay + ey) / 2), (ex, ey)], [7 * span, 7 * span, 2.5])
        R.paint(m, lighten(c, 0.02 * k) if k % 2 else darken(c, 0.08), dark, outline=1.0)
        if glow:
            p.add_glow_mask(m, R.pal["glow"], 0.18, 6)
    # membrane / os de l'aile
    arm = R.tube([(bx, by), elbow, tip], [11 * span, 8 * span, 3])
    R.paint(arm, c, dark)
    # couvertures (petites plumes arrondies)
    for row in range(2):
        for k in range(6):
            t = k / 5
            x = bx + (tip[0] - bx) * (0.15 + 0.6 * t)
            y = by + (tip[1] - by) * (0.15 + 0.6 * t) + 10 + row * 10
            R.paint(R.ell(x, y, 9 * span, 6 * span, 0.5 * sx), lighten(c, 0.12) if row == 0 else c, dark, outline=0.8)


def _weapon(R, w, hand):
    p, pal = R.p, R.pal
    x, y = hand
    if w == "sword":
        m = R.poly([(x - 3, y - 6), (x + 3, y - 6), (x + 2, y - 80), (x, y - 88), (x - 2, y - 80)])
        R.paint(m, (230, 235, 250), gloss=0.8)
        p.add_glow_mask(m, pal["glow"], 0.5, 6)
        R.paint(R.poly([(x - 12, y - 6), (x + 12, y - 6), (x + 12, y - 2), (x - 12, y - 2)]), (240, 200, 90))
    elif w == "staff":
        R.paint(R.tube([(x, y + 40), (x, y), (x + 2, y - 70)], [3, 3, 3]), (120, 80, 50))
        m = R.ell(x + 2, y - 78, 9, 9)
        p.emit(m, pal["glow"], 1.4, 12)
    elif w == "scythe":
        R.paint(R.tube([(x - 6, y + 40), (x, y), (x + 4, y - 70)], [3, 3, 3]), (60, 50, 60))
        R.paint(R.poly([(x + 4, y - 70), (x - 50, y - 60), (x - 70, y - 40), (x - 40, y - 52), (x + 4, y - 62)]), (210, 220, 235), gloss=0.7)
    elif w == "daggers":
        for dx in (0, -60):
            m = R.poly([(x + dx - 2, y), (x + dx + 2, y), (x + dx + 1, y - 30), (x + dx, y - 34)])
            R.paint(m, (200, 210, 230), gloss=0.8)
            p.add_glow_mask(m, pal["glow"], 0.6, 4)


# ============================================================================ OISEAU
def bird(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    span = o.get("wing_span", 1.0)
    flame = o.get("flame")
    # queue en éventail
    for k in range(7):
        a = math.pi / 2 + (k - 3) * 0.16
        L = 100 * o.get("tail", 1.0) * (1 - abs(k - 3) * 0.08)
        m = R.tube([(0, 26), (math.cos(a) * L * 0.5, 26 + math.sin(a) * L * 0.5), (math.cos(a) * L, 26 + math.sin(a) * L)], [7, 9, 3])
        R.paint(m, c2 if k % 2 else c1)
        if flame:
            p.add_glow_mask(m, pal["glow"], 0.4, 10)
    for side in (-1, 1):
        feather_wing(R, side, (side * 14, -14), span, c1, flame or o.get("wing_glow"), 1.05)
    R.paint(R.ell(0, 6, 28, 38), c1)
    R.paint(R.ell(-4, 16, 18, 24), c2, outline=0.8)
    for k in range(4):  # plumes du poitrail
        R.paint(R.ell(-4, 0 + k * 10, 12 - k, 5), lighten(c2, 0.1), outline=0.6)
    R.paint(R.tube([(0, -20), (-6, -40), (-8, -52)], [17, 15, 14]), c1)
    hx, hy = -8, -60
    R.paint(R.ell(hx, hy, 19, 17), c1)
    for k in range(5):  # crête
        R.paint(R.tube([(hx + 6, hy - 10), (hx + 18 + k * 7, hy - 34 - k * 4), (hx + 26 + k * 10, hy - 42 + k * 3)], [5, 3.5, 1]), c3 if k % 2 else c2)
        if flame:
            p.add_glow_mask(R.ell(hx + 22 + k * 8, hy - 38, 6, 6), pal["glow"], 0.6, 6)
    R.paint(R.poly([(hx - 16, hy - 4), (hx - 40, hy + 6), (hx - 22, hy + 6), (hx - 14, hy + 10)]), (250, 205, 90), gloss=0.5)
    R.eye(hx - 4, hy - 4, 5)
    for side in (-1, 1):  # serres
        for k in range(3):
            R.paint(R.tube([(side * 10, 40), (side * 10 + (k - 1) * 6, 54)], [3, 1.5]), (60, 50, 40), outline=0.6)
    if flame:
        p.radial_glow(*R.T(0, -10), R.r(120), pal["glow"], 0.35)
    if o.get("sparks"):
        m = p.mask()
        d = ImageDraw.Draw(m)
        for k in range(4):
            x0, y0 = R.T(-100 + k * 66, -70)
            pts = [(x0, y0)]
            for j in range(5):
                pts.append((pts[-1][0] + p.rng.uniform(-8, 8), pts[-1][1] + R.r(12)))
            d.line(p.P(pts), fill=255, width=int(p.S(1.5)))
        p.emit(m, pal["glow"], 1.0, 6)


# ============================================================================ POISSON
def fish(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    L = o.get("length", 1.0)
    R.paint(R.poly([(50 * L, 0), (90 * L, -34), (82 * L, 0), (90 * L, 34)]), c3)
    R.paint(R.poly([(-10, -30), (20, -64 * o.get("fin", 1.0)), (40, -26)]), c3)
    R.paint(R.ell(0, 0, 60 * L, 38), c1)
    R.paint(R.ell(-6, 14, 44 * L, 18), c2)
    R.paint(R.poly([(0, 12), (24, 40), (26, 14)]), c3)
    if o.get("feathers"):
        for k in range(3):
            R.paint(R.tube([(-30, -28), (-34 - k * 8, -56 - k * 4)], [5, 2]), tuple(o["feathers"]))
    if o.get("lure"):
        R.paint(R.tube([(-40, -30), (-60, -70), (-84, -64)], [2.5, 2, 1.5]), c3)
        p.emit(R.ell(-86, -60, 7, 7), pal["glow"], 1.6, 14)
    R.eye(-34, -6, 10 if o.get("eyes_style") == "cute" else 7, cute=o.get("eyes_style") == "cute")
    if o.get("teeth"):
        for k in range(5):
            x = -58 + k * 6
            R.paint(R.poly([(x, 10), (x + 3, 20), (x + 6, 10)]), (250, 250, 240), outline=0.6)
    p.particles(12, (200, 245, 255), *R.T(-90, -60), *R.T(-60, 40)) if False else None


# ============================================================================ MÉDUSE
def jelly(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2 = pal["c1"], pal["c2"]
    n = o.get("tentacles", 7)
    for k in range(n):
        x = -40 + k * 80 / (n - 1)
        pts = [(x, 0)]
        for j in range(1, 6):
            pts.append((x + math.sin(j * 1.3 + k) * 12, j * 26 * o.get("length", 1.0)))
        m = R.tube(pts, [6, 4, 3, 2, 1, 0.5])
        R.paint(m, c2, outline=0.8)
        p.add_glow_mask(m, pal["glow"], 0.35, 6)
    dome = R.ell(0, -10, 58, 46)
    lower = R.poly([(-70, 0), (70, 0), (70, 60), (-70, 60)])
    dome.paste(0, mask=lower)
    R.paint(dome, c1, gloss=0.5, a=0.92)
    p.add_glow_mask(dome, pal["glow"], 0.5, 18)
    R.paint(R.ell(0, -14, 26, 20), lighten(c1, 0.3), gloss=0.4, a=0.7)
    if o.get("stars"):
        p.particles(18, (255, 255, 255), *R.T(-40, -45), *R.T(40, -5), 0.4, 1.2, 1.0, 2)
    if o.get("eyes_style") == "cute":
        R.eye(-14, -18, 7, cute=True)
        R.eye(14, -18, 7, cute=True)
    elif o.get("big_eye"):
        R.eye(0, -16, 9)


# ============================================================================ KRAKEN
def kraken(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2 = pal["c1"], pal["c2"]
    for k in range(8):
        a = math.pi * (0.1 + 0.8 * k / 7)
        sx = math.cos(a) * 30
        pts = [(sx, 20)]
        for j in range(1, 6):
            r = j * 26
            pts.append((math.cos(a) * r * 1.4 + math.sin(j + k) * 18, 20 + math.sin(a) * r * 0.6 + j * 6 - (j > 3) * 30))
        m = R.tube(pts, [16, 13, 10, 7, 4, 1.5])
        R.paint(m, c1 if k % 2 else darken(c1, 0.15))
        for j in range(1, 5):
            x, y = pts[j]
            R.paint(R.ell(x, y + 6, 3.5, 2.5), c2, outline=0.5)
    R.paint(R.ell(0, -30, 46, 62, 0.1), c1)
    R.paint(R.ell(-10, -50, 14, 20, 0.2), lighten(c1, 0.15), gloss=0.4)
    for x in (-18, 18):
        R.eye(x, 4, 8, slit=True)


# ============================================================================ CRABE
def crab(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    for side in (-1, 1):
        for k in range(3):
            bx = side * (30 + k * 10)
            R.paint(R.tube([(bx, 20), (bx + side * 26, 6), (bx + side * 36, 46)], [7, 5, 2]), darken(c1, 0.2))
    for side in (-1, 1):
        R.paint(R.tube([(side * 40, 0), (side * 64, -30), (side * 70, -56)], [9, 8, 8]), c1)
        cl = (side * 76, -78)
        R.paint(R.ell(cl[0], cl[1], 24, 18, side * 0.4), c1)
        R.paint(R.poly([(cl[0] - side * 4, cl[1] - 10), (cl[0] + side * 26, cl[1] - 34), (cl[0] + side * 12, cl[1] - 6)]), c1)
    shell = R.ell(0, 10, 66, 40)
    R.paint(shell, c1, gloss=0.4)
    if o.get("fortress"):
        for x in (-34, -12, 10, 32):
            R.paint(R.poly([(x - 8, -22), (x + 8, -22), (x + 8, -42), (x - 8, -42)]), c3)
            R.paint(R.poly([(x - 9, -42), (x - 3, -42), (x - 3, -48), (x - 9, -48)]), c3)
            R.paint(R.poly([(x + 3, -42), (x + 9, -42), (x + 9, -48), (x + 3, -48)]), c3)
        R.paint(R.poly([(-40, -24), (40, -24), (52, 0), (-52, 0)]), lighten(c3, 0.1))
    for x in (-14, 14):
        R.paint(R.tube([(x, -14), (x, -30)], [3, 3]), c1)
        R.eye(x, -34, 6, cute=o.get("eyes_style") == "cute")


# ============================================================================ PLANTE / TRÉANT
def plant(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    kind = o.get("kind", "flower")
    gx, gy = R.T(0, 82)
    p.shadow(gx, gy, R.r(60), R.r(8), 0.4)
    if kind == "treant":
        for side in (-1, 1):
            R.paint(R.tube([(side * 14, 60), (side * 40, 80), (side * 60, 86)], [14, 9, 4]), (100, 70, 45))
        R.paint(R.poly([(-34, 80), (34, 80), (26, -40), (-26, -40)]), (120, 84, 52))
        for side in (-1, 1):
            R.paint(R.tube([(side * 20, -20), (side * 56, -50), (side * 80, -90)], [12, 8, 3]), (110, 76, 48))
        canopy = [(0, -110, 60, 40), (-50, -80, 40, 32), (50, -84, 42, 30), (0, -70, 50, 30)]
        for (x, y, rx, ry) in canopy:
            R.paint(R.ell(x, y, rx, ry), c1, gloss=0.2)
        for k in range(12):
            x, y = p.rng.uniform(-70, 70), p.rng.uniform(-130, -60)
            m = R.ell(x, y, 3, 3)
            p.emit(m, tuple(o.get("bloom", c2)), 0.8, 4)
        p.fill(R.ell(-10, 4, 7, 9), (20, 10, 6))
        p.fill(R.ell(12, 4, 7, 9), (20, 10, 6))
        p.emit(R.ell(-10, 4, 3, 4), pal["eye"], 1.4, 5)
        p.emit(R.ell(12, 4, 3, 4), pal["eye"], 1.4, 5)
        p.fill(R.poly([(-14, 28), (14, 26), (10, 38), (-10, 38)]), (20, 10, 6))
        return
    if kind == "carnivore":
        R.paint(R.tube([(0, 80), (-10, 40), (14, 0), (0, -30)], [10, 9, 8, 7]), (60, 130, 60))
        for side in (-1, 1):
            R.paint(R.tube([(0, 60), (side * 40, 50), (side * 60, 30)], [5, 6, 2]), c1)
        top = R.ell(0, -60, 50, 24, -0.15)
        R.paint(top, c1)
        bot = R.ell(4, -24, 46, 20, 0.15)
        R.paint(bot, c1)
        R.paint(R.ell(2, -42, 40, 12), (120, 20, 40), gloss=0)
        for k in range(8):
            x = -34 + k * 9
            R.paint(R.poly([(x, -52), (x + 4, -40), (x + 8, -52)]), (250, 245, 220), outline=0.6)
            R.paint(R.poly([(x, -32), (x + 4, -44), (x + 8, -32)]), (250, 245, 220), outline=0.6)
        for k in range(6):
            x = -40 + k * 16
            R.paint(R.ell(x, -70, 4, 4), c2, outline=0.6)
        return
    # fleur mignonne / majestueuse
    big = o.get("big", 1.0)
    R.paint(R.tube([(0, 80), (6, 40), (0, 10)], [6 * big, 6 * big, 6 * big]), (70, 140, 60))
    for side in (-1, 1):
        R.paint(R.ell(side * 22 * big, 52, 22 * big, 9 * big, side * -0.5), (90, 170, 70))
    n = o.get("petals", 6)
    for k in range(n):
        a = k / n * math.tau
        R.paint(R.ell(math.cos(a) * 30 * big, -14 + math.sin(a) * 30 * big, 22 * big, 14 * big, a), c1, gloss=0.25)
    if o.get("petals2"):
        for k in range(n):
            a = (k + 0.5) / n * math.tau
            R.paint(R.ell(math.cos(a) * 46 * big, -14 + math.sin(a) * 46 * big, 22 * big, 12 * big, a), tuple(o["petals2"]), gloss=0.25)
    R.paint(R.ell(0, -14, 24 * big, 24 * big), c2, gloss=0.3)
    R.eye(-9 * big, -18, 5 * big, cute=True)
    R.eye(9 * big, -18, 5 * big, cute=True)
    p.fill(R.ell(0, -6, 5 * big, 3 * big), (110, 40, 40))
    p.fill(R.ell(-16 * big, -8, 5, 3), (255, 120, 140), 0.5)
    p.fill(R.ell(16 * big, -8, 5, 3), (255, 120, 140), 0.5)
    if o.get("glow_petals"):
        p.radial_glow(*R.T(0, -14), R.r(80), pal["glow"], 0.5)


# ============================================================================ INSECTE (mante)
def insect(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    for side in (-1, 1):
        for k in range(2):
            bx = 10 + k * 20
            R.paint(R.tube([(bx, 20), (bx + side * 30, 40), (bx + side * 36, 76)], [4, 3, 2]), darken(c1, 0.2))
    if o.get("wings", True):
        for k in range(2):
            m = R.ell(40 + k * 8, -10 - k * 6, 50, 14, -0.4 - k * 0.2)
            R.paint(m, lighten(c2, 0.4), outline=0.8, a=0.55, gloss=0.6)
    R.paint(R.ell(46, 14, 40, 16, 0.25), c1)
    R.paint(R.tube([(10, 10), (-10, -20), (-18, -52)], [12, 10, 8]), c1)
    for side in (-1, 1):
        R.paint(R.tube([(-14, -30), (-40, -20 + side * 6), (-56, -50 + side * 6)], [6, 5, 3]), c1)
        R.paint(R.poly([(-56, -50 + side * 6), (-46, -94 + side * 6), (-50, -46 + side * 6)]), c3, gloss=0.7)
    R.paint(R.poly([(-36, -70), (-6, -70), (-20, -46)]), c1)
    R.eye(-30, -66, 6)
    R.eye(-12, -66, 6)
    R.paint(R.tube([(-26, -74), (-34, -110)], [1.5, 0.8]), c1, outline=0.5)
    R.paint(R.tube([(-18, -74), (-8, -110)], [1.5, 0.8]), c1, outline=0.5)
    if o.get("poison"):
        p.emit(R.ell(-50, -96, 4, 4), (140, 255, 90), 1.3, 6)


# ============================================================================ ORBE / ŒIL / PLANÉTOÏDE
def orb(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    r = 50 * o.get("size", 1.0)
    if o.get("tentacles"):
        for k in range(o["tentacles"]):
            a = k / o["tentacles"] * math.tau + 0.3
            pts = [(math.cos(a) * r * 0.8, math.sin(a) * r * 0.8)]
            for j in range(1, 5):
                pts.append((math.cos(a + j * 0.25) * (r + j * 26), math.sin(a + j * 0.25) * (r + j * 26)))
            m = R.tube(pts, [10, 7, 5, 3, 1])
            R.paint(m, darken(c1, 0.2))
            p.add_glow_mask(m, pal["glow"], 0.15, 6)
    if o.get("ring"):
        back = R.ell(0, 0, r * 1.9, r * 0.45, -0.25)
        hole = R.ell(0, 0, r * 1.5, r * 0.3, -0.25)
        back.paste(0, mask=hole)
        top = R.poly([(-200, -200), (200, -200), (200, 0), (-200, 0)]) if False else None
        p.emit(back, tuple(o.get("ring_c", c3)), 0.6, 4)
    body = R.ell(0, 0, r, r)
    R.paint(body, c1, gloss=0.4)
    p.add_glow_mask(body, pal["glow"], 0.3, 18)
    if o.get("craters"):
        for k in range(5):
            x, y = p.rng.uniform(-r * 0.6, r * 0.6), p.rng.uniform(-r * 0.6, r * 0.6)
            R.paint(R.ell(x, y, r * 0.12, r * 0.1), darken(c1, 0.25), outline=0, gloss=0)
    style = o.get("face", "eye")
    if style == "eye":
        R.paint(R.ell(0, 0, r * 0.72, r * 0.5), (245, 240, 235), gloss=0.5)
        iris = R.ell(0, 0, r * 0.38, r * 0.38)
        p.emit(iris, pal["eye"], 1.0, 8)
        R.paint(iris, pal["eye"], outline=0.8, gloss=0.5)
        p.fill(R.ell(0, 0, r * 0.1, r * 0.3), (5, 0, 10))
        p.fill(R.ell(-r * 0.12, -r * 0.14, r * 0.07, r * 0.07), (255, 255, 255))
        for side in (-1, 1):  # paupières
            lid = R.ell(0, side * r * 0.62, r * 0.9, r * 0.32)
            R.paint(lid, darken(c1, 0.1), outline=0.8)
    elif style == "cute":
        R.eye(-r * 0.3, -r * 0.05, r * 0.16, cute=True)
        R.eye(r * 0.3, -r * 0.05, r * 0.16, cute=True)
        p.fill(R.ell(0, r * 0.25, r * 0.12, r * 0.06), (90, 30, 40))
    if o.get("ring"):
        front = R.ell(0, 0, r * 1.9, r * 0.45, -0.25)
        hole = R.ell(0, 0, r * 1.5, r * 0.3, -0.25)
        front.paste(0, mask=hole)
        cut = R.poly([(-300, -300), (300, -300), (300, -70), (-300, 70)])  # moitié arrière cachée
        front.paste(0, mask=cut)
        p.emit(front, tuple(o.get("ring_c", c3)), 0.8, 4)
    if o.get("orbiters"):
        for k in range(o["orbiters"]):
            a = k / o["orbiters"] * math.tau
            m = R.ell(math.cos(a) * r * 1.6, math.sin(a) * r * 1.1, 6, 6)
            p.emit(m, pal["glow"], 1.0, 6)


# ============================================================================ ESPRIT (feu follet, fantôme, flocon)
def spirit(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2 = pal["c1"], pal["c2"]
    kind = o.get("kind", "ghost")
    sz = o.get("size", 1.0)
    p.radial_glow(*R.T(0, 0), R.r(90 * sz), pal["glow"], 0.45)
    if kind == "ghost":
        R.paint(R.tube([(0, -10), (14, 40), (-10, 70), (16, 100)], [40 * sz, 30 * sz, 16 * sz, 3]), c1, a=0.85, gloss=0.3)
        for side in (-1, 1):
            R.paint(R.tube([(side * 30 * sz, 0), (side * 56 * sz, 20), (side * 60 * sz, 44)], [10, 6, 2]), c1, a=0.85)
        R.paint(R.ell(0, -24, 40 * sz, 40 * sz), c1, a=0.9, gloss=0.3)
        p.fill(R.ell(-14 * sz, -26, 8 * sz, 11 * sz), (10, 4, 20))
        p.fill(R.ell(14 * sz, -26, 8 * sz, 11 * sz), (10, 4, 20))
        p.emit(R.ell(-14 * sz, -24, 3 * sz, 4 * sz), pal["eye"], 1.4, 5)
        p.emit(R.ell(14 * sz, -24, 3 * sz, 4 * sz), pal["eye"], 1.4, 5)
        p.fill(R.ell(0, -2, 10 * sz, 6 * sz), (10, 4, 20))
    elif kind == "flame":
        for k in range(5):
            a = -math.pi / 2 + (k - 2) * 0.35
            m = R.tube([(0, 10), (math.cos(a) * 30 * sz, -20), (math.cos(a) * 20 * sz, -70 * sz + abs(k - 2) * 12)], [30 * sz, 16 * sz, 2])
            R.paint(m, c1 if k % 2 else c2, outline=1, gloss=0.2)
            p.add_glow_mask(m, c2, 0.3, 8)
        body = R.ell(0, 10, 32 * sz, 32 * sz)
        R.paint(body, c1, outline=1, gloss=0.4)
        R.eye(-10 * sz, 8, 6 * sz, cute=True)
        R.eye(10 * sz, 8, 6 * sz, cute=True)
        p.fill(R.ell(0, 22, 5 * sz, 3 * sz), (90, 20, 20))
    elif kind == "snow":
        for k in range(6):
            a = k / 6 * math.tau
            m = R.tube([(0, 0), (math.cos(a) * 60 * sz, math.sin(a) * 60 * sz)], [5, 2])
            R.paint(m, (230, 245, 255), outline=0.8)
            for j in (0.5, 0.75):
                bx, by = math.cos(a) * 60 * sz * j, math.sin(a) * 60 * sz * j
                for d in (-0.6, 0.6):
                    R.paint(R.tube([(bx, by), (bx + math.cos(a + d) * 14, by + math.sin(a + d) * 14)], [2.5, 1]), (230, 245, 255), outline=0.6)
        R.paint(R.ell(0, 0, 30 * sz, 30 * sz), (240, 250, 255), gloss=0.5)
        R.eye(-10 * sz, -2, 6 * sz, cute=True)
        R.eye(10 * sz, -2, 6 * sz, cute=True)
        p.fill(R.ell(-18, 8, 5, 3), (255, 150, 180), 0.6)
        p.fill(R.ell(18, 8, 5, 3), (255, 150, 180), 0.6)
    elif kind == "light":
        for side in (-1, 1):
            m = R.ell(side * 30 * sz, -16, 30 * sz, 14 * sz, side * 0.5)
            R.paint(m, (255, 255, 240), outline=0.8, a=0.6, gloss=0.6)
        body = R.ell(0, 0, 24 * sz, 26 * sz)
        p.emit(body, c1, 1.0, 16)
        R.eye(-8 * sz, -2, 5 * sz, cute=True)
        R.eye(8 * sz, -2, 5 * sz, cute=True)
    elif kind == "spark":
        m = p.mask()
        d = ImageDraw.Draw(m)
        for k in range(8):
            a = k / 8 * math.tau
            pts = [R.T(0, 0)]
            for j in range(1, 4):
                pts.append(R.T(math.cos(a) * j * 22 + p.rng.uniform(-8, 8), math.sin(a) * j * 22 + p.rng.uniform(-8, 8)))
            d.line(p.P(pts), fill=255, width=int(p.S(2)))
        p.emit(m, pal["glow"], 1.2, 6)
        body = R.ell(0, 0, 28 * sz, 28 * sz)
        R.paint(body, c1, outline=1, gloss=0.6)
        R.eye(-9 * sz, -2, 6 * sz, cute=True)
        R.eye(9 * sz, -2, 6 * sz, cute=True)
        p.fill(R.poly([(-6, 12), (6, 12), (0, 18)]), (90, 40, 10))


# ============================================================================ GUEULE COSMIQUE
def maw(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2, c3 = pal["c1"], pal["c2"], pal["c3"]
    for k in range(10):
        a = k / 10 * math.tau
        pts = [(math.cos(a) * 60, math.sin(a) * 60)]
        for j in range(1, 5):
            pts.append((math.cos(a + j * 0.3) * (60 + j * 30), math.sin(a + j * 0.3) * (60 + j * 30)))
        m = R.tube(pts, [16, 12, 8, 4, 1])
        R.paint(m, darken(c1, 0.25))
        p.add_glow_mask(m, pal["glow"], 0.2, 6)
    R.paint(R.ell(0, 0, 80, 80), c1, gloss=0.3)
    hole = R.ell(0, 0, 52, 52)
    p.fill(hole, (2, 0, 8))
    p.radial_glow(*R.T(0, 0), R.r(50), pal["glow"], 0.9, 1.4)
    p.stars(30, *[R.T(0, -40)[1], R.T(0, 40)[1]]) if False else None
    for ring, n, L in ((50, 18, 16), (36, 14, 12)):
        for k in range(n):
            a = k / n * math.tau
            x, y = math.cos(a) * ring, math.sin(a) * ring
            tip = (math.cos(a) * (ring - L), math.sin(a) * (ring - L))
            side = (math.cos(a + 0.12) * ring, math.sin(a + 0.12) * ring)
            R.paint(R.poly([(x, y), tip, side]), (245, 240, 225), outline=0.6, gloss=0.5)
    for k in range(o.get("eyes", 6)):
        a = k / o.get("eyes", 6) * math.tau - 0.3
        R.eye(math.cos(a) * 68, math.sin(a) * 68, 6, slit=True)


# ============================================================================ ŒUF / LARVE
def egg(R):
    o, pal, p = R.o, R.pal, R.p
    p.shadow(*R.T(0, 52), R.r(40), R.r(7), 0.5)
    m = R.ell(0, 0, 38, 50)
    R.paint(m, pal["c1"], gloss=0.6)
    for k in range(4):
        x = -24 + k * 16
        R.paint(R.poly([(x, -6), (x + 8, -18), (x + 16, -6), (x + 8, 4)]), pal["c2"], outline=0.6)
    m2 = p.mask()
    d = ImageDraw.Draw(m2)
    d.line(p.P(R.pts([(-10, -40), (-2, -26), (-12, -14), (0, 0)])), fill=255, width=int(p.S(1.6)))
    p.emit(m2, pal["glow"], 1.4, 8)
    p.radial_glow(*R.T(0, 0), R.r(70), pal["glow"], 0.4)


def larva(R):
    o, pal, p = R.o, R.pal, R.p
    c1, c2 = pal["c1"], pal["c2"]
    segs = [(70, 60), (50, 50), (28, 36), (8, 18), (-8, -4), (-18, -30)]
    for i, (x, y) in enumerate(segs):
        r = 16 + i * 2.6
        R.paint(R.ell(x, y, r, r * 0.9), c1 if i % 2 else darken(c1, 0.1), gloss=0.35)
        p.add_glow_mask(R.ell(x, y + r * 0.4, r * 0.6, r * 0.3), pal["glow"], 0.4, 4)
    hx, hy = segs[-1]
    mouth = R.ell(hx - 8, hy - 10, 18, 16)
    p.fill(mouth, (20, 4, 16))
    for k in range(8):
        a = k / 8 * math.tau
        R.paint(R.poly([(hx - 8 + math.cos(a) * 16, hy - 10 + math.sin(a) * 14), (hx - 8 + math.cos(a) * 6, hy - 10 + math.sin(a) * 5), (hx - 8 + math.cos(a + 0.3) * 16, hy - 10 + math.sin(a + 0.3) * 14)]), (240, 240, 210), outline=0.5)
    for k in range(o.get("eyes", 3)):
        R.eye(hx + 10 + k * 6, hy - 26 + k * 7, 4)


ARCH = {}
