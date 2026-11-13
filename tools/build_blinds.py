import os, re, urllib.request
from PIL import Image, ImageDraw, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bosses_lua = os.path.join(ROOT, 'src', 'bosses.lua')
boss_cache = os.path.join(ROOT, 'boss_art_cache')
os.makedirs(boss_cache, exist_ok=True)

with open(bosses_lua, 'r', encoding='utf-8') as f:
    text = f.read()

blinds = []
lines = text.splitlines()
i = 0
while i < len(lines):
    line = lines[i].strip()
    if line.startswith('B {') or line.startswith('big {'):
        block = line
        while '}' not in block and i + 1 < len(lines):
            i += 1
            block += ' ' + lines[i].strip()
        k_m = re.search(r"key\s*=\s*'([^']+)'", block)
        id_m = re.search(r"hs_id\s*=\s*'([^']+)'", block)
        name_m = re.search(r"name\s*=\s*'([^']+)'", block)
        if k_m:
            blinds.append({'key': k_m.group(1), 'name': name_m.group(1) if name_m else k_m.group(1), 'hs_id': id_m.group(1) if id_m else ''})
    elif line.startswith('small('):
        # the name may be in single or double quotes (Sen'jin Shieldmasta)
        m = re.match(r"""small\('([^']+)',\s*(['"])(.+?)\2,\s*'([^']+)'""", line)
        if m:
            blinds.append({'key': m.group(1), 'name': m.group(3), 'hs_id': m.group(4)})
        else:
            raise SystemExit(f'Could not parse blind line (art rows would shift): {line}')
    i += 1

print(f'Building art for {len(blinds)} blinds...')

def get_blind_image(b):
    hid = b['hs_id']
    clean_id = hid.replace('VAN_', '').replace('CORE_', '')
    cached_path = os.path.join(boss_cache, f'{clean_id}.jpg')
    if os.path.exists(cached_path):
        return Image.open(cached_path).convert('RGB')
    
    # Check boss_art_cache with other names
    for cand in [f'{hid}.jpg', f'CORE_{clean_id}.jpg', f'VAN_{clean_id}.jpg']:
        p = os.path.join(boss_cache, cand)
        if os.path.exists(p):
            return Image.open(p).convert('RGB')
            
    # Check art_cache
    for cand in [f'{hid}.jpg', f'{clean_id}.jpg', f'CORE_{clean_id}.jpg', f'VAN_{clean_id}.jpg']:
        p = os.path.join(ROOT, 'art_cache', cand)
        if os.path.exists(p):
            img = Image.open(p).convert('RGB')
            img.save(cached_path)
            return img

    # Check render_cache_512
    for cand in [f'{hid}_512.png', f'{clean_id}_512.png', f'CORE_{clean_id}_512.png', f'VAN_{clean_id}_512.png']:
        p = os.path.join(ROOT, 'render_cache_512', cand)
        if os.path.exists(p):
            rimg = Image.open(p).convert('RGB')
            # minion portrait area
            crop = rimg.crop((128, 88, 384, 344))
            crop.save(cached_path)
            return crop

    # Download from Hearthstone art API
    url = f'https://art.hearthstonejson.com/v1/512x/{clean_id}.jpg'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = resp.read()
        with open(cached_path, 'wb') as f:
            f.write(data)
        return Image.open(cached_path).convert('RGB')

def create_blind_token(src_img, size):
    # render at 4x for super-smooth antialiasing
    scale = 4
    s = size * scale
    token = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    
    # crop center square of src_img
    w, h = src_img.size
    min_d = min(w, h)
    left = (w - min_d) // 2
    top = (h - min_d) // 2
    square = src_img.crop((left, top, left + min_d, top + min_d)).resize((s, s), Image.Resampling.LANCZOS)
    
    # circular mask
    mask = Image.new('L', (s, s), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, s - 1, s - 1), fill=255)
    
    token.paste(square, (0, 0), mask)
    
    # gold border
    draw_token = ImageDraw.Draw(token)
    border_w = int(2.5 * scale * (size / 34.0))
    # outer gold ring
    draw_token.ellipse((border_w//2, border_w//2, s - 1 - border_w//2, s - 1 - border_w//2), outline=(245, 195, 35, 255), width=border_w)
    # inner dark highlight
    draw_token.ellipse((border_w, border_w, s - 1 - border_w, s - 1 - border_w), outline=(130, 95, 20, 200), width=scale)
    
    return token.resize((size, size), Image.Resampling.LANCZOS)

# Build atlases
total_blinds = len(blinds)
frames = 21

sheet_1x = Image.new('RGBA', (34 * frames, 34 * total_blinds), (0, 0, 0, 0))
sheet_2x = Image.new('RGBA', (68 * frames, 68 * total_blinds), (0, 0, 0, 0))

for idx, b in enumerate(blinds):
    src = get_blind_image(b)
    t1 = create_blind_token(src, 34)
    t2 = create_blind_token(src, 68)
    
    for f in range(frames):
        sheet_1x.paste(t1, (f * 34, idx * 34))
        sheet_2x.paste(t2, (f * 68, idx * 68))
    print(f"[{idx+1}/{total_blinds}] Built {b['key']}")

p1x = os.path.join(ROOT, 'assets', '1x', 'blinds.png')
p2x = os.path.join(ROOT, 'assets', '2x', 'blinds.png')
sheet_1x.save(p1x)
sheet_2x.save(p2x)

# Also update bosses.png just in case anything refers to it
sheet_1x.save(os.path.join(ROOT, 'assets', '1x', 'bosses.png'))
sheet_2x.save(os.path.join(ROOT, 'assets', '2x', 'bosses.png'))

print(f"Saved 1x: {sheet_1x.size} to {p1x}")
print(f"Saved 2x: {sheet_2x.size} to {p2x}")
