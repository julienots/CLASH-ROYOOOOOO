#!/usr/bin/env python3
"""Génère les illustrations pixel art de toutes les cartes à partir de data/cards/*.json.

Usage : python3 tools/art/gen_cards.py [id1 id2 ...] [--sheet chemin.jpg] [--force]
Les images sont écrites dans assets/cards/<id>.png (450x630, palette indexée).
Une carte n'est régénérée que si sa recette a changé (cache .hash), sauf avec --force.
"""
import glob
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

from creatures import Rig, default_pal, quadruped, serpent  # noqa: E402
from creatures2 import biped, bird, crab, egg, fish, insect, jelly, kraken, larva, maw, orb, plant, spirit  # noqa: E402
from paint import Painter  # noqa: E402
from scenes import scene  # noqa: E402
from spells import spell  # noqa: E402

ARCH = {"quadruped": quadruped, "serpent": serpent, "biped": biped, "bird": bird, "fish": fish, "jelly": jelly,
        "kraken": kraken, "crab": crab, "plant": plant, "insect": insect, "orb": orb, "spirit": spirit, "maw": maw,
        "egg": egg, "larva": larva}
EPIC = {"C": 0, "U": 0, "R": 1, "SR": 1, "E": 1, "L": 2, "M": 2, "A": 2, "D": 3, "CE": 3, "CO": 3, "T": 3, "AB": 3, "O": 3, "X": 3, "P": 3, "SW": 3, "G": 3, "NE": 1, "IN": 2, "MI": 3, "CH": 3, "SY": 3}
VERSION = "4"


def load_cards():
    cards = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "cards", "*.json"))):
        cards += json.load(open(f, encoding="utf-8"))["cards"]
    return cards


def render(card):
    a = dict(card["art"])
    el = card["element"]
    seed = int(hashlib.md5(card["id"].encode()).hexdigest()[:8], 16)
    p = Painter(300, 420, seed=seed)
    scene(p, el, a.get("scene"), EPIC.get(card["rarity"], 0))
    pal = default_pal(el, a)
    if a["arch"] == "spell":
        spell(p, a["spell"], pal)
    else:
        R = Rig(p, a.get("cx", 150), a.get("cy", 150), a.get("scale", 0.95), a.get("flip", False), pal, a)
        ARCH[a["arch"]](R)
    p.vignette(0.35)
    return p.pixel(150, 3, colors=a.get("colors", 56))


def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    sheet = None
    if "--sheet" in sys.argv:
        sheet = sys.argv[sys.argv.index("--sheet") + 1]
        args = [x for x in args if x != sheet]
    force = "--force" in sys.argv
    out = os.path.join(ROOT, "assets", "cards")
    os.makedirs(out, exist_ok=True)
    cards = load_cards()
    if args:
        cards = [c for c in cards if c["id"] in args]
    ims = []
    for c in cards:
        path = os.path.join(out, c["id"] + ".png")
        h = hashlib.md5((VERSION + json.dumps(c["art"], sort_keys=True) + c["element"] + c["rarity"]).hexdigest().encode()).hexdigest() if False else \
            hashlib.md5((VERSION + json.dumps(c["art"], sort_keys=True) + c["element"] + c["rarity"]).encode()).hexdigest()
        hp = path + ".hash"
        if not force and os.path.exists(path) and os.path.exists(hp) and open(hp).read() == h:
            if sheet:
                from PIL import Image
                ims.append(Image.open(path).convert("RGB"))
            continue
        im = render(c)
        im.quantize(64, dither=0).save(path, optimize=True)
        open(hp, "w").write(h)
        print("✓", c["id"], c["name"])
        ims.append(im)
    if sheet and ims:
        from PIL import Image
        w, h = 150, 210
        cols = 8
        rows = (len(ims) + cols - 1) // cols
        sh = Image.new("RGB", (w * cols, h * rows))
        for i, im in enumerate(ims):
            sh.paste(im.resize((w, h)), ((i % cols) * w, (i // cols) * h))
        sh.save(sheet, quality=88)


if __name__ == "__main__":
    main()
