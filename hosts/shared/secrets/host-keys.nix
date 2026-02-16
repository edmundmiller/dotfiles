# Mapping of hostnames to SSH public keys.
# Used by modules/agenix.nix to filter shared secrets per-host
# and by secrets.nix for encryption targets.
{
  "MacTraitor-Pro" =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC";
  "Seqeratop" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLH5ywipRADaxVcZ/kK2Pg9kwRZyj/ABEurj+5KXHty";
  "nuc" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBPG2vvh8XkVObXANO9/CBfczftZrmpbjg2w5onK/Tv";
}
