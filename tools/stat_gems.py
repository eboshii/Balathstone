"""Blank Attack/Health gems for minion tiles.

The game draws each minion's live Attack and Health itself (src/core.lua HS.draw_badges), in
Belwe like real Hearthstone, so the atlas tiles must not have numbers printed on their gems.
blank_stats() paints them out using tools/templates/blank_gems.png (made by
tools/make_gem_template.py). Geometry is in 512x776 render coordinates.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(ROOT, 'tools', 'templates', 'blank_gems.png')

# boxes holding each gem plus any digits that spill past it (two-digit numbers)
BOXES = ((18, 572, 162, 702), (356, 556, 496, 702))

# where the printed digits sit and how tall they are (measured over all cached renders);
# src/core.lua HS.BADGE uses the same numbers as fractions of the cropped tile
ATK_CENTRE = (87.5, 638.5)
HP_CENTRE = (424.5, 640.5)
DIGIT_HEIGHT = 60

_cache = {}


def _load():
    if not _cache:
        yy, xx = np.mgrid[0:776, 0:512]
        atk = ((xx - 89) ** 2 + (yy - 636) ** 2) < 35 ** 2
        hp = (((xx - 424) ** 2 + (yy - 648) ** 2) < 29 ** 2) | \
            ((abs(xx - 424) < (yy - 586) * 0.48) & (yy > 590) & (yy < 652))
        inside = np.zeros((776, 512), bool)
        for x0, y0, x1, y1 in BOXES:
            inside[y0:y1, x0:x1] = True
        _cache['gems'] = atk | hp
        _cache['inside'] = inside
        _cache['tmpl'] = np.asarray(Image.open(TEMPLATE).convert('RGBA')).astype(float)
    return _cache['gems'], _cache['inside'], _cache['tmpl']


def blank_stats(img):
    """Paint the printed numbers out of a 512x776 RGBA minion render, in place."""
    gems, inside, tmpl = _load()
    a = np.asarray(img).astype(float)
    m = gems.copy()
    for x0, y0, x1, y1 in BOXES:
        sub = a[y0:y1, x0:x1]
        white = (sub[..., 0] > 200) & (sub[..., 1] > 200) & (sub[..., 2] > 200)
        grown = np.asarray(Image.fromarray((white * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(13))) > 0
        m[y0:y1, x0:x1] |= grown & (sub[..., 3] > 0)
    m &= inside
    soft = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0)))
    soft = soft.astype(float)[..., None] / 255
    a[..., :3] = a[..., :3] * (1 - soft) + tmpl[..., :3] * soft
    img.paste(Image.fromarray(a.astype(np.uint8)))
    return img
