# Validates the Herdr config template with Herdr's own `config config check`.
#
# `~/.config/herdr/config.toml` is intentionally writable (Herdr rewrites
# onboarding/settings at runtime), so the tracked template is the only copy we
# can gate. Herdr rejects unknown keys, which is how stale template keys are
# caught: `ui.agent_panel_scope` survived a Herdr upgrade that dropped the key
# and left every new shell printing a config warning.
#
# `herdr config check` takes no path argument and reads
# $XDG_CONFIG_HOME/herdr/config.toml, so the template is staged into a
# throwaway XDG root. It exits non-zero on unknown keys.
{
  pkgs,
  herdrPackage,
  configFile,
}:

pkgs.runCommand "herdr-config-check"
  {
    # gnused: `sed -i` without a backup suffix is a GNU extension, and this
    # check also runs on Darwin builders where /usr/bin/sed is BSD.
    nativeBuildInputs = [
      herdrPackage
      pkgs.gnused
    ];
  }
  ''
    export HOME="$PWD/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/herdr"
    install -m 0644 ${configFile} "$XDG_CONFIG_HOME/herdr/config.toml"

    # Guard the guard: if `config check` ever stops flagging unknown keys, the
    # real assertion below would silently pass on any template.
    cp "$XDG_CONFIG_HOME/herdr/config.toml" "$PWD/canary.toml"
    # Insert under the existing [ui] header instead of appending a second one:
    # a duplicate table is a TOML parse error, which would fail the check
    # without proving that unknown keys specifically are detected.
    grep -q '^\[ui\]' "$XDG_CONFIG_HOME/herdr/config.toml"
    sed -i '0,/^\[ui\]/s//[ui]\nherdr_config_check_canary = "x"/' \
      "$XDG_CONFIG_HOME/herdr/config.toml"
    grep -q 'herdr_config_check_canary' "$XDG_CONFIG_HOME/herdr/config.toml"
    if herdr config check > "$PWD/canary.log" 2>&1; then
      echo "FAIL: 'herdr config check' accepted an unknown key, so it cannot detect template drift" >&2
      cat "$PWD/canary.log" >&2
      exit 1
    fi
    install -m 0644 "$PWD/canary.toml" "$XDG_CONFIG_HOME/herdr/config.toml"

    if ! herdr config check > "$PWD/check.log" 2>&1; then
      echo "FAIL: 'herdr config check' rejected config/herdr/config.toml" >&2
      cat "$PWD/check.log" >&2
      exit 1
    fi
    cat "$PWD/check.log"

    touch $out
  ''
