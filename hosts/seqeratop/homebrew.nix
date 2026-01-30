{
  # Homebrew configuration for seqeratop (work machine)
  # This file contains all brew packages and casks

  taps = [
    "seqeralabs/tap"
    "pulumi/tap"
    "max-sixty/worktrunk"
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
    "max-sixty/worktrunk/wt"
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
    "positron"
    "repo-prompt"
    "claude"

    # Communication & Productivity
    "sunsama"
    "gitify"

    # Media
    "spotify"
    "soundsource"

    # Fonts
    "font-jetbrains-mono"
  ];

  masApps = {
    "Xcode" = 497799835;
  };
}
