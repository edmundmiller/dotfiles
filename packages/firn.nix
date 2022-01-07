{ stdenv
, fetchurl
, alsaLib
, unzip
, openssl_1_0_2
, zlib
, libjack2
, autoPatchelfHook
}:

let
  pname = "firn";
  version = "0.0.10";
in
stdenv.mkDerivation rec {
  name = "${pname}-${version}";

  src = fetchurl {
    url =
      "https://github.com/theiceshelf/firn/releases/download/v${version}/firn-linux.zip";
    sha256 = "sha256-/YCIcCveGTNtD4xfgk6RQVAf7qKg0V1+/IX5SNHrZ2s=";
  };

  nativeBuildInputs = [ unzip autoPatchelfHook ];

  buildInputs = [ zlib ];

  unpackPhase = ''
    unzip -qqo $src
  '';

  installPhase = ''
    mkdir -p $out/bin
    chmod +x ${pname}
    install -v -m755 -D firn $out/bin
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/theiceshelf/firn";
    description = "Org Mode Static Site Generator";
    platforms = platforms.linux;
    maintainers = with maintainers; [ emiller88 ];
  };
}
