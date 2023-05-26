{...}: {
  ## System security tweaks
  boot.tmp.useTmpfs = true;
  security.protectKernelImage = true;

  # Fix a security hole in place for backwards compatibility. See desc in
  # nixpkgs/nixos/modules/system/boot/loader/systemd-boot/systemd-boot.nix
  boot.loader.systemd-boot.editor = false;

  # Change me later!
  user.initialPassword = "nix";
  users.users.root.initialPassword = "nix";
}
