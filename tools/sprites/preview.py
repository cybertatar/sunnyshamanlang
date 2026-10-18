import re, sys
from PIL import Image
PAL = {
 'K':'2A1A12','S':'EDB98C','s':'C98A62','Y':'FFD23F','O':'FF9F1C',
 'F':'6B3E26','f':'8E5A3A','R':'B8322A','r':'8C2320','T':'F2B134',
 'W':'A0703F','D':'F3E0B5','d':'D9BF8A','B':'5A3820','w':'FFFFFF','G':'3FA34D',
}
def parse(src):
    out = {}
    for name, body in re.findall(r'static let (\w+) = Sprite\("""\n(.*?)\n\s*"""\)', src, re.S):
        out[name] = [l.strip() for l in body.split('\n')]
    return out
def render(rows, scale):
    w = max(len(r) for r in rows); h = len(rows)
    im = Image.new('RGBA', (w*scale, h*scale), (0,0,0,0))
    for y,r in enumerate(rows):
        for x,c in enumerate(r):
            if c in PAL:
                col = tuple(int(PAL[c][i:i+2],16) for i in (0,2,4)) + (255,)
                for dy in range(scale):
                    for dx in range(scale):
                        im.putpixel((x*scale+dx, y*scale+dy), col)
    return im
if __name__ == '__main__':
    sprites = parse(open(sys.argv[1]).read())
    ims = [render(r, 8) for r in sprites.values()]
    W = sum(i.width for i in ims) + 20*(len(ims)+1); H = max(i.height for i in ims) + 40
    sheet = Image.new('RGBA', (W, H), (246,236,214,255))
    x = 20
    for i in ims:
        sheet.alpha_composite(i, (x, 20)); x += i.width + 20
    sheet.save(sys.argv[2])
    for n, r in sprites.items():
        print(n, len(r), set(len(l) for l in r))
