{
  # Homebrew configuration for seqeratop (work machine)
  # This file contains all brew packages and casks

  taps = [
    "seqeralabs/tap"
    "pulumi/tap"
    "joshmedeski/sesh"
  ];

  brews = [
    # Development tools
    "duckdb"
    "dvc"
    "uv"
    "tealdeer"
    "joshmedeski/sesh/sesh"
    "seqeralabs/tap/tw"
    "seqeralabs/tap/wave-cli"
    "pulumi/tap/pulumi"
    "awscli"
    "wakatime-cli"
  ];

  casks = [
    # Core productivity
    "1password-cli"
    "raycast"
    "bartender"

    # Development
    "claude"
    "linear" # Linear app
    "superset"
    "lookaway"

    # Media
    "helium"
    "elgato-stream-deck"
    "spotify"
    "soundsource"

    # Fonts
    "font-jetbrains-mono"
  ];

  masApps = {
    "Xcode" = 497799835;
  };
}
