{ stdenv, fetchurl, alsaLib, unzip, openssl_1_0_2, zlib, libjack2
, autoPatchelfHook }:

let
  pname = "firn";
  version = "0.0.7";
in stdenv.mkDerivation rec {
  name = "${pname}-${version}";

  src = fetchurl {
    url =
      "https://github.com/theiceshelf/firn/releases/download/v${version}/firn-linux.zip";
    sha256 = "046jz6d1pvb3160rri1yfvv0rkang8q3pb47405z4g6889g1zb3z";
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
