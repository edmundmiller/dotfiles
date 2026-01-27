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
  # TaskChampion sync - per-host client_id for multi-device sync
  # Each host needs unique client_id but shared encryption_secret
  "taskchampion-sync-mactraitor.age".publicKeys = [ mactraitor ];
  "taskchampion-sync-seqeratop.age".publicKeys = [ seqeratop ];
  "taskchampion-sync-nuc.age".publicKeys = [ nuc ];

  # Legacy shared secret (deprecated - will remove after migration)
  "taskchampion-sync.age".publicKeys = [ mactraitor seqeratop nuc ];

  "wakatime-api-key.age".publicKeys = [ mactraitor seqeratop ];

  "clawdbot-bridge-token.age".publicKeys = [ mactraitor nuc ];

  "anthropic-api-key.age".publicKeys = [ mactraitor seqeratop nuc ];
}
