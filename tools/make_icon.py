"""Génère l'icône de l'application Clash of Things (couronne + épées, lettres « CoT »)."""
import sys
from PIL import Image, ImageDraw, ImageFont

S = 512
font_path, out = sys.argv[1], sys.argv[2]
im = Image.new('RGBA', (S, S))
d = ImageDraw.Draw(im)
for i in range(S, 0, -2):
    t = i / S
    d.ellipse([S / 2 - i, S / 2 - i, S / 2 + i, S / 2 + i], fill=(int(20 + 60 * (1 - t)), int(70 + 120 * (1 - t)), int(200 + 50 * (1 - t)), 255))
mask = Image.new('L', (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=110, fill=255)
bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
bg.paste(im, (0, 0), mask)
im = bg
d = ImageDraw.Draw(im)
d.rounded_rectangle([6, 6, S - 7, S - 7], radius=106, outline=(11, 20, 48, 255), width=14)
ink = (11, 20, 48, 255)
# épées croisées
for sgn in (-1, 1):
    a = (256 - 150 * sgn, 70)
    b = (256 + 120 * sgn, 330)
    d.line([a, b], fill=ink, width=46)
    d.line([a, b], fill=(230, 238, 248, 255), width=26)
    d.line([(b[0] - 50 * sgn, b[1] - 50), (b[0] + 40 * sgn, b[1] - 80)], fill=ink, width=34)
    d.line([(b[0] - 50 * sgn, b[1] - 50), (b[0] + 40 * sgn, b[1] - 80)], fill=(255, 201, 40, 255), width=18)
# couronne
crown = [(140, 300), (140, 150), (200, 215), (256, 110), (312, 215), (372, 150), (372, 300)]
d.polygon([(x, y + 8) for x, y in crown], fill=ink)
d.polygon(crown, fill=(255, 210, 63, 255), outline=ink, width=12)
for cx, cy in ((140, 145), (256, 105), (372, 145)):
    d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=(255, 243, 160, 255), outline=ink, width=8)
f = ImageFont.truetype(font_path, 130)
txt = 'CoT'
w = d.textlength(txt, font=f)
d.text(((S - w) / 2, 320), txt, font=f, fill=(255, 255, 255, 255), stroke_width=10, stroke_fill=ink)
im.save(out)
