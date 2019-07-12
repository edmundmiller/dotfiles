# dotfiles

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

Credit: [hlissner/dotfiles](https://github.com/hlissner/dotfiles)

To keep up with my dotfiles.

+ shell: zsh
+ font: Iosevka

## Quick start

`bash <(curl -s https://raw.githubusercontent.com/emiller88/dotfiles/master/bootstrap.sh)`

`ln -s ~/.dotfiles/configuration.$HOSTNAME.nix /etc/nixos/configuration.nix`

`sudo nixos-rebuild switch`

## Overview

```sh
# general
bin/       # global scripts
assets/    # wallpapers, sounds, screenshots, etc

# categories
base/      # provisions my system with the bare essentials
dev/       # relevant to software development & programming in general
editor/    # configuration for my text editors
misc/      # for various apps & tools
shell/     # shell utilities, including zsh + bash
```

## Relevant projects

+ [DOOM Emacs](https://github.com/hlissner/doom-emacs) (pulled by `editor/emacs`)
+ [Henrik's vim config](https://github.com/hlissner/.vim) (pulled by `editor/{neo,}vim`)
