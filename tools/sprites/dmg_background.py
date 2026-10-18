"""Фон окна установщика (.dmg) в тёмных тонах: ночное небо с пиксельными звёздами,
заголовок цвета солнца, шаман на пиксельной стрелке от приложения к папке Applications.

    python3 tools/sprites/dmg_background.py

Пишет Resources/dmg-background.png (640×400) и @2x. Раскладка иконок — в dmg.py,
координаты здесь должны с ней совпадать. Заголовок — Unifont (пиксельный, с кириллицей).
"""

import os
import random

from PIL import Image, ImageDraw, ImageFont

from preview import parse, render

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'Resources')
UNIFONT = '/usr/share/fonts/opentype/unifont/unifont.otf'
INTER = '/usr/share/fonts/opentype/inter/Inter-Medium.otf'

W, H = 640, 400
APP_X, FOLDER_X, ICON_Y = 160, 480, 200
TITLE = (255, 210, 63)        # солнце с короны шамана
TITLE_SHADOW = (184, 50, 42)  # мантия
HINT = (232, 220, 200)
ARROW = (255, 159, 28)
ARROW_DARK = (184, 50, 42)
TOP, BOTTOM = (16, 14, 32), (46, 26, 52)  # ночь: от чернильно-синего к тёмной сливе
STARS = [(255, 236, 170), (200, 210, 255), (255, 255, 255)]
# Подписи под иконками рисует Finder: чёрные в светлой теме macOS, белые в тёмной.
# Табличка такой яркости даёт контраст 4,6:1 с обоими цветами.
PLATE = (0x84, 0x68, 0xB0)
LABEL_Y, PLATE_W, PLATE_H = 277, 148, 24
PX = 4  # шаг пиксельной сетки фона на 1x


def pixel_text(text, scale):
    """Жирный текст Unifont 16px, увеличенный без сглаживания."""
    font = ImageFont.truetype(UNIFONT, 16)
    left, top, right, bottom = font.getbbox(text)
    small = Image.new('L', (right - left + 1, bottom - top), 0)
    # Дважды со сдвигом на пиксель — жирное начертание, как у пиксельных заголовков игр.
    for dx in (0, 1):
        ImageDraw.Draw(small).text((-left + dx, -top), text, font=font, fill=255)
    small = small.point(lambda v: 255 if v > 127 else 0)
    return small.resize((small.width * scale, small.height * scale), Image.NEAREST)


def draw(scale):
    s = lambda v: round(v * scale)
    img = Image.new('RGBA', (s(W), s(H)))
    d = ImageDraw.Draw(img)
    # Градиент ступеньками по сетке, как на пиксельном небе.
    for y in range(0, H, PX):
        t = y / (H - PX)
        color = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
        d.rectangle([0, s(y), s(W), s(y + PX)], fill=color)

    # Пиксельные звёзды: одни и те же при каждой сборке, не лезут на иконки и подписи.
    rng = random.Random(7)
    for _ in range(70):
        x, y = rng.randrange(0, W // PX) * PX, rng.randrange(0, 300 // PX) * PX
        near_icons = abs(y - ICON_Y) < 100 and (abs(x - APP_X) < 90 or abs(x - FOLDER_X) < 90)
        near_title = 30 < y < 100 and 150 < x < 490
        if near_icons or near_title:
            continue
        size = PX if rng.random() < 0.8 else PX // 2
        d.rectangle([s(x), s(y), s(x + size) - 1, s(y + size) - 1], fill=rng.choice(STARS))
        if rng.random() < 0.12:  # крупная звезда-крестик
            for dx, dy in ((-PX, 0), (PX, 0), (0, -PX), (0, PX)):
                d.rectangle([s(x + dx), s(y + dy), s(x + dx + PX) - 1, s(y + dy + PX) - 1], fill=STARS[0])

    # Таблички под подписями, с пиксельными углами.
    for cx in (APP_X, FOLDER_X):
        x0, y0 = cx - PLATE_W // 2, LABEL_Y - PLATE_H // 2
        x1, y1 = x0 + PLATE_W, y0 + PLATE_H
        d.rectangle([s(x0 + PX), s(y0), s(x1 - PX) - 1, s(y1) - 1], fill=PLATE)
        d.rectangle([s(x0), s(y0 + PX), s(x1) - 1, s(y1 - PX) - 1], fill=PLATE)

    title = pixel_text('САНБОЙ ШАМАН', 3 * scale)
    tx, ty = (s(W) - title.width) // 2, s(44)
    img.paste(TITLE_SHADOW, (tx + 3 * scale, ty + 3 * scale), title)
    img.paste(TITLE, (tx, ty), title)

    # Пиксельная стрелка между иконками (иконки 128pt, подписи рисует Finder).
    x0, x1, y = APP_X + 84, FOLDER_X - 80, ICON_Y
    shaft_end = x1 - 5 * PX
    d.rectangle([s(x0), s(y - PX), s(shaft_end), s(y + PX) - 1], fill=ARROW)
    d.rectangle([s(x0), s(y + PX), s(shaft_end), s(y + 2 * PX) - 1], fill=ARROW_DARK)
    for i in range(6):  # наконечник ступеньками
        half = (5 - i) * PX
        d.rectangle([s(shaft_end + i * PX), s(y - half), s(shaft_end + (i + 1) * PX) - 1, s(y + half + PX) - 1], fill=ARROW)

    # Шаман с бубном стоит на стрелке.
    sprites = parse(open(os.path.join(ROOT, 'Sources', 'SunboyShaman', 'Sprites.swift')).read())
    shaman = render(sprites['up'], 3 * scale)
    img.alpha_composite(shaman, ((s(W) - shaman.width) // 2 - s(6), s(y - PX) - shaman.height))

    hint = ImageFont.truetype(INTER, s(15))
    d.text((s(W / 2), s(352)), 'Перетащи шамана в папку Applications', font=hint, fill=HINT, anchor='mm')

    name = 'dmg-background@2x.png' if scale == 2 else 'dmg-background.png'
    img.convert('RGB').save(os.path.join(OUT, name))


if __name__ == '__main__':
    draw(1)
    draw(2)
    print('written', OUT)
