{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my; {
  imports =
    # I use home-manager to deploy files to $HOME; little else
    [
      inputs.home-manager.nixosModules.home-manager
    ]
    # All my personal modules
    ++ (mapModulesRec' (toString ./modules) import);

  # Common config for all nixos machines; and to ensure the flake operates
  # soundly
  environment.variables.DOTFILES = findFirst pathExists dotFilesDir [
    "${config.user.home}/.config/dotfiles"
    "/etc/dotfiles"
  ];
  environment.variables.DOTFILES_BIN = "$DOTFILES/bin";

  # Configure nix and nixpkgs
  environment.variables.NIXPKGS_ALLOW_UNFREE = "1";
  nix =
    let
      filteredInputs = filterAttrs (n: _: n != "self") inputs;
      nixPathInputs = mapAttrsToList (n: v: "${n}=${v}") filteredInputs;
      registryInputs = mapAttrs (_: v: { flake = v; }) filteredInputs;
    in
    {
      package = pkgs.nixFlakes;
      extraOptions = "experimental-features = nix-command flakes";
      nixPath = nixPathInputs ++ [
        "nixpkgs-overlays=${dotFilesDir}/overlays"
        "dotfiles=${dotFilesDir}"
      ];
      binaryCaches = [ "https://nix-community.cachix.org" ];
      binaryCachePublicKeys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      registry = registryInputs // { dotfiles.flake = inputs.self; };
      autoOptimiseStore = true;
    };
  system.configurationRevision = with inputs; mkIf (self ? rev) self.rev;
  system.stateVersion = "21.05";

  ## Some reasonable, global defaults
  # This is here to appease 'nix flake check' for generic hosts with no
  # hardware-configuration.nix or fileSystem config.
  fileSystems."/".device = mkDefault "/dev/disk/by-label/nixos";

  # https://community.frame.work/t/using-the-ax210-with-linux-on-the-framework-laptop/1844/64
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader = {
    efi.canTouchEfiVariables = mkDefault true;
    systemd-boot.configurationLimit = 10;
    systemd-boot.enable = mkDefault true;
  };

  # Just the bear necessities...
  environment.systemPackages = with pkgs; [
    bind
    cached-nix-shell
    coreutils
    git
    vim
    wget
    go-task
    gnumake
    unzip
  ];
}
