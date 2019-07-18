{ config, lib, pkgs, ... }:

let
  name = "Edmund Miller";
  protonmail = "edmund.a.miller@protonmail.com";
in {
  home-manager.users.emiller.programs = {
    git = {
      enable = true;
      lfs.enable = true;
      userName = "${name}";
      userEmail = "${protonmail}";
      signing.key = "BC10AA9D";
      signing.signByDefault = true;
      aliases = {
        amend = "commit --amend";
        exec = "!exec ";
        lg =
        "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --";
        ls = "ls-files";
        orphan = "checkout --orphan";
        unadd = "reset HEAD";
        undo-commit = ''
          reset --soft "HEAD^"
                    mr = !sh -c 'git fetch $1 merge-requests/$2/head:mr-$1-$2 && git checkout mr-$1-$2' -'';
        # data analysis
        ranked-authors = "!git authors | sort | uniq -c | sort -n";
        emails = ''!git log --format="%aE" | sort -u'';
        email-domains =
        ''!git log --format="%aE" | awk -F'@' '{print $2}' | sort -u'';
      };
      extraConfig = ''
        [github]
          user = emiller88
        [color]
          ui = auto
        [rebase]
          autosquash = true
        [push]
          default = current
        [merge]
          ff = onlt
          log = true
      '';
    };
  };
}
