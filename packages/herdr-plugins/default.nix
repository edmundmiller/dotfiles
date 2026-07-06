{
  lib,
  stdenvNoCC,
}:
let
  pluginNames = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (./. + "/${name}/herdr-plugin.toml")
    ) (builtins.readDir ./.)
  );
in
stdenvNoCC.mkDerivation {
  pname = "dotfiles-herdr-plugins";
  version = "0.1.0";
  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    plugins_dir="$out/share/herdr/plugins"
    mkdir -p "$plugins_dir"

    for plugin in ${lib.escapeShellArgs pluginNames}; do
      cp -R "$src/$plugin" "$plugins_dir/$plugin"
      rm -rf "$plugins_dir/$plugin/__pycache__"
    done

    runHook postInstall
  '';

  passthru = {
    inherit pluginNames;
  };

  meta = {
    description = "Dotfiles-managed Herdr plugins";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
