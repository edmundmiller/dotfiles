# Bugster — Bugwarrior meets TaskNotes, running on Dagster
#
# Syncs GitHub/Jira/Linear issues into Obsidian TaskNotes via dlt pipelines.
# Runs as a dagster code location (gRPC server) managed by the dagster module.
#
# Architecture:
#   - Git clone of bugster repo at ${cfg.dataDir}
#   - uv manages Python deps from pyproject.toml + uv.lock
#   - dagster code-server exposes bugster.definitions on gRPC port
#   - dagster webserver/daemon connect via workspace.yaml
#
# Secrets: API tokens passed as env vars, referenced in bugster.toml as ${VAR}
{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.bugster;

  # Generate bugster.toml from Nix options
  bugsterToml = pkgs.writeText "bugster.toml" (
    ''
      [tasknotes]
      vault_path = "${cfg.tasknotes.vaultPath}"
      tasks_dir = "${cfg.tasknotes.tasksDir}"
    ''
    + concatMapStrings (src:
      if src.type == "github" then ''

        [[sources]]
        type = "github"
        name = "${src.name}"
        token = "''${${src.tokenEnv}}"
        username = "${src.username}"
        contexts = [${concatMapStringsSep ", " (c: ''"${c}"'') src.contexts}]
        include_issues = ${boolToString src.includeIssues}
        include_prs = ${boolToString src.includePrs}
        include_review_requests = ${boolToString src.includeReviewRequests}
        ${optionalString (src.includeRepos != []) "include_repos = [${concatMapStringsSep ", " (r: ''\"${r}\"'') src.includeRepos}]"}
        ${optionalString (src.excludeRepos != []) "exclude_repos = [${concatMapStringsSep ", " (r: ''\"${r}\"'') src.excludeRepos}]"}
      ''
      else if src.type == "linear" then ''

        [[sources]]
        type = "linear"
        name = "${src.name}"
        token = "''${${src.tokenEnv}}"
        ${optionalString (src.teamIds != []) "team_ids = [${concatMapStringsSep ", " (t: ''\"${t}\"'') src.teamIds}]"}
        contexts = [${concatMapStringsSep ", " (c: ''"${c}"'') src.contexts}]
        only_assigned = ${boolToString src.onlyAssigned}
      ''
      else if src.type == "jira" then ''

        [[sources]]
        type = "jira"
        name = "${src.name}"
        url = "''${${src.urlEnv}}"
        username = "''${${src.usernameEnv}}"
        token = "''${${src.tokenEnv}}"
        ${optionalString (src.projects != []) "projects = [${concatMapStringsSep ", " (p: ''\"${p}\"'') src.projects}]"}
        contexts = [${concatMapStringsSep ", " (c: ''"${c}"'') src.contexts}]
        only_my_issues = ${boolToString src.onlyMyIssues}
      ''
      else ""
    ) cfg.sources
  );

  # Script to set up the bugster repo and config
  # Runs as root to handle git clone (private repo needs user SSH keys),
  # then chowns to dagster.
  setupScript = pkgs.writeShellScript "bugster-setup" ''
    set -euo pipefail

    REPO_DIR="${cfg.dataDir}"

    # Use emiller's SSH keys for private repo access
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /home/emiller/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new"

    # Allow root to operate on dagster-owned repo
    ${pkgs.git}/bin/git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true

    # Clone if not present, pull if exists
    if [ ! -d "$REPO_DIR/.git" ]; then
      ${pkgs.git}/bin/git clone ${cfg.gitUrl} "$REPO_DIR"
    else
      cd "$REPO_DIR"
      ${pkgs.git}/bin/git fetch origin
      ${pkgs.git}/bin/git reset --hard origin/${cfg.gitBranch}
    fi

    # Fix ownership
    chown -R dagster:dagster "$REPO_DIR"

    # Copy generated config (env vars expanded at runtime by bugster)
    cp ${bugsterToml} "$REPO_DIR/bugster.toml"
    chown dagster:dagster "$REPO_DIR/bugster.toml"
    chmod 640 "$REPO_DIR/bugster.toml"

    # Grant dagster write access to the obsidian vault for TaskNotes output
    ${pkgs.acl}/bin/setfacl -R -m u:dagster:rwX ${cfg.tasknotes.vaultPath}/${cfg.tasknotes.tasksDir} 2>/dev/null || true
    ${pkgs.acl}/bin/setfacl -R -d -m u:dagster:rwX ${cfg.tasknotes.vaultPath}/${cfg.tasknotes.tasksDir} 2>/dev/null || true
  '';

  sourceType = types.submodule ({ config, ... }: {
    options = {
      type = mkOpt (types.enum [ "github" "linear" "jira" ]) "github";
      name = mkOpt types.str "";
      # Common
      contexts = mkOpt (types.listOf types.str) [];
      tokenEnv = mkOpt types.str "";
      # GitHub
      username = mkOpt types.str "";
      includeIssues = mkBoolOpt true;
      includePrs = mkBoolOpt true;
      includeReviewRequests = mkBoolOpt true;
      includeRepos = mkOpt (types.listOf types.str) [];
      excludeRepos = mkOpt (types.listOf types.str) [];
      # Linear
      teamIds = mkOpt (types.listOf types.str) [];
      onlyAssigned = mkBoolOpt true;
      # Jira
      urlEnv = mkOpt types.str "JIRA_URL";
      usernameEnv = mkOpt types.str "JIRA_USERNAME";
      projects = mkOpt (types.listOf types.str) [];
      onlyMyIssues = mkBoolOpt true;
    };
  });
in
{
  options.modules.services.bugster = {
    enable = mkBoolOpt false;

    gitUrl = mkOpt types.str "git@github.com:edmundmiller/bugster.git";
    gitBranch = mkOpt types.str "main";

    port = mkOpt types.port 4000;

    dataDir = mkOpt types.str "/var/lib/dagster/bugster";

    # Environment file with API tokens (agenix secret)
    environmentFile = mkOpt types.str "";

    tasknotes = {
      vaultPath = mkOpt types.str "/home/emiller/obsidian-vault";
      tasksDir = mkOpt types.str "00_Inbox/Tasks/Bugster";
    };

    sources = mkOpt (types.listOf sourceType) [];
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {

      # Ensure dagster is enabled with tailscale UI access
      modules.services.dagster = {
        enable = true;
        tailscaleService.enable = true;

        # Register bugster as a gRPC code location
        codeLocations = [
          {
            type = "grpc";
            name = "bugster";
            host = "localhost";
            port = cfg.port;
            service = {
              enable = true;
              workingDirectory = cfg.dataDir;
              execStart = pkgs.writeShellScript "bugster-code-server" ''
                set -euo pipefail
                cd ${cfg.dataDir}

                # Sync Python deps (frozen = use lockfile, no resolution)
                ${pkgs.uv}/bin/uv sync --frozen --no-dev 2>&1

                # Start gRPC code server
                exec ${pkgs.uv}/bin/uv run dagster code-server start \
                  -m bugster.definitions \
                  -h 0.0.0.0 \
                  -p ${toString cfg.port}
              '';
              environment = {
                BUGSTER_CONFIG = "${cfg.dataDir}/bugster.toml";
                # uv needs a writable cache dir
                UV_CACHE_DIR = "/var/lib/dagster/.cache/uv";
                # Use system Python
                UV_PYTHON_PREFERENCE = "system";
                # Home for uv/pip
                HOME = "/var/lib/dagster";
              };
              environmentFiles = optional (cfg.environmentFile != "") cfg.environmentFile;
              readWritePaths = [
                cfg.dataDir
                "/var/lib/dagster/.cache"
                cfg.tasknotes.vaultPath
              ];
            };
          }
        ];
      };

      # Setup service — clones/updates bugster repo before code server starts
      # Runs as root to access emiller's SSH keys for private repo
      systemd.services.bugster-setup = {
        description = "Bugster repo setup";
        wantedBy = [ "multi-user.target" ];
        before = [ "dagster-code-bugster.service" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = setupScript;
        };

        environment = {
          HOME = "/var/lib/dagster";
          GIT_TERMINAL_PROMPT = "0";
        };
      };

      # Make dagster-code-bugster depend on setup
      systemd.services.dagster-code-bugster = {
        after = [ "bugster-setup.service" ];
        requires = [ "bugster-setup.service" ];
      };

      # Ensure data directory exists
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 dagster dagster -"
        "d /var/lib/dagster/.cache 0750 dagster dagster -"
        "d /var/lib/dagster/.cache/uv 0750 dagster dagster -"
      ];

      # Obsidian vault needs to be writable by dagster user
      # Vault is owned by emiller:users with 0755 — add dagster to users group
      users.users.dagster.extraGroups = [ "users" ];
    }
  );
}
