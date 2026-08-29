-- Extra autostart processes migrated from the pre-Quattro config.

-- Steam controller input bypasses Hyprland's idle monitor. Inhibit idle while
-- any Steam game is fullscreen so controller-driven play stays uninterrupted.
o.window("steam_app_.*", { idle_inhibit = "fullscreen" })

-- Reserve the GPU for Rocket League whenever the game is running.
o.launch_on_start("/home/edmundmiller/.local/bin/rocket-league-lmstudio-guard")

-- Retry because Steam can drop the initial launch request while applying updates.
o.launch_on_start("/home/edmundmiller/.local/bin/rocket-league-autostart")
