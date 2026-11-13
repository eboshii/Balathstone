"""
Balathstone Cinematic Trailer B-Roll Generator
Renders 1080p 30fps MP4 clips showcasing key synergies, boss combat,
and card packs, then compiles them into a trailer reel.
"""

import os
import math
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import imageio.v3 as iio

WIDTH = 1920
HEIGHT = 1088
FPS = 30

# Load catalogs and assets
with open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'test_output', 'reports', 'cards_catalog.json'), 'r', encoding='utf-8') as f:
    CATALOG = json.load(f)

MINIONS_ATLAS = Image.open('assets/2x/minions.png').convert('RGBA')
SPELLS_ATLAS = Image.open('assets/2x/consumables.png').convert('RGBA')
PACKS_ATLAS = Image.open('assets/2x/packs.png').convert('RGBA')
DECKS_ATLAS = Image.open('assets/2x/decks.png').convert('RGBA')

TILE_W = 284
TILE_H = 380

FONT_PATH = 'assets/fonts/belwe-bd-bt-bold.ttf'

def get_font(size):
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except Exception:
        return ImageFont.load_default()

FONT_TITLE = get_font(52)
FONT_SUB = get_font(32)
FONT_CARD = get_font(26)
FONT_STAT = get_font(34)
FONT_HUD = get_font(40)

# Card slice helper
def get_card_sprite(atlas, pos_x, pos_y):
    box = (pos_x * TILE_W, pos_y * TILE_H, (pos_x + 1) * TILE_W, (pos_y + 1) * TILE_H)
    return atlas.crop(box)

def get_minion_sprite(mid):
    info = CATALOG['minions'].get(mid)
    if not info:
        return Image.new('RGBA', (TILE_W, TILE_H), (50, 50, 50, 255))
    return get_card_sprite(MINIONS_ATLAS, info['pos']['x'], info['pos']['y'])

def get_spell_sprite(sid):
    info = CATALOG['spells'].get(sid)
    if not info:
        return Image.new('RGBA', (TILE_W, TILE_H), (50, 50, 50, 255))
    return get_card_sprite(SPELLS_ATLAS, info['pos']['x'], info['pos']['y'])

def get_pack_sprite(col, row):
    return get_card_sprite(PACKS_ATLAS, col, row)

def get_deck_sprite(col, row):
    return get_card_sprite(DECKS_ATLAS, col, row)

# Background generation
def create_balatro_felt():
    im = Image.new('RGBA', (WIDTH, HEIGHT), (22, 68, 48, 255))
    # Subtle gradient vignette
    x = np.linspace(-1, 1, WIDTH)
    y = np.linspace(-1, 1, HEIGHT)
    xx, yy = np.meshgrid(x, y)
    rad = np.sqrt(xx**2 + yy**2)
    vignette = np.clip(1.0 - rad * 0.45, 0.45, 1.0)
    arr = np.array(im, dtype=np.float32)
    for c in range(3):
        arr[:, :, c] *= vignette
    # Add subtle felt noise texture
    noise = np.random.normal(0, 3.5, (HEIGHT, WIDTH, 1))
    arr[:, :, :3] = np.clip(arr[:, :, :3] + noise, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))

FELT_BG = create_balatro_felt()

# Draw visual effects matching Balathstone engine
def draw_taunt(im, w, h):
    draw = ImageDraw.Draw(im)
    pad = int(w * 0.04)
    # Outer wood/bronze frame
    draw.rounded_rectangle([-pad, -pad, w + pad, h + pad], radius=int(w * 0.1), outline=(95, 85, 70, 240), width=int(w * 0.065))
    draw.rounded_rectangle([-pad, -pad, w + pad, h + pad], radius=int(w * 0.1), outline=(185, 170, 140, 240), width=int(w * 0.022))
    # Crest
    cx, cy, s = w // 2, -pad, int(w * 0.13)
    pts = [(cx - s, cy - int(s * 0.55)), (cx + s, cy - int(s * 0.55)), (cx + int(s * 0.9), cy + int(s * 0.45)),
           (cx, cy + int(s * 1.05)), (cx - int(s * 0.9), cy + int(s * 0.45))]
    draw.polygon(pts, fill=(110, 95, 80, 255), outline=(205, 185, 155, 255))

def draw_divine_shield(im, w, h, t):
    p = 0.5 + 0.5 * math.sin(t * 2.6)
    pad = int(w * 0.06)
    overlay = Image.new('RGBA', (w + pad*2, h + pad*2), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    alpha_fill = int(35 + 20 * p)
    alpha_line = int(160 + 80 * p)
    d.rounded_rectangle([0, 0, w + pad*2, h + pad*2], radius=int(w * 0.14), fill=(255, 220, 90, alpha_fill), outline=(255, 235, 130, alpha_line), width=int(w * 0.03))
    # Highlight gleam
    hx = int((w + pad*2) * ((t * 0.35) % 1.0))
    d.ellipse([hx - 15, int(h * 0.15) - 20, hx + 15, int(h * 0.15) + 20], fill=(255, 255, 220, 90))
    im.alpha_composite(overlay, (-pad, -pad))

def draw_ready(im, w, h, t):
    p = 0.5 + 0.5 * math.sin(t * 4.0)
    draw = ImageDraw.Draw(im)
    draw.rounded_rectangle([-int(w*0.02), -int(w*0.02), int(w*1.02), int(h*1.02)], radius=int(w * 0.08), outline=(65, 255, 75, int(140 + 100 * p)), width=int(w * 0.035))

def draw_windfury(im, w, h, t):
    draw = ImageDraw.Draw(im)
    cx, cy = w // 2, int(h * 0.45)
    r = int(w * 0.6)
    for i in range(3):
        a = t * 2.4 + i * (2 * math.pi / 3)
        deg_start = int(math.degrees(a))
        draw.arc([cx - r, cy - r, cx + r, cy + r], start=deg_start, end=deg_start + 55, fill=(220, 245, 255, 190), width=int(w * 0.03))

def draw_frozen_blind(im, cx, cy, r, t):
    draw = ImageDraw.Draw(im)
    pulse = 0.5 + 0.5 * math.sin(t * 2.8)
    # 1. Cyan Frost tint
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(55, 175, 255, int(90 + 35 * pulse)))
    # 2. Ice shards along bottom rim
    shards = [
        (-0.34, 0.28, 0.14, 0.42),
        (-0.21, 0.35, 0.13, 0.50),
        (-0.07, 0.38, 0.16, 0.56),
        ( 0.08, 0.36, 0.14, 0.52),
        ( 0.22, 0.32, 0.14, 0.45),
        ( 0.33, 0.25, 0.12, 0.38),
    ]
    for sx, sy, sw, sh in shards:
        bx = cx + int(sx * r * 2)
        by = cy + int(sy * r * 2)
        sw_px = int(sw * r * 2)
        sh_px = int(sh * r * 2)
        pts_l = [(bx - sw_px // 2, by), (bx, by - sh_px), (bx, by)]
        pts_r = [(bx, by), (bx, by - sh_px), (bx + sw_px // 2, by)]
        draw.polygon(pts_l, fill=(30, 110, 210, 225), outline=(230, 250, 255, 240))
        draw.polygon(pts_r, fill=(195, 235, 255, 235), outline=(230, 250, 255, 240))
    # 3. Ice cracks
    draw.line([cx - int(r*0.6), cy - int(r*0.2), cx - int(r*0.2), cy + int(r*0.1), cx + int(r*0.1), cy - int(r*0.15), cx + int(r*0.65), cy + int(r*0.1)], fill=(215, 245, 255, 220), width=4)
    draw.line([cx - int(r*0.2), cy + int(r*0.1), cx - int(r*0.1), cy + int(r*0.5)], fill=(215, 245, 255, 220), width=3)
    # 4. Outer frost ring
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(165, 230, 255, int(180 + 50 * pulse)), width=6)

def draw_stat_badges(card_im, atk, hp, x_mult=None, base_atk=None, base_hp=None):
    w, h = card_im.size
    draw = ImageDraw.Draw(card_im)
    font = get_font(int(h * 0.11))
    
    # 1. Attack badge (bottom-left)
    ax, ay = int(w * 0.153), int(h * 0.914)
    rad = int(w * 0.085)
    draw.ellipse([ax - rad, ay - rad, ax + rad, ay + rad], fill=(215, 155, 30, 255), outline=(60, 40, 10, 255), width=2)
    atk_col = (255, 255, 255, 255)
    if base_atk is not None:
        atk_col = (55, 235, 65, 255) if atk > base_atk else ((245, 55, 55, 255) if atk < base_atk else (255, 255, 255, 255))
    text_atk = str(atk)
    bbox = font.getbbox(text_atk)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    # Outline text
    for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1), (-1, 1), (1, -1)]:
        draw.text((ax - tw // 2 + ox, ay - th // 2 - 3 + oy), text_atk, font=font, fill=(0, 0, 0, 255))
    draw.text((ax - tw // 2, ay - th // 2 - 3), text_atk, font=font, fill=atk_col)

    # 2. Health badge (bottom-right)
    hx, hy = int(w * 0.874), int(h * 0.912)
    draw.ellipse([hx - rad, hy - rad, hx + rad, hy + rad], fill=(160, 20, 20, 255), outline=(50, 10, 10, 255), width=2)
    hp_col = (255, 255, 255, 255)
    if base_hp is not None:
        hp_col = (55, 235, 65, 255) if hp > base_hp else ((245, 55, 55, 255) if hp < base_hp else (255, 255, 255, 255))
    text_hp = str(hp)
    bbox = font.getbbox(text_hp)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1), (-1, 1), (1, -1)]:
        draw.text((hx - tw // 2 + ox, hy - th // 2 - 3 + oy), text_hp, font=font, fill=(0, 0, 0, 255))
    draw.text((hx - tw // 2, hy - th // 2 - 3), text_hp, font=font, fill=hp_col)

    # 3. New Crimson X-Mult badge (bottom-center)
    if x_mult and x_mult > 1:
        xm_str = f"X{x_mult:.2f}".rstrip('0').rstrip('.')
        mx, my = int(w * 0.514), int(h * 0.913)
        bbox = font.getbbox(xm_str)
        tw = bbox[2] - bbox[0]
        bw = max(int(w * 0.22), tw + int(w * 0.08))
        bh = int(w * 0.17)
        br = int(bh * 0.45)
        # Outer dark shadow
        draw.rounded_rectangle([mx - bw//2 - 2, my - bh//2 - 2, mx + bw//2 + 2, my + bh//2 + 2], radius=br, fill=(30, 20, 20, 240))
        # Gold frame
        draw.rounded_rectangle([mx - bw//2, my - bh//2, mx + bw//2, my + bh//2], radius=br, fill=(225, 175, 40, 255))
        # Crimson mult fill
        draw.rounded_rectangle([mx - bw//2 + 2, my - bh//2 + 2, mx + bw//2 - 2, my + bh//2 - 2], radius=br - 2, fill=(215, 40, 55, 255))
        # Text
        for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
            draw.text((mx - tw // 2 + ox, my - (bbox[3] - bbox[1]) // 2 - 3 + oy), xm_str, font=font, fill=(0, 0, 0, 255))
        draw.text((mx - tw // 2, my - (bbox[3] - bbox[1]) // 2 - 3), xm_str, font=font, fill=(255, 255, 255, 255))

def draw_top_hud(im, title, ante=3, round_num=6, hands=4, discards=3, dollars=30):
    draw = ImageDraw.Draw(im)
    # Header bar
    draw.rectangle([0, 0, WIDTH, 85], fill=(15, 25, 20, 230))
    draw.line([0, 85, WIDTH, 85], fill=(80, 160, 110, 255), width=3)
    
    # Title / Mod name
    draw.text((40, 18), "BALATHSTONE", font=FONT_TITLE, fill=(255, 215, 80, 255))
    draw.text((420, 28), f"|  {title}", font=FONT_SUB, fill=(220, 235, 220, 255))
    
    # HUD stats
    stats_x = WIDTH - 680
    # Money
    draw.text((stats_x, 24), f"${dollars}", font=FONT_HUD, fill=(255, 225, 60, 255))
    # Hands
    draw.text((stats_x + 160, 24), f"Hands: {hands}", font=FONT_CARD, fill=(80, 190, 255, 255))
    # Discards
    draw.text((stats_x + 320, 24), f"Discards: {discards}", font=FONT_CARD, fill=(255, 110, 80, 255))
    # Ante
    draw.text((stats_x + 500, 24), f"Ante: {ante}/8", font=FONT_CARD, fill=(255, 255, 255, 255))

def draw_lower_banner(im, headline, subline):
    draw = ImageDraw.Draw(im)
    bx, by, bw, bh = 140, HEIGHT - 130, WIDTH - 280, 100
    # Pill banner with gold gradient
    draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=25, fill=(12, 18, 15, 235), outline=(230, 185, 55, 255), width=4)
    # Texts
    h_box = FONT_TITLE.getbbox(headline)
    draw.text((WIDTH // 2 - (h_box[2] - h_box[0]) // 2, by + 12), headline, font=FONT_TITLE, fill=(255, 225, 75, 255))
    s_box = FONT_SUB.getbbox(subline)
    draw.text((WIDTH // 2 - (s_box[2] - s_box[0]) // 2, by + 62), subline, font=FONT_SUB, fill=(220, 240, 230, 255))


# =============================================================================
# SCENE 1: The Murloc Swarm & Battlecry Storm
# =============================================================================
def render_scene_1(out_path):
    print("Rendering Scene 1: Murloc Swarm & Battlecry Storm...")
    minion_ids = [
        ('brann_bronzebeard', 2, 4, None),
        ('murloc_warleader', 3, 3, None),
        ('murloc_tidehunter', 4, 1, None),
        ('murloc_scout', 3, 1, None),
        ('grim_patron', 3, 3, None),
        ('shudderwock', 6, 6, None),
    ]
    
    n_frames = 120
    frames = []
    
    for f in range(n_frames):
        t = f / FPS
        im = FELT_BG.copy()
        draw_top_hud(im, "Murloc Swarm & Battlecry Cascades", ante=4, round_num=8, dollars=24)
        
        # 6 Minions in center row (scale: 0.65)
        scale = 0.62
        cw, ch = int(TILE_W * scale), int(TILE_H * scale)
        spacing = cw + 22
        start_x = (WIDTH - (len(minion_ids) * spacing - 22)) // 2
        base_y = 380
        
        draw = ImageDraw.Draw(im)
        
        for i, (mid, atk, hp, xm) in enumerate(minion_ids):
            bob = int(math.sin(t * 3.0 + i * 0.9) * 8)
            card_x = start_x + i * spacing
            card_y = base_y + bob
            
            # Card image
            raw = get_minion_sprite(mid).copy()
            # If warleader is on board, murlocs gain +2 attack
            cur_atk = atk + (2 if 'murloc' in mid and mid != 'murloc_warleader' else 0)
            draw_stat_badges(raw, cur_atk, hp, x_mult=xm, base_atk=atk, base_hp=hp)
            
            # Shudderwock lightning bolts
            if mid == 'shudderwock':
                # Shimmer aura
                draw_ready(raw, raw.width, raw.height, t)
            elif mid == 'grim_patron':
                pass
            elif mid == 'murloc_warleader':
                draw_ready(raw, raw.width, raw.height, t * 0.8)
                
            card_scaled = raw.resize((cw, ch), Image.Resampling.LANCZOS)
            
            # Shadow
            im.paste((0, 0, 0, 140), (card_x + 10, card_y + 16, card_x + cw + 10, card_y + ch + 16), mask=card_scaled.split()[3])
            im.alpha_composite(card_scaled, (card_x, card_y))
            
            # Name tag below
            name = CATALOG['minions'].get(mid, {}).get('name', mid)
            bbox = FONT_CARD.getbbox(name)
            draw.text((card_x + cw//2 - (bbox[2] - bbox[0])//2, card_y + ch + 8), name, font=FONT_CARD, fill=(240, 240, 240, 255))
        
        # Battlecry Lightning Sparks over Shudderwock & Brann
        sw_x = start_x + 5 * spacing + cw // 2
        sw_y = base_y + ch // 2
        spark_phase = (f % 15) / 15.0
        if spark_phase < 0.6:
            for s in range(5):
                angle = s * (2 * math.pi / 5) + t * 4
                dist = 70 + int(30 * math.sin(t * 8 + s))
                px = sw_x + int(math.cos(angle) * dist)
                py = sw_y + int(math.sin(angle) * dist)
                draw.ellipse([px - 6, py - 6, px + 6, py + 6], fill=(255, 235, 90, 240))
        
        # Scoring simulation text
        score_val = int(48000 + f * 1250)
        draw.text((WIDTH // 2 - 200, 200), f"ROUND SCORE: {score_val:,}", font=FONT_TITLE, fill=(110, 230, 255, 255))
        draw.text((WIDTH // 2 - 170, 260), "Battlecry x2! Murloc Aura Active!", font=FONT_SUB, fill=(255, 180, 80, 255))
        
        draw_lower_banner(im, "AUTHENTIC HEARTHSTONE TRIBES & SYNERGIES", "Brann doubles Battlecries  *  Shudderwock repeats the board  *  Murlocs swarm")
        frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, frames, fps=FPS)
    print(f"Saved: {out_path}")


# =============================================================================
# SCENE 2: Legendary God-Board & Spell Barrage
# =============================================================================
def render_scene_2(out_path):
    print("Rendering Scene 2: Legendary God-Board & Spell Barrage...")
    minion_ids = [
        ('tirion_fordring', 6, 6, None, 'taunt_shield'),
        ('archmage_antonidas', 5, 7, None, None),
        ('reno_jackson', 4, 6, None, None),
        ('kelthuzad', 6, 8, None, None),
        ('yogg_saron_hopes_end', 7, 5, None, None),
    ]
    spells = [('fireball', 'Fireball'), ('lay_on_hands', 'Lay on Hands'), ('frostbolt', 'Frostbolt')]
    
    n_frames = 120
    frames = []
    
    for f in range(n_frames):
        t = f / FPS
        im = FELT_BG.copy()
        draw_top_hud(im, "Legendary Power & Spell Combos", ante=6, round_num=14, dollars=30)
        
        scale = 0.68
        cw, ch = int(TILE_W * scale), int(TILE_H * scale)
        spacing = cw + 30
        start_x = 120
        base_y = 360
        
        draw = ImageDraw.Draw(im)
        
        # Draw Minions
        for i, (mid, atk, hp, xm, fx) in enumerate(minion_ids):
            bob = int(math.sin(t * 2.5 + i * 0.8) * 7)
            card_x = start_x + i * spacing
            card_y = base_y + bob
            
            raw = get_minion_sprite(mid).copy()
            draw_stat_badges(raw, atk, hp, x_mult=xm, base_atk=atk, base_hp=hp)
            
            if fx == 'taunt_shield':
                draw_taunt(raw, raw.width, raw.height)
                draw_divine_shield(raw, raw.width, raw.height, t)
            
            card_scaled = raw.resize((cw, ch), Image.Resampling.LANCZOS)
            im.paste((0, 0, 0, 140), (card_x + 10, card_y + 16, card_x + cw + 10, card_y + ch + 16), mask=card_scaled.split()[3])
            im.alpha_composite(card_scaled, (card_x, card_y))
            
            name = CATALOG['minions'].get(mid, {}).get('name', mid)
            bbox = FONT_CARD.getbbox(name)
            draw.text((card_x + cw//2 - (bbox[2] - bbox[0])//2, card_y + ch + 8), name, font=FONT_CARD, fill=(240, 240, 240, 255))
        
        # Draw Consumables / Spells on right
        cons_x = WIDTH - 340
        cons_scale = 0.52
        scw, sch = int(TILE_W * cons_scale), int(TILE_H * cons_scale)
        for j, (sid, sname) in enumerate(spells):
            sy = 220 + j * (sch + 20)
            s_raw = get_spell_sprite(sid).copy()
            s_scaled = s_raw.resize((scw, sch), Image.Resampling.LANCZOS)
            im.paste((0, 0, 0, 140), (cons_x + 8, sy + 12, cons_x + scw + 8, sy + sch + 12), mask=s_scaled.split()[3])
            im.alpha_composite(s_scaled, (cons_x, sy))
            bbox = FONT_CARD.getbbox(sname)
            draw.text((cons_x + scw//2 - (bbox[2] - bbox[0])//2, sy + sch + 4), sname, font=FONT_CARD, fill=(255, 215, 80, 255))

        # Fireball spell projectile streak
        proj_p = (f % 40) / 40.0
        proj_x = int(cons_x + (WIDTH // 2 - cons_x) * proj_p)
        proj_y = int(240 + math.sin(proj_p * math.pi) * -120)
        draw.line([proj_x - 40, proj_y, proj_x + 20, proj_y], fill=(255, 120, 20, 240), width=12)
        draw.line([proj_x - 20, proj_y, proj_x + 20, proj_y], fill=(255, 240, 120, 255), width=6)
        for sp in range(4):
            draw.circle((proj_x - 30 - sp * 8, proj_y + int(math.sin(f + sp)*6)), 4, fill=(255, 180, 40, 200))
            
        draw.text((WIDTH // 2 - 280, 170), "ANTONIDAS GENERATES INFINITE FIREBALLS", font=FONT_SUB, fill=(255, 160, 60, 255))
        draw_lower_banner(im, "COMMAND ICONIC LEGENDARIES & SPELL COMBOS", "Divine Shield & Taunt defense  *  Reno heals to $30  *  Yogg casts wild spells")
        frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, frames, fps=FPS)
    print(f"Saved: {out_path}")


# =============================================================================
# SCENE 3: Maximum X-Mult Overkill & Crimson Badges
# =============================================================================
def render_scene_3(out_path):
    print("Rendering Scene 3: Maximum X-Mult Overkill & Crimson Badges...")
    minion_ids = [
        ('leeroy_jenkins', 6, 2, 2.0, 'rush'),
        ('raid_leader', 4, 4, 2.0, None),          # Blessed Champion
        ('dire_wolf_alpha', 4, 5, 1.5, None),      # Apotheosis
        ('zilliax', 3, 2, 1.5, 'divine_taunt'),    # Magnetic + Survival
    ]
    
    n_frames = 120
    frames = []
    
    for f in range(n_frames):
        t = f / FPS
        im = FELT_BG.copy()
        draw_top_hud(im, "Exponential X-Mult Multipliers", ante=7, round_num=18, dollars=28)
        
        scale = 0.76
        cw, ch = int(TILE_W * scale), int(TILE_H * scale)
        spacing = cw + 40
        start_x = (WIDTH - (len(minion_ids) * spacing - 40)) // 2
        base_y = 350
        
        draw = ImageDraw.Draw(im)
        
        for i, (mid, atk, hp, xm, fx) in enumerate(minion_ids):
            bob = int(math.sin(t * 3.5 + i * 1.1) * 8)
            card_x = start_x + i * spacing
            card_y = base_y + bob
            
            raw = get_minion_sprite(mid).copy()
            draw_stat_badges(raw, atk, hp, x_mult=xm, base_atk=atk - 2 if xm else atk, base_hp=hp)
            
            if fx == 'rush':
                draw_ready(raw, raw.width, raw.height, t)
            elif fx == 'divine_taunt':
                draw_taunt(raw, raw.width, raw.height)
                draw_divine_shield(raw, raw.width, raw.height, t)
            
            card_scaled = raw.resize((cw, ch), Image.Resampling.LANCZOS)
            im.paste((0, 0, 0, 150), (card_x + 12, card_y + 18, card_x + cw + 12, card_y + ch + 18), mask=card_scaled.split()[3])
            im.alpha_composite(card_scaled, (card_x, card_y))
            
            name = CATALOG['minions'].get(mid, {}).get('name', mid)
            bbox = FONT_CARD.getbbox(name)
            draw.text((card_x + cw//2 - (bbox[2] - bbox[0])//2, card_y + ch + 12), name, font=FONT_CARD, fill=(240, 240, 240, 255))
        
        # Scoring popups
        score_chips = 450
        score_mult = int(80 * (2.0 ** (min(f, 60) / 20.0)))
        total = score_chips * score_mult
        
        draw.text((WIDTH // 2 - 280, 160), f"HAND SCORE: {total:,}", font=FONT_TITLE, fill=(255, 95, 105, 255))
        draw.text((WIDTH // 2 - 240, 230), f"Chips: {score_chips}   x   Mult: X{score_mult:,}", font=FONT_SUB, fill=(255, 230, 90, 255))
        
        draw_lower_banner(im, "STACK GAME-BREAKING X-MULT MULTIPLIERS", "Blessed Champion X2 Mult  *  Survival of the Fittest X1.5  *  Permanent Crimson Badges")
        frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, frames, fps=FPS)
    print(f"Saved: {out_path}")


# =============================================================================
# SCENE 4: Boss Encounter & Tactical Freezing
# =============================================================================
def render_scene_4(out_path):
    print("Rendering Scene 4: Boss Encounter & Tactical Freezing...")
    minion_ids = [
        ('tirion_fordring', 6, 6, None, 'taunt_shield'),
        ('grim_patron', 3, 3, None, 'ready'),
        ('dr_boom', 7, 7, None, None),
        ('boom_bot', 1, 1, None, 'deathrattle'),
    ]
    
    n_frames = 120
    frames = []
    
    for f in range(n_frames):
        t = f / FPS
        im = FELT_BG.copy()
        draw_top_hud(im, "Boss Showdown: Loatheb (FROZEN)", ante=8, round_num=24, dollars=30)
        
        draw = ImageDraw.Draw(im)
        
        # Draw Boss Blind at the top center
        boss_cx, boss_cy, boss_r = WIDTH // 2, 230, 95
        # Outer boss shadow & token
        draw.ellipse([boss_cx - boss_r - 6, boss_cy - boss_r - 6, boss_cx + boss_r + 6, boss_cy + boss_r + 6], fill=(20, 10, 15, 220))
        draw.ellipse([boss_cx - boss_r, boss_cy - boss_r, boss_cx + boss_r, boss_cy + boss_r], fill=(130, 30, 45, 255), outline=(245, 185, 55, 255), width=6)
        
        # Boss skull & text
        draw.text((boss_cx - 65, boss_cy - 40), "BOSS", font=FONT_TITLE, fill=(255, 255, 255, 255))
        draw.text((boss_cx - 75, boss_cy + 15), "LOATHEB", font=FONT_CARD, fill=(255, 215, 80, 255))
        
        # Authentic Frozen effect over boss!
        draw_frozen_blind(im, boss_cx, boss_cy, boss_r, t)
        draw.text((boss_cx - 90, boss_cy + boss_r + 14), "FROZEN (Can't Attack!)", font=FONT_CARD, fill=(120, 230, 255, 255))
        
        # Draw defending Minions
        scale = 0.70
        cw, ch = int(TILE_W * scale), int(TILE_H * scale)
        spacing = cw + 36
        start_x = (WIDTH - (len(minion_ids) * spacing - 36)) // 2
        base_y = 440
        
        for i, (mid, atk, hp, xm, fx) in enumerate(minion_ids):
            bob = int(math.sin(t * 3.0 + i * 0.9) * 6)
            card_x = start_x + i * spacing
            card_y = base_y + bob
            
            raw = get_minion_sprite(mid).copy()
            draw_stat_badges(raw, atk, hp, x_mult=xm, base_atk=atk, base_hp=hp)
            
            if fx == 'taunt_shield':
                draw_taunt(raw, raw.width, raw.height)
                draw_divine_shield(raw, raw.width, raw.height, t)
            elif fx == 'ready':
                draw_ready(raw, raw.width, raw.height, t)
            
            card_scaled = raw.resize((cw, ch), Image.Resampling.LANCZOS)
            im.paste((0, 0, 0, 140), (card_x + 10, card_y + 16, card_x + cw + 10, card_y + ch + 16), mask=card_scaled.split()[3])
            im.alpha_composite(card_scaled, (card_x, card_y))
            
            name = CATALOG['minions'].get(mid, {}).get('name', mid)
            bbox = FONT_CARD.getbbox(name)
            draw.text((card_x + cw//2 - (bbox[2] - bbox[0])//2, card_y + ch + 8), name, font=FONT_CARD, fill=(240, 240, 240, 255))
            
        # Attack Clash FX on Boss
        impact_f = f % 30
        if impact_f < 15:
            p = impact_f / 15.0
            # Double slash lines
            draw.line([boss_cx - 90, boss_cy - 90, boss_cx + 90, boss_cy + 90], fill=(255, 60, 60, int(255 * (1 - p))), width=8)
            draw.line([boss_cx + 90, boss_cy - 90, boss_cx - 90, boss_cy + 90], fill=(255, 230, 80, int(255 * (1 - p))), width=5)
            # Hit sparks
            for s in range(6):
                sa = s * math.pi / 3
                sd = int(30 + p * 80)
                draw.circle((boss_cx + int(math.cos(sa)*sd), boss_cy + int(math.sin(sa)*sd)), 5, fill=(255, 240, 120, int(255 * (1 - p))))
                
        draw_lower_banner(im, "TACTICAL COMBAT & AUTHENTIC FROZEN BLINDS", "Frostbolt freezes Boss Blinds  *  Taunt deflects damage  *  Minions strike back")
        frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, frames, fps=FPS)
    print(f"Saved: {out_path}")


# =============================================================================
# SCENE 5: Authentic Hearthstone Packs & Discover
# =============================================================================
def render_scene_5(out_path):
    print("Rendering Scene 5: Authentic Hearthstone Packs & Discover...")
    # (col, row, Pack Name, Pack Type)
    packs_info = [
        (0, 0, "Scholomance Academy", "Spell Pack"),
        (0, 1, "TITANS", "Location Pack"),
        (0, 2, "Whispers of the Old Gods", "Forbidden Pack"),
        (0, 4, "Darkmoon Faire", "Minion Pack"),
    ]
    
    n_frames = 120
    frames = []
    
    for f in range(n_frames):
        t = f / FPS
        im = FELT_BG.copy()
        draw_top_hud(im, "Expansion Card Packs & Discover Selection", ante=2, round_num=4, dollars=16)
        
        scale = 0.78
        cw, ch = int(TILE_W * scale), int(TILE_H * scale)
        spacing = cw + 48
        start_x = (WIDTH - (len(packs_info) * spacing - 48)) // 2
        base_y = 350
        
        draw = ImageDraw.Draw(im)
        
        for i, (col, row, pack_name, pack_type) in enumerate(packs_info):
            # Gentle hover tilt/bob
            bob = int(math.sin(t * 2.8 + i * 0.9) * 10)
            pack_x = start_x + i * spacing
            pack_y = base_y + bob
            
            pack_raw = get_pack_sprite(col, row).copy()
            pack_scaled = pack_raw.resize((cw, ch), Image.Resampling.LANCZOS)
            
            # Shadow
            im.paste((0, 0, 0, 150), (pack_x + 12, pack_y + 18, pack_x + cw + 12, pack_y + ch + 18), mask=pack_scaled.split()[3])
            im.alpha_composite(pack_scaled, (pack_x, pack_y))
            
            # Pack Names & Types
            bbox_type = FONT_CARD.getbbox(pack_type)
            draw.text((pack_x + cw//2 - (bbox_type[2] - bbox_type[0])//2, pack_y + ch + 10), pack_type, font=FONT_CARD, fill=(255, 215, 80, 255))
            bbox_name = FONT_CARD.getbbox(pack_name)
            draw.text((pack_x + cw//2 - (bbox_name[2] - bbox_name[0])//2, pack_y + ch + 38), pack_name, font=FONT_CARD, fill=(220, 220, 220, 255))

        draw.text((WIDTH // 2 - 290, 190), "OPEN EXPANSION PACKS & CHOOSE YOUR REWARDS", font=FONT_SUB, fill=(255, 235, 110, 255))
        draw_lower_banner(im, "AUTHENTIC HEARTHSTONE EXPANSION ART", "Scholomance Spells  *  TITANS Locations  *  Darkmoon Minions  *  Old Gods Spectrals")
        frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, frames, fps=FPS)
    print(f"Saved: {out_path}")


# =============================================================================
# SCENE 6: Full Trailer Sizzle Reel Compiler
# =============================================================================
def compile_sizzle_reel(clips, out_path):
    print("Compiling full trailer sizzle reel...")
    all_frames = []
    
    # Render Intro Title (60 frames / 2.0s)
    for f in range(60):
        t = f / FPS
        im = FELT_BG.copy()
        draw = ImageDraw.Draw(im)
        
        # Center logo
        title = "BALATHSTONE"
        sub = "THE HEARTHSTONE TOTAL CONVERSION FOR BALATRO"
        t_box = FONT_TITLE.getbbox(title)
        draw.text((WIDTH // 2 - (t_box[2] - t_box[0]) // 2, HEIGHT // 2 - 90), title, font=FONT_TITLE, fill=(255, 220, 70, 255))
        s_box = FONT_SUB.getbbox(sub)
        draw.text((WIDTH // 2 - (s_box[2] - s_box[0]) // 2, HEIGHT // 2 + 5), sub, font=FONT_SUB, fill=(230, 240, 230, 255))
        
        badge = "166 MINIONS  *  75 SPELLS  *  AUTHENTIC PACKS & COMBAT"
        b_box = FONT_CARD.getbbox(badge)
        draw.text((WIDTH // 2 - (b_box[2] - b_box[0]) // 2, HEIGHT // 2 + 75), badge, font=FONT_CARD, fill=(120, 220, 255, 255))
        
        all_frames.append(np.array(im.convert('RGB')))
        
    # Append all scene clips
    for clip_path in clips:
        print(f"Adding {clip_path}...")
        frames = iio.imread(clip_path)
        for frame in frames:
            if frame.shape[0] != HEIGHT or frame.shape[1] != WIDTH:
                padded = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
                h_copy = min(HEIGHT, frame.shape[0])
                w_copy = min(WIDTH, frame.shape[1])
                padded[:h_copy, :w_copy] = frame[:h_copy, :w_copy]
                all_frames.append(padded)
            else:
                all_frames.append(frame)
            
    # Render Outro Title (60 frames / 2.0s)
    for f in range(60):
        im = FELT_BG.copy()
        draw = ImageDraw.Draw(im)
        title = "PLAY BALATHSTONE NOW"
        sub = "Total Conversion Mod for Balatro  *  Steamodded Compatible"
        t_box = FONT_TITLE.getbbox(title)
        draw.text((WIDTH // 2 - (t_box[2] - t_box[0]) // 2, HEIGHT // 2 - 60), title, font=FONT_TITLE, fill=(255, 220, 70, 255))
        s_box = FONT_SUB.getbbox(sub)
        draw.text((WIDTH // 2 - (s_box[2] - s_box[0]) // 2, HEIGHT // 2 + 15), sub, font=FONT_SUB, fill=(220, 235, 225, 255))
        all_frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, all_frames, fps=FPS)
    print(f"Full trailer reel compiled successfully to: {out_path}")


if __name__ == '__main__':
    os.makedirs('test_output/trailer', exist_ok=True)
    
    c1 = 'test_output/trailer/scene1_murloc_swarm.mp4'
    c2 = 'test_output/trailer/scene2_legendary_barrage.mp4'
    c3 = 'test_output/trailer/scene3_xmult_overkill.mp4'
    c4 = 'test_output/trailer/scene4_boss_combat.mp4'
    c5 = 'test_output/trailer/scene5_packs_discover.mp4'
    
    if not os.path.exists(c1): render_scene_1(c1)
    if not os.path.exists(c2): render_scene_2(c2)
    if not os.path.exists(c3): render_scene_3(c3)
    if not os.path.exists(c4): render_scene_4(c4)
    if not os.path.exists(c5): render_scene_5(c5)
    
    full_reel = 'test_output/trailer/balathstone_trailer_reel.mp4'
    compile_sizzle_reel([c1, c2, c3, c4, c5], full_reel)
    print("ALL TRAILER FOOTAGE GENERATED SUCCESSFULLY!")
