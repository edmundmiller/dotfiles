{ lib, pkgs }:
let
  githubTools = pkgs.writeTextDir "package.json" ''{"name":"github-tools-fixture"}'';
  render =
    enabled:
    (import ../lib/_settings.nix {
      inherit lib;
      config.modules.shell.herdr.enable = enabled;
      cfg = {
        extraPackages = [
          "npm:@ogulcancelik/pi-herdr@9.9.9"
          {
            source = "npm:pi-tmux-window-name@1.2.3";
            extensions = [ "custom.ts" ];
          }
        ];
        enabledModels = [ ];
        defaultProvider = null;
        defaultModel = null;
        computerUse.enable = false;
        gitTools.enable = true;
        statusUi.enable = true;
        contextMemory.enable = false;
        cursorSdk.enable = false;
        honcho.enable = false;
      };
      piGithubToolsPackage = githubTools;
      piSettingsParsed.packages = [
        "npm:keep-me"
        "npm:@ogulcancelik/pi-herdr"
        "npm:pi-tmux-window-name"
      ];
    }).piSettingsValidated;
  nativeSettings = render true;
  disabledSettings = render false;
in
# Rendering must preserve derivation context without a JSON round trip.
assert builtins.hasAttr (builtins.unsafeDiscardStringContext githubTools.drvPath) (
  builtins.getContext nativeSettings
);
pkgs.runCommand "pi-herdr-settings-tests"
  {
    inherit nativeSettings disabledSettings;
    githubToolsPath = toString githubTools;
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    python3 - <<'PY'
    import json
    import os

    for key in ["nativeSettings", "disabledSettings"]:
        packages = json.loads(os.environ[key])["packages"]
        sources = [item if isinstance(item, str) else item["source"] for item in packages]
        assert "npm:keep-me" in sources
        assert "git:github.com/Thinkscape/pi-status" in sources
        assert os.environ["githubToolsPath"] in sources
        assert not any(item.startswith(("npm:@ogulcancelik/pi-herdr", "npm:pi-tmux-window-name")) for item in sources)
        assert ("npm:pi-interactive-shell" in sources) == (key == "disabledSettings")
    print("PASS: retired adapters excluded; supported packages and Nix dependency context preserved")
    PY
    touch "$out"
  ''
