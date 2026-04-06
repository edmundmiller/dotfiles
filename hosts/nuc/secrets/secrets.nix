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
  "gemini-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "kilocode-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "fireworks-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "linear-api-token.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "linear-refresh-token.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "linear-webhook-secret.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "elevenlabs-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "telegram-bot-token.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "telegram-bot-token-scintillate.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "discord-bot-token-anne.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "anne-linear-mcp-token.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "scintillate-linear-mcp-token.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "anne-firecrawl-api.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "scintillate-firecrawl-api.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "scintillate-google-client-secret.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "scintillate-google-token.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "homepage-env.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "lubelogger-env.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "speedtest-tracker-env.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "hass-secrets.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "ha-hermes-token.age".publicKeys = [
    edmundmiller
    nuc
  ];
  # Bugster env file (GITHUB_TOKEN, LINEAR_TOKEN, etc.)
  "bugster-env.age".publicKeys = [
    edmundmiller
    nuc
  ];
  # Healthchecks.io keys (for automation)
  "healthchecks-ping-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "healthchecks-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "healthchecks-api-key-readonly.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "openrouter-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "perplexity-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];
  "agentmail-api-key.age".publicKeys = [
    edmundmiller
    nuc
  ];

  # TODO: create these .age files to re-enable vault-sync
  # "cubox-api-key.age".publicKeys = [
  #   edmundmiller
  #   nuc
  # ];
  # "snipd-api-key.age".publicKeys = [
  #   edmundmiller
  #   nuc
  # ];
}
