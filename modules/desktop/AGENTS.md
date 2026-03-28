# Desktop Modules

GUI applications, terminals, window managers, and desktop environment config. Most subdirectories are **Linux-only** (X11/Wayland); macOS-specific modules live in `macos/`.

## Subdirectories

| Directory    | Purpose                                    | Platform |
| ------------ | ------------------------------------------ | -------- |
| `apps/`      | Desktop applications (openclaw client, etc.)| Mixed    |
| `browsers/`  | Firefox, qutebrowser                       | Linux    |
| `gaming/`    | Game-related packages                      | Linux    |
| `gnome/`     | GNOME desktop tweaks                       | Linux    |
| `macos/`     | macOS-specific desktop config              | Darwin   |
| `media/`     | Media players, mpv, etc.                   | Mixed    |
| `term/`      | Terminal emulators (ghostty, kitty, etc.)  | Mixed    |
| `themes/`    | Desktop theming                            | Linux    |
| `vm/`        | Virtual machine config                     | Linux    |

## Top-Level Files

- `default.nix` — Shared desktop config (fonts, picom, Qt/GTK theming). Only activates when `services.xserver.enable = true`.
- `bspwm.nix`, `gnome.nix`, `kde.nix` — Window manager / DE modules. Only one can be enabled at a time (enforced by assertion).

## Subdirectories with Their Own AGENTS.md

- `apps/openclaw/` — OpenClaw Mac remote client
- `macos/` — macOS desktop settings
- `term/ghostty/` — Ghostty terminal emulator
