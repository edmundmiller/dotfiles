-- Extra autostart processes migrated from the pre-Quattro config.

-- Add a suspend-only idle listener alongside Omarchy's Quickshell lock timers.
o.launch_on_start("hypridle -q")

-- Steam controller input bypasses Hyprland's idle monitor. Inhibit idle while
-- any Steam game is fullscreen so controller-driven play stays uninterrupted.
o.window("steam_app_.*", { idle_inhibit = "fullscreen" })

-- Keep BakkesMod's Proton windows out of the active gaming workspaces.
o.window({ title = "^BakkesMod(InjectorCpp)?$" }, { workspace = "10 silent" })

-- Reserve the GPU for Rocket League whenever the game is running.
o.launch_on_start("/home/edmundmiller/.local/bin/rocket-league-lmstudio-guard")

-- Retry because Steam can drop the initial launch request while applying updates.
o.launch_on_start("/home/edmundmiller/.local/bin/rocket-league-autostart")
