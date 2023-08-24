{
  appimageTools,
  fetchurl,
  makeWrapper,
  ...
}: let
  pname = "beeper";
  version = "v3.71.16";
  name = "${pname}-${version}";
  src = fetchurl {
    url = "https://download.beeper.com/linux/appImage/x64";
    hash = "sha256-Ho5zFmhNzkOmzo/btV+qZfP2GGx5XvV/1JncEKlH4vc=";
    name = "${name}.AppImage";
  };
in
  appimageTools.wrapType2 {
    inherit name src version;

    extraInstallCommands = let
      appimageContents = appimageTools.extractType2 {inherit name src;};
    in ''
      mv $out/bin/${name} $out/bin/${pname}
      source "${makeWrapper}/nix-support/setup-hook"
      wrapProgram $out/bin/${pname} \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
      install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop
      install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/${pname}.png \
         $out/share/icons/hicolor/512x512/apps/${pname}.png
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace 'Icon=lens' 'Icon=${pname}' \
        --replace 'Exec=AppRun' 'Exec=${pname}'
    '';

    meta = {
      homepage = "https://www.beeper.com/";
      description = "All your chats in one app. Yes, really.";
      # license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
      maintainers = ["emiller88"];
    };
  }
