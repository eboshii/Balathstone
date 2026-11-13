import os, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sounds_dir = os.path.join(ROOT, 'assets', 'sounds')
os.makedirs(sounds_dir, exist_ok=True)

sound_map = {
    'attack.wav': 'ClawNCutlass_Attack_Underlay.wav',
    'death.wav': 'Minion_Death_01.wav',
    'summon.wav': 'Minion_Summon_Minion_01.wav',
    'spell.wav': 'AE_Holy_Cast_01.wav',
    'your_turn.wav': 'ALERT_YourTurn_0v2.wav',
}

for local_name, remote_name in sound_map.items():
    dest = os.path.join(sounds_dir, local_name)
    url = f'https://storage.googleapis.com/hearthsounds/{remote_name}'
    print(f'Downloading {remote_name} -> {local_name}...')
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=10) as resp:
        with open(dest, 'wb') as f:
            f.write(resp.read())
    print(f'Saved {dest} ({os.path.getsize(dest)} bytes)')

print('All sounds downloaded successfully!')
