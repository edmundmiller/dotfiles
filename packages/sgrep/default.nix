{
  lib,
  unstable,
}:

unstable.rustPlatform.buildRustPackage {
  pname = "sgrep";
  version = "0.3.0-unstable-2026-10-14";

  src = unstable.fetchFromGitHub {
    owner = "context-dot-dev";
    repo = "sgrep";
    rev = "dde0c13c8d6081f9c6d6d1d33580eebf1034aecf";
    hash = "sha256-/yLT+vg4EfsaWv3CTjN5o8Y3yc1vftwlFuUCSFb8GpE=";
  };

  cargoHash = "sha256-t8hluTvIkvklAaHASs4CXS59JhqTYd9Xo1sAXJ4P3S0=";

  # Parsers are downloaded at runtime; the Nix build must not fetch sources.
  env.TSLP_OFFLINE = "1";

  nativeBuildInputs = [ unstable.makeWrapper ];
  postInstall = ''
    wrapProgram $out/bin/sgrep --prefix PATH : ${lib.makeBinPath [ unstable.ripgrep ]}
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/sgrep --help > /dev/null
    status=0
    $out/bin/sgrep 'empty input' --stdin --json < /dev/null > empty.json || status=$?
    test "$status" -eq 1
    grep -Fx '[]' empty.json
    runHook postInstallCheck
  '';

  meta = {
    description = "Local semantic code and document search with ripgrep and static embeddings";
    homepage = "https://github.com/context-dot-dev/sgrep";
    license = lib.licenses.mit;
    mainProgram = "sgrep";
    platforms = lib.platforms.unix;
  };
}
