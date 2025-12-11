let
  # Edmund's SSH keys - used for encrypting shared secrets
  # MacTraitor-Pro
  mactraitor = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC";
  # Seqeratop
  seqeratop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLH5ywipRADaxVcZ/kK2Pg9kwRZyj/ABEurj+5KXHty";
in
{
  "taskchampion-sync.age".publicKeys = [ mactraitor seqeratop ];
}
