# nixos-base.nix
# NixOS-specific base configuration
{
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
{
  config = mkIf (!isDarwin) {
    # NixOS state version
    system.stateVersion = "25.05";

    # Nix optimization (use the newer API)
    nix.optimise.automatic = true;

    # Bound build parallelism; see modules/darwin-base.nix for the full
    # reasoning. Nix multiplies max-jobs by cores, and the stock cores = 0
    # means "every core", so leaving it unset lets ncpu^2 threads run. Each
    # host pins max-jobs = ncpu / 2 to pair with this.
    nix.settings.cores = mkDefault 2;

    ## Some reasonable, global defaults
    # This is here to appease 'nix flake check' for generic hosts with no
    # hardware-configuration.nix or fileSystem config.
    fileSystems."/".device = mkDefault "/dev/disk/by-label/nixos";

    boot = {
      kernelPackages = mkDefault pkgs.linuxKernel.packages.linux_6_1;
      loader = {
        efi.canTouchEfiVariables = mkDefault true;
        systemd-boot.configurationLimit = 10;
        systemd-boot.enable = mkDefault true;
      };
    };

    # XDG base directory specification (NixOS uses sessionVariables)
    environment.sessionVariables = {
      # These are the defaults, and xdg.enable does set them, but due to load
      # order, they're not set before environment.variables are set, which could
      # cause race conditions.
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_BIN_HOME = "$HOME/.local/bin";
    };

    # Move ~/.Xauthority out of $HOME (X11-specific, NixOS only)
    environment.extraInit = ''
      export XAUTHORITY=/tmp/Xauthority
      [ -e ~/.Xauthority ] && mv -f ~/.Xauthority "$XAUTHORITY"
    '';
  };
}
