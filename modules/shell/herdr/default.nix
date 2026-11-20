{ lib, ... }:
{
  options.modules.shell.herdr = {
    enable = lib.my.mkBoolOpt false;
    tnote.enable = lib.my.mkBoolOpt true;
  };
}
