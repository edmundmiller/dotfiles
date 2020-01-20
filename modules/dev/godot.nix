# modules/dev/godot.nix --- https://godotengine.org/

{ pkgs, ... }: {
  my.packages = with pkgs; [ godot ];
}
