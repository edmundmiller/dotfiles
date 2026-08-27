{
  nixosConfig ? null,
  expectedAgentsWorkspaceRevision ? null,
  pkgs,
}:
let
  resolverPath = ../_lib/deployment-provenance.nix;
  resolverExists = builtins.pathExists resolverPath;

  missingSourceResult =
    builtins.tryEval
      (import resolverPath {
        inherit (pkgs) lib;
        self = { };
        agentsWorkspace.rev = "2222222222222222222222222222222222222222";
        markerPath = ./fixtures + "/missing-deployment-revision";
      }).configurationRevision;
  missingAgentsWorkspaceResult =
    builtins.tryEval
      (import resolverPath {
        inherit (pkgs) lib;
        self.rev = "1111111111111111111111111111111111111111";
        agentsWorkspace = { };
        markerPath = ./fixtures/deployment-revision;
      }).configurationRevision;

  assertions = [
    {
      test = resolverExists;
      msg = "NUC deployment provenance must have a pure resolver.";
    }
    {
      test = !missingSourceResult.success;
      msg = "NUC evaluation must fail closed when neither flake self.rev nor the synced-worktree marker is present.";
    }
    {
      test = !missingAgentsWorkspaceResult.success;
      msg = "NUC evaluation must fail closed when the locked agents-workspace revision is absent.";
    }
  ]
  ++ pkgs.lib.optionals resolverExists (
    let
      provenance = import resolverPath {
        inherit (pkgs) lib;
        self = { };
        agentsWorkspace = {
          rev = "2222222222222222222222222222222222222222";
        };
        markerPath = ./fixtures/deployment-revision;
      };
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
          provenance.configurationRevision
          == "dotfiles=1111111111111111111111111111111111111111;agents-workspace=2222222222222222222222222222222222222222";
        msg = "The deployed configuration revision must contain both exact labeled revisions.";
      }
    ]
  )
  ++ pkgs.lib.optionals (nixosConfig != null) (
    let
      actualRevision = nixosConfig.config.system.configurationRevision;
    in
    [
      {
        test =
          builtins.match "dotfiles=[0-9a-f]{40}(-dirty)?;agents-workspace=[0-9a-f]{40}" actualRevision
          != null;
        msg = "The evaluated NUC configuration must carry both labeled revisions.";
      }
      {
        test = pkgs.lib.hasSuffix "agents-workspace=${expectedAgentsWorkspaceRevision}" actualRevision;
        msg = "The evaluated NUC configuration must carry the exact locked agents-workspace revision.";
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
