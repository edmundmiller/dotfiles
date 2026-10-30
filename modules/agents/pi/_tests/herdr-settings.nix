{ lib, pkgs }:
let
  githubTools = pkgs.writeTextDir "package.json" ''{"name":"github-tools-fixture"}'';
  legacyHerdr = pkgs.writeTextDir "package.json" ''{"name":"legacy-herdr-fixture"}'';
  render =
    enabled: backend:
    (import ../lib/_settings.nix {
      inherit lib;
      config = {
        modules.shell.herdr = {
          enable = enabled;
          inherit backend;
          managePiTheme = false;
        };
        modules.shell.tmux.enable = false;
      };
      cfg = {
        extraPackages = [
          "npm:@ogulcancelik/pi-herdr@9.9.9"
          {
            source = "npm:@ogulcancelik/pi-herdr";
            extensions = [ "custom.ts" ];
          }
        ];
        enabledModels = [ ];
        defaultProvider = null;
        defaultModel = null;
        computerUse.enable = false;
        gitTools.enable = true;
        statusUi.enable = false;
        contextMemory.enable = false;
        cursorSdk.enable = false;
        honcho.enable = false;
      };
      piHerdrPackage = legacyHerdr;
      herdrVersion = "0.9.1";
      piSettingsParsed = {
        packages = [
          "npm:keep-me"
          (toString githubTools)
          "npm:@ogulcancelik/pi-herdr"
        ];
      };
    }).piSettingsValidated;
  nativeSettings = render true "native";
  legacySettings = render true "legacy";
  disabledSettings = render false "native";
in
# These are real derivation-backed strings, unlike a plain source-path fixture.
# Rendering must retain dependency context without attempting a JSON round trip.
assert builtins.hasAttr (builtins.unsafeDiscardStringContext githubTools.drvPath) (
  builtins.getContext nativeSettings
);
assert builtins.hasAttr (builtins.unsafeDiscardStringContext legacyHerdr.drvPath) (
  builtins.getContext legacySettings
);
assert
  !(builtins.hasAttr (builtins.unsafeDiscardStringContext legacyHerdr.drvPath) (
    builtins.getContext nativeSettings
  ));
pkgs.runCommand "pi-herdr-settings-tests"
  {
    inherit nativeSettings legacySettings disabledSettings;
    githubToolsPath = toString githubTools;
    legacyHerdrPath = toString legacyHerdr;
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    python3 - <<'PY'
    import json
    import os

    def sources(key):
        packages = json.loads(os.environ[key])["packages"]
        return [item if isinstance(item, str) else item["source"] for item in packages]

    for key in ["nativeSettings", "disabledSettings"]:
        packages = sources(key)
        assert "npm:keep-me" in packages
        assert os.environ["githubToolsPath"] in packages
        assert os.environ["legacyHerdrPath"] not in packages
        assert not any(item.startswith("npm:@ogulcancelik/pi-herdr") for item in packages)

    legacy = sources("legacySettings")
    assert os.environ["legacyHerdrPath"] in legacy
    assert "npm:@ogulcancelik/pi-herdr@0.4.0" in legacy
    assert "npm:@ogulcancelik/pi-herdr@9.9.9" in legacy
    assert os.environ["githubToolsPath"] in legacy
    print("PASS: native and disabled backends filter legacy packages; legacy retains them; Nix dependency context survives")
    PY
    touch "$out"
  ''
