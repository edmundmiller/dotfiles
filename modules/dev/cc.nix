# modules/dev/cc.nix --- C & C++

{ pkgs, ... }: {
  imports = [ ./. ];

  my.packages = with pkgs; [ clang gcc bear gdb cmake llvmPackages.libcxx ];
}
