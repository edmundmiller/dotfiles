{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ clojure joker leiningen ];

  home-manager.users.emiller.xdg.configFile = {
    "zsh/rc.d/aliases.clojure.zsh".source = <config/clojure/aliases.zsh>;
    "zsh/rc.d/env.clojure.zsh".source = <config/clojure/env.zsh>;
  };
}
