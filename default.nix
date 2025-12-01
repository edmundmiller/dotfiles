{
  inputs,
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
{
  imports =
    # I use home-manager to deploy files to $HOME; little else
    # Note: For darwin, home-manager is imported in flake.nix as darwinModules
    (lib.optional (!isDarwin)
      inputs.home-manager.nixosModules.home-manager)
    # All my personal modules (filtered for platform compatibility)
    ++ (let
      modulesPath = toString ./modules;
      allModulePaths = mapModulesRec' modulesPath id;
      # Filter out NixOS-only directories on Darwin
      nixosOnlyDirs = [ "hardware" "desktop" ];
      nixosOnlyFiles = [
        "security.nix"
        "nixos-base.nix"
        "fonts-nixos.nix"
        "browsers-nixos.nix"
        # NixOS-only hardware/shell modules
        "nushell.nix"
        "yubikey.nix"
        # NixOS-only services
        "audiobookshelf.nix"
        "calibre.nix"
        "gitea.nix"
        "hass.nix"
        "homepage.nix"
        "jellyfin.nix"
        "keybase.nix"
        "mpd.nix"
        "nginx.nix"
        "ollama.nix"
        "paperless.nix"
        "prowlarr.nix"
        "qb.nix"
        "radarr.nix"
        "sonarr.nix"
        "syncthing.nix"
        "transmission.nix"
      ];
      isNixOSOnly = path:
        let pathStr = toString path; in
        lib.any (dir:
          lib.hasInfix "/modules/${dir}/" pathStr ||  # Files inside directory
          lib.hasSuffix "/modules/${dir}" pathStr     # Directory itself
        ) nixosOnlyDirs
        || lib.any (file: lib.hasSuffix file pathStr) nixosOnlyFiles;
    in
    map import (if isDarwin then filter (p: !isNixOSOnly p) allModulePaths else allModulePaths));

  # Propagate isDarwin to all sub-modules so they can guard platform-specific options
  _module.args.isDarwin = isDarwin;

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
      package = pkgs.nixVersions.stable;
      extraOptions = "experimental-features = nix-command flakes";
      nixPath = nixPathInputs ++ [
        "nixpkgs-overlays=${dotFilesDir}/overlays"
        "dotfiles=${dotFilesDir}"
      ];
      settings.substituters = [
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
        "https://cosmic.cachix.org/"
      ];
      settings.trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      ];
      registry = registryInputs // {
        dotfiles.flake = inputs.self;
      };
    };
  system.configurationRevision = with inputs; mkIf (self ? rev) self.rev;

  # Just the bear necessities...
  environment.systemPackages = with pkgs; [
    bind
    cached-nix-shell
    coreutils
    git
    vim
    visidata
    wget
    go-task
    gnumake
    just
    unzip
  ];
}
