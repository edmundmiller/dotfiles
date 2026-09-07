{
  coreutils,
  jq,
  restic,
  sqlite,
  writeShellApplication,
}:
writeShellApplication {
  name = "discrawl-backup";
  runtimeInputs = [
    coreutils
    jq
    restic
    sqlite
  ];
  text = builtins.readFile ./discrawl-backup;
}
