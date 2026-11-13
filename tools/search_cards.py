import os
import json

with open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'test_output', 'reports', 'cards_catalog.json')) as f:
    cat = json.load(f)

print("=== Minions ===")
for k, v in sorted(cat['minions'].items()):
    name = v['name']
    lower = name.lower()
    if any(s in lower for s in ['murk', 'antonidas', 'cthun', "c'thun", 'yogg', 'savage', 'boom', 'ragnaros', 'sylvanas', 'lich', "kel'thuzad", 'baku', 'genn']):
        print(f"{k:25} -> {name:25} ({v['atk']}/{v['hp']})")

print("\n=== Spells ===")
for k, v in sorted(cat['spells'].items()):
    print(f"{k:25} -> {v['name']:25} set={v['set']}")
