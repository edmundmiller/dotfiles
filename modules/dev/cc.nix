# modules/dev/cc.nix --- C & C++

{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.dev.cc = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.dev.cc.enable {
    my.packages = with pkgs; [ clang gcc bear gdb cmake llvmPackages.libcxx ];
  };
}
