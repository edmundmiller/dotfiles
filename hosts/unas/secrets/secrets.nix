let
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC edmundmiller";
in {
  "restic/rclone.age".publicKeys = [key];
  "restic/repo.age".publicKeys = [key];
  "restic/password.age".publicKeys = [key];
}
