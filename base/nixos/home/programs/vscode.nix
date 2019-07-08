{ pkgs, lib, ... }:

{
  programs.vscode = {
    enable = true;
    haskell.hie.enable = true;
    userSettings = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
      "editor.formatOnSave" = true;
      "[shellscript]" = {
        "editor.defaultFormatter" = "foxundermoon.shell-format";
      };
      "[scala]" = {
        "editor.defaultFormatter" = "scalameta.metals";
      };
      "[terraform]" = {
        "editor.defaultFormatter" = "mauve.terraform";
      };
      "vim.useSystemClipboard" = true;
      "gitlens.advanced.messages"."suppressShowKeyBindingsNotice" = true  ;
      "window.zoomLevel" = 0;
      "files.associations"."*.mdx"  = "markdown";
      "typescript.updateImportsOnFileMove.enabled" = "never";
      "gitlens.views.fileHistory.enabled" = true;
      "gitlens.views.lineHistory.enabled" = true;
      "workbench.colorTheme" = "Default Light+";
      "metals.javaHome" = pkgs.openjdk8;
    };
    extensions = with pkgs.vscode-extensions; [
      bbenoist.Nix
    ]
    ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      # Get these hashes by putting in the wrong hash.
      # `home-manager switch` will tell you what the correct hash is.
      {
        name = "vscode-docker";
        publisher = "ms-azuretools";
        version = "0.6.4";
        sha256 = "1683hc200ld3b6dhb2lf87lsrqd2gynjx7iz7z24dm21qd7fqy13";
      }
      {
        name = "vsliveshare";
        publisher = "MS-vsliveshare";
        version = "1.0.488";
        sha256 = "16p1f8qlm4p9q3ngbysa5smq1sf3cwv575rjl31290gkrmpd0rzp";
      }
      {
        name = "gitlens";
        publisher = "eamodio";
        version = "9.1.0";
        sha256 = "0a6iqnqmig0s4d107vzwygybndd9hq99kk6mykc88c8qgwf0zdrr";
      }
      {
        name = "vim";
        publisher = "vscodevim";
        version = "0.16.14";
        sha256 = "0b8d3sj3754l3bwcb5cdn2z4z0nv6vj2vvaiyhrjhrc978zw7mby";
      }
      {
        name = "vsc-material-theme";
        publisher = "equinusocio";
        version = "2.9.0";
        sha256 = "1blz6fh60bqny4fskln1a3n0xggfn9w9vdrabh5h73ighqi2w51z";
      }
      {
        name = "prettier-vscode";
        publisher = "esbenp";
        version = "1.8.1";
        sha256 = "0qcm2784n9qc4p77my1kwqrswpji7bp895ay17yzs5g84cj010ln";
      }
      {
        name = "vscode-typescript-tslint-plugin";
        publisher = "ms-vscode";
        version = "0.4.1";
        sha256 = "0fsf9ycc7b09adifipylx1gfg51nmzlqb8n2v3l3g52lx9lxk3is";
      }
      {
        name = "graphql-for-vscode";
        publisher = "kumar-harsh";
        version = "1.3.0";
        sha256 = "0ff0f6g0gq4ckvs9qpkcskz1af9v82xxakzs4rljw85vw8yfpq73";
      }
      {
        name = "vscode-styled-components";
        publisher = "jpoissonnier";
        version = "0.0.25";
        sha256 = "12qgx56g79snkf9r7sgmx3lv0gnzp7avf3a5910i0xq9shfr67n0";
      }
      {
        name = "metals";
        publisher = "scalameta";
        version = "1.3.1";
        sha256 = "1sfpsp8m24k9mmaq1dscpy25mn9f7a9qgsr7sz8flv9b0blb0jcy";
      }
      {
        name = "scala";
        publisher = "scala-lang";
        version = "0.2.0";
        sha256 = "0z2knfgn1g5rvanssnz6ym8zqyzzk5naaqsggrv77k6jzd5lpw49";
      }
      {
        name = "go";
        publisher = "ms-vscode";
        version = "0.10.1";
        sha256 = "1gqpqivfg046s9sydjndm8pnfc4q4m9412dl56fc0f2rb7xfgsbn";
      }
      {
        name = "terraform";
        publisher = "mauve";
        version = "1.3.11";
        sha256 = "0di7psqcn7gmdl604cxra2xnc8rc6izandqz44qrgjl3j41vp8jr";
      }
      {
        name = "vscode-apollo";
        publisher = "apollographql";
        version = "1.7.1";
        sha256 = "18r5d0f7hkz2s1hm7lanfymrvjarpb1sfplhi93dc5qz93q10l6a";
      }
      {
        name = "language-haskell";
        publisher = "justusadam";
        version = "2.6.0";
        sha256 = "1891pg4x5qkh151pylvn93c4plqw6vgasa4g40jbma5xzq8pygr4";
      }
      {
        name = "vscode-hie-server";
        publisher = "alanz";
        version = "0.0.27";
        sha256 = "1mz0h5zd295i73hbji9ivla8hx02i4yhqcv6l4r23w3f07ql3i8h";
      }
      {
        name = "shell-format";
        publisher = "foxundermoon";
        version = "6.0.1";
        sha256 = "1zkvrlhmw8id65km9cfpgv8p3w1ym4g4mr7cmb32fn3yk937gpmy";
      }
      {
        name = "vscode-github";
        publisher = "knisterpeter";
        version = "0.30.2";
        sha256 = "0axq6a8lgf17kwmsw3fj5g4n0wgwr7x6qfxshaqbl6ac6p1pnd9v";
      }
      {
        name = "vscode-pull-request-github";
        publisher = "github";
        version = "0.8.0";
        sha256 = "0gk9jb8i894jx7a0wjx3w220kh55gyczrfi01b3dcdnwi8gvh80n";
      }
    ];
  };
}
