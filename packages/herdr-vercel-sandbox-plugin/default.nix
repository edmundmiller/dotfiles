{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gitMinimal,
  nodejs,
}:

stdenvNoCC.mkDerivation {
  pname = "herdr-vercel-sandbox-plugin";
  version = "0.6.0-agent-selection";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "herdr-vercel-sandbox-plugin";
    rev = "be8393aac17eae4b67ca58fdcc5ad8233f91b6c5";
    hash = "sha256-9rVf4Oi5CKJD8VdR1G4LdHIcMTYfj7/Bh7hz3vGS8XE=";
  };

  patches = [
    ./patches/0001-add-explicit-agent-start-actions.patch
  ];

  nativeCheckInputs = [
    gitMinimal
    nodejs
  ];
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    # The upstream real-PTY deletion test is not reliable in a Nix build
    # sandbox. Exercise the patched manifest/docs and action dispatcher here;
    # package-harness runs the complete upstream check outside the derivation.
    node --check src/action-main.mjs
    node --test test/docs.test.mjs test/action.test.mjs
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    plugin_dir="$out/share/herdr/plugins/vercel-sandbox"
    mkdir -p "$plugin_dir"
    cp -R README.md docs herdr-plugin.toml package.json src verification "$plugin_dir/"
    runHook postInstall
  '';

  meta = {
    description = "Run selectable coding-agent CLIs in persistent Vercel Sandboxes from Herdr";
    homepage = "https://github.com/vercel-labs/herdr-vercel-sandbox-plugin";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
