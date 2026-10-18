"""Пиксельный портрет для иконки из фото: вырезает человека, ужимает до 40×40, теплит цвет.

    python3 tools/icon/make_portrait.py фото.png

Нужны rembg и Pillow (pip install "rembg[cpu]" pillow). Пишет tools/icon/portrait.png,
дальше иконку собирает tools/icon/icon.py.
"""
import os
import sys

from PIL import Image, ImageEnhance
from rembg import new_session, remove

HERE = os.path.dirname(os.path.abspath(__file__))
N = 40  # портрет в «пикселях» иконки

cut = remove(Image.open(sys.argv[1]), session=new_session('u2net_human_seg')).convert('RGBA')
r, g, b, a = cut.split()
# На фото лиловый свет — теплим кожу.
r = r.point(lambda v: min(255, int(v * 1.08 + 6)))
g = g.point(lambda v: min(255, int(v * 1.10 + 4)))
b = b.point(lambda v: int(v * 0.80))
rgb = ImageEnhance.Contrast(Image.merge('RGB', (r, g, b))).enhance(1.25)
rgb = rgb.point(lambda v: min(v, 200))

small = rgb.resize((N, N), Image.LANCZOS).quantize(colors=14, method=Image.Quantize.MEDIANCUT).convert('RGB')
alpha = a.resize((N, N), Image.LANCZOS).point(lambda v: 255 if v > 110 else 0)
portrait = Image.merge('RGBA', (*small.split(), alpha))

# Блик на волосах читается как русые волосы, а у щеки остаётся кусок стены — красим в тон волос.
pix = portrait.load()
for y in range(N):
    for x in range(N):
        cr, cg, cb, ca = pix[x, y]
        if ca == 0:
            continue
        lum = 0.3 * cr + 0.59 * cg + 0.11 * cb
        if y < N * 0.45 and lum > 120:
            pix[x, y] = (88, 60, 46, 255) if lum > 150 else (70, 48, 38, 255)
        elif x > N * 0.85 and lum > 135:
            pix[x, y] = (70, 48, 38, 255)

portrait.save(os.path.join(HERE, 'portrait.png'))
print('written', os.path.join(HERE, 'portrait.png'))
