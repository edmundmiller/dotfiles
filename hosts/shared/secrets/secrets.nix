let
  # Edmund's SSH keys - used for encrypting shared secrets
  # MacTraitor-Pro
  mactraitor = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC";
  # Seqeratop
  seqeratop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLH5ywipRADaxVcZ/kK2Pg9kwRZyj/ABEurj+5KXHty";
  # NUC
  nuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBPG2vvh8XkVObXANO9/CBfczftZrmpbjg2w5onK/Tv";
in
{
  "wakatime-api-key.age".publicKeys = [
    mactraitor
    seqeratop
  ];

  "clawdbot-bridge-token.age".publicKeys = [
    mactraitor
    nuc
  ];

  "openclaw-gateway-token.age".publicKeys = [
    mactraitor
    nuc
  ];

  "anthropic-api-key.age".publicKeys = [
    mactraitor
    seqeratop
    nuc
  ];
}
