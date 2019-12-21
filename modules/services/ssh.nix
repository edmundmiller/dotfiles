{ config, pkgs, ... }:

{
  services.openssh = {
    enable = true;
    forwardX11 = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
  };

  users.users.emiller.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPRJA9hhJHA7gyTld8fEsTVKUAD75FASE3e+QeGIJfmHAL7OhC9wbY6Bcy+G77tRVScb6ZQEYIoUtBH6spBAJeiswU45cF22Az9Sjf0sItj55QVc9+gHFuAwVzr1lpYZFBGgd8yyRvWurtsFHoJrKAcfHIad+QsBp1K6uCwrQhkNmYgamazQFXtA84awcaJaluD/vcRl2E5OkdrT53hvAlFwUim8G0Dar+cGDOxfil9D3p8buMRzK6UYr1s6X3llib0Ax1LMKZ1MPJIGhKeqvSvnOQrlU2rtpmNxRGedq4itBL/cXlkXFCwBjuhO7B12zR2QhZAMt7FvQKNLDL7XiRLRNqQ6CbhdiXWZL0TtAmepUW6BwW6faR0zXl+88wyXCHZjbGsoZSHKI+ZETq4P8U9g8bvvBgL7n3fFpTWm2I4LuszLoq4QdGsrTWqjCIH7mtNI0V0ekTMSK9eIrWoWM8W+QvCyPK6NpbWSNGgzGQgRtEvUUqGuk+nUWSThtqStOxHdJez7dhpgVGaRwCYHghKkLuqLzNe+Vor0YK9a2Motbds4M0L3NMo1YTYdGVZ4hq/oZddA/p6vvNJW90HVO8xcGZ2zmPq9Zbmsg4IoNDAICK6SLh3quHa6izwumW2owZvmuDUbMiHbSMJaiWPFbNnJ6kayiyiGTokYraQGn0ZQ== edmund.a.miller@gmail.com"
  ];
}
