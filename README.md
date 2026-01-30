<div align="center">
   
[![Made with Doom Emacs](https://img.shields.io/badge/Made_with-Doom_Emacs-blueviolet.svg?style=flat-square&logo=GNU%20Emacs&logoColor=white)](https://github.com/hlissner/doom-emacs)
[![NixOS 24.11](https://img.shields.io/badge/NixOS-v24.11-blue.svg?style=flat-square&logo=NixOS&logoColor=white)](https://nixos.org)
[![nix-darwin](https://img.shields.io/badge/nix--darwin-24.11-green.svg?style=flat-square&logo=apple&logoColor=white)](https://github.com/nix-darwin/nix-darwin)

</div>

**Hey,** you. You're finally awake. You were trying to configure your OS declaratively, right? Walked right into that NixOS ambush, same as us, and those dotfiles over there.

> **Good news, traveler!** These dotfiles now work on both NixOS and macOS. One config to rule them all, and in the darkness bind them.

```sh
# Quick taste of what you're in for:
nix run nix-darwin -- switch --flake ~/.config/dotfiles  # macOS
nixos-rebuild switch --flake .#hostname                   # NixOS
```

---

|                |                                                           |
| -------------- | --------------------------------------------------------- |
| **Shell:**     | zsh + a bunch of Nix magic                                |
| **DM:**        | lightdm + lightdm-mini-greeter                            |
| **WM:**        | bspwm + polybar (Linux) / Aerospace (macOS)               |
| **Editor:**    | [Doom Emacs][doom-emacs] (and nvim when Emacs is napping) |
| **Terminal:**  | st (Linux) / Ghostty (macOS)                              |
| **Launcher:**  | rofi (Linux) / Raycast (macOS)                            |
| **Browser:**   | firefox / Zen Browser / Orion (I collect browsers)        |
| **GTK Theme:** | [Ant Dracula](https://github.com/EliverLara/Ant-Dracula)  |

---

## Quick start

### NixOS? I used to be an adventurer like you...

1. Acquire [NixOS 24.11][nixos] (or close enough).
2. Boot into the installer.
3. Do your partitions and mount your root to `/mnt` (or don't, I'm not your supervisor)
4. `git clone https://github.com/emiller88/dotfiles /etc/nixos`
5. Install NixOS: `nixos-install --root /mnt --flake /etc/nixos#XYZ`, where `XYZ` is your
   hostname. Use `#generic` for a simple, universal config.
6. OPTIONAL: Create a sub-directory in `hosts/` for your device. See [host/kuro]
   as an example.
7. Reboot!

### macOS? Let me guess, someone stole your sweetroll.

1. Install Nix using the [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer) (it's like the official installer, but actually works):
   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```
   Why this installer? It handles macOS quirks, enables flakes by default, and won't leave you troubleshooting for hours.
2. `git clone https://github.com/emiller88/dotfiles ~/.config/dotfiles`
3. `cd ~/.config/dotfiles`
4. `./bin/hey re` (or if `hey` isn't in your PATH yet: `nix run .#darwinConfigurations.HOSTNAME.system.build.darwin-rebuild -- switch --flake .`)
   - Use `MacTraitor-Pro` or `Seqeratop` for HOSTNAME, or check `flake.nix` for available configs
5. Grab a coffee while Nix downloads the internet
6. `sudo ./result/sw/bin/darwin-rebuild --flake .#HOSTNAME switch` when prompted

## Management

And I say, `bin/hey`. [What's going on?](https://www.youtube.com/watch?v=ZZ5LpwO-An4)

| Command           | Description                                                     |
| ----------------- | --------------------------------------------------------------- |
| `hey rebuild`     | Rebuild this flake (shortcut: `hey re`)                         |
| `hey upgrade`     | Update flake lockfile and switch to it (shortcut: `hey up`)     |
| `hey rollback`    | Roll back to previous system generation                         |
| `hey gc`          | Runs `nix-collect-garbage -d`. Use sudo to clean system profile |
| `hey push REMOTE` | Deploy these dotfiles to REMOTE (over ssh)                      |
| `hey check`       | Run tests and checks for this flake                             |
| `hey show`        | Show flake outputs of this repo                                 |

## Frequently asked questions

- **How do I change the default username?**
  1. Set `USER` the first time you run `nixos-install`: `USER=myusername nixos-install --root /mnt --flake #XYZ`
  2. Or change `"emiller"` in modules/options.nix (was `"hlissner"` in the before times).
  3. For macOS: just make sure your username matches what's in the flake

- **How do I "set up my partitions"?**

  My main host [has a README](hosts/kuro/README.org) you can use as a reference.
  I set up an EFI+GPT system and partitions with `parted` and `zfs`.

  macOS users: You can skip this part and feel smug about it.

- **Why is my build failing with homebrew errors?**

  That's just homebrew being homebrew. The build succeeded, you just need to run the
  activation with sudo. Check the message at the end of `hey re`.

- **How 2 flakes?**

  It wouldn't be the NixOS experience if I gave you all the answers in one,
  convenient place. But basically: everything is a flake now, resistance is futile.

[doom-emacs]: https://github.com/hlissner/doom-emacs
[vim]: https://github.com/hlissner/.vim
[nixos]: https://releases.nixos.org/?prefix=nixos/24.11/
[host/kuro]: https://github.com/hlissner/dotfiles/tree/master/hosts/kuro

## Usage as a flake

[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/Emiller88/dotfiles/badge)](https://flakehub.com/flake/Emiller88/dotfiles)

Add dotfiles to your `flake.nix`:

```nix
{
  inputs.dotfiles.url = "https://flakehub.com/f/Emiller88/dotfiles/*.tar.gz";

  outputs = { self, dotfiles }: {
    # Use in your outputs
  };
}

```
