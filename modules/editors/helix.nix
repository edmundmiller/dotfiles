{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.editors.helix;
in
{
  options.modules.editors.helix = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name}.programs.helix = {
      enable = true;
      extraPackages = [ pkgs.marksman ];
      languages = {
        # the language-server option currently requires helix from the master branch at https://github.com/helix-editor/helix/
        language-server.typescript-language-server = with pkgs.nodePackages; {
          command = "${typescript-language-server}/bin/typescript-language-server";
          args = [
            "--stdio"
            "--tsserver-path=${typescript}/lib/node_modules/typescript/lib"
          ];
        };

        language = [
          {
            name = "rust";
            auto-format = false;
          }
        ];
      };
      settings = {
        # theme = "STYLIX";
        editor = {
          line-number = "relative";
          lsp.display-messages = true;
        };
        keys.normal = {
          space.space = "file_picker";
          space.w = ":w";
          space.q = ":q";
          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];
          C-f = [
            ":new"
            ":insert-output lf -selection-path=/dev/stdout"
            "split_selection_on_newline"
            "goto_file"
            "goto_last_modification"
            "goto_last_modified_file"
            ":buffer-close!"
            ":redraw"
          ];
        };
      };
    };
  };
}
