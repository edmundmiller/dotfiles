{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    rustc
    cargo
    rustfmt
    rls
    # rustPlatform.rustcSrc
    # rustracer
  ];

  home-manager.users.emiller.xdg.configFile = {
    "zsh/rc.d/aliases.rust.zsh".source = <config/rust/aliases.zsh>;
    "zsh/rc.d/env.rust.zsh".source = <config/rust/env.zsh>;
  };
}
