# Pure Nix eval test: assert Scintillate has the live runtime access it needs.
#
# This catches regressions where the Telegram gateway can see the Obsidian
# vault but cannot use the TaskNotes CLI, or where the container receives a
# stale/mutable tnote symlink instead of the packaged CLI.
{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  profile = cfg.services.hermes-agent.profiles.scintillate;
  nucHostSource = builtins.readFile ../default.nix;

  inherit (builtins)
    any
    concatStringsSep
    elem
    toString
    ;
  inherit (pkgs.lib) hasInfix mapAttrsToList;

  # Use the exact package from the evaluated NUC config, not the local host's
  # package set.  This keeps the check valid when evaluated from macOS.
  stripContext = builtins.unsafeDiscardStringContext;
  tnotePkg = builtins.elemAt profile.extraPackages 0;
  tnotePkgString = stripContext (toString tnotePkg);
  extraPackageStrings = map (pkg: stripContext (toString pkg)) profile.extraPackages;

  hostMounts = mapAttrsToList (source: target: { inherit source target; }) profile.hostPathMounts;
  hasMount = source: target: any (mount: mount.source == source && mount.target == target) hostMounts;

  assertions = [
    {
      test = profile.workingDirectory == "/home/hermes/repos/obsidian-vault";
      msg = "Scintillate workingDirectory must be the Hermes-visible Obsidian vault path.";
    }
    {
      test = profile.settings.skills.config.wiki.path == "/repos/obsidian-vault";
      msg = "Scintillate wiki skill path must point at the container vault bind mount.";
    }
    {
      test = profile.environment.TN_VAULT_PATH == "/home/hermes/repos/obsidian-vault";
      msg = "Scintillate TN_VAULT_PATH must point at the Hermes-visible Obsidian vault.";
    }
    {
      test = profile.environment.WIKI_PATH == "/repos/obsidian-vault";
      msg = "Scintillate WIKI_PATH must point at the container vault bind mount.";
    }
    {
      test = hasMount "/home/emiller/obsidian-vault" "/repos/obsidian-vault";
      msg = "Scintillate must bind-mount /home/emiller/obsidian-vault at /repos/obsidian-vault.";
    }
    {
      test = hasMount "/home/emiller/src/personal/tnote" "/repos/tnote";
      msg = "Scintillate must bind-mount the tnote repo for reference/debugging.";
    }
    {
      test = elem tnotePkgString extraPackageStrings;
      msg = "Scintillate extraPackages must include the packaged TaskNotes CLI (pkgs.my.tnote).";
    }
    {
      test = any (pkg: hasInfix "util-linux" (toString pkg)) extraPackageStrings;
      msg = "Scintillate extraPackages must include util-linux so the container entrypoint can setpriv to HERMES_UID/GID.";
    }
    {
      test = hasInfix (
        "ln -sfn " + "$" + "{pkgs.my.tnote}/bin/tnote /var/lib/hermes-scintillate/home/.local/bin/tnote"
      ) nucHostSource;
      msg = "Scintillate ExecStartPre must link ~/.local/bin/tnote to the packaged tnote binary.";
    }
    {
      test = !(hasInfix "/home/emiller/.local/bin/tnote" nucHostSource);
      msg = "Scintillate host config must not recreate a container-broken /home/emiller/.local/bin/tnote symlink.";
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

    mkdir -p "$out"
    echo "Scintillate runtime access assertions passed" > "$out/result"
''
