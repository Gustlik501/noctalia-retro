#!/usr/bin/env python3
"""Secondary rendering check when Aquamarine's NVIDIA offscreen capture stalls.
Uses the testbed's private-environment helpers, never its running instance.
"""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
NOCTALIA = "/nix/store/ijh1xbj7mzygxi8z183yl90gw4glvqqb-noctalia-5.4.1/bin/noctalia"


def main():
    if sys.argv[1:] != ["--worker"]:
        spec = importlib.util.spec_from_file_location("testbed", ROOT / ".work/testbed/share/retro-testbed/testbed.py")
        tb = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tb)
        scratch = ROOT / ".work/sway"
        scratch.mkdir(parents=True, exist_ok=True)
        (scratch / "launcher-clicked").unlink(missing_ok=True)
        env = tb.isolated_env(scratch)
        env.update(XDG_RUNTIME_DIR=str(scratch / "run"), XDG_CURRENT_DESKTOP="sway",
                   SWAY_TEST_BINARY=tb.BRIDGE, GRIM_TEST_BINARY=tb.GRIM)
        config = ROOT / ".work/t/config/noctalia"
        dest = scratch / "config/noctalia"
        (dest / "palettes").mkdir(parents=True, exist_ok=True)
        text = (config / "config.toml").read_text()
        text = text.replace('[plugin_settings."retro/noctalia-retro".workspace_ids]\n',
                            '[plugin_settings."retro/noctalia-retro".workspace_ids]\n"HEADLESS-1" = "1,2,3,4"\n')
        text = text.replace('terminal_command = "kitty"',
                            'terminal_command = "printf clicked > ' + str(scratch / 'launcher-clicked') + '"')
        (dest / "config.toml").write_text(text)
        (dest / "palettes/Workstation95.json").write_bytes((config / "palettes/Workstation95.json").read_bytes())
        (scratch / "sway.conf").write_text("""xwayland disable
output * resolution 1920x1080
output * background #2F7F86 solid_color
seat * hide_cursor 100
swaybg_command -
""")
        with (ROOT / ".work/sway-smoke.log").open("w") as log:
            proc = subprocess.Popen([tb.DBUS, "--config-file", str(ROOT / ".work/t/bus.conf"), "--",
                                     sys.executable, str(Path(__file__).resolve()), "--worker"],
                                    env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                    start_new_session=True)
            try:
                return proc.wait(timeout=90)
            finally:
                # Only the process group we created above, never process-name matching.
                if proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGTERM)
                    try:
                        proc.wait(timeout=8)
                    except subprocess.TimeoutExpired:
                        os.killpg(proc.pid, signal.SIGKILL)
                        proc.wait()
    env = os.environ.copy()
    runtime = Path(env["XDG_RUNTIME_DIR"])
    scratch = runtime.parent
    sway_log = (scratch / "sway.log").open("w")
    sway_env = env | {"WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_HEADLESS_OUTPUTS": "1",
                      "WLR_LIBINPUT_NO_DEVICES": "1"}
    sway = subprocess.Popen([env["SWAY_TEST_BINARY"], "-c", str(scratch / "sway.conf")], env=sway_env,
                            stdin=subprocess.DEVNULL, stdout=sway_log, stderr=subprocess.STDOUT)
    noctalia = None
    try:
        for _ in range(100):
            sockets = [p for p in runtime.glob("wayland-*") if p.is_socket()]
            if sockets:
                break
            if sway.poll() is not None:
                raise RuntimeError("Private Sway exited")
            time.sleep(.1)
        env["WAYLAND_DISPLAY"] = sockets[0].name
        env["SWAYSOCK"] = str(next(runtime.glob("sway-ipc.*.sock")))
        with (scratch / "noctalia.log").open("w") as log:
            noctalia = subprocess.Popen([NOCTALIA], env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
        for _ in range(100):
            if (runtime / f"noctalia-{env['WAYLAND_DISPLAY']}.sock").is_socket():
                break
            if noctalia.poll() is not None:
                raise RuntimeError("Private Noctalia exited")
            time.sleep(.1)
        time.sleep(5)
        def msg(*args):
            subprocess.run([NOCTALIA, "msg", *args], env=env, check=True, timeout=8)
        def shot(name):
            subprocess.run([env["GRIM_TEST_BINARY"], "-o", "HEADLESS-1", str(ROOT / ".work/screens" / name)],
                           env=env, check=True, timeout=12)
        msg("plugin", "retro/noctalia-retro:front", "all", "diagnostics")
        shot("sway-before.png")
        pointer = str(ROOT / ".work/click")
        def click(x, y):
            subprocess.run([pointer, str(x), str(y)], env=env, check=True, timeout=8)
            time.sleep(.15)
        click(710, 1040)
        time.sleep(.5)
        print("Launcher click marker:", (scratch / "launcher-clicked").exists(), flush=True)
        assert (scratch / "launcher-clicked").read_text() == "clicked"
        click(40, 14)
        time.sleep(.5)
        shot("sway-toolchest-click.png")
        msg("panel-close")
        click(1650, 14)
        time.sleep(.5)
        shot("sway-net-click.png")
        msg("panel-close")
        msg("bar-toggle", "front")
        time.sleep(1)
        shot("sway-hidden.png")
        msg("bar-toggle", "front")
        time.sleep(1)
        shot("sway-restored.png")
        for tab in ("network", "bluetooth", "audio"):
            msg("panel-open", "control-center", tab)
            time.sleep(1)
            shot(f"sway-panel-{tab}.png")
            msg("panel-close")
        return 0
    finally:
        for proc in (noctalia, sway):
            if proc is not None and proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()
        sway_log.close()


if __name__ == "__main__":
    sys.exit(main())
