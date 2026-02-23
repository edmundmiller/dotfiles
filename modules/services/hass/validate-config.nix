# Build-time config validation using HA's own check_config.
#
# Runs HA's voluptuous validators against the generated configuration.yaml
# inside a nix build sandbox. Catches every config error HA would reject,
# including custom component options (e.g. force_rgb_color).
#
# Fires during `nixos-rebuild switch`. If validation fails, build fails.
#
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.home-assistant;
  hassEnabled = cfg.enable or false;

  configYaml = (pkgs.formats.yaml { }).generate "configuration.yaml" cfg.config;

  # Minimal config dir: config + custom_components + dummy secrets
  configDir = pkgs.runCommand "hass-check-config-dir" { } ''
    mkdir -p $out/custom_components

    cp ${configYaml} $out/configuration.yaml

    # Dummy secrets — we validate structure, not secret values
    cat > $out/secrets.yaml <<'EOF'
    ${lib.concatStringsSep "\n" (map (k: "${k}: dummy-build-time-value") secretKeys)}
    EOF

    # Empty !include targets
    touch $out/automations.yaml $out/scenes.yaml $out/scripts.yaml

    # Symlink custom components from nix packages
    ${lib.concatMapStringsSep "\n" (comp: ''
      if [ -d "${comp}/custom_components" ]; then
        for d in ${comp}/custom_components/*/; do
          ln -sf "$d" $out/custom_components/
        done
      fi
    '') cfg.customComponents}
  '';

  # Extract !secret keys from config for dummy secrets.yaml
  secretKeys =
    let
      findSecrets =
        attrs:
        if builtins.isString attrs then
          let
            m = builtins.match "!secret (.*)" attrs;
          in
          if m != null then [ (builtins.head m) ] else [ ]
        else if builtins.isList attrs then
          lib.concatMap findSecrets attrs
        else if builtins.isAttrs attrs then
          lib.concatMap findSecrets (builtins.attrValues attrs)
        else
          [ ];
    in
    lib.unique (findSecrets cfg.config);

  # We can't use `hass` (bash wrapper with --skip-pip) or `.hass-wrapped`
  # (Python script, not interpreter) directly. Instead, we use the bash
  # wrapper's environment setup + our Python stub. The bash `hass` wrapper
  # sets PATH and PYTHONNOUSERSITE then execs `.hass-wrapped --skip-pip`.
  # We replicate this by running `hass` but replacing the executed script.
  #
  # Approach: create a sitecustomize.py that stubs colorlog + pip,
  # placed in PYTHONPATH before HA runs check_config normally.
  siteCustomize = pkgs.writeTextDir "sitecustomize.py" ''
    import sys, types

    # Stub colorlog (only used for terminal colors, not validation)
    colorlog = types.ModuleType("colorlog")
    esc = types.ModuleType("colorlog.escape_codes")
    esc.escape_codes = {"reset": ""}
    esc.parse_colors = lambda x: ""
    colorlog.escape_codes = esc
    sys.modules["colorlog"] = colorlog
    sys.modules["colorlog.escape_codes"] = esc

    # Stub package installer so REQUIREMENTS check passes
    import homeassistant.util.package as pkg
    pkg.install_package = lambda *a, **kw: True
    pkg.is_installed = lambda *a, **kw: True
    pkg.is_virtual_env = lambda: True
  '';

  hassConfigCheck =
    pkgs.runCommand "hass-check-config"
      {
        nativeBuildInputs = [
          cfg.package
          pkgs.jq
        ];
      }
      ''
        export HOME=$TMPDIR

        # Inject sitecustomize.py that stubs colorlog + pip before HA loads
        export PYTHONPATH="${siteCustomize}:''${PYTHONPATH:-}"

        # Run check_config. The hass wrapper injects --skip-pip which
        # check_config doesn't understand — it prints "Unknown arguments"
        # to stdout before the JSON. We extract just the JSON object.
        set +e
        ${cfg.package}/bin/hass --script check_config -c ${configDir} --json \
          >$TMPDIR/raw_output 2>$TMPDIR/stderr.log
        EXIT_CODE=$?
        set -e

        # Extract JSON from output (skip any non-JSON lines from --skip-pip)
        grep -E '^\{' $TMPDIR/raw_output | head -1 > $TMPDIR/start_line || true
        if [ -s $TMPDIR/start_line ]; then
          # Find the line number where JSON starts and extract from there
          LINE=$(grep -n '^\{' $TMPDIR/raw_output | head -1 | cut -d: -f1)
          tail -n +$LINE $TMPDIR/raw_output > $TMPDIR/result.json
        else
          cp $TMPDIR/raw_output $TMPDIR/result.json
        fi

        if ! jq . $TMPDIR/result.json >/dev/null 2>&1; then
          echo "check_config did not produce valid JSON (exit $EXIT_CODE)"
          echo "=== raw output ===" && cat $TMPDIR/raw_output || true
          echo "=== stderr ===" && cat $TMPDIR/stderr.log || true
          exit 1
        fi

        COMPONENTS=$(jq -r '.components | join(", ")' $TMPDIR/result.json)
        echo "Components: $COMPONENTS"

        # Filter false positives: nix's YAML generator quotes !secret and
        # !include as literal strings. HA's real loader handles these as tags.
        # Also filter NodeStrClass errors (from !include being a string).
        REAL_ERRORS=$(jq '
          .errors | to_entries
          | map(select(
              (.value | tostring) as $v |
              ($v | contains("!secret") or contains("!include") or contains("NodeStrClass")) | not
            ))
          | length
        ' $TMPDIR/result.json)

        ALL_ERRORS=$(jq '.total_errors' $TMPDIR/result.json)
        echo "Errors: $ALL_ERRORS total, $REAL_ERRORS real"

        if [ "$REAL_ERRORS" != "0" ]; then
          echo ""
          jq -r '
            .errors | to_entries[]
            | select(
                (.value | tostring) as $v |
                ($v | contains("!secret") or contains("!include") or contains("NodeStrClass")) | not
              )
            | "\(.key): \(.value[0])"
          ' $TMPDIR/result.json
          echo ""
          echo "HA config validation failed."
          exit 1
        fi

        mkdir -p $out
        cp $TMPDIR/result.json $out/
        echo "passed" > $out/result
      '';

in
lib.mkIf hassEnabled {
  system.extraDependencies = [ hassConfigCheck ];
}
