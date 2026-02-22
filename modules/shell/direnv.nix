{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.direnv;
in
{
  options.modules.shell.direnv = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    modules.shell.zsh.rcInit = "_cache direnv hook zsh";

    # Use home-manager's native direnv + nix-direnv for cached flake evaluation
    home-manager.users.${config.user.name}.programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      stdlib = ''
        use_docker-machine(){
          local env=''${1:-default}
          echo Docker machine: $env
          eval $(docker-machine env --shell bash $env)
        }

        use_guix() {
          local cache_dir="$(direnv_layout_dir)/.guix-profile"
          if [[ -e "$cache_dir/etc/profile" ]]; then
            source "$cache_dir/etc/profile"
          else
            mkdir "$(direnv_layout_dir)"
            eval "$(guix environment --root="$cache_dir" "$@" --search-paths)"
          fi
        }
      '';
    };
  };
}
