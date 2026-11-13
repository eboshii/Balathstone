"""
Compile the full extended trailer sizzle reel weaving Card Spotlights and Gameplay Scenes.
"""

import numpy as np
import imageio.v3 as iio
from PIL import Image, ImageDraw, ImageFont

WIDTH = 1920
HEIGHT = 1088
FPS = 30

FONT_PATH = 'assets/fonts/belwe-bd-bt-bold.ttf'

def get_font(size):
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except Exception:
        return ImageFont.load_default()

FONT_TITLE = get_font(52)
FONT_SUB = get_font(32)
FONT_CARD = get_font(26)

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

def main():
    clips = [
        'test_output/trailer/spotlight1_dr_boom.mp4',
        'test_output/trailer/scene1_murloc_swarm.mp4',
        'test_output/trailer/spotlight2_antonidas.mp4',
        'test_output/trailer/scene3_xmult_overkill.mp4',
        'test_output/trailer/spotlight3_grim_patron.mp4',
        'test_output/trailer/scene4_boss_combat.mp4',
        'test_output/trailer/scene5_packs_discover.mp4',
    ]
    
    out_path = 'test_output/trailer/balathstone_trailer_reel.mp4'
    all_frames = []
    
    # Intro Logo (60 frames / 2.0s)
    for f in range(60):
        t = f / FPS
        im = FELT_BG.copy()
        draw = ImageDraw.Draw(im)
        title = "BALATHSTONE"
        sub = "THE HEARTHSTONE TOTAL CONVERSION FOR BALATRO"
        t_box = FONT_TITLE.getbbox(title)
        draw.text((WIDTH // 2 - (t_box[2] - t_box[0]) // 2, HEIGHT // 2 - 90), title, font=FONT_TITLE, fill=(255, 220, 70, 255))
        s_box = FONT_SUB.getbbox(sub)
        draw.text((WIDTH // 2 - (s_box[2] - s_box[0]) // 2, HEIGHT // 2 + 5), sub, font=FONT_SUB, fill=(230, 240, 230, 255))
        badge = "166 MINIONS  *  75 SPELLS  *  TACTICAL COMBAT & EXPANSIONS"
        b_box = FONT_CARD.getbbox(badge)
        draw.text((WIDTH // 2 - (b_box[2] - b_box[0]) // 2, HEIGHT // 2 + 75), badge, font=FONT_CARD, fill=(120, 220, 255, 255))
        all_frames.append(np.array(im.convert('RGB')))
        
    for cp in clips:
        print(f"Adding {cp}...")
        frames = iio.imread(cp)
        for frame in frames:
            if frame.shape[0] != HEIGHT or frame.shape[1] != WIDTH:
                padded = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
                h_copy = min(HEIGHT, frame.shape[0])
                w_copy = min(WIDTH, frame.shape[1])
                padded[:h_copy, :w_copy] = frame[:h_copy, :w_copy]
                all_frames.append(padded)
            else:
                all_frames.append(frame)
                
    # Outro Call to Action (60 frames / 2.0s)
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
        
    print(f"Encoding {len(all_frames)} frames to {out_path}...")
    iio.imwrite(out_path, all_frames, fps=FPS)
    print("Extended trailer reel compiled successfully!")

if __name__ == '__main__':
    main()
