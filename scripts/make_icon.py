"""Génère l'icône de l'application (cristal d'essence + « EA »)."""
import sys
from PIL import Image, ImageDraw, ImageFont

S = 512
font_path, out = sys.argv[1], sys.argv[2]
im = Image.new('RGBA', (S, S))
d = ImageDraw.Draw(im)
for i in range(S, 0, -2):
    t = i / S
    d.ellipse([S / 2 - i, S / 2 - i, S / 2 + i, S / 2 + i], fill=(int(15 + 50 * (1 - t)), int(60 + 130 * (1 - t)), int(190 + 60 * (1 - t)), 255))
mask = Image.new('L', (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=110, fill=255)
bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
bg.paste(im, (0, 0), mask)
im = bg
d = ImageDraw.Draw(im)
d.rounded_rectangle([6, 6, S - 7, S - 7], radius=106, outline=(11, 20, 48, 255), width=14)
cx, cy = S / 2, 190
pts = [(cx, cy - 130), (cx + 90, cy), (cx, cy + 140), (cx - 90, cy)]
d.polygon([(x + 8, y + 10) for x, y in pts], fill=(11, 20, 48, 220))
d.polygon(pts, fill=(70, 210, 255, 255))
d.polygon([(cx, cy - 130), (cx + 90, cy), (cx, cy)], fill=(190, 245, 255, 255))
d.polygon([(cx, cy), (cx - 90, cy), (cx, cy + 140)], fill=(20, 120, 220, 255))
d.line(pts + [pts[0]], fill=(11, 20, 48, 255), width=10)
f = ImageFont.truetype(font_path, 150)
for txt, x, col in (('E', 150, (255, 255, 255, 255)), ('A', 270, (255, 201, 40, 255))):
    for dx, dy in ((0, 9),):
        d.text((x + dx, 330 + dy), txt, font=f, fill=(11, 20, 48, 255), stroke_width=9, stroke_fill=(11, 20, 48, 255))
    d.text((x, 330), txt, font=f, fill=col, stroke_width=7, stroke_fill=(11, 20, 48, 255))
im.resize((192, 192), Image.LANCZOS).save(out)
