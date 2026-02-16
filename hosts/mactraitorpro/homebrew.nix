{
  # Homebrew configuration for mactraitorpro
  # This file contains all brew packages and casks

  taps = [
    # "jimeh/emacs-builds"  # Not needed, using Nix emacs instead
    "jnsahaj/lumen" # AI-powered CLI explanations
    "keith/formulae" # reminders-cli
    "rockorager/tap" # Prise terminal multiplexer
    "seqeralabs/tap"
    "steipete/tap" # Codexbar
    "steveyegge/beads" # Beads debugging tool
    "tw93/tap" # Mole
    "anomalyco/tap" # Opencode
    "max-sixty/worktrunk" # Git worktree management for parallel AI agents
    "joshmedeski/sesh" # Smart tmux session manager with zoxide integration
    "ahkohd/oyo" # oy - tmux session manager
    "chmouel/lazyworktree" # lazyworktree - lazy git worktree switcher
  ];

  brews = [
    # Development tools
    "actionlint"
    "autoconf"
    "automake"
    "cmake"
    "gcc"
    "git"
    "git-lfs"
    "gh"
    "go"
    "gitu"
    "jjui"
    "libtool"
    "llvm"
    "m4"
    "make"
    "nim"
    "python@3.13"
    "r"

    # Python tools
    "pipx"
    "ruff"
    "uv"
    "numpy"
    "openblas"

    # JavaScript/Node tools
    "fnm"

    # Shell and terminal tools
    "asciinema"
    "rockorager/tap/prise" # Modern terminal multiplexer
    "bash"
    "bat"
    "bats-core"
    "btop"
    "coreutils"
    "difftastic"
    "direnv"
    "eza"
    "fd"
    "fish"
    "fzf"
    "glow"
    "lazygit"
    "neovim"
    "ripgrep"
    "sd"
    "shellcheck"
    "shfmt"
    "tealdeer"
    "terminal-notifier"
    "thefuck"
    # "tmux"  # Using Nix-managed tmux for custom config
    "tree"
    "tree-sitter"
    "wget"
    "max-sixty/worktrunk/wt"
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
    "curl"
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
    "pngpaste"
    "usage"
    "seqeralabs/tap/wave-cli"
    "wimlib"
    "z3"

    # Additional tools
    "block-goose-cli"
    "bookokrat"
    "claude-squad"
    "mole"
    "crush"
    "dataline"
    "eask-cli"
    "harper"
    "html2markdown"
    "jnsahaj/lumen/lumen"
    "opencode"
    "steveyegge/beads/bd"

    "reminders-cli"
    "wakatime-cli"
  ];

  casks = [
    # Core productivity
    "1password"
    "1password-cli"
    # "raycast"  # Managed by modules.desktop.apps.raycast
    "jordanbaird-ice"

    # Communication
    "slack"
    "legcord"
    "microsoft-teams"
    "microsoft-auto-update"
    "zoom"

    # Development
    "ghostty@tip"
    "visual-studio-code"
    "claude"
    "repo-prompt"
    # "emacs-app-pretest"  # Conflicts with emacs-app, using Nix version instead
    "positron"
    "zed"
    "warp@preview"
    "termius@beta"
    "tuist"

    # Browsers
    "google-chrome"
    "orion"
    "vivaldi"
    "zen"

    # Media
    "spotify"
    "vlc"
    "soundsource"
    "subler"
    "openaudible"

    # Productivity & Notes
    "obsidian"
    "logseq"
    "anytype"
    "capacities"
    "heptabase"
    "sunsama"
    "linear-linear"
    "motion"
    "granola"

    # AI Tools
    "block-goose"
    "claude-code"
    "codexbar"
    "superset"
    "voicenotes"

    # Git/Development utilities
    "chmouel/lazyworktree/lazyworktree"

    # Utilities
    # FIXME: gitify cask has invalid 'uninstall' stanza with unsupported :on_upgrade key
    # "gitify"
    "calibre"
    "inkscape"
    "keymapp" # ZSA keyboard firmware flasher
    "mactex"
    "mendeley-reference-manager"
    "neohtop"
    "helpwire-operator"
    "bentobox"
    "flashspace"
    "aqua-voice"

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
