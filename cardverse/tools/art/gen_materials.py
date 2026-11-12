#!/usr/bin/env python3
"""Textures de matériaux réalistes (procédurales) : bois verni de la table, carton kraft,
film plastique rétractable, masques de foil des boosters."""
import os
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "materials")
rng = np.random.default_rng(42)


def tile_noise(n, scale, octaves=4):
    """Bruit de valeur périodique (raccord parfait) de taille n."""
    out = np.zeros((n, n), np.float32)
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        s = scale * (2 ** o)
        g = rng.random((s, s)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
        # raccord : on mélange avec la version décalée
        a = np.asarray(im, np.float32) / 255
        out += a * amp
        tot += amp
        amp *= 0.5
    return out / tot


def stretched(n, sx, sy):
    """Bruit étiré : sx cellules en largeur, sy en hauteur (fibres longues si sy << sx)."""
    g = rng.random((sy, sx)).astype(np.float32)
    return np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), np.float32) / 255


def wood():
    """Planches de bois verni : fibres longues et serrées, nœuds discrets, joints entre planches."""
    n = 1024
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    plank = (x // 256).astype(np.int32)
    warp = stretched(n, 6, 2) * 40 + stretched(n, 24, 3) * 8
    grain = np.sin((x + warp + plank * 37) * 0.32) * 0.5 + 0.5
    grain = grain ** 3
    fibers = stretched(n, 400, 12)
    figure = stretched(n, 10, 3)
    v = 0.5 + 0.18 * grain + 0.22 * (fibers - 0.5) + 0.25 * (figure - 0.5)
    # nœuds
    for _ in range(6):
        cx, cy = rng.uniform(0, n), rng.uniform(0, n)
        d = np.sqrt(((x - cx) * 1.0) ** 2 + ((y - cy) * 0.35) ** 2)
        v -= 0.25 * np.exp(-d / 14.0)
        v += 0.06 * np.sin(d * 0.5) * np.exp(-d / 40.0)
    # teinte légèrement différente par planche
    shade = 1.0 + (rng.random(4)[plank] - 0.5) * 0.18
    dark = np.array([52, 27, 14], np.float32) / 255
    light = np.array([156, 98, 56], np.float32) / 255
    col = (dark + (light - dark) * np.clip(v, 0, 1)[..., None]) * shade[..., None]
    seam = (x % 256 < 2)
    col[seam] *= 0.35
    return Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB")


def kraft():
    n = 512
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    base = np.array([168, 128, 84], np.float32) / 255
    fib = tile_noise(n, 96, 2) * 0.12 + tile_noise(n, 8) * 0.1
    corr = 0.04 * np.sin(y * 0.5)  # ondulations du carton cannelé
    specks = (rng.random((n, n)) > 0.995) * -0.25
    v = 0.9 + fib - 0.08 + corr + specks
    col = base * v[..., None]
    return Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB")


def wrap():
    """Film rétractable : presque transparent, plis et reflets étirés."""
    n = 512
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    wr = tile_noise(n, 6) * 0.6 + tile_noise(n, 24) * 0.4
    creases = np.abs(np.sin(x * 0.03 + wr * 9.0)) ** 30
    creases += np.abs(np.sin((x + y) * 0.02 + wr * 6.0)) ** 40 * 0.7
    a = np.clip(0.06 + creases * 0.5 + (wr - 0.5) * 0.06, 0, 1)
    rgb = np.ones((n, n, 3), np.float32)
    return Image.fromarray((np.dstack([rgb, a]) * 255).astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    wood().save(os.path.join(OUT, "wood.png"), optimize=True)
    kraft().save(os.path.join(OUT, "kraft.png"), optimize=True)
    wrap().save(os.path.join(OUT, "wrap.png"), optimize=True)
    print("matériaux générés")


if __name__ == "__main__":
    main()
