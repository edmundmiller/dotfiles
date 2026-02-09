{
  options,
  config,
  lib,
  pkgs,
  ...
}:

with lib;
with lib.my;
let
  cfg = config.modules.shell.agents.skills;

  # Each pinned skill: fetched from GitHub with hash verification
  skillType = types.submodule {
    options = {
      owner = mkOption {
        type = types.str;
        description = "GitHub owner";
      };
      repo = mkOption {
        type = types.str;
        description = "GitHub repo";
      };
      rev = mkOption {
        type = types.str;
        description = "Git revision (commit SHA)";
      };
      hash = mkOption {
        type = types.str;
        description = "SRI hash (nix-prefetch)";
      };
      skill = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Subdirectory within repo (null = repo root is the skill)";
      };
    };
  };

  # Fetch and build a single skill derivation
  mkSkill =
    name: spec:
    let
      src = pkgs.fetchFromGitHub {
        inherit (spec)
          owner
          repo
          rev
          hash
          ;
      };
      skillPath = if spec.skill != null then "${src}/${spec.skill}" else src;
    in
    pkgs.runCommand "agent-skill-${name}" { } ''
      mkdir -p $out
      # Copy SKILL.md and references/
      if [ -f "${skillPath}/SKILL.md" ]; then
        cp "${skillPath}/SKILL.md" $out/
      else
        echo "ERROR: No SKILL.md found in ${spec.owner}/${spec.repo}${
          optionalString (spec.skill != null) "/${spec.skill}"
        }" >&2
        exit 1
      fi
      if [ -d "${skillPath}/references" ]; then
        cp -r "${skillPath}/references" $out/
      fi
    '';

  # Build all pinned skills
  pinnedSkills = mapAttrs mkSkill cfg.pinned;

in
{
  options.modules.shell.agents.skills = {
    enable = mkBoolOpt false;

    pinned = mkOption {
      type = types.attrsOf skillType;
      default = { };
      description = "Skills pinned by GitHub rev + SRI hash";
      example = literalExpression ''
        {
          pr-review = {
            owner = "anthropics";
            repo = "claude-code-skills";
            skill = "pr-review";
            rev = "abc123...";
            hash = "sha256-...";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # Symlink each pinned skill into all agent skill directories
    home.file =
      let
        # Generate entries for one agent's skill dir
        agentSkills =
          prefix:
          mapAttrs' (
            name: _drv:
            nameValuePair "${prefix}/${name}" {
              source = _drv;
              recursive = true;
            }
          ) pinnedSkills;
      in
      # All three agents get every pinned skill
      (agentSkills ".pi/agent/skills")
      // (agentSkills ".claude/skills")
      // (agentSkills ".config/opencode/skill");
  };
}
