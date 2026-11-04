# Herdr T3 source

Vendored from [JinJieBeWater/herdr-t3](https://github.com/JinJieBeWater/herdr-t3)
at commit `e51653943ec79862eb5b58613df344faa9900af0`, the version installed and
checked in the desktop app. The Apache-2.0 license is in `LICENSE`.

Only the layout, its SVG preview and the seven runtime mod folders are included.
Repository formatting is applied without changing their behavior. Upstream's
optional theme and pulls.review integration are not installed.

`modules/shell/herdr/native.nix` installs these files only when
`modules.shell.herdr.native.app.enable` is true. Ctrl+C prefix bindings live in
`../mods/dotfiles-prefix/`, not in this upstream copy. Ctrl+Shift+L switches
between the shipped `main` layout and `herdr-t3`.

The Spaces mod runs read-only Git commands in workspace folders, watches Git
metadata and lists Herdr machines. Focus writes terminal labels when settling
or unsettling agents. The mods make no direct network requests. New terminal
and agent launches use Herdr's normal commands.

To update, review the new upstream recipe and runtime files, replace this copy,
update the commit above, and check every mod with `herdr-app check`. Preserve
the license. Do not copy generated typings, runtime state or personal theme
settings from an installed app.
