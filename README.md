# noctalia-retro — Workstation '95

Original MIT-licensed Noctalia **5.4.1** plugin: IRIX text-only top status bar and
an opaque, square, bevelled CDE-style bottom front panel (variant 2).
No NeXT/Apple artwork, fonts, or upstream plugin code is redistributed.

## Build / install

```sh
nix build                 # also runs offline schema, Luau syntax and layout tests
nix flake check
```

Outputs:
- `share/noctalia/plugins/noctalia-retro/{plugin.toml,*.luau,lib/,translations/}`
- `share/noctalia-retro/examples/retro.toml` (plugin and base-include store paths substituted)
- `share/noctalia-retro/examples/{profiles/user-base.toml,palettes/Workstation95.json}`

Flake package: `packages.x86_64-linux.noctalia-retro` (also `default`).
`overlays.default` provides `pkgs.noctalia-retro`. nixpkgs is locked to
`885ba4d038f10c3d17d7a92e8c3cc185b99c9158`; downstream inputs may follow nixpkgs.

### Home Manager / NixOS

Add this flake as `inputs.noctalia-retro` with URL
`git+file:///data/SSD1/dotfilesprojects/noctalia-retro` until a remote is assigned
(this excludes ignored test sockets), and `inputs.nixpkgs.follows = "nixpkgs"`. In the user's existing Noctalia HM module:

```nix
{ inputs, pkgs, ... }:
let retro = inputs.noctalia-retro.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  programs.noctalia = {
    enable = true;
    settings = /. + "${retro}/share/noctalia-retro/examples/retro.toml";
  };
  xdg.configFile."noctalia/palettes/Workstation95.json".source =
    "${retro}/share/noctalia-retro/examples/palettes/Workstation95.json";
  home.packages = with pkgs; [ tex-gyre socat iproute2 wireplumber bluez kitty thunar firefox neovim ];
  # On NixOS instead: fonts.packages = [ pkgs.tex-gyre ];
  fonts.fontconfig.enable = true;
}
```

This uses the user's `programs.noctalia.settings = <TOML file>` interface, not the
older Quickshell JSON interface. `/. +` makes a Nix **path**: this module treats a
plain string as raw TOML contents, even if it looks like a filename. The installed
base include is absolute so the HM config symlink resolves it correctly. No plugin copy or mutable install step is needed:

```toml
[plugins]
enabled = ["retro/noctalia-retro"]
auto_update = "none"
[[plugins.source]]
name = "noctalia-retro"
kind = "path"
location = "/nix/store/...-noctalia-retro-0.1.0/share/noctalia/plugins"
enabled = true
```

Path sources are scanned read-only. Enable **plugin ID** `retro/noctalia-retro`;
bar **entry IDs** are `retro/noctalia-retro:toolchest`, `:clock`, `:spectrum`,
`:net`, `:bt`, `:vol`, `:bat`, `:front`. Named widget definitions are in the example.
For checkout development replace `@PLUGIN_ROOT@` with the checkout root
(the scanner finds its `plugin/` child); the marker is intentionally not expanded by Noctalia itself.

Palette name **Workstation95**, font family **TeX Gyre Heros** (`pkgs.tex-gyre`).
A NixOS system module can apply the overlay and pass the same package to HM;
merely installing it in `environment.systemPackages` does not enable the plugin.

## Profiles / existing settings

`examples/profiles/user-base.toml` preserves the supplied user's `lockscreen_widgets`,
`shell` and `wallpaper` sections unchanged. Noctalia merges includes first, then
this profile: only added font/square/opaque appearance keys override the base.
The wallpaper path is user-specific; replace it on another machine.
`[include] autoload = false` prevents other root TOMLs from loading as profiles.
For a switchable profile, make config.toml contain only:

```toml
[include]
autoload = false
files = ["profiles/retro.toml"]
```

If relocating retro.toml, adjust its base include. Existing app-owned
`$XDG_STATE_HOME/noctalia/settings.toml` overrides declarative settings, including
plugin enablement and bar geometry; review conflicts before adopting the profile.
No files in the real config or state were changed by this project.

## Settings

Global keys live under `[plugin_settings."retro/noctalia-retro"]`; all have typed
GUI controls and English labels in `plugin/plugin.toml` / `translations/en.json`.

| Key | Default / meaning |
| --- | --- |
| `font_family` | `TeX Gyre Heros` |
| `clock_format` | `%H:%M`, strftime, both clocks |
| `clock_icon` | `""`; optional local PNG, live time remains below it |
| `status_poll_ms` | `5000`, range 1000–60000, shared NET/BT/VOL polling |
| `network_interface` | `""` = lowest-metric IPv4 default-route interface |
| `workspace_ids` | `{}`; monitor → comma-separated positive IDs, e.g. `{ "DP-1" = "5,6,7,8" }` |
| `terminal_command` | `kitty` |
| `files_command` | `thunar` |
| `browser_command` | `firefox` |
| `editor_command` | `kitty -e nvim` |
| `settings_command` | `noctalia msg settings` |
| `trash_command` | `thunar trash:///` (opens trash, never empties it) |
| `<launcher>_icon` | `""` for all six; absolute, `~` or plugin-relative local PNG |

Commands are **trusted shell commands**, run only on clicks. Empty commands do
nothing. Missing icons use labelled placeholder tiles; point the six icon settings
at your separately installed Nextlike theme's PNGs. No icon-theme guessing occurs.
The spectrum widget's entry-level `audio_spectrum = true` enables Noctalia's
PipeWire FFT hook; silence renders low green bars, never fake animated activity.

Workspaces are the first four positive IDs sorted on **this bar's monitor**, not
the globally focused monitor; special workspaces are excluded. Missing cells are
grey, blank and inert. Fixed lists preserve their specified order and can create
not-yet-existing workspaces. Active state is the monitor's `activeWorkspace.id`.
Click focuses that output then dispatches the workspace, using inherited Hyprland
coordinates. Hyprland 0.57 uses `hl.dsp.focus({monitor=...})` / `{workspace=...}`
through `hyprctl dispatch`; older versions fall back to `focusmonitor` / `workspace <id>`.
The requested legacy command alone is rejected by this user's Lua-based Hyprland. Socket2 events are debounced; a 5s query also recovers missed events.

Top NET/BT/VOL open `panel-toggle control-center network|bluetooth|audio`.
Toolchest and EXIT open `panel-toggle session`; lock uses `session lock`.
CPU/MEM use `noctalia.systemStats()` (enable `[system.monitor]`); unavailable
samples show empty meters. BAT hides without a system battery; the first system
battery in sorted sysfs order is shown, polled every 30s (not a multi-battery sum).
BT/VOL display `--` when unavailable; NET shows `offline` without an IPv4 route.

`bar.front` is 840×76 at 1920 logical pixels with `margin_ends = 540`;
for each other output width set `(width - 840) / 2` in its monitor override.
Tiles are 58px wide to fit the mockup's otherwise overcommitted 840px footprint.
Use `noctalia msg bar-toggle front` in a Hyprland bind to hide/show it and release
its reserved space. Neither bar auto-hides. Bar background comes from palette
`surface = #C0C0C0`; widgets paint exact original raised/sunken/well strips.

## Dependencies / provenance / limits

Runtime: Noctalia 5.4.1, Hyprland/hyprctl, socat (optional event acceleration),
iproute2 `ip`, WirePlumber `wpctl`, BlueZ `bluetoothctl`, TeX Gyre Heros; the six
configured applications. No polling process changes devices, volume or Bluetooth.
The state service is shared across all monitor/widget instances.

API verified against exact source `/nix/store/qhijs5gn69985bkdkpl9qxcg7vlazrmw-source`
(`docs/user/plugins/development`, `src/scripting`, `src/shell`). Official examples
consulted at `noctalia-dev/official-plugins@510773a6eb33e50051d7c213d0f8682fd748e9dc`;
implementation and bevels here are original. No fetched assets enter the build.
The palette includes terminal colours: 5.4.1 rejects palettes without that object.
The front widget caches `barWidget.outputName()` at load because state-watch
callbacks lack a bar snapshot in this build (otherwise monitor filtering flickers).
No italics (host label API limitation). Native pop-up panel contents retain
Noctalia's layout; this plugin restyles bars, not the entire shell.

See [TESTING.md](TESTING.md) for isolated screenshots, checks and hardware limits.
