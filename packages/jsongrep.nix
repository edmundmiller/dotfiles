# jsongrep.nix - JSONPath-inspired query language packaged from micahkepe/jsongrep
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "jsongrep";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "micahkepe";
    repo = "jsongrep";
    rev = "v${version}";
    hash = "sha256-rDt4jtrC+KuPKdEoReVWW8R9/sKBnalnRuB4bj1tzas=";
  };

  cargoHash = "sha256-VJ8ZB3oVppMRsSvpVOF1SIvOtI0rcS8elJEweoum/lY=";

  meta = with lib; {
    description = "JSONPath-inspired query language for JSON, YAML, TOML, and other serialization formats";
    homepage = "https://github.com/micahkepe/jsongrep";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "jg";
    platforms = platforms.unix;
  };
}
