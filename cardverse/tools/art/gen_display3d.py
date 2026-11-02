#!/usr/bin/env python3
"""Textures des displays 3D : face avant illustrée, côté, couvercle (d'après data/products.json)."""
import json
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
FONT_T = os.path.join(ROOT, "assets", "fonts", "CinzelDecorative-Bold.ttf")
FONT_B = os.path.join(ROOT, "assets", "fonts", "lilita_one.woff2")


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def grad(w, h, c1, c2):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)))
    return im


def text_center(d, cx, y, txt, font, fill, stroke=4):
    w = d.textlength(txt, font=font)
    d.text((cx - w / 2, y), txt, font=font, fill=fill, stroke_width=stroke, stroke_fill=(20, 10, 30))


def front(dd, booster, mascot):
    W, H = 640, 400
    c = hexc(dd["color"])
    im = grad(W, H, tuple(min(255, int(v * 1.1) + 20) for v in c), tuple(int(v * 0.35) for v in c))
    d = ImageDraw.Draw(im)
    for x in range(-H, W, 28):  # bandes foil
        d.line([(x, 0), (x + H, H)], fill=tuple(min(255, int(v * 1.25) + 25) for v in c), width=6)
    im = im.filter(ImageFilter.GaussianBlur(1))
    d = ImageDraw.Draw(im)
    art = Image.open(os.path.join(ROOT, "assets", "cards", mascot + ".png")).convert("RGB").crop((60, 75, 390, 355)).resize((250, 212), Image.NEAREST)
    m = Image.new("L", art.size, 0)
    ImageDraw.Draw(m).ellipse([0, 0, art.size[0] - 1, art.size[1] - 1], fill=255)
    d.ellipse([W - 300, 70, W - 30, 300], fill=(255, 230, 150))
    im.paste(art, (W - 290, 80), m)
    ft = ImageFont.truetype(FONT_T, 54)
    fn = ImageFont.truetype(FONT_T, 30)
    fb = ImageFont.truetype(FONT_T, 26)
    d.text((28, 30), "CARDVERSE", font=ft, fill=(255, 242, 210), stroke_width=5, stroke_fill=(40, 10, 70))
    name = dd["name"].replace("Display ", "")
    d.text((30, 120), name.upper()[:22], font=fn, fill=(255, 255, 255), stroke_width=4, stroke_fill=(20, 10, 30))
    d.text((30, 180), "%d BOOSTERS" % dd["count"], font=fb, fill=(255, 220, 120), stroke_width=4, stroke_fill=(20, 10, 30))
    d.text((30, 220), {"L": "LÉGENDAIRE GARANTI", "M": "MYTHIQUE GARANTI"}.get(dd.get("guarantee", "L"), "CARTE GARANTIE"), font=fb, fill=(255, 220, 120), stroke_width=4, stroke_fill=(20, 10, 30))
    d.rectangle([0, H - 46, W, H], fill=tuple(int(v * 0.25) for v in c))
    d.text((30, H - 42), "ÉDITION COLLECTOR · ULTIMATE TCG", font=ImageFont.truetype(FONT_T, 22), fill=(255, 220, 150))
    d.rectangle([0, 0, W - 1, H - 1], outline=(255, 230, 160), width=6)
    return im


def side(dd):
    c = hexc(dd["color"])
    im = grad(256, 256, tuple(int(v * 0.85) for v in c), tuple(int(v * 0.4) for v in c))
    d = ImageDraw.Draw(im)
    for y in range(0, 256, 32):
        d.line([(0, y), (256, y)], fill=tuple(int(v * 0.3) for v in c), width=2)
    d.rectangle([0, 0, 255, 255], outline=(255, 230, 160), width=5)
    return im


def lid(dd):
    c = hexc(dd["color"])
    im = grad(512, 300, tuple(min(255, int(v * 1.15) + 15) for v in c), tuple(int(v * 0.5) for v in c))
    d = ImageDraw.Draw(im)
    ft = ImageFont.truetype(FONT_T, 46)
    text_center(d, 256, 110, "CARDVERSE", ft, (255, 242, 210), 5)
    d.rectangle([0, 0, 511, 299], outline=(255, 230, 160), width=6)
    d.rectangle([236, 0, 276, 300], fill=(255, 205, 90))  # bande adhésive
    return im


def main():
    out = os.path.join(ROOT, "assets", "ui", "display3d")
    os.makedirs(out, exist_ok=True)
    prods = json.load(open(os.path.join(ROOT, "data", "products.json"), encoding="utf-8"))
    boosters = {b["id"]: b for b in json.load(open(os.path.join(ROOT, "data", "boosters.json"), encoding="utf-8"))["boosters"]}
    import gen_ui
    gen_ui.type_packs()
    for dd in prods["displays"]:
        mascot = gen_ui.PACKS.get(dd["booster"], (None, None, "f004"))[2]
        front(dd, boosters[dd["booster"]], mascot).save(os.path.join(out, dd["id"] + "_front.png"), optimize=True)
        side(dd).save(os.path.join(out, dd["id"] + "_side.png"), optimize=True)
        lid(dd).save(os.path.join(out, dd["id"] + "_lid.png"), optimize=True)
    print("textures 3D :", len(prods["displays"]))


if __name__ == "__main__":
    import sys
    sys.path.insert(0, HERE)
    main()
