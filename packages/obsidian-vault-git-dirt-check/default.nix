{
  coreutils,
  git,
  writeShellApplication,
}:
writeShellApplication {
  name = "obsidian-vault-git-dirt-check";
  runtimeInputs = [
    coreutils
    git
  ];
  text = builtins.readFile ./obsidian-vault-git-dirt-check;
}
