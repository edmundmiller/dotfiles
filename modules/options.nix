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

    dotfiles = {
      # Use static path to avoid self-referential infinite recursion
      dir = mkOpt path (toString ../.);
      binDir = mkOpt path "${toString ../.}/bin";
      configDir = mkOpt path "${toString ../.}/config";
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
        name =
          if
            elem user [
              ""
              "root"
            ]
          then
            "emiller"
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
        extraGroups = [ "wheel" ];
        isNormalUser = true;
        home = "${homeBase}/${name}";
        group = "users";
        uid = 1000;
      };

    # Install user packages to /etc/profiles instead. Necessary for
    # nixos-rebuild build-vm to work.
    home-manager = {
      useUserPackages = true;

      # I only need a subset of home-manager's capabilities. That is, access to
      # its home.file, home.xdg.configFile and home.xdg.dataFile so I can deploy
      # files easily to my $HOME, but 'home-manager.users.emiller.home.file.*'
      # is much too long and harder to maintain, so I've made aliases in:
      #
      #   home.file        ->  home-manager.users.emiller.home.file
      #   home.configFile  ->  home-manager.users.emiller.home.xdg.configFile
      #   home.dataFile    ->  home-manager.users.emiller.home.xdg.dataFile
      users.${config.user.name} = {
        home = {
          file = mkAliasDefinitions options.home.file;
          # Necessary for home-manager to work with flakes, otherwise it will
          # look for a nixpkgs channel.
          inherit (config.system) stateVersion;
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
