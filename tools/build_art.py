# -*- coding: utf-8 -*-
"""Build every Balathstone atlas from official Hearthstone card renders.

    python tools/build_art.py            # build all atlases
    python tools/build_art.py --sample   # also write a preview sheet to test_output/

Card names, Hearthstone ids, atlas positions and the ability text all come from
the mod's own Lua definitions (loaded headlessly with lupa), so the art always
matches the code. For each card the official 512px render is downloaded
(cached), the Hearthstone text in the text box is painted out, and the Balatro
ability text is typeset in its place in Franklin Gothic (Hearthstone's body
font), with Balatro colours for Mult / Chips / money / keywords.
"""
import io
import json
import os
import re
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from lupa import luajit21 as lupa

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stat_gems import blank_stats  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, 'render_cache_512')
CARDS_JSON = os.path.join(ROOT, 'data', 'raw', 'cards_all.json')
UA = {'User-Agent': 'Mozilla/5.0'}

# Final tile sizes: atlas px/py in Balathstone.lua are 142x190 (1x); 2x doubles.
TILE_1X = (142, 190)
TILE_2X = (284, 380)

# Geometry in the coordinates of a 512px-wide official render.
#   crop:  card body rectangle (aspect 0.747 like a Balatro card)
#   erase: area whose old text is painted out (with optional polygon to prevent clipping icons)
#   text:  area the new text is fitted into
MINION_ERASE_POLY = [
    (96, 470),
    (416, 470),
    (416, 555),
    (388, 580),
    (365, 605),
    (345, 626),
    (167, 626),
    (147, 605),
    (124, 580),
    (96, 555),
]

MINION_TEXT_POLY = [
    (110, 480),
    (402, 480),
    (402, 555),
    (380, 578),
    (358, 600),
    (335, 606),
    (177, 606),
    (154, 600),
    (132, 578),
    (110, 555),
]

WEAPON_ERASE_POLY = [
    (84, 470),
    (420, 470),
    (420, 560),
    (390, 590),
    (360, 618),
    (335, 640),
    (169, 640),
    (144, 618),
    (114, 590),
    (84, 560),
]

WEAPON_TEXT_POLY = [
    (104, 482),
    (404, 482),
    (404, 550),
    (380, 575),
    (355, 596),
    (153, 596),
    (128, 575),
    (104, 550),
]

FRAMES = {
    'MINION':   dict(crop=(12, 56, 488, 693), erase=(78, 466, 432, 630), erase_poly=MINION_ERASE_POLY,
                     text=(110, 480, 402, 606), text_poly=MINION_TEXT_POLY, light=False),
    'SPELL':    dict(crop=(14, 70, 476, 688), erase=(102, 480, 410, 638), text=(114, 488, 386, 628), light=False),
    'LOCATION': dict(crop=(6, 16, 509, 689), erase=(102, 480, 410, 638), text=(114, 488, 386, 628), light=False),
    'WEAPON':   dict(crop=(27, 73, 486, 688), erase=(86, 490, 426, 642), erase_poly=WEAPON_ERASE_POLY,
                     text=(104, 482, 404, 596), text_poly=WEAPON_TEXT_POLY, light=True),
    'HERO':     dict(crop=(25, 105, 487, 724), erase=(92, 508, 422, 672), text=(106, 516, 408, 662), light=False),
}

FONT_PATHS = ['C:/Windows/Fonts/framd.ttf', 'C:/Windows/Fonts/arialbd.ttf', 'C:/Windows/Fonts/arial.ttf']

COLOURS = {
    None: None,  # default ink, depends on frame
    'mult': (205, 35, 35), 'red': (205, 35, 35), 'hearts': (205, 35, 35), 'diamonds': (215, 90, 20),
    'chips': (0, 95, 205), 'blue': (0, 95, 205), 'spades': (40, 40, 90), 'clubs': (30, 90, 60),
    'money': (175, 120, 0), 'green': (35, 135, 35), 'purple': (125, 45, 165),
    'legendary': (150, 40, 170), 'dark_edition': (90, 70, 170), 'inactive': (80, 70, 60),
    'attention': 'bold', 'filter': 'bold', 'white': (205, 35, 35), 'xmult': (205, 35, 35),
}


# --------------------------------------------------------------------- card data
def load_cards():
    """Load the real mod headlessly and return every card's art metadata."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    root = ROOT.replace('\\', '/') + '/'
    run = lua.eval('function(path, ...) return assert(loadfile(path))(...) end')
    run(root + 'tests/mock_balatro.lua', root)
    run(root + 'Balathstone.lua')
    dump = lua.eval('''function()
        local out = {}
        local function vars_for(c)
            if c.hs_minion and c.hs_minion.vars then
                local ok, v = pcall(c.hs_minion.vars, nil)
                if ok and v then return v end
            end
            return {}
        end
        for key, c in pairs(G.P_CENTERS) do
            if (c.atlas == 'hs_minions' or c.atlas == 'hs_consumables' or c.atlas == 'hs_vouchers'
                or c.atlas == 'hs_cards') and c.hs_text then
                local text = {}
                for i, l in ipairs(c.hs_text) do text[i] = l end
                local vars = {}
                for i, v in ipairs(vars_for(c)) do vars[i] = tostring(v) end
                local tribe = c.hs_minion and c.hs_minion.tribe
                out[#out + 1] = { key = key, name = c.name, atlas = c.atlas, x = c.pos.x, y = c.pos.y,
                    hs_id = c.hs_id or '', text = text, vars = vars, tribe = tribe or '' }
            end
        end
        -- Secrets: the tag icon is drawn separately; their card art lives in hs_secrets
        for key, c in pairs(G.P_TAGS or {}) do
            if c.hs_card_atlas and c.hs_text then
                local text = {}
                for i, l in ipairs(c.hs_text) do text[i] = l end
                out[#out + 1] = { key = key, name = c.name, atlas = c.hs_card_atlas, x = c.hs_card_pos.x,
                    y = c.hs_card_pos.y, hs_id = c.hs_id or '', text = text, vars = {}, tribe = '' }
            end
        end
        return out
    end''')
    cards = []
    for t in dump().values():
        cards.append({
            'key': t['key'], 'name': t['name'], 'atlas': t['atlas'], 'x': int(t['x']), 'y': int(t['y']),
            'hs_id': t['hs_id'] or None,
            'text': list(t['text'].values()), 'vars': list(t['vars'].values()),
            'tribe': t['tribe'] or None,
        })
    return sorted(cards, key=lambda c: (c['atlas'], c['y'], c['x']))


def load_hs_db():
    if not os.path.exists(CARDS_JSON):
        print('Downloading Hearthstone card database...')
        os.makedirs(os.path.dirname(CARDS_JSON), exist_ok=True)
        req = urllib.request.Request('https://api.hearthstonejson.com/v1/latest/enUS/cards.json', headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            open(CARDS_JSON, 'wb').write(r.read())
    data = json.load(open(CARDS_JSON, encoding='utf-8'))
    by_id = {c['id']: c for c in data if 'id' in c}
    by_name = {}
    for c in data:
        if c.get('name') and c.get('type') not in (None, 'ENCHANTMENT', 'HERO_POWER'):
            by_name.setdefault(c['name'], []).append(c)
    return by_id, by_name


def resolve_id(card, by_id, by_name):
    if card['hs_id'] and card['hs_id'] in by_id:
        return card['hs_id']
    hits = by_name.get(card['name'], [])

    def score(c):
        s = 10 if c.get('collectible') else 0
        if c['id'].startswith('VAN_'): s += 5
        if c['id'].startswith('CORE_'): s += 4
        if c['id'].startswith(('BG', 'TB', 'LT', 'LETL', 'Story', 'TUTR', 'TU5', 'PVPDR')): s -= 20
        return s
    hits = sorted(hits, key=score, reverse=True)
    return hits[0]['id'] if hits else card['hs_id']


def fetch_render(cid):
    os.makedirs(CACHE, exist_ok=True)
    for path in (os.path.join(CACHE, f'{cid}_512.png'),
                 os.path.join(ROOT, 'render_cache', f'{cid}_512_render.png')):
        if os.path.exists(path):
            try:
                return Image.open(path).convert('RGBA')
            except Exception:
                pass
    url = f'https://art.hearthstonejson.com/v1/render/latest/enUS/512x/{cid}.png'
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20) as r:
            data = r.read()
    except Exception as e:
        print(f'  ! could not download {cid}: {e}')
        return None
    open(os.path.join(CACHE, f'{cid}_512.png'), 'wb').write(data)
    return Image.open(io.BytesIO(data)).convert('RGBA')


# --------------------------------------------------------------------- erasing
def _box(a, r, axis):
    r = max(1, int(r))
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    p = np.pad(a, pad, mode='edge')
    c = np.cumsum(p, axis=axis)
    hi = np.take(c, range(2 * r + 1, c.shape[axis]), axis=axis)
    lo = np.take(c, range(0, c.shape[axis] - 2 * r - 1), axis=axis)
    return (hi - lo) / (2 * r + 1)


def _blur(a, r):
    """Approximate Gaussian blur (three box passes) on a float HxWxC array."""
    out = a.astype(np.float32)
    rr = max(1, r / 1.7)
    for _ in range(3):
        out = _box(_box(out, rr, 0), rr, 1)
    return out


def _blur_f(arr, r):
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r))).astype(np.float32)

def _blur_mask(mask_f, r):
    im = Image.fromarray((mask_f[:, :, 0] * 255).astype(np.uint8))
    blurred = np.asarray(im.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255.0
    return np.repeat(blurred[:, :, None], 3, axis=2)

TEMPLATES = {}


def get_template(cid):
    if cid in TEMPLATES:
        return TEMPLATES[cid]
    base = fetch_render(cid)
    if base is not None:
        if base.size != (512, 776):
            canvas = Image.new('RGBA', (512, 776), (0, 0, 0, 0))
            canvas.paste(base, (0, 0))
            base = canvas
    TEMPLATES[cid] = base
    return base


def erase_text(img, box, light, poly=None, ctype='SPELL', has_tribe=False):
    """Completely wipe out the old pre-rendered Hearthstone text to clean parchment.
    Uses official clean card templates to guarantee 100% removal of default text
    with authentic Hearthstone texture and seamless anti-aliased edge blending."""
    if ctype == 'MINION':
        clean = get_template('VAN_CS2_182')
        if clean is not None:
            tbox = (78, 466, 432, 630)
            bw, bh = tbox[2] - tbox[0], tbox[3] - tbox[1]
            patch = clean.crop(tbox)
            mask = Image.new('L', (bw, bh), 255)
            draw = ImageDraw.Draw(mask)
            # Rarity gem at top center
            draw.ellipse([178 - 14, -10, 178 + 14, 20], fill=0)
            # Attack badge at bottom-left
            draw.polygon([(0, 105), (15, 105), (32, 125), (46, 145), (46, bh), (0, bh)], fill=0)
            # Health badge at bottom-right
            draw.polygon([(bw, 105), (bw - 15, 105), (bw - 32, 125), (bw - 46, 145), (bw - 46, bh), (bw, bh)], fill=0)
            # Tribe banner at bottom center if minion has tribe
            if has_tribe:
                draw.rectangle([68, 140, 288, bh], fill=0)
            padded = Image.new('L', (bw + 6, bh + 6), 0)
            padded.paste(mask, (3, 3))
            soft = padded.filter(ImageFilter.GaussianBlur(1.2)).crop((3, 3, 3 + bw, 3 + bh))
            img.paste(patch, (tbox[0], tbox[1]), soft)
            return

    elif ctype in ('SPELL', 'LOCATION'):
        clean = get_template('LOOTA_Mage_20')
        if clean is not None:
            tbox = (102, 480, 410, 638)
            bw, bh = tbox[2] - tbox[0], tbox[3] - tbox[1]
            patch = clean.crop(tbox)
            mask = Image.new('L', (bw, bh), 255)
            if ctype == 'LOCATION':
                draw = ImageDraw.Draw(mask)
                draw.ellipse([154 - 14, -10, 154 + 14, 16], fill=0)
                draw.polygon([(bw, 105), (bw - 28, 125), (bw - 28, bh), (bw, bh)], fill=0)
            padded = Image.new('L', (bw + 6, bh + 6), 0)
            padded.paste(mask, (3, 3))
            soft = padded.filter(ImageFilter.GaussianBlur(1.2)).crop((3, 3, 3 + bw, 3 + bh))
            img.paste(patch, (tbox[0], tbox[1]), soft)
            return

    elif ctype == 'WEAPON':
        clean = get_template('VAN_CS2_082')
        if clean is not None:
            tbox = (86, 490, 426, 642)
            bw, bh = tbox[2] - tbox[0], tbox[3] - tbox[1]
            patch = clean.crop(tbox)
            mask = Image.new('L', (bw, bh), 255)
            draw = ImageDraw.Draw(mask)
            draw.polygon([(0, 100), (45, 120), (45, bh), (0, bh)], fill=0)
            draw.polygon([(bw, 100), (bw - 45, 120), (bw - 45, bh), (bw, bh)], fill=0)
            padded = Image.new('L', (bw + 6, bh + 6), 0)
            padded.paste(mask, (3, 3))
            soft = padded.filter(ImageFilter.GaussianBlur(1.2)).crop((3, 3, 3 + bw, 3 + bh))
            img.paste(patch, (tbox[0], tbox[1]), soft)
            return

    elif ctype == 'HERO':
        # Default hero base renders (e.g. Magic Mirror) already have clean empty text boxes
        return

    # Fallback diffusion inpaint if clean template is missing
    x0, y0, x1, y1 = box
    region = np.asarray(img.crop(box)).astype(np.float32)
    h, w, _ = region.shape
    p_mask = Image.new('L', (w, h), 0)
    p_draw = ImageDraw.Draw(p_mask)
    if poly is not None:
        p_draw.polygon([(px - x0, py - y0) for px, py in poly], fill=255)
    else:
        p_draw.rectangle([0, 0, w - 1, h - 1], fill=255)

    pad = 10
    padded = Image.new('L', (w + 2 * pad, h + 2 * pad), 0)
    padded.paste(p_mask, (pad, pad))
    eroded = padded.filter(ImageFilter.MinFilter(7)).crop((pad, pad, pad + w, pad + h))
    mask = np.asarray(eroded) > 0
    p_arr = np.asarray(p_mask) > 0

    rgb = region[:, :, :3].copy()
    keep = (p_arr & ~mask).astype(np.float32)[:, :, None]
    filled = rgb.copy()

    for r in (6, 12, 24, 48, 96):
        num = _blur_f(rgb * keep, r)
        den = _blur_mask(keep, r)
        est = num / np.maximum(den, 1e-4)
        holes = mask & (den[:, :, 0] > 0.01)
        filled[holes] = est[holes]
        keep = np.maximum(keep, (den[:, :, :1] > 0.1).astype(np.float32))
        rgb = np.where(mask[:, :, None], filled, rgb)

    noise = np.random.RandomState(42).normal(0, 1.2, (h, w, 3)).astype(np.float32)
    filled = np.clip(filled + noise, 0, 255)
    out_rgb = np.where(p_arr[:, :, None], filled, region[:, :, :3])
    out = np.concatenate([out_rgb, region[:, :, 3:]], axis=2).clip(0, 255).astype(np.uint8)
    img.paste(Image.fromarray(out, 'RGBA'), (x0, y0), p_mask)


# --------------------------------------------------------------------- typesetting
TOKEN = re.compile(r'\{([^}]*)\}')


def parse_markup(lines, vars_):
    """Balatro loc text -> list of (word, style) with style = colour key or None."""
    text = ' '.join(lines)
    for i, v in enumerate(vars_, start=1):
        text = text.replace(f'#{i}#', v)
    text = re.sub(r'#\d+#', '', text)
    words, style, pos = [], None, 0
    lead = False
    for m in TOKEN.finditer(text):
        chunk = text[pos:m.start()]
        got, lead = _split(chunk, style, lead)
        words.extend(got)
        tag = m.group(1)
        style = None
        for part in tag.split(','):
            if part.startswith('C:'):
                style = part[2:]
        if 'X:mult' in tag:
            style = 'mult'
        pos = m.end()
    got, _ = _split(text[pos:], style, lead)
    words.extend(got)
    return words


def _split(chunk, style, lead):
    """Split a styled chunk into (word, style, space_before). `lead` carries a
    trailing space from the previous chunk across a style change."""
    res = []
    if not chunk:
        return res, lead
    space_before = lead or chunk[0].isspace()
    for p in re.split(r'(\s+)', chunk):
        if not p:
            continue
        if p.isspace():
            space_before = True
            continue
        res.append((p, style, space_before))
        space_before = False
    return res, chunk[-1].isspace() or (lead and chunk.isspace())


def load_fonts(size):
    for p in FONT_PATHS:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def layout(words, font, max_w):
    lines, cur, cur_w = [], [], 0
    space = font.getlength(' ')
    for w, s, sp in words:
        ww = font.getlength(w) + (1 if COLOURS.get(s) == 'bold' else 0)
        add = ww + (space if cur and sp else 0)
        if cur and cur_w + add > max_w and sp:
            lines.append((cur, cur_w))
            cur, cur_w = [], 0
            add = ww
        cur.append((w, s, sp and bool(cur)))
        cur_w += add
    if cur:
        lines.append((cur, cur_w))
    return lines


def poly_width_at(poly, y):
    """Calculate the available [xmin, xmax] of a polygon at vertical position y."""
    intersections = []
    n = len(poly)
    for i in range(n):
        p1 = poly[i]
        p2 = poly[(i + 1) % n]
        if (p1[1] <= y < p2[1]) or (p2[1] <= y < p1[1]):
            x = p1[0] + (y - p1[1]) * (p2[0] - p1[0]) / (p2[1] - p1[1])
            intersections.append(x)
    if len(intersections) >= 2:
        return min(intersections), max(intersections)
    return None, None


def typeset(img, words, box, light, poly=None):
    x0, y0, x1, y1 = box
    max_w, max_h = x1 - x0, y1 - y0
    ink = (250, 245, 235) if light else (22, 18, 14)
    for size in range(34, 13, -1):
        font = load_fonts(size)
        lines = layout(words, font, max_w)
        line_h = int(size * 1.12)
        total_h = len(lines) * line_h
        if total_h > max_h:
            continue
        fits = True
        test_y = y0 + (max_h - total_h) / 2
        for line, width in lines:
            mid_y = test_y + line_h / 2
            if poly is not None:
                xmin, xmax = poly_width_at(poly, mid_y)
                avail_w = (xmax - xmin) if xmin is not None else max_w
            else:
                avail_w = max_w
            if width > avail_w:
                fits = False
                break
            test_y += line_h
        if fits:
            break

    draw = ImageDraw.Draw(img)
    total_h = len(lines) * line_h
    y = y0 + (max_h - total_h) / 2
    space = font.getlength(' ')
    for line, width in lines:
        mid_y = y + line_h / 2
        if poly is not None:
            xmin, xmax = poly_width_at(poly, mid_y)
            avail_w = (xmax - xmin) if xmin is not None else max_w
            cur_x0 = xmin if xmin is not None else x0
        else:
            avail_w = max_w
            cur_x0 = x0
        x = cur_x0 + (avail_w - width) / 2
        for w, s, sp in line:
            if sp:
                x += space
            col = COLOURS.get(s)
            bold = col == 'bold'
            fill = ink if (col is None or bold) else col
            if light and col not in (None, 'bold'):
                fill = tuple(min(255, int(c * 0.6 + 110)) for c in col)
            if light:
                draw.text((x, y), w, font=font, fill=fill, stroke_width=2, stroke_fill=(10, 8, 6))
            else:
                draw.text((x, y), w, font=font, fill=fill, stroke_width=1 if bold else 0, stroke_fill=fill)
            x += font.getlength(w) + (1 if bold else 0)
        y += line_h


# --------------------------------------------------------------------- per card
def render_card(card, by_id, by_name):
    cid = resolve_id(card, by_id, by_name)
    base = fetch_render(cid) if cid else None
    if base is None:
        print(f'  ! no render for {card["key"]} ({card["name"]})')
        return None, cid, None
    ctype = (by_id.get(cid) or {}).get('type', 'SPELL')
    if ctype not in FRAMES:
        ctype = 'SPELL'
    f = FRAMES[ctype]
    # renders are 512 wide but 774 or 776 tall; normalise to 776
    if base.size != (512, 776):
        canvas = Image.new('RGBA', (512, 776), (0, 0, 0, 0))
        canvas.paste(base, (0, 0))
        base = canvas
    img = base.copy()
    has_tribe = bool(card.get('tribe') or (by_id.get(cid) or {}).get('race') or (by_id.get(cid) or {}).get('races'))
    erase_text(img, f['erase'], f['light'], f.get('erase_poly'), ctype=ctype, has_tribe=has_tribe)
    if ctype == 'MINION' and card.get('atlas') == 'hs_minions':
        blank_stats(img)  # the game draws live Attack/Health
    words = parse_markup(card['text'], card['vars'])
    if words:
        typeset(img, words, f['text'], f['light'], f.get('text_poly'))
    tile = img.crop(f['crop'])
    return tile, cid, ctype


def build_atlas(cards, atlas, cols, by_id, by_name, report):
    sub = [c for c in cards if c['atlas'] == atlas]
    if not sub:
        return
    rows = max(c['y'] for c in sub) + 1
    cols = max(cols, max(c['x'] for c in sub) + 1)
    a1 = Image.new('RGBA', (cols * TILE_1X[0], rows * TILE_1X[1]), (0, 0, 0, 0))
    a2 = Image.new('RGBA', (cols * TILE_2X[0], rows * TILE_2X[1]), (0, 0, 0, 0))
    for c in sub:
        tile, cid, ctype = render_card(c, by_id, by_name)
        report.append({'key': c['key'], 'name': c['name'], 'hs_id': cid, 'frame': ctype, 'ok': tile is not None})
        if tile is None:
            continue
        t2 = tile.resize(TILE_2X, Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=60, threshold=2))
        t1 = tile.resize(TILE_1X, Image.LANCZOS)
        a2.paste(t2, (c['x'] * TILE_2X[0], c['y'] * TILE_2X[1]), t2)
        a1.paste(t1, (c['x'] * TILE_1X[0], c['y'] * TILE_1X[1]), t1)
    name = atlas.replace('hs_', '') + '.png'
    a1.save(os.path.join(ROOT, 'assets', '1x', name), optimize=True)
    a2.save(os.path.join(ROOT, 'assets', '2x', name), optimize=True)
    print(f'  {atlas}: {len(sub)} cards -> assets/1x|2x/{name} ({a2.size[0]}x{a2.size[1]})')


def main():
    cards = load_cards()
    by_id, by_name = load_hs_db()
    print(f'Loaded {len(cards)} cards from the mod definitions')
    report = []
    build_atlas(cards, 'hs_minions', 10, by_id, by_name, report)
    build_atlas(cards, 'hs_consumables', 10, by_id, by_name, report)
    build_atlas(cards, 'hs_vouchers', 8, by_id, by_name, report)
    build_atlas(cards, 'hs_cards', 8, by_id, by_name, report)
    build_atlas(cards, 'hs_secrets', 8, by_id, by_name, report)
    missing = [r for r in report if not r['ok']]
    os.makedirs(os.path.join(ROOT, 'test_output'), exist_ok=True)
    json.dump(report, open(os.path.join(ROOT, 'test_output', 'reports', 'art_report.json'), 'w'), indent=1)
    print(f'Done. {len(report) - len(missing)} rendered, {len(missing)} missing')
    for r in missing:
        print('   missing:', r['key'], r['name'])
    if '--sample' in sys.argv:
        keys = sys.argv[sys.argv.index('--sample') + 1:] or None
        sample(cards, by_id, by_name, keys)


def sample(cards, by_id, by_name, keys=None):
    picks = [c for c in cards if (keys is None and c['key'] in SAMPLE_KEYS) or (keys and c['key'] in keys)]
    tiles = []
    for c in picks:
        t, _, _ = render_card(c, by_id, by_name)
        if t is not None:
            tiles.append(t.resize(TILE_2X, Image.LANCZOS))
    if not tiles:
        return
    cols = min(6, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * TILE_2X[0], rows * TILE_2X[1]), (30, 30, 30, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * TILE_2X[0], (i // cols) * TILE_2X[1]), t)
    out = os.path.join(ROOT, 'test_output', 'art_sample.png')
    sheet.save(out)
    print('Sample sheet:', out)


SAMPLE_KEYS = {'j_hs_murloc_tidehunter', 'j_hs_sire_denathrius', 'j_hs_grim_patron', 'j_hs_leper_gnome',
               'j_hs_carnivorous_cube', 'j_hs_young_dragonhawk', 'c_hs_fireball', 'c_hs_mark_of_the_wild',
               'c_hs_castle_kennels', 'c_hs_duplicate', 'v_hs_archmage_staff', 'v_hs_magic_mirror',
               'm_hs_waxadreds_candle', 'm_hs_golden_monkey', 'j_hs_sparkbot_taunt', 'j_hs_sparkbot_windfury'}

if __name__ == '__main__':
    main()
