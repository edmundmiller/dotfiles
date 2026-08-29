{
  hermesTokenizers,
  pkgs,
}:
let
  patchedTool = "${hermesTokenizers.cargoDeps}/source-registry-0/cc-1.2.48/src/tool.rs";
in
pkgs.runCommand "hermes-local-tokenizers-cc-regression" { } ''
  grep -F '.wait_with_output()?' '${patchedTool}'
  grep -F 'process::{Command, Output, Stdio}' '${patchedTool}'
  if grep -F 'child.stdout.take().unwrap().read_to_end' '${patchedTool}'; then
    exit 1
  fi

  mkdir -p "$out"
  printf '%s\n' "Hermes Tokenizers uses the nonblocking cc-rs compiler probe." > "$out/result"
''
