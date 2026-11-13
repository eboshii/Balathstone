import os
import json
from lupa import luajit21 as lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/') + '/'

lua = lupa.LuaRuntime(unpack_returned_tuples=True)
run = lua.eval('function(path, ...) return assert(loadfile(path))(...) end')
run(ROOT + 'tests/mock_balatro.lua', ROOT)
run(ROOT + 'Balathstone.lua')

lua.execute("""
T.new_run()

minion_info = {}
for k, v in pairs(G.P_CENTERS) do
    if v.hs_minion then
        local m = v.hs_minion
        minion_info[m.id] = {
            id = m.id,
            name = m.name,
            key = k,
            pos = { x = v.pos.x, y = v.pos.y },
            atk = m.atk,
            hp = m.hp,
            mana = m.mana or 1,
            tribe = type(m.tribe) == 'table' and table.concat(m.tribe, ' / ') or m.tribe or '',
            kw = m.kw or {}
        }
    end
end

local HS = Balathstone or Balearthstone
spell_info = {}
for k, s in pairs(HS.spell_by_key) do
    local center = G.P_CENTERS[k]
    if center then
        spell_info[s.id] = {
            id = s.id,
            name = s.name,
            key = k,
            set = s.set,
            pos = { x = center.pos.x, y = center.pos.y },
            mana = s.mana or 1
        }
    end
end
""")

minions = dict(lua.eval('minion_info'))
spells = dict(lua.eval('spell_info'))

out = {'minions': {}, 'spells': {}}
for mid, mdata in minions.items():
    pos = dict(mdata.pos)
    kw = list(mdata.kw.values()) if mdata.kw else []
    out['minions'][str(mid)] = {
        'id': str(mdata.id),
        'name': str(mdata.name),
        'pos': {'x': int(pos['x']), 'y': int(pos['y'])},
        'atk': int(mdata.atk),
        'hp': int(mdata.hp),
        'mana': int(mdata.mana),
        'tribe': str(mdata.tribe),
        'kw': [str(k) for k in kw]
    }

for sid, sdata in spells.items():
    pos = dict(sdata.pos)
    out['spells'][str(sid)] = {
        'id': str(sdata.id),
        'name': str(sdata.name),
        'set': str(sdata.set),
        'pos': {'x': int(pos['x']), 'y': int(pos['y'])},
        'mana': int(sdata.mana)
    }

with open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'test_output', 'reports', 'cards_catalog.json'), 'w') as f:
    json.dump(out, f, indent=2)

print(f"Catalog dumped: {len(out['minions'])} minions, {len(out['spells'])} spells/consumables")
