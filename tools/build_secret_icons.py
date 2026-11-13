"""Build assets/1x|2x/secret_icons.png: Hearthstone's Secret "?" gem in each class colour.

Columns: 0 Mage, 1 Hunter, 2 Paladin, 3 Rogue (src/secrets.lua HS.SECRET_CLASS). 34px tiles at 1x.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, 'assets', 'fonts', 'belwe-bd-bt-bold.ttf')

CLASSES = [  # (light, dark) gem colours
    ((236, 140, 255), (98, 22, 140)),   # Mage
    ((150, 235, 120), (22, 96, 30)),    # Hunter
    ((255, 228, 120), (150, 92, 10)),   # Paladin
    ((210, 210, 220), (60, 60, 72)),    # Rogue
]


def icon(light, dark, size=272):
    s = size
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    cx = cy = s / 2
    r_out, r_rim, r_gem = s * 0.47, s * 0.42, s * 0.36
    yy, xx = np.mgrid[0:s, 0:s]
    d = np.hypot(xx - cx, yy - cy)
    # gem: radial gradient, lighter towards the upper left
    hl = np.hypot(xx - (cx - s * 0.1), yy - (cy - s * 0.12)) / (r_gem * 1.4)
    t = np.clip(hl, 0, 1)[..., None]
    gem = (np.array(light) * (1 - t) + np.array(dark) * t)
    rgba = np.zeros((s, s, 4))
    rgba[..., :3] = gem
    rgba[..., 3] = np.where(d < r_gem, 255, 0)
    # gold rim and dark outer ring
    rim = (d >= r_gem) & (d < r_rim)
    rim_shade = (0.75 + 0.25 * np.cos(np.arctan2(yy - cy, xx - cx) + 2.3))[..., None]
    rgba[rim, :3] = (np.array([232, 188, 92]) * rim_shade)[rim]
    rgba[rim, 3] = 255
    ring = (d >= r_rim) & (d < r_out)
    rgba[ring, :3] = (40, 28, 22)
    rgba[ring, 3] = 255
    img = Image.fromarray(rgba.astype(np.uint8))
    # soft highlight
    hl_layer = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(hl_layer).ellipse((s * 0.27, s * 0.2, s * 0.55, s * 0.4), fill=(255, 255, 255, 70))
    img.alpha_composite(hl_layer.filter(ImageFilter.GaussianBlur(s * 0.03)))
    # the "?"
    f = ImageFont.truetype(FONT, int(s * 0.5))
    ImageDraw.Draw(img).text((cx, cy + s * 0.02), '?', font=f, fill=(255, 255, 255), anchor='mm',
                             stroke_width=int(s * 0.035), stroke_fill=(20, 12, 8))
    return img


def main():
    tiles = [icon(l, d) for l, d in CLASSES]
    for scale, px in (('1x', 34), ('2x', 68)):
        sheet = Image.new('RGBA', (px * len(tiles), px), (0, 0, 0, 0))
        for i, t in enumerate(tiles):
            sheet.paste(t.resize((px, px), Image.LANCZOS), (i * px, 0))
        out = os.path.join(ROOT, 'assets', scale, 'secret_icons.png')
        sheet.save(out)
        print('wrote', out)


if __name__ == '__main__':
    main()
