let
  hostKeys = import ./host-keys.nix;
  mactraitor = hostKeys."MacTraitor-Pro";
  seqeratop = hostKeys."Seqeratop";
  inherit (hostKeys) nuc;
in
{
  "wakatime-api-key.age".publicKeys = [
    mactraitor
    seqeratop
    nuc
  ];

  "anthropic-api-key.age".publicKeys = [
    mactraitor
    nuc
  ];
}
