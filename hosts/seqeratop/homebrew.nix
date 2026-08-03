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
    "vibeproxy" # AI subscription proxy on :8317; omp.vibeproxy wires omp to it

    # Media
    "helium"
    "elgato-stream-deck"
    "spotify"
    "soundsource"

    # Fonts
    "font-jetbrains-mono"
  ];

  # Xcode intentionally undeclared. It IS installed from the App Store and fully
  # working: valid Contents/_MASReceipt, `codesign --verify` passes, and
  # `xcodebuild -version` reports 26.6. The problem is Spotlight -- Xcode is the
  # only app in /Applications missing from the index (70 others present), so
  # `mas list`, which reads Spotlight, cannot see it. `brew bundle` therefore
  # treats this entry as unsatisfied and runs `mas install --force 497799835`,
  # which hung ~29h and blocked darwin-rebuild.
  #
  # The importer itself is fine: `mdimport -t -d2 /Applications/Xcode.app`
  # emits kMDItemAppStoreAdamID = 497799835. But `mdimport -f` and
  # `sudo mdutil -E /` both leave the index unchanged. Untried: `sudo mdutil -Eai on`.
  # If that repair lands and `mas list | grep -i Xcode` shows Xcode, restore:
  #   masApps = { "Xcode" = 497799835; };
  masApps = { };
}
