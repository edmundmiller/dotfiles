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
    "gh"
    "fzf"
    "neovim"
    "ruff"
    "uv"
    "tealdeer"
    "joshmedeski/sesh/sesh"
    "seqeralabs/tap/tw"
    "seqeralabs/tap/wave-cli"
    "pulumi/tap/pulumi"
    "awscli"
    "wakatime-cli"

    # Doom dependencies
    "git"
    "ripgrep"
    "coreutils"
    "fd"
    "tree-sitter"
  ];

  casks = [
    # Core productivity
    "1password-cli"
    "raycast"
    "bartender"

    # Development
    "ghostty@tip"
    "claude"

    # Media
    "helium"
    "spotify"
    "soundsource"

    # Fonts
    "font-jetbrains-mono"
  ];

  masApps = {
    "Xcode" = 497799835;
  };
}
