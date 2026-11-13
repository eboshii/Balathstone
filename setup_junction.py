import os, subprocess

src = os.path.dirname(os.path.abspath(__file__))  # this repo
appdata = os.environ.get("APPDATA")
mods_dir = os.path.join(appdata, "Balatro", "Mods")
os.makedirs(mods_dir, exist_ok=True)
dst = os.path.join(mods_dir, "Balathstone")

print(f"Linking from {src} to {dst}")
if os.path.exists(dst):
    print("Already exists")
else:
    # Use PowerShell New-Item -ItemType Junction
    cmd = ["powershell", "-NoProfile", "-Command", f'New-Item -ItemType Junction -Path "{dst}" -Target "{src}"']
    res = subprocess.run(cmd, capture_output=True, text=True)
    print(res.stdout, res.stderr)
    print("Junction exists:", os.path.exists(dst))
