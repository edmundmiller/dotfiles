# darwin-base.nix
# Shared configuration for all nix-darwin systems
{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
{
  config = mkIf isDarwin {
    # Nix configuration
    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [
          "https://nix-community.cachix.org"
          "https://hyprland.cachix.org"
          "https://cosmic.cachix.org/"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
        ];
        # Increase download buffer size for large derivations (e.g., texlive)
        download-buffer-size = 134217728; # 128MB (default is 64MB)
      };
      optimise.automatic = true;
    };

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
