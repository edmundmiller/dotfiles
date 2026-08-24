{
  coreutils,
  jq,
  restic,
  sqlite,
  writeShellApplication,
}:
writeShellApplication {
  name = "screentime-backup";
  runtimeInputs = [
    coreutils
    jq
    restic
    sqlite
  ];
  text = builtins.readFile ./screentime-backup;
}
