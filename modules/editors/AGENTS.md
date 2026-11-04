# Editors

`modules.editors.default` selects `$EDITOR` (default `vim`). Modules install
packages and link dotfiles from `config/`; editor configuration belongs there.

Run `hey check modules/editors` plus the edited `config/<editor>` path. Use that
editor's scoped smoke check for runtime configuration; module evaluation alone
only checks installation and linking.
