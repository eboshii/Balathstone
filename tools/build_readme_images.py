"""Build the README showcase images in docs/ from the card and Blind atlases:
minions.png, spells.png (Spells + Secrets) and bosses.png."""
import os
import sys

from lupa import luajit21 as lupa
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from build_banner import card_tile  # noqa: E402

FONT = os.path.join(ROOT, 'assets', 'fonts', 'belwe-bd-bt-bold.ttf')
W, H = 284, 380
GAP = 14

MINIONS = ['brann_bronzebeard', 'grim_patron', 'zola_the_gorgon', 'mimiron_the_mastermind', 'tess_greymane',
           'ragnaros_the_firelord']
SPELLS = [('c_hs_savage_roar', 'consumables'), ('c_hs_lightning_bolt', 'consumables'),
          ('c_hs_blessed_champion', 'consumables'), ('tag_hs_freezing_trap', 'secrets'),
          ('tag_hs_mirror_entity', 'secrets'), ('tag_hs_counterspell', 'secrets')]
BOSSES = ['ragnaros', 'moroes', 'patchwerk', 'al_akir', 'sindragosa', 'kiljaeden', 'nzoth', 'deathwing']


def load():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    root = ROOT.replace('\\', '/') + '/'
    run = lua.eval('function(path, ...) return assert(loadfile(path))(...) end')
    run(root + 'tests/mock_balatro.lua', root)
    run(root + 'Balathstone.lua')
    return lua


def strip(tiles, path):
    img = Image.new('RGBA', (len(tiles) * (W + GAP) - GAP, H), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        img.alpha_composite(t, (i * (W + GAP), 0))
    img.save(path, optimize=True)


def main():
    import build_art
    cards = {c['key']: c for c in build_art.load_cards()}
    lua = load()
    stats = lua.eval('function(k) local d = Balathstone.defs[k]; return d.atk, d.hp end')

    strip([card_tile(cards, 'j_hs_' + m, 'minions', stats('j_hs_' + m)) for m in MINIONS],
          os.path.join(ROOT, 'docs', 'minions.png'))
    strip([card_tile(cards, k, a, None) for k, a in SPELLS], os.path.join(ROOT, 'docs', 'spells.png'))

    # Bosses: first frame of each animated Blind portrait, with its name
    pos = lua.eval("function(k) return G.P_BLINDS['bl_hs_' .. k].pos.y end")
    names = lua.eval("function(k) return G.P_BLINDS['bl_hs_' .. k].name end")
    sheet = Image.open(os.path.join(ROOT, 'assets', '2x', 'blinds.png'))
    size, cell, label_h = 68, 190, 56
    font = ImageFont.truetype(FONT, 22)
    img = Image.new('RGBA', (len(BOSSES) * cell, cell + label_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, b in enumerate(BOSSES):
        y = pos(b)
        token = sheet.crop((0, y * size, size, y * size + size)).resize((cell - 20, cell - 20), Image.LANCZOS)
        img.alpha_composite(token, (i * cell + 10, 10))
        name = names(b).replace('Ragnaros the Firelord', 'Ragnaros').replace(', Rage Unbound', '')
        name = name.replace(', the Corruptor', '').replace(' the Windlord', '')
        d.text((i * cell + cell / 2, cell + 18), name, font=font, fill=(240, 228, 200), anchor='mm',
               stroke_width=3, stroke_fill=(20, 14, 10))
    img.save(os.path.join(ROOT, 'docs', 'bosses.png'), optimize=True)
    print('wrote docs/minions.png, docs/spells.png, docs/bosses.png')


if __name__ == '__main__':
    main()
