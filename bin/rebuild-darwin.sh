#!/usr/bin/env bash
# Rebuild helper for darwin when not in a terminal

set -e

echo "Building darwin configuration..."
nix build .#darwinConfigurations.MacTraitor-Pro.system

if [[ -f ./result/sw/bin/darwin-rebuild ]]; then
    echo "Build succeeded! To complete activation, run:"
    echo "sudo ./result/sw/bin/darwin-rebuild --flake .#MacTraitor-Pro switch"
else
    echo "Error: darwin-rebuild not found in build result"
    exit 1
fi