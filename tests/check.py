"""Offline schema, source-preservation and syntax checks; no desktop contact."""
import json
from pathlib import Path
import subprocess
import tomllib

root = Path(__file__).resolve().parent.parent
plugin = root / "plugin"
manifest = tomllib.loads((plugin / "plugin.toml").read_text())
translations = json.loads((plugin / "translations/en.json").read_text())
assert manifest["id"] == "retro/noctalia-retro"
assert len(manifest["widget"]) == 8
for setting in manifest["setting"] + [s for w in manifest["widget"] for s in w.get("setting", [])]:
    assert setting["label_key"] in translations
    assert "default" in setting
for kind in ("widget", "service"):
    for entry in manifest[kind]:
        assert (plugin / entry["entry"]).is_file()
for path in plugin.rglob("*.luau"):
    subprocess.run(["luau-compile", str(path)], check=True, stdout=subprocess.DEVNULL)
for path in (root / "examples").rglob("*.toml"):
    tomllib.loads(path.read_text())
profile = tomllib.loads((root / "examples/retro.toml").read_text())
assert set(profile["bar"]) == {"order", "main", "front"}  # "default" would create a third bar
for name, thickness in (("main", 28), ("front", 76)):
    bar = profile["bar"][name]
    assert bar["thickness"] == thickness and bar["background_opacity"] == 1.0
    assert bar["reserve_space"] and not bar["auto_hide"]
    assert bar["radius"] == 0 and not bar["shadow"]
palette = json.loads((root / "examples/palettes/Workstation95.json").read_text())
assert palette["version"] == 2
for mode in ("light", "dark"):
    assert palette[mode]["surface"] == "#C0C0C0"
    assert len(palette[mode]) == 17
    assert set(palette[mode]["terminal"]["normal"]) == {"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"}
base = tomllib.loads((root / "examples/profiles/user-base.toml").read_text())
assert set(base) == {"lockscreen_widgets", "shell", "wallpaper"}
assert base["shell"]["polkit_agent"] is True  # preserved, not the TEST override
assert 8 * 58 + 2 * 12 + 225 + 82 + 11 * 3 + 2 * 4 + 2 * 2 == 840
print("schema, Luau syntax, palette and dimensions: OK")
