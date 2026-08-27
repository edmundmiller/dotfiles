{ pkgs }:
let
  resolverPath = ../../../lib/nuc-deployment-provenance.nix;
  resolverExists = builtins.pathExists resolverPath;

  # Flip this only after the regression has been observed and the resolver is
  # implemented. Nix checks do not provide a strict xfail primitive.
  expectedFailure = true;

  assertions = [
    {
      test = if expectedFailure then !resolverExists else resolverExists;
      msg = "NUC deployment provenance must have a pure resolver.";
    }
  ]
  ++ pkgs.lib.optionals (resolverExists && !expectedFailure) (
    let
      provenance = import resolverPath {
        inherit (pkgs) lib;
        self = { };
        agentsWorkspace = {
          rev = "2222222222222222222222222222222222222222";
        };
        markerPath = ./fixtures/deployment-revision;
      };
      decoded = builtins.fromJSON provenance.json;
    in
    [
      {
        test = provenance.dotfilesRevision == "1111111111111111111111111111111111111111";
        msg = "The synced-worktree marker must recover the dotfiles revision when flake self.rev is absent.";
      }
      {
        test = provenance.agentsWorkspaceRevision == "2222222222222222222222222222222222222222";
        msg = "The locked agents-workspace revision must be preserved.";
      }
      {
        test =
          decoded == {
            schemaVersion = 1;
            dotfilesRevision = "1111111111111111111111111111111111111111";
            agentsWorkspaceRevision = "2222222222222222222222222222222222222222";
          };
        msg = "The deployed provenance fact must be exact, complete, and machine-readable.";
      }
    ]
  );

  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-deployment-provenance" { } ''
  if [ ${builtins.toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC deployment provenance assertions failed:
  ${pkgs.lib.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
