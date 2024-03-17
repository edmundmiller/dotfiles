let
  edmundmiller = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC edmundmiller";
  unas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC edmundmiller";
in {
  "restic/rclone.age".publicKeys = [edmundmiller unas];
  "restic/repo.age".publicKeys = [edmundmiller unas];
  "restic/password.age".publicKeys = [edmundmiller unas];
}
