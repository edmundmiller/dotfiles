# modules/dev/java.nix ---

{ pkgs, ... }: {
  my.packages = with pkgs; [ openjdk11 gradle ];
}
