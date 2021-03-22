{ config, options, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.editors.code;
  extensions = (with pkgs.vscode-extensions; [
    bbenoist.Nix
    eamodio.gitlens
    vscodevim.vim
    ms-python.python
    ms-azuretools.vscode-docker
    ms-vsliveshare.vsliveshare
    ms-vscode-remote.remote-ssh
    ms-kubernetes-tools.vscode-kubernetes-tools
    redhat.vscode-yaml
  ]) ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "nextflow";
      publisher = "nextflow";
      version = "0.3.0";
      sha256 = "sha256-XLyGG8KoXaMhtbbY3V1r63B/4WFOV2horp184hV74dI=";
    }
    {
      name = "vscode-groovy-lint";
      publisher = "NicolasVuillamy";
      version = "1.4.0";
      sha256 = "sha256-Uz6U18Kr+tyarOv9b/GzD9g9LXRYyZ+jxagMVkHstZM=";
    }
  ];
  vscode-with-extensions =
    pkgs.vscode-with-extensions.override { vscodeExtensions = extensions; };
in {
  options.modules.editors.code = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    user.packages = with pkgs; [ editorconfig-core-c vscode-with-extensions ];

  };
}
