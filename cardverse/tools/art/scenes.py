"""Décors d'arrière-plan des illustrations, un univers par élément (+ variantes)."""
import math

from PIL import ImageDraw, ImageFilter

from paint import lighten, darken

# Palettes : (principale, secondaire/lueur, sombre, ciel haut, ciel bas)
ELEMENTS = {
    "feu":      dict(main=(236, 92, 38), glow=(255, 196, 70), dark=(70, 16, 12), top=(38, 6, 12), bot=(150, 40, 18)),
    "eau":      dict(main=(40, 150, 225), glow=(130, 235, 255), dark=(8, 28, 70), top=(4, 18, 48), bot=(18, 90, 140)),
    "terre":    dict(main=(160, 114, 70), glow=(255, 205, 130), dark=(55, 36, 22), top=(70, 52, 60), bot=(190, 130, 80)),
    "foudre":   dict(main=(252, 218, 60), glow=(150, 225, 255), dark=(34, 34, 80), top=(14, 14, 40), bot=(60, 60, 120)),
    "glace":    dict(main=(165, 222, 255), glow=(225, 248, 255), dark=(40, 78, 140), top=(40, 70, 130), bot=(170, 210, 240)),
    "nature":   dict(main=(84, 186, 82), glow=(225, 255, 140), dark=(18, 56, 30), top=(20, 60, 50), bot=(110, 170, 90)),
    "ombre":    dict(main=(128, 62, 170), glow=(225, 100, 255), dark=(18, 8, 28), top=(10, 4, 18), bot=(50, 20, 70)),
    "lumiere":  dict(main=(255, 222, 140), glow=(255, 250, 215), dark=(150, 100, 40), top=(250, 190, 120), bot=(255, 240, 210)),
    "cosmique": dict(main=(110, 86, 230), glow=(255, 120, 225), dark=(10, 6, 40), top=(4, 2, 20), bot=(40, 16, 90)),
    "neant":    dict(main=(56, 50, 70), glow=(110, 255, 205), dark=(4, 4, 8), top=(0, 0, 0), bot=(16, 18, 26)),
}


def scene(p, element, variant=None, epic=0):
    """Peint le décor. epic (0..3) ajoute rayons/particules pour les hautes raretés."""
    e = ELEMENTS[element]
    v = variant or element
    fn = SCENES.get(v, SCENES[element])
    fn(p, e)
    if epic >= 1:
        p.rays(150, 120, 6 + epic * 4, e["glow"], 0.10 + 0.05 * epic, spread=1.4, seed=epic)
    if epic >= 2:
        p.particles(30 * epic, e["glow"], 0, 300, 20, 400, 0.5, 1.6, 0.6, 3)


def _ground(p, y, c, a=1.0):
    p.ridge(y, 10, c, 0.3, seed=3, peaks=3, a=a)


def volcano(p, e):
    p.vgrad(e["top"], e["bot"], 0, 0.75)
    p.radial(150, 250, 220, (255, 120, 40), 0.55)
    p.clouds((90, 30, 30), 14, 20, 140, 20, 50, 0.55, 14)
    p.ridge(250, 120, (60, 20, 22), 0.8, seed=11, peaks=2.2)
    lava = p.tube_mask([(-10, 318), (80, 310), (160, 322), (240, 308), (310, 316)], [3, 4, 3, 4, 3])
    p.emit(lava, (255, 110, 30), 0.7, 6)
    p.radial_glow(150, 70, 60, (255, 140, 40), 0.5)  # cratère
    p.ridge(330, 50, (34, 10, 12), 0.6, seed=5, peaks=4)
    p.radial_glow(150, 120, 90, (255, 90, 20), 0.35)
    p.particles(60, (255, 170, 60), 0, 300, 60, 420, 0.5, 1.4, 0.9, 3)


def ocean(p, e):
    p.vgrad(e["top"], e["bot"], 0, 1)
    p.rays(150, -20, 9, (120, 220, 255), 0.22, spread=0.6, length=520, seed=4)
    p.nebula((30, 110, 170), (80, 200, 255), 0.35, 90, seed=2)
    p.ridge(330, 70, (10, 40, 70), 0.9, seed=8, peaks=5)
    for i in range(9):  # algues
        x = 10 + i * 36 + p.rng.uniform(-10, 10)
        h = p.rng.uniform(60, 120)
        pts = [(x, 430), (x + p.rng.uniform(-8, 8), 430 - h * 0.4), (x + p.rng.uniform(-14, 14), 430 - h * 0.75), (x + p.rng.uniform(-10, 10), 430 - h)]
        p.flat(p.tube_mask(pts, [6, 5, 3, 1]), (10, 50, 60) if i % 2 else (14, 64, 70))
    p.ridge(380, 30, (6, 22, 46), 0.4, seed=2, peaks=3)
    bm = p.mask()
    d = ImageDraw.Draw(bm)
    for _ in range(30):
        x, y, r = p.rng.uniform(0, 300), p.rng.uniform(40, 400), p.rng.uniform(1, 4)
        d.ellipse([p.S(x - r), p.S(y - r), p.S(x + r), p.S(y + r)], outline=200, width=int(p.S(1)))
    p.emit(bm, (180, 240, 255), 0.4, 2, core=False)
    p.fill(bm, (190, 240, 255), 0.6)


def abyss(p, e):
    p.vgrad((1, 6, 18), (6, 30, 60), 0, 1)
    p.nebula((10, 50, 90), (40, 140, 200), 0.4, 70, seed=9)
    p.ridge(300, 120, (2, 10, 22), 0.9, seed=4, peaks=3)
    p.particles(50, (90, 255, 220), 0, 300, 0, 420, 0.5, 1.5, 0.8, 4)


def canyon(p, e):
    p.vgrad((120, 90, 110), (240, 170, 110), 0, 0.6)
    p.radial(220, 110, 120, (255, 230, 170), 0.6)
    p.ridge(220, 110, (150, 90, 70), 0.9, seed=2, peaks=2.5)
    p.ridge(270, 80, (110, 66, 48), 0.9, seed=6, peaks=3.5)
    p.ridge(340, 60, (70, 42, 30), 0.7, seed=9, peaks=2)
    p.clouds((255, 220, 180), 6, 280, 330, 20, 40, 0.25, 12)


def storm(p, e):
    p.vgrad(e["top"], e["bot"], 0, 1)
    p.clouds((50, 50, 100), 18, 0, 180, 25, 60, 0.75, 12)
    p.clouds((90, 90, 150), 10, 20, 140, 20, 40, 0.5, 8)
    # éclairs
    m = p.mask()
    d = ImageDraw.Draw(m)
    for bx in (55, 250):
        x, y = bx, 0
        pts = [(x, y)]
        while y < 300:
            x += p.rng.uniform(-18, 18)
            y += p.rng.uniform(15, 30)
            pts.append((x, y))
        d.line(p.P(pts), fill=255, width=int(p.S(2)))
    p.emit(m, (170, 220, 255), 1.2, 8)
    p.ridge(340, 50, (20, 20, 46), 0.8, seed=3, peaks=4)
    p.particles(25, (255, 240, 120), 0, 300, 100, 420, 0.5, 1.2, 0.8, 3)


def tundra(p, e):
    p.vgrad((30, 50, 110), (180, 220, 245), 0, 0.8)
    # aurore
    p.nebula((90, 230, 200), (120, 255, 220), 0.25, 160, seed=4)
    p.ridge(250, 120, (200, 225, 245), 1.0, seed=7, peaks=2.4)
    p.ridge(260, 90, (150, 190, 230), 0.8, seed=1, peaks=3.2, a=0.9)
    p.ridge(340, 40, (230, 245, 255), 0.4, seed=4, peaks=2)
    p.particles(80, (255, 255, 255), 0, 300, 0, 420, 0.5, 1.6, 0.4, 2)


def forest(p, e):
    p.vgrad((30, 80, 70), (170, 210, 120), 0, 0.85)
    p.rays(200, -10, 8, (255, 250, 180), 0.25, spread=0.7, length=500, seed=8)
    for layer, (y, c) in enumerate(((330, (40, 90, 60)), (360, (25, 66, 40)))):
        for i in range(9):
            x = p.rng.uniform(-10, 310)
            h = p.rng.uniform(140, 230)
            p.flat(p.poly_mask([(x - 26, y), (x, y - h), (x + 26, y)]), c)
    p.ridge(380, 40, (16, 44, 24), 0.5, seed=5, peaks=3)
    p.particles(40, (230, 255, 140), 0, 300, 100, 400, 0.6, 1.6, 0.9, 4)


def haunted(p, e):
    p.vgrad(e["top"], e["bot"], 0, 1)
    p.radial(150, 110, 70, (200, 190, 230), 0.8, 3)  # lune
    p.radial_glow(150, 110, 120, (160, 90, 220), 0.4)
    p.clouds((40, 16, 60), 10, 120, 300, 20, 50, 0.6, 16)
    # arbres morts / ruines
    for x in (30, 270):
        p.flat(p.tube_mask([(x, 420), (x + 4, 300), (x - 10, 220), (x - 30, 180)], [10, 6, 3, 1]), (12, 6, 18))
        p.flat(p.tube_mask([(x + 3, 290), (x + 30, 250), (x + 46, 240)], [4, 2, 1]), (12, 6, 18))
    p.ridge(350, 40, (10, 4, 16), 0.6, seed=2, peaks=5)
    p.particles(30, (220, 120, 255), 0, 300, 150, 420, 0.6, 1.6, 0.8, 4)


def temple(p, e):
    p.vgrad((120, 80, 70), (240, 190, 130), 0, 0.8)
    p.radial_glow(150, 120, 140, (255, 220, 150), 0.35)
    p.rays(150, 130, 16, (255, 240, 190), 0.22, spread=2.0, length=400, seed=3)
    p.clouds((255, 250, 240), 12, 280, 380, 25, 55, 0.85, 10)
    for x in (34, 266):
        m = p.poly_mask([(x - 13, 420), (x - 11, 150), (x + 11, 150), (x + 13, 420)])
        p.part(m, (250, 235, 205), (190, 160, 120), outline=0, gloss=0.2)
        p.part(p.poly_mask([(x - 18, 150), (x + 18, 150), (x + 15, 138), (x - 15, 138)]), (240, 215, 170), outline=0)
    p.particles(40, (255, 230, 150), 0, 300, 0, 420, 0.6, 1.6, 0.7, 4)


def nebula(p, e):
    p.vgrad(e["top"], e["bot"], 0, 1)
    p.nebula((120, 40, 160), (255, 100, 200), 0.75, 110, seed=3)
    p.nebula((30, 60, 160), (90, 160, 255), 0.5, 80, seed=12)
    p.stars(260, big=0.06)
    # planète
    m = p.ellipse_mask(250, 70, 34, 34)
    p.part(m, (220, 120, 180), (60, 20, 70), rim=(255, 200, 255), outline=0, gloss=0.1)
    ring = p.ellipse_mask(250, 72, 56, 10, -0.3)
    hole = p.ellipse_mask(250, 72, 44, 6, -0.3)
    ring.paste(0, mask=hole)
    p.emit(ring, (255, 190, 240), 0.4, 3)


def void(p, e):
    p.vgrad((0, 0, 0), (10, 10, 18), 0, 1)
    p.nebula((24, 30, 34), (60, 255, 190), 0.4, 70, seed=5)
    p.stars(80, c=(160, 255, 220), big=0.02)
    # faille
    m = p.mask()
    d = ImageDraw.Draw(m)
    pts = [(150 + math.sin(y * 0.05) * 18 + p.rng.uniform(-6, 6), y) for y in range(-10, 430, 18)]
    d.line(p.P(pts), fill=255, width=int(p.S(3)))
    p.emit(m, (90, 255, 200), 1.0, 14)
    p.ridge(380, 40, (4, 4, 8), 0.9, seed=9, peaks=6)


def sanctum(p, e):
    """Sanctuaire divin doré pour les plus hautes raretés."""
    p.vgrad((20, 10, 40), (150, 80, 70), 0, 1)
    p.nebula((180, 100, 80), (255, 200, 130), 0.45, 120, seed=21)
    p.radial_glow(150, 140, 150, (255, 200, 120), 0.35)
    p.rays(150, 140, 22, (255, 225, 170), 0.25, spread=2.0, length=500, seed=6)
    p.stars(120, 0, 300, (255, 240, 200))


SCENES = {
    "feu": volcano, "eau": ocean, "terre": canyon, "foudre": storm, "glace": tundra,
    "nature": forest, "ombre": haunted, "lumiere": temple, "cosmique": nebula, "neant": void,
    "abyss": abyss, "sanctum": sanctum, "volcano": volcano, "nebula": nebula, "void": void,
    "forest": forest, "temple": temple, "storm": storm, "tundra": tundra, "canyon": canyon, "ocean": ocean,
    "haunted": haunted,
}
