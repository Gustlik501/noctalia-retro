#!/usr/bin/env bash
# Run from the repository root. Everything mutable stays under this repo's .work.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
TESTBED_BIN=${TESTBED_BIN:-$ROOT/.work/testbed/bin/testbed}
NOCTALIA_BIN=${NOCTALIA_BIN:-/nix/store/ijh1xbj7mzygxi8z183yl90gw4glvqqb-noctalia-5.4.1/bin/noctalia}
export TESTBED_DIR="$ROOT/.work/t"
mkdir -p .work/screens
python3 - <<'PY'
from pathlib import Path
root = Path.cwd()
config = root / '.work/t/config/noctalia'
(config / 'palettes').mkdir(parents=True, exist_ok=True)
text = (root / 'examples/retro.toml').read_text()
import os
text = text[text.index('[plugins]'):].replace('@PLUGIN_ROOT@', os.environ.get('RETRO_PLUGIN_ROOT', str(root)))
text = text.replace('[shell]\n', '''[shell]
polkit_agent = false
clipboard_enabled = false
setup_wizard_enabled = false
offline_mode = true
telemetry_enabled = false
''')
text += '''
[notification]
enable_daemon = false
[lockscreen]
enabled = false
[wallpaper]
enabled = false
fill_color = "#2F7F86"
[dock]
enabled = false
[idle.behavior.lock]
enabled = false
[idle.behavior.screen-off]
enabled = false
[idle.behavior.suspend]
enabled = false
[bluetooth]
connect_when_enabled = false
'''
(config / 'config.toml').write_text(text)
(config / 'palettes/Workstation95.json').write_bytes((root / 'examples/palettes/Workstation95.json').read_bytes())
PY
# Launcher already uses a private dbus-run-session with no activation directories.
timeout 90 "$TESTBED_BIN" up --outputs 2 --size 1920x1080 --backend offscreen
trap 'timeout 20 "$TESTBED_BIN" down' EXIT
# A second dbus-run-session explicitly encloses Noctalia as well. The bus config,
# HOME, five XDG roots, system bus and audio endpoints are all private.
timeout 180 "$TESTBED_BIN" run dbus-run-session --config-file "$TESTBED_DIR/bus.conf" -- "$NOCTALIA_BIN" \
  > .work/noctalia.log 2>&1 &
client=$!
for _ in $(seq 1 60); do
  if timeout 5 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg plugins list > .work/plugins.json 2>/dev/null; then break; fi
  sleep 1
done
sleep 8
shot() {
  if [[ ${SKIP_HYPR_SHOTS:-0} == 1 ]]; then return; fi
  timeout 8 "$TESTBED_BIN" shot "$@" || printf 'CAPTURE BLOCKED: %s\n' "$*"
}
timeout 10 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg plugin retro/noctalia-retro:state all diagnostics
timeout 10 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg plugin retro/noctalia-retro:front all diagnostics
sleep 1
timeout 15 "$TESTBED_BIN" ctl -j monitors > .work/monitors-before.json
shot .work/screens/before.png TESTBED-1
shot .work/screens/second-monitor.png TESTBED-2
timeout 10 "$TESTBED_BIN" ctl --batch 'dispatch hl.dsp.focus({monitor="TESTBED-1"}); dispatch hl.dsp.focus({workspace="3"})'
sleep 2
timeout 10 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg plugin retro/noctalia-retro:state all diagnostics
timeout 10 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg plugin retro/noctalia-retro:front all diagnostics
timeout 10 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg bar-toggle front > .work/toggle-hide.txt
sleep 2
timeout 15 "$TESTBED_BIN" ctl -j monitors > .work/monitors-hidden.json
shot .work/screens/hidden.png TESTBED-1
timeout 10 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg bar-toggle front > .work/toggle-show.txt
sleep 2
timeout 15 "$TESTBED_BIN" ctl -j monitors > .work/monitors-restored.json
shot .work/screens/restored.png TESTBED-1
python3 - <<'PY'
import json
from pathlib import Path
before, hidden, restored = [json.loads(Path('.work/monitors-' + stage + '.json').read_text()) for stage in ('before', 'hidden', 'restored')]
assert all(m['reserved'] == [0, 28, 0, 76] for m in before)
assert all(m['reserved'] == [0, 28, 0, 0] for m in hidden)
assert all(m['reserved'] == [0, 28, 0, 76] for m in restored)
print('Both monitors: front toggle releases 76px and restores 76px; top remains 28px')
PY
# Exercise the configured IPC destinations without invoking session actions.
for tab in network bluetooth audio; do
  timeout 10 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg panel-open control-center "$tab"
  sleep 1
  shot ".work/screens/panel-$tab.png" TESTBED-1
  timeout 10 "$TESTBED_BIN" run "$NOCTALIA_BIN" msg panel-close
 done
# Keep enough time for a caller to inspect output before automatic teardown.
if [[ ${TESTBED_PAUSE:-0} != 0 ]]; then sleep "$TESTBED_PAUSE"; fi
# down verifies process provenance and closes only our private testbed processes.
