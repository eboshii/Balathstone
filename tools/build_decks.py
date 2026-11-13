import os, urllib.request, io
from PIL import Image, ImageFilter
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CACHE = os.path.join(ROOT, 'deck_cache')
os.makedirs(CACHE, exist_ok=True)

UA = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Balathstone/1.0'}

DECKS = [
    # Row 0
    {'id': 'b_red', 'name': 'Molten Core', 'file': 'Card_Back_MoltonCore.png', 'x': 0, 'y': 0},
    {'id': 'b_blue', 'name': 'Icecrown', 'file': 'Card_Back_IceCrown.png', 'x': 1, 'y': 0},
    {'id': 'b_yellow', 'name': 'Golden Celebration', 'file': 'Card_Back_GoldenCelebration.png', 'x': 2, 'y': 0},
    {'id': 'b_green', 'name': 'Naxxramas', 'file': 'Card_Back_Naxxramas.png', 'x': 3, 'y': 0},
    # Row 1
    {'id': 'b_black', 'name': 'Black Temple', 'file': 'Card_Back_BlackTemple.png', 'x': 0, 'y': 1},
    {'id': 'b_magic', 'name': 'Dalaran Flame', 'file': 'Card_Back_TeSPA.png', 'x': 1, 'y': 1},
    {'id': 'b_nebula', 'name': 'Legacy of the Void', 'file': 'Card_Back_Void.png', 'x': 2, 'y': 1},
    {'id': 'b_ghost', 'name': 'Heroic Naxxramas', 'file': 'Card_Back_Naxxramas2.png', 'x': 3, 'y': 1},
    # Row 2
    {'id': 'b_abandoned', 'name': 'Shadowmoon Valley', 'file': 'Card_Back_Shadowmoon.png', 'x': 0, 'y': 2},
    {'id': 'b_checkered', 'name': 'Ninjas!', 'file': 'Card_Back_Ninja.png', 'x': 1, 'y': 2},
    {'id': 'b_zodiac', 'name': 'Lunar New Year', 'file': 'Card_Back_Lunar.png', 'x': 2, 'y': 2},
    {'id': 'b_painted', 'name': 'Rainbow!', 'file': 'Card_Back_Charm.png', 'x': 3, 'y': 2},
    # Row 3
    {'id': 'b_anaglyph', 'name': 'Overwatch', 'file': 'Card_Back_Overwatch.png', 'x': 0, 'y': 3},
    {'id': 'b_plasma', 'name': 'Clutch of Yogg-Saron', 'file': 'Card_Back_OG1.png', 'x': 1, 'y': 3},
    {'id': 'b_erratic', 'name': 'Hogger', 'file': 'Card_Back_Hogger.png', 'x': 2, 'y': 3},
    {'id': 'b_challenge', 'name': 'Classic', 'file': 'Card_Back_Default.png', 'x': 3, 'y': 3},
]

BASE_URL = 'https://wow.zamimg.com/images/hearthstone/backs/original/'

def download_cardbacks():
    for d in DECKS:
        local_path = os.path.join(CACHE, d['file'])
        if not os.path.exists(local_path):
            url = BASE_URL + d['file']
            print(f"Downloading {d['name']} ({d['file']})...")
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=15) as r:
                with open(local_path, 'wb') as f:
                    f.write(r.read())
        else:
            print(f"Cached: {d['name']}")

def build_atlas():
    # Card 2x dimensions: tile 284x380, full Balatro card back bbox (4, 4, 280, 376) -> 276x372
    tile_w, tile_h = 284, 380
    card_w, card_h = 276, 372
    pos_x, pos_y = 4, 4
    cols, rows = 4, 4

    mask_path = os.path.join(ROOT, 'tools', 'card_mask_2x.png')
    mask_2x = Image.open(mask_path).convert('L')

    atlas_2x = Image.new('RGBA', (cols * tile_w, rows * tile_h), (0, 0, 0, 0))

    for d in DECKS:
        img_path = os.path.join(CACHE, d['file'])
        cb = Image.open(img_path).convert('RGBA')

        # Remove outer transparent padding from raw Hearthstone web renders
        bbox = cb.getbbox()
        if bbox:
            cb_content = cb.crop(bbox)
        else:
            cb_content = cb

        # Scale up card back art to full Balatro card dimensions (276x372)
        cb_resized = cb_content.resize((card_w, card_h), Image.LANCZOS)

        # Place onto tile canvas centered exactly at (4, 4)
        tile = Image.new('RGBA', (tile_w, tile_h), (0, 0, 0, 0))
        tile.paste(cb_resized, (pos_x, pos_y))

        # Apply exact Balatro rounded playing card mask
        r, g, b, a = tile.split()
        final_a = np.minimum(np.asarray(a), np.asarray(mask_2x))
        card_tile = Image.merge('RGBA', (r, g, b, Image.fromarray(final_a)))

        atlas_2x.paste(card_tile, (d['x'] * tile_w, d['y'] * tile_h))

    # 1x atlas
    atlas_1x = atlas_2x.resize((cols * 142, rows * 190), Image.LANCZOS)

    # Save to assets
    os.makedirs(os.path.join(ROOT, 'assets', '1x'), exist_ok=True)
    os.makedirs(os.path.join(ROOT, 'assets', '2x'), exist_ok=True)
    atlas_1x.save(os.path.join(ROOT, 'assets', '1x', 'decks.png'))
    atlas_2x.save(os.path.join(ROOT, 'assets', '2x', 'decks.png'))
    print("Saved assets/1x/decks.png and assets/2x/decks.png")

    # Sample preview sheet
    os.makedirs(os.path.join(ROOT, 'test_output'), exist_ok=True)
    atlas_2x.save(os.path.join(ROOT, 'test_output', 'decks_sample.png'))
    print("Saved test_output/decks_sample.png")

if __name__ == '__main__':
    download_cardbacks()
    build_atlas()
    print("All deck card backs built successfully!")
