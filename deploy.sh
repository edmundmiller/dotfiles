#!/usr/bin/env bash

echo "Nixos"
sudo ln -sf /home/emiller/.dotfiles/nixos /etc/nixos
sudo chown -R emiller:root /etc/nixos
sudo nixos-rebuild boot

echo "Home-manager"
ln -sf /home/emiller/.dotfiles/home /home/emiller/.config/nixpkgs
home-manager switch
