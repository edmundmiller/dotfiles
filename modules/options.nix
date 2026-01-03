{
  config,
  options,
  lib,
  pkgs,
  home-manager,
  isDarwin,
  ...
}:
with lib;
with lib.my;
{
  options = with types; {
    user = mkOpt attrs { };
    # Add user.packages option for aliasing to home-manager
    "user.packages" = mkOpt (listOf package) [];

    dotfiles = {
      # Use static path to avoid self-referential infinite recursion
      dir = mkOpt path (toString ../.);
      binDir = mkOpt path "${toString ../.}/bin";
      configDir = mkOpt path "${toString ../.}/config";
      configFile = mkOpt path "${toString ../.}/config";
      modulesDir = mkOpt path "${toString ../.}/modules";
      themesDir = mkOpt path "${toString ../.}/modules/themes";
    };

    home = {
      file = mkOpt' attrs { } "Files to place directly in $HOME";
      configFile = mkOpt' attrs { } "Files to place in $XDG_CONFIG_HOME";
      dataFile = mkOpt' attrs { } "Files to place in $XDG_DATA_HOME";
    };

    env = mkOption {
      type = attrsOf (oneOf [
        str
        path
        (listOf (either str path))
      ]);
      apply = mapAttrs (_n: v: if isList v then concatMapStringsSep ":" toString v else (toString v));
      default = { };
      description = "TODO";
    };
  };

  config = {
    user =
      let
        user = builtins.getEnv "USER";
        # Use system.primaryUser as fallback when $USER is root/empty (e.g., during sudo darwin-rebuild)
        # This ensures the correct username is used on hosts with different usernames (e.g., edmundmiller on Seqeratop)
        name =
          if
            elem user [
              ""
              "root"
            ]
          then
            "emiller"  # Static fallback - hosts override via system.primaryUser
          else
            user;
        description =
          if
            elem user [
              ""
              "root"
            ]
          then
            "Edmund Miller"
          else
            "The primary user account";
        # Determine home directory based on platform
        homeBase = if isDarwin
                   then "/Users"
                   else "/home";
      in
      {
        inherit name description;
        home = "${homeBase}/${name}";
        uid = 1000;
      }
      # NixOS-specific user options
      // optionalAttrs (!isDarwin) {
        extraGroups = [ "wheel" ];
        isNormalUser = true;
        group = "users";
      };

    # Install user packages to /etc/profiles instead. Necessary for
    # nixos-rebuild build-vm to work.
    home-manager = {
      useUserPackages = true;

      # I only need a subset of home-manager's capabilities. That is, access to
      # its home.file, home.xdg.configFile and home.xdg.dataFile so I can deploy
      # files easily to my $HOME, but 'home-manager.users.<user>.home.file.*'
      # is much too long and harder to maintain, so I've made aliases in:
      #
      #   home.file        ->  home-manager.users.<user>.home.file
      #   home.configFile  ->  home-manager.users.<user>.home.xdg.configFile
      #   home.dataFile    ->  home-manager.users.<user>.home.xdg.dataFile
      #   user.packages    ->  home-manager.users.<user>.home.packages
      users.${config.user.name} = {
        home = {
          file = mkAliasDefinitions options.home.file;
          packages = mkAliasDefinitions options."user.packages";
          # Necessary for home-manager to work with flakes, otherwise it will
          # look for a nixpkgs channel.
          # On Darwin, system.stateVersion is a number; home-manager needs a string
          stateVersion = if isDarwin then "24.11" else config.system.stateVersion;
        };
        xdg = {
          configFile = mkAliasDefinitions options.home.configFile;
          dataFile = mkAliasDefinitions options.home.dataFile;
        };
      };

      backupFileExtension = "bkup";
    };

    users.users.${config.user.name} = mkAliasDefinitions options.user;

    nix =
      let
        users = [
          "root"
          config.user.name
        ];
      in
      {
        settings.trusted-users = users;
        settings.allowed-users = users;
      };

    # must already begin with pre-existing PATH. Also, can't use binDir here,
    # because it contains a nix store path.
    env.PATH = [
      "$DOTFILES_BIN"
      "$XDG_BIN_HOME"
      "$PATH"
    ];

    environment.extraInit = concatStringsSep "\n" (
      mapAttrsToList (n: v: ''export ${n}="${v}"'') config.env
    );
  };
}
