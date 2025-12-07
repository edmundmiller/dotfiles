let
  # Edmund's SSH key - used on MacTraitor-Pro, Seqeratop, and for encrypting shared secrets
  edmundmiller = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC";
in
{
  "taskchampion-sync.age".publicKeys = [ edmundmiller ];
}
