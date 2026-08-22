---
purpose: Preserve meshify's user-owned Omarchy Quattro overrides.
applies_to: Restoring or reviewing Omarchy on the meshify host.
entrypoint: Install plugins, then copy config/ and local/ under $HOME.
verification: Run the checks below, then confirm hyprctl configerrors is empty.
update_when: A tracked meshify Omarchy override changes.
---

# Meshify Omarchy configuration

This directory stores only meshify-specific overrides. Omarchy continues to own
and update its packaged defaults under `/usr/share/omarchy/`.

The repository paths mirror the home directory without leading dots:

- `config/hypr/` → `~/.config/hypr/`
- `config/omarchy/` → `~/.config/omarchy/`
- `local/bin/` → `~/.local/bin/`
- `plugins.txt` → third-party plugins installed with `omarchy plugin add`

Legacy Hyprland `.conf` files, timestamped backups, logs, session state, sample
hooks, and packaged shader symlinks are intentionally excluded.

## Restore

Back up the live files first. Install the third-party plugin and its daemon,
then copy these overrides into place:

```bash
cd ~/.config/dotfiles/hosts/meshify/omarchy
plugin_id=io.github.thisisgm.omapods
if [[ ! -d "$HOME/.config/omarchy/plugins/$plugin_id" ]]; then
  omarchy plugin add "$(< plugins.txt)" --enable
fi
"$HOME/.config/omarchy/plugins/$plugin_id/setup"

install -Dm644 config/hypr/*.lua ~/.config/hypr/
install -Dm644 config/omarchy/shell.json ~/.config/omarchy/shell.json
install -Dm755 local/bin/rocket-league-lmstudio-guard \
  ~/.local/bin/rocket-league-lmstudio-guard
hyprctl reload
hyprctl configerrors
```

The shell reloads `shell.json` automatically.

## Verify the snapshot

```bash
cd ~/.config/dotfiles/hosts/meshify/omarchy
for file in config/hypr/*.lua; do
  diff "$file" "$HOME/.config/hypr/${file##*/}"
done
diff config/omarchy/shell.json ~/.config/omarchy/shell.json
cmp local/bin/rocket-league-lmstudio-guard \
  ~/.local/bin/rocket-league-lmstudio-guard
test "$(git -C ~/.config/omarchy/plugins/io.github.thisisgm.omapods \
  remote get-url origin)" = "$(< plugins.txt)"
omarchy plugin list --json | jq -e \
  'any(.[]; .id == "io.github.thisisgm.omapods" and .enabled)'
systemctl --user is-active --quiet librepods.service
jq empty config/omarchy/shell.json
bash -n local/bin/rocket-league-lmstudio-guard
```
