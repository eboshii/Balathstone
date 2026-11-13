"""Build the Hearthstone card pack atlas (hs_packs) for Balathstone.

Atlas layout:
  Columns: 0: Normal, 1: Jumbo, 2: Mega, 3: Alternate/Bonus
  Rows:
    0: arcana (Spells)           -> Scholomance Academy / Golden Scholomance / Mage Pack
    1: celestial (Locations)     -> TITANS / Golden TITANS / Sunken City
    2: spectral (Forbidden)      -> Whispers of the Old Gods / Frozen Throne / Lich King
    3: standard (Playing Cards)  -> Classic Pack / Golden Classic / Standard Pack
    4: buffoon (Minions)         -> Darkmoon Faire / Golden Darkmoon / Festival of Legends
    5: discover (Discovers)      -> 0: Spell (Mage), 1: Location (Sunken City), 2: Minion (GvG)
"""

import os, io, urllib.request
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
CACHE = os.path.join(ROOT, 'pack_cache')
os.makedirs(CACHE, exist_ok=True)

UA = {'User-Agent': 'Balathstone/1.0 (contact@balathstone.local)'}

# (col, row): (name, pack_id)
PACK_TILES = {
    # Row 0: Arcana (Spells)
    (0, 0): ('Scholomance Academy', 468),
    (1, 0): ('Golden Scholomance', 603),
    (2, 0): ('Mage Class Pack', 545),
    (3, 0): ('Rise of Shadows', 49),
    
    # Row 1: Celestial (Locations)
    (0, 1): ('TITANS', 819),
    (1, 1): ('Golden TITANS', 937),
    (2, 1): ('Voyage to the Sunken City', 694),
    (3, 1): ('The Great Dark Beyond', 965),
    
    # Row 2: Spectral (Forbidden Spells)
    (0, 2): ('Whispers of the Old Gods', 11),
    (1, 2): ('Knights of the Frozen Throne', 21),
    (2, 2): ('March of the Lich King', 821),
    (3, 2): ('Ashes of Outland', 423),
    
    # Row 3: Standard (Playing Cards)
    (0, 3): ('Classic Pack', 1),
    (1, 3): ('Golden Classic Pack', 23),
    (2, 3): ('Standard Pack', 713),
    (3, 3): ('Golden Standard Pack', 716),
    
    # Row 4: Buffoon (Minions)
    (0, 4): ('Madness at the Darkmoon Faire', 616),
    (1, 4): ('Golden Darkmoon Faire', 643),
    (2, 4): ('Festival of Legends', 854),
    (3, 4): ('Showdown in the Badlands', 922),
    
    # Row 5: Discover Packs
    (0, 5): ('Discover Spell (Mage Pack)', 545),
    (1, 5): ('Discover Location (Sunken City)', 694),
    (2, 5): ('Discover Minion (Goblins vs Gnomes)', 9),
    (3, 5): ('Discover Minion Extra (Festival of Legends)', 854),
}

def ensure_pack_downloaded(pid, name):
    local_path = os.path.join(CACHE, f'CardPack{pid}.png')
    if not os.path.exists(local_path):
        url = f'https://hearthstone.wiki.gg/images/CardPack{pid}.png'
        print(f"Downloading pack {pid} ({name})...")
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=15) as r:
            with open(local_path, 'wb') as f:
                f.write(r.read())
    return local_path

def render_pack_tile(image_path, tile_w=284, tile_h=380, max_w=268, max_h=364):
    im = Image.open(image_path).convert('RGBA')
    bbox = im.getbbox()
    if bbox:
        cropped = im.crop(bbox)
    else:
        cropped = im

    # Scale preserving aspect ratio
    aspect = cropped.width / cropped.height
    target_h = max_h
    target_w = int(target_h * aspect)
    if target_w > max_w:
        target_w = max_w
        target_h = int(target_w / aspect)

    scaled = cropped.resize((target_w, target_h), Image.LANCZOS)

    tile = Image.new('RGBA', (tile_w, tile_h), (0, 0, 0, 0))
    px = (tile_w - target_w) // 2
    py = (tile_h - target_h) // 2
    tile.paste(scaled, (px, py), scaled)
    return tile

def build_atlas():
    cols, rows = 4, 6
    tile_w_2x, tile_h_2x = 284, 380
    atlas_2x = Image.new('RGBA', (cols * tile_w_2x, rows * tile_h_2x), (0, 0, 0, 0))

    print("Building 2x pack atlas...")
    for (col, row), (name, pid) in PACK_TILES.items():
        pack_path = ensure_pack_downloaded(pid, name)
        tile = render_pack_tile(pack_path, tile_w_2x, tile_h_2x)
        atlas_2x.paste(tile, (col * tile_w_2x, row * tile_h_2x), tile)
        print(f"  Pasted [{col}, {row}]: {name} (ID {pid})")

    # Build 1x atlas
    tile_w_1x, tile_h_1x = 142, 190
    print("Downscaling to 1x pack atlas...")
    atlas_1x = atlas_2x.resize((cols * tile_w_1x, rows * tile_h_1x), Image.LANCZOS)
    atlas_1x = atlas_1x.filter(ImageFilter.UnsharpMask(radius=0.5, percent=50, threshold=2))

    # Save atlases
    out_1x = os.path.join(ROOT, 'assets', '1x', 'packs.png')
    out_2x = os.path.join(ROOT, 'assets', '2x', 'packs.png')
    atlas_1x.save(out_1x, optimize=True)
    atlas_2x.save(out_2x, optimize=True)
    print(f"Saved 1x atlas -> {out_1x} ({atlas_1x.size})")
    print(f"Saved 2x atlas -> {out_2x} ({atlas_2x.size})")

    # Save preview sample
    preview_path = os.path.join(ROOT, 'test_output', 'packs_sample.png')
    os.makedirs(os.path.dirname(preview_path), exist_ok=True)
    atlas_2x.save(preview_path)
    print(f"Saved preview sample -> {preview_path}")

if __name__ == '__main__':
    build_atlas()
