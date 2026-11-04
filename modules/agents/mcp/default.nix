{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.modules.agents.mcp;
  runtimes = [
    "pi"
    "omp"
    "claude"
    "codex"
    "opencode"
    "amp"
  ];
  serverType = types.submodule {
    options = {
      enable = lib.mkEnableOption "this MCP server on the host";
      transport = mkOption {
        type = types.enum [
          "stdio"
          "http"
        ];
        default = "http";
      };
      url = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Literal, non-secret subprocess environment. Resolve secrets in the server launcher.";
      };
      bearerTokenEnv = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Environment variable containing a bearer token, never the token itself.";
      };
      excludeAgents = mkOption {
        type = types.listOf (types.enum runtimes);
        default = [ ];
      };
    };
  };
  agents = lib.filter (name: cfg.enable && cfg.agents.${name}) runtimes;
  manifest = pkgs.writeText "host-mcp.json" (
    builtins.toJSON {
      inherit agents;
      servers = if cfg.enable then cfg.servers else { };
    }
  );
  python = pkgs.python3.withPackages (p: [
    p.json5
    p.tomlkit
  ]);
in
{
  options.modules.agents.mcp = {
    enable = lib.mkEnableOption "host-owned MCP configuration for coding agents";
    servers = mkOption {
      type = types.attrsOf serverType;
      default = { };
    };
    agents = lib.genAttrs runtimes (
      name:
      mkOption {
        type = types.bool;
        default = if name == "amp" then false else config.modules.agents.${name}.enable;
        description = "Reconcile host MCP servers for ${name}. Amp is app-managed and must be selected explicitly.";
      }
    );
  };
  config = {
    modules.agents.mcp.servers = lib.mkIf cfg.enable (
      import ../../../config/agents/mcp.nix { inherit lib pkgs; }
    );
    assertions =
      lib.mapAttrsToList (name: server: {
        assertion =
          !server.enable
          || (
            if server.transport == "stdio" then
              server.command != null && server.url == null && server.bearerTokenEnv == null
            else
              server.url != null && server.command == null && server.args == [ ] && server.env == { }
          );
        message = "MCP ${name}: stdio requires command and forbids URL/bearer auth; HTTP requires URL and forbids subprocess fields.";
      }) cfg.servers
      ++ [
        {
          assertion =
            builtins.all (name: builtins.match "[A-Za-z0-9_-]+" name != null) (builtins.attrNames cfg.servers)
            &&
              lib.length (lib.unique (map (lib.replaceStrings [ "-" ] [ "_" ]) (builtins.attrNames cfg.servers)))
              == lib.length (builtins.attrNames cfg.servers);
          message = "MCP server names must contain only letters, digits, underscores or hyphens and must not collide after hyphen normalization.";
        }
      ];
    home.file.".config/agents/mcp.json".source = manifest;
    home-manager.users.${config.user.name} = { lib, ... }: {
      home.activation.host-mcp-detach =
        lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            ${python}/bin/python3 ${../../../config/agents/reconcile_mcp.py} --home "$HOME" --detach-store-links ${manifest}
          '';
      home.activation.host-mcp =
        lib.hm.dag.entryAfter
          [
            "linkGeneration"
            "codex-config-bootstrap"
            "claude-mcp-cleanup"
            "opencode-v1-cleanup"
            "opencode-config-bootstrap"
          ]
          ''
            ${python}/bin/python3 ${../../../config/agents/reconcile_mcp.py} --home "$HOME" ${manifest}
          '';
    };
  };
}
