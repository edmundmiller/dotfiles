# darwin-base.nix
# Shared configuration for all nix-darwin systems
{
  config,
  inputs,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
{
  config = optionalAttrs isDarwin {
    # Determinate's installer/Nixd owns the runtime and nix.conf. The module
    # writes only nix.custom.conf, the registry and Nixd configuration.
    determinateNix = {
      enable = true;
      registry = mapAttrs (_: v: { flake = v; }) (removeAttrs inputs [ "self" ]) // {
        dotfiles.flake = inputs.self;
      };
      customSettings = {
        extra-substituters = [
          "https://nix-community.cachix.org"
          "https://hyprland.cachix.org"
          "https://cosmic.cachix.org/"
          "https://cache.numtide.com" # llm-agents.nix binary cache
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" # llm-agents.nix
        ];
        trusted-users = [
          "root"
          config.system.primaryUser
        ];
        allowed-users = [
          "root"
          config.system.primaryUser
        ];
        # Keep legacy <input> lookups without overriding Nixd's extra-nix-path.
        nix-path = mapAttrsToList (n: v: "${n}=${v}") (removeAttrs inputs [ "self" ]) ++ [
          "nixpkgs-overlays=${lib.my.dotFilesDir}/overlays"
          "dotfiles=${lib.my.dotFilesDir}"
        ];
        # Increase download buffer size for large derivations (e.g., texlive)
        download-buffer-size = 134217728; # 128MB (default is 64MB)

        # Bound build parallelism. Nix multiplies these: max-jobs concurrent
        # derivations, each allowed `cores` threads. The stock pairing here is
        # max-jobs = auto (= ncpu) with cores = 0 (= ncpu), which permits
        # ncpu^2 threads -- on an 11-core host that is 121, and a patched Rust
        # build (hunk/herdr carry local patches, so no cache can serve them)
        # drove load to 258 and exhausted 34GB of swap.
        #
        # Each host pins max-jobs = ncpu / 2 so the product still saturates the
        # machine while halving the number of simultaneous memory-holding
        # builds -- memory, not CPU, is what falls over first.
        cores = mkDefault 2;
      };
      # Keep the existing seven-day generation retention policy and one GC
      # owner. Disk-pressure GC does not prune generations the same way.
      determinateNixd.garbageCollector.strategy = "disabled";
      # Work-machine policy: no crash reports or usage telemetry.
      determinateNixd.telemetry.sentry.endpoint = null;
      envVars.DETSYS_IDS_TELEMETRY = "disabled";
    };

    # Nixd runs from the installer's plist, which shell variables never reach.
    # Determinate upgrades rewrite it; the next activation patches it again.
    system.activationScripts.postActivation.text = ''
      plist=/Library/LaunchDaemons/systems.determinate.nix-daemon.plist
      pb=/usr/libexec/PlistBuddy
      if [[ -f $plist ]] &&
         [[ "$($pb -c 'Print :EnvironmentVariables:DETSYS_IDS_TELEMETRY' "$plist" 2>/dev/null)" != disabled ]]; then
        echo "disabling Determinate Nixd telemetry..." >&2
        $pb -c 'Add :EnvironmentVariables dict' "$plist" 2>/dev/null || true
        $pb -c 'Add :EnvironmentVariables:DETSYS_IDS_TELEMETRY string disabled' "$plist" 2>/dev/null ||
          $pb -c 'Set :EnvironmentVariables:DETSYS_IDS_TELEMETRY disabled' "$plist"
        # kickstart keeps the cached job definition; reload to apply the env.
        launchctl bootout system/systems.determinate.nix-daemon || true
        for _ in 1 2 3 4 5; do
          launchctl bootstrap system "$plist" && break
          sleep 1
        done
        launchctl print system/systems.determinate.nix-daemon >/dev/null
      fi
    '';

    # Adopt only the exact generated policy staged before the installer starts.
    environment.etc."determinate/config.json".knownSha256Hashes = [
      (builtins.hashString "sha256" config.environment.etc."determinate/config.json".text)
    ];

    # Refuse to relinquish the old daemon before the independent runtime exists.
    system.activationScripts.preActivation.text = mkBefore ''
      if [[ ! -x /nix/var/nix/profiles/default/bin/nix ]] ||
         [[ "$(/nix/var/nix/profiles/default/bin/nix --version)" != *"Determinate Nix"* ]]; then
        echo "Determinate runtime missing; install the signed macOS package before activating. See docs/runbooks/determinate-darwin.md." >&2
        exit 1
      fi

      # Legacy launchctl unload can fail while nix-darwin removes its plist.
      # Boot out the loaded service by label before it can compete with Nixd.
      if launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
        launchctl bootout system/org.nixos.nix-daemon
      fi
    '';

    # Use the installer-managed tools, never a second nixpkgs Nix runtime.
    # These retain the old job labels and schedules without nix.enable.
    launchd.daemons = {
      nix-gc = {
        command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 7d";
        serviceConfig.ProcessType = "Background";
        serviceConfig.LowPriorityIO = true;
        serviceConfig.StandardOutPath = "/var/log/nix-gc.log";
        serviceConfig.StandardErrorPath = "/var/log/nix-gc.err.log";
        serviceConfig.RunAtLoad = false;
        serviceConfig.StartCalendarInterval = {
          Weekday = 0;
          Hour = 2;
          Minute = 0;
        };
      };
      nix-optimise = {
        command = "/nix/var/nix/profiles/default/bin/nix-store --optimise";
        serviceConfig.ProcessType = "Background";
        serviceConfig.LowPriorityIO = true;
        serviceConfig.StandardOutPath = "/var/log/nix-optimise.log";
        serviceConfig.StandardErrorPath = "/var/log/nix-optimise.err.log";
        serviceConfig.RunAtLoad = false;
        serviceConfig.StartCalendarInterval = [
          {
            Weekday = 7;
            Hour = 4;
            Minute = 15;
          }
        ];
      };
    };

    # Use macOS's existing rotation service. Rotate at 1 MiB; keep seven archives.
    # No signal or compression: a running one-shot job may still hold the old
    # file open, and launchd opens the current path on its next scheduled run.
    environment.etc."newsyslog.d/nix-maintenance.conf".text = ''
      # logfilename                 owner:group mode count size when flags
      /var/log/nix-gc.log           root:wheel  640  7     1024 *    N
      /var/log/nix-gc.err.log       root:wheel  640  7     1024 *    N
      /var/log/nix-optimise.log     root:wheel  640  7     1024 *    N
      /var/log/nix-optimise.err.log root:wheel  640  7     1024 *    N
    '';

    # Darwin state version
    system.stateVersion = 4;

    # Home-manager integration
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };

    # Fix nixbld group ID mismatch (common Darwin issue)
    ids.gids.nixbld = 350;

    # Set the user's default shell to zsh
    users.users.${config.user.name}.shell = pkgs.zsh;
  };
}
