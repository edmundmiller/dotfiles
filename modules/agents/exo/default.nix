{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (lib.my) mkBoolOpt;
  cfg = config.modules.agents.exo;

  exo = pkgs.rustPlatform.buildRustPackage {
    pname = "exoharness-exo";
    version = "0.1.0-unstable-2026-09-03";

    src = pkgs.fetchFromGitHub {
      owner = "exoharness";
      repo = "exo";
      rev = "7801005e6a1ab77008a05dbba80e0a2a7a56e35d";
      hash = "sha256-wOVr/zwKJLDD1uC9lGqlKkg+w+M6prbYnbEDCKbGQcw=";
    };

    cargoHash = "sha256-GAXfXBJ9zA+zUCZeDR7xx4gNGwlN+AITYX1WJSfHDoc=";
    cargoBuildFlags = [
      "-p"
      "exo"
    ];
    doCheck = false;

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.pkg-config
    ];

    meta = {
      description = "Agent harness for managing coding agents in isolated environments";
      homepage = "https://github.com/exoharness/exo";
      license = lib.licenses.mit;
      mainProgram = "exo";
      platforms = lib.platforms.unix;
    };
  };
in
{
  options.modules.agents.exo = {
    enable = mkBoolOpt false;
    package = mkOption {
      type = types.package;
      default = exo;
      description = "Pinned Exo CLI package.";
    };
  };

  config = mkIf cfg.enable {
    user.packages = [ cfg.package ];
  };
}
