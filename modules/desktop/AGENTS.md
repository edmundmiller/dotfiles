# Desktop modules

`macos/` owns Darwin defaults. Apps, media, and terminals may support both
platforms. Meshify's desktop recovery belongs to `hosts/meshify/omarchy/`.

Shared Linux fonts and applications in `default.nix` require an explicit
`modules.desktop.enable = true`. They do not select X11, a compositor, or a
desktop environment. GNOME, KDE, Rofi and st deployments are retired.

Run `hey check modules/desktop` for shared edits. Add the target platform check
for changes to assertions, package availability, or generated desktop settings;
do not activate a desktop merely to prove evaluation.
