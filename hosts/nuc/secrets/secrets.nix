let
  edmundmiller = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC edmundmiller";
  nuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBPG2vvh8XkVObXANO9/CBfczftZrmpbjg2w5onK/Tv";
in
{
  "restic/repo.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "restic/password.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "emiller_password.age".publicKeys = [ nuc ];
  "goose-auth-token.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "anthropic-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "opencode-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "openai-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
}
