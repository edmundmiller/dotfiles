{
  description = "openclaw plugin: linear";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=62c8382960464ceb98ea593cb8321a2cf8f9e3e5&narHash=sha256-kKB3bqYJU5nzYeIROI82Ef9VtTbu4uA3YydSk/Bioa8%3D";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      mkPkgs = system: import nixpkgs { inherit system; };
      mkLinear = system:
        let
          pkgs = mkPkgs system;
        in
        pkgs.writeShellApplication {
          name = "linear";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.curl
            pkgs.jq
          ];
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            usage() {
              cat <<'EOF'
            linear issues list --limit <n>
            linear issue get <identifier>
            linear gql <query> [variables_json]
            EOF
            }

            if [[ "''${1:-}" == "" ]]; then
              usage
              exit 1
            fi

            token_file="''${LINEAR_API_TOKEN_FILE:-}"
            if [[ -z "$token_file" ]]; then
              echo "LINEAR_API_TOKEN_FILE is not set" >&2
              exit 1
            fi
            if [[ ! -f "$token_file" ]]; then
              echo "LINEAR_API_TOKEN_FILE not found: $token_file" >&2
              exit 1
            fi

            token="$(cat "$token_file")"
            endpoint="https://api.linear.app/graphql"

            graphql() {
              local query="$1"
              local vars="''${2:-{}}"
              curl -sS \
                -H "Authorization: $token" \
                -H "Content-Type: application/json" \
                --data "$(jq -n --arg query "$query" --argjson variables "$vars" '{query:$query, variables:$variables}')" \
                "$endpoint"
            }

            case "$1" in
              issues)
                sub="''${2:-}"
                case "$sub" in
                  list)
                    shift 2
                    limit=20
                    while [[ $# -gt 0 ]]; do
                      case "$1" in
                        --limit)
                          limit="$2"
                          shift 2
                          ;;
                        *)
                          usage
                          exit 1
                          ;;
                      esac
                    done
                    query='query($first:Int!){issues(first:$first, orderBy:updatedAt){nodes{identifier title url state{name} assignee{name} updatedAt}}}'
                    vars="$(jq -n --argjson first "$limit" '{first:$first}')"
                    graphql "$query" "$vars"
                    ;;
                  *)
                    usage
                    exit 1
                    ;;
                esac
                ;;
              issue)
                sub="''${2:-}"
                case "$sub" in
                  get)
                    identifier="''${3:-}"
                    if [[ -z "$identifier" ]]; then
                      usage
                      exit 1
                    fi
                    query='query($identifier:String!){issues(first:1, filter:{identifier:{eq:$identifier}}){nodes{identifier title description url state{name} assignee{name email} team{key name} createdAt updatedAt}}}'
                    vars="$(jq -n --arg identifier "$identifier" '{identifier:$identifier}')"
                    graphql "$query" "$vars"
                    ;;
                  *)
                    usage
                    exit 1
                    ;;
                esac
                ;;
              gql)
                shift
                query="''${1:-}"
                vars="''${2:-{}}"
                if [[ -z "$query" ]]; then
                  usage
                  exit 1
                fi
                graphql "$query" "$vars"
                ;;
              *)
                usage
                exit 1
                ;;
            esac
          '';
        };
      pluginFor = system:
        let
          linear = mkLinear system;
        in
        {
          name = "linear";
          skills = [ ./skills/linear ];
          packages = [ linear ];
          needs = {
            stateDirs = [ ];
            requiredEnv = [ "LINEAR_API_TOKEN_FILE" ];
          };
        };
    in
    {
      packages = lib.genAttrs systems (system: {
        linear = mkLinear system;
      });
      openclawPlugin = pluginFor;
    };
}
