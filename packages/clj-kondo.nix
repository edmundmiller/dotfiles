{ stdenv, fetchurl, unzip, zlib, libjack2, autoPatchelfHook }:

let
  inherit (stdenv.hostPlatform) system;

  pname = "clj-kondo";
  version = "2020.07.29";
  plat = {
    x86_64-linux = "linux";
    x86_64-darwin = "macos";
  }.${system};
in stdenv.mkDerivation rec {
  name = "${pname}-${version}";

  src = fetchurl {
    url =
      "https://github.com/borkdude/clj-kondo/releases/download/v${version}/clj-kondo-${version}-${plat}-amd64.zip";
    sha256 = "1wsw3aqpp7k4mhzhskdr6rd26b4ngjqhyhb8nf5s4z2j6ix3xfqf";
  };

  nativeBuildInputs = [ unzip autoPatchelfHook ];

  buildInputs = [ zlib stdenv.cc.cc.lib ];

  unpackPhase = ''
    unzip -qqo $src
  '';

  installPhase = ''
    mkdir -p $out/bin
    chmod +x ${pname}
    install -v -m755 -D clj-kondo $out/bin
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/borkdude/clj-kondo";
    description = "A linter for Clojure code that sparks joy.";
    platforms = [ "x86_64-linux" "x86_64-darwin" ];
    maintainers = with maintainers; [ emiller88 ];
  };
}
