#!/usr/bin/env zsh

_obsidian_cli_dir="/Applications/Obsidian.app/Contents/MacOS"
[[ -d "$_obsidian_cli_dir" ]] && path+=("$_obsidian_cli_dir")
unset _obsidian_cli_dir
