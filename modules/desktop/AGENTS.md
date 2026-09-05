# Desktop modules

Most desktop modules target Linux X11/Wayland; `macos/` owns Darwin defaults.
Apps, media, and terminals may support both platforms.

Shared `default.nix` font/compositor/Qt/GTK configuration activates only with
`services.xserver.enable`. Window-manager/desktop selections are mutually
exclusive, enforced by assertion.
