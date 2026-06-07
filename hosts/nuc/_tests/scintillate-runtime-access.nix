# Pure Nix eval test: assert the NUC satisfies Scintillate's agent-owned
# TaskNotes runtime contract with host-specific providers.
#
# The policy/defaults live in agents-workspace. This host check should verify
# concrete NUC provider satisfaction, not re-author Scintillate's runtime wiring.
{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  hermesAgent = cfg.modules.services.hermes.agents.scintillate;
  profile = cfg.services.hermes-agent.profiles.scintillate;
  gatewayService = cfg.systemd.services.hermes-gateway-scintillate;
  activation = cfg.system.activationScripts."canonical-hermes-profiles-materialize".text;
  activationFile = pkgs.writeText "canonical-hermes-profiles-materialize.sh" activation;
  nucHostSource = builtins.readFile ../default.nix;

  inherit (builtins) any concatStringsSep toString;
  inherit (pkgs.lib) hasInfix mapAttrsToList;

  stripContext = builtins.unsafeDiscardStringContext;
  tnotePkg = hermesAgent.providers.tnote.package;
  tnotePkgString = stripContext (toString tnotePkg);
  packageStrings = map (pkg: stripContext (toString pkg)) profile.extraPackages;

  hostMounts = mapAttrsToList (source: target: { inherit source target; }) profile.hostPathMounts;
  hasMount = source: target: any (mount: mount.source == source && mount.target == target) hostMounts;
  hasPackageNamed = name: any (pkg: hasInfix name pkg) packageStrings;

  assertions = [
    {
      test = hermesAgent.providers.obsidianVault.hostPath == "/home/emiller/obsidian-vault";
      msg = "NUC must provide Scintillate's Obsidian vault provider.";
    }
    {
      test = hasInfix "tnote" tnotePkgString;
      msg = "NUC must provide Scintillate's tnote package provider.";
    }
    {
      test = hermesAgent.providers.tnote.repoPath == "/home/emiller/src/personal/tnote";
      msg = "NUC must provide Scintillate's tnote repo provider.";
    }
    {
      test = profile.workingDirectory == "/home/hermes/repos/obsidian-vault";
      msg = "Scintillate workingDirectory must come from the agent-owned TaskNotes runtime default.";
    }
    {
      test = profile.settings.skills.config.wiki.path == "/home/hermes/repos/obsidian-vault";
      msg = "Scintillate wiki skill path must come from the agent-owned TaskNotes runtime default.";
    }
    {
      test = profile.settings.terminal.cwd == "/home/hermes/repos/obsidian-vault";
      msg = "Scintillate terminal cwd must come from the agent-owned TaskNotes runtime default.";
    }
    {
      test = profile.environment.TN_VAULT_PATH == "/home/hermes/repos/obsidian-vault";
      msg = "Scintillate TN_VAULT_PATH must come from the agent-owned TaskNotes runtime default.";
    }
    {
      test = profile.environment.WIKI_PATH == "/repos/obsidian-vault";
      msg = "Scintillate WIKI_PATH must point at the container vault bind mount.";
    }
    {
      test = hasMount "/home/emiller/obsidian-vault" "/repos/obsidian-vault";
      msg = "Scintillate must bind-mount the provided Obsidian vault at /repos/obsidian-vault.";
    }
    {
      test = hasMount "/home/emiller/src/personal/tnote" "/repos/tnote";
      msg = "Scintillate must bind-mount the provided tnote repo at /repos/tnote.";
    }
    {
      test = hasPackageNamed "tnote";
      msg = "Scintillate profile extraPackages must include the provided tnote package.";
    }
    {
      test = hasPackageNamed "util-linux";
      msg = "Scintillate profile extraPackages must include util-linux so the container entrypoint can setpriv to HERMES_UID/GID.";
    }
    {
      test =
        !(any (
          preStart: hasInfix "hermes-scintillate-codex-auth-import" (toString preStart)
        ) gatewayService.serviceConfig.ExecStartPre);
      msg = "Scintillate must not import Codex CLI OAuth tokens; refresh tokens are single-use and Hermes owns its own Codex auth store.";
    }
    {
      test = profile.authFile == null;
      msg = "Scintillate must not seed Hermes auth from ~/.codex/auth.json.";
    }
    {
      test = !(hasInfix "skills.config.wiki.path = \"/home/hermes/repos/obsidian-vault\"" nucHostSource);
      msg = "NUC host config must not re-author Scintillate's wiki runtime default.";
    }
    {
      test = !(hasInfix "extraPackages = [\n          pkgs.my.tnote" nucHostSource);
      msg = "NUC host config must not inject Scintillate's ordinary tnote runtime package directly.";
    }
    {
      test = !(hasInfix "hermes-scintillate-repo-compat-links" nucHostSource);
      msg = "NUC host config must not carry Scintillate's ordinary repo/tnote compatibility link script.";
    }
  ];

  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-scintillate-runtime-access" { } ''
    if [ ${toString (builtins.length failures)} -ne 0 ]; then
      cat >&2 <<'EOF'
  Scintillate runtime access assertions failed:
  ${concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
      exit 1
    fi

    grep -Fq "ln -sfn /repos/obsidian-vault /var/lib/hermes-scintillate/home/repos/obsidian-vault" ${activationFile} || {
      echo "Agent-owned activation must create Scintillate's vault compatibility link." >&2
      exit 1
    }

    grep -Fq "ln -sfn ${tnotePkgString}/bin/tnote /var/lib/hermes-scintillate/home/.local/bin/tnote" ${activationFile} || {
      echo "Agent-owned activation must link ~/.local/bin/tnote to the provided tnote package." >&2
      exit 1
    }

    mkdir -p "$out"
    echo "Scintillate runtime access assertions passed" > "$out/result"
''
