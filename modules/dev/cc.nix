{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ cmake bear gdb ccls ];

  home-manager.users.emiller.xdg.configFile = {
    # "zsh/rc.d/aliases.cc.zsh".source = <config/cc/aliases.zsh>;
    # "zsh/rc.d/env.cc.zsh".source = <config/cc/env.zsh>;
  };
}
