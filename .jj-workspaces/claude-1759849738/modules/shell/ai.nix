{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.ai;
in
{
  options.modules.shell.ai = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      # (unstable.llm.withPlugins [
      #   # inputs.llm-prompt.packages.${system}.llm-prompt
      #   # my.llm-claude-3
      # ])
      unstable.chatblade
      unstable.aichat
    ];
  };
}
