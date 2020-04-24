# dotfiles

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)
[![Made with Doom Emacs](https://img.shields.io/badge/Made_with-Doom_Emacs-blueviolet.svg?style=flat-square&logo=GNU%20Emacs&logoColor=white)](https://github.com/hlissner/doom-emacs)
[![NixOS 20.03](https://img.shields.io/badge/NixOS-v20.03-blue.svg?style=flat-square&logo=NixOS&logoColor=white)](https://nixos.org)

Credit: [hlissner/dotfiles](https://github.com/hlissner/dotfiles)

To keep up with my dotfiles.

I've learned a ton from keeping up with @hlissner's configs and use it as a
technique to improve my own reasoning about software practices and develope my
young opinions. Give them a read and while you're at it come check out [Doom
Emacs][doom-emacs].

## Quick start

```sh
# Assumes your partitions are set up and root is mounted on /mnt
curl https://raw.githubusercontent.com/Emiller88/dotfiles/master/deploy | sh
```

This is equivalent to:

```sh
DOTFILES=/home/$USER/.dotfiles
git clone https://github.com/emiller88/dotfiles $DOTFILES
ln -s /etc/dotfiles $DOTFILES
chown -R $USER:users $DOTFILES

# make channels
nix-channel --add "https://nixos.org/channels/nixos-${NIXOS_VERSION}" nixos
nix-channel --add "https://github.com/rycee/home-manager/archive/release-${NIXOS_VERSION}.tar.gz" home-manager
nix-channel --add "https://nixos.org/channels/nixpkgs-unstable" nixpkgs-unstable

# make /etc/nixos/configuration.nix
nixos-generate-config --root /mnt
echo "import /etc/dotfiles \"$(hostname)\"" >/mnt/etc/nixos/configuration.nix

# make secrets.nix
nix-shell -p gnupg --run "gpg -dq secrets.nix.gpg >secrets.nix"

# make install
nixos-install --root /mnt -I "my=/etc/dotfiles"
```

### Management

- `make` = `nixos-rebuild test`
- `make switch` = `nixos-rebuild switch`
- `make upgrade` = `nix-channel --update && nixos-rebuild switch`
- `make install` = `nixos-generate-config --root $PREFIX && nixos-install --root $PREFIX`
- `make gc` = `nix-collect-garbage -d` (use sudo to clear system profile)

## Overview

- OS: NixOS 19.09
- Shell: zsh
- DE/WM: bspwm + polybar
- Editor: [Doom Emacs][doom-emacs] (and occasionally [vim][vimrc])
- Terminal: st
- Browser: firefox (waiting for qutebrowser to mature)

[doom-emacs]: https://github.com/hlissner/doom-emacs
