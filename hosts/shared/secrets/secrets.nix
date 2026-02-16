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
