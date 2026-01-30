{
  config,
  options,
  pkgs,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.zsh;
  inherit (config.dotfiles) configDir;

  configSubdirs = builtins.sort builtins.lessThan (
    builtins.attrNames (filterAttrs (_: type: type == "directory") (builtins.readDir configDir))
  );

  claudeEnabled = attrByPath [ "modules" "shell" "claude" "enable" ] false config;

  aliasPathFor = dir:
    if dir == "claude" && !claudeEnabled then null
    else "${configDir}/${dir}/aliases.zsh";

  envPathFor = dir:
    if dir == "claude" && !claudeEnabled then null
    else "${configDir}/${dir}/env.zsh";

  autoRcFiles = builtins.filter (
    path: path != null && builtins.pathExists path
  ) (map aliasPathFor configSubdirs);

  autoEnvFiles = builtins.filter (
    path: path != null && builtins.pathExists path
  ) (map envPathFor configSubdirs);
in
{
  options.modules.shell.zsh = with types; {
    enable = mkBoolOpt false;

    rcInit = mkOpt' lines "" ''
      Zsh lines to be written to $XDG_CONFIG_HOME/zsh/extra.zshrc and sourced by
      $XDG_CONFIG_HOME/zsh/.zshrc
    '';
    envInit = mkOpt' lines "" ''
      Zsh lines to be written to $XDG_CONFIG_HOME/zsh/extra.zshenv and sourced
      by $XDG_CONFIG_HOME/zsh/.zshenv
    '';

    rcFiles = mkOpt (listOf (either str path)) (
      [ "${configDir}/zsh/prompt.zsh" ] ++ autoRcFiles
    );
    envFiles = mkOpt (listOf (either str path)) autoEnvFiles;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Add zsh to available shells
      environment.shells = [ pkgs.zsh ];

      # Enable zsh at system level - this creates /etc/zshrc that loads nix-darwin environment
      programs.zsh = {
        enable = true;
        # I init completion myself, because enableGlobalCompInit initializes it
        # too soon, which means commands initialized later in my config won't get
        # completion, and running compinit twice is slow.
        enableCompletion = true;
        enableGlobalCompInit = false;
        # I configure the prompt myself, so disable the default.
        promptInit = "";
        
      };

      modules.shell.zsh = {
        rcFiles = mkBefore ([ "${configDir}/zsh/prompt.zsh" ] ++ autoRcFiles);
        envFiles = mkBefore autoEnvFiles;
      };

      user.packages = with pkgs; [
        zsh
        antidote
        unstable.atuin
        bat
        btop
        eza
        fd
        unstable.fzf
        gh
        git-lfs
        glow
        (ripgrep.override { withPCRE2 = true; })
        lazygit
        neovim
        procs
        difftastic
        hyperfine
        just
        sd
        unstable.yazi
        zoxide
        my.hey  # Nix-managed hey command with completions
      ];

      env = {
        ZDOTDIR = "$XDG_CONFIG_HOME/zsh";
        ZSH_CACHE = "$XDG_CACHE_HOME/zsh";
        PATH = [ "$DOTFILES_BIN" ];
      };

      environment.shellAliases = {
        # zoxide is initialized via zshrc init, no need for alias
        # cd = "z";  (zoxide init zsh handles this)
        # cdi = "zi";

        # file operations
        chmod = "chmod -v";
        cp = "cp -iv";
        ln = "ln -v";
        mkdir = "mkdir -vp";
        mv = "mv -iv";
        rm = "rm -v";
        rmdir = "rmdir -v";

        # shell
        rst = "exec $SHELL";
        sudo = "sudo ";
        su = "sudo su";

        # nix
        scrap = "nix-collect-garbage -d && sudo nix-collect-garbage -d";
        rebuild = "sudo nixos-rebuild switch";
        reflake = "sudo nixos-rebuild switch --recreate-lock-file";
        nix-clean = "nix-collect-garbage -d";

        # ls (eza)
        ls = "eza --group-directories-first --git";
        la = "ll -a";
        ll = "ls -l";
        l = "ls -1A";

        # ripgrep
        rg = "rg --color=auto";
        rga = "rg -uuu";
        rgf = "rg --files";

        # misc
        q = "exit";
        c = "clear";
        cat = "bat --style=plain";
        e = "$EDITOR";
        http = "xh";
        dsize = "du -hs";
        # rcp: rsync that respects gitignore
        # -a = archive mode (-rlptgoD: recursive, symlinks, permissions, times, group, owner)
        # -z = compression
        # -P = --partial --progress (show progress, keep partial files)
        # -J = omit symlink mtimes (prevents errors)
        # --include=.git/ = include git directories
        # --filter = respect .gitignore files
        rcp = "rsync -azPJ --include=.git/ --filter=':- .gitignore' --filter=':- $XDG_CONFIG_HOME/git/ignore'";
        weather = "curl -s 'wttr.in/Ft+Worth?m&format=3'";

        # docker-compose
        dcup = "docker-compose up -d";
        dcdw = "docker-compose down";
        dcre = "docker-compose restart";
        dclo = "docker-compose logs -f";
      };

      home.configFile = {
        # Link zsh directory recursively, so other modules (or the user) can
        # write files there later.
        "zsh" = {
          source = "${configDir}/zsh";
          recursive = true;
        };
        
        # Create extra.zshrc with rcInit content
        "zsh/extra.zshrc".text = ''
          # This file was autogenerated, do not edit it!
          ${concatMapStrings (path: ''
            source '${path}'
          '') (lib.unique cfg.rcFiles)}
          ${cfg.rcInit}
        '';
        
        # Create extra.zshenv with envInit content
        "zsh/extra.zshenv".text = ''
          # This file is autogenerated, do not edit it!
          ${concatMapStrings (path: ''
            source '${path}'
          '') (lib.unique cfg.envFiles)}
          ${cfg.envInit}
        '';


      };
    }
  ]);
}
