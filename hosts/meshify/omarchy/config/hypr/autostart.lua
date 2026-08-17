-- Extra autostart processes migrated from the pre-Quattro config.

-- Reserve the GPU for Rocket League whenever the game is running.
o.launch_on_start("/home/edmundmiller/.local/bin/rocket-league-lmstudio-guard")

-- Launch Rocket League after the desktop session and Steam services settle.
o.exec_on_start("sleep 8 && uwsm-app -- steam steam://rungameid/252950")
