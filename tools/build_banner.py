"""Build docs/banner.png (1280x640: GitHub social preview, Nexus, Thunderstore page)
and docs/icon.png (256x256: Thunderstore icon) from the card atlases."""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_art  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, 'assets', 'fonts', 'belwe-bd-bt-bold.ttf')
W, H = 284, 380  # 2x card tile
BADGE = dict(ax=0.1586, ay=0.9144, hx=0.8666, hy=0.9176, digit_h=0.0942)  # src/core.lua HS.BADGE

CARDS = [  # key, atlas, (attack, health) or None
    ('j_hs_ragnaros_the_firelord', 'minions', (8, 8)),
    ('j_hs_deathwing', 'minions', (12, 12)),
    ('c_hs_fireball', 'consumables', None),
    ('j_hs_tyrande', 'minions', (5, 7)),
    ('j_hs_lyra_the_sunshard', 'minions', (3, 5)),  # last = on top of the fan: the face of the mod
]


def card_tile(cards, key, atlas, stats):
    c = cards[key]
    sheet = Image.open(os.path.join(ROOT, 'assets', '2x', atlas + '.png'))
    tile = sheet.crop((c['x'] * W, c['y'] * H, c['x'] * W + W, c['y'] * H + H)).convert('RGBA')
    if stats:
        f64 = ImageFont.truetype(FONT, 64)
        bb = f64.getbbox('0123456789')
        font = ImageFont.truetype(FONT, int(64 * BADGE['digit_h'] * H / (bb[3] - bb[1])))
        stroke = max(2, int(BADGE['digit_h'] * H * 0.09))
        d = ImageDraw.Draw(tile)
        for (fx, fy), v in (((BADGE['ax'], BADGE['ay']), stats[0]), ((BADGE['hx'], BADGE['hy']), stats[1])):
            d.text((fx * W, fy * H), str(v), font=font, fill='white', anchor='mm', stroke_width=stroke, stroke_fill='black')
    return tile


def background(w, h):
    img = Image.new('RGB', (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            # warm tavern glow on the right, deep teal felt on the left
            gx = (x - w * 0.68) / w
            gy = (y - h * 0.5) / h
            glow = max(0.0, 1 - math.hypot(gx * 1.4, gy * 1.8))
            t = x / w
            r = int(18 + 40 * t + 150 * glow ** 2)
            g = int(42 + 10 * t + 80 * glow ** 2)
            b = int(48 - 20 * t + 20 * glow ** 2)
            px[x, y] = (min(r, 255), min(g, 255), max(b, 0))
    # vignette
    vig = Image.new('L', (w, h), 0)
    ImageDraw.Draw(vig).ellipse((-w * 0.15, -h * 0.35, w * 1.15, h * 1.35), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(h * 0.12))
    dark = Image.new('RGB', (w, h), (6, 8, 10))
    return Image.composite(img, dark, vig).convert('RGBA')


def fan(img, tiles, cx, cy, scale, spread=8, step=0.36):
    n = len(tiles)
    for i, tile in enumerate(tiles):
        k = i - (n - 1) / 2
        t = tile.resize((int(W * scale), int(H * scale)), Image.LANCZOS)
        shadow = Image.new('RGBA', t.size, (0, 0, 0, 0))
        shadow.putalpha(t.getchannel('A').point(lambda a: int(a * 0.55)))
        rot = t.rotate(-k * spread, resample=Image.BICUBIC, expand=True)
        srot = shadow.rotate(-k * spread, resample=Image.BICUBIC, expand=True).filter(ImageFilter.GaussianBlur(10))
        x = int(cx + k * t.width * step - rot.width / 2)
        y = int(cy + abs(k) ** 1.6 * t.height * 0.05 - rot.height / 2)
        img.alpha_composite(srot, (x + 10, y + 16))
        img.alpha_composite(rot, (x, y))


def title(img, x, y, size):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, size)
    # gold text with a dark outline and soft drop shadow
    shadow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x + 6, y + 8), 'Balathstone', font=f, fill=(0, 0, 0, 200))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
    d.text((x, y), 'Balathstone', font=f, fill=(250, 214, 120), stroke_width=max(3, size // 18),
           stroke_fill=(40, 22, 8))
    return f


def main():
    cards = {c['key']: c for c in build_art.load_cards()}
    tiles = [card_tile(cards, *c) for c in CARDS]

    # ---- banner 1280x640 (rendered at 2x, then downsampled)
    S = 2
    bw, bh = 1280 * S, 640 * S
    img = background(bw // 4, bh // 4).resize((bw, bh), Image.BICUBIC)
    fan(img, tiles, cx=bw * 0.775, cy=bh * 0.52, scale=0.78 * S)
    # "TOTAL CONVERSION MOD" tag above the title
    d = ImageDraw.Draw(img)
    tag_font = ImageFont.truetype(FONT, 21 * S)
    tag = 'TOTAL CONVERSION MOD'
    tx, ty = int(bw * 0.057), int(bh * 0.225)
    tb = d.textbbox((tx, ty), tag, font=tag_font)
    pad_x, pad_y = 16 * S, 8 * S
    d.rounded_rectangle((tb[0] - pad_x, tb[1] - pad_y, tb[2] + pad_x, tb[3] + pad_y), radius=10 * S,
                        fill=(122, 30, 18), outline=(250, 214, 120), width=3 * S)
    d.text((tx, ty), tag, font=tag_font, fill=(250, 226, 160))
    title(img, int(bw * 0.05), int(bh * 0.31), 96 * S)
    d = ImageDraw.Draw(img)
    sub = ImageFont.truetype(FONT, 40 * S)
    small = ImageFont.truetype(FONT, 22 * S)
    d.text((int(bw * 0.055), int(bh * 0.53)), 'Hearthstone in Balatro', font=sub, fill=(245, 240, 230),
           stroke_width=3 * S, stroke_fill=(20, 14, 10))
    d.text((int(bw * 0.057), int(bh * 0.64)), '175 minions  ·  90 spells  ·  17 Secrets  ·  69 Blinds',
           font=small, fill=(215, 205, 185), stroke_width=2 * S, stroke_fill=(20, 14, 10))
    img.resize((1280, 640), Image.LANCZOS).convert('RGB').save(os.path.join(ROOT, 'docs', 'banner.png'), optimize=True)

    # ---- icon 256x256 (Thunderstore)
    ic = background(64, 64).resize((512, 512), Image.BICUBIC)
    th = 480
    t = tiles[-1].resize((int(W * th / H), th), Image.LANCZOS)  # Lyra, the face of the mod
    ic.alpha_composite(t, ((512 - t.width) // 2, (512 - th) // 2))
    ic.resize((256, 256), Image.LANCZOS).convert('RGB').save(os.path.join(ROOT, 'docs', 'icon.png'), optimize=True)
    print('wrote docs/banner.png and docs/icon.png')


if __name__ == '__main__':
    main()
