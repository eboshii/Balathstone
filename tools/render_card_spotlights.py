"""
Balathstone Card Spotlight Generator
Produces cinematic card showcase clips:
1. Card Spotlight (enlarged card + stats & rules tooltip)
2. In-Game Action (battlefield deployment + ability triggers & animations)
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

with open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'test_output', 'reports', 'cards_catalog.json'), 'r', encoding='utf-8') as f:
    CATALOG = json.load(f)

MINIONS_ATLAS = Image.open('assets/2x/minions.png').convert('RGBA')
SPELLS_ATLAS = Image.open('assets/2x/consumables.png').convert('RGBA')

TILE_W = 284
TILE_H = 380

FONT_PATH = 'assets/fonts/belwe-bd-bt-bold.ttf'

def get_font(size):
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except Exception:
        return ImageFont.load_default()

FONT_HERO = get_font(60)
FONT_TITLE = get_font(46)
FONT_SUB = get_font(30)
FONT_CARD = get_font(24)
FONT_STAT = get_font(36)
FONT_DESC = get_font(28)

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

def create_balatro_felt():
    im = Image.new('RGBA', (WIDTH, HEIGHT), (22, 68, 48, 255))
    x = np.linspace(-1, 1, WIDTH)
    y = np.linspace(-1, 1, HEIGHT)
    xx, yy = np.meshgrid(x, y)
    rad = np.sqrt(xx**2 + yy**2)
    vignette = np.clip(1.0 - rad * 0.45, 0.45, 1.0)
    arr = np.array(im, dtype=np.float32)
    for c in range(3):
        arr[:, :, c] *= vignette
    noise = np.random.normal(0, 3.5, (HEIGHT, WIDTH, 1))
    arr[:, :, :3] = np.clip(arr[:, :, :3] + noise, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))

FELT_BG = create_balatro_felt()

def draw_stat_badges(card_im, atk, hp, x_mult=None, base_atk=None, base_hp=None):
    w, h = card_im.size
    draw = ImageDraw.Draw(card_im)
    font = get_font(int(h * 0.11))
    
    # Attack
    ax, ay = int(w * 0.153), int(h * 0.914)
    rad = int(w * 0.085)
    draw.ellipse([ax - rad, ay - rad, ax + rad, ay + rad], fill=(215, 155, 30, 255), outline=(60, 40, 10, 255), width=2)
    atk_col = (255, 255, 255, 255)
    if base_atk is not None:
        atk_col = (55, 235, 65, 255) if atk > base_atk else ((245, 55, 55, 255) if atk < base_atk else (255, 255, 255, 255))
    text_atk = str(atk)
    bbox = font.getbbox(text_atk)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1), (-1, 1), (1, -1)]:
        draw.text((ax - tw // 2 + ox, ay - th // 2 - 3 + oy), text_atk, font=font, fill=(0, 0, 0, 255))
    draw.text((ax - tw // 2, ay - th // 2 - 3), text_atk, font=font, fill=atk_col)

    # Health
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

    # X-Mult
    if x_mult and x_mult > 1:
        xm_str = f"X{x_mult:.2f}".rstrip('0').rstrip('.')
        mx, my = int(w * 0.514), int(h * 0.913)
        bbox = font.getbbox(xm_str)
        tw = bbox[2] - bbox[0]
        bw = max(int(w * 0.22), tw + int(w * 0.08))
        bh = int(w * 0.17)
        br = int(bh * 0.45)
        draw.rounded_rectangle([mx - bw//2 - 2, my - bh//2 - 2, mx + bw//2 + 2, my + bh//2 + 2], radius=br, fill=(30, 20, 20, 240))
        draw.rounded_rectangle([mx - bw//2, my - bh//2, mx + bw//2, my + bh//2], radius=br, fill=(225, 175, 40, 255))
        draw.rounded_rectangle([mx - bw//2 + 2, my - bh//2 + 2, mx + bw//2 - 2, my + bh//2 - 2], radius=br - 2, fill=(215, 40, 55, 255))
        for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
            draw.text((mx - tw // 2 + ox, my - (bbox[3] - bbox[1]) // 2 - 3 + oy), xm_str, font=font, fill=(0, 0, 0, 255))
        draw.text((mx - tw // 2, my - (bbox[3] - bbox[1]) // 2 - 3), xm_str, font=font, fill=(255, 255, 255, 255))

def draw_top_hud(im, title, ante=3, round_num=6, hands=4, discards=3, dollars=30):
    draw = ImageDraw.Draw(im)
    draw.rectangle([0, 0, WIDTH, 85], fill=(15, 25, 20, 230))
    draw.line([0, 85, WIDTH, 85], fill=(80, 160, 110, 255), width=3)
    draw.text((40, 18), "BALATHSTONE", font=FONT_HERO, fill=(255, 215, 80, 255))
    draw.text((470, 28), f"|  {title}", font=FONT_SUB, fill=(220, 235, 220, 255))
    stats_x = WIDTH - 680
    draw.text((stats_x, 24), f"${dollars}", font=FONT_TITLE, fill=(255, 225, 60, 255))
    draw.text((stats_x + 160, 24), f"Hands: {hands}", font=FONT_CARD, fill=(80, 190, 255, 255))
    draw.text((stats_x + 320, 24), f"Discards: {discards}", font=FONT_CARD, fill=(255, 110, 80, 255))
    draw.text((stats_x + 500, 24), f"Ante: {ante}/8", font=FONT_CARD, fill=(255, 255, 255, 255))

def draw_lower_banner(im, headline, subline):
    draw = ImageDraw.Draw(im)
    bx, by, bw, bh = 140, HEIGHT - 130, WIDTH - 280, 100
    draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=25, fill=(12, 18, 15, 235), outline=(230, 185, 55, 255), width=4)
    h_box = FONT_TITLE.getbbox(headline)
    draw.text((WIDTH // 2 - (h_box[2] - h_box[0]) // 2, by + 12), headline, font=FONT_TITLE, fill=(255, 225, 75, 255))
    s_box = FONT_SUB.getbbox(subline)
    draw.text((WIDTH // 2 - (s_box[2] - s_box[0]) // 2, by + 58), subline, font=FONT_SUB, fill=(220, 240, 230, 255))

# Draw the cinematic Card Spotlight screen
def draw_spotlight_frame(im, mid, title_badge, rarity_badge, lines, t):
    draw = ImageDraw.Draw(im)
    
    # 1. Dark spotlight overlay with radial glow
    overlay = Image.new('RGBA', (WIDTH, HEIGHT), (10, 16, 12, 235))
    d_ov = ImageDraw.Draw(overlay)
    
    # Glow behind card
    card_cx, card_cy = 480, 570
    pulse = 0.5 + 0.5 * math.sin(t * 3.0)
    glow_r = int(280 + 30 * pulse)
    for r_i in range(glow_r, 0, -20):
        alpha = int(45 * (1.0 - r_i / glow_r))
        d_ov.ellipse([card_cx - r_i, card_cy - r_i, card_cx + r_i, card_cy + r_i], fill=(255, 215, 80, alpha))
    im.alpha_composite(overlay)
    
    # 2. Top Banner
    draw.rectangle([0, 0, WIDTH, 110], fill=(12, 20, 15, 250))
    draw.line([0, 110, WIDTH, 110], fill=(235, 185, 55, 255), width=4)
    b_box = FONT_HERO.getbbox(title_badge)
    draw.text((WIDTH // 2 - (b_box[2] - b_box[0]) // 2, 22), title_badge, font=FONT_HERO, fill=(255, 225, 75, 255))
    
    # 3. Enlarged Card on Left
    raw = get_minion_sprite(mid).copy()
    info = CATALOG['minions'].get(mid, {'atk': 1, 'hp': 1})
    draw_stat_badges(raw, info['atk'], info['hp'])
    
    card_scale = 1.25
    cw, ch = int(TILE_W * card_scale), int(TILE_H * card_scale)
    card_scaled = raw.resize((cw, ch), Image.Resampling.LANCZOS)
    
    card_x = card_cx - cw // 2
    card_y = card_cy - ch // 2 + int(math.sin(t * 2.5) * 6)
    
    # Drop shadow
    im.paste((0, 0, 0, 180), (card_x + 18, card_y + 24, card_x + cw + 18, card_y + ch + 24), mask=card_scaled.split()[3])
    im.alpha_composite(card_scaled, (card_x, card_y))
    
    # 4. Description Box on Right
    box_x, box_y, box_w, box_h = 880, 220, 880, 680
    draw.rounded_rectangle([box_x, box_y, box_x + box_w, box_y + box_h], radius=24, fill=(18, 28, 22, 240), outline=(225, 180, 50, 255), width=4)
    
    # Rarity Pill
    pill_w, pill_h = 280, 48
    draw.rounded_rectangle([box_x + 40, box_y + 35, box_x + 40 + pill_w, box_y + 35 + pill_h], radius=16, fill=(180, 130, 25, 255))
    draw.text((box_x + 55, box_y + 42), rarity_badge, font=FONT_SUB, fill=(255, 255, 255, 255))
    
    # Card Name
    name = info.get('name', mid)
    draw.text((box_x + 40, box_y + 105), name, font=FONT_HERO, fill=(255, 225, 80, 255))
    
    # Mana / Stats
    stat_line = f"Cost: {info.get('mana', 1)} Mana   *   Attack: +{info['atk']} Mult   *   Health: +{info['hp']*25} Chips"
    draw.text((box_x + 40, box_y + 180), stat_line, font=FONT_SUB, fill=(130, 215, 255, 255))
    draw.line([box_x + 40, box_y + 230, box_x + box_w - 40, box_y + 230], fill=(80, 140, 100, 255), width=2)
    
    # Rules Text lines
    for li, line in enumerate(lines):
        color = (255, 255, 255, 255)
        if line.startswith('Battlecry:') or line.startswith('Deathrattle:'):
            color = (255, 215, 70, 255)
        elif line.startswith('WARNING:') or line.startswith('Result:'):
            color = (255, 110, 90, 255)
        elif line.startswith('->'):
            color = (130, 240, 160, 255)
        draw.text((box_x + 40, box_y + 260 + li * 48), line, font=FONT_DESC, fill=color)


# =============================================================================
# SPOTLIGHT 1: Dr. Boom & Exploding Boom Bots
# =============================================================================
def render_spotlight_dr_boom(out_path):
    print("Rendering Spotlight: Dr. Boom...")
    n_frames = 150
    frames = []
    
    # Phase 1: 0 - 65 frames (Card Spotlight)
    # Phase 2: 66 - 150 frames (In-Game Battlecry & Exploding Bots)
    
    for f in range(n_frames):
        t = f / FPS
        im = FELT_BG.copy()
        
        if f < 65:
            lines = [
                "Battlecry:",
                "Summon two 1/1 Boom Bots.",
                "",
                "WARNING: Bots may explode.",
                "",
                "-> Boom Bot Deathrattle:",
                "    Deals 1 to 4 damage straight into",
                "    the Blind, permanently lowering",
                "    the Boss score requirement!"
            ]
            draw_spotlight_frame(im, 'dr_boom', "CARD SPOTLIGHT: DR. BOOM", "LEGENDARY MINION", lines, t)
        else:
            action_t = (f - 65) / FPS
            draw_top_hud(im, "Dr. Boom Battlecry: Summoning Boom Bots", ante=4, round_num=9, dollars=25)
            draw = ImageDraw.Draw(im)
            
            # Boss Blind at top
            boss_cx, boss_cy, boss_r = WIDTH // 2, 220, 80
            draw.ellipse([boss_cx - boss_r, boss_cy - boss_r, boss_cx + boss_r, boss_cy + boss_r], fill=(120, 30, 40, 255), outline=(245, 180, 50, 255), width=5)
            draw.text((boss_cx - 55, boss_cy - 20), "BLIND", font=FONT_TITLE, fill=(255, 255, 255, 255))
            
            # Board: Dr. Boom in center (slot 2), Boom Bots on sides (slots 1 and 3)
            scale = 0.74
            cw, ch = int(TILE_W * scale), int(TILE_H * scale)
            spacing = cw + 35
            
            # Summon animation progress for bots (from action_t 0.0 to 1.0)
            bot_alpha = min(1.0, max(0.0, action_t * 2.0))
            
            minions_in_play = [
                ('boom_bot', 1, 1, 0, bot_alpha),
                ('dr_boom', 7, 7, 1, 1.0),
                ('boom_bot', 1, 1, 2, bot_alpha),
            ]
            
            start_x = (WIDTH - (3 * spacing - 35)) // 2
            base_y = 440
            
            for mid, atk, hp, idx, alpha in minions_in_play:
                if alpha <= 0:
                    continue
                card_x = start_x + idx * spacing
                card_y = base_y + int(math.sin(t * 3.0 + idx) * 6)
                
                raw = get_minion_sprite(mid).copy()
                draw_stat_badges(raw, atk, hp)
                card_scaled = raw.resize((cw, ch), Image.Resampling.LANCZOS)
                
                # Apply alpha if spawning
                if alpha < 1.0:
                    arr = np.array(card_scaled)
                    arr[:, :, 3] = (arr[:, :, 3] * alpha).astype(np.uint8)
                    card_scaled = Image.fromarray(arr)
                    
                im.paste((0, 0, 0, int(150 * alpha)), (card_x + 12, card_y + 16, card_x + cw + 12, card_y + ch + 16), mask=card_scaled.split()[3])
                im.alpha_composite(card_scaled, (card_x, card_y))
                
                name = CATALOG['minions'].get(mid, {}).get('name', mid)
                bbox = FONT_CARD.getbbox(name)
                draw.text((card_x + cw//2 - (bbox[2] - bbox[0])//2, card_y + ch + 10), name, font=FONT_CARD, fill=(240, 240, 240, 255))
                
            # Battlecry pop text
            if action_t < 1.2:
                draw.text((WIDTH // 2 - 130, 370), "BATTLECRY!", font=FONT_TITLE, fill=(255, 235, 70, 255))
            
            # Boom Bots explode between action_t 1.2 and 2.8!
            if action_t >= 1.2:
                exp_t = action_t - 1.2
                # Explosions over boss
                draw.text((WIDTH // 2 - 220, 360), "BOOM BOTS EXPLODE! -4 HP", font=FONT_TITLE, fill=(255, 75, 75, 255))
                # Blast wave from both bots to boss
                p = (exp_t % 0.8) / 0.8
                for bx_idx in [0, 2]:
                    bx = start_x + bx_idx * spacing + cw // 2
                    by = base_y
                    proj_x = int(bx + (boss_cx - bx) * p)
                    proj_y = int(by + (boss_cy - by) * p)
                    draw.circle((proj_x, proj_y), int(16 + 12 * p), fill=(255, 120, 20, int(240 * (1 - p))))
                    draw.circle((proj_x, proj_y), int(8 + 6 * p), fill=(255, 240, 100, int(255 * (1 - p))))
                
            draw_lower_banner(im, "SUMMON BOOM BOTS  *  DEAL 1-4 DAMAGE TO THE BLIND", "Dr. Boom fills your battlefield with explosive, autonomous tokens!")
            
        frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, frames, fps=FPS)
    print(f"Saved: {out_path}")


# =============================================================================
# SPOTLIGHT 2: Archmage Antonidas & Infinite Fireballs
# =============================================================================
def render_spotlight_antonidas(out_path):
    print("Rendering Spotlight: Archmage Antonidas...")
    n_frames = 150
    frames = []
    
    for f in range(n_frames):
        t = f / FPS
        im = FELT_BG.copy()
        
        if f < 65:
            lines = [
                "Whenever you cast a Spell,",
                "add a 'Fireball' spell to your hand.",
                "",
                "-> Fireball Deal 6 damage to Blind:",
                "    Hits the enemy Blind directly!",
                "    Boosted by Spell Damage minions.",
                "",
                "-> Chain Infinite Fireballs:",
                "    Cast spells -> Gain Fireballs -> Cast",
                "    Fireballs to incinerate the enemy!"
            ]
            draw_spotlight_frame(im, 'archmage_antonidas', "CARD SPOTLIGHT: ARCHMAGE ANTONIDAS", "LEGENDARY MINION", lines, t)
        else:
            action_t = (f - 65) / FPS
            draw_top_hud(im, "Archmage Antonidas: 'You require my assistance?'", ante=5, round_num=12, dollars=22)
            draw = ImageDraw.Draw(im)
            
            # Boss Blind at top
            boss_cx, boss_cy, boss_r = WIDTH // 2, 220, 80
            draw.ellipse([boss_cx - boss_r, boss_cy - boss_r, boss_cx + boss_r, boss_cy + boss_r], fill=(120, 30, 40, 255), outline=(245, 180, 50, 255), width=5)
            draw.text((boss_cx - 55, boss_cy - 20), "BLIND", font=FONT_TITLE, fill=(255, 255, 255, 255))
            
            # Antonidas on board
            scale = 0.78
            cw, ch = int(TILE_W * scale), int(TILE_H * scale)
            card_x, card_y = 500, 430
            raw = get_minion_sprite('archmage_antonidas').copy()
            draw_stat_badges(raw, 5, 7)
            card_scaled = raw.resize((cw, ch), Image.Resampling.LANCZOS)
            im.paste((0, 0, 0, 150), (card_x + 12, card_y + 16, card_x + cw + 12, card_y + ch + 16), mask=card_scaled.split()[3])
            im.alpha_composite(card_scaled, (card_x, card_y))
            draw.text((card_x + 20, card_y + ch + 10), "Archmage Antonidas", font=FONT_CARD, fill=(240, 240, 240, 255))
            
            # Consumable Slot with Fireball on right
            cons_x, cons_y = 1200, 430
            s_raw = get_spell_sprite('fireball').copy()
            s_scaled = s_raw.resize((cw, ch), Image.Resampling.LANCZOS)
            im.paste((0, 0, 0, 150), (cons_x + 12, cons_y + 16, cons_x + cw + 12, cons_y + ch + 16), mask=s_scaled.split()[3])
            im.alpha_composite(s_scaled, (cons_x, cons_y))
            draw.text((cons_x + 55, cons_y + ch + 10), "Fireball (Created!)", font=FONT_CARD, fill=(255, 180, 50, 255))
            
            # "AHA!" Speech Bubble & Fireball Projectile
            p = (action_t % 1.2) / 1.2
            proj_x = int(cons_x + cw // 2 + (boss_cx - (cons_x + cw // 2)) * p)
            proj_y = int(cons_y + (boss_cy - cons_y) * p)
            
            draw.text((card_x + cw // 2 - 40, card_y - 60), "'AHA!'", font=FONT_HERO, fill=(255, 230, 80, 255))
            draw.line([proj_x + 30, proj_y + 20, proj_x - 10, proj_y - 10], fill=(255, 110, 20, 250), width=14)
            draw.line([proj_x + 20, proj_y + 10, proj_x, proj_y], fill=(255, 240, 110, 255), width=7)
            
            draw.text((WIDTH // 2 - 250, 360), "CAST A SPELL -> GAIN A FIREBALL!", font=FONT_TITLE, fill=(255, 160, 40, 255))
            draw_lower_banner(im, "INFINITE SPELL ENGINE  *  DEAL MASSIVE DIRECT DAMAGE", "Antonidas turns every spell you cast into pure lethal firepower!")
            
        frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, frames, fps=FPS)
    print(f"Saved: {out_path}")


# =============================================================================
# SPOTLIGHT 3: Grim Patron & Self-Replication
# =============================================================================
def render_spotlight_grim_patron(out_path):
    print("Rendering Spotlight: Grim Patron...")
    n_frames = 150
    frames = []
    
    for f in range(n_frames):
        t = f / FPS
        im = FELT_BG.copy()
        
        if f < 65:
            lines = [
                "Whenever this minion survives",
                "damage, summon another Grim Patron.",
                "",
                "-> Infinite Battlefield Scaling:",
                "    When enemy Blinds attack or spells",
                "    deal damage, your Patron army",
                "    rapidly multiplies across all slots!",
                "",
                "-> Result: 'EVERYONE, GET IN HERE!'"
            ]
            draw_spotlight_frame(im, 'grim_patron', "CARD SPOTLIGHT: GRIM PATRON", "RARE MINION", lines, t)
        else:
            action_t = (f - 65) / FPS
            draw_top_hud(im, "Grim Patron: 'Everyone, get in here!'", ante=3, round_num=7, dollars=18)
            draw = ImageDraw.Draw(im)
            
            # Boss attacking
            boss_cx, boss_cy, boss_r = WIDTH // 2, 220, 80
            draw.ellipse([boss_cx - boss_r, boss_cy - boss_r, boss_cx + boss_r, boss_cy + boss_r], fill=(120, 30, 40, 255), outline=(245, 180, 50, 255), width=5)
            draw.text((boss_cx - 55, boss_cy - 20), "BLIND", font=FONT_TITLE, fill=(255, 255, 255, 255))
            
            # Patron 1 (always there) + Patron 2 & 3 multiplying as action_t increases
            n_patrons = 1
            if action_t > 0.8: n_patrons = 2
            if action_t > 1.8: n_patrons = 3
            
            scale = 0.74
            cw, ch = int(TILE_W * scale), int(TILE_H * scale)
            spacing = cw + 36
            start_x = (WIDTH - (n_patrons * spacing - 36)) // 2
            base_y = 440
            
            for i in range(n_patrons):
                card_x = start_x + i * spacing
                card_y = base_y + int(math.sin(t * 3.5 + i * 1.2) * 6)
                
                raw = get_minion_sprite('grim_patron').copy()
                # Patron 1 is damaged (3/2) to trigger effect!
                cur_hp = 2 if i == 0 else 3
                draw_stat_badges(raw, 3, cur_hp, base_atk=3, base_hp=3)
                card_scaled = raw.resize((cw, ch), Image.Resampling.LANCZOS)
                
                im.paste((0, 0, 0, 150), (card_x + 12, card_y + 16, card_x + cw + 12, card_y + ch + 16), mask=card_scaled.split()[3])
                im.alpha_composite(card_scaled, (card_x, card_y))
                
                draw.text((card_x + cw//2 - 50, card_y + ch + 10), "Grim Patron", font=FONT_CARD, fill=(240, 240, 240, 255))
                
            # Shout bubble
            if n_patrons > 1:
                draw.text((WIDTH // 2 - 270, 360), "'EVERYONE, GET IN HERE!'", font=FONT_HERO, fill=(255, 235, 75, 255))
            else:
                draw.text((WIDTH // 2 - 200, 360), "PATRON SURVIVES DAMAGE!", font=FONT_TITLE, fill=(255, 120, 120, 255))
                
            draw_lower_banner(im, "SURVIVE DAMAGE -> SUMMON ANOTHER PATRON", "Turn enemy attacks into massive exponential board presence!")
            
        frames.append(np.array(im.convert('RGB')))
        
    iio.imwrite(out_path, frames, fps=FPS)
    print(f"Saved: {out_path}")


if __name__ == '__main__':
    os.makedirs('test_output/trailer', exist_ok=True)
    
    s1 = 'test_output/trailer/spotlight1_dr_boom.mp4'
    s2 = 'test_output/trailer/spotlight2_antonidas.mp4'
    s3 = 'test_output/trailer/spotlight3_grim_patron.mp4'
    
    render_spotlight_dr_boom(s1)
    render_spotlight_antonidas(s2)
    render_spotlight_grim_patron(s3)
    
    print("ALL CARD SPOTLIGHT FOOTAGE GENERATED SUCCESSFULLY!")
