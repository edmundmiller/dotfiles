{
  ast-grep,
  fetchFromGitHub,
  rustPlatform,
}:

let
  version = "0.44.1";
  src = fetchFromGitHub {
    owner = "ast-grep";
    repo = "ast-grep";
    tag = version;
    hash = "sha256-C6JwLx6z+/xSm9kMF48hfd3WTRax8Bdy3zgGeYxGyg8=";
  };
in
ast-grep.overrideAttrs (
  _finalAttrs: _previousAttrs: {
    inherit version src;

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-waeAXcxnvTWbuAhVWdA5wPdWvS1aSSptGerFoGEtFUE=";
    };
  }
)
