---
purpose: Describe the Herdr action that previews clicked GitHub issues and pull requests.
applies_to: Installing, using, or changing dotfiles.github-link-preview.
entrypoint: Read herdr-plugin.toml, then github_link_preview.py.
verification: Link the plugin and invoke its action on a GitHub issue or pull request URL.
update_when: Herdr link-handler context, GitHub CLI behavior, or plugin actions change.
---

# Dotfiles GitHub Link Preview

Herdr plugin for previewing GitHub issue and pull request URLs in a side pane.

## Install

```bash
herdr plugin install edmundmiller/dotfiles/packages/herdr-plugins/dotfiles-github-link-preview
```

## Entrypoints

- Action: `dotfiles.github-link-preview.preview`
- Link handler: GitHub issue and pull request URLs

## Requirements

- Herdr `0.7.0` or newer
- `python3`
- GitHub CLI authenticated with `gh auth login`
