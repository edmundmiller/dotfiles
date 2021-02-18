{ config, options, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.editors.code;
  extensions = (with pkgs.vscode-extensions; [
    bbenoist.Nix
    vscodevim.vim
    ms-python.python
    ms-azuretools.vscode-docker
    ms-vsliveshare.vsliveshare
    ms-vscode-remote.remote-ssh
    ms-kubernetes-tools.vscode-kubernetes-tools
  ]);
  # ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [{
  # }];
  vscode-with-extensions =
    pkgs.vscode-with-extensions.override { vscodeExtensions = extensions; };
in {
  options.modules.editors.code = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    user.packages = with pkgs; [ editorconfig-core-c vscode-with-extensions ];

  };
}
