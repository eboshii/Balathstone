"""Build tools/templates/blank_gems.png: the Attack/Health gem corners with no numbers.

Every minion render shares the same gem art; only the digits differ. For each pixel we take
the median over all cached neutral minion renders where that pixel is NOT covered by a digit,
which reconstructs the clean gems (and the rim/frame the bigger numbers spill onto).

tools/build_art.py pastes this over every minion's printed stats, and the game draws the live
numbers itself (src/core.lua HS.draw_badges). Run once after render_cache_512 is filled.
"""
import json
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, 'render_cache_512')
CARDS = os.path.join(ROOT, 'data', 'raw', 'cards_all.json')
OUT = os.path.join(ROOT, 'tools', 'templates', 'blank_gems.png')

# boxes (512px render coordinates) that contain each gem plus any spilling digits
ATK_BOX = (18, 572, 162, 702)
HP_BOX = (356, 556, 496, 702)


def digit_mask(rgba):
    """White digit fill plus its thick black outline (white grown by ~6px). Transparent counts too."""
    rgb = rgba[..., :3]
    white = (rgb[..., 0] > 200) & (rgb[..., 1] > 200) & (rgb[..., 2] > 200)
    img = Image.fromarray((white * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(13))
    return (np.asarray(img) > 0) | (rgba[..., 3] < 250)


def fill_holes(img, holes):
    """Diffuse neighbouring colours into pixels that were never clean."""
    img = np.where(holes[..., None], 0, img)
    known = (~holes).astype(float)
    for _ in range(200):
        if known.min() > 0:
            break
        acc = np.zeros_like(img)
        cnt = np.zeros(known.shape)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            acc += np.roll(np.roll(img * known[..., None], dy, 0), dx, 1)
            cnt += np.roll(np.roll(known, dy, 0), dx, 1)
        grow = (known == 0) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        known[grow] = 1
    return img


def main():
    db = {c['id']: c for c in json.load(open(CARDS, encoding='utf-8'))}
    stack = []
    for name in sorted(os.listdir(CACHE)):
        cid = name.replace('_512.png', '').replace('.png', '')
        c = db.get(cid)
        if not c or c.get('type') != 'MINION' or c.get('cardClass') != 'NEUTRAL':
            continue
        im = Image.open(os.path.join(CACHE, name)).convert('RGBA')
        if im.size[0] != 512 or im.size[1] < 700:
            continue
        a = np.zeros((776, 512, 4), np.uint8)
        a[:im.size[1]] = np.asarray(im)
        stack.append(a)
    print(f'{len(stack)} neutral minion renders')
    stack = np.stack(stack).astype(float)
    out = np.zeros((776, 512, 4), np.uint8)
    for x0, y0, x1, y1 in (ATK_BOX, HP_BOX):
        region = stack[:, y0:y1, x0:x1, :]
        masks = np.stack([digit_mask(r) for r in region])
        vals = np.where(masks[..., None], np.nan, region)
        with np.errstate(all='ignore'):
            import warnings
            warnings.simplefilter('ignore')
            med = np.nanmedian(vals, axis=0)
        # pixels covered by digits on every card (shouldn't happen): fall back to the plain median
        holes = np.isnan(med[..., 0])
        if holes.any():
            print(f'  {holes.sum()} pixels never clean; filling from neighbours')
            med = fill_holes(med, holes)
            # smooth the filled patch so it has no seams (it sits under the drawn number)
            blur = np.asarray(Image.fromarray(np.clip(med, 0, 255).astype(np.uint8)).filter(
                ImageFilter.GaussianBlur(3))).astype(float)
            med[holes] = blur[holes]
        med[..., 3] = 255
        out[y0:y1, x0:x1] = np.clip(med, 0, 255).astype(np.uint8)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(out).save(OUT)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
