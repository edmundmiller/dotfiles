{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  jujutsu,
}:
rustPlatform.buildRustPackage {
  pname = "jj-hunk";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "laulauland";
    repo = "jj-hunk";
    rev = "v0.4.1";
    hash = "sha256-lFuYTg6TW/Lsz4wwaaWFi37F2aGKpLwQgq40VTdDUKE=";
  };

  cargoHash = "sha256-7yCA4a2NM20o7z757lbMtyvFC+72ScTd+N7AKWCH1KU=";

  nativeCheckInputs = [ jujutsu ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/jj-hunk --prefix PATH : ${lib.makeBinPath [ jujutsu ]}
  '';

  meta = with lib; {
    description = "Programmatic hunk selection for Jujutsu";
    homepage = "https://github.com/laulauland/jj-hunk";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "jj-hunk";
    platforms = platforms.unix;
  };
}
