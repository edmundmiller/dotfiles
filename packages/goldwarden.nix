{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "goldwarden";
  version = "0.2.7";

  src = fetchFromGitHub {
    owner = "quexten";
    repo = "goldwarden";
    rev = "v${version}";
    hash = "sha256-OXJovoJ2+YIMqzoG6J2LlxUC5DMZRAdEl+ZEv6PDXlI=";
  };

  vendorHash = "sha256-1Px60+f23qoP5eEOUC3WG5vKJYjbD3bPOrDyBpXlMT0=";

  ldflags = ["-s" "-w"];

  meta = with lib; {
    description = "A feature-packed Bitwarden compatible desktop integration";
    homepage = "https://github.com/quexten/goldwarden";
    license = licenses.mit;
    maintainers = with maintainers; [];
    mainProgram = "goldwarden";
  };
}
