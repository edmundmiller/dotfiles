let
  edmundmiller = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC edmundmiller";
  nuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBPG2vvh8XkVObXANO9/CBfczftZrmpbjg2w5onK/Tv";
in
{
  "tailscale-auth.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "webui.age".publicKeys = [
    edmundmiller
    nuc
  ];
}
