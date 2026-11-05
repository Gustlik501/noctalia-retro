# Verification

## Results

- `nix build`, `nix flake check`: offline TOML/JSON/schema, all Luau syntax,
  dimensions, monitor filtering, sorting, special/empty workspaces and fixed IDs.
- Exact Noctalia 5.4.1 `plugins lint plugin`: zero errors/warnings.
- `config validate` accepts the installed profile both directly and through an
  HM-like config symlink. Absolute packaged includes avoid symlink-relative paths.
- Exact binary loaded all **9 entries**, including one shared state service,
  inside a **second Hyprland** with two 1920×1080 offscreen test outputs.
- Private testbed runtime: `.work/t`; separate HOME, XDG config/state/data/cache/
  runtime, private session D-Bus, unreachable system bus and audio endpoints.
  Noctalia was additionally enclosed in `dbus-run-session`; notification daemon,
  polkit, lockscreen, idle behaviors, clipboard history and theme synchronization
  were disabled. No user config or running desktop was modified.
- Test monitor JSON proves both outputs reserve `[left, top, right, bottom]` =
  `[0,28,0,76]`, then `[0,28,0,0]` after `bar-toggle front`, then `[0,28,0,76]`
  after a second toggle. Disabling animations makes this deterministic even when
  the test compositor's frame delivery stalls.
- Service diagnostics show workspaces scoped to TESTBED-1 = 1, TESTBED-2 = 2;
  after the tested Lua dispatch, TESTBED-1 changes to 3 while TESTBED-2 stays 2.
  Events/poll recovery work without a global-active-workspace assumption.
- **Aquamarine/NVIDIA capture limitation:** native headless GBM allocations fail
  on this machine. The testbed's private Wayland-inside-headless-Sway fallback
  creates the correct output geometry, but `grim` against that Hyprland instance
  repeatedly times out. No screenshot is claimed from that compositor.
- As a secondary real rendering test, exact Noctalia was started under a separate
  private **Sway headless/pixman** instance (`.work/sway`) with the same isolation.
  This produced actual 1920×1080 screenshots and successful front hide/show.
  A test-only fixed workspace list makes all four slot colours visible; no fake
  CPU/audio/battery data is injected. CPU/MEM are actual host read-only samples.
- A single-connection virtual-pointer helper (`tests/click.c`) clicked Terminal
  (overridden to write an isolated marker), Toolchest and NET successfully.
  Screenshots confirm the session menu and network tab. BT/audio panel IDs were
  also opened by test-instance IPC; no device or session action was activated.
- All started processes were stopped; the testbed's provenance-checked `down`
  targets only its children. The Sway worker cleans up its own Popen children.

## Screenshots / evidence (not committed)

Under `/data/SSD1/dotfilesprojects/noctalia-retro/.work/screens/`:

- `sway-before.png`, `sway-hidden.png`, `sway-restored.png` — full 1920×1080
- `top-bar.png` — 1920×28 crop; `front-panel.png` — 840×76 crop
- `sway-toolchest-click.png`, `sway-net-click.png`
- `sway-panel-network.png`, `sway-panel-bluetooth.png`, `sway-panel-audio.png`

Evidence: `.work/noctalia.log`, `.work/isolated.log`,
`.work/monitors-{before,hidden,restored}.json`, `.work/sway/noctalia.log`,
`.work/sway-smoke.log`, `.work/sway/launcher-clicked`.
The black test desktop is intentional: Noctalia wallpaper is disabled.

## Reproduce without touching a desktop session

Run from this repository only; mutable files are confined to `.work/`.

```sh
nix build
nix build 'git+file:///data/SSD1/dotfilesprojects/retro-testbed' --out-link .work/testbed
# Attempts Hyprland captures, records timeouts but continues IPC/reservation tests.
timeout 140 bash tests/isolated.sh
# To rerun non-rendering checks quickly after the capture failure is established:
SKIP_HYPR_SHOTS=1 timeout 80 bash tests/isolated.sh
```

The testbed must provide the `--backend offscreen` option and TESTBED-1/2 output
names. The initial in-progress testbed versions failed readiness before the
upstream job added this fallback. Never substitute a live WAYLAND_DISPLAY or
HYPRLAND_INSTANCE_SIGNATURE to work around a failure.

Build the original test pointer using pinned dev-shell dependencies, then render
on private Sway (uses the already staged `.work/t/config/noctalia` test config):

```sh
nix develop --command bash -c '
  xml=$(pkg-config --variable=pkgdatadir wlr-protocols)/unstable/wlr-virtual-pointer-unstable-v1.xml
  wayland-scanner client-header "$xml" .work/pointer.h
  wayland-scanner private-code "$xml" .work/pointer.c
  cc -I.work tests/click.c .work/pointer.c $(pkg-config --cflags --libs wayland-client) -o .work/click
'
timeout 100 python3 tests/sway-smoke.py
magick .work/screens/sway-before.png -crop 1920x28+0+0 .work/screens/top-bar.png
magick .work/screens/sway-before.png -crop 840x76+540+1004 .work/screens/front-panel.png
```

The Sway test only uses private sockets and a private bus, never the user's Sway
or Hyprland. Its Terminal command is replaced with an isolated marker write.
`RETRO_PLUGIN_ROOT=/nix/store/.../share/noctalia/plugins` can make the Hyprland
test load the immutable built package instead of the checkout.

Read-only diagnostic IPC (target the testbed with `testbed run`, not a bare msg):
`noctalia msg plugin retro/noctalia-retro:state all diagnostics`, or replace
`:state` with `:front` to log each placement's monitor/fixed IDs.

## Not verified / decisions

- Actual Hyprland screenshots remain blocked by the testbed render/capture path;
  the supplied real screenshots are explicitly Sway-headless, not Hyprland.
- Real PipeWire FFT/volume, BlueZ adapter, battery and lock authentication are not
  exercised: their buses/endpoints are deliberately inaccessible. No battery is
  installed here. Hardware fallbacks render without script errors.
- Pre-0.57 legacy dispatcher fallback is source-compatible but not runtime-tested.
- User-selected Nextlike icon files and real application launches are not tested;
  placeholders are intentional. Choose icon PNG paths/commands in plugin settings.
- No italics in host labels. The front panel requires per-monitor margins on
  non-1920 logical widths; no responsive layout below 840px is attempted.
- Native popups keep Noctalia layouts. Existing app-owned settings overrides may
  need reconciliation by the user/orchestrator; nothing was cleared or switched.
