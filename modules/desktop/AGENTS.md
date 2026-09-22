# Desktop modules

Most desktop modules target Linux X11/Wayland; `macos/` owns Darwin defaults.
Apps, media, and terminals may support both platforms.

Shared `default.nix` font/compositor/Qt/GTK configuration activates only with
`services.xserver.enable`. Window-manager/desktop selections are mutually
exclusive, enforced by assertion.

Run `hey check modules/desktop` for shared edits. Add the target platform check
for changes to assertions, package availability, or generated desktop settings;
do not activate a desktop merely to prove evaluation.
