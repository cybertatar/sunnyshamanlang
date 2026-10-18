# Рисует кадры шамана в сетку символов и печатает их для Sprites.swift
W, H = 30, 30
def blank(): return [['.']*W for _ in range(H)]
def put(g, x, y, c):
    if 0 <= x < W and 0 <= y < H: g[y][x] = c
def rect(g, x0, y0, x1, y1, c):
    for y in range(y0, y1+1):
        for x in range(x0, x1+1): put(g, x, y, c)
def row(g, y, x0, s):
    for i, c in enumerate(s):
        if c != ' ': put(g, x0+i, y, c)

CX = 17  # центр головы

def crown(g, flicker):
    # солнце-корона над шапкой
    row(g, 4, CX-2, 'KOOOK')
    row(g, 3, CX-2, 'OYYYO')
    row(g, 2, CX-2, 'OYYYO')
    row(g, 1, CX-1, 'OOO')
    rays = [(0, -1), (-5, 0), (5, 0), (-4, 3), (4, 3)] if flicker else [(0, 0), (-4, 1), (4, 1), (-5, 3), (5, 3)]
    for dx, y in rays:
        if dx == 0: put(g, CX, y, 'Y')
        else:
            put(g, CX+dx, y, 'Y')

def head(g, eyes='open', mouth='calm'):
    row(g, 5, CX-4, 'KKFFFFFKK')
    row(g, 6, CX-5, 'KFfFfFfFfFK')
    row(g, 7, CX-5, 'KTTTTTTTTTK')
    row(g, 8, CX-5, 'KSSSSSSSSSK')
    if eyes == 'open':
        row(g, 9, CX-5, 'KSSKSSSKSSK')
        row(g, 10, CX-5, 'KSSKSSSKSSK')
    else:
        row(g, 9, CX-5, 'KSSSSSSSSSK')
        row(g, 10, CX-5, 'KSKKSSSKKSK')
    if mouth == 'calm':
        row(g, 11, CX-4, 'KsSSSSSsK')
        row(g, 12, CX-3, 'KKsssKK')
    else:  # поёт
        row(g, 11, CX-4, 'KsSSKSSsK')
        row(g, 12, CX-3, 'KKsssKK')
    # меховые уши шапки
    for y in range(7, 12):
        put(g, CX-6, y, 'F'); put(g, CX+6, y, 'F')
    put(g, CX-7, 8, 'K'); put(g, CX-7, 9, 'K'); put(g, CX-7, 10, 'K'); put(g, CX-6, 12, 'K')
    put(g, CX+7, 8, 'K'); put(g, CX+7, 9, 'K'); put(g, CX+7, 10, 'K'); put(g, CX+6, 12, 'K')
    put(g, CX-7, 11, 'K'); put(g, CX+7, 11, 'K')
    put(g, CX-6, 6, 'K'); put(g, CX+6, 6, 'K')

def body(g):
    # ворот
    row(g, 13, CX-3, 'KTTTTTK')
    # мантия-трапеция
    widths = [(14, 4), (15, 5), (16, 5), (17, 5), (18, 6), (19, 6), (20, 6), (21, 7), (22, 7)]
    for y, hw in widths:
        put(g, CX-hw, y, 'K'); put(g, CX+hw, y, 'K')
        rect(g, CX-hw+1, y, CX+hw-1, y, 'R')
        put(g, CX, y, 'T')
        put(g, CX-hw+1, y, 'r')
    row(g, 16, CX-1, 'OYO')
    put(g, CX, 17, 'O')
    # пояс с бахромой
    row(g, 23, CX-7, 'KTTTTTTTTTTTTTK')
    row(g, 24, CX-6, 'KTKTKTKTKTKTK')
    # ноги
    row(g, 25, CX-4, 'KRK   KRK')
    row(g, 26, CX-4, 'KFK   KFK')
    row(g, 27, CX-5, 'KKFK   KFKK')
    row(g, 28, CX-5, 'KKKK   KKKK')

def drum(g, x0, y0, shake=0):
    # круглый бубен с солнцем
    pat = [
        '...KKKKK...',
        '.KKWWWWWKK.',
        '.KWDDDDDWK.',
        'KWDDDdDDDWK',
        'KWDDdYdDDWK',
        'KWDdYOYdDWK',
        'KWDDdYdDDWK',
        'KWDDDdDDDWK',
        '.KWDDDDDWK.',
        '.KKWWWWWKK.',
        '...KKKKK...',
    ]
    for dy, line in enumerate(pat):
        for dx, c in enumerate(line):
            if c != '.': put(g, x0+dx+shake, y0+dy, c)
    # бубенцы снизу
    put(g, x0+2+shake, y0+11, 'T'); put(g, x0+8+shake, y0+11, 'T')

def left_arm(g, shake=0):
    # рука держит бубен (слева)
    row(g, 16, CX-6, 'KK')
    row(g, 17, CX-8, 'KSSK')
    row(g, 18, CX-8, 'KSSK')

def beater_up(g):
    # рука поднята, колотушка над головой
    row(g, 14, CX+5, 'KRK')
    row(g, 13, CX+6, 'KRK')
    row(g, 12, CX+7, 'KRK')
    row(g, 11, CX+7, 'KSSK')
    row(g, 10, CX+7, 'KSSK')
    put(g, CX+9, 9, 'B'); put(g, CX+9, 8, 'B'); put(g, CX+10, 7, 'B'); put(g, CX+10, 6, 'B')
    row(g, 4, CX+10, 'ww'); row(g, 5, CX+10, 'ww')

def beater_hit(g):
    # колотушка ударяет по бубну: рука через грудь влево
    row(g, 15, CX+5, 'KRK')
    row(g, 16, CX+3, 'KRRK')
    row(g, 17, CX+1, 'KRRK')
    row(g, 17, CX-1, 'KSSK')
    row(g, 18, CX-1, 'KSSK')
    # палка к центру бубна
    for i, (x, y) in enumerate([(CX-2, 18), (CX-3, 18), (CX-4, 19), (CX-5, 19), (CX-6, 19)]):
        put(g, x, y, 'B')
    row(g, 19, CX-8, 'ww'); row(g, 20, CX-8, 'ww')

def beater_rest(g):
    # рука опущена, колотушка вниз
    row(g, 15, CX+6, 'K')
    row(g, 16, CX+6, 'KK')
    row(g, 17, CX+6, 'KSSK')
    row(g, 18, CX+6, 'KSSK')
    put(g, CX+8, 19, 'B'); put(g, CX+8, 20, 'B'); put(g, CX+9, 21, 'B')
    row(g, 22, CX+9, 'ww'); row(g, 23, CX+9, 'ww')

def frame(kind):
    g = blank()
    crown(g, flicker=(kind == 'hit'))
    body(g)
    if kind == 'idle':
        head(g, eyes='open', mouth='calm')
        drum(g, 0, 14)
        left_arm(g)
        beater_rest(g)
    elif kind == 'up':
        head(g, eyes='open', mouth='sing')
        drum(g, 0, 13)
        left_arm(g)
        beater_up(g)
    elif kind == 'hit':
        head(g, eyes='closed', mouth='sing')
        drum(g, 0, 14, shake=1)
        left_arm(g)
        beater_hit(g)
    elif kind == 'blink':
        head(g, eyes='closed', mouth='calm')
        drum(g, 0, 14)
        left_arm(g)
        beater_rest(g)
    return [''.join(r) for r in g]

# Значок для строки меню: бубен, рисуется шаблоном (цвет задаёт система)
MENU_ICON = [
    '.....XXXXXX.....',
    '...XX......XX...',
    '..X..........X..',
    '.X.....XX.....X.',
    '.X...X.XX.X...X.',
    'X.....XXXX.....X',
    'X...XXXXXXXX...X',
    'X...XXXXXXXX...X',
    'X.....XXXX.....X',
    '.X...X.XX.X...X.',
    '.X.....XX.....X.',
    '..X..........X..',
    '...XX......XX...',
    '.....XXXXXX.....',
    '...X........X...',
    '...X........X...',
]

if __name__ == '__main__':
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(here, '..', '..', 'Sources', 'SunboyShaman', 'Sprites.swift')
    parts = []
    for name in ['idle', 'blink', 'up', 'hit']:
        rows = frame(name)
        while rows and set(rows[-1]) == {'.'}:
            rows.pop()
        parts.append(f'    static let {name} = Sprite("""\n' + '\n'.join('        ' + r for r in rows) + '\n        """)\n')
    parts.append('    static let menuIcon = Sprite("""\n' + '\n'.join('        ' + r for r in MENU_ICON) + '\n        """)\n')
    header = (
        '// Сгенерировано tools/sprites/draw.py — правьте там и перезапустите:\n'
        '// python3 tools/sprites/draw.py\n\n'
        'extension Sprite {\n'
    )
    open(target, 'w').write(header + '\n'.join(parts) + '}\n')
    print('written', os.path.normpath(target))
