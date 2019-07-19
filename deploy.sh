#!/usr/bin/env bash

echo "Nixos"
sudo nix-channel --add https://github.com/rycee/home-manager/archive/master.tar.gz home-manager
sudo nix-channel --update
sudo mkdir -p /etc/nixos
sudo chown -R emiller:root /etc/nixos
sudo ln -sf /home/emiller/.dotfiles/configuration.omen.nix /etc/nixos/configuration.nix
echo "NIXOS-REBUILD SWITCH"
sudo nixos-rebuild switch
