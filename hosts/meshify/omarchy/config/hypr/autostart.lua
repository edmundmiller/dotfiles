-- Extra autostart processes migrated from the pre-Quattro config.

-- Reserve the GPU for Rocket League whenever the game is running.
o.launch_on_start("/home/edmundmiller/.local/bin/rocket-league-lmstudio-guard")

-- Retry because Steam can drop the initial launch request while applying updates.
o.launch_on_start("/home/edmundmiller/.local/bin/rocket-league-autostart")
