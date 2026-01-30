# Homebrew Activation Fix for nix-darwin

## Problem

When running `sudo darwin-rebuild switch` with homebrew enabled in your nix-darwin configuration, you'll encounter this error:

```
Error: Running Homebrew as root is extremely dangerous and no longer supported.
```

This happens because:

1. Recent versions of nix-darwin (24.11+) require `sudo` for system activation
2. Homebrew refuses to run as root for security reasons
3. The `homebrew.user` option that existed in older versions has been removed

## Solution

We use a two-step activation process:

### Step 1: System Activation (with sudo)

Run the darwin-rebuild with sudo, allowing it to fail on the homebrew step:

```bash
sudo ./result/sw/bin/darwin-rebuild --flake .#MacTraitor-Pro switch || true
```

This will:

- Apply all system configurations
- Set up launchd services
- Configure system defaults
- Fail at the homebrew bundle step (which is okay)

### Step 2: Homebrew Activation (without sudo)

Run the manual homebrew activation script as your regular user:

```bash
./bin/activate-homebrew
```

This script:

- Finds the generated Brewfile in the nix store
- Runs `brew bundle` as your user (not root)
- Installs/updates all packages defined in your configuration

## Automated Helper

The `hey re` command has been updated to provide instructions when running without a terminal:

```bash
./bin/hey re
```

Will output:

```
Build succeeded!
To complete activation, run:
  sudo ./result/sw/bin/darwin-rebuild --flake .#MacTraitor-Pro switch

Note: If you get a homebrew error, run these commands separately:
  1. sudo ./result/sw/bin/darwin-rebuild --flake .#MacTraitor-Pro switch || true
  2. ./bin/activate-homebrew
```

## Configuration

Your homebrew configuration in `hosts/mactraitorpro/default.nix` remains unchanged:

```nix
homebrew = {
  enable = true;

  onActivation = {
    autoUpdate = false;
    cleanup = "none";
    upgrade = false;
  };

  taps = [ "jimeh/emacs-builds" ];
  brews = [ "gh", "fzf", "neovim", ... ];
  casks = [ "ghostty", "raycast", ... ];
  masApps = { "Keynote" = 409183694; ... };
};
```

## Technical Details

### Why This Happens

- nix-darwin 24.11+ changed to require root for all system activation
- The old user activation system (extraUserActivation) was removed
- Homebrew's security model explicitly prevents root execution
- There's currently no built-in way in nix-darwin to drop privileges for specific activation steps

### Alternative Approaches Considered

1. **nix-homebrew module**: Requires additional setup and may have compatibility issues
2. **Custom activation module**: Too complex and fragile, would need to override internal nix-darwin behavior
3. **Disabling homebrew in nix-darwin**: Loses declarative package management benefits

### Future Improvements

The nix-darwin team is aware of this issue and may implement a built-in solution in future versions. Until then, this two-step approach provides a reliable workaround.

## Troubleshooting

If `activate-homebrew` can't find the Brewfile:

1. Make sure you've run `darwin-rebuild build` or `hey re` first
2. Check that the build succeeded and created the `./result` symlink
3. Manually locate the Brewfile: `find /nix/store -name "Brewfile" -path "*/darwin-system*"`

If homebrew packages aren't installing:

1. Check homebrew is installed: `which brew`
2. Update homebrew: `brew update`
3. Check for conflicts: `brew doctor`
4. Run with verbose output: `brew bundle --file=/path/to/Brewfile --verbose`
