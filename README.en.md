# 標 (Shirube)

[日本語](README.md)

Shirube is a QuickShell interface for Niri and Hyprland. It presents desktop
information as floating holograms inside a softly fading field of light emerging
from the left edge, rather than as widgets placed on an opaque sidebar.

> [!NOTE]
> Shirube is a personal project originally built by the author for their own
> environment, with the assistance of AI. It has currently been tested only on
> the author's setup, so operation on other configurations is not guaranteed.
> The author's own use case takes priority. Feature requests may not be accepted,
> and no ongoing maintenance or updates are promised.

## Features

- Niri / Hyprland workspace display and switching with formal Japanese numerals
- Average and per-core CPU usage, memory, volume, network, and battery details
- Luminous status rings for CPU, memory, audio, network, and battery
- A vertical formal-numeral clock and a calendar with traditional Japanese month names
- A continuous light field that reshapes around expanded content
- Subtle floating motion, a moving light edge, and startup/open/close animations
- Optional light response to the current PipeWire output level
- Live JSON configuration for fonts, colors, layout, motion, polling, and actions
- Automatic Matugen palette loading with animated transitions and safe fallback
- CLI / QuickShell IPC control
- Automatic hiding of the battery module on systems without a battery
- Optional QuickShell process sharing with the independently packaged Kaname app

Shirube deliberately does not include a window overview or switcher.

## Interaction

| Item | Action |
| --- | --- |
| Workspace | Click to focus it |
| 算 / 録 / 音 / 信 / 電 | Click to toggle details |
| Audio | Scroll to change volume |
| Clock | Click to toggle the calendar |
| Detail view | Closes after the pointer leaves both the source and details |
| Middle action | Click to run its configured command |

The default `☯` action runs `wofi --show drun`; `終` runs wlogout. These programs
are optional and must be installed separately if used.

## Requirements

- Niri or Hyprland on Wayland
- QuickShell 0.3.x
- PipeWire / WirePlumber for audio (`pw-record`, `wpctl`)
- NetworkManager for network status (`nmcli`)
- A C11 compiler for the audio-level helper
- Optional: Wofi, wlogout, Makinas, and Matugen 4.x

CPU and memory data come from `/proc`; battery data comes from
`/sys/class/power_supply`. Missing optional commands do not prevent startup.
When Makinas is unavailable, Shirube tries `Noto Sans CJK JP` and then the
system `sans-serif`.

Memory usage follows htop's Linux memory meter: free memory, buffers, cache, and
reclaimable slab are excluded from application-used memory.

## Installation

### NixOS (recommended)

Add Shirube as a flake input and import its NixOS module.

```nix
{
  inputs.shirube.url = "github:bakumugi777/Shirube";

  outputs = { nixpkgs, shirube, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        shirube.nixosModules.default
        {
          programs.shirube.enable = true;
          programs.shirube.autostart = true;
        }
      ];
    };
  };
}
```

### Home Manager

```nix
{
  imports = [ inputs.shirube.homeManagerModules.default ];
  programs.shirube.enable = true;
  programs.shirube.autostart = true;
}
```

Both modules create a systemd user service tied to `graphical-session.target`.

### Run or install directly from the flake

```sh
nix run github:bakumugi777/Shirube
nix profile install github:bakumugi777/Shirube#shirube
shirube
```

### Other Linux distributions

Install the requirements and run from the repository root:

```sh
sh install.sh
systemctl --user enable --now shirube.service
```

Add `~/.local/bin` to `PATH` if necessary. A normal uninstall preserves configuration.

```sh
sh uninstall.sh
sh uninstall.sh --purge  # also remove ~/.config/shirube
```

## Starting and stopping

```sh
shirube             # start
shirube quit        # terminate Shirube
systemctl --user restart shirube.service
systemctl --user stop shirube.service
```

## Configuration

The launcher creates `~/.config/shirube/config.json`. Shirube watches this file
and reloads saved changes. Missing keys and invalid JSON fall back to built-in
defaults. See [`config.json`](config.json) for every key and its current value.

### Fonts

| Key | Default | Purpose |
| --- | ---: | --- |
| `font.family` | `Makinas` | Preferred family |
| `font.fallbacks` | `Noto Sans CJK JP`, `sans-serif` | Ordered fallbacks |
| `font.moduleSize` | `14` | Module text size |
| `font.workspaceSize` | `14` | Workspace text size |
| `font.clockSize` | `16` | Clock text size |
| `font.weight` | `500` | Normal text weight |
| `font.letterSpacing` | `1.5` | Letter spacing |

### Layout

| Key | Default | Purpose |
| --- | ---: | --- |
| `layout.exclusiveZoneWidth` | `64` | Width reserved from tiled windows |
| `layout.compactSurfaceWidth` | `90` | Compact UI reference width |
| `layout.lightWidth` | `90` | Idle light-field width |
| `layout.expandedSurfaceWidth` | `380` | Maximum deformation drawing area |
| `layout.moduleAxis` | `26` | Module-center X coordinate |

The exclusive zone changes compositor layout. The larger drawing surface is
input-transparent outside actual controls.

### Appearance

| Keys | Purpose |
| --- | --- |
| `idleOpacity`, `subduedOpacity`, `hoverOpacity` | State opacity |
| `hologramPanelOpacity` | Detail backing density |
| `lightUnderlayOpacity` | Dark contrast layer that follows and fades with the light field |
| `glowIntensity`, `textGlowIntensity` | Overall and text glow |
| `ringTransitionMs` | Status-ring value transition duration |
| `paletteTransitionMs` | Animated palette transition time |
| `ambientAnimationEnabled` | Master ambient-animation switch |
| `floatingEnabled`, `floatingAmplitude`, `floatingPeriodMs` | Module drift |
| `lightWaveEnabled`, `lightWaveAmplitude`, `lightWavePeriodMs`, `lightWaveFps` | Moving light edge |
| `lightFieldStripHeight` | Drawing density; lower is smoother and costlier |
| `audioReactionEnabled`, `audioReactionStrength` | Audio-driven response |
| `audioReactionAttackMs`, `audioReactionReleaseMs`, `audioReactionBrightness` | Audio response timing and brightness |

Audio is converted to 2 kHz mono only for analysis; playback is unchanged. To
reduce CPU use, lower `lightWaveFps`, raise `lightFieldStripHeight`, or disable
ambient animation/audio response.

### Animation and polling

`animation.enabled` disables all animations and audio analysis. Interaction and
startup timing are controlled by `interactionMs`, `startupLightMs`,
`startupUiDelayMs`, and `startupUiMs`.

The `updates` section contains `systemMs`, `desktopMs`, `audioMs`, `networkMs`,
`batteryMs`, and `workspaceFallbackMs`. All are milliseconds. Workspace updates
prefer compositor events.

### Middle actions

```json
{
  "middle": {
    "spacing": 6,
    "actions": [{
      "symbol": "☯",
      "name": "Launcher",
      "command": ["wofi", "--show", "drun"],
      "enabled": true,
      "size": 14
    }]
  }
}
```

Executable-and-argument arrays are recommended. A command string runs through
`sh -c`. `enabled` and `size` are optional.

### Colors

The `colors` section exposes text (`accent`, `text`, `subduedText`, `brightText`,
`caption`), workspace/clock, ring, light-field, and `hologramPanel` colors. Use
`#RRGGBB` or `#RRGGBBAA`. See [`config.json`](config.json) for the complete list.
Values in `colors.overrides` take priority over default and Matugen palettes.

## Matugen

Shirube watches `~/.config/shirube/matugen-colors.json`. Valid `accent`, `text`,
and `surface` values activate the generated palette. When `secondary` and
`tertiary` are also present, Shirube uses whichever candidate has the greatest
hue distance from the wallpaper-derived `accent`. Legacy three-color files
remain supported. Missing, incomplete, or malformed required data falls back to
the default blue palette.

Candidate selection uses the shortest distance around the HSL hue circle. With
hues represented from `0.0` to `1.0`, the distance is
`min(abs(a - b), 1 - abs(a - b))`. This is a low-cost approximation that treats
Matugen's `primary` as the wallpaper's representative color; it does not inspect
screen pixels or include lightness and saturation in candidate selection.

```json
{
  "accent": "#9acbfa",
  "secondary": "#b8c4ff",
  "tertiary": "#e0b6dc",
  "text": "#e0e2e8",
  "surface": "#142631"
}
```

Use `matugen/templates/shirube-colors.json` with Matugen 4.x; an integration
example is provided in `matugen/config.example.toml`.

## IPC and key bindings

```sh
shirube open cpu
shirube toggle audio
shirube close
shirube quit
```

Modules: `cpu`, `memory`, `audio`, `network`, `battery`, `calendar`. Aliases:
`mem`, `volume`, `sound`, `net`, `bat`, `clock`, `date`. `close` hides details;
`quit` terminates Shirube.

Niri example:

```kdl
Mod+V { spawn "shirube" "toggle" "audio"; }
```

## Optional Kaname process sharing

Kaname is not bundled. If both apps are installed independently, they may share
one QuickShell process:

```nix
programs.shirube.sharedShell = {
  enable = true;
  kanamePackage =
    inputs.kaname.packages.${pkgs.stdenv.hostPlatform.system}.default;
};
```

Disable Kaname's standalone autostart while sharing. Kaname is neither evaluated
nor installed by default. See [`examples/shared-shell/`](examples/shared-shell/).

## Development

```sh
nix run .
nix flake check
```

Checks build the package and run ShellCheck and JSON validation. Build only the
RMS helper with `sh helpers/build.sh` or `make -C helpers`.

## License

Shirube is released under the [MIT License](LICENSE). Modification,
redistribution, and commercial use are permitted, and the software is provided
without warranty as described in the license.
