"""Иконка приложения: пиксельный портрет Санбоя с солнцем-нимбом на ночной плашке.

    python3 tools/icon/icon.py

Берёт tools/icon/portrait.png (его делает make_portrait.py), пишет Resources/AppIcon.icns,
docs/icon.png и плоскую версию без обводки для карусели promo/instagram/assets/icon.png.
Нужен Pillow.
"""
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))

S = 1024
G = 15  # пиксель портрета в иконке
SUN, SUN_EDGE, STAR = (255, 210, 63), (255, 159, 28), (255, 236, 170)
TOP, BOTTOM = (16, 14, 32), (60, 30, 58)  # ночь, как в окне установщика
FRAME = (242, 177, 52)

portrait = Image.open(os.path.join(HERE, 'portrait.png'))
plate = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(plate)

# Плашка по сетке иконок macOS: 824×824 с отступом 100, градиент ступеньками.
for y in range(100, 924, 8):
    t = (y - 100) / 824
    d.rectangle([100, y, 924, y + 8], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))

# Солнце-нимб за головой из пиксельных квадратов и лучи.
cx, cy, R = 512, 400, 285
for y in range(cy - R - 120, cy + R + 1, G):
    for x in range(cx - R - 120, cx + R + 121, G):
        dist = math.hypot(x + G / 2 - cx, y + G / 2 - cy)
        if dist < R:
            d.rectangle([x, y, x + G - 1, y + G - 1], fill=SUN if dist < R - 3 * G else SUN_EDGE)
for k in range(12):
    angle = k * math.pi / 6 + math.pi / 12
    for step in range(3):
        rr = R + 30 + step * G * 1.6
        x = round((cx + math.cos(angle) * rr) / G) * G
        y = round((cy + math.sin(angle) * rr) / G) * G
        d.rectangle([x, y, x + G - 1, y + G - 1], fill=SUN_EDGE if step else SUN)
for x, y in [(176, 176), (848, 208), (160, 560), (864, 600), (240, 832), (800, 848)]:
    d.rectangle([x, y, x + G // 2 - 1, y + G // 2 - 1], fill=STAR)

big = portrait.resize((portrait.width * G, portrait.height * G), Image.NEAREST)
plate.alpha_composite(big, ((S - big.width) // 2, 924 - big.height))

icon = Image.new('RGBA', (S, S), (0, 0, 0, 0))
mask = Image.new('L', (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((100, 100, 924, 924), radius=185, fill=255)
icon.paste(plate, (0, 0), mask)
# Для карусели — плоская, без обводки и без полей сетки macOS.
icon.crop((100, 100, 924, 924)).save(os.path.join(ROOT, 'promo', 'instagram', 'assets', 'icon.png'))
ImageDraw.Draw(icon).rounded_rectangle((100, 100, 924, 924), radius=185, outline=FRAME, width=16)

out = os.path.join(ROOT, 'Resources', 'AppIcon.icns')
icon.save(out, sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
icon.save(os.path.join(ROOT, 'docs', 'icon.png'))
print('written', out)
