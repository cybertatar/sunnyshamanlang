"""Прототип стиля «как пишет Санбой» один в один с Shamanizer.sunboy в Swift.

Нужен, чтобы подбирать вероятности без Mac:
    python3 tools/style/sunboy.py "Привет, как дела?" "Ещё сообщение"
Меняешь числа здесь — меняй и в Sources/ShamanCore/Sunboy.swift (и наоборот).
"""
import sys

MASK = (1 << 64) - 1


def fnv1a(s):
    h = 0xcbf29ce484222325
    for b in s.encode():
        h ^= b
        h = (h * 0x100000001B3) & MASK
    h ^= h >> 33
    h = (h * 0xff51afd7ed558ccd) & MASK
    h ^= h >> 33
    return h


def is_word(c):
    return c.isalpha() or c.isdigit()


def is_protected(chunk):
    low = chunk.lower()
    return '://' in chunk or low.startswith('www.') or ('@' in chunk and '.' in chunk.split('@')[-1])


def tokenize(text):
    tokens = []  # (kind, text): word / sep / keep

    def add_sep(s):
        if tokens and tokens[-1][0] == 'sep':
            tokens[-1] = ('sep', tokens[-1][1] + s)
        else:
            tokens.append(('sep', s))

    def flush(chunk):
        if not chunk:
            return
        if is_protected(chunk):
            tokens.append(('keep', chunk))
            return
        cur, cur_word = '', False
        for c in chunk:
            wc = is_word(c)
            if cur and wc != cur_word:
                tokens.append(('word', cur)) if cur_word else add_sep(cur)
                cur = ''
            cur += c
            cur_word = wc
        if cur:
            tokens.append(('word', cur)) if cur_word else add_sep(cur)

    chunk = ''
    for c in text:
        if c.isspace():
            flush(chunk)
            chunk = ''
            add_sep(c)
        else:
            chunk += c
    flush(chunk)
    return tokens


def swap_letters(s):
    for a, b in (('о', '0'), ('О', '0'), ('г', 'х'), ('Г', 'Х'), ('е', 'э'), ('Е', 'Э'),
                 ('з', 'э'), ('З', 'Э'), ('й', 'и'), ('Й', 'И')):
        s = s.replace(a, b)
    return s


# Разговорные словечки, как «НУ ШО» у Санбоя.
SLANG = {
    'что': 'шо', 'чтобы': 'шобы', 'чего': 'чо', 'сейчас': 'щас', 'вообще': 'ваще',
    'только': 'тока', 'ничего': 'ничо', 'конечно': 'канешно', 'пожалуйста': 'пажалуста',
    'здравствуйте': 'здрасте', 'спасибо': 'спасиба', 'тебя': 'тибя', 'меня': 'миня',
    'сегодня': 'седня', 'хорошо': 'харашо', 'короче': 'карочи', 'нормально': 'нармальна',
}


def slang(word):
    low = word.lower()
    if low not in SLANG:
        return word
    new = SLANG[low]
    return new.upper() if word.isupper() and len(word) > 1 else (new.capitalize() if word[:1].isupper() else new)


def sunboy(text):
    if ',,,,' in text or '....' in text:
        return text
    tokens = tokenize(text)
    out = [t for _, t in tokens]

    caps, prev, n = False, '', 0
    for i, (kind, t) in enumerate(tokens):
        if kind == 'keep':
            prev = t
            continue
        if kind != 'word':
            continue
        h = fnv1a('w\x1f' + prev + '\x1f' + t)
        # Капс тянется длинными кусками: войти в него легко, выйти трудно (~70% слов капсом).
        if n > 0 and h % 100 < (16 if caps else 50):
            caps = not caps
        word = slang(t) if (h >> 28) % 100 < 85 else t
        if caps:
            s = word.upper()
        else:
            s = word.lower()
            if n == 0:
                s = s[:1].upper() + s[1:]
        if (h >> 8) % 100 < 65:
            s = swap_letters(s)
        # Повтор для нажима: «ДРУЗЬЯ,,НАСТОЯЩИЕ,,,,,,».
        if caps and len(t) >= 4 and (h >> 36) % 100 < 9:
            s = s + ',' * (2 + (h >> 40) % 5) + s
        out[i] = s
        prev, n = t, n + 1

    for i, (kind, t) in enumerate(tokens):
        if kind != 'sep' or i == 0:
            continue
        left = tokens[i - 1]
        right = tokens[i + 1] if i + 1 < len(tokens) else None
        if left[0] == 'keep' or (right and right[0] == 'keep') or '\n' in t:
            continue
        if right and not any(c.isspace() for c in t):
            continue  # «кто-то», «1,5», «:)» без пробела — не трогаем
        h = fnv1a('g\x1f' + left[1] + '\x1f' + t + '\x1f' + (right[1] if right else ''))
        dots = lambda lo, hi: '.' * (lo + (h >> 12) % (hi - lo + 1))
        commas = lambda lo, hi: ',' * (lo + (h >> 12) % (hi - lo + 1))
        if t == ' ':
            r = h % 1000
            if r < 380: s = ' '
            elif r < 610: s = dots(2, 13)
            elif r < 800: s = commas(2, 6)
            elif r < 850: s = '--..'
            elif r < 910: s = ' ' + dots(3, 6)
            elif r < 960: s = ''
            else: s = '.. '
        else:
            s = ''
            for c in t:
                if c.isspace(): continue
                if c in '.…': s += dots(2, 16)
                elif c == ',': s += commas(2, 5)
                elif c == '!': s += '!!'
                elif c == '?': s += ' ?' + dots(2, 5)
                elif c in '—–-': s += ' —' if (h >> 20) & 1 else '--'
                else: s += c
            if right and (h >> 24) % 100 < 20:
                s += ' '
        out[i] = s

    # Сообщение без точки в конце иногда затухает многоточием.
    if tokens and tokens[-1][0] == 'word':
        h = fnv1a('e\x1f' + tokens[-1][1])
        if h % 100 < 45:
            out.append('.' * (3 + (h >> 12) % 8))
    result = ''.join(out)
    # Без длинной пачки повторное колдовство перемешало бы регистр заново.
    if result and ',,,,' not in result and '....' not in result:
        result += '.' * (4 + (fnv1a('z\x1f' + text) >> 12) % 6)
    return result


if __name__ == '__main__':
    for t in sys.argv[1:]:
        print(sunboy(t))
        print()
