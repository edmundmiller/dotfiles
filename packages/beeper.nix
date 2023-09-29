{
  lib,
  fetchurl,
  stdenv,
  appimageTools,
  libsecret,
  makeWrapper,
  hicolor-icon-theme,
}: let
  pname = "beeper";
  version = "3.78.23";
  name = "${pname}-${version}";
  src = fetchurl {
    url = "https://download.todesktop.com/2003241lzgn20jd/beeper-${version}.AppImage";
    hash = "sha512-UfRGFJm5oq/2rpRORLxCNEAWYgk28upyn1AWgZg35IlSS++D/aezqk0pdm8GSq5hQGtx5pv/v6fmpVUorpD1WQ==";
  };
  appimage = appimageTools.wrapType2 {
    inherit version pname src;
    extraPkgs = pkgs: with pkgs; [libsecret];
  };
  appimageContents = appimageTools.extractType2 {
    inherit version pname src;
  };
in
  stdenv.mkDerivation rec {
    inherit name pname;

    src = appimage;

    nativeBuildInputs = [makeWrapper];

    # Used in AUR https://aur.archlinux.org/packages/beeper-latest-bin
    buildInputs = [hicolor-icon-theme];

    installPhase = ''
      runHook preInstall

      mv bin/${name} bin/${pname}

      mkdir -p $out/
      cp -r bin $out/bin

      mkdir -p $out/share/${pname}
      cp -a ${appimageContents}/locales $out/share/${pname}
      cp -a ${appimageContents}/resources $out/share/${pname}
      for s in 16 32 48 64 128 256 512 1024 ; do
        install -vDm0644 \
        "${appimageContents}/usr/share/icons/hicolor/''${s}x''${s}/apps/beeper.png" \
        -t "$out/share/icons/hicolor/''${s}x''${s}/apps"
      done
      install -Dm 644 ${appimageContents}/${pname}.desktop -t $out/share/applications/

      substituteInPlace $out/share/applications/${pname}.desktop --replace "AppRun" "${pname}"

      wrapProgram $out/bin/${pname} \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}} --no-update"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Universal chat app.";
      longDescription = ''
        Beeper is a universal chat app. With Beeper, you can send
        and receive messages to friends, family and colleagues on
        many different chat networks.
      '';
      homepage = "https://beeper.com";
      license = licenses.unfree;
      maintainers = with maintainers; [jshcmpbll];
      platforms = ["x86_64-linux"];
    };
  }
