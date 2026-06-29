{
  # Homebrew configuration for mactraitorpro
  # This file contains all brew packages and casks

  taps = [
    # "jimeh/emacs-builds"  # Not needed, using Nix emacs instead
    "jnsahaj/lumen" # AI-powered CLI explanations
    "keith/formulae" # reminders-cli
    "openclaw/tap" # Discrawl Discord export CLI
    "rjyo/moshi" # moshi-hook + moshi CLI for mobile agent events
    "rockorager/tap" # Prise terminal multiplexer
    "steipete/tap" # Codexbar
    "tw93/tap" # Mole
    "joshmedeski/sesh" # Smart tmux session manager with zoxide integration
    "ahkohd/oyo" # oy - tmux session manager
  ];

  brews = [
    # Development tools
    "autoconf"
    "automake"
    "cmake"
    "gcc"
    "git"
    "go"
    "difi"
    "gitu"
    "jjui"
    "libtool"
    "llvm"
    "m4"
    "make"
    {
      name = "rjyo/moshi/moshi-hook";
      start_service = true;
    }

    # Python tools
    "gdbm"
    "python@3.10" # label-studio runtime dependency
    "uv"

    # JavaScript/Node tools
    "fnm"

    # Shell and terminal tools
    "asciinema"
    "bash"
    "bats-core"
    "fish"
    "shellcheck"
    "shfmt"
    "terminal-notifier"
    "thefuck"
    # "tmux"  # Using Nix-managed tmux for custom config
    "tree"
    "wget"
    "joshmedeski/sesh/sesh"
    "ahkohd/oyo/oy"
    "zoxide"

    # Cloud and infrastructure
    "awscli"
    "aws-shell"
    "cf-terraforming"
    "cloudflare-wrangler"
    "flyctl"
    "gitpod"

    # Data tools
    "aria2"
    "duckdb"
    "dvc"
    "graphviz"
    "harlequin"
    "label-studio"
    "pandoc"
    "postgresql@14"
    "sqlite"
    "sqruff"

    # Media tools
    "ffmpeg"
    "ffmpegthumbnailer"
    "imagemagick"
    "media-info"
    "mpv"
    "sox"
    "tesseract"
    "yt-dlp"

    # Networking and communication
    "rsync"
    "rclone"

    # Security
    "gnupg"
    "gpgme"
    "rage"

    # Utilities
    "jq"
    "yq"
    "mas"
    "mise"
    "openclaw/tap/discrawl"
    "pngpaste"
    "usage"
    "wimlib"
    "z3"

    # Additional tools
    "bookokrat"
    "mole"
    "dataline"
    "eask-cli"
    "harper"
    "html2markdown"
    "jnsahaj/lumen/lumen"
    "reminders-cli"
  ];

  casks = [
    # Core productivity
    "1password"
    "1password-cli"
    "jordanbaird-ice"

    # Communication
    "legcord"
    "zoom"

    # Development
    "visual-studio-code"
    "claude"
    "repo-prompt"
    "warp@preview"
    "tuist"
    "neovide-app" # GUI for Neovim — used by Raycast quake/toggle scripts

    # Browsers
    "google-chrome"

    # Media
    "spotify"
    "vlc"
    "soundsource"
    "subler"

    # Productivity & Notes
    "obsidian"
    "linear" # Linear app
    "granola"

    # AI Tools
    "codexbar"
    "home-assistant"
    # Temporarily disabled: upstream GitHub release download returns HTTP 502.
    # Re-enable when https://github.com/superset-sh/superset/releases is healthy.
    # "superset"
    "lookaway"

    # Utilities
    "elgato-stream-deck"
    "helium"
    "calibre"
    "inkscape"
    "keymapp" # ZSA keyboard firmware flasher
    "neohtop"
    "helpwire-operator"

    # Fonts
    "font-jetbrains-mono"
    "font-juliamono"
    "font-ia-writer-duo"
    "font-maple-mono"
  ];

  masApps = {
    "Keynote" = 409183694;
    "Numbers" = 409203825;
    "Xcode" = 497799835;
  };
}
